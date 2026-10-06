# IdentityScanner — Gerçek Zamanlı Belge Tarama Motoru

IdentityScanner, SDK'nın içindeki kamera tabanlı belge tarama motorudur. Kimlik ekranındaki
davranışların hepsi buradan gelir: belge dörtgenini canlı yakalama, alan alan OCR (TCKN, ad-soyad,
doğum tarihi...), MRZ okuma, perspektif düzeltme ve TCKN/MRZ doğrulaması. Bunların hepsi cihaz
üzerinde çalışır.

Motoru iki yoldan kullanırsınız:

1. Dolaylı: [IdCard](../../IdentifySample/Modules/IdCard/IdCard.md) ve
   [AddressConfirm](../../IdentifySample/Modules/AddressConfirm/AddressConfirm.md) modüllerinin hazır
   ekranları bu motoru zaten kullanır. Sizin bir şey yapmanız gerekmez.
2. Doğrudan: `IdentityScannerView`'ı kendi ekranlarınıza bağımsız bir bileşen olarak koyarsınız.
   Bu, KYC akışı dışındaki işler içindir (form ön-doldurma, belge arşivleme...).

Gereksinim: iOS 15+.

← [README'ye dön](../../README.md) · İlgili: [Özelleştirme](customization.md) · [Tema](theming.md)

---

## Kurulum — Tek Satır

Uygulama açılırken profilleri ve doğrulayıcıları kaydedin:

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

Kullanıcı belgeyi çerçeveye tutar. Kareler sabitlenince motor fotoğrafı kendisi çeker (gerekirse
elle çekim düğmesi çıkar), alanları okur, doğrular ve sonucu döndürür.

---

## Hazır Profiller

Profil, bir belgenin nasıl taranacağını tarif eder: strateji, alan bölgeleri ve anahtar kelime
kapısı.

| Profil | Strateji | Ne yapar |
|---|---|---|
| `.turkishIDFront` | `visionText` | TC kimlik ön yüz: TCKN, soyad, ad, doğum tarihi, belge no. Alanlar bölgesel OCR ile okunur |
| `.turkishIDBack` | `mrzTurkishID` | TC kimlik arka yüz: anne adı, baba adı ve veren makam basılı etiketlerine göre bulunur (`labelAnchor`); MRZ kuralı `.td1`, zorunlu, `.presence` |
| `.turkishID` | — | Ön ve arka yüzün birleşik anahtar kelime kümesi |
| `.passport` | `mrzPassport` | Pasaport veri sayfası (TD3 MRZ); pasaport dik tutulursa "yana çevirin" yönergesi çıkar |
| `.turkishDrivingLicense` | `visionText` | TR ehliyet |
| `.bankCard` | `visionText` | Banka kartı |
| `.a4Document` / `.generic` | `imageOnly` | Serbest belge. Alan çıkarmaz, düzgün kırpılmış görsel verir (AddressConfirm bunu kullanır) |

Anahtar kelime kapısı (keyword gating): profildeki `keywordSet` içindeki ibareler ("TÜRKİYE
CUMHURİYETİ / KİMLİK KARTI" gibi) görünmeden çekim yapılmaz. Böylece masadaki rastgele bir
dikdörtgen kimlik sanılmaz.

## Kendi Profiliniz

`DocumentProfile` `Codable` olduğu için profili JSON'dan da yükleyebilirsiniz. Sunucudan profil
indirerek uygulamayı güncellemeden yeni bir belge tipini destekleyebilirsiniz:

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

`FieldRegion` normalize koordinat kullanır (0–1). Alan yalnızca belgenin o bölgesinde aranır; bu
hem hızı hem isabeti belirgin biçimde artırır. Alanı sabit bir bölge yerine basılı etikete göre
bulmak için `labelAnchor: LabelAnchor(variants: ["ANNE ADI", "MOTHER'S NAME"], direction: .below)`
verin. Belge çerçeveyi tam doldurmasa da bölge kaymaz.

### Neyin çekimi beklettiğine profil karar verir

Otomatik çekim iki şeye bakar ve ikisi de profilden okunur:

| Ne | Nasıl ayarlanır | Etkisi |
|---|---|---|
| Basılı alan | `FieldDescriptor.isRequired` | `true`: alan okunmadan çekim yapılmaz. `false`: okunursa sonuçta döner, çekim onu beklemez |
| MRZ | `DocumentProfile.mrz: MRZRequirement?` | `nil`: MRZ aranmaz. `isRequired: false`: okunur ama beklenmez. `true`: `level`'a göre beklenir |

`MRZRequirement(format:isRequired:level:)` parametreleri:

- `format`: `.td1` (kimlik, 3×30) ya da `.td3` (pasaport, 2×44).
- `level`: `.presence` MRZ bölgesinin görünmesi yeter; en az iki MRZ yapılı satır aranır, uzunluk
  ve kontrol hanesine bakılmaz. `.parsed` ise belge no, doğum tarihi ve geçerlilik tarihinin
  ayrıştırılmasını ister.

Kesin MRZ okuması çekimden sonra yapılır. Canlı kural yalnızca çekimin ne zaman yapılacağına
karar verir.

`.mrzTurkishID` stratejili bir profil `mrz` vermezse eski kural uygulanır
(`MRZRequirement.legacyTurkishID`: `.td1`, zorunlu, `.parsed`). JSON profilde `mrz` anahtarı yoksa
da aynısı olur.

### Hazır profili değiştirmek — kopya yardımcıları

Hazır profiller sabittir. Aşağıdaki yardımcıların her biri profilin değiştirilmiş bir kopyasını
döner:

```swift
let back = DocumentProfile.turkishIDBack
    .settingRequired(false, for: "fatherName")          // bir/birden çok alanı zorunlu ↔ zorunsuz
    .settingMRZRequired(false)                           // MRZ okunsun ama çekimi beklemesin
    // .settingMRZ(MRZRequirement(format: .td1, isRequired: true, level: .parsed))
    // .settingField(FieldDescriptor(key: "issuedBy", isRequired: true))   // alanı değiştir / ekle
    // .removingFields("documentType")                                       // hiç arama
    // .settingKeywordSet(nil)                                               // anahtar kelime kapısını kapat

IdentityScannerView(profile: back) { result in … }
```

Kopya iki yerde geçerli olur: kendi ekranınızdaki `IdentityScannerView(profile:)` içinde ya da
aynı `id` ile `DocumentProfileRegistry.shared.register(_:)` çağrıldıktan sonra `DocumentScanner`
içinde. SDK'nın hazır kimlik ekranı (`SDKIdCardView`) hazır profili doğrudan kullanır, kopyayı
görmez.

## Doğrulayıcılar

Kayıtlı doğrulayıcılar sonuçlarını `validationResults`'a yazar. `doc.isValid` bunların özetidir.

- `TCKNValidator`: TC kimlik numarasının checksum kontrolü
- `MRZValidator`: MRZ satırlarının check-digit kontrolü

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

`IdentityScannerView`'ın bütün init parametreleri:

| Parametre | Ne işe yarar |
|---|---|
| `profile` | Hangi belgenin nasıl taranacağı (yukarıya bakın) |
| `style: QuadrilateralStyle` | Dörtgen overlay'in görünümü (köşe stili, renkler) |
| `configuration: ScannerConfiguration` | HUD metinleri, zamanlama ve çerçeve modu (aşağıda) |
| `frameMode: ScannerFrameMode?` | Çerçeve modunu yalnızca bu çağrı için değiştirir (`nil` ise configuration'daki kullanılır) |
| `debugROI` | Alan bölgelerini ekranda çizer (geliştirme için) |
| `externalTorchOn` | El fenerini dışarıdan kontrol etmek için (`Binding<Bool>`) |
| `onTorchAvailability` | Cihazda fener olup olmadığını bildirir |
| `speechKey` / `speechModule` | Açılışta sesli yönerge ([ReadAloud](../../IdentifySample/Modules/ReadAloud.md) sistemiyle) |
| `dismissesOnResult` | Sonuçtan sonra ortamın `dismiss`'i çağrılsın mı (varsayılan `true`). Tarayıcıyı bir ekranın parçası olarak gömüyorsanız `false` verin, yoksa ekranın kendisi kapanır |
| `keepsCameraRunning` | Başarılı çekimden sonra kamera açık kalsın mı (varsayılan `false`). `true` verirseniz yalnızca kare işleme durur, önizleme canlı kalır |
| `scanSession` | Değeri değişince tarayıcı kamerayı yeniden kurmadan güncel `profile`/`configuration` ile yeni çekime hazırlanır (ön yüzden arka yüze geçerken). `keepsCameraRunning` ile birlikte anlamlıdır |
| `onResult` | `Result<RecognizedDocument, Error>` |

Şu an değiştiremedikleriniz: tarayıcının kendi HUD'u gizlenemez. Talimat metninin konumu ve yazı
stili, elle çekim ve iptal düğmeleri yerinde kalır; yalnızca metinleri değiştirebilirsiniz.
Çerçevenin içine host içeriği (ör. kart çizimi) koyamazsınız. Fener, kapat düğmesi ya da adım
göstergesi gibi öğeleri tarayıcının üstüne `ZStack` ile kendiniz çizebilirsiniz.

Tarayıcı varsayılan olarak sonucu teslim edince kendini `dismiss()` eder, bu yüzden onu
`fullScreenCover` ya da `sheet` içinde sunun. En kısa yol `.documentScanner(isPresented:…)`
modifier'ıdır: sunumu ve kapanışı kendisi yapar, üstüne katman koymak için `navOverlay`
kullanırsınız. Tarayıcıyı bir ekranın gövdesine gömecekseniz `dismissesOnResult: false` verin. Ön
ve arka yüzü aynı kamera oturumunda çekmek için `keepsCameraRunning: true` verip her yüzde
`scanSession`'ı artırın. Çalışan örnek:
[IdCardSingleScreenCustomView.swift](../../IdentifySample/Modules/IdCard/IdCardSingleScreenCustomView.swift).

### HUD Metinleri ve Zamanlama — `ScannerConfiguration`

Tarayıcının bütün yönerge metinleri (`idle`, `focusing`, `reading`, `locked`, `tooClose`,
`tooFar`, `centreDocument`, `align`, `glare`, `manualCapture`...) aktif SDK diline
göre hazır gelir ve her biri tek tek değiştirilebilir. `glare` metnini boş verirseniz yalnızca
metin kaybolur, parlama kontrolü çalışmaya devam eder (kontrolü kapatmak için
[Otomatik Davranışlar](#otomatik-davranışlar--scannerautomation) bölümüne bakın).

Üç hazır kompozisyon var ve her birinin global override kancası bulunuyor:

```swift
ScannerConfiguration.default    // kimlik kartı (override: .overrideDefault)
ScannerConfiguration.passport   // pasaport      (override: .overridePassport)
ScannerConfiguration.document   // serbest belge (override: .overrideDocument)

// Örnek: tüm kimlik taramalarında bekleme metnini değiştir
var cfg = ScannerConfiguration.default
cfg.texts.idle = "Kimliğinizi çerçeveye yerleştirin"
ScannerConfiguration.overrideDefault = cfg
```

Çekim hızı, odak davranışı ve elle çekim düğmesinin gecikmesi `timing` altında ayarlanır
(`ScannerTimingConfig`).

Duruma bağlı dört metin daha vardır. Boş bırakılan gösterilmez:

| Metin | Ne zaman | Kimlik için varsayılan |
|---|---|---|
| `preparing` | Kamera ilk karesini verene kadar. | Hazırlanıyor... |
| `start` | Belge bu taramada tanınana kadar; tanındıktan sonra yerini `idle` alır. Anahtar kelimesi olmayan profillerde (pasaport, serbest belge) belge "tanınmaz", metin kalır. | SDK'nın kimlik ekranında "Belgenin Ön Yüzünü Hizalayın" / "Belgenin Arka Yüzünü Hizalayın"; `IdentityScannerView` doğrudan kullanılıyorsa boş |
| `notDetected` | Çerçeveye oturan nesnede belgenin anahtar kelimeleri `timing.notDetectedDelay` (varsayılan `4.0` sn) boyunca bulunamazsa: başka bir kart ya da yanlış yüz. | Kimlik tespit edilemedi. Lütfen geçerli bir kimlik kartı kullanın. |
| `orientation` | Sabit çerçevede belge dik tutulursa. Pasaportta gösterilmez. | Kimliği yatay tutun |

#### Yönergelerin seslendirilmesi

Ekrandaki yönerge her değiştiğinde sesli okunur (`ScannerAutomation.guidanceSpeech`,
varsayılan açık). Süren okuma bölünmez; arada birkaç yönerge değişirse yalnız sonuncusu
okunur. Kamera ilk karesini vermeden hiçbir şey okunmaz, bu yüzden `preparing` sessizdir.

Ses, modülün sesli okuma modunu izler: `SDKSpeechConfig` o modül için `.off` ise yönergeler de
sessizdir. Okunan metin ekrandaki metindir. Sesin farklı bir cümle okuması için anahtarın
sonuna `Tts` ekleyip o metni de kaydedin:

```swift
// Tek bir yönergeyi değiştir (ekranda ve seste)
SDKLocalization.shared.setOverride(key: .scannerTooFarId, language: .tr,
                                   value: "Kimliği kameraya yaklaştırın")

// Ekranda kısa metin, seste tam cümle
SDKLocalization.shared.registerOverrides([.tr: [
    "ScannerTooCloseId":    "Uzaklaşın",
    "ScannerTooCloseIdTts": "Kimliğinizi uzaklaştırın",
]])

// Kendi ses kaydınız: anahtarla aynı adlı klibi bundle'a koyun (ScannerTooFarId.m4a)
SDKSpeechConfig.shared.setMode(.customAudio, for: .idCard)

// Yönergeleri seslendirme, yalnız baştaki talimat okunsun
ScannerAutomation.default.guidanceSpeech = false
```

Dile özel kayıt için dosya adına dil kodu eklenir (`ScannerTooFarId_tr.m4a`). Klip yalnız
SDK'nın hazır metinleri için aranır. `ScannerGuidanceTexts`'e elle yazdığınız metnin anahtarı
yoktur; o metin sistem sesiyle okunur, `fallbackToNativeIfAudioMissing` kapalıysa okunmaz.
`Tts` ekli ayrı ses metni de yalnız hazır metinlerde çalışır.

### Çerçeve Modu — `ScannerFrameMode`

Tarayıcı belgenin karedeki yerini iki yoldan biriyle bulur:

| Mod | Nasıl çalışır |
|---|---|
| `.fixedFrame(ScannerFixedFrame)` | Ekrana sabit bir çerçeve çizilir, kullanıcı belgeyi ona hizalar. OCR yalnızca çerçevenin içini okur. Varsayılan budur. |
| `.dynamicQuad` | Belge canlı dikdörtgen tespitiyle takip edilir ve perspektifi düzeltilir. |

Mod her belge türü için ayrı seçilir. `ScannerConfiguration` presetleri de zaten türe göre ayrıdır:

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

Hazır geometriler `.idCard` (ID-1, 1.585), `.passport` (TD3 veri sayfası, 1.42) ve `.document`
(A4 dikey, 0.707). Üçünde de 15pt yan boşluk, 16pt köşe yarıçapı ve `maxWidth: 630` var.

`maxWidth` çerçevenin nokta cinsinden en fazla ne kadar genişleyeceğini belirler. Telefonda bu
sınıra hiç ulaşılmaz, tablette ise belirleyici olur. Yalnızca yan boşluk kuralıyla iPad'de
yaklaşık 790 pt'lik bir çerçeve çizilirdi ve kullanıcının 85 mm'lik kartı lensin yakın odak
sınırından daha yakına getirmesi gerekirdi. Belge çerçeveyi hiç dolduramaz, otomatik çekim de
tetiklenmezdi. Değeri düşürmenin de bir bedeli var: kırpılıp gönderilen bölge çerçevedir, onu
yarıya indirirseniz OCR'a giden piksel sayısı dörtte bire düşer.

> Çerçeve önce ekran noktasında ölçülür, sonra kamera koordinatına çevrilir. Kamera tamponuna göre
> ölçmek daha sezgisel görünse de yanlış sonuç verir. Önizleme ekranı doldurmak için tamponu
> kırpar; bu yüzden tampon genişliğinin %90'ı görünen genişliğin %90'ı etmez. Çerçeve ekrandan
> taşar ve kırpılan bölge belgeden çok daha geniş kalır. Ekranda ölçünce gördüğünüz çerçeve ile
> kırpılan bölge birebir aynı olur.

Sabit modda lens ve kamera geçişi kapalıdır. Geçişin tek amacı kaybolan tespiti kurtarmaktı. Sabit
çerçevede kurtarılacak bir tespit yok, ama geçiş kadrajı yine kaydırırdı. Otomatik çekim iki modda
da aynı işler: alanlar eşleşince tarama çizgisi başlar ve iki aday görüntüden en keskini teslim
edilir.

Teslim edilen görüntü çerçeveye göre değil, belgeye göre kırpılır. Sabit çerçeve kullanıcıyı
yönlendirir ve OCR bölgesini belirler. Çekim anında çerçevenin içinde belgenin gerçek kenarları
aranır ve kırpma bunlara göre yapılır; dinamik modda da davranış aynıdır. Kenarlar bulunamazsa ya
da bulunan şekil belgeye benzemezse çerçeve kırpması teslim edilir. Yani bu deneme sonucu hiçbir
durumda kötüleştirmez.

### Mesafe kapısı — "çerçeveye oturmadan çekmez"

Sabit modda belge çerçeveye oturana kadar çekim yapılmaz. Bu sırada HUD kullanıcıya ne yapması
gerektiğini söyler:

| Durum | Yönerge |
|---|---|
| Belge çerçeveden taşıyor | "Kimliği biraz uzaklaştırın" |
| Belge çerçevenin epey içinde kalıyor (uzaktan çekim) | "Kimliği biraz yaklaştırın" |
| Boyut doğru ama bir yana kaymış | "Kimliği çerçeveye ortalayın" |
| Netlik gelmiyor ve lens yakın sınırda | "Kimliği biraz uzaklaştırın" (belge asgari odak mesafesinden daha yakında) |
| Belgede parlama var | `texts.glare`. Patlamış piksel oranı eşiği aşınca çekim bekletilir |

Belge oturduktan sonra da çekim hemen yapılmaz, görüntünün sabitlenmesi beklenir. Ardışık kareler
arasındaki fark (kamera ya da belge hareketi) ve cihazın IMU'su birlikte sakin görünmeli, sonra
0.5 sn daha beklenir. Amaç kullanıcıyı kıpırdamaz hale getirmek değil, bulanık kare yüklenmesini
önlemektir. Mesafe kararında histerezis var; belge bir kez oturduktan sonra yönerge sınırda
"yaklaştırın" ile "uzaklaştırın" arasında gidip gelmez.

Ölçüyü `ScannerFixedFrame` ile ayarlarsınız:

```swift
ScannerFixedFrame(aspect: 1.585,
                  captureFitTolerance: 30,   // pt — kenar başına izin verilen boşluk
                  overflowTolerance: 4)      // pt — çerçeveyi taşma payı
```

`captureFitTolerance` varsayılan olarak 30pt'dir. 360pt genişliğindeki bir çerçevede bu, belgenin
çerçevenin en az %83 kadarını doldurması demektir. 10'a indirirseniz neredeyse tam oturma istenir,
yükseltirseniz kural gevşer.

Boyut ve konum ayrı ölçülür. Boyut için karşılıklı kenarlardaki toplam boşluğa bakılır; belgenin
nerede durduğu bu değeri değiştirmez. Kaymışlık için bu boşluğun iki yana ne kadar dengesiz
dağıldığına bakılır. İkisi ayrı ölçülmeseydi doğru boyutta ama sola kaymış bir kimlik için
"yaklaştırın" denirdi.

> Kapı yalnızca elinde kanıt varken çekimi kısıtlar. Belgenin kenarları bulunamıyorsa (koyu kart
> ve koyu zemin, düşük ışık) karar üretilmez ve çekim eskisi gibi serbest kalır. Öyle olmasaydı
> tarayıcı hiç tetiklenmeyen bir ekrana dönüşebilirdi. Elle çekim düğmesi her durumda bu kapının
> dışındadır.

Bütün profiller belgenin kenarlarını bulmayı dener, ama başarı oranı profile göre değişir; çünkü
dikdörtgen tespitinin en-boy ve güven eşikleri profile özeldir. En çok kimlik ve ehliyet kazanır:
alan ROI'leri karta göre tanımlandığından kırpmadaki kayma bölgesel OCR'ı da kaydırır. Tanınmayan
belge profili en katı eşiklere sahip olduğu için en sık çerçeve kırpmasına düşer.

### Otomatik Davranışlar — `ScannerAutomation`

Tarayıcının kullanıcıdan bir şey beklemeden yaptığı işler bunlar. `autoTorch` varsayılan olarak
kapalı, diğerleri açık. Değiştirmek için:

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
| `autoTorch` (varsayılan kapalı) | Sahne çok karanlıksa ve belge 4 sn boyunca bulunamazsa feneri açar. Kameranın elle kapatılması da karanlık sahne sayılır. | Fener yalnızca kullanıcı ya da host açarsa yanar. |
| `ultraWideLensSwitch` | Belge kadrajı dolduruyor ama geniş lens netleyemiyorsa (belge çok yakın) ultra-geniş lense geçer ve "uzaklaştırın" der. | Geniş lenste kalır; kullanıcının kartı netlik gelene kadar uzaklaştırması gerekir. |
| `wideLensRecovery` | Ultra-geniş lensten geniş lense kendiliğinden döner (senaryolar aşağıda). | Ultra-geniş lense geçildiyse tarama bitene kadar orada kalınır. |
| `manualCaptureFallback` | Otomatik çekim zorlanınca **Elle çek** düğmesini gösterir: `manualCaptureHintDelay` sn geçince ya da `maxAutoCaptureFails` kez başarısız denemeden sonra. | Düğme hiç çıkmaz. Tarayıcı başarılı olana ya da kullanıcı ekrandan çıkana kadar otomatik çekimi dener. |
| `glareGate` | Kartta parlama varken çekimi bekletir ve `texts.glare` metnini gösterir. | Parlama yok sayılır; yansımanın altında kalan alanlar OCR'da okunamayabilir. |
| `exposureBoost` | Loş ışıkta görüntüyü biraz aydınlatır (+0.7 EV). Belge bulunamazsa ya da belge görünüp zorunlu alanlar okunmuyorsa (gölge) 1,5 sn sonra devreye girer. Kullanıcı fark etmez. | Kameranın kendi pozlaması kullanılır. |
| `fieldLocking` | Geçerli okunan alan okunmuş kalır; alanların aynı karede okunması gerekmez. Hepsi kilitlenince OCR durur, çekim yalnızca net ve sabit bir kare bekler. Ayrıntı aşağıda. | Zorunlu alanların hepsi aynı karede, art arda birkaç karede okunmalıdır. Değerler her zaman fotoğraftan gelir. |
| `facePhotoCheck` | Vesikalık canlıda görülüp çekilen fotoğrafta bulunamazsa (üstünde el varsa) çekimi kabul etmez. | Fotoğrafta vesikalık aranmaz. |
| `guidanceSpeech` | Ekrandaki yönerge her değiştiğinde sesli okunur (modülün sesli okuma modu açıksa). | Yalnızca tarama başındaki talimat okunur. |

#### Alan kilitleme

`fieldLocking` açıkken tarayıcı her alanı bir kez geçerli okuyunca kilitler ve o alanı yeniden
aramaz. Gölgede ya da titrek elde bir alanın arada bir okunamaması çekimi geciktirmez.

- TC no sağlamasından geçtiği için tek okumada kilitlenir. Diğer alanlar ve MRZ aynı değer
  iki kez okununca kilitlenir.
- Kilit süreyle düşmez. Kart çerçeveden çıkınca ya da kadraj büyük oynayınca düşer; eşik
  `ScannerTimingConfig.fieldLockDropMotion` (varsayılan `15`).
- Çekimden sonra fotoğraftan okunan değerler kilitlenenlerle karşılaştırılır. Harf büyüklüğü,
  aksan ve boşluk farkı sayılmaz.
- Zorunlu bir alan fotoğrafta yoksa ya da farklıysa (üstünde parmak, parlama) tarayıcı
  beklemeden bir fotoğraf daha çeker ve onu kilitli değerlerle teslim eder. İkinci fotoğraf
  okunmaz.

İkinci durumda `RecognizedDocument.fields` teslim edilen görüntüden değil canlı karelerden
gelir. Değerlerin her zaman teslim edilen fotoğraftan okunmasını isteyen entegratör kilitlemeyi
kapatır:

```swift
ScannerAutomation.default.fieldLocking = false
```

Pasaportta ve `imageOnly` profillerde kilitleme yoktur.

#### Düşük ışık eşikleri

Pozlama artışının ve fenerin ne zaman devreye gireceği `ScannerTimingConfig` ile ayarlanır.
Varsayılanlar aşağıdaki gibidir.

| Alan | Varsayılan | Anlamı |
|---|---|---|
| `exposureBoostISO` | `700` | Bu ISO'nun üstü loş sayılır. Normal iç mekân 100–400 civarıdır. |
| `exposureBoostReleaseISO` | `400` | ISO buna inince artış geri alınır. `exposureBoostISO`'dan belirgin düşük olmalı. |
| `exposureBoostDelay` | `1.5` | Artıştan önce sahnenin loş kalması gereken süre (sn). |
| `exposureBoostEV` | `0.7` | Artış miktarı (EV). Yükseldikçe görüntü aydınlanır ama gürültü artar, açık renkli kart patlayabilir. |
| `autoTorchISO` | `1400` | `autoTorch` açıkken fenerin yanabileceği ISO. |
| `autoTorchDelay` | `4.0` | Fener için belge bulunamadan geçmesi gereken süre (sn). Belge kadrajdayken fener kendiliğinden açılmaz. |

```swift
// Gölgede daha erken ve daha güçlü aydınlat
ScannerConfiguration.default.timing.exposureBoostISO = 500
ScannerConfiguration.default.timing.exposureBoostEV = 1.0
```

#### Fener düğmesi

Fener düğmesini (tarayıcının kendi düğmesi ve hazır kimlik ekranının üst çubuğundaki düğme)
`ScannerConfiguration.showsTorchButton` ile gizlersiniz. Varsayılan olarak görünür.

```swift
// Tüm tarayıcılar için
ScannerConfiguration.showsTorchButtonDefault = false


// Yalnız bir tarayıcı için
var cfg = ScannerConfiguration.default
cfg.showsTorchButton = false
```

İki davranış kapatılamaz: loş ışıkta pozlamanın fark ettirmeden artırılması ve kontrast destekli
ikinci tespit geçişi. İkisi de ekranda görünmez, yalnızca tespiti kurtarır. Çekim titreşimini
`SDKHapticConfig` ile (modül bazında da) kapatabilirsiniz. `.fixedFrame` modunda lens hiç değişmez;
iki lens anahtarının yalnızca `.dynamicQuad` modunda bir etkisi vardır.

#### Lens senaryoları

Tarayıcı her zaman geniş lensle açılır.

| Senaryo | `ultraWideLensSwitch` | `wideLensRecovery` | Sonuç |
|---|---|---|---|
| Kart çok yakın, geniş lens netleyemiyor | açık | — | Ultra-geniş lense geçer, "uzaklaştırın" der. Geçişten sonra 4 sn boyunca (`lensCommitHoldDuration`) lens değişmez. |
| Ultra-genişe geçildi, kart kadrajda küçüldü ve 2 sn görünmedi | açık | açık | Geniş lense döner. |
| Ultra-genişe geçildi, kart görünüyor ama bekleme süresinden sonra da netlenmiyor | açık | açık | Kart aslında yakın değilmiş; geniş lense döner. |
| Yukarıdaki iki durum | açık | **kapalı** | Ultra-geniş lenste kalır. Kart kadrajda küçükse kullanıcının yaklaştırması gerekir; tarama ekranı kapanınca lens sıfırlanır. |
| Kart çok yakın | **kapalı** | fark etmez | Geçiş olmaz, geniş lenste kalır. |

### Diğer Davranışlar

- Dokunarak odaklama (sarı odak göstergesi). Sabit çerçevede belge oturunca odak bir kez daha
  tetiklenir; nokta değişmediği için sürekli AF'e aynı noktayı ikinci kez yazmak hiçbir işe
  yaramıyordu.
- Pasaport dik tutulursa "yana çevirin" yönergesi çıkar.

---

## ⚠️ KYC Akışı İçinde Kullanmayın (Bypass)

Kural tarayıcıyı kullanmanızı yasaklamaz; yasak olan, sonucu kendiniz yüklemektir. KYC akışında:

| Yapılış | Sonuç |
|---|---|
| Override ekranında `IdentityScannerView` → `doc.croppedImage` → `vm.scanFront(image:)` / `vm.scanBack(image:)` | ✅ Doğru. SDK'nın kendi kimlik ekranı da tam olarak bunu yapar. |
| `RecognizedDocument`'i kendi HTTP isteğinizle göndermek | ❌ `upload` / `sendStep` gitmez, akış sunucuda ilerlemez. |

`vm.scanFront(image:)` tarayıcıyı çalıştırmaz; verilen görüntüye OCR yapar ve yükler. Görüntünün
tarayıcıdan mı yoksa kendi kameranızdan mı geldiğini bilmez. İki yol arasındaki kalite farkı da
buradan doğar. Örnek ve iki yolun karşılaştırması:
[IdCard rehberi](../../IdentifySample/Modules/IdCard/IdCard.md#kendi-tasarımınızla-override).

Akış dışında (form ön-doldurma, belge arşivleme, şube içi araçlar) tarayıcıyı tek başına
kullanabilirsiniz.
