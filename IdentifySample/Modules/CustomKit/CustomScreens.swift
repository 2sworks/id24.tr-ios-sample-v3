//
//  CustomScreens.swift
//  IdentifySample
//
//  Tüm modüllerin tam özel ekranlarını SDK akışına takar.
//
//  Host uygulamada yalnızca gereken satırlar kullanılır:
//
//      let registry = SDKViewRegistry()
//      registry.override(.selfie) { SelfieCustomView() }
//      SDKFlowHostView(coordinator: coordinator, registry: registry) { LoginView() }
//
//  Örnek uygulamada ekranlar hamburger menüsündeki "Tam Özel Ekranlar" anahtarıyla açılıp kapatılır;
//  kapalıyken SDK'nın kendi ekranları görünür. Anahtar ekran her açıldığında okunduğu için
//  uygulamayı yeniden başlatmak gerekmez; anahtar akış başlamadan önce değiştirilir.
//

import SwiftUI
import IdentifySDK

enum CustomScreens {

    /// Hamburger menüsündeki anahtarın `UserDefaults` adı.
    static let storageKey = "sampleCustomScreensEnabled"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: storageKey) }

    /// Görüşme socket üzerinden bittiğinde (ör. panel `.endCall`) teşekkür ekranında gösterilecek durum.
    ///
    /// SDK'nın kendi görüşme ekranı bunu `coordinator.pendingThankYouStatus`'a yazar; o alanın
    /// setter'ı 3.1.0'da public olmadığından özel görüşme ekranı değeri burada bırakır, özel
    /// teşekkür ekranı `.thankYou(nil)` rotasında buradan okur.
    @MainActor static var pendingThankYouStatus: ThankYouStatus?

    @MainActor
    static func register(in registry: SDKViewRegistry) {
        registry.override(.prepare)        { pick(PrepareCustomView(), else: SDKPrepareView()) }
        registry.override(.selfie)         { pick(SelfieCustomView(), else: SDKSelfieView()) }
        registry.override(.selfieWithLiveness) { pick(SelfieWithLivenessCustomView(), else: SDKSelfieWithLivenessView()) }
        registry.override(.idCard)         { pick(IdCardCustomView(), else: SDKIdCardView()) }
        registry.override(.idCardOVD)      { pick(IdCardOVDCustomView(), else: SDKIdCardOVDView()) }
        registry.override(.nfc)            { pick(NfcCustomView(), else: SDKNfcView()) }
        registry.override(.liveness)       { pick(LivenessCustomView(), else: SDKLivenessView()) }
        registry.override(.speech)         { pick(SpeechCustomView(), else: SDKSpeechRecView()) }
        registry.override(.addressConfirm) { pick(AddressConfirmCustomView(), else: SDKAddressConfirmView()) }
        registry.override(.signature)      { pick(SignatureCustomView(), else: SDKSignatureView()) }
        registry.override(.videoRecorder)  { pick(VideoRecorderCustomView(), else: SDKVideoRecorderView()) }
        registry.override(.callScreen)     { pick(CallScreenCustomView(), else: SDKCallScreenView()) }

        // Teşekkürler rotası bitiş durumunu taşır; her değer ayrı anahtardır.
        registry.override(.thankYou(nil)) {
            pick(ThankYouCustomView(status: pendingThankYouStatus ?? .completed), else: SDKThankYouView())
        }
        for status in [ThankYouStatus.completed, .missedCall, .notCompleted] {
            registry.override(.thankYou(status)) {
                pick(ThankYouCustomView(status: status), else: SDKThankYouView(status: status))
            }
        }

        // Bağlantı Koptu ve İşaret Dili ekranları rota değildir; özel sürümleri
        // CallScreenCustomView içinde kullanılır.
    }

    /// Anahtar açıksa özel ekranı, kapalıysa SDK ekranını döndürür.
    @ViewBuilder
    private static func pick<Custom: View, Default: View>(_ custom: @autoclosure () -> Custom,
                                                          else fallback: @autoclosure () -> Default) -> some View {
        if isEnabled { custom() } else { fallback() }
    }
}
