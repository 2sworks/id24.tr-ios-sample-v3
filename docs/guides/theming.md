# Tema — SDK Ekranlarını Markanıza Boyamak

> 3.1.0 ile gelen yenilikler ve geçiş adımları: [3.1.0 Değişiklik Rehberi](migration-3.1.0.md)

SDK'nın hazır ekranları tek bir tema kaynağından beslenir: `SDKTheme.shared`. Renkleri, fontu,
ikonları, boşlukları ve köşe yarıçaplarını `setupSDK`'dan önce bir kez ayarlarsınız. Hazır
ekranların hepsi markanızın görünümüne geçer; hiçbir ekranı yeniden yazmanız gerekmez.

← [README'ye dön](../../README.md) · İlgili: [Özelleştirme](customization.md) (ekranın tamamını değiştirmek için)

---

## İki Seviye Özelleştirme

1. Tema (bu rehber): SDK ekranları yerinde kalır, yalnızca görünümleri değişir. Marka uyumu için
   çoğu zaman bu yeterlidir.
2. Ekran override: ekranın tamamını kendi tasarımınızla değiştirirsiniz.
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

SDK ekranlarında hiçbir renk, font ya da boşluk değeri elle yazılmaz; hepsi token'lardan okunur.
Token'lar da `SDKTheme.shared`'a bakar. Temayı değiştirdiğinizde bütün ekranlar birlikte değişir.

| Token ailesi | Örnek | Kaynağı |
|---|---|---|
| `IDColor` | `IDColor.primary`, `IDColor.error` | `theme.colors` (`SDKColors`) |
| `IDFont` | `IDFont.font(size:weight:)` | `theme.fonts` (`SDKFonts`) |
| `IDSpacing` | `IDSpacing.md` (12pt) | `theme.metrics` (`SDKMetrics`) |
| `IDRadius` | `IDRadius.card` (36pt) | `theme.metrics` |
| `SDKButtonShape` | `SDKButtonShape.themed()` | `theme.buttons` (`SDKButtons`) |

Aynı token'ları kendi custom ekranlarınızda da kullanabilirsiniz. Böylece override ettiğiniz ekran
SDK'nın geri kalanıyla uyumlu kalır.

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

- `familyName` tek satırda SDK'nın bütün tipografisini değiştirir (varsayılan: Inter).
- Font uygulamanızda kayıtlı değilse çalışma zamanında yükleyebilirsiniz:

```swift
SDKTheme.shared.registerFont(at: fontFileURL)     // ya da
SDKTheme.shared.registerFont(data: fontData)      // bundle'a gömülü veri
SDKTheme.shared.fonts.familyName = "Sofia Pro"
```

### Metrikler — `SDKMetrics`

Boşluklar `spacingXS` (4) ile `spacingXXL` (32) arasında, köşe yarıçapları `radiusSM` (8) ile
`radiusCard` (36) arasında tanımlı. Daha keskin köşeler için örneğin:

```swift
SDKTheme.shared.metrics.radiusCard = 12
```

### Butonlar — `SDKButtons`

SDK'nın aksiyon butonlarının bütün görünümü `SDKTheme.shared.buttons` üzerinden ayarlanır. Her
alan isteğe bağlıdır; dokunmadığınız alanlar SDK varsayılanında kalır.

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

Köşe ayarı yalnızca `SDKButton`'a değil, hazır ekranlardaki bütün aksiyon butonlarına uygulanır
(görüşme ekranı, ThankYou, bağlantı koptu, kimlik kartı, uyarı diyalogları). Kendi custom
ekranınızda aynı biçimi elde etmek için `SDKButtonShape` kullanın:

```swift
Text("Devam")
    .padding()
    .background(IDColor.primary)
    .clipShape(SDKButtonShape.themed())          // aktif temanın köşesi
```

---

## İkonlar ve İllüstrasyonlar — `SDKIconKey`

Her görsel öğeyi bir anahtarla değiştirebilirsiniz. Anahtarların tam listesi `SDKIconKey`
(`CaseIterable`) enum'ında. Başlıca gruplar:

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

> Başlıktaki marka işaretinin anahtarı `.logo` değil, `.headerLogo`'dur. `.logo` giriş ekranında
> ve kamera üstü başlıkta kullanılır; `.headerLogo` ise modül ve ilerleme başlığındaki yuvarlak
> işarettir. Eski entegrasyonlar bu işareti `.langButton` ile değiştiriyordu. O ad hâlâ çalışır,
> ama yeni kodda `.headerLogo` kullanın.
>
> ```swift
> theme.setIcon(.headerLogo, Image("my_mark"))
> ```

Değiştirmediğiniz her anahtar için SDK kendi görselini kullanır.

---

## Rol Renkleri

Yüzey rolleri, marka renklerinden (`primary`, `success`, `error`) ayrı tutulur. Rol vermezseniz
SDK bugünkü gibi davranır; bir rol verdiğinizde yalnızca o yüzey değişir. Örneğin `primary`'ye
dokunmadan seçili satırın rengini ayarlayabilirsiniz.

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

Kamera görüntüsünün üstüne çizilen katmanlarda (kılavuz çerçevesi, maske, uyarı yazıları) beyaz ve
siyah okunabilirlik için seçildi. Bunları `capture` token'larıyla değiştirebilirsiniz, ama
kontrastı kendi görsellerinizle deneyin.

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

İnce ayar için `SDKTheme.shared.navBar` alanları: `height`, `showsLogo`, `logoSize`,
`circleButtonSize`, `iconSize`, `titleFont`, `subtitleFont`, `progressHeight`, `progressSpacing`,
`progressCorner`, `overlayGradientOpacity`, `showsDivider`.

### Başlık Metni — Marka Adı

Varsayılan olarak çubukta her adımın adı yazar ("Kimlik Doğrulama", "Adres Doğrulama"…). Çubuğa
kendi markanızı koymak için:

```swift
SDKTheme.shared.navBar.brandTitle = "Acme Bank"
SDKTheme.shared.navBar.titleMode  = .brandWithModule   // varsayılan: marka verilince bu
```

| `titleMode` | Üst satır | Alt satır |
|---|---|---|
| `.module` | adım adı | ekranın alt başlığı (SDK varsayılanı) |
| `.brandWithModule` | `brandTitle` | adım adı |
| `.brand` | `brandTitle` | `brandSubtitle` (verilmişse) |

`brandTitle` verip `titleMode`'u `.module` bırakırsanız `.brandWithModule` uygulanır. Kamera üstü
ekranlarda (selfie, NFC, hologram) marka adı logonun yanına yazılır. Marka adıyla adım adını
birlikte göstermek için en uygun yerleşim, iki satırlı olan `.prominent` preset'idir.

Adım adlarını değiştirmek için metin override'ı kullanın (bkz. `SDKLocalization`):

```swift
SDKLocalization.shared.setOverride(key: .idVerifyTitle, language: .tr, value: "Kimlik Kontrolü")
```

JSON temada: `"navBar": { "brandTitle": "Acme Bank", "titleMode": "brandWithModule" }`.

### Başlık Çubuğu Düğmeleri

Geri, yardım (?) ve menü düğmelerini kaldırabilir, sağ tarafa kendi düğmelerinizi
ekleyebilirsiniz:

```swift
SDKTheme.shared.navBar.buttons.showsHelp = false          // yardım düğmesi hiçbir ekranda yok
SDKTheme.shared.navBar.buttons.onHelp = { route in        // ya da işlev verin
    showHelp(for: route)                                  // route: .selfie, .nfc …
}
SDKTheme.shared.navBar.buttons.trailing = [
    SDKNavBarButton(id: "chat", icon: Image(systemName: "message"),
                    accessibilityLabel: "Canlı destek") { openChat() }
]
```

Tek bir ekrana ayrı ayar verebilirsiniz. Kaydı olan ekranda genel `buttons` yerine bu kullanılır:

```swift
SDKTheme.shared.navBar.routeButtons[.selfieWithLiveness] = SDKNavBarButtons(showsHelp: false)
```

| Alan | Varsayılan | Not |
|---|---|---|
| `showsBack` | `true` | Kapatılırsa kullanıcı ekrandan geri dönemez |
| `showsHelp` | `true` | Yardım düğmesi kamera ekranlarında çizilir (selfie, canlılık, NFC, hologram, video) |
| `showsMenu` | `true` | `.login` stilindeki menü düğmesi |
| `onHelp` | `nil` | Verilmezse yardım düğmesi bir şey yapmaz |
| `trailing` | `[]` | Ekranın kendi düğmesinden (ör. fener) sonra çizilir |

JSON temada yalnızca görünürlük ayarlanır: `"navBar": { "buttons": { "showsHelp": false } }`.

---

## Bileşen Görünümleri

Butonlardaki (`buttons`) kalıp burada da geçerli: her alan isteğe bağlıdır, `nil` SDK
varsayılanı demektir.

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

## Titreşim (Haptik)

SDK iki yerde titreşim kullanır ve ikisini de host kapatabilir:

| Nerede | Ne yapar |
|---|---|
| Otomatik çekim yapan modüller | Çekim yaklaştıkça hızlanan darbeler (ramp); kullanıcı çekimin geldiğini hisseder |
| Canlılık adımları | Adım (göz kırpma, gülümseme, başı çevirme…) onaylanınca çok kısa tek bir darbe; kullanıcı ekrana bakmadan adımı geçtiğini anlar |

```swift
// Adım onay darbesi — canlılık testindeki "geçtim" hissi:
SDKHapticConfig.shared.stepFeedbackEnabled = false     // yalnız bu darbeyi kapat
SDKHapticConfig.shared.stepFeedbackIntensity = 0.4     // daha hafif (0…1, varsayılan 0.6)

// Çekim rampası + adım darbesi birlikte:
SDKHapticConfig.shared.isEnabled = false                          // tüm modüllerde kapat
SDKHapticConfig.shared.setEnabled(false, for: .livenessDetection) // tek modül
SDKHapticConfig.shared.setEnabled(false, for: [.selfie, .idCard])
```

Modül anahtarı (`setEnabled(_:for:)`) hem rampayı hem adım darbesini kapatır.
`stepFeedbackEnabled` yalnızca adım darbesini etkiler. İkisi de varsayılan olarak açık.

Dokunsallık donanımı olmayan cihazlarda darbe `UIImpactFeedbackGenerator` ile çalınır; bu da
desteklenmiyorsa sessizce atlanır. iPad'lerde Taptic Engine olmadığından titreşim hissedilmez,
ama akış bundan etkilenmez.

Adım darbesi yalnızca `livenessDetection` modülünde çalar. Birleşik `selfieWithLiveness`
ekranında adım kavramı farklı olduğu için çalmaz; orada çekim rampası vardır.

---

## Tek Sözlükle Tema (JSON)

Bütün bölümleri tek bir sözlükten uygulayabilirsiniz. React Native ve Flutter köprüleri de bu
yolu kullanır, bu yüzden renk ya da logo denemek için native derleme gerekmez.

```swift
SDKTheme.shared.apply([
    "colors": [
        "primary": "#0F172A",
        "pageBackground": ["light": "#F8FAFC", "dark": "#0B1120"],
        "selectedItemBackground": "#1D4ED8"
    ],
    "navBar":  ["preset": "centered", "showsDivider": true, "brandTitle": "Acme Bank"],
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

`apply(...)` tanımadığı anahtarların listesini döner. Entegrasyonda bu listeyi loglayın; böylece
bir yazım hatası gözden kaçmaz:

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

Sample App'teki Showcase bölümünde (`Showcase/ShowcaseCatalogView.swift`) bütün ekranları ve
tasarım sistemini tek yerden gezebilirsiniz. Temanızı ayarladıktan sonra kataloğu açıp markanızın
her ekranda nasıl göründüğüne bakın; bunun için akışı baştan sona çalıştırmanız gerekmez.
