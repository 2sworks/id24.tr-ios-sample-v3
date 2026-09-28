# Lokalizasyon — Dil Desteği ve Metin Override

> 3.1.0 ile İngilizcenin dil kodu `.eng` yerine `.en` oldu. `.eng` eski ad olarak derlenmeye
> devam ediyor. Ayrıntı: [3.1.0 Değişiklik Rehberi](migration-3.1.0.md).

SDK beş dille gelir: Türkçe, İngilizce, Almanca, Azerbaycanca ve Rusça. Ekrandaki her metnin
bir anahtarı vardır (`SDKKeyword`) ve her birini kendi metninizle değiştirebilirsiniz.

← [README'ye dön](../../README.md) · İlgili: [Tema](theming.md) · [ReadAloud](../../IdentifySample/Modules/ReadAloud.md)

---

## Dil Seçimi

Dili `IdentifyManager` üzerinden seçersiniz. Varsayılan Türkçedir; tanınmayan bir dil gelirse
İngilizce kullanılır.

```swift
IdentifyManager.shared.sdkLang = .en     // .tr / .en / .de / .az / .ru
```

| `SDKLang` | Dil | STT kodu |
|---|---|---|
| `.tr` | Türkçe | `tr` |
| `.en` | İngilizce | `en` |
| `.de` | Almanca | `de` |
| `.az` | Azerbaycanca | `az` |
| `.ru` | Rusça | `ru` |

Seçtiğiniz dil ekran metinlerinin yanında konuşma tanımanın (Speech modülü) ve sesli okumanın
(Read-Aloud) dilini de belirler.

> OCR'ın ayrı bir ayarı var: `setupSDK(idCardLang:)`, belgenin üzerindeki yazının dilidir.

---

## Metinleri Okumak

SDK bütün metinleri `SDKKeyword` üzerinden çözer. Kendi ekranınızda SDK'nın kullandığı metnin
aynısını göstermek için:

```swift
let title = SDKLocalization.shared.translate(.connect)
```

---

## Metinleri Ezmek (Override)

Üç yolu var. Hepsi çalışma zamanında uygulanır; `setupSDK`'dan önce çağırın.

### 1. Tek metin

```swift
SDKLocalization.shared.setOverride(key: .connect, language: .tr, value: "Bağlan")
```

### 2. Toplu sözlük

```swift
SDKLocalization.shared.registerOverrides([
    .tr: ["connect": "Bağlan", "selfie_info": "Yüzünüzü çerçeveye alın"],
    .en: ["connect": "Connect"]
])
```

### 3. Dosyadan yükleme

Metinleri bir JSON dosyasına koyup tek seferde yükleyebilirsiniz. Dosyayı sunucudan
indirirseniz metinleri uygulamayı güncellemeden değiştirmiş olursunuz.

```swift
if let url = Bundle.main.url(forResource: "sdk_texts_tr", withExtension: "json") {
    SDKLocalization.shared.loadOverrides(from: url, language: .tr)
}
```

`clearOverrides()` bütün ezmeleri kaldırır, `clearCache()` çeviri önbelleğini yeniler.

---

## Sesli Okuma Metinleri

Modül yönergelerinin sesli halleri de aynı sistemden geçer. Her modülün bir `*Tts` anahtarı
vardır (ör. `.selfieTts`), yani sesli metni ekrandaki metne dokunmadan değiştirebilirsiniz:

```swift
SDKLocalization.shared.setOverride(
    key: .selfieTts, language: .tr,
    value: "Lütfen yüzünüzü ekrandaki çerçeveye hizalayın."
)
```

Ayrıntı: [ReadAloud rehberi](../../IdentifySample/Modules/ReadAloud.md).

---

## İpuçları

- Override, `SDKKeyword.rawValue` ile eşleşir. 400'den fazla anahtarın tam listesi SDK'daki
  `SDKKeyword` enum'ında. Bir metnin anahtarını ilgili modülün rehberinde de bulabilirsiniz.
- SDK'nın başlık çubuğunda hazır bir dil düğmesi var (`langButton` ikonu). Dil seçimini kendi
  arayüzünüzde yapıyorsanız `sdkLang`'i güncellemeniz yeterli.
