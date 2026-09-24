# IdentityScanner — Gerçek Zamanlı Belge Tarama Motoru

SDK'nın içindeki kamera tabanlı **belge tarama motoru**. Kimlik ekranında gördüğünüz o akıllı
davranışların hepsi buradan gelir: belge dörtgenini canlı yakalama, alan alan OCR (TCKN,
ad-soyad, doğum tarihi...), MRZ okuma, perspektif düzeltme ve TCKN/MRZ doğrulaması —
**tamamı cihaz üzerinde.**

İki şekilde karşınıza çıkar:

1. **Dolaylı** — [IdCard](../../IdentifySample/Modules/IdCard/IdCard.md) ve
   [AddressConfirm](../../IdentifySample/Modules/AddressConfirm/AddressConfirm.md) modüllerinin hazır
   ekranları bu motoru zaten kullanır; hiçbir şey yapmanız gerekmez.
2. **Doğrudan** — `IdentityScannerView`'ı kendi ekranlarınızda **bağımsız bileşen** olarak
   kullanabilirsiniz (KYC akışı dışındaki senaryolar için: form ön-doldurma, belge arşivleme...).

Gereksinim: **iOS 15+**.

← [README'ye dön](../../README.md) · İlgili: [Özelleştirme](customization.md) · [Tema](theming.md)

---

## Kurulum — Tek Satır

Uygulama açılışında profil ve doğrulayıcı kayıtlarını yapın:

```swift
IdentityScanner.setup()   // built-in profiller + TCKN/MRZ doğrulayıcıları kaydedilir
```

## Hızlı Başlangıç

```swift
IdentityScannerView(profile: .turkishIDFront) { result in
    switch result {
    case .success(let doc):
        let tckn = doc.fields["tckn"]?.value          // alan bazlı erişim
        let cropped = doc.croppedImage                 // perspektif düzeltilmiş görsel
        print("Geçerli mi:", doc.isValid)              // TCKN checksum vb. doğrulamalar
    case .failure(let error):
        // ScanningError.cancelled dahil hata durumları
    }
}
```

Kullanıcı belgeyi çerçeveye tutar; motor kareler stabilize olunca **otomatik yakalar**
(gerekirse manuel yakalama butonu belirir), alanları okur, doğrular ve sonucu döndürür.

---

## Hazır Profiller

Profil = "bu belge nasıl taranır" tarifi (strateji + alan bölgeleri + anahtar kelime kapısı):

| Profil | Strateji | Ne yapar |
|---|---|---|
| `.turkishIDFront` | `visionText` | TC kimlik ön yüz: TCKN, soyad, ad, doğum tarihi, belge no — **bölgesel OCR** ile |
| `.turkishIDBack` | `visionText` | TC kimlik arka yüz (MRZ satırları dahil) |
| `.turkishID` | — | Ön/arka birleşik anahtar kelime kümesi |
| `.passport` | `mrzPassport` | Pasaport veri sayfası (TD3 MRZ); dik tutulursa "yana çevirin" yönergesi |
| `.turkishDrivingLicense` | `visionText` | TR ehliyet |
| `.bankCard` | `visionText` | Banka kartı |
| `.a4Document` / `.generic` | `imageOnly` | Serbest belge — alan çıkarmadan düzgün kırpılmış görsel (AddressConfirm bunu kullanır) |

**Anahtar kelime kapısı (keyword gating):** Profildeki `keywordSet`, "TÜRKİYE CUMHURİYETİ /
KİMLİK KARTI" gibi ibareler görünmeden yakalamayı tetiklemez — masadaki rastgele bir dikdörtgen
kimlik sanılmaz.

## Kendi Profiliniz

`DocumentProfile` `Codable`'dır — profili **JSON'dan bile yükleyebilirsiniz** (sunucudan
indirilen profille yeni belge tipi desteği, uygulama güncellemeden):

```swift
let profile = DocumentProfile(
    id: "my.company.badge",
    displayName: "Personel Kartı",
    strategy: .visionText,
    fields: [
        FieldDescriptor(key: "sicilNo",
                        pattern: #"\b[A-Z]{2}\d{6}\b"#,
                        valueType: .number,
                        isRequired: true,
                        regionOfInterest: FieldRegion(x: 0.05, y: 0.60, width: 0.5, height: 0.15))
    ],
    keywordSet: DocumentKeywordSet(keywords: [DocumentKeyword(text: "PERSONEL")])
)
// veya: try DocumentProfile(decoding: jsonData)
```

`FieldRegion` normalize koordinattır (0–1); alan yalnızca belgedeki o bölgede aranır — bu,
hem hızı hem isabeti ciddi artırır.

## Doğrulayıcılar

Kayıtlı doğrulayıcılar sonucu `validationResults`'a işler; `doc.isValid` hepsinin özetidir:

- `TCKNValidator` — TC kimlik numarası checksum kontrolü
- `MRZValidator` — MRZ satır check-digit kontrolü

Kendi kuralınız için `DocumentValidator` protokolünü uygulayın:

```swift
struct AgeValidator: DocumentValidator {
    let key = "birthDate"
    func validate(_ document: inout RecognizedDocument) -> [ValidationResult] {
        // doc.fields["birthDate"] üzerinden 18+ kontrolü...
    }
}
Task { await DocumentValidatorRegistry.shared.register(AgeValidator()) }
```

---

## Sonuç Modeli — `RecognizedDocument`

| Alan | Anlam |
|---|---|
| `croppedImage` | Kırpılmış, perspektifi düzeltilmiş belge görseli |
| `fields` | Alan sözlüğü (`FieldDescriptor.key` → `DocumentField`) |
| `rawText` | Belgeden okunan tüm ham metin |
| `validationResults` | Alan bazlı doğrulama sonuçları |
| `isValid` | Tüm zorunlu doğrulamalar geçti mi |
| `profileID` | Sonucu üreten profil |

## Görünüm ve Davranış Ayarları

`IdentityScannerView`'ın tüm init parametreleri:

| Parametre | Ne işe yarar |
|---|---|
| `profile` | Hangi belge, nasıl taranır (yukarıda) |
| `style: QuadrilateralStyle` | Dörtgen overlay'in görünümü (köşe stili, renkler) |
| `configuration: ScannerConfiguration` | HUD metinleri + zamanlama + çerçeve modu (aşağıda) |
| `frameMode: ScannerFrameMode?` | Çerçeve modunu tek çağrı için ezer (`nil` → configuration'ınki) |
| `debugROI` | Alan bölgelerini ekranda çizer (geliştirme) |
| `externalTorchOn` | El feneri kontrolünü dışarıdan bağlama (`Binding<Bool>`) |
| `onTorchAvailability` | Cihazda fener var/yok bildirimi |
| `speechKey` / `speechModule` | Açılışta sesli yönerge ([ReadAloud](../../IdentifySample/Modules/ReadAloud.md) sistemiyle) |
| `onResult` | `Result<RecognizedDocument, Error>` |

**Değiştirilemeyenler (şu an):** tarayıcının kendi HUD'u — talimat metninin konumu ve yazı
stili, manuel çekim ve iptal düğmeleri — gizlenemez; yalnız metinleri değişir. Çerçevenin
**içine** host içeriği (ör. kart çizimi) konamaz. Fener, kapat, adım göstergesi gibi öğeleri
tarayıcının üstüne `ZStack` ile kendiniz çizebilirsiniz.

Tarayıcı sonucu teslim edince kendini `dismiss()` eder: `fullScreenCover` / `sheet` içinde
sunun, bir ekranın gövdesine doğrudan gömmeyin. En kısa yol `.documentScanner(isPresented:…)`
modifier'ıdır — sunumu ve kapanışı kendisi yapar, `navOverlay` ile üstüne katman koyarsınız.

### HUD Metinleri ve Zamanlama — `ScannerConfiguration`

Tarayıcının tüm rehber metinleri (`idle`, `focusing`, `reading`, `locked`, `tooClose`,
`tooFar`, `centreDocument`, `align`, `glare`, `manualCapture`, `orientation`...) aktif SDK
diline göre hazır gelir ve tek tek değiştirilebilir. `glare` boş verilirse yalnız metin
kapanır, kapı çalışmaya devam eder (kapıyı kapatmak için bkz. [Otomatik Davranışlar](#otomatik-davranışlar--scannerautomation)). Üç hazır kompozisyon vardır ve **global override kancaları** sunar:

```swift
ScannerConfiguration.default    // kimlik kartı (override: .overrideDefault)
ScannerConfiguration.passport   // pasaport      (override: .overridePassport)
ScannerConfiguration.document   // serbest belge (override: .overrideDocument)

// Örnek: tüm kimlik taramalarında bekleme metnini değiştir
var cfg = ScannerConfiguration.default
cfg.texts.idle = "Kimliğinizi çerçeveye yerleştirin"
ScannerConfiguration.overrideDefault = cfg
```

`timing` tarafında yakalama hızı, odak davranışı ve manuel yakalama gecikmesi ayarlanır
(`ScannerTimingConfig`).

### Çerçeve Modu — `ScannerFrameMode`

Tarayıcı, belgenin karede nerede olduğuna iki yoldan birinden karar verir:

| Mod | Nasıl çalışır |
|---|---|
| `.fixedFrame(ScannerFixedFrame)` | Ekranda **sabit** bir çerçeve çizilir; kullanıcı belgeyi ona hizalar. OCR yalnız çerçevenin içini okur. **Varsayılan.** |
| `.dynamicQuad` | Belge canlı dikdörtgen tespitiyle **takip edilir**, perspektifi düzeltilir. |

Seçim belge türü başına yapılır — `ScannerConfiguration` presetleri zaten türe göre ayrık:

```swift
// Varsayılanlar — üçü de sabit çerçeve
ScannerFrameMode.idCardDefault   = .fixedFrame(.idCard)     // kimlik
ScannerFrameMode.passportDefault = .fixedFrame(.passport)   // pasaport
ScannerFrameMode.documentDefault = .fixedFrame(.document)   // serbest belge

// Takip moduna dönmek: tek satır
ScannerFrameMode.idCardDefault = .dynamicQuad

// Çerçevenin ölçüsü de ayarlanabilir — ölçüler EKRAN NOKTASI cinsinden
ScannerFrameMode.idCardDefault = .fixedFrame(
    ScannerFixedFrame(aspect: 1.585,          // belgenin en/boy oranı
                      horizontalPadding: 15,  // iki yandan boşluk (pt)
                      verticalOffset: -24,    // merkezden kaydırma (pt, negatif = yukarı)
                      cornerRadius: 16)       // köşe yarıçapı (pt)
)
```

Hazır geometriler: `.idCard` (ID-1, 1.585), `.passport` (TD3 veri sayfası, 1.42),
`.document` (A4 dikey, 0.707) — üçü de 15pt yan boşluk + 16pt köşe yarıçapı +
`maxWidth: 630`.

`maxWidth` çerçevenin nokta cinsinden üst genişliğidir; telefonda devreye girmez, tablette
belirleyicidir. Yan boşluk kuralı iPad'de ~790 pt'lik bir çerçeve çizer ve kullanıcıdan
85 mm'lik kartı lensin yakın odak sınırının içine sokmasını ister — belge çerçeveyi asla
dolduramaz, otomatik çekim tetiklenmez. Değeri düşürmek de bedelsiz değildir: çerçeve
kırpılıp gönderilen bölgedir, yarıya indirmek OCR'a giden pikseli dörtte bire düşürür.

> Çerçeve **ekran noktasında** ölçülür, sonra kamera koordinatına çevrilir. Tersi
> (kamera tamponuna göre ölçmek) sezgisel ama yanlıştır: önizleme tamponu kırparak
> ekranı doldurur, dolayısıyla tampon genişliğinin %90'ı görünür genişliğin %90'ı
> **değildir** — çerçeve ekran dışına taşar ve kırpılan bölge belgeden çok daha geniş
> kalır. Ekranda ölçmek, gördüğünüz çerçeve ile kırpılan bölgeyi tanım gereği eşitler.

Sabit modda **lens/kamera geçişi kapalıdır** — geçişin tek amacı tespiti kurtarmaktı,
sabit çerçevede kurtarılacak tespit yok ama kadrajın kayma bedeli aynen sürüyor. Otomatik
çekim mekanizması iki modda da aynıdır: alanlar eşleşince tarama çizgisi başlar, iki aday
görüntüden en keskini teslim edilir.

**Teslim edilen görüntü çerçeveye değil, belgeye kırpılır.** Sabit çerçeve kullanıcı
yönlendirmesi ve OCR bölgesidir; çekim anında çerçevenin içinde belgenin gerçek kenarları
aranır ve kırpma ona göre yapılır — dinamik moddaki davranışın aynısı. Bulunamazsa ya da
bulunan şey belgeye benzemiyorsa çerçeve kırpması teslim edilir; yani deneme hiçbir şeyi
kötüleştiremez.

### Mesafe kapısı — "çerçeveye oturmadan çekmez"

Sabit modda çekim, belge çerçeveye oturana kadar onaylanmaz; bu sırada ne yapılması
gerektiği HUD'da yazar:

| Durum | Yönerge |
|---|---|
| Belge çerçeveyi taşıyor | "Kimliği biraz uzaklaştırın" |
| Belge çerçevenin epey içinde (uzaktan çekim) | "Kimliği biraz yaklaştırın" |
| Boyut doğru ama bir yana kaymış | "Kimliği çerçeveye ortalayın" |
| Netlik gelmiyor ve lens yakın sınırda | "Kimliği biraz uzaklaştırın" — belge asgari odak mesafesinin içinde |
| Belgede parlama var | `texts.glare` — patlamış piksel oranı eşiği aşınca çekim bekletilir |

Oturduktan sonra da çekim hemen değil, **görüntü sabitlenince** alınır: ardışık kareler
arası fark (kamera ya da belge hareketi) ve cihaz IMU'su birlikte sakin okunmalı, ardından
0.5 sn beklenir. Amaç hareket yasağı değil, bulanık kare yüklenmesini engellemektir. Mesafe
kararında histerezis vardır; belge bir kez oturduktan sonra sınırda "yaklaştır / uzaklaştır"
arasında titremez.

Ölçü `ScannerFixedFrame` üzerinden ayarlanır:

```swift
ScannerFixedFrame(aspect: 1.585,
                  captureFitTolerance: 30,   // pt — kenar başına izin verilen boşluk
                  overflowTolerance: 4)      // pt — çerçeveyi taşma payı
```

`captureFitTolerance` varsayılan 30pt: 360pt genişliğindeki bir çerçevede belgenin en az
~%83'ünü doldurması gerekir. 10'a çekmek neredeyse tam oturma ister; yükseltmek gevşetir.

Boyut ve konum **ayrı** ölçülür: boyut, karşılıklı kenarların toplam boşluğuna bakar
(belgenin nerede durduğu bunu değiştirmez), kaymışlık ise bu boşluğun iki yana ne kadar
dengesiz dağıldığına. Aksi hâlde doğru boyutta ama sola kaymış bir kimliğe "yaklaştırın"
denirdi.

> Kapı yalnız **kanıt varken** kısıtlar: belgenin kenarları bulunamıyorsa (koyu kart +
> koyu zemin, düşük ışık) karar üretilmez ve çekim eskisi gibi serbest kalır. Aksi hâlde
> tarayıcı hiç tetiklenmeyen bir ekrana dönüşebilirdi. Elle çekim düğmesi her hâlükârda
> kapıdan muaftır.

Tüm profiller dener, ama başarı oranı profile göre değişir: dikdörtgen tespitinin en-boy
ve güven eşikleri profile özeldir. Kimlik/ehliyet en çok kazanan taraftır — alan ROI'leri
karta göre tanımlı olduğundan kırpmanın kayması bölgesel OCR'ı da kaydırır. Tanınmayan
belge profili en katı eşiklere sahip olduğu için en sık çerçeveye düşendir.

### Otomatik Davranışlar — `ScannerAutomation`

Tarayıcının kullanıcı bir şey yapmadan yaptığı işler. `autoTorch` varsayılan olarak
**kapalı**, diğerleri **açıktır**; değiştirmek için:

```swift
// Tüm tarayıcılar için (kimlik, pasaport, belge) — tarayıcı açılmadan önce
ScannerAutomation.default.autoTorch = true

// Yalnız bir tarayıcı için
var cfg = ScannerConfiguration.default
cfg.automation.manualCaptureFallback = false
IdentityScannerView(profile: .turkishIDFront, configuration: cfg) { … }
```

| Anahtar | Açıkken ne yapar | Kapatınca |
|---|---|---|
| `autoTorch` (varsayılan kapalı) | Sahne çok karanlıksa ve belge 4 sn bulunamazsa feneri açar. Kamerayı elle kapatmak da karanlık sahne sayılır. | Fener yalnız kullanıcı ya da host açarsa açılır. |
| `ultraWideLensSwitch` | Belge kadrajı dolduruyor ama geniş lens netleyemiyorsa (çok yakın) ultra-geniş lense geçer, "uzaklaştırın" der. | Geniş lenste kalır; kullanıcı kartı netlenene kadar uzaklaştırmalıdır. |
| `wideLensRecovery` | Ultra-geniş lensten geniş lense kendiliğinden döner (senaryolar aşağıda). | Ultra-geniş lense geçildiyse tarama bitene kadar orada kalır. |
| `manualCaptureFallback` | Otomatik çekim zorlanınca **Elle çek** düğmesini gösterir: `manualCaptureHintDelay` sn sonra ya da `maxAutoCaptureFails` başarısız denemeden sonra. | Düğme hiç çıkmaz; tarayıcı başarılı olana ya da kullanıcı ekrandan çıkana kadar otomatik çekimi dener. |
| `glareGate` | Kartta parlama varken çekimi bekletir, `texts.glare` metnini gösterir. | Parlama yok sayılır; yansıma altındaki alanlar OCR'da okunamayabilir. |

#### Fener düğmesi

Fener düğmesi (tarayıcının kendi düğmesi ve hazır kimlik ekranının üst çubuğundaki düğme)
`ScannerConfiguration.showsTorchButton` ile gizlenir. Varsayılan açık.

```swift
// Tüm tarayıcılar için
ScannerConfiguration.showsTorchButtonDefault = false


// Yalnız bir tarayıcı için
var cfg = ScannerConfiguration.default
cfg.showsTorchButton = false
```

Kapatılamayanlar: loş ışıkta görünmez pozlama artırımı ve kontrast destekli ikinci tespit
geçişi. İkisi de ekranda görünmez, yalnız tespiti kurtarır. Çekim titreşimi `SDKHapticConfig`
ile (modül bazında da) kapatılır. `.fixedFrame` modunda lens hiç değişmez; iki lens anahtarı
yalnız `.dynamicQuad` modunda anlam taşır.

#### Lens senaryoları

Tarayıcı her zaman geniş lensle açılır.

| Senaryo | `ultraWideLensSwitch` | `wideLensRecovery` | Sonuç |
|---|---|---|---|
| Kart çok yakın, geniş lens netleyemiyor | açık | — | Ultra-geniş lense geçer, "uzaklaştırın" der. Geçişten sonra 4 sn (`lensCommitHoldDuration`) lens değişmez. |
| Ultra-genişe geçildi, kart kadrajda küçüldü ve 2 sn görünmedi | açık | açık | Geniş lense döner. |
| Ultra-genişe geçildi, kart görünüyor ama bekleme süresinden sonra da netlenmiyor | açık | açık | Kart aslında yakın değilmiş; geniş lense döner. |
| Yukarıdaki iki durum | açık | **kapalı** | Ultra-geniş lenste kalır. Kart kadrajda küçükse kullanıcı yaklaştırmalıdır; tarama ekranı kapanınca sıfırlanır. |
| Kart çok yakın | **kapalı** | fark etmez | Geçiş olmaz; geniş lenste kalır. |

### Diğer Davranışlar

- Dokunarak odaklama (sarı odak göstergesi); sabit çerçevede belge oturunca **tek atış odak
  dürtmesi** — nokta değişmediği için sürekli AF'e ikinci kez yazmak hiçbir şey yapmıyordu
- Pasaport dik tutulursa **"yana çevirin"** yönlendirmesi

---

## ⚠️ KYC Akışı İçinde Kullanmayın (Bypass)

Kural tarayıcıyı kullanmak değil, **sonucu kendiniz yüklemek** üzerinedir. KYC akışında:

| Yapılış | Sonuç |
|---|---|
| Override ekranında `IdentityScannerView` → `doc.croppedImage` → `vm.scanFront(image:)` / `vm.scanBack(image:)` | ✅ Doğru. SDK'nın kendi kimlik ekranı da tam olarak bunu yapar. |
| `RecognizedDocument`'i kendi HTTP isteğinizle göndermek | ❌ `upload` / `sendStep` gitmez, akış sunucuda ilerlemez. |

`vm.scanFront(image:)` tarayıcıyı çalıştırmaz; verilen görüntüye OCR yapıp yükler. Görüntünün
tarayıcıdan mı kendi kameranızdan mı geldiğini bilmez — kalite farkı buradan doğar.
Örnek ve iki yolun karşılaştırması: [IdCard rehberi](../../IdentifySample/Modules/IdCard/IdCard.md#kendi-tasarımınızla-override).

Akış dışında (form ön-doldurma, belge arşivleme, şube içi araçlar) tarayıcı tek başına da kullanılır.
