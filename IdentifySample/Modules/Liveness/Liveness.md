# Liveness — Canlılık Testi

"Karşımdaki gerçek ve canlı bir insan mı, yoksa bir fotoğraf/video mu?" sorusunu cevaplar.
Kullanıcıya sırayla hareket talimatları verilir — **göz kırp, gülümse, başını sola/sağa çevir,
başını öne/geriye eğ, kaşlarını kaldır, gözlerini sola/sağa/yukarı çevir** — ve her adım bir
doğrulama karesiyle kanıtlanır. Hangi adımların hangi sırayla isteneceğini sunucu belirler (her
oturumda farklı olabilir), böylece önceden kaydedilmiş videoyla aldatma zorlaşır.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.livenessDetection` |
| Rota | `SDKModuleRoute.liveness` |
| Drop-in view | `SDKLivenessView` |
| ViewModel | `SDKLivenessViewModel` |
| Dış dünya | Adım API'si (`getNextLivenessTest`) + **HTTP** (kare + isteğe bağlı video) |
| Ses anahtarı | `LivenessTts` |
| Donanım | **TrueDepth kamera (ARKit yüz takibi) zorunlu** — yoksa modül akışa hiç girmez |

## Kullanıcı Ne Yaşar?

1. Ön kamera açılır; ekranda ilk talimat belirir (ör. "Gözlerinizi kırpın").
2. Hareketi yapar; doğrulama karesi arka planda yüklenir, sıradaki talimat gelir.
3. Tüm adımlar bitince — sunucu ekran kaydı istiyorsa — oturum videosu da yüklenir.
4. Akış otomatik ilerler.

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKLivenessView` çizilir.

## Kendi Tasarımınızla (Override)

> **Önce okuyun:** İfade algılama (göz kırpma, gülümseme, baş/göz yönü) **VM'de değil,
> SDK'nın hazır ekranındadır.** Override ederseniz ARKit yüz takibini ve her adımın algılama
> kuralını **siz yazarsınız**. Yalnız görünümü değiştirmek istiyorsanız
> [tema](../../../docs/guides/theming.md) ve metin override'ı yeterlidir; önerilen yol budur.

| SDK'da kalan | Sizde kalan |
|---|---|
| Adım sırası (sunucudan), kare yükleme, sonraki adıma geçiş | ARKit oturumu (`ARFaceTrackingConfiguration`, A12+ cihaz) |
| Ekran kaydı (ReplayKit) ve bitince yükleme | `vm.currentStep` için ifadeyi algılamak |
| Uygulama arka plana geçince kaydın yönetimi | Algılanınca ekran görüntüsünü `uploadFrame` ile vermek |

Çağrı sırası:

```swift
registry.override(.liveness) { MyLivenessView() }

struct MyLivenessView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKLivenessViewModel()   // init ilk adımı zaten ister
    let face = MyARFaceTracker()

    var body: some View {
        ZStack {
            MyARView(tracker: face)
            Text(vm.stepInstruction)
        }
        .onAppear {
            vm.onCompleted     = { coordinator.advanceToNextModule() }   // ✅
            vm.onSkipRequested = { coordinator.skipCurrentModule() }
            vm.onFlowFailed    = { coordinator.finishFlowAsFailed() }
            vm.onRecordingReady = { face.start() }       // ✅ kamerayı kayıt hazır olunca aç
            vm.prepareRecording()                         // ✅ ekran kaydını başlatır
            face.onDetected = { step, snapshot in
                guard step == vm.currentStep else { return }
                face.pause()                              // yükleme sürerken ikinci tetik olmasın
                vm.uploadFrame(image: snapshot)           // ✅ başarıda sıradaki adım kendiliğinden gelir
            }
        }
        .onChange(of: vm.currentStep) { _ in if !vm.allStepsCompleted { face.resume() } }
        .onDisappear { face.stop(); vm.abandonRecording() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in vm.noteWillResignActive() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in vm.noteDidBecomeActive() }
    }
}
```

- Son adım yüklenince VM kaydı durdurup yükler ve `onCompleted`'ı çağırır; `uploadVideo` ya da
  `fetchNextStep` elle çağrılmaz.
- Cihaz yüz takibini desteklemiyorsa `vm.reportFaceTrackingUnsupported()` çağırın; modül
  entegrasyonun `faceTrackingFallback` politikasıyla atlanır.

SDK'nın kullandığı algılama kuralları (başlangıç için referans; eşikler cihazda ayarlandı):

| Adım | Kural |
|---|---|
| `turnLeft` / `turnRight` | `jawLeft` / `jawRight` > 0.12 |
| `blinkEyes` | `eyeBlinkLeft` ve `eyeBlinkRight` > 0.35, `jawLeft/Right` < 0.03 |
| `smile` | `mouthSmileLeft + mouthSmileRight` > 1.2, `jawLeft/Right` < 0.03 |
| `nodDown` `nodUp` `lookUp` `browUp` `eyesLeft` `eyesRight` | Adım başında nötr baş pozu ölçülür; açı/blendshape farkı belirli süre tutulmalı. Bu kurallar public değildir — bu adımlar sunucuda açıksa override önerilmez. |

> ❌ **Bypass yapmayın:** Adımları kendi mantığınızla "geçti" sayıp ilerlemeyin — her adım
> `uploadFrame` ile kanıtlanmalıdır.
> Kural: [bypass yok](../../../docs/guides/customization.md#bypass-yok-kuralı).

---

## ViewModel Referansı — `SDKLivenessViewModel`

### State (`@Published`, salt-okunur)
| Üye | Tip | Anlam |
|---|---|---|
| `currentStep` | `LivenessTestStep?` | Mevcut adım (`turnLeft/turnRight/blinkEyes/smile/nodDown/nodUp/lookUp/browUp/eyesLeft/eyesRight/completed`) |
| `stepInstruction` | `String` | Adım talimatı (ör. "Göz kırpın") |
| `allStepsCompleted` | `Bool` | Tüm adımlar bitti mi |

### Hesaplanan / ayar
| Üye | Anlam |
|---|---|
| `isRecordingEnabled: Bool` | Video kaydı açık mı (`manager.livenessRecordingEnabled` — sunucudan) |
| `maxVideoSize: Int` | İzinli en büyük video boyutu |
| `allowBlink / allowSmile / allowLeft / allowRight` | Hangi adımlar etkin (r/w) |

### Metotlar
| Metot | Etki |
|---|---|
| `prepareRecording()` | Ekran kaydını başlatır; hazır olunca `onRecordingReady` (kayıt kapalıysa hemen) |
| `uploadFrame(image: UIImage)` | Mevcut adımın karesini yükler; başarıda sıradaki adımı ister, son adımda kaydı yükleyip `onCompleted` |
| `abandonRecording()` | Ekrandan çıkışta kaydı bırakır |
| `noteWillResignActive()` / `noteDidBecomeActive()` | Uygulama aktiflik bildirimleri (kesilen kayıt yönetimi) |
| `reportFaceTrackingUnsupported()` | Cihaz ARKit yüz takibini desteklemiyor — modül atlanır |
| `fetchNextStep()` | Sıradaki adımı sunucudan alır; `init` ve `uploadFrame` zaten çağırır |
| `finishRecordingAndUpload()` / `uploadVideo(videoData:)` | İç akış; son adımda VM kendisi çağırır |
| `resetTest()` | Testi başa alır |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onCompleted: (() -> Void)?` | Tüm akış (adımlar + varsa video) tamamlandı |
| `onRecordingReady: (() -> Void)?` | Ekran kaydı başladı — kamerayı şimdi açın |
| `onSkipRequested: (() -> Void)?` | Atlama istendi |
| `onFlowFailed: (() -> Void)?` | Akış başarısız sonlandı |

## Sinyal Zinciri — Perde Arkası

```
fetchNextStep()          → manager.getNextLivenessTest  → currentStep / stepInstruction
uploadFrame(image:)      → manager.uploadIdPhoto [HTTP]  (her adım doğrulaması)
(adımlar bitti) → uploadVideo(videoData:)
     ├─ kayıt açık   → manager.uploadLivenessVideo [HTTP] → onCompleted?()
     └─ kayıt kapalı → onCompleted?()   (doğrudan)
host: → coordinator.advanceToNextModule() [modulePresented]
```

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class LivenessHostViewModel: HostModuleViewModel {
    let sdk = SDKLivenessViewModel()
    override init() {
        super.init(); bridge(sdk)
        sdk.onCompleted = { [weak self] in self?.log("liveness_done") }
    }
    var instruction: String { sdk.stepInstruction }
    func next() { sdk.fetchNextStep() }
    func sendFrame(_ img: UIImage) { sdk.uploadFrame(image: img) }
}
```

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .livenessDetection)        // Siri/sistem sesi
// veya kendi kaydınız: bundle'a LivenessTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .livenessDetection)   // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .livenessTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Video kaydı zorunlu mu?** Sunucu belirler (`liveness_recording`). `isRecordingEnabled`
  `false` ise `uploadVideo` boş `Data` ile çağrılabilir; VM yine `onCompleted`'a düşer.
- **Adım seti:** `allowBlink/allowSmile/allowLeft/allowRight` ile hangi hareketlerin
  isteneceğini host daraltabilir.
- **Adım sırası neden rastgele?** `RoomResponse.liveness` dizisi sırayı belirler —
  replay saldırılarını zorlaştırmak için oturum başına değişebilir.
- **Cihaz desteklemiyorsa ne olur?** Göz kırpma/gülümseme ARKit blend shape'lerinden, baş
  açısı yüz dönüşümünden okunur; bu yüzden modül **ARKit yüz takibi ister** (TrueDepth kamera
  ya da A12+ çip). TrueDepth'siz A11 ve öncesi cihazlarda (iPhone 8, iPad 7…) çalışamaz; model
  listesi: [Cihaz modelleri](../SelfieWithLiveness/SelfieWithLiveness.md#cihaz-modelleri). Kontrol akış kurulurken yapılır
  (`ARFaceTrackingConfiguration.isSupported`) ve modül akışa alınmaz — kullanıcı
  geçemeyeceği bir ekranda kalmaz. Yerine ne geleceğini siz seçersiniz:

  ```swift
  IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan: selfie ile doğrula
  IdentifyManager.shared.faceTrackingFallback = .skip     // adımı tamamen çıkar
  ```

  Akışta zaten selfie varsa `.selfie` yeni adım eklemez, canlılık adımını yalnızca çıkarır.
  Olay: `status == .skipped`, modül `Liveness Detection`.
  Ayrıntı: [iPad Desteği](../../../docs/guides/ipad-support.md).
- **Adım geçince titreşim:** her onaylanan adımda tek ve çok kısa bir darbe çalınır.
  `SDKHapticConfig.shared.stepFeedbackEnabled = false` ile kapatılır,
  `stepFeedbackIntensity` (0…1, vars. 0.6) ile şiddeti ayarlanır.
- **iPad:** Face ID'li iPad Pro'da derinlikli, A12+ Touch ID'li iPad'lerde (iPad 8+, mini 5+, Air 3+) derinliksiz çalışır. Yüz ovali tablette pencereyle
  birlikte büyümez; `SDKLayout.maxFaceGuideWidth` ile sınırlanır.
