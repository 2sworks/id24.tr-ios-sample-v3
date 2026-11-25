# iPad Desteği ve Cihaz Yetenekleri

SDK 3.1.0'dan itibaren iPad'de de çalışıyor. Bu rehberde iPad desteğiyle neyin değiştiğini, her
modülün hangi donanıma ihtiyaç duyduğunu ve cihazda o donanım yoksa akışın nasıl devam ettiğini
bulacaksınız.

---

## Özet

| Konu | Davranış |
|---|---|
| Cihaz ailesi | iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) |
| Yönelim | Dikey (portrait); iPad'de de yalnızca dikey konum tanımlanır (host Info.plist) |
| NFC | Hiçbir iPad'de yok. NFC modülü akıştan çıkarılır ve panele bildirilir |
| Canlılık (ARKit) | Face ID'li iPad Pro'da derinlikli; A12+ Touch ID'li iPad'de derinliksiz (RGB); daha eskilerde yedek modül (`faceTrackingFallback`). Selfie + canlılıkta derinliğin zorunlu olup olmadığını `selfieWithLivenessTrueDepth` belirler |
| Yerleşim | Metin ve form sütunları okunabilir genişlikte ortalanır; kamera ekranları tam ekran |

---

## Yönelim

SDK ekranları dikey konuma göre tasarlandı ve kamera bağlantıları cihazın dik tutulduğu
varsayılarak kurulur. SDK yönü kendisi kilitlemez. Host uygulamanın Info.plist'inde iPad için de
yalnızca dikey konum tanımlı olmalı:

```
UISupportedInterfaceOrientations~ipad = UIInterfaceOrientationPortrait
```

Kullanıcı cihazı yan tutarsa arayüz dikey kalır ama kameradan gelen görüntü döner. SDK cihazın
duruşunu yerçekimi sensöründen ölçer ve "dik tutun" uyarısı gösterir
(`SDKDeviceOrientationMonitor`). Uyarı tablette de çalışır. Selfie, canlılık, selfie + canlılık
ve video kaydı ekranlarında çıkar; kimlik tarayıcıda ve görüşmede yoktur.

Eşikler tüm cihazlarda aynı: cihaz 60 dereceden fazla yatık 1,2 sn kalırsa uyarı çıkar, 40
derecenin altında 0,4 sn kalınca kalkar. Masada düz duran cihaz uyarı üretmez. Değerler
`SDKDeviceOrientationMonitor`'ün statik değişkenleriyle (`sidewaysEnterDegrees`,
`sidewaysExitDegrees`, `enterDwellSeconds`, `exitDwellSeconds`) değiştirilebilir.

---

## Donanım yetenekleri ve modül davranışı

### NFC — hiçbir iPad'de yok

Akış kurulurken cihazda NFC donanımı yoksa NFC modülü modül listesine hiç eklenmez ve panele
`NFCStatus = notAvailable` bildirilir. Böylece kullanıcı geçemeyeceği bir adımda beklemez.

`showNFCNotFoundPage: true` verirseniz modül akışta kalır ve SDK'nın NFC ekranı açılır. Ayrı bir
"NFC yok" sayfası yoktur, okuma denemesi hata verir:

```swift
IdentifyManager.shared.setupSDK(..., showNFCNotFoundPage: true, ...)
```

### ARKit yüz takibi — TrueDepth kamera ya da A12+ çip

TrueDepth kamera Face ID'li iPhone'larda ve iPad'ler arasında yalnızca iPad Pro'da (2018 ve
sonrası) bulunur. iPad Air, iPad mini ve temel iPad modellerinin hiçbirinde yoktur. ARKit yüz
takibi için TrueDepth kamera ya da A12 veya daha yeni bir çip gerekir. A12+ Touch ID'li iPad'lerde
(iPad 8+, mini 5+, Air 3+) derinliksiz (RGB) çalışır, daha eski iPad'lerde hiç çalışmaz. Model
listesi: [SelfieWithLiveness → Cihaz modelleri](../../IdentifySample/Modules/SelfieWithLiveness/SelfieWithLiveness.md#cihaz-modelleri).

ARKit yüz takibini destekleyen cihazlarda `livenessDetection` ve `selfieWithLiveness` olduğu gibi
çalışır, yerlerine başka modül konmaz. Destek kontrolü tek bir yerde yapılır
(`ARFaceTrackingConfiguration.isSupported`) ve akış kurulurken okunur.

Desteklemeyen cihazlarda şu olur:

| Sunucudan gelen modül | Cihaz ARKit yüz takibini desteklemiyorsa |
|---|---|
| `livenessDetection` | Selfie akışta bu modülden önce geliyorsa canlılık adımı yalnızca çıkarılır; gelmiyorsa yerine selfie modülü eklenir. Sunucu selfie'yi sonra gönderirse akışta iki selfie olur |
| `selfieWithLiveness` | Varsayılan `.automatic`'te yerine selfie modülü konur (selfie akışta önce geliyorsa yalnızca çıkarılır). `.required`'da TrueDepth kamerası olmayan cihazlarda da aynısı olur. `.disabled`'da ekran Vision ile çalışır, yerine bir şey konmaz |

Doğrulama yine yüz üzerinden yapılır: selfie modülü çekilen kareyi kimlik fotoğrafıyla
karşılaştırır. Karar akış kurulurken verildiği için kullanıcı desteklenmeyen ekranı hiç görmez.
Hangi modülün neyle değiştirildiği `sdk_logs`'a yazılır ve ilgili `TrackingEventType`
(`livelinessModuleSkipped` / `selfieWithLivenessModuleSkipped`) gönderilir.

> Canlılık ekranı akışa elle eklenmişse ve cihaz desteklemiyorsa kullanıcı bir uyarı görür ve
> modül atlanır. Ekran donmuş halde kalmaz.

#### Yerine ne geleceğini siz seçersiniz

Yedek davranış koda sabit yazılmadı; siz `setupSDK` çağrısından önce belirlersiniz. Bu seçim son
kullanıcıya sorulmaz:

```swift
IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan
IdentifyManager.shared.faceTrackingFallback = .skip     // modülü tamamen çıkar
```

| Değer | Davranış |
|---|---|
| `.selfie` | Varsayılan. Doğrulama normal selfie modülüyle yapılır; selfie akışta bu modülden önce geliyorsa modül yalnızca çıkarılır. Sunucu selfie'yi sonra gönderirse akışta iki selfie olur |
| `.skip` | Yerine bir şey konmaz, modül akıştan çıkarılır. Yüz doğrulaması akışın başka bir adımında ya da operatör görüşmesinde yapılıyorsa bunu seçin |
| `.livenessDetection` | Uygulanamaz ve `.selfie` gibi davranır. Canlılık ekranı da ARKit yüz takibiyle çalışır (göz kırpma ve gülümseme blend shape'lerden, baş açısı yüz dönüşümünden okunur); ARKit yüz takibi yoksa o da çalışmaz. Seçeneği yine de kabul ediyoruz ve `sdk_logs`'a bir satır yazıyoruz; ileride donanım istemeyen bir canlılık akışı eklenirse entegrasyonunuzu değiştirmeniz gerekmez |

Kısacası ARKit yoksa canlılık modülüne düşmek mümkün değil, çünkü iki canlılık modülü de aynı
donanımı istiyor. Gerçekte seçim ikisinden biri: selfie ile doğrulamak ya da adımı çıkarmak.

#### Selfie + canlılık: TrueDepth modu

ARKit yüz takibi TrueDepth kamerayla ya da A12+ çiple çalışır. A12+ Touch ID'li iPad'lerde (ör.
iPad Air 5) ekran derinlik verisi olmadan çalışır. Hangisinin kullanılacağını entegrasyon seçer:

```swift
IdentifyManager.shared.selfieWithLivenessTrueDepth = .required   // yalnız TrueDepth'li cihazda ARKit
IdentifyManager.shared.selfieWithLivenessTrueDepth = .disabled   // ARKit yok, Vision ile her iPad'de
```

Cihaz tablosu, güvenlik notu ve ekran parametresi:
[SelfieWithLiveness → TrueDepth modu](../../IdentifySample/Modules/SelfieWithLiveness/SelfieWithLiveness.md#truedepth-modu).

### Diğer donanımlar

| Yetenek | iPad durumu |
|---|---|
| Ön/arka kamera | Var. Kimlik, selfie, video ve görüşme modülleri çalışır |
| Mikrofon | Var |
| Konuşma tanıma | Var |
| Apple Pencil | İmza modülünde kullanılabilir (ek ayar gerekmez) |

---

## App Store doğrulaması — iPad hedefi eklendiğinde

`TARGETED_DEVICE_FAMILY`'ye iPad eklediğinizde App Store Connect yüklemesi üç şart arar. Üçü de
SDK'yla değil host uygulamanın paketiyle ilgili:

| Şart | Çözüm |
|---|---|
| iPad uygulama ikonları (20/29/40/76 pt @1x-2x, 83.5 @2x) | AppIcon setine `idiom: ipad` girişleri ekleyin; hepsi tek bir 1024 px görselden üretilebilir |
| Çoklu görev için 4 yön + Launch Storyboard | SDK ekranları dikey konuma göre tasarlandığı için çoklu görevden çıkın: `UIRequiresFullScreen = YES` (`INFOPLIST_KEY_UIRequiresFullScreen`) |
| Launch Storyboard (çoklu görev şartı) | `UIRequiresFullScreen = YES` ile bu şart da kalkar; storyboard zaten varsa dokunmayın |

`UIRequiresFullScreen` verilmezse yalnızca dikey konumu destekleyen bir iPad paketi yükleme
sırasında reddedilir ("you need to include all of the … orientations to support iPad
multitasking").

## Yerleşim

Geniş ekranda metin ve form sütunları ekranın bir ucundan diğerine yayılmasın diye SDK içerik
genişliğini sınırlar. Kendi ekranlarınızda aynı davranış için:

```swift
VStack { ... }
    .sdkReadableWidth()          // varsayılan 600 pt
    .sdkReadableWidth(720)       // kendi sınırınız
```

Telefonda bunun görünür bir etkisi olmaz, çünkü pencere zaten dar.

Ölçüler artık ekrana göre değil pencereye göre hesaplanıyor:

```swift
SDKLayout.bounds          // etkin pencerenin sınırları (UIScreen yerine)
SDKLayout.isPad           // cihaz türü
SDKLayout.readableWidth   // metin sütunu üst sınırı (varsayılan 600)
SDKLayout.maxCaptureGuideWidth // OVD çekim kılavuzu üst sınırı (varsayılan 630) — kırpılıp yüklenen bölge
SDKLayout.maxFaceGuideWidth // yüz ovali referans genişliği üst sınırı (varsayılan 560)
```

iPad'de `UIScreen.main.bounds` yanlış sonuç verebilir, çünkü uygulama ekranın yalnızca bir
bölümünü kaplıyor olabilir. Bu yüzden kamera kırpma alanı (ROI), kılavuz çerçevesi ve canlılık
ekran kaydı pencereyi esas alır. Kendi kamera ekranlarınızı yazarken siz de pencereyi esas alın.

Belge çekim kılavuzlarının tablette fazla büyümemesi için bir üst sınırı var. OVD kılavuzu
(`SDKLayout.maxCaptureGuideWidth`) ve tarayıcının sabit çerçevesi (`ScannerFixedFrame.maxWidth`)
varsayılan olarak 630 pt. Bu dikdörtgen kullanıcıya yalnızca yol göstermez; kırpılıp sunucuya
gönderilen görüntü de odur. Daraltırsanız
sensörün küçük bir bölümü kullanılır ve OCR ile sunucu tarafındaki kalite düşer. Genişletirseniz
kullanıcı belgeyi lensin netleyebildiği mesafeden daha yakına tutmak zorunda kalır ve otomatik
çekim tetiklenmez. Telefonda bunun etkisi yoktur, çünkü ekran zaten dar.
TC kimlikte `ScannerFixedFrame.maxWidth`'i 630'un üstüne çıkarmak ise telefonda da hızlı çekimi
kapatır ([IdentityScanner → Hızlı çekim ve çerçeve](identity-scanner.md#hızlı-çekim-ve-çerçeve)).

Selfie ve selfie + canlılık ekranlarındaki yüz ovali de aynı nedenle sınırlı. Ovalin boyutu pencere
genişliğinden değil, `maxFaceGuideWidth` ile sınırlanmış referans genişlikten hesaplanır. Sınır
olmasaydı tablette oval ekranla birlikte büyür ve kullanıcının kameraya gereğinden çok yaklaşması
gerekirdi. Kılavuz ile yüz analizi aynı dikdörtgeni kullandığı için "çok uzak / çok yakın"
değerlendirmesi de bu sınırla birlikte değişir:

```swift
SDKLayout.maxFaceGuideWidth = 620   // tablette daha büyük oval
```

---

## Modül ekranlarını tablette gözden geçirme

Her modülün tam ekran halini backend oturumu açmadan simülatörde görebilirsiniz. Örnek uygulamada
bunun için iki test kancası var:

```bash
SIM="iPad Pro 11-inch (M5)"
BID=com.2sworks.identifytr.v3

SIMCTL_CHILD_SHOWCASE_ITEM=addressConfirm \
SIMCTL_CHILD_SHOWCASE_FULLSCREEN=1 \
xcrun simctl launch "$SIM" $BID -showShowcase

xcrun simctl io "$SIM" screenshot addressConfirm.png
```

- `-showShowcase`: uygulama açılırken modül rehberini açar.
- `SHOWCASE_ITEM`: verilen modülün detayını doğrudan açar.
- `SHOWCASE_FULLSCREEN=1`: modülü rehber kartı yerine tam ekran çizer. Kart 540 pt genişliğe
  sabit olduğu için tablet yerleşimini ancak bu modda görebilirsiniz.

Modül id'leri `Showcase/ShowcaseCatalog.swift` içinde (`prepare`, `idCard`, `nfc`,
`addressConfirm`, `signature`, `speech`, `thankYou`, …).

Simülatörde kamera, NFC ve ARKit çalışmadığı için bu modlarda yalnızca yerleşimi kontrol
edebilirsiniz. Çekim davranışını gerçek cihazda test edin.

## Test matrisi

Yayına çıkmadan önce akışı en az şu üç cihaz sınıfında baştan sona çalıştırın:

| Cihaz | Beklenen |
|---|---|
| Face ID'li iPad Pro | `livenessDetection` ve `selfieWithLiveness` normal çalışır (selfie + canlılıkta yüz ovali ekranla büyümez); akışta NFC adımı yoktur |
| A12+ Touch ID'li iPad Air / mini | Canlılık modülleri ARKit ile derinliksiz çalışır; `selfieWithLivenessTrueDepth = .required` iken selfie + canlılık yedeğe düşer, `.disabled` iken Vision ile çalışır. Akışta NFC adımı yoktur |
| Face ID'siz iPhone (SE 2/3) | iPad Air / mini ile aynı (A12+); SE 1 ve iPhone 8 gibi A11 ve öncesinde `faceTrackingFallback` devreye girer |

Kontrol edilecekler:

- Kamera kılavuzları (kimlik çerçevesi, yüz ovali) ekranla birlikte aşırı büyümüyor.
- Metin ve form sütunları ortalanmış, satırlar ekranın tamamına yayılmıyor.
- Canlılık adımı geçildiğinde kısa bir titreşim hissediliyor (`stepFeedbackEnabled`). iPad'de
  titreşim donanımı olmadığından titreşim sessizce atlanır ve akış etkilenmez.
- Atlanan modüller için `status == .skipped` olayı host uygulamaya ulaşıyor ve `sdk_logs`'ta hangi
  modülün neyle değiştirildiği görünüyor. NFC donanımı olmayan cihazda NFC adımı
  `status == .notFound` olayıyla bildirilir ve `SDKFlowOutcome.skippedModules` içinde `.nfc` olarak
  yer alır.
- Split View ve Stage Manager'da kamera önizlemesi ve kırpma alanı kaymıyor.
