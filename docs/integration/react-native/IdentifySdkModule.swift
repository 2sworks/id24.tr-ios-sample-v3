//
//  IdentifySdkModule.swift
//  React Native köprüsü — IdentifySDK
//
//  SDK'nın setupSDK çağrısını ve birleşik olay akışını (SDKEvent) JS tarafına bağlar.
//  Bu bir İSKELETTİR: imza ve alan eşlemeleri gerçek SDK'ya göredir; projenize
//  uyarlayın (TURN/WS anahtarları, ek parametreler, hata yönetimi).
//

import Foundation
import IdentifySDK
import React

@objc(IdentifySdkModule)
class IdentifySdkModule: RCTEventEmitter, SDKEventListener {

    private var hasListeners = false

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
                nfcMaxErrorCount: nfcMax,
                selectedModules: selectedModules,
                turnKey: turnKey,
                wsSecretKey: wsSecretKey,
                showThankYouPage: showThankYou,
                showNFCNotFoundPage: showNfcNotFound,
                supportU18: supportU18
            ) { socket, roomResponse, error in
                // DİKKAT: setupSDK hata parametresini HER ZAMAN dolu gönderir; başarılı
                // kurulumda `errorMessages` boş string olur. Bu yüzden `if let error = error`
                // başarıda da doğrudur ve akış hiç başlamadan E_SETUP ile reddedilir.
                // Doğru kontrol, mesajın dolu olup olmadığıdır.
                if let message = error?.errorMessages, !message.isEmpty {
                    reject("E_SETUP", message, nil)
                    return
                }
                guard socket?.isConnected == true, roomResponse.result == true else {
                    reject("E_SETUP", "Socket bağlantısı kurulamadı", nil)
                    return
                }
                // Akışı sunmak için: kendi UIViewController host'unuzu present edin,
                // veya SDKFlowHostView (SwiftUI) ile coordinator'ı start() edin.
                //
                // KAPANIŞ ANİMASYONU: SDK akışı kendini sunmaz ve kapatmaz — sunum da
                // kapanış da host'a aittir. Akış bittiğinde ekranı animasyonlu kaldırın:
                //
                //   host.modalPresentationStyle = .fullScreen
                //   host.modalTransitionStyle = .coverVertical     // yukarıdan aşağı
                //   presenter.present(host, animated: true)
                //   ...
                //   host.dismiss(animated: true)                   // animated: false ANINDA kapatır
                //
                // React Native tarafında akışı <Modal animationType="slide"> içinde
                // gösteriyorsanız kapanış animasyonu oradan gelir.
                resolve(["result": true])
            }
        }
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
