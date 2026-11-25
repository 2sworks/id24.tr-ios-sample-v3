# AddressConfirm — Adres Onayı

Kullanıcı ikamet adresini yazar ve kanıt olarak bir belge ekler — kamerayla çekilmiş ya da
galeriden seçilmiş bir **fotoğraf** veya bir **PDF** (ör. e-Devlet ikametgâh belgesi).
"Devam Et" ile adres + belge tek istekte sunucuya yüklenir.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.addressConf` |
| Rota | `SDKModuleRoute.addressConfirm` |
| Drop-in view | `SDKAddressConfirmView` |
| ViewModel | `SDKAddressConfirmViewModel` |
| Dış dünya | **HTTP** (foto: `uploadAddressInfo` / PDF: `uploadAddressInfoWithPdf`) |
| Ses anahtarı | `AddressConfirmTts` |

## Kullanıcı Ne Yaşar?

1. Adresini metin alanına yazar (alan boş kalamaz).
2. "Belge ekle" ile kaynağını seçer: kamerayla tara, galeriden fotoğraf seç **veya** dosyalardan PDF seç.
3. Adres geçerli + belge ekli olunca "Devam Et" aktifleşir; yükleme biter, akış ilerler.

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKAddressConfirmView` çizilir.

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [AddressConfirmCustomView.swift](AddressConfirmCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.addressConfirm) { AddressConfirmCustomView() }`
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


Örnek uygulamada bu rotanın kaydı `CustomScreens.register(in:)` içindedir
(`RootView.configureIfNeeded` çağırır). Kendi ekranınız için en kısa kayıt:

```swift
registry.override(.addressConfirm) { MyAddressView() }

struct MyAddressView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKAddressConfirmViewModel()

    var body: some View {
        VStack {
            TextField("Adres", text: $vm.addressText)
            Button("Belgeyi tara") { vm.openScanner() }     // yalnız showScanner = true
            Button("PDF seç") { vm.openPDFPicker() }        // yalnız showPDFPicker = true
            Button("Gönder") { vm.submit() }                // ✅ uploadAddressInfo[WithPdf]
                .disabled(!vm.canSubmit)
        }
        // Sunum sizde: bayrakları dinleyip seçiciyi açın, sonucu VM'e geri verin.
        .documentScanner(isPresented: $vm.showScanner, profile: .generic,
                         configuration: .document, navOverlay: { EmptyView() }) { result in
            if case .success(let doc) = result { vm.photoSelected(doc.croppedImage) }   // ✅
        }
        .fileImporter(isPresented: $vm.showPDFPicker, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            vm.pdfSelectedFromURL(url)                                                  // ✅ boyut kontrolü dahil
            if access { url.stopAccessingSecurityScopedResource() }
        }
        .onAppear { vm.onCompleted = { coordinator.advanceToNextModule() } }  // ✅
    }
}
```

`openScanner()` / `openPDFPicker()` hiçbir şey sunmaz, yalnız bayrağı açar. Galeriden seçim de
aynı şekilde: seçilen görseli `photoSelected(_:)` ile verin. PDF sınırı: `vm.maxPDFSizeMB`.

---

## ViewModel Referansı — `SDKAddressConfirmViewModel`

### State (`@Published`)
| Üye | Tip | Anlam |
|---|---|---|
| `addressText` | `String` | Girilen adres |
| `docPhoto` | `UIImage?` | Belge fotoğrafı |
| `pdfData` | `Data?` | Belge PDF'i |
| `showDocumentOptions` | `Bool` | Belge kaynağı seçim sheet'i |
| `showScanner` | `Bool` | Kamera/tarayıcı açık mı |
| `showPDFPicker` | `Bool` | PDF seçici açık mı |

### Hesaplanan
| Üye | Anlam |
|---|---|
| `isAddressValid: Bool` | Adres boş değil mi (`count >= 1`) |
| `canSubmit: Bool` | Adres geçerli **ve** (foto veya PDF) var mı |
| `maxPDFSizeMB: Int` | İzinli en büyük PDF (`manager.maxAddressPDFFileSize`) |

### Metotlar
| Metot | Etki |
|---|---|
| `openScanner()` | Belge tarayıcısını açar |
| `openPDFPicker()` | PDF seçiciyi açar |
| `photoSelected(_ image: UIImage)` | Seçilen fotoğrafı set eder |
| `pdfSelectedFromURL(_ url: URL)` | URL'den PDF yükler |
| `pdfSelected(_ data: Data, preview: UIImage?)` | PDF verisini set eder |
| `submit()` | Adres + belgeyi yükler → `onCompleted`. `canSubmit`'i kendisi denetlemez; kendi ekranınızda çağırmadan önce `canSubmit`'e bakın. Belge yokken çağrılırsa hiçbir şey gönderilmez ve `isLoading` `true` kalır |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onCompleted: (() -> Void)?` | Yükleme başarılı |

## Sinyal Zinciri — Perde Arkası

```
photoSelected / pdfSelected...  → docPhoto / pdfData (UI durumu)
submit()
   ├─ PDF var  → manager.uploadAddressInfoWithPdf [HTTP]
   └─ foto var → manager.uploadAddressInfo        [HTTP]
                                   → onCompleted?()
host: → coordinator.advanceToNextModule() [modulePresented]
```

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class AddressHostViewModel: HostModuleViewModel {
    let sdk = SDKAddressConfirmViewModel()
    override init() {
        super.init(); bridge(sdk)
        sdk.onCompleted = { [weak self] in self?.log("address_done") }
    }
    var canSubmit: Bool { sdk.canSubmit }
    func submit() {
        guard sdk.canSubmit else { return }   // submit() canSubmit'e bakmaz
        sdk.submit()
    }
}
```

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

Bu modülün bir ayrıcalığı vardır: SDK bundle'ında **hazır Türkçe klip** gelir
(`AddressConfirmTts_tr.mp3`). Sesli okuma açıkken ve bu modüle açıkça mod atamadıysanız:
dil TR ise hazır klip çalar; diğer dillerde native okuma devreye girer.

```swift
// Hazır klibi kullanma, native oku:
SDKSpeechConfig.shared.setMode(.native, for: .addressConf)

// Kendi kaydınız — tüm diller için AddressConfirmTts.m4a
// veya dil bazlı AddressConfirmTts_tr.m4a (host dosyası SDK klibini ezer):
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .addressConf)   // dosya yoksa native'e düşer

// Kapalı:
SDKSpeechConfig.shared.setMode(.off, for: .addressConf)
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .addressConfirmTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Foto mu PDF mi?** Biri yeterli — ikisi aynı anda gerekmez.
- **"Devam Et" pasif:** Düğme `canSubmit` ile açılır. Adres alanı boşsa (`isAddressValid`
  `false`) ya da belge eklenmediyse `canSubmit` `false` kalır.
- **PDF sınırı:** `maxPDFSizeMB` SDK'da sabittir: 5 MB (`manager.maxAddressPDFFileSize`).
  Daha büyük dosyayı `pdfSelected` almaz, `errorMessage`'ı doldurur. Fotoğrafın boyutuna
  bakılmaz. Sınırı seçimden önce kullanıcıya gösterin. Hazır ekranın seçimden önce gösterdiği
  `addressFileFormats` metni beş dilde de 15 MB yazar (TR: "PDF, JPG, JPEG, PNG, WEBP, TIFF
  15MB'den az"). Metni her dil için ayrı düzeltin:

  ```swift
  SDKLocalization.shared.setOverride(key: .addressFileFormats, language: .tr,
                                     value: "PDF (en fazla 5 MB), JPG, JPEG, PNG, WEBP, TIFF")
  ```
- **Fotoğraf kalitesi:** SDK, adres belgesini okunaklı kalacak sıkıştırma ayarlarıyla yükler
  (2.5.4'te iyileştirildi) — ekstra sıkıştırma yapmayın.
- **Belge tarayıcısı:** `openScanner()` ile açılan kamera, SDK'nın gerçek zamanlı tarama
  motorunu (`.generic` profil — otomatik kırpma + perspektif düzeltme) kullanır —
  [IdentityScanner rehberi](../../../docs/guides/identity-scanner.md).
