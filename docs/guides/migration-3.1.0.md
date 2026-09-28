# 3.1.0 — Neler Değişti, Neler Eklendi

Bu sürüm tema ve özelleştirmeye odaklanıyor. Değişikliklerin hepsi ekleme niteliğinde: hiçbir tema
ayarı vermezseniz ekranlar 3.0.0'daki gibi görünür.

Ayrıntılı kullanım için [Tema Rehberi](theming.md)'ne, temayı tek bir sözlükle vermek için aynı
rehberdeki *Tek Sözlükle Tema (JSON)* bölümüne bakın.

---

## Özet

| Alan | 3.0.0 | 3.1.0 |
|---|---|---|
| Buton | 4 stil, sabit kapsül köşe | `SDKTheme.shared.buttons`: köşe, ölçü, font, kenarlık, gölge, haptik; stil bazında override |
| Başlık çubuğu | tek tasarım | 4 hazır tasarım (`preset`) + ölçü ve renk token'ları |
| Renkler | marka paleti | + 18 rol token'ı (açık ve koyu tema ayrı) |
| Bileşenler | koda sabit yazılmış ölçüler | `selection` · `alerts` · `banners` · `fields` · `sheets` · `capture` · `controls` · `call` · `motion` |
| Yapılandırma | yalnızca Swift API | + sözlük/JSON (`apply`) → RN ve Flutter'da `setTheme`, native derleme gerekmez |
| Header marka işareti | `.langButton` (yanlış ad) | `.headerLogo` (eski ad çalışmaya devam ediyor) |
| İngilizce dil kodu | `.eng` | `.en` |
| Cihaz ailesi | yalnızca iPhone | iPhone + iPad (tablette de dikey konuma kilitli) |
| Donanımı eksik cihaz | canlılık modülü akıştan düşerdi | `faceTrackingFallback`: yerine ne geleceğini entegrasyon seçer |
| Selfie + canlılık derinliği | ARKit varsa ARKit (A12+ cihazda derinliksiz de) | `selfieWithLivenessTrueDepth`: `.automatic` · `.required` · `.disabled` (Vision) |
| Canlılık adımı geçişi | sessiz | çok kısa bir onay titreşimi (`stepFeedbackEnabled`) |
| Oturum sonucu | dağınık (`terminateCall` delegate, `session.*` olayları) | `setupSDK(onFinished:)` / `onFlowFinished` / `flowResultDelegate`: tek bir `SDKFlowOutcome`, oturum başına bir kez |
| `showThankYouPage: false` | yalnızca görüşmesiz akışın sonunda geçerliydi, kullanıcı son ekranda kalıyordu | her yolda geçerli: sonuç ekranı açılmaz, SDK aşağı kayarak kapanır |

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

Köşe ayarı yalnızca `SDKButton`'a değil, hazır ekranlardaki bütün aksiyon butonlarına uygulanır
(görüşme, ThankYou, bağlantı koptu, kimlik kartı, uyarı diyalogları). Kendi ekranınızda aynı
biçimi kullanmak için:

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

İnce ayar için: `height`, `showsLogo`, `logoSize`, `circleButtonSize`, `iconSize`, `titleFont`,
`subtitleFont`, `progressHeight`, `progressSpacing`, `progressCorner`,
`overlayGradientOpacity`, `showsDivider`.

Başlık çubuğunda adım adı yerine markanızı da gösterebilirsiniz:

```swift
SDKTheme.shared.navBar.brandTitle = "Acme Bank"
SDKTheme.shared.navBar.titleMode  = .brandWithModule   // .module | .brand | .brandWithModule
```

JSON: `"navBar": { "brandTitle": "Acme Bank", "titleMode": "brandWithModule" }`.
`.prominent` tasarımının yüksekliği iki satır sığsın diye 92'ye çıktı; 56'dayken başlık alttaki
bileşenin üstüne biniyordu. Geri, yardım ve menü ikonlarını `setIcon(.back | .help | .hamburger, …)`
ile değiştirirsiniz. Ayrıntı: [Tema → Başlık Metni](theming.md#başlık-metni--marka-adı).

### 3. Rol renkleri — `SDKAdaptiveColor`

Marka renkleri ile yüzey rolleri ayrıldı. Artık `primary`'ye dokunmadan yalnızca seçili satırın ya
da yalnızca başlık çubuğunun rengini değiştirebilirsiniz.

```swift
SDKTheme.shared.colors.pageBackground =
    SDKAdaptiveColor(light: Color(hex: "#F8FAFC"), dark: Color(hex: "#0B1120"))
SDKTheme.shared.colors.selectedItemBackground = SDKAdaptiveColor(Color.black)
```

Roller: `pageBackground`, `moduleBackground`, `surface`, `title`, `subtitle`, `border`,
`headerBackground`, `headerTitle`, `headerSubtitle`, `headerIcon`, `headerIconBackground`,
`headerIconBorder`, `progressActive`, `progressInactive`, `selectedItemBackground`,
`selectedItemText`, `unselectedItemBackground`, `unselectedItemText`.

Sesli okuma ekranlarındaki turuncu vurgu rengi (`colors.accentWarning`) da artık temadan geliyor;
önceden koda sabit yazılıydı.

### 4. Bileşen görünüm kapları

`SDKTheme.shared.` altında: `selection`, `alerts`, `banners`, `fields`, `sheets`, `capture`,
`controls`, `call`, `motion`. Alan listeleri [Tema Rehberi](theming.md#bileşen-görünümleri)'ndeki
tabloda. Hepsinde kural aynı: bir alanı `nil` bırakırsanız SDK varsayılanı kullanılır.

`motion` ile akıştaki geçişlerin süresini ayarlarsınız; `motion.disabled = true` animasyonları
kapatır.

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

`apply(...)` tanımadığı anahtarların listesini döndürür, böylece yazım hataları gözden kaçmaz.

React Native ve Flutter köprüleri aynı şemayı kullanır. Renk ya da logo denerken native derleme
gerekmez; JS ya da Dart reload yeterli:

```ts
const { unknownKeys } = await IdentifySdk.setTheme({ navBar: { preset: 'minimal' } });
IdentifySdk.resetTheme();
```

Örnek dosya: [`docs/integration/theme.example.json`](../integration/theme.example.json).
TS tipleri `IdentifySdk.ts` içindeki `SDKThemeConfig`'te.

### 6. `IDFont.custom(_:_:)`

Tasarım ölçeğinde olmayan, tek seferlik font boyutları için. `.system(size:)` yerine bunu
kullanın; yoksa `fonts.familyName` verdiğinizde o metin sistem fontunda kalır.

### 7. iPad desteği ve yetenek tabanlı modül ikamesi

SDK artık iPad'de de çalışıyor; ekran tablette de dikey konuma kilitli. Donanım isteyen modüller
için karar akış kurulurken verilir ve yerine ne geleceğini siz belirlersiniz:

```swift
IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan
IdentifyManager.shared.faceTrackingFallback = .skip     // adımı tamamen çıkar
// setupSDK'dan ÖNCE
```

Cihaz ARKit yüz takibini desteklemiyorsa (TrueDepth kamerası olmayan A11 ve öncesi: iPhone 8,
iPad 7…) `livenessDetection` ve `selfieWithLiveness` bu ayara göre değiştirilir. Face ID'li
cihazlarda ve A12+ Touch ID'li iPad'lerde iki modül de çalışır. NFC'si olmayan cihazlarda panele
artık `NFCStatus = notAvailable` bildiriliyor.

Selfie + canlılık TrueDepth modu: varsayılan `.automatic` önceki davranışla aynı, bir şey
değiştirmeniz gerekmez. Derinlik verisini zorunlu tutmak isteyen entegrasyonlar `.required`,
ARKit olmadan her cihazda çalıştırmak isteyenler `.disabled` seçer. Tek bir ekran için:
`SDKSelfieWithLivenessView(trueDepthMode:)`.
[Ayrıntı](../../IdentifySample/Modules/SelfieWithLiveness/SelfieWithLiveness.md#truedepth-modu)

Yerleşimde ölçüler artık ekrana değil pencereye göre hesaplanıyor (`SDKLayout.bounds`). Metin
sütunlarını `.sdkReadableWidth()`, kılavuz çerçevelerini `SDKLayout.maxGuideWidth` /
`maxFaceGuideWidth` sınırlar. Ayrıntı: [iPad Desteği](ipad-support.md).

### 8. Canlılık adımlarında onay titreşimi

Onaylanan her canlılık adımında tek ve çok kısa bir titreşim hissedilir. Bu 2.x'te vardı, 3.0.0'da
yoktu. Varsayılan olarak açık:

```swift
SDKHapticConfig.shared.stepFeedbackEnabled = false   // kapat
SDKHapticConfig.shared.stepFeedbackIntensity = 0.4   // 0…1, vars. 0.6
```

Modül anahtarı (`setEnabled(_:for:)`) hem çekim sırasındaki artan titreşimi hem bu titreşimi
kapatır. Ayrıntı: [Tema Rehberi — Titreşim](theming.md#titreşim-haptik).

### 9. Akış sonucu — `onFinished`

SDK hangi yolla kapanırsa kapansın (panel kararı, kullanıcının ya da host'un çıkışı, modül hatası,
oda dolu, kurulum hatası, uygulamanın kapatılması) sonuç karar anında ve tam bir kez gelir:

```swift
IdentifyManager.shared.setupSDK(
    ...,
    showThankYouPage: false,              // isteğe bağlı: sonuç ekranı olmadan kapan
    onFinished: { outcome in
        switch outcome.result {
        case .approved:                          router.show(.success)
        case .rejected, .neutral, .notCompleted: router.show(.failure(outcome.reason))
        case .cancelled:                         router.show(.abandoned)
        case .error:                             router.show(.error(outcome.errorMessage))
        }
        // outcome.terminateReason / outcome.statusSummary → panel kapattıysa birebir
    }
) { socket, room, error in ... }

// Delegate ile
IdentifyManager.shared.flowResultDelegate = resultHandler   // IdentifyFlowResultListener, weak
```

Karar içermeyen sonlandırmalar (statü yok, "Durum Seçilmedi", bağlantı sorunları) sonuç üretmez;
kullanıcı yeniden bağlanır. Doğrulanmadan geçilen modüller (atlandı, NFC yok…)
`outcome.skippedModules`'ta listelenir. Bütün çıkış yolları ve yönlendirme:
[Oturum Çıkışları](session-exit.md). Alanlar ve sebep tablosu:
[FULL-INTERGATION → Akış Sonucu](../../FULL-INTERGATION.md#akış-sonucu--onfinished-310).

### 10. Kimlik tarayıcı — MRZ kuralı, etiketli arka yüz, gömülebilir tarayıcı

- `DocumentProfile.mrz: MRZRequirement?`: MRZ kuralı artık profilin bir parçası. Alanları
  `format` (`.td1`/`.td3`), `isRequired` ve `level` (`.presence`/`.parsed`). Basılı alanları
  `FieldDescriptor.isRequired`, MRZ'yi `mrz.isRequired` zorunlu yapar. Koda sabit yazılmış "MRZ
  tam ayrışmadan çekme" kuralı kaldırıldı. `mrz` vermeyen `.mrzTurkishID` profili eski kuralla
  çalışır.
- Kopya yardımcıları: `settingRequired(_:for:)`, `settingMRZ(_:)`, `settingMRZRequired(_:)`,
  `settingField(_:)`, `removingFields(_:)`, `settingKeywordSet(_:)`. Hazır profili baştan
  kurmadan istediğiniz alanı açıp kapatabilirsiniz.
- `turkishIDBack`: anne adı, baba adı ve veren makam artık sabit bir bölgeden değil, basılı
  etiketlerine göre bulunuyor. MRZ kuralı `.td1`, zorunlu, `.presence`. Önceden kart çerçeveyi
  tam doldurmadığında arka yüz elle çekime düşüyordu.
- MRZ okuması: `«` ve `‹` karakterleri `<` olarak okunur, satırlar konumlarına göre sıralanıp
  parçaları birleştirilir, TD1 satırları yapılarına göre tanınır.
- `IdentityScannerView`: `dismissesOnResult`, `keepsCameraRunning` ve `scanSession` ile tarayıcıyı
  bir ekranın parçası olarak gömebilir, ön ve arka yüzü aynı kamera oturumunda çekebilirsiniz.
  Örnek: `IdCardSingleScreenCustomView`.
- `SDKSelfieWithLivenessViewModel` artık public (ARKit / Vision). Selfie + canlılık ekranı SwiftUI
  ve ViewModel ile yazıldı. Örnek: `SelfieWithLivenessCustomView`.

Ayrıntı: [IdentityScanner rehberi](identity-scanner.md#neyin-çekimi-beklettiğine-profil-karar-verir).

---

## Değişti

- Başlıktaki marka işaretinin anahtarı `.headerLogo` oldu. 3.0.0'da bu görsel `.langButton`
  anahtarıyla çiziliyordu (v2'den kalma bir asset adı), bu yüzden `.logo`'yu değiştirmek başlığı
  etkilemiyordu. `.logo` giriş ekranında ve kamera ekranlarının üstündeki başlıkta kullanılmaya
  devam ediyor.

  ```swift
  SDKTheme.shared.setIcon(.headerLogo, Image("my_mark"))
  ```

  `.langButton` ile yapılmış override'lar çalışmaya devam eder. Yeni kodda `.headerLogo` kullanın.

- Sayfa arka planlarını artık değiştirebilirsiniz. 3.0.0'da açık temada sayfa zemini koda sabit
  yazılmış beyazdı, kamera ve modül ekranları ise doğrudan `primary` kullanıyordu. İkisi de artık
  rol token'larına bağlı (`pageBackground`, `moduleBackground`).

- Seçim satırları kendi rollerini kullanıyor. Hazırlık ekranındaki izin satırları ve belge türü
  seçimi renklerini artık `selectedItem*` / `unselectedItem*` rollerinden alıyor; `primary`
  değiştiğinde bunlar kendiliğinden değişmiyor.

- İngilizce dil kodu `.eng` yerine `.en` oldu (ISO 639-1 ile aynı).

- Sabit ölçüler token'a dönüştü: seçim satırının köşesi ve yüksekliği, alan köşeleri, uyarı kartı
  ölçüleri, sheet tutamağı, kamera maskesinin opaklığı, kılavuz çerçevesi renkleri, kayıt
  butonunun ölçüsü.

- `showThankYouPage` varsayılanı `true`. 3.0.0'da varsayılan `false` görünüyordu, ama görüşme
  sonunda bu bayrağa bakılmadığı için sonuç ekranı yine açılıyordu. Yani görünen davranış
  değişmiyor. `false` artık her yolda geçerli (bkz. *Akış sonucu*).

- `session.completed` ve `session.failed` olayları yalnızca gerçek bir bitişte gönderiliyor.
  3.0.0'da her `terminateCall`'da gönderiliyordu ve panelin `positive` statüsü başarı sayılmıyordu.
  Karar içermeyen sonlandırmalarda bu olaylar artık gelmiyor.

---

## Geçiş Adımları

Çoğu projede yapmanız gereken bir şey yok. Aşağıdaki adımlar yalnızca ilgili API'yi
kullanıyorsanız gerekli:

1. `SDKLang.eng` → `SDKLang.en`

   ```swift
   IdentifyManager.shared.setSDKLang(lang: .en)      // eskiden .eng
   SDKLocalization.shared.registerOverrides([.en: ["Continue": "Proceed"]])
   ```

   - `.eng` hâlâ derlenir (deprecated uyarısıyla). Tek istisna `switch` içindeki `case .eng:`
     deseni: bu derleme hatası verir ve sürümdeki tek kırılma noktası budur.
   - `SDKLang(rawValue: "eng")` çalışmaya devam eder; kayıtlı dil tercihini `"eng"` olarak
     saklayan projeler etkilenmez.
   - Kendi ses paketinizdeki İngilizce klipler `<ad>_eng` adındaysa yeniden adlandırmanız gerekmez:
     yeni ad (`<ad>_en`) bulunamazsa eski ad denenir. Yeni paketlerde `_en` kullanın.

2. Header logosu: `.langButton` override'ınız varsa `.headerLogo`'ya taşıyın. Davranış aynı,
   yalnızca ad doğru.

3. Kendi ekranlarınızda `.font(.system(size:))` kullanıyorsanız `IDFont.custom(_:_:)` ile
   değiştirin; böylece tema fontu bu metinlere de uygulanır.

4. Sonucu `session.completed` / `session.failed` olaylarından okuyorsanız bunun yerine
   `onFinished`'ı (ya da `session.finished` + `metadata.result`) kullanın. Onaylanan oturumlar artık
   doğru şekilde `session.completed` olarak geliyor.

5. Kendi UIKit akışınızda `getNextModule` kullanıyor ve `showThankYouPage` vermiyorsanız son adımda
   artık `thankYouViewController` döner. Sonuç ekranı istemiyorsanız `showThankYouPage: false`
   verin.

---

## Kapanış Animasyonu Hakkında

SDK akışı kendisi sunmaz ve kendisi kapatmaz; ikisi de host uygulamanın işi. Ekran animasyonsuz
kapanıyorsa sebep, akışın içinde durduğu görünümün animasyonsuz kaldırılmasıdır:

```swift
host.modalPresentationStyle = .fullScreen
host.modalTransitionStyle = .coverVertical
presenter.present(host, animated: true)
...
host.dismiss(animated: true)     // animated: false ANINDA kapatır
```

`showThankYouPage: false` iken akışın içindeki üst ekran aşağı kayarak kalkar ve `onFinished`
çağrılır. Akışın içinde durduğu modal ya da `fullScreenCover`'ı kapatmak yine host'un işi; bunu
`onFinished` içinde yapın.

React Native'de akışı `<Modal animationType="slide">` içinde gösterin. Akış içindeki adım
geçişlerinin süresini temadan ayarlarsınız: `SDKTheme.shared.motion.transitionDuration`.

---

## Sample App'te Nerede Görebilirim?

Showcase'teki Tasarım Sistemi bölümünde:

| Kart | İçerik |
|---|---|
| Buton | 4 stil; köşe, yükseklik, kenarlık, gölge ve haptik için canlı kontroller; üretilen kod bloğu |
| Nav Bar | 4 preset seçici, marka işareti ve ayırıcı anahtarları, 4 stilin canlı önizlemesi |
| JSON ile Tema | 3 hazır tema, düzenlenebilir JSON, uygula/sıfırla, tanınmayan anahtar raporu |
| Renkler / Tipografi | Token paleti ve ölçek |
| Özelleştirme | İkon ve metin override örneği |
