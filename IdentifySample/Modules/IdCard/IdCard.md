# IdCard — Kimlik Tarama (OCR)

Akışın en temel adımı: kullanıcı kimlik kartının (veya pasaportunun) fotoğrafını çeker,
SDK yazıları **cihaz üzerinde** okur (OCR) ve görseli sunucuya yükler. İnternete yalnızca
yükleme için ihtiyaç vardır — okuma tamamen cihazda gerçekleşir, kimlik verisi ham fotoğraf
dışında hiçbir yere gitmez.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.idCard` |
| Rota | `SDKModuleRoute.idCard` |
| Drop-in view | `SDKIdCardView` |
| ViewModel | `SDKIdCardViewModel` |
| Dış dünya | Cihazda OCR + **HTTP** (`uploadIdPhoto`) |
| Ses anahtarı | `IdCardTts` |

## Kullanıcı Ne Yaşar?

1. (Birden fazla belge tipi izinliyse) belge tipini seçer: kimlik kartı / pasaport / eski tip.
2. Ön yüzü çerçeveye hizalar, fotoğraf çekilir; SDK okur ve yükler.
3. Aynısını arka yüz için yapar (pasaportta tek MRZ sayfası yeter).
4. Okuma başarısızsa tekrar dener; deneme hakkı tükenir ve atlamaya izin varsa adım atlanabilir.

Burada okunan MRZ alanları (seri no, doğum tarihi, geçerlilik) sonraki **NFC** adımının
anahtarıdır — bu yüzden OCR genellikle NFC'den önce gelir.

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKIdCardView` çizilir. İki init'i vardır:

```swift
SDKIdCardView()                       // kendi VM'ini kurar
SDKIdCardView(viewModel: myIdCardVM)  // dışarıdan VM enjeksiyonu (host VM ile)
```

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [IdCardCustomView.swift](IdCardCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.idCard) { IdCardCustomView() }`
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Özel Ekranlar** ile açılıp kapatılır.


Ekranı siz çizersiniz; OCR + yükleme + adım sinyali SDK VM'inde kalır. Görüntüyü nereden
aldığınıza göre iki yol vardır:

| | A) SDK tarayıcısı (önerilen) | B) Kendi kameranız |
|---|---|---|
| Otomatik çekim | ✅ | ❌ siz tetiklersiniz |
| Mesafe / bulanıklık / parlama kapıları | ✅ | ❌ |
| Belgeye kırpma, pasaport oryantasyon düzeltmesi | ✅ | ❌ |
| Tasarım serbestliği | Çerçeve, çizgi stili, metinler, fener; HUD gizlenemez ([sınırlar](../../../docs/guides/identity-scanner.md#görünüm-ve-davranış-ayarları)) | Tam |
| Risk | — | Bulanık/parlamalı kare → "okunamadı" ya da sunucu karşılaştırma reddi |

> **Otomatik fener, lens geçişi, Elle çek düğmesi, parlama kapısı** `ScannerAutomation` ile
> kapatılır (ör. `ScannerAutomation.default.autoTorch = false`). Ayrıntı:
> [Otomatik Davranışlar](../../../docs/guides/identity-scanner.md#otomatik-davranışlar--scannerautomation).

### A) SDK tarayıcısıyla

`.documentScanner` modifier'ı tarayıcıyı tam ekran açar, sonuç gelince kapatır ve üstüne
kendi katmanınızı koymanıza izin verir (iOS 15+):

```swift
registry.override(.idCard) { MyIdCardScanView() }

struct MyIdCardScanView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKIdCardViewModel()
    @State private var scanning = false
    @State private var torchOn = false

    var body: some View {
        MyIdCardIntro(side: vm.currentSide, isLoading: vm.isLoading,
                      error: vm.errorMessage) { scanning = true }      // "Tara" düğmesi
            .documentScanner(
                isPresented: $scanning,
                profile: vm.currentSide == .front ? .turkishIDFront : .turkishIDBack,
                style: QuadrilateralStyle(strokeColor: .white, lockedStrokeColor: .green,
                                          dashPattern: [16, 8]),
                configuration: vm.currentSide == .front ? .default : .idBack,
                externalTorchOn: $torchOn,                   // verilince tarayıcının fener düğmesi gizlenir
                navOverlay: { MyScannerChrome(torchOn: $torchOn, side: vm.currentSide) { scanning = false } }
            ) { result in
                guard case .success(let doc) = result else { return }   // iptal / hata
                vm.currentSide == .front
                    ? vm.scanFront(image: doc.croppedImage)   // ✅ OCR + upload + sendStep
                    : vm.scanBack(image: doc.croppedImage)    // ✅
            }
            .onChange(of: vm.canContinue) { if $0 { coordinator.advanceToNextModule() } }
            .onAppear { vm.onSkipRequested = { coordinator.skipCurrentModule() } }
    }
}
```

- Ön yüz yüklenince `vm.currentSide` kendiliğinden `.back` olur; arka yüz için tarayıcıyı
  yeniden açın. OCR ya da yükleme düşerse `vm.errorMessage` dolar, yüz değişmez.
- Arka yüzde `configuration: .idBack` kullanın: arka yüz daha az dokulu, netlik eşikleri ayrı.
- Pasaport: `profile: .passport` + `configuration: .passport`.
- `IdentityScannerView`'ı modifier olmadan kullanacaksanız mutlaka `fullScreenCover` içinde
  sunun: sonuç gelince kendini `dismiss()` eder, bir ekranın gövdesine gömülürse o ekranı kapatır.

### B) Kendi kameranızla

```swift
MyCameraView { captured in
    vm.currentSide == .front ? vm.scanFront(image: captured) : vm.scanBack(image: captured)
}
```

Bu yolda kalite kontrolü sizdedir: çekimden önce görüntünün net, parlamasız ve belgeye
kırpılmış olduğundan emin olun. `vm.errorMessage` OCR başarısızlığını, `vm.isLoading`
yüklemeyi bildirir.

### Örnek Senaryo: Akışı 4 Ekranla Sarmak

"Tanıtım → ön yüz → arka yüz → başarı" gibi kendi ekran zincirinizi kurmak isterseniz,
pasif ekranları **custom**, aktif taramayı **override** yaparsınız:

```swift
registry.custom("idcard_intro")   { IdCardIntroView() }    // pasif
registry.custom("idcard_success") { IdCardSuccessView() }  // pasif
registry.override(.idCard)        { MyIdCardScanView() }   // aktif (SDK VM kullanır)

coordinator.insert(["idcard_intro"],   before: .idCard)
coordinator.insert(["idcard_success"], after:  .idCard)
```

| Ekran | Tür | VM çağrısı |
|---|---|---|
| Tanıtım | custom / pasif | — (yalnızca `coordinator.advanceExternal()`) |
| Ön yüz | override / aktif | `vm.scanFront(image:)` ✅ |
| Arka yüz | override / aktif | `vm.scanBack(image:)` ✅ |
| Başarı | custom / pasif | — sonra `coordinator.advanceToNextModule()` |

> **Soket/WebRTC bozulur mu?** Hayır. Bağlantılar `IdentifyManager.shared`'da yaşar, ekran
> yaşam döngüsünden izoledir. Tek şart: tarama/yükleme SDK VM'inden geçsin
> ([bypass yok](../../../docs/guides/customization.md#bypass-yok-kuralı)).

---

## ViewModel Referansı — `SDKIdCardViewModel`

### Tip
```swift
public enum IdCardSide: String, Identifiable, Hashable { case front, back }
```

### State
| Üye | Tip | Erişim | Anlam |
|---|---|---|---|
| `frontPhoto` | `UIImage?` | r/w | Ön yüz görseli |
| `backPhoto` | `UIImage?` | r/w | Arka yüz görseli |
| `currentSide` | `IdCardSide` | salt-okunur | Şu an okunan yüz |
| `resultText` | `String` | salt-okunur | Kullanıcıya gösterilen sonuç metni |
| `canContinue` | `Bool` | salt-okunur | Devam edilebilir mi |

### Hesaplanan
| Üye | Anlam |
|---|---|
| `allowedCardTypes: [CardType]` | İzinli belge tipleri (`manager.allowedCardType`) |
| `nfcRetryExceeded: Bool` | NFC karşılaştırma 2+ kez denendi mi |

### Metotlar
| Metot | Etki |
|---|---|
| `selectCardType(_ type: CardType)` | Belge tipini seçer (`manager.selectedCardType`) |
| `scanFront(image: UIImage)` | Ön yüz OCR (`startFrontIdOcr`) → `uploadIdPhoto` |
| `scanBack(image: UIImage)` | Arka yüz OCR (`startBackIdOcr`) → `uploadIdPhoto`; bitince akış ilerler |
| `scanPassport(image:comingData:)` | Pasaport MRZ okuma (`startPassportMrzKey`) |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onSkipRequested: (() -> Void)?` | Deneme hakkı tükenip atlamaya izin varsa |

## Sinyal Zinciri — Perde Arkası

```
selectCardType(_:)                       → manager.selectedCardType (cihazda)
scanFront(image:)  → startFrontIdOcr (cihazda OCR) → uploadIdPhoto [HTTP] → sendStep idFront=true [SOKET]
scanBack(image:)   → startBackIdOcr  (cihazda OCR) → uploadIdPhoto [HTTP] → sendStep idBack=true [SOKET]
                   → (deneme hakkı tükendi & skip izinli) → onSkipRequested?()
host: tüm yüzler tamam → coordinator.advanceToNextModule()  [modulePresented]
```

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class IdCardHostViewModel: HostModuleViewModel {
    let sdk = SDKIdCardViewModel()
    override init() {
        super.init()
        bridge(sdk)
        sdk.onSkipRequested = { [weak self] in self?.log("skip_requested") }
    }
    var currentSideText: String { sdk.currentSide == .front ? "ön" : "arka" }
    var canContinue: Bool { sdk.canContinue }
    func scanFront(_ image: UIImage) { log("scan_front"); sdk.scanFront(image: image) }
    func scanBack(_ image: UIImage)  { log("scan_back");  sdk.scanBack(image: image) }
}
```

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .idCard)         // Siri/sistem sesi
// veya kendi kaydınız: bundle'a IdCardTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .idCard)    // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .idCardTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Pasaport?** `scanPassport(image:comingData:)` yalnızca belge tipi `.passport`
  seçildiğinde gerekir; tek MRZ sayfası yeterlidir. Kabul edilen tipleri
  `setupSDK(identCardType:)` belirler.
- **Yamuk çekimler:** `setupSDK(enableAutoRotateOCR: true)` fotoğrafı otomatik döndürür.
- **OCR nerede çalışır?** Tamamen cihazda; ağ yalnızca `uploadIdPhoto` için kullanılır.
- **Tarama motoru:** Hazır ekranın altındaki gerçek zamanlı tarayıcı (dörtgen yakalama,
  bölgesel OCR, TCKN/MRZ doğrulama) bağımsız bir bileşen olarak da kullanılabilir —
  [IdentityScanner rehberi](../../../docs/guides/identity-scanner.md).
- **Deneme hakları:** `ocr_comparison_count` sunucudan gelir; tükenince `onSkipRequested`
  devreye girebilir — custom ekranınızda bu closure'ı mutlaka bağlayın.
