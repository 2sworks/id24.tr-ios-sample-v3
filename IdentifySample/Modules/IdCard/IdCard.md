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

---

## Hazırlık Ekranı (Belge Türü Seçimi)

Modül, tarama başlamadan önce "Çipli TC / Pasaport / Diğer" seçim ekranını açar. Bu ekran
`SDKDocumentSelectionConfig.shared.idCard` ile ayarlanır — `setupSDK`ten önce yazın:

```swift
SDKDocumentSelectionConfig.shared.idCard.showsScreen = false      // ekranı tamamen kaldır
SDKDocumentSelectionConfig.shared.idCard.defaultType = .idCard    // kaldırıldığında kullanılacak tip
SDKDocumentSelectionConfig.shared.idCard.options = [.idCard, .passport]  // ekrandaki satırlar ve sıraları
SDKDocumentSelectionConfig.shared.idCard.speaksOnScreen = false   // yalnız bu ekranın sesli yönergesi sussun
SDKDocumentSelectionConfig.shared.idCard.autoSkipSingleOption = false  // tek seçenekte de ekranı göster
```

| Alan | Varsayılan | Anlam |
|---|---|---|
| `showsScreen` | `true` | `false` → ekran hiç açılmaz, doğrudan taramaya girilir |
| `options` | `[.idCard, .passport, .oldSchool]` | Ekrandaki satırlar, yazdığınız sırayla. Sunucunun izin verdikleriyle (`identCardType`) kesiştirilir; kesişim boşsa sunucunun listesi kullanılır ve durum `sdk_logs`a yazılır |
| `defaultType` | `nil` | Ekranda ilk seçili gelen / ekran atlandığında kullanılan tip. `nil` → `options` içindeki ilk tip |
| `speaksOnScreen` | `true` | `false` → yalnız bu ekran okunmaz, modülün diğer adımları okunmaya devam eder |
| `autoSkipSingleOption` | `true` | Geriye tek seçenek kaldığında ekran atlanır (kullanıcıya sorulacak bir şey yoktur) |

**Ekran atlandığında ne gönderilir?** Seçim ekranı açılsaydı gidecek olan
`stepChanged / location: "documentSelection"` mesajı **gitmez**; onun yerine seçilen tipin kendi
konumu (`Id Card` / `Passport` / `Other`) ve `setDocType` isteği **modül açılır açılmaz**, kullanıcı
hiçbir şeye dokunmadan gider. Ekran atlandığında bu ekranın sesli yönergesi de okunmaz.

> **Dikkat — davranış değişikliği:** `setupSDK(identCardType:)` ile tek tip gönderen
> entegratörler önceden tek satırlı bir seçim ekranı görüyordu. Artık o ekran atlanır. Eski
> davranış için `autoSkipSingleOption = false`.

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [IdCardCustomView.swift](IdCardCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.idCard) { IdCardCustomView() }`
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Özel Ekranlar** ile açılıp kapatılır.

> **İkinci örnek — tek ekranda ön + arka yüz:** [IdCardSingleScreenCustomView.swift](IdCardSingleScreenCustomView.swift).
> Kamera modül açılır açılmaz tam ekran çalışır; ön yüz çekilip sunucuda onaylanınca aynı ekranda
> arka yüze geçilir, arka yüz onaylanınca modül tamamlanır. Ret olursa çerçevenin altında mesaj
> gösterilir ve 2 sn sonra aynı yüz otomatik yeniden çekilir. Oturum yokken (socket bağlı değil)
> her çekim dummy onayla geçer (`init(simulateServer:)` ile zorlanabilir).
> Kullandığı SDK parçaları: `IdentityScannerView(dismissesOnResult: false, keepsCameraRunning: true,
> scanSession:)` — tarayıcı ekranın parçası olarak gömülür, kamera oturumu yüzler arasında
> kapanmaz; `scanSession` değişince aynı oturumda yeni profille (ön → arka) yeniden çekime hazırlanır.
> Çerçevedeki silik `frontID` / `backID` görselleri `Bundle.sdkUI`'dan gelir. Örnek uygulamada
> **Tam Özel Ekranlar → "Kimlik: tek ekran tarama"** anahtarı ya da Modül Rehberi → Senaryo →
> **Ekran modu** ile açılır. Takmak için: `registry.override(.idCard) { IdCardSingleScreenCustomView() }`


Ekranı siz çizersiniz; OCR + yükleme + adım sinyali SDK VM'inde kalır. Görüntüyü nereden
aldığınıza göre iki yol vardır:

| | A) SDK tarayıcısı (önerilen) | B) Kendi kameranız |
|---|---|---|
| Otomatik çekim | ✅ | ❌ siz tetiklersiniz |
| Mesafe / bulanıklık / parlama kapıları | ✅ | ❌ |
| Belgeye kırpma, pasaport oryantasyon düzeltmesi | ✅ | ❌ |
| Tasarım serbestliği | Çerçeve, çizgi stili, metinler, fener; HUD gizlenemez ([sınırlar](../../../docs/guides/identity-scanner.md#görünüm-ve-davranış-ayarları)) | Tam |
| Risk | — | Bulanık/parlamalı kare → "okunamadı" ya da sunucu karşılaştırma reddi |

> **Arka yüzde neyin zorunlu olduğunu değiştirmek:** `DocumentProfile.turkishIDBack`
> `.settingRequired(false, for: "fatherName")` / `.settingMRZRequired(false)` ile kopyalanıp
> `IdentityScannerView(profile:)`'a verilir; ayrıntı [IdentityScanner rehberi](../../../docs/guides/identity-scanner.md#neyin-çekimi-beklettiğine-profil-karar-verir).
>
> **Otomatik fener, lens geçişi, Elle çek düğmesi, parlama kapısı** `ScannerAutomation` ile
> ayarlanır. Otomatik fener varsayılan kapalı; açmak için
> `ScannerAutomation.default.autoTorch = true`. Ayrıntı:
> [Otomatik Davranışlar](../../../docs/guides/identity-scanner.md#otomatik-davranışlar--scannerautomation).
>
> **Fener düğmesi** `ScannerConfiguration.showsTorchButtonDefault = false` ile gizlenir. Ayrıntı:
> [Fener düğmesi](../../../docs/guides/identity-scanner.md#fener-düğmesi).

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
| `selectionOptions: [CardType]` | Seçim ekranında çizilecek satırlar (config ∩ izinliler) |
| `initialCardType: CardType` | İlk seçili gelen / ekran atlanırsa kullanılan tip |
| `skippedCardType: CardType?` | Ekran atlanacaksa o tip, gösterilecekse `nil`. Atlandığında `onAppear`da bir kez `selectCardType(_:)` çağırın, `notifyDocumentSelectionShown()` **çağırmayın** |
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
