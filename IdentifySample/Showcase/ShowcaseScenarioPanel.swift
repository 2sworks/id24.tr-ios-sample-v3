//
//  ShowcaseScenarioPanel.swift
//  IdentifySample
//
//  Showcase'te modülleri SENARYO bazında denemek için yüzen butonla açılan popup.
//
//  Gerçek akışta modüllerin davranışını iki şey belirler: oturum açılışında backend'in
//  döndürdüğü bayraklar (`hide_call_answer_screen`, `liveness_recording`, …) ve görüşme
//  sırasında socket'ten gelen aksiyonlar (`.incomingCall`, `.startTransfer`, …). Backend
//  olmadan bunların hiçbiri tetiklenemediği için showcase'te modül tek bir durumda
//  donuk kalıyordu.
//
//  Panel ikisini de elle sürer:
//    • Bayraklar doğrudan `IdentifyManager.shared` üzerine yazılır (mock oturum verisi
//      gibi; katalog kapanırken ShowcaseMockData.restore() ile temizlenir).
//    • Socket aksiyonları `IdentifyManager.shared.socketMessageListener` üzerinden
//      gönderilir — SDK'nın kendi socket'inin kullandığı yolun AYNISI, yani ekran
//      gerçek akıştaki gibi tepki verir.
//

import SwiftUI
import IdentifySDK

// MARK: - Panelin tek bir satırı

/// Popup'ta gösterilecek bir bayrak (toggle) ya da aksiyon (buton).
enum ShowcaseControl: Identifiable {

    /// Sunucudan gelen bir bool. Oturum açılışında okunduğu için değişiklik ancak modül
    /// yeniden kurulunca görünür; popup kapanınca ekran otomatik yeniden kurulur.
    case flag(title: String, note: String, get: () -> Bool, set: (Bool) -> Void)

    /// Tek seferlik tetik.
    ///
    /// - Parameter reloads: `true` ise değişiklik modülün KURULUMUNU etkiler (oturum verisi,
    ///   belge türü, deneme hakkı) ve ekran yeniden kurulur. `false` ise etki canlı
    ///   ViewModel üzerindedir (socket aksiyonları) — yeniden kurmak o durumu siler.
    case action(title: String, note: String, reloads: Bool = true, run: () -> Void)

    var id: String {
        switch self {
        case .flag(let title, _, _, _):    return "flag-" + title
        case .action(let title, _, _, _):  return "action-" + title
        }
    }
}

// MARK: - Kontrol grubu

/// Birbirine bağlı kontroller tek başlık altında toplanır; kontroller o başlığın alt
/// maddeleridir (ör. "Deneme hakkı" grubunun altında "5 hak" ve "0 hak").
struct ShowcaseScenarioGroup: Identifiable {
    let title: String
    /// Grubun ne anlattığı; tek satır.
    let note: String
    let controls: [ShowcaseControl]
    /// Adımların SIRAYLA uygulanması gerekiyorsa alt maddeler numaralandırılır.
    var isOrdered: Bool = false

    var id: String { title }
}

// MARK: - Hazırlanıyor / reproduce durumu

/// Senaryo değişikliğini "Hazırlanıyor" örtüsü altında uygulayan paylaşılan durum.
///
/// Her senaryo için akış aynıdır: örtü açılır → değişiklik uygulanır → örtü kapanır ve ekran
/// yeni hâliyle görünür. Geri sayım yok; kullanıcı sayıyı değil sonucu bekler.
///
/// İki senaryo türü vardır ve ayrım davranışı belirler:
/// - **Kurulum senaryoları** (bayraklar, belge türü, deneme hakkı, oturum verisi) modül
///   KURULURKEN okunur; örtü altında modül sıfırdan kurulur (`reloadToken`).
/// - **Canlı senaryolar** (socket aksiyonları) ekrandaki ViewModel'e etki eder; modül
///   yeniden kurulmaz, yoksa aksiyonun ürettiği durum hemen silinirdi. Onlarda aksiyonun
///   kendisi örtü altında çalıştırılır, böylece örtü kalkarken ekran değişmiş olur.
@MainActor
final class ShowcaseScenarioState: ObservableObject {

    static let shared = ShowcaseScenarioState()

    /// Örtü açık mı.
    @Published private(set) var isPreparing = false
    /// Canlı ekranın kimliği; değişince SwiftUI modülü sıfırdan kurar.
    @Published private(set) var reloadToken = UUID()

    /// Örtünün açık kalacağı süre. Ekranın "bir şey oldu" hissini vermesi için görünür,
    /// beklemeyi uzatmayacak kadar kısa.
    private let prepareDuration: UInt64 = 900_000_000

    /// Örtü altında çalıştırılacak iş (socket aksiyonu).
    private var pendingWork: (() -> Void)?
    /// Modülün yeniden kurulması gerekiyor mu.
    private var needsReload = false
    private var task: Task<Void, Never>?

    private init() {}

    /// Bir bayrak değişti: uygulanması için modül yeniden kurulmalı.
    func flagChanged() {
        needsReload = true
    }

    /// Bir aksiyona basıldı.
    ///
    /// - Parameters:
    ///   - reloads: Aksiyon modülün kurulumunu etkiliyorsa `true`; canlı ViewModel'e
    ///     etki eden socket aksiyonlarında `false`.
    ///   - work: Örtü açıldıktan sonra çalıştırılacak iş.
    func actionTapped(reloads: Bool, work: @escaping () -> Void) {
        if reloads {
            // Kurulum verisi: hemen yazılır, etkisi yeniden kurulumda görünür.
            work()
            needsReload = true
        } else {
            // Canlı etki: örtü altında çalışsın ki örtü kalkarken ekran değişmiş olsun.
            pendingWork = work
        }
    }

    /// Popup kapandı: bekleyen değişiklik varsa "Hazırlanıyor" örtüsü altında uygulanır.
    func sheetClosed() {
        guard needsReload || pendingWork != nil else { return }
        prepare()
    }

    private func prepare() {
        task?.cancel()
        task = Task { @MainActor in
            isPreparing = true
            try? await Task.sleep(nanoseconds: prepareDuration)
            if Task.isCancelled { isPreparing = false; return }

            pendingWork?()
            pendingWork = nil
            if needsReload {
                reloadToken = UUID()      // modül sıfırdan kurulur
                needsReload = false
            }
            isPreparing = false
        }
    }
}

// MARK: - Senaryo popup'ı

/// Senaryo gruplarını popup olarak gösterir; modül ekranı tam ekran kalır.
struct ShowcaseScenarioSheet: View {

    let groups: [ShowcaseScenarioGroup]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    /// Toggle'lar `IdentifyManager` üzerindeki değerleri okuduğu için yeniden çizim
    /// elle tetiklenir.
    @State private var revision = 0

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: IDSpacing.lg) {
                    Text("Bayraklar oturum açılışında backend'den gelir; aksiyonlar görüşme sırasında socket'ten. Buradan gönderilen aksiyon SDK için sunucudan gelenle aynıdır.")
                        .font(.system(size: 11))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))

                    ForEach(groups) { group in
                        groupBlock(group)
                    }
                }
                .padding(IDSpacing.lg)
                .id(revision)
            }
            .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Senaryo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .font(IDFont.caption(.semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
        .onDisappear { ShowcaseScenarioState.shared.sheetClosed() }
    }

    // MARK: Grup bloğu

    private func groupBlock(_ group: ShowcaseScenarioGroup) -> some View {
        VStack(alignment: .leading, spacing: IDSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(IDFont.bodyRegular(.semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                Text(group.note)
                    .font(.system(size: 10))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Alt maddeler: sol kenarda dikey çizgiyle girintili.
            HStack(alignment: .top, spacing: IDSpacing.sm) {
                Rectangle()
                    .fill(IDColor.adaptiveBorder(for: colorScheme))
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: IDSpacing.sm) {
                    ForEach(Array(group.controls.enumerated()), id: \.element.id) { index, control in
                        row(control, bullet: group.isOrdered ? "\(index + 1)." : "•")
                    }
                }
            }
            .padding(.leading, 2)
        }
        .padding(IDSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IDRadius.md)
                .fill(IDColor.adaptiveSurface(for: colorScheme))
        )
    }

    // MARK: Satır

    @ViewBuilder
    private func row(_ control: ShowcaseControl, bullet: String) -> some View {
        switch control {

        case .flag(let title, let note, let get, let set):
            HStack(alignment: .top, spacing: 6) {
                Text(bullet)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(isOn: Binding(get: get, set: { newValue in
                        set(newValue)
                        ShowcaseScenarioState.shared.flagChanged()
                        revision += 1
                    })) {
                        Text(title).font(IDFont.caption(.medium))
                    }
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case .action(let title, let note, let reloads, let run):
            Button {
                // İş örtü açıldıktan sonra uygulanır; örtü kalkarken ekran değişmiş olur.
                ShowcaseScenarioState.shared.actionTapped(reloads: reloads, work: run)
                revision += 1
                // Aksiyonun sonucu ekranda görülecek: popup kapanır.
                dismiss()
            } label: {
                HStack(alignment: .top, spacing: 6) {
                    Text(bullet)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(IDFont.caption(.medium))
                        Text(note)
                            .font(.system(size: 10))
                            .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .padding(.top, 3)
                }
                .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                .multilineTextAlignment(.leading)
            }
        }
    }
}

// MARK: - Cooldown örtüsü

/// Senaryo değişikliğinden sonra "Senaryo uygulanıyor 3…1" örtüsünü gösterir ve geri sayım
/// bitince içeriği sıfırdan kurar.
private struct ShowcaseCooldownModifier: ViewModifier {

    @ObservedObject private var state = ShowcaseScenarioState.shared

    func body(content: Content) -> some View {
        content
            // Token değişince SwiftUI modülü yeni bayraklarla sıfırdan kurar.
            .id(state.reloadToken)
            .overlay {
                if state.isPreparing {
                    ZStack {
                        Color.black.opacity(0.72)
                        VStack(spacing: IDSpacing.md) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.3)
                            Text("Hazırlanıyor")
                                .font(IDFont.bodyLarge(.semibold))
                                .foregroundColor(.white)
                            Text("Senaryo uygulanıyor, ekran yeni hâliyle açılacak")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, IDSpacing.xl)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: state.isPreparing)
    }
}

extension View {
    /// Senaryo geri sayımını ve yeniden kurulumu bu görünüme uygular.
    func showcaseScenarioCooldown() -> some View {
        modifier(ShowcaseCooldownModifier())
    }
}

// MARK: - Yüzen tetik

/// Modül ekranının üstüne küçük bir yüzen buton koyar; basınca senaryo popup'ı açılır.
private struct ShowcaseScenarioOverlay: ViewModifier {

    let groups: [ShowcaseScenarioGroup]
    @State private var showsSheet = false

    private var controlCount: Int { groups.reduce(0) { $0 + $1.controls.count } }

    func body(content: Content) -> some View {
        content
            .showcaseScenarioCooldown()
            .overlay(alignment: .topTrailing) {
                Button {
                    showsSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(controlCount)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.55), in: Capsule())
                }
                .padding(.top, 10)
                .padding(.trailing, 12)
                .accessibilityLabel("Senaryo ayarları")
            }
            .sheet(isPresented: $showsSheet) {
                ShowcaseScenarioSheet(groups: groups)
            }
    }
}

extension View {
    /// Ekranı tam ekran bırakarak senaryo popup'ını ekler.
    func showcaseScenarios(_ groups: [ShowcaseScenarioGroup]) -> some View {
        modifier(ShowcaseScenarioOverlay(groups: groups))
    }
}

// MARK: - Socket sürücüsü

/// Socket aksiyonlarını ekrandaki SDK ViewModel'ine iletir.
///
/// `IdentifyManager.shared.socketMessageListener` ekrandaki ViewModel'dir (modül kendini
/// açılışta dinleyici olarak atar). Gerçek socket de mesajları buraya yazar; panelin
/// gönderdiği aksiyon ile sunucunun gönderdiği aksiyon arasında SDK açısından fark yoktur.
@MainActor
enum ShowcaseSocketDriver {

    static func send(_ action: SDKCallActions) {
        IdentifyManager.shared.sdkSocketActions = action
        IdentifyManager.shared.socketMessageListener?.listenSocketMessage(message: action)
    }

    /// Ekrandaki görüşme ViewModel'i (dinleyici olarak kendini atar).
    static var callViewModel: SDKCallScreenViewModel? {
        IdentifyManager.shared.socketMessageListener as? SDKCallScreenViewModel
    }

    /// Kopma ekranını kapatır ve SDK'nın "zaten gösteriliyor" bayrağını temizler.
    ///
    /// Senaryo listesinde kopma tetiği yok; bu yalnız emniyet kemeridir — SDK başka bir
    /// nedenle (gerçek ağ kesintisi) kopma ekranını açtıysa modülden çıkışta temizlenir.
    static func recoverConnection() {
        callViewModel?.showLostConnection = false
        IdentifyManager.shared.isAlreadyShowingReConnectScreen = false
    }
}

// MARK: - Modül senaryoları

/// Her modülün senaryo grupları. `ShowcaseDetailView` modül id'siyle buradan okur; liste
/// boşsa o modülde senaryo butonu gösterilmez. Birbirine bağlı kontroller aynı grubun alt
/// maddeleridir.
///
/// Yalnız **public** SDK yüzeyi kullanılır: `IdentifyManager` üzerindeki oturum bayrakları
/// ve `socketMessageListener`. Modülün kendi ViewModel'indeki (ör. canlılık adım izinleri)
/// değerler showcase'ten erişilemez — onları sunucu belirler.
@MainActor
enum ShowcaseScenarios {

    static func groups(for id: String) -> [ShowcaseScenarioGroup] {
        let m = IdentifyManager.shared

        switch id {

        // MARK: Görüntülü görüşme
        case "callScreen":
            return [
                .init(title: "Oturum bayrakları",
                      note: "Backend oturum açılışında döndürür; değişince ekran yeniden kurulur.",
                      controls: [
                        .flag(title: "hide_call_answer_screen",
                              note: "Açıkken çalma ekranı gösterilmez, çağrı anında yanıtlanır.",
                              get: { m.hideCallAnswerScreen }, set: { m.hideCallAnswerScreen = $0 }),
                        .flag(title: "bigCustomerCam",
                              note: "Görüşmede müşteri kamerası büyük, temsilci küçük kutuda.",
                              get: { m.showBigCustomerCam }, set: { m.showBigCustomerCam = $0 }),
                        .flag(title: "signLangSupport",
                              note: "Açıkken görüşme ekranı açılışında TAM EKRAN işaret dili tercihi sunulur; \"Devam\" ile kapanıp görüşmeye dönülür. Gerçek akıştaki davranış budur.",
                              get: { m.connectToSignLang }, set: { m.connectToSignLang = $0 })
                      ]),

                .init(title: "Gelen çağrı zili",
                      note: "Yalnız çalma ekranında devreye girer.",
                      controls: [
                        .flag(title: "Zil sesi",
                              note: "Sistem zil sesi; sessiz modda iOS kısıtı gereği çalmaz.",
                              get: { m.incomingCallRingtoneEnabled }, set: { m.incomingCallRingtoneEnabled = $0 }),
                        .flag(title: "Zil titreşimi",
                              note: "CoreHaptics ile sessiz modda da hissedilir. iPad'de Taptic Engine yoktur.",
                              get: { m.incomingCallVibrationEnabled }, set: { m.incomingCallVibrationEnabled = $0 })
                      ]),

                .init(title: "Bekleme → görüşme akışı",
                      note: "Sırayla uygulayın; her adım socket'ten gelen aksiyonun aynısıdır.",
                      controls: [
                        .action(title: ".updateQueue — sırada 2. kişi",
                                note: "Bekleme ekranındaki sıra ve tahmini süre güncellenir.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.updateQueue("2", "4")) }),
                        .action(title: ".incomingCall — çağrı çalıyor",
                                note: "Çalma ekranı açılır; zil ayarları burada devreye girer.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.incomingCall) }),
                        .action(title: ".startTransfer — görüşme bağlandı",
                                note: "Kameralı görüşme ekranına geçer. Backend olmadığı için \"Yanıtla\" butonu gerçek çağrı kuramaz; geçişi bu adım yapar.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.startTransfer) }),
                        .action(title: ".comingSms — SMS doğrulama",
                                note: "6 haneli kod ekranı açılır.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.comingSms) })
                      ],
                      isOrdered: true),

                .init(title: "Görüşme içi bildirimler",
                      note: "Görüşme bağlandıktan sonra anlamlıdır.",
                      controls: [
                        .action(title: ".networkQuality(\"poor\") — hat zayıf",
                                note: "Bağlantı kalitesi göstergesi uyarıya geçer.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.networkQuality("poor")) }),
                        .action(title: ".networkQuality(\"good\") — hat iyi",
                                note: "Göstergeyi normale döndürür.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.networkQuality("good")) }),
                        .action(title: ".photoTaken — temsilci kare aldı",
                                note: "Ekranda kısa bildirim çıkar.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.photoTaken("Temsilci bir kare aldı")) }),
                        .action(title: ".disableEndCallButton",
                                note: "Görüşmeyi sonlandır butonu pasifleşir.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.disableEndCallButton) })
                      ]),

                .init(title: "Bitiş",
                      note: "Görüşmenin karar verilmeden kapandığı durum.",
                      controls: [
                        .action(title: ".endCall — temsilci düştü",
                                note: "Görüşme biter, oturum sonucu beklenmez.",
                                reloads: false,
                                run: { ShowcaseSocketDriver.send(.endCall) })
                      ])

                // Listede OLMAYAN socket aksiyonları ve nedenleri:
                //   • `.missedCall` / `.imOffline` — ayrı bir ekranı yok, yalnız bekleme
                //     durumuna döner; zaten bekleme ekranındayken görünür bir değişiklik
                //     olmaz. Cevapsız çağrının SONUCU "Teşekkür / Sonuç" kartında
                //     "Cevapsız" varyantıdır.
                //   • `.approveSms(_)` — görüşme ViewModel'inde karşılığı yok (no-op).
                //   • `.openCardCircle` / `.closeCardCircle` / `.openWarningCircle` /
                //     `.closeWarningCircle` — SDK bunları `IdentifyListenerDelegate`'e
                //     iletiyor (host kendi çerçevesini çizsin diye); v3'ün HAZIR görüşme
                //     ekranında karşılığı yok, bu yüzden burada bir şey göstermezler.
                //   • `.terminateCall(_, _)` — karar taşımayan sebep/statü `enterReconnect`
                //     ile uygulamanın kendi bağlantı koptu ekranını tam ekran açıyor ve
                //     showcase kilitleniyor; karar taşıyan hâli SDK'yı kapatıp ThankYou'ya
                //     yönlendiriyor, showcase akış yönlendiricisi barındırmadığı için ekranda
                //     bir şey görünmüyor. Sonuç ekranları "Teşekkür / Sonuç" kartındadır.
                //   • `.connectionErr` — yeniden bağlanma ekranını tam ekran açıyor, tek
                //     çıkışı gerçek oturum isteyen "Yeniden Bağlan" butonu. Tasarımı
                //     "Bağlantı Koptu" kartından görülebilir.
            ]

        // MARK: Hazırlık
        case "prepare":
            return [
                .init(title: "Bağlantı hızı testi",
                      note: "Görüşme öncesi ölçüm adımı.",
                      controls: [
                        .flag(title: "needSpeedTest",
                              note: "Açıkken hazırlık ekranı hız testi çalıştırır; backend olmadan ölçüm tamamlanmaz.",
                              get: { m.needSpeedTest ?? false }, set: { m.needSpeedTest = $0 })
                      ])
            ]

        // MARK: Kimlik (OCR)
        case "idCard":
            return [
                .init(title: "Ekran modu",
                      note: "Kimlik modülünün hangi ekranla açılacağı; değişince ekran yeniden kurulur.",
                      controls: [
                        .flag(title: "Tek ekran tarama",
                              note: "Açıkken ön + arka yüz tek tam ekranda sırayla çekilir (IdCardSingleScreenCustomView). Oturum yoksa her çekim dummy onayla geçer; ret olursa 2 sn sonra aynı yüz tekrar çekilir.",
                              get: { CustomScreens.isIdCardSingleScreenEnabled },
                              set: { UserDefaults.standard.set($0, forKey: CustomScreens.idCardSingleScreenKey) })
                      ]),

                .init(title: "İzin verilen belge türleri",
                      note: "Seçim ekranındaki seçenekleri backend belirler.",
                      controls: [
                        .action(title: "Kimlik + pasaport + eski tip",
                                note: "Üç seçenek birlikte görünür.",
                                run: { m.allowedCardType = [.idCard, .passport, .oldSchool] }),
                        .action(title: "Yalnız kimlik",
                                note: "Tek seçenek kalır.",
                                run: { m.allowedCardType = [.idCard]; m.selectedCardType = .idCard }),
                        .action(title: "Yalnız pasaport",
                                note: "Pasaport akışı: tek sayfa (MRZ'li yüz).",
                                run: { m.allowedCardType = [.passport]; m.selectedCardType = .passport })
                      ]),

                .init(title: "OCR deneme hakkı",
                      note: "Hak bitince modülün uyarı ve çıkış davranışı değişir.",
                      controls: [
                        .action(title: "5 hak (normal)",
                                note: "Olağan durum.",
                                run: { m.ocrComparisonCount = 5 }),
                        .action(title: "0 hak (tükendi)",
                                note: "Hak tükenmiş senaryosu.",
                                run: { m.ocrComparisonCount = 0 })
                      ])
            ]

        // MARK: Kimlik OVD (hologram)
        case "idCardOVD":
            return [
                .init(title: "Belge türü",
                      note: "Adım sayısını belirler.",
                      controls: [
                        .action(title: "Kimlik — 3 adım",
                                note: "Ön yüz → hologram → arka yüz.",
                                run: { m.selectedCardType = .idCard }),
                        .action(title: "Pasaport — 2 adım",
                                note: "Ön yüz → hologram; arka yüz adımı yoktur.",
                                run: { m.selectedCardType = .passport })
                      ])
            ]

        // MARK: NFC
        case "nfc":
            return [
                .init(title: "MRZ ön-doldurma",
                      note: "Çip okuma anahtarı bu üç alandan üretilir.",
                      controls: [
                        .flag(title: "useKpsData",
                              note: "Açıkken alanlar hazır gelir, kullanıcı elle girmez.",
                              get: { m.useKpsData }, set: { m.useKpsData = $0 }),
                        .action(title: "Alanları doldur",
                                note: "Örnek veri: seri no A12B34567, doğum 900101, geçerlilik 300101.",
                                run: { m.mrzDocNo = "A12B34567"; m.mrzBirthDay = "900101"; m.mrzValidDate = "300101" }),
                        .action(title: "Alanları boşalt",
                                note: "Kullanıcının elle girdiği durum.",
                                run: { m.mrzDocNo = ""; m.mrzBirthDay = ""; m.mrzValidDate = "" })
                      ]),

                .init(title: "Çip doğrulaması",
                      note: "ICAO güvenlik adımları.",
                      controls: [
                        .flag(title: "performChipAuthentication",
                              note: "Chip Authentication (DG14) denenir; çipte yoksa atlanır.",
                              get: { m.performChipAuthentication }, set: { m.performChipAuthentication = $0 })
                      ]),

                .init(title: "NFC deneme hakkı",
                      note: "Hak bitince modül akıştan çıkar.",
                      controls: [
                        .action(title: "5 hak (normal)",
                                note: "Olağan durum.",
                                run: { m.nfcComparisonCount = 5 }),
                        .action(title: "0 hak (tükendi)",
                                note: "Hak tükenmiş senaryosu.",
                                run: { m.nfcComparisonCount = 0 })
                      ])
            ]

        // MARK: Selfie
        case "selfie":
            return [
                .init(title: "Doğrulama rolü",
                      note: "Selfie'nin kimlik fotoğrafıyla karşılaştırılıp karşılaştırılmadığı.",
                      controls: [
                        .flag(title: "isSelfieIdent",
                              note: "Açıkken selfie bir doğrulama adımı sayılır.",
                              get: { m.isSelfieIdent }, set: { m.isSelfieIdent = $0 })
                      ]),

                .init(title: "Karşılaştırma hakkı",
                      note: "Hak bitince modülün davranışı değişir.",
                      controls: [
                        .action(title: "5 hak (normal)",
                                note: "Olağan durum.",
                                run: { m.selfieComparisonCount = 5 }),
                        .action(title: "0 hak (tükendi)",
                                note: "Hak tükenmiş senaryosu.",
                                run: { m.selfieComparisonCount = 0 })
                      ])
            ]

        // MARK: Canlılık
        case "liveness":
            return [
                .init(title: "Kayıt ve rapor",
                      note: "Backend oturum açılışında ikisini ayrı ayrı açar.",
                      controls: [
                        .flag(title: "liveness_recording",
                              note: "Adımlar boyunca ekran kaydı (ReplayKit) alınır ve sonunda yüklenir.",
                              get: { m.livenessRecordingEnabled }, set: { m.livenessRecordingEnabled = $0 }),
                        .flag(title: "liveness_report",
                              note: "Sunucuya ek canlılık raporu gönderilir.",
                              get: { m.livenessReportEnabled }, set: { m.livenessReportEnabled = $0 })
                      ])

                // Adım seti (göz kırpma, gülümseme, baş çevirme…) modülün kendi
                // ViewModel'indeki `allow*` alanlarından gelir ve sunucunun gönderdiği
                // `RoomResponse.liveness` dizisiyle kurulur; showcase o örneğe erişemez.
            ]

        // MARK: Canlılıkla selfie
        case "selfieWithLiveness":
            return [
                .init(title: "Doğrulama rolü",
                      note: "Birleşik ekranın doğrulama adımı sayılıp sayılmadığı.",
                      controls: [
                        .flag(title: "isSelfieIdent",
                              note: "Açıkken selfie bir doğrulama adımı sayılır.",
                              get: { m.isSelfieIdent }, set: { m.isSelfieIdent = $0 })
                      ]),

                .init(title: "Karşılaştırma hakkı",
                      note: "Hak bitince modülün davranışı değişir.",
                      controls: [
                        .action(title: "5 hak (normal)",
                                note: "Olağan durum.",
                                run: { m.selfieComparisonCount = 5 }),
                        .action(title: "0 hak (tükendi)",
                                note: "Hak tükenmiş senaryosu.",
                                run: { m.selfieComparisonCount = 0 })
                      ])
            ]

        // MARK: Video kayıt
        case "videoRecorder":
            return [
                .init(title: "Sesli okuma doğrulaması",
                      note: "Açıkken kullanıcı ekrandaki cümleyi okur, konuşma sunucuda doğrulanır.",
                      controls: [
                        .flag(title: "video_record_speech",
                              note: "Doğrulamayı açar; kapalıyken yalnız video kaydedilir.",
                              get: { m.videoRecordSpeechEnabled }, set: { m.videoRecordSpeechEnabled = $0 }),
                        .action(title: "Metin: kısa",
                                note: "Tek satırlık cümle.",
                                run: { m.videoRecordReadText = "Kimliğimi onaylıyorum" }),
                        .action(title: "Metin: uzun",
                                note: "Metin alanının kaydırmalı hâli.",
                                run: { m.videoRecordReadText = "Kendi rızamla, uzaktan kimlik tespiti yapılmasını kabul ediyorum ve verdiğim bilgilerin doğru olduğunu beyan ediyorum." })
                      ]),

                .init(title: "Kayıt süresi",
                      note: "Sunucudan milisaniye olarak gelir.",
                      controls: [
                        .action(title: "5 saniye",
                                note: "Kısa kayıt penceresi.",
                                run: { m.videoRecordDurationSeconds = 5 }),
                        .action(title: "15 saniye",
                                note: "Uzun kayıt penceresi.",
                                run: { m.videoRecordDurationSeconds = 15 })
                      ])
            ]

        // MARK: Konuşma tanıma
        case "speech":
            return [
                .init(title: "Okunacak cümle",
                      note: "Sunucu `speech_expected_sentence` ile gönderir.",
                      controls: [
                        .action(title: "Kısa cümle",
                                note: "Tek satır.",
                                run: { m.speechExpectedSentence = "Bugün hava çok güzel" }),
                        .action(title: "Uzun cümle",
                                note: "Çok satırlı yerleşim.",
                                run: { m.speechExpectedSentence = "Bugün hava çok güzel ve kimliğimi kendi rızamla onaylıyorum, verdiğim bilgiler doğrudur" }),
                        .action(title: "Boş cümle",
                                note: "Sunucu cümle göndermediğinde ekranın davranışı.",
                                run: { m.speechExpectedSentence = "" })
                      ])
            ]

        // MARK: İşaret dili
        case "signLang":
            return [
                .init(title: "Tercih ekranı",
                      note: "Gerçek akışta bu ekran görüşme başında tam ekran sunulur.",
                      controls: [
                        .flag(title: "signLangSupport",
                              note: "Sunucu işaret dili desteği istediğinde açıktır; kullanıcının seçimi \"Devam\" ile kaydedilir.",
                              get: { m.connectToSignLang }, set: { m.connectToSignLang = $0 })
                      ])
            ]

        default:
            return []
        }
    }
}

// MARK: - Görüntülü görüşme sarmalayıcısı

/// Görüşme modülü. Senaryo kalıntısını (kopma ekranı) çıkışta temizler.
struct CallScreenShowcaseView: View {

    var body: some View {
        SDKCallScreenView()
            .onDisappear { ShowcaseSocketDriver.recoverConnection() }
    }
}
