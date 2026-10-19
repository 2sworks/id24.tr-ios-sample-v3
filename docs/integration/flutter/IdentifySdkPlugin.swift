//
//  IdentifySdkPlugin.swift
//  Flutter plugin köprüsü — IdentifySDK
//
//  MethodChannel ile setupSDK'yı, EventChannel ile birleşik olay akışını (SDKEvent)
//  Dart tarafına bağlar. Bu bir İSKELETTİR; projenize uyarlayın.
//
//  setupSDK başarılı olunca SDK ekranlarını (SDKFlowHostView) Flutter ekranının üstüne tam
//  ekran sunar ve akışı başlatır; akış bitip köke dönünce ekranı kapatır. Sıra örnek
//  uygulamadakiyle aynı: IdentifySample/Modules/Login/LoginViewModel.swift (connect) ve
//  IdentifySample/App/RootView.swift.
//
//  En az IdentifySDK 3.1.0 ister: `onFinished`, `roomOccupiedMessage` ve tema köprüsünün
//  kullandığı `SDKTheme.shared.apply` / `resetAppearance` 3.0.0'da yok.
//

import Flutter
import UIKit
import SwiftUI
import Combine
import IdentifySDK

public class IdentifySdkPlugin: NSObject, FlutterPlugin, SDKEventListener, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?

    // MARK: Akış durumu

    /// Akışın beyni. Plugin örneği başına bir tane; tek FlutterEngine'de uygulama ömrü boyunca
    /// tek örnek (örnek uygulamadaki RootView gibi).
    @MainActor private lazy var coordinator = SDKFlowCoordinator()
    /// Rota → ekran kayıt defteri. Bir SDK ekranını native tarafta kendi tasarımınızla
    /// değiştirecekseniz (`registry.override`, `registry.custom`) kaydı akış başlamadan yapın.
    private let registry = SDKViewRegistry()
    /// Flutter ekranının üstüne sunulan, SDK ekranlarını taşıyan controller.
    private var flowController: UIViewController?
    private var pathObserver: AnyCancellable?
    /// Oturumun sonucu (`onFinished`) geldi mi.
    private var sessionFinished = false
    /// Yanıt bekleyen setupSDK çağrısı ve kimliği. Geri çağrı ile zaman aşımından hangisi önce
    /// gelirse o yanıtlar: SDK aynı kurulumun geri çağrısını tekrarlayabiliyor (ikinci bir
    /// setupSDK ilkinin bağlantı denetimini durdurmuyor), bazı ağ hatalarında hiç vermeyebiliyor.
    private var pendingSetup: FlutterResult?
    private var setupID = 0
    /// SDK ekranının sunumu tamamlandı mı ve ne zaman istendi. Sıraya giren sunumda host bir
    /// süre ekranda görünmez; bu, "uygulama kapattı" ile karıştırılmasın.
    private var flowShown = false
    private var presentRequestedAt = Date.distantPast

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = IdentifySdkPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "identify_sdk/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "identify_sdk/events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    // MARK: FlutterStreamHandler (olay akışı)

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        IdentifyManager.shared.eventDelegate = self
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        if IdentifyManager.shared.eventDelegate === self {
            IdentifyManager.shared.eventDelegate = nil
        }
        return nil
    }

    // MARK: SDKEventListener

    public func onSDKEvent(_ event: SDKEvent) {
        // toDictionary() JSON-güvenli → EventSink ile doğrudan Dart'a.
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event.toDictionary())
        }
    }

    // MARK: MethodChannel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setupSDK":
            setupSDK(call.arguments as? [String: Any] ?? [:], result: result)
        case "setTheme":
            // Tema sözlüğü Dart tarafından gelir; native derleme gerekmez.
            let unknown = SDKTheme.shared.apply(call.arguments as? [String: Any] ?? [:])
            result(["result": true, "unknownKeys": unknown])
        case "resetTheme":
            SDKTheme.shared.resetAppearance()
            result(nil)
        case "reportAbandoned":
            let reason = (call.arguments as? [String: Any])?["reason"] as? String
            IdentifyManager.shared.reportSessionAbandoned(reason: reason)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupSDK(_ args: [String: Any], result: @escaping FlutterResult) {
        guard
            let identId = args["identId"] as? String,
            let baseApiUrl = args["baseApiUrl"] as? String,
            let turnKey = args["turnKey"] as? String
        else {
            result(FlutterError(code: "E_ARGS", message: "identId, baseApiUrl ve turnKey zorunludur", details: nil))
            return
        }

        let moduleRaws = args["selectedModules"] as? [String] ?? []
        let selectedModules = moduleRaws.compactMap { SdkModules(rawValue: $0) }

        // Coordinator ve SDK ekranları ana thread'de (MainActor) çalışır.
        DispatchQueue.main.async {
            // SDK ekranını uygulama kendisi kapattıysa (ör. çıkışta bütün ekranları kapatmak) ya da
            // sunum hiç gerçekleşmediyse kaydı bırak; yoksa sonraki her çağrı E_BUSY alır. Sıraya
            // giren sunum (gösterilmedi, 2 sn dolmadı) kapatılmış sayılmaz.
            if let host = self.flowController, host.presentingViewController == nil,
               self.flowShown || Date().timeIntervalSince(self.presentRequestedAt) > 2 {
                self.flowController = nil
                self.pathObserver = nil
                let sessionWasOpen = !IdentifyManager.shared.isSessionClosed
                self.coordinator.resetFlow()   // ekransız kalan oturumu kapatır, akışı köke döndürür
                if sessionWasOpen {
                    // SDK kapanışı 0,1 sn sonra tamamlıyor; yeni kurulum hemen başlarsa onun
                    // verisini silebilir. Bu yüzden bu çağrı E_BUSY ile döner.
                    result(FlutterError(code: "E_BUSY", message: "Önceki oturum kapatılıyor, tekrar deneyin", details: nil))
                    return
                }
            }
            // Kurulum sürerken ya da SDK ekranı açıkken gelen ikinci çağrı (ör. çift dokunma)
            // reddedilir; yoksa SDK ekranları üst üste açılır.
            guard self.pendingSetup == nil, self.flowController == nil else {
                result(FlutterError(code: "E_BUSY", message: "Kurulum sürüyor ya da SDK ekranı açık", details: nil))
                return
            }
            self.setupID += 1
            let id = self.setupID
            self.pendingSetup = result
            // Geri çağrı hiç gelmezse çağrı yanıtsız kalmasın, yeni kurulum da engellenmesin.
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
                guard let self = self, self.setupID == id, let reply = self.pendingSetup else { return }
                self.pendingSetup = nil
                reply(FlutterError(code: "E_SETUP", message: "Kurulum yanıt vermedi", details: nil))
            }
            self.sessionFinished = false
            // ZORUNLU ve setupSDK'dan ÖNCE: modül controller'larını SDK'ya kaydeder.
            // Atlanırsa ya da setupSDK'dan sonra çağrılırsa modüller başlamaz.
            self.coordinator.prepareForSetup()

            IdentifyManager.shared.setupSDK(
                identId: identId,
                baseApiUrl: baseApiUrl,
                networkOptions: SDKNetworkOptions(
                    timeoutIntervalForRequest: 30,
                    timeoutIntervalForResource: 30,
                    useSslPinning: args["useSslPinning"] as? Bool ?? false
                ),
                kpsData: nil,
                signLangSupport: args["signLangSupport"] as? Bool ?? false,
                // SDK 3.2.0 ve üzerinde işaret dili tercihini de geçirebilirsiniz (3.1.x'te yok):
                // signLangPreference: args["signLangPreference"] as? Bool,
                nfcMaxErrorCount: args["nfcMaxErrorCount"] as? Int ?? 3,
                bigCustomerCam: args["bigCustomerCam"] as? Bool,
                selectedModules: selectedModules,
                needCertForNfc: args["needCertForNfc"] as? Bool,
                turnKey: turnKey,
                wsSecretKey: args["wsSecretKey"] as? String,
                showThankYouPage: args["showThankYouPage"] as? Bool ?? false,
                showNFCNotFoundPage: args["showNFCNotFoundPage"] as? Bool ?? false,
                supportU18: args["supportU18"] as? Bool ?? false,
                AESKey: args["AESKey"] as? String,
                enableAutoRotateOCR: args["enableAutoRotateOCR"] as? Bool,
                ttsEnabled: args["ttsEnabled"] as? Bool,
                // Oturum nasıl biterse bitsin bir kez çağrılır. Sonuç Dart'a ayrıca
                // `session.finished` olayıyla gider; burada yalnızca SDK ekranı kapatılır.
                onFinished: { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.sessionFinished = true
                        self?.dismissFlowIfFinished()
                    }
                }
            ) { [weak self] socket, roomResponse, error in
                DispatchQueue.main.async {
                    // Yalnız bu kurulumun ilk geri çağrısı işlenir; tekrarları yok sayılır.
                    guard let self = self, self.setupID == id, let reply = self.pendingSetup else { return }
                    self.pendingSetup = nil
                    // DİKKAT: setupSDK hata parametresini HER ZAMAN dolu gönderir; başarılı
                    // kurulumda `errorMessages` boş string olur. Bu yüzden `if let error = error`
                    // başarıda da doğrudur ve akış hiç başlamadan E_SETUP ile reddedilir.
                    // Doğru kontrol, mesajın dolu olup olmadığıdır.
                    if let message = error?.errorMessages, !message.isEmpty {
                        reply(FlutterError(code: "E_SETUP", message: message, details: nil))
                        return
                    }
                    guard socket?.isConnected == true, roomResponse.result == true else {
                        reply(FlutterError(code: "E_SETUP", message: "Socket bağlantısı kurulamadı", details: nil))
                        return
                    }
                    guard self.presentFlow() else {
                        self.coordinator.resetFlow()   // açık kalan oturumu da kapatır
                        reply(FlutterError(code: "E_PRESENT", message: "SDK ekranını sunacak view controller bulunamadı", details: nil))
                        return
                    }
                    self.coordinator.start()   // sunucunun modül listesiyle ilk ekranı açar
                    reply(["result": true])
                }
            }
        }
    }

    // MARK: SDK ekranının sunumu

    /// SDK ekranlarını Flutter ekranının üstüne tam ekran sunar.
    ///
    /// SDK akışı kendini sunmaz ve kapatmaz; ikisi de host'un (bu köprünün) işi. Akış köke
    /// döndüğünde (sonuç ekranında "Tamam", ilk ekranda geri, `showThankYouPage: false` ile
    /// kapanış) `coordinator.path` boşalır; oturum da bittiyse ekran kapatılır.
    @MainActor
    private func presentFlow() -> Bool {
        guard let presenter = Self.topViewController() else { return false }
        let host = UIHostingController(rootView: SDKFlowHostView(coordinator: coordinator, registry: registry) {
            EmptyView()   // kök: path boşken (akış başlamadan hemen önce, kapanırken) görünür
        })
        host.modalPresentationStyle = .fullScreen
        host.modalTransitionStyle = .coverVertical
        flowShown = false
        presentRequestedAt = Date()
        presenter.present(host, animated: true) { [weak self, weak host] in
            // Sunum tamamlandı (sıraya girdiyse önceki geçiş bitince); reddedilirse hiç gelmez.
            if let self = self, let host = host, self.flowController === host { self.flowShown = true }
        }
        flowController = host
        pathObserver = coordinator.$path
            .dropFirst()
            .filter { $0.isEmpty }
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.dismissFlowIfFinished() }
            }
        return true
    }

    /// Oturum bittiyse ve akış köke döndüyse SDK ekranını kapatır. Sonuç ekranı açıksa
    /// (`showThankYouPage: true`) kullanıcı "Tamam"a basana kadar beklenir.
    @MainActor
    private func dismissFlowIfFinished() {
        guard sessionFinished, let host = flowController,
              coordinator.path.isEmpty, coordinator.roomOccupiedMessage == nil else { return }
        flowController = nil
        pathObserver = nil
        // Host'un üstünde SDK'nın açtığı bir ekran (ör. bağlantı koptu) kaldıysa onunla birlikte
        // kapatır; host.dismiss yalnız o üstteki ekranı kapatırdı. animated: false ANINDA kapatır.
        host.presentingViewController?.dismiss(animated: true)
    }

    /// SDK ekranının sunulacağı, uygulamanın en üstteki controller'ı.
    @MainActor
    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        // Kapanmakta olan ekranın üstüne sunulan ekran hiç açılmaz; onu atla, sunum sıraya girer.
        while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }
}
