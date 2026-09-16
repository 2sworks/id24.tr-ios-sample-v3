# Modül Rehberleri — Buradan Başlayın

IdentifySDK'daki her doğrulama adımı bir **modüldür**: kimlik tarama, NFC, selfie, görüntülü
görüşme... Her modülün bu klasörde kendi rehberi vardır. Bu sayfa, hepsinde ortak olan şeyleri
bir kez anlatır: kurulum, akışın nasıl ilerlediği, ekranları özelleştirme yolları ve tek
altın kural.

> SDK, ikili (binary) XCFramework olarak dağıtılır. Modül ekranları **drop-in**'dir: hiçbir şey
> yazmadan hazır akış çalışır; istediğiniz ekranı kendi tasarımınızla değiştirirsiniz.
> **İç mantık (OCR, soket, WebRTC, yükleme) her zaman SDK'da kalır** — siz yalnızca UI'a dokunursunuz.

Daha geniş bağlam için: [Mimari](../../docs/guides/architecture.md) ·
[Sunucu & API](../../docs/guides/server-api.md) · [Özelleştirme](../../docs/guides/customization.md)

---

## Modül Kataloğu

| Modül | Ne yapar | Backend key | Rota | Rehber |
|---|---|---|---|---|
| 🎬 Hazırlık | İzinler + hız testi, kullanıcıyı akışa hazırlar | `.prepare` | `.prepare` | [Prepare.md](Prepare/Prepare.md) |
| 🪪 Kimlik (OCR) | Kimlik ön/arka yüz çekimi + cihazda okuma | `.idCard` | `.idCard` | [IdCard.md](IdCard/IdCard.md) |
| ✨ Kimlik (OVD) | Hologram/optik doğrulamayla sahtecilik kontrolü | `.idcard_w_ovd` | `.idCardOVD` | [IdCardOVD.md](IdCardOVD/IdCardOVD.md) |
| 📡 NFC | Kimlik/pasaport çipini okur | `.nfc` | `.nfc` | [NFC.md](NFC/NFC.md) |
| 🤳 Selfie | Selfie + cihazda yüz tespiti | `.selfie` | `.selfie` | [Selfie.md](Selfie/Selfie.md) |
| 🫦 Selfie + Canlılık | İkisini tek adımda birleştirir | `.selfieWithLiveness` | `.selfieWithLiveness` | [SelfieWithLiveness.md](SelfieWithLiveness/SelfieWithLiveness.md) |
| 👁 Canlılık | Sola dön / göz kırp / gülümse testleri | `.livenessDetection` | `.liveness` | [Liveness.md](Liveness/Liveness.md) |
| 🗣 Konuşma | Metni sesli okutup doğrular | `.speech` | `.speech` | [Speech.md](Speech/Speech.md) |
| ✍️ İmza | Ekranda imza alır | `.signature` | `.signature` | [Signature.md](Signature/Signature.md) |
| 🎥 Video Kayıt | Kısa video kaydı (isteğe bağlı sesli okuma doğrulamalı) | `.videoRecord` | `.videoRecorder` | [VideoRecorder.md](VideoRecorder/VideoRecorder.md) |
| 🏠 Adres Onayı | Adres belgesi foto/PDF yükler | `.addressConf` | `.addressConfirm` | [AddressConfirm.md](AddressConfirm/AddressConfirm.md) |
| 📞 Görüntülü Görüşme | Agent ile canlı WebRTC görüşmesi | `.waitScreen` | `.callScreen` | [CallScreen.md](CallScreen/CallScreen.md) |
| 🙏 Teşekkür | Akış sonucu (terminal ekran) | `.thankU` | `.thankYou(_)` | [ThankYou.md](ThankYou/ThankYou.md) |
| 🤟 İşaret Dili | Görüşme öncesi tercih kapısı (CallScreen alt-ekranı) | — | — | [SignLang.md](SignLang/SignLang.md) |
| 📵 Bağlantı Koptu | Kopma overlay'i + toparlanma (modül değil, katman) | — | — | [LostConnection.md](LostConnection/LostConnection.md) |

Modül sırasına backend karar verir (`RoomResponse.modules`) — uygulamanız hangi modüller
gelirse gelsin çalışacak şekilde kurulur.

---

## Kurulum — Bir Kez Yapılır

İki adım vardır ve **sıra kritiktir**:

```swift
// 1) Kök view — SDKFlowHostView her şeyi çizer
struct RootView: View {
    @StateObject private var coordinator = SDKFlowCoordinator()
    @State private var registry = SDKViewRegistry()

    var body: some View {
        SDKFlowHostView(coordinator: coordinator, registry: registry) {
            LoginView().environmentObject(coordinator)   // sizin giriş ekranınız
        }
    }
}

// 2) Bağlanma — prepareForSetup HER ZAMAN setupSDK'dan önce
func connect(coordinator: SDKFlowCoordinator) {
    coordinator.prepareForSetup()                        // ⚠️ önce bu

    IdentifyManager.shared.setupSDK(
        identId: "...",
        baseApiUrl: "https://v2api.identify.com.tr/",
        networkOptions: SDKNetworkOptions(useSslPinning: false),
        kpsData: nil,
        signLangSupport: false,
        nfcMaxErrorCount: 3,
        selectedModules: [],                             // boş = backend'in sırası
        turnKey: "...",
        wsSecretKey: "...",
        showThankYouPage: true
    ) { socket, roomResponse, error in
        Task { @MainActor in
            if error == nil, socket?.isConnected == true, roomResponse.result == true {
                coordinator.start()                      // ilk modüle geç
            }
        }
    }
}
```

`prepareForSetup()` atlanırsa SDK modül dizisini farklı instance'larla kurar ve **hiçbir modül
başlamaz** — en sık yapılan kurulum hatası budur.

Tüm `setupSDK` parametreleri için: [Sunucu & API rehberi](../../docs/guides/server-api.md#setupsdk--tam-parametre-referansı).

---

## Her Modülde Aynı Üçlü

| Dosya | Kimin | Görev |
|---|---|---|
| `SDKXxxView.swift` | SDK | Drop-in SwiftUI ekranı — hiçbir şey yazmazsanız bu çalışır |
| `SDKXxxViewModel.swift` | SDK | İş mantığı + state (`public final`, `SDKBaseModuleViewModel` tabanlı) |
| `XxxCustomView.swift` | Sample App (örnek) | SDK ekranının public API ile yazılmış **birebir, çalışan** kopyası — override'a takılıp değiştirilmek için |
| `XxxHostViewModel.swift` | Sample App (örnek) | SDK VM'ini saran host VM — gözlem/analitik deseni |

Her VM'de hazır olanlar: `isLoading`, `errorMessage` (`@Published`) ve `manager`
(`IdentifyManager.shared`) erişimi.

---

## Ekranları Özelleştirme — Üç Yöntem

> **Nereden başlamalı?** Her modülün klasöründe `XxxCustomView.swift` vardır: SDK ekranının
> yalnızca public API ile yazılmış, gerçekten çalışan kopyası (kamera, ARKit, WebRTC görünümü
> dahil). Dosyayı projenize kopyalayıp `registry.override` ile takın — SDK'daki ekranın aynısını
> görürsünüz; özelleştirme bu dosya üzerinde yapılır. Tüm modüllerin kaydı:
> [CustomKit/CustomScreens.swift](CustomKit/CustomScreens.swift). Örnek uygulamada hamburger
> menü → **Özel Ekranlar** anahtarı hepsini birden açar.
>
> `XxxExample.swift` dosyaları üç biçimi yan yana gösterir: (1) hazır SDK ekranı, (2) tema
> override, (3) `XxxCustomView` önizlemesi. Kök kurulum ve entegrasyon adımları için
> [App/RootView.swift](../App/RootView.swift) başındaki rehberi okuyun.
>
> **Selfie + Canlılık** için `SDKSelfieWithLivenessViewModel` ve `SelfieWithLivenessCustomView`
> SDK 3.1.0 ile birlikte gelir.

```swift
// A) Ekranı kendi tasarımınla değiştir (başlangıç noktası: SelfieCustomView.swift)
registry.override(.selfie) { SelfieCustomView() }

// B) Araya kendi ekranını sok (pasif: tanıtım, sözleşme, başarı...)
registry.custom("welcome") { MyIntroView() }
coordinator.insert(["welcome"], before: .selfie)
// custom ekranın devam butonu → coordinator.advanceExternal()

// C) SDK VM'ini sar (gözlem/log/analitik) — ekran SDK'nın kalır
final class SelfieHostViewModel: HostModuleViewModel { let sdk = SDKSelfieViewModel() ... }
```

Derinlemesine anlatım + kontrol listesi: [Özelleştirme rehberi](../../docs/guides/customization.md).

---

## ⚠️ Altın Kural: Bypass Yok

Custom ekranınız her iş eylemini — **tara / yükle / ilerle** — SDK VM metoduna indirmelidir.
VM metotları işin yanında backend'e ilerleme sinyali gönderir (`sendStep`, `modulePresented`);
kendi HTTP isteğinizi atar veya kendi navigasyonunuzu kurarsanız **sunucu akışı ilerlemez.**

| ✅ Doğru | ❌ Bypass |
|---|---|
| `vm.scanFront(image:)` | Kendi OCR'ınız + kendi `POST`'unuz |
| `coordinator.advanceToNextModule()` | `path.append(...)` |
| `vm.uploadSignature(image:)` | Görseli kendiniz yüklemek |

Soket + WebRTC `IdentifyManager.shared`'da yaşar, ekranlardan izoledir. Araya **pasif** ekran
eklemek bağlantıyı etkilemez.

---

## Sesli Okuma (Read-Aloud) — Kesişen Özellik

Her modül ekranı açıldığında yönergesi otomatik seslendirilebilir; mod **modül bazında** seçilir:

```swift
SDKSpeechConfig.shared.setModeForAll(.native)                  // Siri/sistem sesi
SDKSpeechConfig.shared.setMode(.customAudio, for: [.selfie])   // kendi ses kaydınız
SDKSpeechConfig.shared.setMode(.off, for: .livenessDetection)  // kapalı
```

Seslendirmeyi `SDKFlowHostView` otomatik yapar; modül başına kod gerekmez. Her modülün
rehberinde kendi ses anahtarı yazar. Tam ayrıntı: [ReadAloud.md](ReadAloud.md).

> ⚠️ "Sesli okuma" (TTS) ile **Konuşma modülü** (`.speech`, konuşma **tanıma**) ayrı şeylerdir.

---

## Modüllerin Dış Bağımlılıkları

| Bağımlılık | Modüller |
|---|---|
| Yalnızca cihaz üzerinde (soket yok) | IdCard (OCR), IdCardOVD, Selfie, Liveness (kare analizi), Prepare (izinler) |
| HTTP upload | IdCard, IdCardOVD, NFC, Selfie, Liveness, Signature, VideoRecorder, AddressConfirm |
| Soket sinyali | Prepare (`sendPreparetatus`), SignLang (`sendStep`), Speech (`sendSpeechStatus`), CallScreen |
| WebRTC | CallScreen |

Pasif ekranlar (ThankYou + sizin eklediğiniz ekranlar) hiçbir sinyal göndermez; araya
eklenmeleri her zaman güvenlidir.

---

## Donanım Gereksinimleri ve Yedek Modüller

Sunucu akışı cihazdan bağımsız kurar; iki modül donanım ister ve cihaz desteklemiyorsa
akışa **hiç alınmaz** — kullanıcı geçemeyeceği bir ekranda kalmaz.

| Modül | Gereken donanım | Desteklemeyen cihazda |
|---|---|---|
| `nfc` | NFC okuyucu (iPad'de yok) | Modül çıkarılır; panele `NFCStatus = notAvailable` bildirilir. `showNFCNotFoundPage: true` ile bilgi sayfası gösterilebilir |
| `livenessDetection` | ARKit yüz takibi (TrueDepth kamera ya da A12+ çip) | `faceTrackingFallback` uygulanır |
| `selfieWithLiveness` | Moda bağlı: `selfieWithLivenessTrueDepth` (`.automatic` ARKit · `.required` TrueDepth · `.disabled` donanım istemez) | `faceTrackingFallback` uygulanır — [TrueDepth modu](SelfieWithLiveness/SelfieWithLiveness.md#truedepth-modu) |

```swift
IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan: selfie ile doğrula
IdentifyManager.shared.faceTrackingFallback = .skip     // adımı tamamen çıkar
// setupSDK'dan ÖNCE — karar akış kurulurken uygulanır, son kullanıcıya sorulmaz
```

Her iki durumda da olay yayınlanır (`status == .skipped`) ve hangi modülün neyle
değiştirildiği `sdk_logs`'a yazılır. Ayrıntı ve cihaz matrisi:
[iPad Desteği](../../docs/guides/ipad-support.md).
