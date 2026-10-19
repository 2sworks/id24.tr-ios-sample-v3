//
//  IdentifySdkModule.swift
//  React Native köprüsü — IdentifySDK
//
//  SDK'nın setupSDK çağrısını ve birleşik olay akışını (SDKEvent) JS tarafına bağlar.
//  Bu bir İSKELETTİR: imza ve alan eşlemeleri gerçek SDK'ya göredir; projenize
//  uyarlayın (TURN/WS anahtarları, ek parametreler, hata yönetimi).
//
//  setupSDK başarılı olunca SDK ekranlarını (SDKFlowHostView) React Native ekranının üstüne
//  tam ekran sunar ve akışı başlatır; akış bitip köke dönünce ekranı kapatır. Sıra örnek
//  uygulamadakiyle aynı: IdentifySample/Modules/Login/LoginViewModel.swift (connect) ve
//  IdentifySample/App/RootView.swift.
//
//  En az IdentifySDK 3.1.0 ister: `onFinished`, `roomOccupiedMessage` ve tema köprüsünün
//  kullandığı `SDKTheme.shared.apply` / `resetAppearance` 3.0.0'da yok.
//

import Foundation
import UIKit
import SwiftUI
import Combine
import IdentifySDK
import React

@objc(IdentifySdkModule)
class IdentifySdkModule: RCTEventEmitter, SDKEventListener {

    private var hasListeners = false

    // MARK: Akış durumu

    /// Akışın beyni. Modül örneği başına bir tane; tek bridge'de uygulama ömrü boyunca tek
    /// örnek (örnek uygulamadaki RootView gibi).
    @MainActor private lazy var coordinator = SDKFlowCoordinator()
    /// Rota → ekran kayıt defteri. Bir SDK ekranını native tarafta kendi tasarımınızla
    /// değiştirecekseniz (`registry.override`, `registry.custom`) kaydı akış başlamadan yapın.
    private let registry = SDKViewRegistry()
    /// React Native ekranının üstüne sunulan, SDK ekranlarını taşıyan controller.
    private var flowController: UIViewController?
    private var pathObserver: AnyCancellable?
    /// Oturumun sonucu (`onFinished`) geldi mi.
    private var sessionFinished = false
    /// Yanıt bekleyen setupSDK çağrısı ve kimliği. Geri çağrı ile zaman aşımından hangisi önce
    /// gelirse o yanıtlar: SDK aynı kurulumun geri çağrısını tekrarlayabiliyor (ikinci bir
    /// setupSDK ilkinin bağlantı denetimini durdurmuyor), bazı ağ hatalarında hiç vermeyebiliyor.
    private var pendingSetup: (resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock)?
    private var setupID = 0

    // MARK: RCTEventEmitter

    override func supportedEvents() -> [String]! {
        return ["onSDKEvent"]
    }

    override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func startObserving() {
        hasListeners = true
        // Birleşik olay akışına bağlan.
        IdentifyManager.shared.eventDelegate = self
    }

    override func stopObserving() {
        hasListeners = false
        if IdentifyManager.shared.eventDelegate === self {
            IdentifyManager.shared.eventDelegate = nil
        }
    }

    // MARK: SDKEventListener

    func onSDKEvent(_ event: SDKEvent) {
        guard hasListeners else { return }
        // toDictionary() JSON-güvenli (yalnız String/Int/[String:String]) → doğrudan iletilir.
        sendEvent(withName: "onSDKEvent", body: event.toDictionary())
    }

    // MARK: setupSDK köprüsü

    @objc(setupSDK:resolver:rejecter:)
    func setupSDK(_ options: NSDictionary,
                  resolver resolve: @escaping RCTPromiseResolveBlock,
                  rejecter reject: @escaping RCTPromiseRejectBlock) {

        guard
            let identId = options["identId"] as? String,
            let baseApiUrl = options["baseApiUrl"] as? String,
            let turnKey = options["turnKey"] as? String
        else {
            reject("E_ARGS", "identId, baseApiUrl ve turnKey zorunludur", nil)
            return
        }

        let signLang = options["signLangSupport"] as? Bool ?? false
        let nfcMax = options["nfcMaxErrorCount"] as? Int ?? 3
        let showThankYou = options["showThankYouPage"] as? Bool ?? false
        let showNfcNotFound = options["showNFCNotFoundPage"] as? Bool ?? false
        let supportU18 = options["supportU18"] as? Bool ?? false
        let wsSecretKey = options["wsSecretKey"] as? String

        // selectedModules: JS'ten string array (SdkModules rawValue'ları) gelir.
        let moduleRaws = options["selectedModules"] as? [String] ?? []
        let selectedModules = moduleRaws.compactMap { SdkModules(rawValue: $0) }

        DispatchQueue.main.async {
            // SDK ekranını uygulama kendisi kapattıysa (ör. çıkışta bütün ekranları kapatmak) kaydı
            // bırak; yoksa sonraki her çağrı E_BUSY alır.
            if let host = self.flowController, host.presentingViewController == nil {
                self.flowController = nil
                self.pathObserver = nil
                let sessionWasOpen = !IdentifyManager.shared.isSessionClosed
                self.coordinator.resetFlow()   // ekransız kalan oturumu kapatır, akışı köke döndürür
                if sessionWasOpen {
                    // SDK kapanışı 0,1 sn sonra tamamlıyor; yeni kurulum hemen başlarsa onun
                    // verisini silebilir. Bu yüzden bu çağrı E_BUSY ile döner.
                    reject("E_BUSY", "Önceki oturum kapatılıyor, tekrar deneyin", nil)
                    return
                }
            }
            // Kurulum sürerken ya da SDK ekranı açıkken gelen ikinci çağrı (ör. çift dokunma)
            // reddedilir; yoksa SDK ekranları üst üste açılır.
            guard self.pendingSetup == nil, self.flowController == nil else {
                reject("E_BUSY", "Kurulum sürüyor ya da SDK ekranı açık", nil)
                return
            }
            self.setupID += 1
            let id = self.setupID
            self.pendingSetup = (resolve, reject)
            // Geri çağrı hiç gelmezse promise asılı kalmasın, yeni kurulum da engellenmesin.
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
                guard let self = self, self.setupID == id, let pending = self.pendingSetup else { return }
                self.pendingSetup = nil
                pending.reject("E_SETUP", "Kurulum yanıt vermedi", nil)
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
                    useSslPinning: (options["useSslPinning"] as? Bool ?? false)
                ),
                kpsData: nil,
                signLangSupport: signLang,
                // SDK 3.2.0 ve üzerinde işaret dili tercihini de geçirebilirsiniz (3.1.x'te yok):
                // signLangPreference: options["signLangPreference"] as? Bool,
                nfcMaxErrorCount: nfcMax,
                bigCustomerCam: options["bigCustomerCam"] as? Bool,
                selectedModules: selectedModules,
                needCertForNfc: options["needCertForNfc"] as? Bool,
                turnKey: turnKey,
                wsSecretKey: wsSecretKey,
                showThankYouPage: showThankYou,
                showNFCNotFoundPage: showNfcNotFound,
                supportU18: supportU18,
                AESKey: options["AESKey"] as? String,
                enableAutoRotateOCR: options["enableAutoRotateOCR"] as? Bool,
                ttsEnabled: options["ttsEnabled"] as? Bool,
                // Oturum nasıl biterse bitsin bir kez çağrılır. Sonuç JS'e ayrıca
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
                    guard let self = self, self.setupID == id, let pending = self.pendingSetup else { return }
                    self.pendingSetup = nil
                    // DİKKAT: setupSDK hata parametresini HER ZAMAN dolu gönderir; başarılı
                    // kurulumda `errorMessages` boş string olur. Bu yüzden `if let error = error`
                    // başarıda da doğrudur ve akış hiç başlamadan E_SETUP ile reddedilir.
                    // Doğru kontrol, mesajın dolu olup olmadığıdır.
                    if let message = error?.errorMessages, !message.isEmpty {
                        pending.reject("E_SETUP", message, nil)
                        return
                    }
                    guard socket?.isConnected == true, roomResponse.result == true else {
                        pending.reject("E_SETUP", "Socket bağlantısı kurulamadı", nil)
                        return
                    }
                    guard self.presentFlow() else {
                        self.coordinator.resetFlow()   // açık kalan oturumu da kapatır
                        pending.reject("E_PRESENT", "SDK ekranını sunacak view controller bulunamadı", nil)
                        return
                    }
                    self.coordinator.start()   // sunucunun modül listesiyle ilk ekranı açar
                    pending.resolve(["result": true])
                }
            }
        }
    }

    // MARK: SDK ekranının sunumu

    /// SDK ekranlarını React Native ekranının üstüne tam ekran sunar.
    ///
    /// KAPANIŞ ANİMASYONU: SDK akışı kendini sunmaz ve kapatmaz — sunum da kapanış da
    /// host'a (bu köprüye) aittir. Akış köke döndüğünde (sonuç ekranında "Tamam", ilk ekranda
    /// geri, `showThankYouPage: false` ile kapanış) `coordinator.path` boşalır; oturum da
    /// bittiyse ekran animasyonlu kaldırılır. Sunumu değiştirirseniz kapanışı da
    /// animasyonlu yapın: `dismiss(animated: false)` ekranı ANINDA kapatır.
    @MainActor
    private func presentFlow() -> Bool {
        guard let presenter = Self.topViewController() else { return false }
        let host = UIHostingController(rootView: SDKFlowHostView(coordinator: coordinator, registry: registry) {
            EmptyView()   // kök: path boşken (akış başlamadan hemen önce, kapanırken) görünür
        })
        host.modalPresentationStyle = .fullScreen
        host.modalTransitionStyle = .coverVertical     // yukarıdan aşağı kapanış
        presenter.present(host, animated: true)
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
        // kapatır; host.dismiss yalnız o üstteki ekranı kapatırdı.
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

    // MARK: Tema köprüsü

    /// JS tarafından gönderilen tema sözlüğünü uygular.
    ///
    /// Renk/logo/köşe denemesi için **native derleme gerekmez**: JS reload yeterlidir.
    /// Dönen dizi tanınmayan anahtarları içerir (yazım hatalarını görmek için).
    ///
    /// JS: `await IdentifySdk.setTheme({ colors: { primary: "#0F172A" } })`
    @objc(setTheme:resolver:rejecter:)
    func setTheme(_ theme: NSDictionary,
                  resolver resolve: @escaping RCTPromiseResolveBlock,
                  rejecter reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            let unknown = SDKTheme.shared.apply(theme as? [String: Any] ?? [:])
            resolve(["result": true, "unknownKeys": unknown])
        }
    }

    /// Tüm görünüm override'larını siler (SDK varsayılanlarına döner).
    @objc(resetTheme)
    func resetTheme() {
        DispatchQueue.main.async {
            SDKTheme.shared.resetAppearance()
        }
    }

    /// Kullanıcı SDK'yı açıkça kapattığında terk olayını tetiklemek için.
    @objc(reportAbandoned:)
    func reportAbandoned(_ reason: NSString?) {
        IdentifyManager.shared.reportSessionAbandoned(reason: reason as String?)
    }
}
