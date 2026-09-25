# SelfieWithLiveness — Selfie + Canlılık (Birleşik)

Selfie çekimi ile canlılık testini **tek ekranda** birleştiren varyant: kullanıcı tek
oturuşta hem yüz fotoğrafını verir hem canlı olduğunu kanıtlar. Akışı kısaltmak isteyen
kurumlar için idealdir.

Ekran iki yoldan biriyle çalışır — **ARKit** yüz takibi ya da ön kamera + **Vision** —
seçim [TrueDepth modu](#truedepth-modu) ile yapılır. İş mantığı `SDKSelfieWithLivenessViewModel`
içindedir; ekran (SwiftUI) yalnızca kamera/ARKit girdisini ViewModel'e verir ve çizer.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.selfieWithLiveness` |
| Rota | `SDKModuleRoute.selfieWithLiveness` |
| Drop-in view | `SDKSelfieWithLivenessView(trueDepthMode:)` |
| ViewModel | `SDKSelfieWithLivenessViewModel(trueDepthMode:config:)` |
| Dış dünya | Yüz/canlılık (cihazda) + **HTTP** (`uploadIdPhoto`) |
| Sunucuya giden | `mobile/upload`: `type: selfie` + `with_liveness: true` · soket: `uploadSelfieWithLiveness` (3.1.2+) |
| Ses anahtarı | `SelfieWithLivenessTts` |
| Donanım | Moda bağlı — bkz. [TrueDepth modu](#truedepth-modu) |

## Kullanıcı Ne Yaşar?

1. Ön kamera açılır; küçük bir oval çıkar. Kullanıcı yüzünü ovale oturtur ve kısa süre tutar.
2. Oval büyür; kullanıcı yaklaşır ve yüzünü **3 sn** sabit tutar (halka dolar, titreşim hızlanır).
   Işık, mesafe ve konum bozulursa ekranda yönerge çıkar ve halka sıfırlanır.
3. Ekran kısa süre beyaz yanar (ön kamera flaşı), fotoğraf alınır ve **tek selfie** olarak
   yüklenir; kimlik fotoğrafıyla karşılaştırılır. Göz kırpma / gülümseme gibi talimat adımı
   yoktur — onlar [Liveness](../Liveness/Liveness.md) modülündedir.

---

## Kullanım — Drop-in Önerilir

```swift
// Hiçbir şey yazmayın; rota gelince SDK çizer:
case .selfieWithLiveness: SDKSelfieWithLivenessView()
```

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [SelfieWithLivenessCustomView.swift](SelfieWithLivenessCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.selfieWithLiveness) { SelfieWithLivenessCustomView() }`
>
> Vision yolu için kamera denetleyicisi [SelfieCustomView.swift](../Selfie/SelfieCustomView.swift) içindeki `SelfieCameraController`, önizleme [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Tam Özel Ekranlar** ile açılıp kapatılır.

Kamera/ARKit ve çizim sizin; ölçüm, durum makinesi, çekim zamanı, yükleme ve karar ViewModel'in.

### ViewModel'de ne yapılabilir

| Verdiğiniz | Çalışan |
|---|---|
| `updatePreviewSize(_:)` + `beginSession()` | Oval geometrisi (`ovalRect`, `ovalScale`), ısınma, durum makinesi |
| `.arkit`: her takip karesinde `analyzeFace(SDKFaceObservation)` / yüz yokken `analyzeNoFace()` | Işık/eğim/mesafe/konum eşikleri (histerezis), küçük→büyük oval geçişi, tutma süresi → `guidanceText`, `phase`, `holdProgress`, `isFaceAligned` |
| `.vision`: her kamera karesinde `analyzeFrame(_:cameraPosition:)` | Aynı durum makinesi; ölçüm Vision ile (mesafe = yüz/oval oranı, eğim ölçülmez) |
| `shouldCapture` → kare alınır → `presentCaptured(image:)` | Titreşimin bitişi, yükleme, `SDKComparisonGate` kararı, deneme sayacı → `onCompleted` / `onSkipRequested` / `onFlowFailed`, `errorMessage` + `pendingAlertAction` |
| `isSessionActive` / `sessionGeneration` gözlenir | AR/kamera oturumunun ne zaman açılıp duraklatılacağı (çekimden sonra kapanır, hata alert'i kapanınca yeniden açılır) |
| `SDKSelfieWithLivenessConfig` (init'e) | Süreler (tutma 3 sn, küçük oval 1 sn, çekim gecikmesi 1 sn), oval oranları (0.50 / 0.75), ARKit eşikleri |
| `trueDepthMode` (init'e) | Ekranın yolu: `path` = `.arkit` / `.vision` / `.unsupported` |

### ViewModel'de ne yapılamaz

- Yükleme atlanamaz, kendi `POST`'unuz yazılamaz; karşılaştırma kararı ve deneme hakkı sunucudan gelir.
- `phase`, `holdProgress`, `shouldCapture`, `canContinue` dışarıdan yazılamaz (`private(set)`); yalnız girdiyle ilerler.
- Vision yolunda eşikler `SDKSelfieGuidanceConfig`'in Selfie modülüyle ortak saha değerleridir, ekran bazında değiştirilemez.
- Çekim anı flaşı, projeksiyon (3B yüz → ekran noktası) ve anlık görüntü ekranındır; ViewModel görüntüyü üretmez, yalnız alır.

```swift
registry.override(.selfieWithLiveness) { MySwlView() }

struct MySwlView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKSelfieWithLivenessViewModel()   // mod: global TrueDepth ayarı

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if vm.path == .arkit { MyARView(onFace: vm.analyzeFace, onNoFace: vm.analyzeNoFace) }
                else { MyCamera(onFrame: { vm.analyzeFrame($0, cameraPosition: .front) }) }
                MyOval(rect: vm.ovalRect, progress: vm.holdProgress, verified: vm.phase == .verified)
                Text(vm.guidanceText)
            }
            .onAppear { vm.updatePreviewSize(geo.size); vm.beginSession() }        // ✅ zorunlu
        }
        .onChange(of: vm.shouldCapture) { if $0 { myFlashAndSnapshot { vm.presentCaptured(image: $0) } } }
        .onAppear {
            vm.onCompleted = { coordinator.advanceToNextModule() }               // ✅
            vm.onSkipRequested = { coordinator.skipCurrentModule() }
            vm.onFlowFailed = { coordinator.finishFlowAsFailed() }
        }
        .idErrorAlert($vm.errorMessage, onDismiss: { vm.consumePendingAlertAction() })
    }
}
```

`SDKFaceObservation` ARKit yolunun girdisidir: `center` (yüz çıpasının önizlemedeki noktası —
`sceneView.projectPoint` ile ekran alır), `depthMeters` (`abs(transform.columns.3.z)`),
`pitch` (`transform.columns.2.y`), `ambientIntensity` (`lightEstimate`). Tam kalıp
`SelfieWithLivenessCustomView.swift` içindeki `FaceTrackingCameraView`'dadır.

**Tema** ekran yazmadan da çalışır ([Tema rehberi](../../../docs/guides/theming.md)).

## TrueDepth Modu

Ekranın derinlik kamerası kullanıp kullanmayacağını entegrasyon seçer.

```swift
// Akışın tamamı için — setupSDK'dan ÖNCE
IdentifyManager.shared.selfieWithLivenessTrueDepth = .automatic   // varsayılan
IdentifyManager.shared.selfieWithLivenessTrueDepth = .required
IdentifyManager.shared.selfieWithLivenessTrueDepth = .disabled

// Yalnız bu ekran için — override ile ekranı kendiniz kuruyorsanız
registry.override(.selfieWithLiveness) { SDKSelfieWithLivenessView(trueDepthMode: .disabled) }
// Özel ekranda: SDKSelfieWithLivenessViewModel(trueDepthMode: .disabled)
```

| Mod | Ne yapar |
|---|---|
| `.automatic` | ARKit yüz takibi destekleniyorsa ARKit, değilse yedek modül. **Varsayılan**, önceki davranış. |
| `.required` | Yalnız **gerçek TrueDepth kamerası** olan cihazda ARKit; diğerlerinde yedek modül. |
| `.disabled` | ARKit kullanılmaz; ekran ön kamera + Vision ile **her cihazda** çalışır, yedeğe düşülmez. |

Cihaza göre sonuç:

| Cihaz | `.automatic` | `.required` | `.disabled` |
|---|---|---|---|
| Face ID'li iPhone / iPad Pro | ARKit, derinlikli | ARKit, derinlikli | Vision |
| TrueDepth'siz, A12 ve sonrası (iPhone SE 2/3, A12+ Touch ID'li iPad'ler) | **ARKit, derinliksiz (RGB)** | yedek modül | Vision |
| TrueDepth'siz, A11 ve öncesi (iPhone 8, iPad 7…) | yedek modül | yedek modül | Vision |
| Simülatör | çalışmaz | çalışmaz | çalışmaz (kamera yok) |

### Cihaz modelleri

SDK en az **iOS 15** ister; aşağıdaki tüm modeller iOS 15 ya da üstünü çalıştırır. Modlar ek bir
iOS şartı getirmez: TrueDepth'siz A12+ cihazlarda ARKit yüz takibi iOS 14 ile geldi, Vision yüz
tespiti iOS 11'den beri var.

**1. TrueDepth kameralı (Face ID)** — `.automatic` ARKit derinlikli · `.required` ARKit derinlikli · `.disabled` Vision

| Aile | Modeller |
|---|---|
| iPhone | X · XS · XS Max · XR · 11 · 11 Pro · 11 Pro Max · 12 mini · 12 · 12 Pro · 12 Pro Max · 13 mini · 13 · 13 Pro · 13 Pro Max · 14 · 14 Plus · 14 Pro · 14 Pro Max · 15 · 15 Plus · 15 Pro · 15 Pro Max · 16 · 16 Plus · 16 Pro · 16 Pro Max · 16e · 17 · Air · 17 Pro · 17 Pro Max |
| iPad | iPad Pro 11" (1. nesil, 2018 ve sonrası) · iPad Pro 12.9" (3. nesil, 2018 ve sonrası) · iPad Pro 13" (M4 ve sonrası) |

**2. TrueDepth'siz, A12 ve sonrası çip** — `.automatic` ARKit derinliksiz (RGB) · `.required` yedek modül · `.disabled` Vision

| Aile | Modeller |
|---|---|
| iPhone | SE 2. nesil (2020) · SE 3. nesil (2022) |
| iPad | iPad 8. nesil (2020) · 9. nesil (2021) · 10. nesil (2022) · iPad A16 (2025) |
| iPad mini | mini 5 (2019) · mini 6 (2021) · mini A17 Pro (2024) |
| iPad Air | Air 3 (2019) · Air 4 (2020) · Air 5 (2022) · Air M2 (2024) · Air M3 (2025) — **hiçbir iPad Air'de Face ID yoktur** |

**3. TrueDepth'siz, A11 ve öncesi çip** — `.automatic` yedek modül · `.required` yedek modül · `.disabled` Vision

| Aile | iOS 15+ çalıştıran modeller |
|---|---|
| iPhone | 6s · 6s Plus · SE 1. nesil · 7 · 7 Plus · 8 · 8 Plus |
| iPad | iPad 5 · 6 · 7. nesil · iPad mini 4 · iPad Air 2 · iPad Pro 9.7" · iPad Pro 10.5" · iPad Pro 12.9" 1. ve 2. nesil |

Listede olmayan yeni bir model için kural: **Face ID varsa grup 1**, Face ID yoksa (tüm yeni
çipler A12 ve sonrası olduğundan) **grup 2**. Kod tarafında karar donanım sorgusuyla verilir,
model listesiyle değil; bu tablo yalnız bilgilendirme içindir.

**Neden `.required` var:** Apple'ın `ARFaceTrackingConfiguration.isSupported` kontrolü TrueDepth
değil "TrueDepth ya da A12+ çip" ister. `.automatic` bu yüzden TrueDepth'siz A12+ cihazlarda da
ARKit'i açar; orada mesafe tahmindir ve derinlik sensörü yoktur. Derinlik şartınız varsa `.required`.

> ⚠️ **`.disabled` derinlik tabanlı sahtecilik korumasını kaldırır.** Yönlendirme, tutma ve
> çekim çalışır; kimlik karşılaştırması sunucuda aynen yapılır. Ama kameraya tutulan bir
> fotoğrafı ya da ekranı ayırt etmez. Uyum gereksiniminize göre karar verin.

**Vision yolunda farklar:** deneyim (iki fazlı oval, 3 sn tutma, flaş, metinler, yükleme)
aynıdır. Mesafe metre yerine yüzün ovale oranıyla, ışık kare parlaklığıyla ölçülür; **baş
eğimi ölçülmez**. Yüklenen görüntü Selfie modülündeki gibi 3:4 kırpılmış kamera fotoğrafıdır.

**Global değer ile ekran parametresi:** modülün akışta kalıp kalmayacağına `setupSDK` sırasında
**global** değerle karar verilir; `trueDepthMode` yalnız ekranın yolunu seçer. Ekran parametresi
globalden farklıysa:

- Global `.automatic`, ekran `.disabled` → A11 ve öncesi cihazda modül akıştan zaten çıkarılmış
  olur, ekran hiç açılmaz. Bu cihazlarda da çalışsın istiyorsanız **global değeri** `.disabled` yapın.
- Global `.automatic`, ekran `.required` → TrueDepth'siz A12+ cihazda ekran açılır, "desteklenmiyor"
  uyarısı gösterilir ve modül atlanır.

**Hangi yol kullanıldı:** `sdk_logs`'a `Selfie + canlılık yolu: arkit-truedepth | arkit-rgb | vision`
satırı yazılır. Yedeğe düşülünce önceki gibi `selfieWithLivenessModuleSkipped` olayı yayınlanır.

### Yedek modül

Mod "desteklenmez" dediğinde yerine ne geleceğini ayrıca seçersiniz:

```swift
IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan: selfie ile doğrula
IdentifyManager.shared.faceTrackingFallback = .skip     // adımı tamamen çıkar
// setupSDK'dan ÖNCE
```

Akışta zaten selfie varsa `.selfie` yeni adım eklemez, bu modülü yalnızca çıkarır. Olay:
`status == .skipped`, modül `Selfie With Liveness`. `.livenessDetection` değeri kabul edilir
ama canlılık modülü de ARKit istediğinden `.selfie` gibi davranır.
Ayrıntı: [iPad Desteği](../../../docs/guides/ipad-support.md).

### Denemek

Örnek uygulamada hamburger menüsü → **Debug Değerleri** → *Selfie + Canlılık* → TrueDepth modu.
Seçim bir sonraki bağlantıda geçerli olur; üç yolu aynı cihazda deneyebilirsiniz.

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .selfieWithLiveness)        // Siri/sistem sesi
// veya kendi kaydınız: bundle'a SelfieWithLivenessTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .selfieWithLiveness)   // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .selfieWithLivenessTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)
