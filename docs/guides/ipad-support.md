# iPad Desteği ve Cihaz Yetenekleri

SDK 3.0.1'den itibaren iPad'de çalışır. Bu rehber neyin değiştiğini, hangi modülün hangi
donanımı istediğini ve cihaz o donanıma sahip değilse akışın nasıl ilerlediğini anlatır.

---

## Özet

| Konu | Davranış |
|---|---|
| Cihaz ailesi | iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) |
| Yönelim | **Portrait** — iPad'de de dik kilitli |
| NFC | Hiçbir iPad'de yok → NFC modülü akıştan çıkarılır, panel bilgilendirilir |
| Canlılık (TrueDepth) | Face ID'li iPad Pro / Air'de tam çalışır; yoksa yedek modül (`faceTrackingFallback`, varsayılan selfie) |
| Yerleşim | Metin ve form sütunları okunabilir genişlikte ortalanır; kamera ekranları tam ekran |

---

## Yönelim

SDK ekranları portrait'e kilitlidir ve yakalama bağlantıları dik varsayımıyla kurulur.
iPad'de de aynı kural geçerlidir; host uygulamanın Info.plist'inde iPad için de yalnız
portrait tanımlanmalıdır:

```
UISupportedInterfaceOrientations~ipad = UIInterfaceOrientationPortrait
```

Kullanıcı cihazı yan tutarsa arayüz dik kalır ama sensör görüntüsü döner; SDK bunu
yerçekiminden ölçüp "dik tutun" uyarısı gösterir (`SDKDeviceOrientationMonitor`). Bu uyarı
tablette de geçerlidir — iPad genelde masaya yatık kullanıldığından eşikler toleranslıdır ve
düz duran cihaz uyarı üretmez.

---

## Donanım yetenekleri ve modül davranışı

### NFC — hiçbir iPad'de yok

Akış kurulurken cihazın NFC donanımı yoksa **NFC modülü modül listesine hiç eklenmez** ve
panele `NFCStatus = notAvailable` bildirilir; kullanıcı geçemeyeceği bir adımda beklemez.

Ekranın yine de gösterilmesini isteyen entegrasyonlar için:

```swift
IdentifyManager.shared.setupSDK(..., showNFCNotFoundPage: true, ...)
```

### TrueDepth (ARKit yüz takibi) — yalnız Face ID'li cihazlarda

TrueDepth kamera Face ID'li iPhone'larda ve Face ID'li iPad Pro / iPad Air (M-serisi)
modellerinde bulunur. Touch ID'li iPad Air / iPad mini / temel iPad ile Face ID'siz
iPhone'larda **yoktur**.

Destekleyen cihazlarda `livenessDetection` ve `selfieWithLiveness` **olduğu gibi çalışır** —
iPad Pro dahil, ikame devreye girmez. Kontrol tek yerde yapılır
(`ARFaceTrackingConfiguration.isSupported`) ve akış kurulurken okunur.

Desteklemeyen cihazlarda:

| Sunucudan gelen modül | Cihazda TrueDepth yoksa |
|---|---|
| `livenessDetection` | Akışta selfie modülü zaten varsa canlılık adımı çıkarılır; yoksa yerine **selfie modülü** eklenir |
| `selfieWithLiveness` | Yerine **selfie modülü** konur (akışta selfie varsa yalnız çıkarılır) |

Yani doğrulama yine yüz üzerinden yapılır: selfie modülü çekilen kareyi kimlik fotoğrafıyla
karşılaştırır. Karar akış kurulurken verilir, kullanıcı desteklenmeyen bir ekranı hiç görmez;
`sdk_logs`'a hangi modülün neyle değiştirildiği yazılır ve ilgili `TrackingEventType`
(`livelinessModuleSkipped` / `selfieWithLivenessModuleSkipped`) yayınlanır.

> Emniyet supabı: canlılık ekranı elle akışa eklenirse ve cihaz desteklemiyorsa, kullanıcı
> uyarı görüp modül atlanır — donmuş ekranda kalınmaz.

#### Yerine ne geleceğini siz seçersiniz

Yedek davranış koda gömülü değildir; `setupSDK` çağrısından **önce** belirlenir. Seçim son
kullanıcıya sorulmaz:

```swift
IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan
IdentifyManager.shared.faceTrackingFallback = .skip     // modülü tamamen çıkar
```

| Değer | Davranış |
|---|---|
| `.selfie` | **Varsayılan.** Normal selfie modülü ile doğrulanır; akışta selfie zaten varsa modül yalnızca çıkarılır |
| `.skip` | Yerine bir şey konmaz, modül akıştan çıkarılır. Yüz doğrulaması akışın başka bir adımıyla veya operatör görüşmesiyle yapılıyorsa uygundur |
| `.livenessDetection` | **Uygulanamaz, `.selfie` gibi davranır.** Canlılık ekranı da ARKit yüz takibine dayanır (göz kırpma / gülümseme blend shape'lerden, baş açısı yüz dönüşümünden okunur); TrueDepth yokken o da çalışamaz. Seçenek, ileride donanım istemeyen bir canlılık akışı eklenirse entegrasyonu değiştirmek gerekmesin diye kabul edilir ve `sdk_logs`'a bir satır yazılır |

Yani "TrueDepth yoksa canlılığa düş" fiziksel olarak mümkün değildir: her iki canlılık modülü
de aynı donanımı ister. Gerçek seçim **selfie ile doğrula** ya da **adımı çıkar** arasındadır.

### Diğer donanımlar

| Yetenek | iPad durumu |
|---|---|
| Ön/arka kamera | Var — kimlik, selfie, video ve görüşme modülleri çalışır |
| Mikrofon | Var |
| Konuşma tanıma | Var |
| Apple Pencil | İmza modülünde kullanılabilir (ek ayar gerekmez) |

---

## Yerleşim

Geniş ekranda metin ve form sütunlarının uçtan uca yayılmaması için SDK içerik genişliğini
sınırlar. Kendi ekranlarınızda aynı davranışı almak için:

```swift
VStack { ... }
    .sdkReadableWidth()          // varsayılan 600 pt
    .sdkReadableWidth(720)       // kendi sınırınız
```

Telefonda bu değişikliğin görünür etkisi yoktur (pencere zaten dar).

Ölçüler artık **ekran değil pencere** tabanlıdır:

```swift
SDKLayout.bounds          // etkin pencerenin sınırları (UIScreen yerine)
SDKLayout.isPad           // cihaz türü
SDKLayout.readableWidth   // metin sütunu üst sınırı (varsayılan 600)
SDKLayout.maxGuideWidth   // kimlik/pasaport kılavuz çerçevesi üst sınırı (varsayılan 420)
SDKLayout.maxFaceGuideWidth // yüz ovali referans genişliği üst sınırı (varsayılan 560)
```

`UIScreen.main.bounds` iPad'de yanıltıcıdır: uygulama ekranın yalnız bir bölümünü
kaplayabilir. Kamera kırpma alanı (ROI), kılavuz çerçevesi ve canlılık ekran kaydı bu yüzden
pencereyi referans alır. Kendi kamera ekranlarınızı yazarken aynı kuralı izleyin.

Kimlik/pasaport kılavuz çerçevesi tablette belgeye göre absürt büyümesin diye üst sınırla
kesilir; sınırı temadan değiştirebilirsiniz:

```swift
SDKLayout.maxGuideWidth = 480
```

Selfie ve canlılık ekranlarındaki **yüz ovali** de aynı nedenle sınırlıdır. Oval, pencere
genişliğinin değil `maxFaceGuideWidth` ile kesilmiş referans genişliğin bir oranı kadar
çizilir; sınır olmasa tablette oval ekranla birlikte büyür ve kullanıcının kameraya
gerçekçi olmayan bir yakınlıkta durması gerekirdi. Kılavuz ile analiz aynı dikdörtgeni
paylaştığı için "çok uzak / çok yakın" değerlendirmesi de bu sınırla birlikte kayar:

```swift
SDKLayout.maxFaceGuideWidth = 620   // tablette daha büyük oval
```

---

## Modül ekranlarını tablette gözden geçirme

Backend oturumu açmadan, her modülün **tam ekran** hâli simülatörde açılabilir. Örnek uygulama
iki test kancası taşır:

```bash
SIM="iPad Pro 11-inch (M5)"
BID=com.2sworks.identifytr.v3

SIMCTL_CHILD_SHOWCASE_ITEM=addressConfirm \
SIMCTL_CHILD_SHOWCASE_FULLSCREEN=1 \
xcrun simctl launch "$SIM" $BID -showShowcase

xcrun simctl io "$SIM" screenshot addressConfirm.png
```

- `-showShowcase` — açılışta modül rehberini açar.
- `SHOWCASE_ITEM` — o modülün detayını doğrudan açar.
- `SHOWCASE_FULLSCREEN=1` — modülü rehber kartı yerine **tam ekran** çizer; kart 540 pt'a
  sabit olduğu için tablet yerleşimi ancak bu modda değerlendirilebilir.

Modül id'leri `Showcase/ShowcaseCatalog.swift` içindedir (`prepare`, `idCard`, `nfc`,
`addressConfirm`, `signature`, `speech`, `thankYou`, …).

Kamera, NFC ve ARKit simülatörde çalışmadığından bu modlarda **yerleşim** doğrulanır; yakalama
davranışı gerçek cihaz ister.

## Test matrisi

Yayına çıkmadan önce en az şu üç cihaz sınıfında tam akış koşulmalıdır:

| Cihaz | Beklenen |
|---|---|
| Face ID'li iPad Pro | `livenessDetection` ve `selfieWithLiveness` normal çalışır (yüz ovali ekranla büyümez); NFC adımı akışta yoktur |
| Touch ID'li iPad Air / mini | `faceTrackingFallback` devreye girer (varsayılan: selfie); NFC adımı akışta yoktur |
| Face ID'siz iPhone (örn. SE) | `faceTrackingFallback` devreye girer; NFC cihaza göre |

Kontrol edilecekler:

- Kamera kılavuzları (kimlik çerçevesi, yüz ovali) ekranla birlikte absürt büyümüyor.
- Metin ve form sütunları ortalanmış, satırlar ekranın tamamına yayılmıyor.
- Canlılık adımı geçince kısa titreşim alınıyor (`stepFeedbackEnabled`); iPad'de dokunsal
  donanım yoktur — darbe sessizce atlanır, akış etkilenmez.
- Atlanan modüller için `status == .skipped` olayı host'a ulaşıyor ve `sdk_logs`'ta hangi
  modülün neyle değiştirildiği görünüyor.
- Split View / Stage Manager'da kamera önizlemesi ve kırpma alanı kaymıyor.
