# 3.0.1 — Neler Değişti, Neler Eklendi

Bu sürüm **tema ve özelleştirme** odaklıdır. Tamamı eklemeli (additive) tasarlandı:
hiçbir tema ayarı vermezseniz ekranlar 3.0.0 ile birebir aynı görünür.

Ayrıntılı kullanım için [Tema Rehberi](theming.md), tek sözlükle yapılandırma için aynı
rehberdeki *Tek Sözlükle Tema (JSON)* bölümüne bakın.

---

## Özet

| Alan | 3.0.0 | 3.0.1 |
|---|---|---|
| Buton | 4 stil, sabit kapsül köşe | `SDKTheme.shared.buttons` — köşe, ölçü, font, kenarlık, gölge, haptik; stil bazlı override |
| Başlık çubuğu | tek tasarım | 4 hazır tasarım (`preset`) + ölçü/renk token'ları |
| Renkler | marka paleti | + 18 **rol** token'ı (light/dark ayrı) |
| Bileşenler | koda gömülü ölçüler | `selection` · `alerts` · `banners` · `fields` · `sheets` · `capture` · `controls` · `call` · `motion` |
| Yapılandırma | yalnız Swift API | + sözlük/JSON (`apply`) → RN & Flutter'da `setTheme`, **native derleme gerekmez** |
| Header marka işareti | `.langButton` (yanlış ad) | `.headerLogo` (eski ad çalışmaya devam ediyor) |
| İngilizce dil kodu | `.eng` | `.en` |
| Cihaz ailesi | yalnız iPhone | **iPhone + iPad** (tablette de portrait kilidi) |
| Donanımsız cihaz | canlılık modülü akıştan düşerdi | `faceTrackingFallback` — yerine ne geleceğini entegrasyon seçer |
| Canlılık adımı geçişi | sessiz | çok kısa onay titreşimi (`stepFeedbackEnabled`) |

---

## Yeni

### 1. Buton görünümü — `SDKTheme.shared.buttons`

```swift
SDKTheme.shared.buttons.base.corner = .radius(12)     // .capsule (varsayılan) | .radius(0)=köşeli
SDKTheme.shared.buttons.base.height = 54
SDKTheme.shared.buttons[.secondary].borderWidth = 1
SDKTheme.shared.buttons.reset()
```

Alanlar: `corner`, `height`, `verticalPadding`, `horizontalPadding`, `font`, `background`,
`foreground`, `borderWidth`, `borderColor`, `shadowColor`, `shadowRadius`, `shadowOffsetY`,
`disabledOpacity`, `pressedScale`, `hapticsEnabled`, `fullWidth`.

Köşe ayarı yalnız `SDKButton`'ı değil, hazır ekranlardaki **tüm aksiyon butonlarını** kapsar
(görüşme, ThankYou, bağlantı koptu, kimlik kartı, uyarı diyalogları). Kendi ekranınızda aynı
biçimi yakalamak için:

```swift
Text("Devam").padding().background(IDColor.primary)
    .clipShape(SDKButtonShape.themed())
```

### 2. Başlık çubuğu tasarımları — `SDKTheme.shared.navBar`

```swift
SDKTheme.shared.navBar.preset = .centered
```

| Preset | Yerleşim |
|---|---|
| `.classic` | Solda geri, yanında marka işareti + başlık (varsayılan) |
| `.centered` | Başlık ve marka işareti ortada |
| `.minimal` | Marka işareti yok, ince çubuk (48pt) |
| `.prominent` | İki satır: üstte kontroller, altta büyük başlık |

İnce ayar: `height`, `showsLogo`, `logoSize`, `circleButtonSize`, `iconSize`, `titleFont`,
`subtitleFont`, `progressHeight`, `progressSpacing`, `progressCorner`,
`overlayGradientOpacity`, `showsDivider`.

**Marka başlığı** — çubuk artık adım adı yerine markanızı yazabilir:

```swift
SDKTheme.shared.navBar.brandTitle = "Acme Bank"
SDKTheme.shared.navBar.titleMode  = .brandWithModule   // .module | .brand | .brandWithModule
```

JSON: `"navBar": { "brandTitle": "Acme Bank", "titleMode": "brandWithModule" }`.
`.prominent` yüksekliği 92'ye çıktı (iki satır; 56'da başlık alttaki bileşene biniyordu).
Geri / yardım / menü ikonları `setIcon(.back | .help | .hamburger, …)` ile değişir.
Ayrıntı: [Tema → Başlık Metni](theming.md#başlık-metni--marka-adı).

### 3. Rol renkleri — `SDKAdaptiveColor`

Marka renkleri ile yüzey rolleri ayrıldı. Artık `primary`'yi değiştirmeden yalnız seçili
satırın ya da yalnız başlık çubuğunun rengini ayarlayabilirsiniz.

```swift
SDKTheme.shared.colors.pageBackground =
    SDKAdaptiveColor(light: Color(hex: "#F8FAFC"), dark: Color(hex: "#0B1120"))
SDKTheme.shared.colors.selectedItemBackground = SDKAdaptiveColor(Color.black)
```

Roller: `pageBackground`, `moduleBackground`, `surface`, `title`, `subtitle`, `border`,
`headerBackground`, `headerTitle`, `headerSubtitle`, `headerIcon`, `headerIconBackground`,
`headerIconBorder`, `progressActive`, `progressInactive`, `selectedItemBackground`,
`selectedItemText`, `unselectedItemBackground`, `unselectedItemText`.

Bunlara ek olarak `colors.accentWarning` (sesli okuma ekranlarının turuncu aksanı) artık
temadan gelir; önceden koda gömülüydü.

### 4. Bileşen görünüm kapları

`SDKTheme.shared.` altında: `selection`, `alerts`, `banners`, `fields`, `sheets`, `capture`,
`controls`, `call`, `motion`. Alan listeleri [Tema Rehberi](theming.md#bileşen-görünümleri)
tablosundadır. Hepsinde kural aynı: alan `nil` → SDK varsayılanı.

`motion` ile akış geçiş süreleri ayarlanır, `motion.disabled = true` animasyonları kapatır.

### 5. Tek sözlükle tema (JSON) ve köprüler

```swift
SDKTheme.shared.apply([
    "colors": ["primary": "#0F172A",
               "pageBackground": ["light": "#F8FAFC", "dark": "#0B1120"]],
    "navBar": ["preset": "centered"],
    "buttons": ["corner": 12],
    "icons": ["headerLogo": "my_mark"]          // host asset adı
])
SDKTheme.shared.applyTheme(named: "theme")      // Bundle'daki theme.json
SDKTheme.shared.resetAppearance()
```

`apply(...)` tanınmayan anahtarların listesini döndürür — yazım hatası sessizce kaybolmaz.

React Native ve Flutter köprüleri aynı şemayı kullanır; **renk/logo denemesi için native
derleme gerekmez**, JS/Dart reload yeterlidir:

```ts
const { unknownKeys } = await IdentifySdk.setTheme({ navBar: { preset: 'minimal' } });
IdentifySdk.resetTheme();
```

Örnek dosya: [`docs/integration/theme.example.json`](../integration/theme.example.json).
TS tipleri `IdentifySdk.ts` içindeki `SDKThemeConfig`.

### 6. `IDFont.custom(_:_:)`

Tasarım ölçeği dışındaki tek seferlik boyutlar için. `.system(size:)` yerine bunu kullanın;
aksi hâlde `fonts.familyName` verildiğinde o metin sistem fontunda kalır.

### 7. iPad desteği ve yetenek tabanlı modül ikamesi

SDK artık iPad'de çalışır; yönelim tablette de portrait'e kilitlidir. Donanım isteyen
modüller için karar **akış kurulurken** verilir ve yedeği siz belirlersiniz:

```swift
IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan
IdentifyManager.shared.faceTrackingFallback = .skip     // adımı tamamen çıkar
// setupSDK'dan ÖNCE
```

TrueDepth kamera yoksa (Touch ID'li iPad, Face ID'siz iPhone) `livenessDetection` ve
`selfieWithLiveness` bu politikaya göre değiştirilir; Face ID'li iPad Pro / iPad Air'de her
iki modül de olduğu gibi çalışır. NFC'siz cihazlarda panele artık
`NFCStatus = notAvailable` bildirilir.

Yerleşim tarafında ölçüler ekran değil **pencere** tabanlıdır (`SDKLayout.bounds`), metin
sütunları `.sdkReadableWidth()` ile, kılavuz çerçeveleri `SDKLayout.maxGuideWidth` /
`maxFaceGuideWidth` ile sınırlanır. Tam ayrıntı: [iPad Desteği](ipad-support.md).

### 8. Canlılık adımlarında onay titreşimi

Her onaylanan canlılık adımında tek ve çok kısa bir darbe çalınır (2.x'te vardı, 3.0.0'da
yoktu). Varsayılan **açık**:

```swift
SDKHapticConfig.shared.stepFeedbackEnabled = false   // kapat
SDKHapticConfig.shared.stepFeedbackIntensity = 0.4   // 0…1, vars. 0.6
```

Modül anahtarı (`setEnabled(_:for:)`) hem çekim rampasını hem bu darbeyi kapsar.
Ayrıntı: [Tema Rehberi — Titreşim](theming.md#titreşim-haptik).

---

## Değişti

- **Header'daki marka işaretinin anahtarı `.headerLogo` oldu.** 3.0.0'da bu görsel
  `.langButton` anahtarıyla çiziliyordu (v2'den kalma bir asset adı) ve `.logo`'yu ezmek
  header'ı değiştirmiyordu. `.logo` giriş ekranı ve kamera üstü başlıkta kullanılmaya
  devam ediyor.

  ```swift
  SDKTheme.shared.setIcon(.headerLogo, Image("my_mark"))
  ```

  `.langButton` ile yapılmış mevcut override'lar **çalışmaya devam eder**; yeni kod
  `.headerLogo` kullanmalıdır.

- **Sayfa arka planları artık override edilebilir.** 3.0.0'da açık temada sayfa zemini
  koda gömülü beyazdı; kamera/modül ekranları ise doğrudan `primary` kullanıyordu. İkisi de
  rol token'ına bağlandı (`pageBackground`, `moduleBackground`).

- **Seçim satırları kendi rollerini kullanıyor.** Hazırlık ekranındaki izin satırları ve
  belge türü seçimi artık `selectedItem*` / `unselectedItem*` rollerinden besleniyor;
  `primary` değiştiğinde bunlar zorunlu olarak birlikte değişmiyor.

- **İngilizce dil kodu `.eng` yerine `.en`.** ISO 639-1 ile hizalandı.

- **Sabit ölçüler token'landı:** seçim satırı köşe/yükseklik, alan köşeleri, uyarı kartı
  ölçüleri, sheet tutamağı, kamera maskesi opaklığı, kılavuz çerçevesi renkleri, kayıt
  butonu ölçüsü.

---

## Geçiş Adımları

Çoğu proje için yapılacak bir şey yok. Aşağıdakiler yalnız ilgili API'yi kullanıyorsanız
gerekir:

1. **`SDKLang.eng` → `SDKLang.en`**

   ```swift
   IdentifyManager.shared.setSDKLang(lang: .en)      // eskiden .eng
   SDKLocalization.shared.registerOverrides([.en: ["Continue": "Proceed"]])
   ```

   - `.eng` hâlâ derlenir (deprecated uyarısıyla), ancak **`switch` içinde
     `case .eng:` deseni derlenmez** — bu tek kırılma noktasıdır, derleme hatası verir.
   - `SDKLang(rawValue: "eng")` çalışmaya devam eder; kayıtlı tercihini `"eng"` olarak
     saklayan projeler etkilenmez.
   - Kendi ses paketinizde İngilizce klipleri `<ad>_eng` olarak adlandırdıysanız
     dosyaları yeniden adlandırmanıza gerek yok: yeni ad (`<ad>_en`) bulunamazsa eski ad
     denenir. Yeni paketlerde `_en` kullanın.

2. **Header logosu.** `.langButton` override'ınız varsa `.headerLogo`'ya taşıyın (davranış
   aynı, ad doğru).

3. **Kendi ekranlarınızda `.font(.system(size:))`** kullanıyorsanız `IDFont.custom(_:_:)`
   ile değiştirin ki tema fontu bu metinlerde de geçerli olsun.

---

## Kapanış Animasyonu Hakkında

SDK akışı kendini **sunmaz ve kapatmaz** — sunum da kapanış da host uygulamaya aittir.
"Ekran animasyonsuz kapanıyor" durumu, akışın barındığı görünümün animasyonsuz
kaldırılmasından gelir:

```swift
host.modalPresentationStyle = .fullScreen
host.modalTransitionStyle = .coverVertical
presenter.present(host, animated: true)
...
host.dismiss(animated: true)     // animated: false ANINDA kapatır
```

React Native tarafında akışı `<Modal animationType="slide">` içinde gösterin. Akış
**içindeki** adım geçişlerinin süresi tema üzerinden ayarlanır:
`SDKTheme.shared.motion.transitionDuration`.

---

## Sample App'te Nerede Görebilirim?

Showcase → **Tasarım Sistemi** bölümü:

| Kart | İçerik |
|---|---|
| Buton | 4 stil + köşe/yükseklik/kenarlık/gölge/haptik canlı kontrolleri, üretilen kod bloğu |
| Nav Bar | 4 preset seçici, marka işareti ve ayırıcı anahtarları, 4 stilin canlı önizlemesi |
| JSON ile Tema | 3 hazır tema, düzenlenebilir JSON, uygula/sıfırla, tanınmayan anahtar raporu |
| Renkler / Tipografi | token paleti ve ölçek |
| Özelleştirme | ikon + metin override demosu |
