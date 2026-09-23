//
//  RootView.swift
//  IdentifySample
//
//  ═══════════════════════════════════════════════════════════════════════════════════════
//  IdentifySDK ENTEGRASYON REHBERİ — uygulamanızın kökü burada kurulur.
//  ═══════════════════════════════════════════════════════════════════════════════════════
//
//  SDK'nın çalışması için host uygulamada üç parça olur:
//
//    ┌─────────────────────┐  path   ┌──────────────────────┐  override  ┌───────────────────┐
//    │ SDKFlowCoordinator  │ ──────▶ │   SDKFlowHostView    │ ─────────▶ │  SDKViewRegistry  │
//    │ (modül sırası,      │         │ (rotayı ekrana       │            │ (rota → host      │
//    │  ilerleme, sonuç)   │         │  çevirir, animasyon) │            │  ekranı)          │
//    └─────────────────────┘         └──────────────────────┘            └───────────────────┘
//
//   1. `SDKFlowCoordinator`  — akışın beyni. Sunucudan gelen modül listesini tutar, hangi ekranın
//                              açık olduğunu bilir (`path`), ilerleme (`progressStep/Total`) ve
//                              bağlantı durumunu yayınlar. Her ekran `@EnvironmentObject` ile
//                              buna erişir ve `advanceToNextModule()` / `popBack()` çağırır.
//   2. `SDKFlowHostView`     — kök view. `path` boşken host'un kök ekranını (giriş), doluysa
//                              sıradaki modülün ekranını çizer. Bağlantı kopması, oda dolu uyarısı
//                              ve ekran geçiş animasyonları burada.
//   3. `SDKViewRegistry`     — "hangi rotada hangi ekran". Kayıt yoksa SDK'nın hazır ekranı
//                              (SDKSelfieView vb.) kullanılır; `override` ile host ekranı,
//                              `custom` ile akışa eklenen ara ekranlar verilir.
//
//  ───────────────────────────────────────────────────────────────────────────────────────
//  AKIŞ SIRASI (LoginViewModel.connect):
//
//    coordinator.prepareForSetup()       // 1) ZORUNLU ve setupSDK'dan ÖNCE
//    IdentifyManager.shared.setupSDK(    // 2) oturum: identId, sunucu, seçenekler, onFinished
//        identId:..., baseApiUrl:..., networkOptions:..., ..., onFinished: { outcome in ... }
//    ) { socket, response, error in
//        if socket?.isConnected == true, response.result == true {
//            coordinator.start()         // 3) sunucunun modül listesiyle ilk ekranı açar
//        }
//    }
//
//  Sonra her şey SDK içinde akar: ekran → ViewModel → yükleme → coordinator.advanceToNextModule()
//  → sıradaki modül. Oturum nasıl biterse bitsin `onFinished` bir kez çağrılır (SDKFlowOutcome).
//
//  ───────────────────────────────────────────────────────────────────────────────────────
//  ÖZELLEŞTİRME KATMANLARI (hafiften ağıra):
//
//    A) Tema           SDKTheme.shared (renk/font/ikon/buton/nav bar) — ekran kodu değişmeden görünüm.
//                      JSON ile: SDKTheme.shared.apply(json:). Rehber: Showcase → Tasarım Sistemi.
//    B) Metin          SDKLocalization.shared.registerOverrides([.tr: ["Connect": "Bağlan"]])
//    C) Ara ekran      registry.custom("welcome") { MyIntroView() }
//                      coordinator.insert(["welcome"], before: .selfie)
//                      → MyIntroView'ın Devam butonu coordinator.advanceExternal() çağırır.
//    D) Tam ekran      registry.override(.selfie) { SelfieCustomView() }
//                      Ekranın tamamı host'a aittir; iş mantığı SDK ViewModel'inde kalır.
//                      Başlangıç noktası: her modülün XxxCustomView.swift dosyası — SDK ekranının
//                      public API ile yazılmış birebir kopyası. Projeye kopyalanır, override ile takılır, üzerinde değişiklik yapılır.
//                      Hepsi bir arada: Modules/CustomKit/CustomScreens.swift
//
//  ───────────────────────────────────────────────────────────────────────────────────────
//  ÖZEL EKRAN KURALLARI (modül detayı her XxxCustomView.swift başında):
//
//    • @EnvironmentObject var coordinator: SDKFlowCoordinator   (SDK enjekte eder)
//    • @StateObject var viewModel = SDKXxxViewModel()           (iş mantığı; kendi HTTP'nizi yazmayın)
//    • Adım bitince yalnızca ViewModel metodu çağrılır (scanFront, processSelfie, submit …);
//      ViewModel yükler, sunucuya adım sinyalini gönderir, sonra canContinue/onCompleted verir.
//    • İlerleme: coordinator.advanceToNextModule()  · Geri: coordinator.popBack()
//    • Karşılaştırma hakları tükenince: onSkipRequested → coordinator.skipCurrentModule(),
//      onFlowFailed → coordinator.finishFlowAsFailed()
//    • Hata: .idErrorAlert($viewModel.errorMessage, onDismiss: { viewModel.consumePendingAlertAction() })
//      (alert kapanınca SDK'nın beklettiği aksiyon — atla/bitir/tekrar — burada çalışır)
//    • Kamera/ARKit/NFC gibi donanım ekranın sorumluluğundadır; SDK'ya yalnızca kare/görüntü verilir.
//    • Xcode Preview: SDKModulePreviewHost { MyView() }  (mock coordinator + kamera yerine yer tutucu)
//
//  Bypass yok: ViewModel atlanıp kendi ağ çağrısıyla ilerlenirse panel adım sinyallerini
//  (stepChanged / modulePresented) almaz, görüşme tarafı akışı takip edemez.
//
//  ───────────────────────────────────────────────────────────────────────────────────────
//  BU ÖRNEK UYGULAMADA: Login ekranı kök; hamburger menü → "Tam Özel Ekranlar" anahtarı açıkken
//  tüm modüller XxxCustomView ile, kapalıyken SDK ekranlarıyla açılır. Aynı kod, iki görünüm.
//

import SwiftUI
import IdentifySDK

struct RootView: View {

    /// Akış durumu. Uygulama ömrü boyunca TEK örnek olmalı; ekranlar environment'tan okur.
    @StateObject private var coordinator = SDKFlowCoordinator()
    /// Rota → ekran kayıt defteri. Kayıtlar `SDKFlowHostView` kurulmadan önce yapılır.
    @State private var registry = SDKViewRegistry()
    @State private var didConfigure = false

    var body: some View {
        SDKFlowHostView(coordinator: coordinator, registry: registry) {
            // Kök ekran host'a aittir: giriş, kimlik numarası, sunucu seçimi… `coordinator.start()`
            // çağrılana kadar yalnızca bu görünür. Kök ekranın da coordinator'a erişmesi
            // gerekir (connect → prepareForSetup / start).
            LoginView()
                .environmentObject(coordinator)
        }
        .onAppear(perform: configureIfNeeded)
    }

    /// Registry kayıtları ve global özelleştirmeler. Bir kez çalışır; akış başlamadan önce
    /// tamamlanmış olmalıdır (ekran çözümlemesi her push'ta registry'ye bakar).
    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        // D) Tam ekran değiştirme — tüm modüller (anahtar kapalıyken SDK ekranına düşer).
        CustomScreens.register(in: registry)

        // E) Belge seçim ekranı ve tarayıcı ayarları. Akış başlamadan verilir;
        //    ekranlar açılırken okunur.
        // Belge türü seçim ekranı yok: modül doğrudan çekimle açılır, tip `defaultType`
        // (verilmezse ilk seçenek) olur ve seçim modül açılır açılmaz sunucuya gider.
        SDKDocumentSelectionConfig.shared.idCard.showsScreen = false
        SDKDocumentSelectionConfig.shared.ovd.showsScreen = false
        // Fener yok: düğme gizlenir ve karanlıkta kendiliğinden de yanmaz. OVD'nin hologram
        // adımındaki fener bu ayardan etkilenmez; o adım fenerle ölçülür.
        ScannerConfiguration.showsTorchButtonDefault = false
        ScannerAutomation.default.autoTorch = false

        // Aşağıdakiler kapalı örneklerdir.

        // B) Metin: SDK metin anahtarı dile göre ezilir.
//        SDKLocalization.shared.registerOverrides([
//            .tr: ["Connect": "Bağlan (host)"],
//            .en: ["Connect": "Connect (host)"]
//        ])

        // C) Ara ekran: Selfie modülünden ÖNCE bir bilgilendirme ekranı.
//        registry.custom("welcome") {
//            SDKExternalInfoView(
//                title: "Hoş geldiniz",
//                subtitle: "Selfie adımından önce kısa bir bilgilendirme ekranı (host tarafından eklendi).",
//                systemIcon: "hand.wave.fill"
//            )
//        }
//        coordinator.insert(["welcome"], before: .selfie)

        // D) Tek bir modül, anahtardan bağımsız olarak, host ekranıyla değiştirilir.
//        registry.override(.addressConfirm) { AddressConfirmCustomView() }

        // A) Tema: marka rengi + buton köşesi (tüm SDK ekranlarına yansır).
//        SDKTheme.shared.colors.primary = IDColor.accentPurple
//        SDKTheme.shared.setButtonCorner(.radius(12))
    }
}
