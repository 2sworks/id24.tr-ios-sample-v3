# Selfie — Yüz Fotoğrafı

Kullanıcı ön kamerayla bir selfie çeker; SDK **cihaz üzerinde** yüz olup olmadığını doğrular
(`detectHumanFace`) ve görseli sunucuya yükler. Sunucu tarafında bu selfie, kimlik
fotoğrafı ve NFC çip fotoğrafıyla karşılaştırılır — "belgedeki kişi gerçekten bu kişi mi?"
sorusunun cevabı burada başlar.

Bu modül aynı zamanda Default UI geçişinin pilotuydu; **composition deseninin referans
örneğidir** — diğer modüllere bakmadan önce bunu okumak iyi bir başlangıçtır.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.selfie` |
| Rota | `SDKModuleRoute.selfie` |
| Drop-in view | `SDKSelfieView` |
| ViewModel | `SDKSelfieViewModel` |
| Dış dünya | Yüz tespiti (cihazda) + **HTTP** (`uploadIdPhoto`) |
| Ses anahtarı | `SelfieTts` |

## Kullanıcı Ne Yaşar?

1. Ön kamera açılır; kullanıcı yüzünü çerçeveye alır ve fotoğrafı çeker.
2. SDK cihazda yüz arar — yüz yoksa (ya da birden fazla yüz varsa) uyarı çıkar, yeniden çekilir.
3. Yüz doğrulanınca görsel yüklenir; "Devam" aktifleşir.
4. Sunucudaki karşılaştırma hakkı tükenir ve atlamaya izin varsa adım atlanabilir.

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKSelfieView` çizilir.

## Kendi Tasarımınızla (Override)

Kamera ve UI sizin. Kameranızın karelerini VM'e verirseniz **canlı yönlendirme ve otomatik
çekim de çalışır** — yalnız fotoğrafı verirseniz yalnız yüz tespiti + yükleme çalışır.

| Verdiğiniz | Çalışan |
|---|---|
| `updatePreviewSize(_:)` + her kare `analyzeFrame(_:cameraPosition:)` | `faceCondition`, `guidanceText`, `isFaceAligned`, `holdProgress`, `shouldAutoCapture` |
| Çekilen fotoğraf → `processSelfie(image:)` | Yüz tespiti + yükleme (onay adımı yok) |
| Çekilen fotoğraf → `presentCaptured(image:)` + kullanıcı onayı → `confirmSelfie()` | SDK ekranıyla aynı: önce önizleme, onayda yükleme |

```swift
registry.override(.selfie) { MySelfieView() }

struct MySelfieView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKSelfieViewModel()
    let camera = MyFrontCamera()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MyCameraPreview(camera: camera)
                MyOval(aligned: vm.isFaceAligned, progress: vm.holdProgress)
                Text(vm.guidanceText)
                if vm.awaitingConfirmation {
                    MyConfirm(image: vm.selfieImage, onConfirm: vm.confirmSelfie, onRetake: vm.reset)
                }
            }
            .onAppear {
                vm.updatePreviewSize(geo.size)                                  // ✅ zorunlu
                camera.onPixelBuffer = { vm.analyzeFrame($0, cameraPosition: .front) }  // kamera kuyruğundan
            }
        }
        .onChange(of: vm.shouldAutoCapture) { if $0 { camera.takePhoto { vm.presentCaptured(image: $0) } } }
        .onChange(of: vm.canContinue) { if $0 { coordinator.advanceToNextModule() } }   // ✅
        .onAppear { vm.onSkipRequested = { coordinator.skipCurrentModule() } }
    }
}
```

- Oval, `updatePreviewSize` ile verilen ölçüye göre hesaplanır; önizlemeniz ekranı
  kaplamıyorsa gerçek önizleme boyutunu verin.
- Sesli okuma sürerken çekimi bekletmek için `vm.isCaptureSuspended = true`.
- Eşikler (tutma süresi vb.): `SDKSelfieViewModel(config: SDKSelfieGuidanceConfig(...))`.

---

## ViewModel Referansı — `SDKSelfieViewModel`

### State
| Üye | Tip | Erişim | Anlam |
|---|---|---|---|
| `selfieImage` | `UIImage?` | r/w | Çekilen selfie |
| `faceDetected` | `Bool` | salt-okunur | Yüz tespit edildi mi |
| `canContinue` | `Bool` | salt-okunur | Devam edilebilir mi |
| `resultText` | `String` | salt-okunur | Sonuç metni |
| `faceCondition` | `SDKSelfieFaceCondition` | salt-okunur | Canlı yüz durumu (yok, uzak, yakın, ortada değil, uygun…) |
| `guidanceText` | `String` | salt-okunur | Duruma göre yönlendirme metni |
| `isFaceAligned` | `Bool` | salt-okunur | Yüz ovale oturdu mu |
| `holdProgress` | `Double` | salt-okunur | Otomatik çekime kalan tutma süresi (0…1) |
| `shouldAutoCapture` | `Bool` | salt-okunur | Şimdi çek |
| `awaitingConfirmation` | `Bool` | salt-okunur | Çekilen fotoğraf onay bekliyor |
| `isCaptureSuspended` | `Bool` | r/w | Otomatik çekimi geçici beklet |

### Metotlar
| Metot | Etki |
|---|---|
| `updatePreviewSize(_ size: CGSize)` | Önizleme boyutu; oval ve hizalama buna göre hesaplanır |
| `analyzeFrame(_:cameraPosition:)` | Canlı kare analizi; kamera kuyruğundan çağrılabilir |
| `presentCaptured(image:)` | Çekilen fotoğrafı onaya alır, yüklemez |
| `confirmSelfie()` | Onaylanan fotoğrafı yüz tespiti + yüklemeye gönderir |
| `processSelfie(image: UIImage)` | Onaysız doğrudan yüz tespiti (`detectHumanFace`) → `uploadIdPhoto` |
| `reset()` | Durumu sıfırlar (yeniden çekim) |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onSkipRequested: (() -> Void)?` | Karşılaştırma hakkı tükenip atlamaya izin varsa |

## Sinyal Zinciri — Perde Arkası

```
processSelfie(image:)  → manager.detectHumanFace (cihazda) → uploadIdPhoto [HTTP]
                       → (selfieComparisonCount tükendi & skip izinli) → onSkipRequested?()
host: canContinue → coordinator.advanceToNextModule() [modulePresented]
```

## Host VM ile Gözlem (Composition) — Referans Desen

```swift
@MainActor
final class SelfieHostViewModel: HostModuleViewModel {
    let sdk = SDKSelfieViewModel()
    override init() {
        super.init(); bridge(sdk)                     // child objectWillChange'i yukarı ilet
        sdk.onSkipRequested = { [weak self] in self?.log("selfie_skip") }
    }
    var canContinue: Bool { sdk.canContinue }
    func process(_ img: UIImage) { log("selfie_scan"); sdk.processSelfie(image: img) }
}
```

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .selfie)         // Siri/sistem sesi
// veya kendi kaydınız: bundle'a SelfieTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .selfie)    // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .selfieTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Bu modül aynı zamanda yedektir:** cihazda TrueDepth kamera yoksa `livenessDetection` ve
  `selfieWithLiveness` yerine bu modül konur (varsayılan `faceTrackingFallback = .selfie`) —
  doğrulama yine yüz üzerinden yapılır, çekilen kare kimlik fotoğrafıyla karşılaştırılır.
  Akışta selfie zaten varsa ikinci bir adım eklenmez.
  Ayrıntı: [iPad Desteği](../../../docs/guides/ipad-support.md).
- **Tablet yerleşimi:** yüz ovali pencere genişliğiyle birlikte büyümez;
  `SDKLayout.maxFaceGuideWidth` (vars. 560) ile sınırlanır. Kılavuz ile analiz aynı
  dikdörtgeni paylaştığı için "çok uzak / çok yakın" değerlendirmesi de bu sınırla uyumludur.

- **Yüz bulunamadı:** `faceDetected` `false` kalır, `canContinue` açılmaz — kullanıcıyı
  `reset()` ile yeniden çekime yönlendirin (ışık ve tek-yüz koşulunu hatırlatın).
- **Birden fazla yüz:** SDK yalnızca **tek yüz** algılandığında ilerletir (2.3.15+).
- **Deneme hakkı:** `selfie_comparison_count` sunucudan gelir; custom ekranınızda
  `onSkipRequested`'ı bağlamayı unutmayın — yoksa hak tükenince kullanıcı sıkışır.
