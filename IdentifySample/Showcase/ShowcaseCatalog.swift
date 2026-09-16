//
//  ShowcaseCatalog.swift
//  IdentifySample
//
//  SDK Modül Rehberi'nin veri kaynağı. Her modül için canlı ekranı taşır;
//  ShowcaseCatalogView/DetailView bunu kullanır. Entegrasyon kodu burada değil,
//  docs/ altındaki rehberlerdedir.
//

import SwiftUI
import IdentifySDK

// MARK: - ShowcaseItem

struct ShowcaseItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String              // SF Symbol
    /// Katalogda gruplama başlığı ("Modüller" / "Tasarım Sistemi").
    var category: String = "Modüller"
    /// Canlı SDK ekranı (mock coordinator ile çizilir).
    let liveView: () -> AnyView
}

/// Katalogdaki bölüm sırası.
let showcaseCategories = ["Modüller", "Tasarım Sistemi", "Sesli Okuma", "Olay Örgüsü / Telemetri", "Çapraz Platform (RN/Flutter)"]

// MARK: - Katalog

@MainActor
enum ShowcaseCatalog {

    static let items: [ShowcaseItem] = [
        .init(
            id: "prepare", title: "Hazırlık (Prepare)",
            subtitle: "Kullanıcıyı sürece hazırlayan bilgilendirme ekranı",
            icon: "checklist",
            liveView: { AnyView(SDKPrepareView()) }
        ),
        .init(
            id: "selfie", title: "Selfie",
            subtitle: "Yüz yakalama + canlılık (liveness) ile selfie",
            icon: "person.crop.square",
            liveView: { AnyView(SDKSelfieView()) }
        ),
        .init(
            id: "selfieWithLiveness", title: "Canlılıkla Selfie (ARKit)",
            subtitle: "ARKit yüz takibiyle aktif canlılık + selfie doğrulama",
            icon: "faceid",
            liveView: { AnyView(SDKSelfieWithLivenessView()) }
        ),
        .init(
            id: "idCard", title: "Kimlik Kartı (OCR)",
            subtitle: "Kimlik ön/arka tarama + OCR",
            icon: "person.text.rectangle",
            // "Ekran modu" senaryosu: tek ekran tarama açıksa örnek ekran, değilse SDK ekranı.
            liveView: {
                CustomScreens.isIdCardSingleScreenEnabled
                    ? AnyView(IdCardSingleScreenCustomView())
                    : AnyView(SDKIdCardView())
            }
        ),
        .init(
            id: "nfc", title: "NFC Pasaport/Kimlik",
            subtitle: "ICAO çip okuma (BAC/PACE/Secure Messaging)",
            icon: "wave.3.right.circle",
            liveView: { AnyView(SDKNfcView()) }
        ),
        .init(
            id: "idCardOVD", title: "Kimlik OVD (Hologram)",
            subtitle: "Optik değişken (hologram/gökkuşağı) güvenlik doğrulaması",
            icon: "sparkles.rectangle.stack",
            liveView: { AnyView(SDKIdCardOVDView()) }
        ),
        .init(
            id: "liveness", title: "Canlılık (Liveness)",
            subtitle: "Aktif canlılık tespiti",
            icon: "face.smiling",
            liveView: { AnyView(SDKLivenessView()) }
        ),
        .init(
            id: "speech", title: "Konuşma (Speech)",
            subtitle: "Sesli ifade / konuşma tanıma adımı",
            icon: "waveform",
            liveView: { AnyView(SDKSpeechRecView()) }
        ),
        .init(
            id: "addressConfirm", title: "Adres Onayı",
            subtitle: "Adres girişi + fatura/belge yükleme",
            icon: "house.circle",
            liveView: { AnyView(SDKAddressConfirmView()) }
        ),
        .init(
            id: "signature", title: "İmza (Signature)",
            subtitle: "El ile ıslak imza yakalama",
            icon: "signature",
            liveView: { AnyView(SDKSignatureView()) }
        ),
        .init(
            id: "videoRecorder", title: "Video Kayıt",
            subtitle: "Onam/beyan video kaydı",
            icon: "video.circle",
            liveView: { AnyView(SDKVideoRecorderView()) }
        ),
        .init(
            id: "callScreen", title: "Görüntülü Görüşme",
            subtitle: "WebRTC ile temsilci görüşmesi — bekleme, çalma, SMS ve sonlandırma senaryoları panelden sürülür",
            icon: "phone.circle",
            liveView: { AnyView(CallScreenShowcaseView()) }
        ),
        .init(
            id: "thankYou", title: "Teşekkür / Sonuç",
            subtitle: "Süreç sonucu (pozitif/negatif/kaçırılmış)",
            icon: "checkmark.seal",
            liveView: { AnyView(ThankYouShowcasePreview()) }
        ),
        .init(
            id: "signLang", title: "İşaret Dili (opt-in)",
            subtitle: "Görüşme başında işaret dili desteği tercihi",
            icon: "hand.raised.fingers.spread",
            liveView: { AnyView(SDKSignLangView(onFinish: {})) }
        ),
        .init(
            id: "lostConnection", title: "Bağlantı Koptu",
            subtitle: "Görüşmede internet/socket kopunca yeniden bağlanma",
            icon: "wifi.exclamationmark",
            liveView: { AnyView(SDKLostConnectionView()) }
        ),

        // MARK: Tasarım Sistemi (SDK'nın ortak UI primitifleri)
        .init(
            id: "ds_colors", title: "Renkler (Colors)",
            subtitle: "IDColor paleti — tüm token'lar SDKTheme'den okunur, host override edebilir",
            icon: "paintpalette", category: "Tasarım Sistemi",
            liveView: { AnyView(ColorsShowcaseView()) }
        ),
        .init(
            id: "ds_fonts", title: "Tipografi (Fonts)",
            subtitle: "IDFont ölçeği — varsayılan Inter; host kendi fontunu register edebilir",
            icon: "textformat", category: "Tasarım Sistemi",
            liveView: { AnyView(FontsShowcaseView()) }
        ),
        .init(
            id: "ds_navbar", title: "Navigation Bar",
            subtitle: "SDKNavigationBar — login / module / progress / overlay stilleri",
            icon: "rectangle.topthird.inset.filled", category: "Tasarım Sistemi",
            liveView: { AnyView(NavBarShowcaseView()) }
        ),
        .init(
            id: "ds_button", title: "Buton (Button)",
            subtitle: "SDKButton — 4 stil + loading/disabled; köşe/yükseklik/kenarlık/gölge canlı denenir",
            icon: "capsule", category: "Tasarım Sistemi",
            liveView: { AnyView(ButtonsShowcaseView()) }
        ),
        .init(
            id: "ds_theme_json", title: "JSON ile Tema",
            subtitle: "Tek sözlükle tüm görünüm — RN/Flutter'da native derleme gerekmez",
            icon: "curlybraces", category: "Tasarım Sistemi",
            liveView: { AnyView(ThemeJSONShowcaseView()) }
        ),
        .init(
            id: "ds_alerts", title: "Uyarı (Alert)",
            subtitle: "IDAlert — info / error / success / normal + tek/çift/destructive aksiyon",
            icon: "exclamationmark.bubble", category: "Tasarım Sistemi",
            liveView: { AnyView(AlertsShowcaseView()) }
        ),

        .init(
            id: "ds_customization", title: "Özelleştirme (Metin + İkon)",
            subtitle: "Hazır ekranların metinlerini ve ikonlarını dışarıdan override et",
            icon: "slider.horizontal.3", category: "Tasarım Sistemi",
            liveView: { AnyView(CustomizationShowcaseView()) }
        ),

        // MARK: Sesli Okuma (read-aloud / erişilebilirlik)
        .init(
            id: "speech_read_aloud", title: "Sesli Okuma (Read-Aloud)",
            subtitle: "Modül yönergelerini native (Siri) sesle oku veya kendi ses kaydını çal",
            icon: "speaker.wave.2.circle",
            category: "Sesli Okuma",
            liveView: { AnyView(SpeechShowcaseView()) }
        ),

        // MARK: Olay Örgüsü / Telemetri (SDK'nın birleşik olay akışı)
        .init(
            id: "event_journey", title: "Olay Örgüsü (Telemetri)",
            subtitle: "SDK ne zaman nerede ne yaptı, kullanıcı hangi ekranda çıktı, oturum nasıl kapandı",
            icon: "point.topleft.down.curvedto.point.bottomright.up",
            category: "Olay Örgüsü / Telemetri",
            liveView: { AnyView(EventJourneyView()) }
        ),

        // MARK: Çapraz Platform (RN/Flutter) — gömülü köprü iskeletleri (target'a eklenmez)
        .init(
            id: "cross_platform", title: "React Native & Flutter Köprüsü",
            subtitle: "Birleşik olay akışını RN ve Flutter'a taşıyan köprü iskeletleri (gömülü kod gösterimi)",
            icon: "arrow.triangle.branch",
            category: "Çapraz Platform (RN/Flutter)",
            liveView: { AnyView(CrossPlatformIntegrationView()) }
        ),
    ]

}
