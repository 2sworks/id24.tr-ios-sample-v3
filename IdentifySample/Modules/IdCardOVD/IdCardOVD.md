# IdCardOVD — Kimlik Tarama + Hologram Doğrulama

IdCard'ın güvenlik seviyesi yükseltilmiş hali. Fotoğraf çekmekle kalmaz: kamera akışını
canlı analiz ederek belgenin **optik değişken öğelerini (OVD — hologram)** doğrular.
Parlama (glare), doku (texture) ve gökkuşağı (rainbow) skorları **cihaz üzerinde** hesaplanır;
fotokopi ya da ekran görüntüsüyle yapılan sahtecilik denemeleri bu adımda elenir.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.idcard_w_ovd` |
| Rota | `SDKModuleRoute.idCardOVD` |
| Drop-in view | `SDKIdCardOVDView` |
| ViewModel | `SDKIdCardOVDViewModel` |
| Dış dünya | Cihazda skor analizi + **HTTP** (`uploadIdPhoto`) |
| Ses anahtarı | `IdCardOVDTts` |

## Kullanıcı Ne Yaşar?

0. **Belge tipi seçim ekranı** açılır (IdCardView deseni): **Çipli Kimlik** ya da **Pasaport**.
   Seçime göre çekim akışı belirlenir. (Host `SDKIdCardOVDView(documentType:)` ile bu ekranı atlayabilir.)
1. Belgeyi çerçeveye hizalar; SDK kareleri canlı değerlendirir (dikdörtgen/coverage + netlik +
   görüntü ve cihaz sabitliği + parlama oranı). Uygun olunca **otomatik** yüksek-çözünürlüklü
   fotoğraf çekilir. Çekilen kare bulanıksa (still netlik tabanının altında) kullanıcıya
   göstermeden en fazla iki kez yeniden çekilir.
2. (Yalnız kimlik) Hologram adımında torch açılır ve belgeyi hafifçe eğip çevirmesi istenir —
   gökkuşağı efekti ölçülür (`rainbowProgress` doluyor, baseline'a göre delta). Efekt yakalanınca
   çekim **belge sakinleşince** alınır (en az 0.75 sn, en çok 2.5 sn); bu sırada çerçevede belge
   görünmüyorsa (kart çekildi, renkli başka bir yüzey girdi) adım sıfırlanır — ölçüm ilk yüzde
   onaylanan belgenin çerçevede kalmasını şart koşar.
3. (Yalnız kimlik) arka yüz hizalanır — **MRZ okunana kadar** yakalama tetiklenmez.
4. Adımlar (`OVDStep`) sırayla tamamlanır; her yakalama sunucuya yüklenir. Son adım bitince
   akış otomatik ilerler.

**Adım sayısı belge tipine göre:**
- **Kimlik** → ön → **flaşlı ön (hologram)** → arka  (3 adım)
- **Pasaport** → ön (veri sayfası) → **flaşlı ön (hologram)**  (2 adım — yalnız **arka yüz** çalıştırılmaz)

Her adım geçişinde yönerge hem ekranda gösterilir hem de (TTS açıksa) seslendirilir — UIKit
referans akışının davranışının aynısı. **TTS kapalıysa** yalnız ekran metni yönlendirir.

### Belge Tipi — Pasaport (sadece ön yüz)

Pasaportun tek veri sayfası olduğu için **arka yüz adımı yoktur** — ama flaşlı (hologram) adımı
kimliktekiyle **aynı şekilde çalışır**: `ön (veri sayfası) → flaşlı (hologram) → tamamlandı` (2 adım).
Ön yüz upload'ı `type=passport` + `doc_type=passport`; flaşlı adım kimliktekiyle aynı (`.frontIdOvd`).

```swift
SDKIdCardOVDView(documentType: .passport)   // seçim ekranını atlar, doğrudan pasaport çekimi
// veya VM ayarı:
let vm = SDKIdCardOVDViewModel(); vm.documentType = .passport
```

Standart drop-in `SDKIdCardOVDView()` ise **önce belge tipi seçim ekranı** gösterir; kullanıcı
Kimlik/Pasaport seçince ilgili akış başlar.

`documentType` ayarlanınca `IdentifyManager.selectedCardType` otomatik güncellenir (WS location =
"Passport"). Kimlik varsayılandır (`.idCard`).

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKIdCardOVDView` çizilir.

## Kendi Tasarımınızla (Override)

OVD, kamerayı SDK'dan en çok isteyen modüldür: VM kararı verir, **kamerayı siz sürersiniz**.
Aşağıdaki kancaların hepsi bağlanmadan otomatik çekim çalışmaz.

| Kanca | Yön | Bağlanmazsa |
|---|---|---|
| `ingest(ciImage:roi:)` | host → VM, her kare | Hiçbir analiz yapılmaz |
| `onRequestCapture` → `handleCaptured(_:roi:)` | VM "çek" der, host fotoğrafı verir | **Çekim olmaz** |
| `onSetTorch` | VM → host | Hologram adımında fener yanmaz, gökkuşağı ölçülemez |
| `startMotion()` / `stopMotion()` | host → VM | IMU sabitlik kapısı hiç açılmaz |
| `motionFeed` | host → VM, her kare (`CVPixelBuffer`) | Görüntü sabitlik kapısı atlanır, yalnız IMU'ya bakılır — elde eğilen kartta bulanık kare riski |
| `onRequestLensSwitch` | VM → host | İsteğe bağlı: çok yakın belgede lens geçişi yok |
| `onRequestFocusNudge`, `focusProbe` | VM ↔ host | İsteğe bağlı: aktif odak dürtmesi ve "uzaklaştırın" yönergesi yok |

`roi`, kılavuz çerçevenizin **kamera karesi koordinatındaki** karşılığıdır (`CIImage.extent`
içinde). Ekrandaki çerçeveyi önizlemenin `aspectFill` ölçeğiyle kareye çevirin; yanlış `roi`
belge tespitini ve kırpmayı kaydırır.

```swift
registry.override(.idCardOVD) { MyOVDView() }

struct MyOVDView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKIdCardOVDViewModel()
    let camera = MyCamera()                              // AVCaptureSession + foto çıkışı

    var body: some View {
        ZStack {
            MyCameraPreview(camera: camera)
            MyGuide(detected: vm.guideDetected, progress: vm.rainbowProgress)
            Text(vm.instruction)
        }
        .onAppear {
            vm.onCompleted       = { coordinator.advanceToNextModule() }      // ✅
            vm.onSkipRequested   = { coordinator.skipCurrentModule() }
            vm.onRequestCapture  = { camera.capturePhoto() }                  // ✅ zorunlu
            vm.onSetTorch        = { camera.setTorch($0) }                    // ✅ zorunlu (hologram)
            let motion = vm.motionFeed
            camera.onPixelBuffer = { motion($0) }            // ✅ önerilir — her kare, kamera kuyruğu
            camera.onFrame = { ci in vm.ingest(ciImage: ci, roi: camera.roi(for: ci)) }  // ana thread, ~0.18 sn
            camera.onPhoto = { ci in vm.handleCaptured(ci, roi: camera.roi(for: ci)) }
            camera.start(); vm.startMotion()
        }
        .onDisappear { vm.stopMotion(); camera.stop() }
    }
}
```

- `ingest` ve `handleCaptured` **ana iş parçacığından** çağrılır (VM `@MainActor`). SDK'nın
  kendi kamerası `ingest`'i ~0.18 sn'de bir çağırır; hologram analizi karede pahalı olduğundan
  siz de benzer bir seyreltme uygulayın.
- `motionFeed` ise **her kareyle, kamera kuyruğunda** çağrılır — seyreltmeden önce.
- Yükleme, adım geçişi ve fener kararları VM'dedir; `advance()` elle çağrılmaz.

> ❌ **Bypass yapmayın:** Skorları kendiniz hesaplayıp upload'u atlamayın —
> `ingest` → `handleCaptured` zincirini kullanın, aksi halde OVD doğrulaması
> backend'e hiç ulaşmaz. Kural: [bypass yok](../../../docs/guides/customization.md#bypass-yok-kuralı).

---

## ViewModel Referansı — `SDKIdCardOVDViewModel`

### Tip
```swift
public enum OVDStep: Int, CaseIterable {
    case frontAlign, ..., completed
    public var isCompleted: Bool { self == .completed }
}
```

### State (`@Published`, salt-okunur)
| Üye | Tip | Anlam |
|---|---|---|
| `step` | `OVDStep` | Mevcut adım |
| `canContinue` | `Bool` | Devam edilebilir mi |
| `isUploading` | `Bool` | Yükleme sürüyor mu |
| `rainbowProgress` | `Double` | Hologram adımı ilerlemesi |
| `guideDetected` | `Bool` | Çerçeve yeşil (yakalama koşulu tuttu) |
| `instruction` | `String` | Anlık ekran talimatı (adım/gating'e göre değişir) |
| `debugLive` | `DebugLive?` | Kapıların anlık değerleri (belge, hareket, IMU, hizalama, gökkuşağı, odak, netlik); tanılama ekranı için, üretimde `nil` bırakılabilir |

### Ayar
| Üye | Varsayılan | Anlam |
|---|---|---|
| `documentType` | `.idCard` | `.idCard` (ön→hologram→arka) / `.passport` (ön→hologram, arka YOK) |
| `requiresHologramStep` | `true` | Hologram adımı zorunlu mu |
| `onRequestCapture` / `onSetTorch` | `nil` | Drop-in View kameraya bağlar; özel View'da siz bağlarsınız |

### Hesaplanan
| Üye | Anlam |
|---|---|
| `progress: Double` | Genel ilerleme (0–1) |
| `instruction: String` | Mevcut adımın kullanıcı talimatı |

### Metotlar
| Metot | Etki |
|---|---|
| `ingest(ciImage:roi:)` | Canlı kareyi değerlendirir (glare/texture/rainbow skorları) |
| `handleCaptured(_:roi:)` | `onRequestCapture` sonrası çekilen fotoğrafı işler ve yükler |
| `startMotion()` / `stopMotion()` | IMU sabitlik ölçümünü başlatır / durdurur |
| `motionFeed` | Kare-farkı hareket ölçeri besleyicisi: `(CVPixelBuffer) -> Void`, kamera kuyruğundan çağrılabilir |
| `forceCapture(ciImage:roi:)` | Skorları beklemeden zorla yakalar |
| `capture(image:)` | Yakalanan görseli işler (`makeUIImage` + `processCaptured`) |
| `advance()` | Sonraki adım; son adımda **`onCompleted?()`** |
| `reset()` | Akışı başa alır |
| `requestSkip()` | `onSkipRequested?()` tetikler |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onCompleted: (() -> Void)?` | Tüm OVD adımları + yükleme bitti |
| `onSkipRequested: (() -> Void)?` | Atlama istendi |
| `onRequestCapture: (() -> Void)?` | Kapılar tuttu — host fotoğraf çekip `handleCaptured` çağırmalı |
| `onSetTorch: ((Bool) -> Void)?` | Feneri aç/kapat (hologram adımı) |
| `onRequestLensSwitch: (() -> Void)?` | Belge çok yakın — sonraki lense geç (isteğe bağlı) |
| `onRequestFocusNudge: (() -> Void)?` | Netlik gelmiyor — tek atış odak turu başlat (isteğe bağlı) |
| `focusProbe: (() -> (Bool, Float, Int?, Bool))?` | Odak durumu: ayarlıyor mu, `lensPosition`, asgari odak mm, yakın sınırda mı (isteğe bağlı) |
| `onFlowFailed: (() -> Void)?` | Akış başarısız sonlandı |

## Sinyal Zinciri — Perde Arkası

```
ingest(ciImage:roi:)  → Vision(VNDetectRectangles) + ovdTextureMean + ovdColorMetrics(whiteOut)
                        + kare-farkı hareket ölçeri ∧ CMMotion sabitlik + (arka) probeMRZPresence
                        + (hologram) belge süreklilik kapısı + ovdRainbowMaxScoreDetailed
                        → readyScore histerezis → uygun olunca onRequestCapture (kamera fotoğraf çeker)
handleCaptured(_:roi:) → processCaptured + (front/back) startFrontIdOcr/startBackIdOcr + uploadIdPhoto [HTTP]
advance()  (son adım) → onCompleted?()  → host: coordinator.advanceToNextModule() [modulePresented]
```

> Sesli yönerge adım geçişlerinde `SDKSpeechService.shared.speak(_:in: .idcard_w_ovd)` ile verilir
> (ayrı synthesizer YOK). TTS kapalıysa sessizdir; ekran metni her hâlde görünür.

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class IdCardOVDHostViewModel: HostModuleViewModel {
    let sdk = SDKIdCardOVDViewModel()
    override init() {
        super.init(); bridge(sdk)
        sdk.onCompleted     = { [weak self] in self?.log("ovd_done") }
        sdk.onSkipRequested = { [weak self] in self?.log("ovd_skip") }
    }
    var instruction: String { sdk.instruction }
    var progress: Double { sdk.progress }
}
```

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .idcard_w_ovd)        // Siri/sistem sesi
// veya kendi kaydınız: bundle'a IdCardOVDTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .idcard_w_ovd)   // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .idCardOVDTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Hologram adımı atlanabilir mi?** `requiresHologramStep = false` — düşük donanımlı
  cihaz senaryoları için.
- **Performans:** `ingest` her karede çağrılır ve pahalıdır; kamera frame rate'ini makul
  tutun (ör. 15–30 fps yeterli).
- **Skorlar takılıyorsa:** Işık koşulları kritik — kullanıcıya parlamayı azaltacak yönerge
  verin; gerekirse `forceCapture` ile kilitlemeyi kırın.
