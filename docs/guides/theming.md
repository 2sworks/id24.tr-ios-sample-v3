# Tema — SDK Ekranlarını Markanıza Boyamak

> 3.0.1 ile gelen yenilikler ve geçiş adımları: [3.0.1 Değişiklik Rehberi](migration-3.0.1.md)

SDK'nın hazır ekranları tek bir tema kaynağından beslenir: **`SDKTheme.shared`**.
Renkleri, fontu, ikonları ve boşluk/köşe metriklerini `setupSDK`'dan önce bir kez ayarlarsınız;
tüm drop-in ekranlar otomatik olarak markanıza bürünür — **hiçbir ekranı yeniden yazmadan.**

← [README'ye dön](../../README.md) · İlgili: [Özelleştirme](customization.md) (ekranın tamamını değiştirmek için)

---

## İki Seviye Özelleştirme

1. **Tema (bu rehber)** — SDK ekranları kalır, görünümleri değişir. Çoğu marka uyumu için yeterli.
2. **Ekran override** — ekranın tamamını kendi tasarımınızla değiştirirsiniz.
   → [Özelleştirme Rehberi](customization.md)

---

## Hızlı Başlangıç

```swift
// Uygulama açılışında, setupSDK'dan ÖNCE — bir kez.
let theme = SDKTheme.shared

// Renkler
theme.colors.primary      = Color(hex: "#E4002B")     // marka ana rengi
theme.colors.primaryDark  = Color(hex: "#B80023")
theme.colors.success      = Color(hex: "#0BA34E")

// Font ailesi (uygulamada kayıtlı bir custom font)
theme.fonts.familyName = "Sofia Pro"

// İkon/illüstrasyon değişimi
theme.setIcon(.logo, Image("my_bank_logo"))
theme.setIcons([
    .thankYouSuccess: Image("my_success_hero"),
    .lostConnection:  Image("my_offline_hero"),
])
```

---

## Token Sistemi

SDK ekranları renk/font/boşluk değerlerini asla elle yazmaz; her şey token üzerinden okunur.
Token'lar `SDKTheme.shared`'a bakar — siz temayı değiştirince tüm ekranlar değişir.

| Token ailesi | Örnek | Kaynağı |
|---|---|---|
| `IDColor` | `IDColor.primary`, `IDColor.error` | `theme.colors` (`SDKColors`) |
| `IDFont` | `IDFont.font(size:weight:)` | `theme.fonts` (`SDKFonts`) |
| `IDSpacing` | `IDSpacing.md` (12pt) | `theme.metrics` (`SDKMetrics`) |
| `IDRadius` | `IDRadius.card` (36pt) | `theme.metrics` |
| `SDKButtonShape` | `SDKButtonShape.themed()` | `theme.buttons` (`SDKButtons`) |

Kendi custom ekranlarınızda da bu token'ları kullanabilirsiniz — böylece override ettiğiniz
ekran, SDK'nın geri kalanıyla otomatik uyumlu kalır.

### Renk Paleti — `SDKColors`

| Grup | Üyeler |
|---|---|
| Marka | `primary` · `primaryDark` · `primaryLight` |
| Başarı | `success` · `successAlt` · `successBright` |
| Hata | `error` |
| Metin/yüzey (ink) | `inkDarkest` · `inkDark` · `inkMid` · `inkLight` · `inkBorder` · `inkBackground` · `inkSurface` · `inkSubtitle` |
| Koyu yüzeyler | `darkBg` · `darkBgSecondary` · `darkMuted` |
| Diğer | `divider` · `accentPurple` · `accentTeal` |

### Fontlar — `SDKFonts`

- `familyName` — tek satırla tüm SDK tipografisini değiştirir (varsayılan: **Inter**).
- Font uygulamanızda kayıtlı değilse çalışma zamanında yükleyebilirsiniz:

```swift
SDKTheme.shared.registerFont(at: fontFileURL)     // ya da
SDKTheme.shared.registerFont(data: fontData)      // bundle'a gömülü veri
SDKTheme.shared.fonts.familyName = "Sofia Pro"
```

### Metrikler — `SDKMetrics`

Boşluklar (`spacingXS` 4 → `spacingXXL` 32) ve köşe yarıçapları (`radiusSM` 8 →
`radiusCard` 36). Daha keskin köşeli bir görünüm için örneğin:

```swift
SDKTheme.shared.metrics.radiusCard = 12
```

### Butonlar — `SDKButtons`

SDK'nın aksiyon butonlarının tüm görünümü `SDKTheme.shared.buttons` üzerinden ayarlanır.
Her alan opsiyoneldir: dokunmadığınız her şey SDK varsayılanında kalır.

```swift
// Tüm butonlar — köşe:
SDKTheme.shared.buttons.base.corner = .radius(12)   // .capsule (varsayılan) | .radius(0) = köşeli
SDKTheme.shared.setButtonCorner(.capsule, for: .cancel)   // yalnızca tek stil

// Tüm butonlar — ölçü, tipografi, geri bildirim:
SDKTheme.shared.buttons.base.height          = 56
SDKTheme.shared.buttons.base.verticalPadding = 18      // height verilmediğinde geçerli
SDKTheme.shared.buttons.base.font            = IDFont.bodyLarge(.bold)
SDKTheme.shared.buttons.base.shadowColor     = .black.opacity(0.25)
SDKTheme.shared.buttons.base.shadowRadius    = 12
SDKTheme.shared.buttons.base.shadowOffsetY   = 6
SDKTheme.shared.buttons.base.pressedScale    = 0.94
SDKTheme.shared.buttons.base.disabledOpacity = 0.30
SDKTheme.shared.buttons.base.hapticsEnabled  = false

// Stile özel — outline buton:
SDKTheme.shared.buttons[.secondary].background  = .clear
SDKTheme.shared.buttons[.secondary].borderWidth = 1
SDKTheme.shared.buttons[.secondary].borderColor = IDColor.divider

SDKTheme.shared.buttons.reset()   // her şeyi varsayılana döndür
```

| Alan | Varsayılan |
|---|---|
| `corner` | `.capsule` |
| `height` | `nil` (dikey padding'e göre) |
| `verticalPadding` / `horizontalPadding` | `IDSpacing.lg` / `0` |
| `font` | `IDFont.bodyMedium(.semibold)` |
| `background` / `foreground` | stilin tema rengi |
| `borderWidth` / `borderColor` | `0` / metin rengi |
| `shadowColor` / `shadowRadius` / `shadowOffsetY` | gölge yok |
| `disabledOpacity` | `0.45` |
| `pressedScale` | `0.97` |
| `hapticsEnabled` | `true` |
| `fullWidth` | `true` |

Köşe ayarı yalnızca `SDKButton`'ı değil, hazır ekranlardaki tüm aksiyon butonlarını kapsar
(görüşme ekranı, ThankYou, bağlantı koptu, kimlik kartı, uyarı diyalogları). Kendi custom
ekranınızda aynı biçimi yakalamak için `SDKButtonShape` kullanın:

```swift
Text("Devam")
    .padding()
    .background(IDColor.primary)
    .clipShape(SDKButtonShape.themed())          // aktif temanın köşesi
```

---

## İkonlar ve İllüstrasyonlar — `SDKIconKey`

Her görsel öğe bir anahtarla değiştirilebilir; anahtarların tam listesi `SDKIconKey`
(`CaseIterable`) enum'ındadır. Önemli gruplar:

| Grup | Anahtarlar |
|---|---|
| Nav / chrome | `logo` · **`headerLogo`** · `hamburger` · `back` · `help` · `close` · `langButton` (eski ad) |
| Aksiyonlar | `retry` · `checkmark` · `camera` · `trash` · `video` · `chat` · `calendar` · `chevronRight` · `signLang` ... |
| İzin satırları (Prepare) | `permCamera` · `permMic` · `permSpeech` · `permIdCard` · `permAlone` · `permConditions` |
| İllüstrasyonlar | `incomingCall` · `nfcFront` · `nfcBack` · `thankYouSuccess` · `thankYouFail` · `uploadFile` · `lostConnection` · `idCardFront` · `idCardBack` |
| Durum/kontrol | `successCircle` · `failCircle` · `play` · `pause` · `mic` · `stopRecord` · `torchOn` · `torchOff` · `wifiGood` · `wifiBad` |
| Belge türü seçimi | `idTypeChip` · `idTypePassport` · `idTypeOther` |

```swift
theme.setIcon(.nfcFront, Image("my_nfc_illustration"))
theme.resetIcon(.nfcFront)      // SDK varsayılanına dön
```

> **Header'daki marka işareti `.logo` değil, `.headerLogo`'dur.** `.logo` giriş ekranı ve
> kamera üstü başlıkta, `.headerLogo` ise modül/ilerleme başlığındaki yuvarlak işarette
> kullanılır. Eski entegrasyonlar bu işareti `.langButton` ile override ediyordu; o ad
> hâlâ çalışır ama yeni kod `.headerLogo` kullanmalıdır.
>
> ```swift
> theme.setIcon(.headerLogo, Image("my_mark"))
> ```

Override etmediğiniz her anahtar SDK'nın kendi görselini kullanır.

---

## Rol Renkleri

Marka renkleriyle (`primary`, `success`, `error`) **yüzey rolleri** ayrıdır. Rol vermezseniz
SDK bugünkü davranışını sürdürür; verdiğinizde yalnız o yüzey değişir — örneğin `primary`'yi
değiştirmeden seçili satırın rengini ayarlayabilirsiniz.

```swift
// Tek renk (iki temada da aynı):
SDKTheme.shared.colors.selectedItemBackground = SDKAdaptiveColor(Color.black)
// Açık/koyu ayrı:
SDKTheme.shared.colors.pageBackground = SDKAdaptiveColor(light: Color(hex: "#F8FAFC"),
                                                         dark:  Color(hex: "#0B1120"))
```

| Rol | Nerede | Varsayılan |
|---|---|---|
| `pageBackground` | bilgi/form ekranlarının zemini | light: beyaz · dark: `darkBg` |
| `moduleBackground` | kamera/modül ekranlarının marka zemini | light: `primary` · dark: `darkBg` |
| `surface` | kart, sheet, yükseltilmiş yüzey | `inkSurface` / `darkBgSecondary` |
| `title` · `subtitle` · `border` | metin ve ayırıcılar | `inkDarkest`/beyaz · `inkLight`/`darkMuted` · `inkBorder`/beyaz %8 |
| `headerBackground` | başlık çubuğu zemini | şeffaf (sayfa zemini görünür) |
| `headerTitle` · `headerSubtitle` · `headerIcon` | başlık metinleri ve glifleri | `title` / `subtitle` / `inkDark`-beyaz |
| `headerIconBackground` · `headerIconBorder` | geri/yardım daire butonları | systemGray6 / systemGray4 |
| `progressActive` · `progressInactive` | ilerleme çubuğu | `primary` / `inkBorder` |
| `selectedItemBackground` · `selectedItemText` | seçili satır/kutu | `primary` / `primaryLight` |
| `unselectedItemBackground` · `unselectedItemText` | seçili olmayan satır | `divider` %20 / `darkMuted` |

Kamera üstüne çizilen katmanlarda (kılavuz çerçevesi, maske, uyarı yazıları) beyaz/siyah
seçimleri **okunabilirlik** gereğidir; `capture` token'larıyla değiştirilebilir ama kontrast
testini kendi görsellerinizle yapın.

---

## Başlık Çubuğu — Hazır Tasarımlar

```swift
SDKTheme.shared.navBar.preset = .centered
```

| Preset | Yerleşim |
|---|---|
| `.classic` | Solda geri, yanında marka işareti + başlık (SDK varsayılanı) |
| `.centered` | Başlık ve marka işareti ortada, geri solda |
| `.minimal` | Marka işareti yok, ince çubuk (48pt) |
| `.prominent` | İki satır: üstte kontroller, altta büyük başlık |

İnce ayar (`SDKTheme.shared.navBar`): `height`, `showsLogo`, `logoSize`, `circleButtonSize`,
`iconSize`, `titleFont`, `subtitleFont`, `progressHeight`, `progressSpacing`, `progressCorner`,
`overlayGradientOpacity`, `showsDivider`.

---

## Bileşen Görünümleri

Buton (`buttons`) ile aynı kalıp: her alan opsiyonel, `nil` → SDK varsayılanı.

| Kap | Alanlar |
|---|---|
| `SDKTheme.shared.selection` | `cornerRadius` · `rowMinHeight` · `checkboxSize` · `checkboxCornerRadius` · `radioDotSize` · `checkmarkColor` |
| `SDKTheme.shared.alerts` | `cornerRadius` · `maxWidth` · `shadowRadius` · `shadowOffsetY` · `scrimOpacity` · `iconCircleSize` · `iconCircleOpacity` · `showsDivider` |
| `SDKTheme.shared.banners` | `cornerRadius` · `shadowRadius` · `shadowOffsetY` · `iconCircleSize` · `iconCircleOpacity` |
| `SDKTheme.shared.fields` | `cornerRadius` · `background` · `borderColor` · `borderWidth` · `placeholderColor` · `minHeight` |
| `SDKTheme.shared.sheets` | `cornerRadius` · `handleWidth` · `handleHeight` · `handleColor` · `background` |
| `SDKTheme.shared.capture` | `maskOpacity` · `guideStrokeColor` · `guideLockedColor` · `guideLineWidth` · `faceAlignedColor` · `faceIdleColor` · `overlayButtonFill` · `overlayButtonBorder` |
| `SDKTheme.shared.controls` | `shutterSize` · `shutterRingWidth` · `shutterFill` · `shutterRingColor` · `recordingColor` · `progressRingWidth` |
| `SDKTheme.shared.call` | `panelCornerRadius` · `panelBackground` · `handleColor` · `controlSize` · `remoteVideoBackground` · `localPreviewCornerRadius` |
| `SDKTheme.shared.motion` | `transitionDuration` · `overlayDuration` · `disabled` |

```swift
SDKTheme.shared.resetAppearance()   // renk/font/metrik/bileşen override'larının tümünü sil
```

---

## Tek Sözlükle Tema (JSON)

Tüm bölümler tek bir sözlükten uygulanabilir. React Native ve Flutter köprüleri de bunu
kullanır: **renk/logo denemesi için native derleme gerekmez.**

```swift
SDKTheme.shared.apply([
    "colors": [
        "primary": "#0F172A",
        "pageBackground": ["light": "#F8FAFC", "dark": "#0B1120"],
        "selectedItemBackground": "#1D4ED8"
    ],
    "navBar":  ["preset": "centered", "showsDivider": true],
    "buttons": ["corner": 12, "height": 54,
                "styles": ["secondary": ["borderWidth": 1]]],
    "icons":   ["headerLogo": "my_mark"]        // HOST asset adı
])

SDKTheme.shared.applyTheme(named: "theme")      // Bundle'daki theme.json
SDKTheme.shared.apply(json: data)               // ham JSON
```

Değer biçimleri:

| Tip | Yazım |
|---|---|
| Renk | `"#RRGGBB"` ya da `{"light": "#…", "dark": "#…"}` |
| Köşe | `"capsule"` ya da sayı (`0` = tamamen köşeli) |
| Font | `{"size": 16, "weight": "semibold"}` |
| İkon | host uygulamasının asset adı |

`apply(...)` tanınmayan anahtarların listesini döner — entegrasyonda loglayın, yazım hatası
sessizce kaybolmaz:

```swift
let unknown = SDKTheme.shared.apply(config)
if !unknown.isEmpty { print("Tema: tanınmayan anahtar", unknown) }
```

### React Native / Flutter

```ts
await IdentifySdk.setTheme({ colors: { primary: "#0F172A" }, navBar: { preset: "centered" } });
IdentifySdk.resetTheme();
```

```dart
await IdentifySdk.instance.setTheme({'colors': {'primary': '#0F172A'}});
```

---

## Görsel Kontrol: Showcase Kataloğu

Sample App'teki **Showcase** bölümü (`Showcase/ShowcaseCatalogView.swift`), tüm ekranları ve
tasarım sistemini tek yerden gezmenizi sağlar. Temanızı ayarladıktan sonra kataloğu açıp
markanızın her ekranda nasıl durduğunu hızlıca kontrol edin — akışı baştan sona koşturmanıza
gerek kalmaz.
