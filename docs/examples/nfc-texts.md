# Örnek: NFC Metinlerini Özelleştirme

NFC okuma adımında ekranda görünen ve seslendirilen metinleri değiştirmenin yolları. Buradaki
yöntemler 3.1.2 ve sonraki sürümlerde çalışır.

← [README'ye dön](../../README.md) · İlgili: [Lokalizasyon](../guides/localization.md) · [NFC modülü](../../IdentifySample/Modules/NFC/NFC.md)

---

## Genel bakış

| Alan | Yöntem |
|---|---|
| iOS NFC penceresindeki bilgi satırı | Metin override'ı ya da `nfcMsgHandler` |
| Okuma ilerlemesinin gösterimi (yüzde, emoji çubuğu vb.) | `nfcMsgHandler` |
| SDK'nın hazır NFC ekranındaki metinler | Metin override'ı |
| Sesli yönlendirmeler | Metin override'ı |

iOS NFC penceresindeki "Tarama için Hazır" başlığını, telefon görselini ve "Vazgeç" düğmesini iOS
çizer. Uygulama bunları değiştiremez.

## 1. iOS NFC penceresindeki bilgi satırı

NFC okuması sırasında iOS'un açtığı pencerede başlığın altında bir bilgi satırı bulunur. SDK bu
satırı okumanın durumuna göre günceller:

| Durum (`NFCViewDisplayMessage`) | Metin anahtarı | Varsayılan metin (TR) |
|---|---|---|
| `.requestPresentPassport` | `.nfcScanId` / `.nfcScanPassport` | "Kimliği okutun" / "Pasaportu okutun" |
| `.authenticatingWithPassport(Int)` | `.idVerifyingFmt` | "Kimlik doğrulanıyor: %@%%" |
| `.readingDataGroupProgress(_, Int)` | `.dataReadingFmt` | "Veri okunuyor: %@%%" |
| `.error(NFCPassportReaderError)` | `.errorOccurred` | "Bir sorun oluştu, lütfen tekrar deneyin." |
| `.successfulRead` | `.coreSuccess` | "Başarılı" |

### Yöntem A: Metin override'ı

Yalnız metni değiştirmek için yeterlidir:

```swift
let loc = SDKLocalization.shared
loc.setOverride(key: .nfcScanId,      language: .tr, value: "Kimliğini telefonun arka kamerasına dokundurarak okuma tamamlanana kadar bekle.")
loc.setOverride(key: .idVerifyingFmt, language: .tr, value: "Kimlik doğrulanıyor %%%@")
loc.setOverride(key: .dataReadingFmt, language: .tr, value: "Bilgiler okunuyor %%%@")
```

- Adı `Fmt` ile biten metinlerde `%@` kalmalı. SDK ilerleme yüzdesini oraya yazar.
- Yüzde işareti için `%%` yazın.
- `.errorOccurred` ve `.coreSuccess` başka ekranlarda da kullanılır. Bunları değiştirmek o
  ekranlardaki metni de değiştirir.

### Yöntem B: `nfcMsgHandler` ile özel gösterim

İlerlemeyi emoji çubuğu gibi başka bir biçimde göstermek ya da hata türüne göre ayrı mesaj vermek
için `IdentifyManager.shared.nfcMsgHandler` kullanın. SDK ilerlemeyi bu fonksiyona 0-100 arası tam
sayı olarak verir. Fonksiyonun döndürdüğü metin iOS NFC penceresinde görünür.

```swift
func ilerlemeCubugu(_ yuzde: Int) -> String {
    let dolu = min(5, max(0, yuzde / 20))
    return String(repeating: "🟢 ", count: dolu) + String(repeating: "⚪️ ", count: 5 - dolu)
}

let nfcVM = SDKNfcViewModel()                         // SDK kendi handler'ını burada kurar
let sdkHandler = IdentifyManager.shared.nfcMsgHandler
IdentifyManager.shared.nfcMsgHandler = { msg in
    let sdkText = sdkHandler?(msg) ?? ""              // SDK'nın sesli yönlendirmesi ve durum güncellemesi korunur
    switch msg {
    case .requestPresentPassport:
        return "Kimliğini telefonun arka kamerasına dokundur."
    case .authenticatingWithPassport(let yuzde):
        return "Kimlik doğrulanıyor\n\n" + ilerlemeCubugu(yuzde)
    case .readingDataGroupProgress(_, let yuzde):
        return "Bilgiler okunuyor\n\n" + ilerlemeCubugu(yuzde)
    case .error(let hata):
        switch hata {
        case .ConnectionError: return "Bağlantı koptu, kimliği sabit tut."
        case .InvalidMRZKey:   return "Kimlik bilgileri çiple eşleşmedi."
        case .TagNotValid:     return "Bu kart okunamıyor."
        default:               return sdkText
        }
    case .successfulRead:
        return "Okuma tamamlandı"
    }
}
nfcVM.startNFC()
```

- Handler'ı `SDKNfcViewModel()` oluşturulduktan sonra atayın. View model oluşurken kendi
  handler'ını kurar ve önceden atanmış handler'ın yerine geçer.
- Örnek önce SDK'nın handler'ını çağırır. Okuma sırasındaki sesli yönlendirme ve "Okuma
  tamamlandı" durumu bu sayede çalışır. SDK handler'ı çağrılmazsa ikisi de devre dışı kalır.
- Görüntülü görüşme sırasındaki NFC okumasında handler'ı SDK yönetir. Bu yöntem o akışı
  kapsamaz.

## 2. SDK'nın hazır NFC ekranındaki metinler

| Anahtar | Varsayılan metin (TR) |
|---|---|
| `.nfcVerifyTitle` | "NFC ile Doğrulama" |
| `.nfcScanTitle` | "NFC Tarama" |
| `.nfcChipInstruction` | "Kimliğinizi telefonunuzun arkasına yaklaştırarak çipi okutun." |
| `.nfcChipInstructionPassport` | "Pasaportunuzu telefonunuzun arkasına yaklaştırarak çipi okutun." |
| `.nfcHoldInstruction` | "NFC okutma işlemi için lütfen kimlik kartınızı telefonunuzun önüne tutunuz." |
| `.nfcHoldInstructionPassport` | "NFC okutma işlemi için lütfen pasaportunuzu telefonunuzun önüne tutunuz." |
| `.nfcStart` | "Taramayı başlat" |
| `.nfcStarting` | "NFC başlatılıyor..." |
| `.readingCompleted` | "Okuma tamamlandı" |
| `.nfcSuccess` | "Kimliğiniz başarıyla tanımlandı" |
| `.nfcInfoNotRead` | "Bilgiler okunamadı" |
| `.nfcManualEntry` | "Lütfen kimlik bilgilerinizi manuel olarak girin." |
| `.nfcEditInfoTitle` | "Bilgileri Düzenle" |
| `.serialNoShort` | "Seri No" |
| `.serialNoPassport` | "Pasaport No" |
| `.coreBirthday` | "Doğum Tarihi" |
| `.nfcExpDate` | "Son Geçerlilik Tarihi" |
| `.nfcSerialInvalid` | "Geçerli bir seri numarası girin (örn. A32R17869)." |
| `.nfcSerialInvalidPassport` | "Geçerli bir pasaport numarası girin (örn. U12345678)." |
| `.coreUpdate` | "Güncelle" (başka ekranlarda da kullanılır) |

```swift
SDKLocalization.shared.setOverride(key: .nfcVerifyTitle, language: .tr, value: "NFC ile Doğrula")
```

## 3. Sesli yönlendirmeler

| Anahtar | Varsayılan metin (TR) |
|---|---|
| `.nfcTts` | "Kimliğinizi telefonunuzun ön yüzüne yerleştirin ve sabit tutun." |
| `.nfcPassportTts` | "Pasaportunuzu telefonunuzun ön yüzüne yerleştirin ve sabit tutun." |
| `.nfcReadingTts` | "Okuma devam ediyor, lütfen belgenizi hareket ettirmeyin." |
| `.nfcSuccessTts` | "Çip okuma tamamlandı." |
| `.nfcErrorTts` | "Okuma tamamlanamadı. Lütfen belgenizi telefonun ön yüzüne yeniden yerleştirin." |

Varsayılan sesli metinler "ön yüz" der. Ekrandaki metinde "arka kamera" kullanıyorsanız
`.nfcTts`, `.nfcPassportTts` ve `.nfcErrorTts` anahtarlarını da aynı ifadeye çekin.

## 4. Birden fazla metni tek seferde değiştirme

`registerOverrides` metin dosyasındaki anahtar adlarıyla çalışır:

```swift
SDKLocalization.shared.registerOverrides([
    .tr: [
        "NfcScanId": "Kimliğini telefonun arka kamerasına dokundurarak okuma tamamlanana kadar bekle.",
        "NfcVerifyTitle": "NFC ile Doğrula",
        "NfcChipInstruction": "Kimliğini telefonun arkasına yaklaştır.",
        "NfcTts": "Kimliğini telefonun arkasına yaklaştır ve sabit tut."
    ]
])
```

## Notlar

- Override'ları NFC adımı başlamadan önce, örneğin uygulama açılışında tanımlayın.
- Override'lar dil bazında çalışır. `.en`, `.de`, `.az` ve `.ru` için ayrıca tanımlayın.
- `SDKLocalization.shared.clearOverrides()` bütün override'ları kaldırır.
