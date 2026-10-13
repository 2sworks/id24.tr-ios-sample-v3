# Hata Kanalı, Deneme Sınırları, Canlılık Kuralları ve Çoklu Yüz

Bu rehber dört ayarı anlatır:

| Ayar | Ne yapar |
|---|---|
| `SDKErrorConfig.shared` | Hataların nasıl gösterileceği, metinleri, canlı yönergeler |
| `SDKAttemptLimits.shared` | Modül başına deneme hakkı, hak bitince ne olacağı, bağlantı kopması |
| `SDKLivenessRules.default` | Canlılık adımının süresi ve yanlış hareket denetimi |
| `SDKFaceConfig.shared` | Kadrajda birden fazla yüz görülünce yapılacak iş |

Ayarlar `setupSDK` çağrılmadan önce verilir ve oturum boyunca geçerlidir. Hiçbirini
vermeyen entegrasyonda davranış değişmez; bilerek değişenler en sonda listelenir.

---

## İçindekiler

1. [Hata kanalı](#1-hata-kanalı)
2. [Hata metinlerini değiştirmek](#2-hata-metinlerini-değiştirmek)
3. [Canlı yönergeler](#3-canlı-yönergeler)
4. [Deneme sınırları](#4-deneme-sınırları)
5. [Bağlantı kopması](#5-bağlantı-kopması)
6. [Canlılık kuralları](#6-canlılık-kuralları)
7. [Çoklu yüz](#7-çoklu-yüz)
8. [Kendi ekranınızı yazdıysanız](#8-kendi-ekranınızı-yazdıysanız)
9. [Davranış değişiklikleri](#9-davranış-değişiklikleri)

---

## 1) Hata kanalı

Her modülün hatası tek bir modelle taşınır:

```swift
public struct SDKErrorInfo {
    public let module: SdkModules?       // modüle bağlı olmayan ekranda nil
    public let source: Source            // .local (cihaz) ya da .server (sunucu yanıtı)
    public let code: SDKErrorCode
    public let serverText: String?       // sunucunun gönderdiği ham metin
    public let message: String           // gösterilecek metin, sizin metniniz uygulanmış
    public let attemptsLeft: Int?        // kalan hak; sınır yoksa nil
    public let captureMode: SDKCaptureMode?  // .automatic / .manual; çekimden doğmadıysa nil
}
```

`captureMode` kimlik çekiminden doğan hatalarda dolar. Kendi kimlik ekranınızda tarayıcının
sonucunu ViewModel'e verdiğinizde çekim şekli kendiliğinden gelir:

```swift
viewModel.scanFront(document: document)
```

Yalnız görüntüyle çağırıyorsanız şekli siz verirsiniz: `scanFront(image:captureMode:)`.

SDK'nın popup'ı otomatik çekimin hatasında açılmaz. Hata kapatılmış sayılır ve kullanıcı aynı
yüzü yeniden tarar; hak bittiyse modül mesaj gösterilmeden atlanır ya da akış biter. Manuel
çekimin hatası popup olarak gösterilir. Hatayı kendiniz gösteriyorsanız aynı kuralı `onError`
içinde uygulayın:

```swift
SDKErrorConfig.shared.onError = { info, dismiss in
    if info.captureMode == .automatic { dismiss(); return }
    // kendi gösteriminiz
}
```

Gösterimi siz seçersiniz:

```swift
SDKErrorConfig.shared.presentation = .sdkPopup   // varsayılan: SDK'nın popup'ı
SDKErrorConfig.shared.presentation = .custom     // SDK popup açmaz
SDKErrorConfig.shared.presentation = .both       // ikisi birden

SDKErrorConfig.shared.onError = { info, dismiss in
    // info.message metnini kendi popup'ınızda ya da ekranın herhangi bir yerinde gösterin.
    // Kullanıcı kapatınca dismiss() çağırın: akış kaldığı yerden sürer
    // (aynı adımı yeniden dener, modülü atlar ya da akışı bitirir).
}
```

`onError` ana kuyrukta çağrılır. `.custom` seçip `onError` vermezseniz hata görünmez
kalmasın diye SDK popup'ı yine açılır. Görüntülü görüşme ekranındaki kırmızı hata bandı da
`.custom` iken gösterilmez.

Kendi modül ekranınızı yazdıysanız `.idErrorAlert` bu ayara zaten uyar. Hatayı başka bir
yolla çiziyorsanız (bant, toast) `SDKErrorConfig.shared.showsSDKPopup` false iken çizmeyin.

Kendi kimlik ekranınızda otomatik çekimin hatasını popup'sız geçmek için `isSilent` verin:

```swift
.idErrorAlert($viewModel.errorMessage,
              isSilent: { viewModel.lastError?.captureMode == .automatic },
              onDismiss: { viewModel.consumePendingAlertAction() })
```

`dismiss()` çağrılmazsa hata açık kalır ve akış ilerlemez.

### Kodlar

| Kod | Ne zaman |
|---|---|
| `.comparisonFailed` | Sunucunun karşılaştırması tutmadı, hak var |
| `.attemptsExhausted` | Karşılaştırma hakkı bitti |
| `.requestRejected` | Sunucu isteği reddetti ve anlamlı bir metin gönderdi |
| `.livenessStepTimeout` | Canlılık adımı süresinde yapılmadı |
| `.livenessWrongAction` | Canlılıkta başka bir adımın hareketi yapıldı |
| `.multipleFaces` | Kadrajda birden fazla yüz var |
| `.cameraFailed` | Kamera oturumu açılamadı ya da kesildi |
| `.generic` | Kodu bilinmeyen hata |
| `SDKErrorCode(.anahtar)` | SDK'nın kendi hatası; kod, gösterilen metnin dil anahtarıdır |

Örnek: yüz bulunamadı hatasının kodu `SDKErrorCode(.faceNotFound)`, mikrofon izni
hatasının kodu `SDKErrorCode(.micAccessError)`.

Ağ hatası için ayrı kod yok. SDK'nın ağ katmanı bağlantı hatasında da yalnızca
"istek başarısız" döndürüyor, ikisi ayırt edilemiyor.

### Olay akışı

Her hata `eventDelegate`'e de gider: ad `error.shown`, kategori `.error`, durum `.failed`.
`metadata` içinde `code`, `source` ve varsa `attemptsLeft` ile `captureMode` bulunur.

---

## 2) Hata metinlerini değiştirmek

Bir kodun metni dil ve modül bazında değiştirilir:

```swift
// Tüm modüllerde, tüm dillerde
SDKErrorConfig.shared.setMessage("Fotoğraflar eşleşmedi.", for: .comparisonFailed)
// Yalnız selfie'de, yalnız Türkçe
SDKErrorConfig.shared.setMessage("Yüzünüz kimlikle eşleşmedi.", for: .comparisonFailed,
                                 module: .selfie, language: .tr)
// SDK'nın kendi hatası
SDKErrorConfig.shared.setMessage("Yüz görünmüyor.", for: SDKErrorCode(.faceNotFound))
```

En dar eşleşme kazanır: modül ve dil, sonra yalnız modül, sonra yalnız dil, en son genel.

Sunucunun gönderdiği bir metin koduyla ayırt edilemiyorsa metnin kendisiyle eşlenir.
Büyük/küçük harf ve baştaki/sondaki boşluk önemsizdir:

```swift
SDKErrorConfig.shared.setServerMessage("Oturumunuzun süresi doldu.",
                                       forServerText: "The ident_id has expired.",
                                       language: .tr)
```

Sunucu metni eşleşmesi kod eşleşmesinden önce gelir.

---

## 3) Canlı yönergeler

Kamera ekranlarının anlık durumu hata sayılmaz, ayrı bir kanaldan gelir:

```swift
SDKErrorConfig.shared.onGuidance = { info in
    // info.module: .idCard, .idcard_w_ovd, .selfie, .selfieWithLiveness, .livenessDetection
    // info.state:  kimlik tarayıcısında durumun adı ("idle", "tooFar", "glare", "tilted" …),
    //              diğer ekranlarda nil
    // info.message: ekrandaki metin
}
```

Kimlik tarayıcısında `state`, `ScannerGuidanceTexts` alanının adıdır. Kendi yönerge
alanınızı kullanacaksanız SDK'nınkini kapatın: `ScannerConfiguration.showsGuidanceDefault = false`.

---

## 4) Deneme sınırları

Her modülün kendi sayacı vardır. Selfie'de harcanan hak canlılıktan, kimlikte harcanan hak
OVD'den düşmez. Sunucunun tek değeri ilgili modüllerin her birine ayrı uygulanır:

| Sunucu alanı | Modüller |
|---|---|
| `ocr_comparison_count` | `idCard`, `idcard_w_ovd` |
| `selfie_comparison_count` | `selfie`, `selfieWithLiveness`, `livenessDetection` |
| `nfc_comparison_count` | `nfc` |

Bir modüle kendi değerinizi verirseniz sunucununki ezilir:

```swift
SDKAttemptLimits.shared.set(SDKModuleLimits(comparison: .manual(2), onExhausted: .fail),
                            for: .selfie)
```

- `comparison`: `.server` (varsayılan) ya da `.manual(n)`. Sunucunun kapalı tuttuğu bir
  karşılaştırmayı elle verilen sınır açmaz.
- `onExhausted`: `.server` (`active_comparison_result_skip_module`), `.skip` (modül atlanır)
  ya da `.fail` (akış başarısız biter).

SDK'nın kendi sınırları:

| Ayar | Varsayılan | Ne sayar |
|---|---|---|
| `nfcRead` | `setupSDK(nfcMaxErrorCount:)` | Çip okunamadı. Dolunca anahtar düzeltme ekranı açılır |
| `nfcKeyEntry` | 3 | Düzeltilen anahtarla da okunamadı. Dolunca modül doğrulanmamış geçilir; NFC için `.fail` verilmişse akış biter |
| `livenessStepFailure` | 3 | Canlılık adımı süre ya da yanlış hareketle başarısız oldu. Her adım için ayrı sayılır |
| `livenessRecordingFailure` | 3 | Canlılık kaydı hatası (izin, başlatma, kesinti, boyut, yükleme) |
| `multipleFacesFailure` | 3 | Çoklu yüz `.fail` hatası |
| `livenessVideoUpload` | 3 | Canlılık videosu yükleme denemesi |
| `roomSubscribeRetry` | 3 | Oda doluyken yeniden abone olma |
| `speedTestBusyRetry` | 1 | Hız testinde sunucu meşgul yanıtı |

Canlılık ve çoklu yüz sınırları dolunca modülün `onExhausted` kuralı uygulanır.

```swift
SDKAttemptLimits.shared.nfcKeyEntry = .manual(5)
SDKAttemptLimits.shared.livenessStepFailure = .manual(0)   // 0: sınırsız
```

---

## 5) Bağlantı kopması

```swift
SDKAttemptLimits.shared.connection = SDKConnectionPolicy(
    maxDrops: 3,                 // oturum başına kopma; nil sınırsız (varsayılan)
    onExceeded: .exit,           // .exit akışı bitirir, .continue ekranı açmaya devam eder
    autoReconnectAttempts: 6,    // kopma ekranında kendiliğinden deneme; 0 kapalı (varsayılan)
    autoReconnectInterval: 5     // denemeler arası saniye
)
```

Yalnızca bağlantı koptu ekranını açan kopmalar sayılır. `.exit` ile biten akış
`onFinished` içinde `SDKFlowEndReason.connectionLost` sebebini taşır. Sayaç
`SDKAttemptLimits.shared.connectionDropCount` ile okunur.

---

## 6) Canlılık kuralları

```swift
SDKLivenessRules.default.stepTimeout = 8          // saniye; nil süreyi kapatır (varsayılan 10)
SDKLivenessRules.default.wrongActionCheck = false // varsayılan açık
```

- Süre yalnızca yüz takibi açıkken, hata gösterilmiyorken ve kare yüklenmiyorken işler.
  Kare yüklendikten sonra takip yeniden açılınca süre baştan başlar.
- Yüz kadrajdan çıkınca ekranda "Yüzünüzü çerçeve içine yerleştirin" yazar. Ayrı bir hata
  üretilmez, süre işlemeye devam eder.
- Yanlış hareket: istenen adım sürerken başka bir adımın tetikleme koşulu 0,35 sn boyunca
  sağlanırsa adım başarısız sayılır. Yeni eşik yoktur, her adımın kendi koşulu kullanılır.
  Birlikte oluşan hareketler sayılmaz: göz kırpma hiçbir zaman, kaş kaldırma ile yukarı
  bakma birbirini, başı geriye eğerken yukarı bakma ve kaş kaldırma.
- Hata sonrası aynı adım yeniden istenir. Her başarısız deneme o adımın `livenessStepFailure`
  hakkından düşer; sonraki adım hakkı baştan alır.

Selfie+canlılık modülünde bu kurallar yoktur: o ekranda komut verilen hareket ve kayıt yok.

---

## 7) Çoklu yüz

```swift
SDKFaceConfig.shared.setMultipleFaces(.fail, for: .selfie)
SDKFaceConfig.shared.setMultipleFaces(.warn, for: .livenessDetection)
SDKFaceConfig.shared.setMultipleFaces(.warn, for: .waitScreen)   // görüntülü görüşme
SDKFaceConfig.shared.minFaceAreaRatio = 0.03   // varsayılan 0.02
SDKFaceConfig.shared.failAfter = 2             // varsayılan 1.5 sn
```

| Mod | Davranış |
|---|---|
| `.off` | Denetim yok |
| `.warn` | "Kadrajda birden fazla yüz var" uyarısı; çekim ya da adım yüz tek kalana kadar bekler |
| `.fail` | Yüzler `failAfter` boyunca kadrajda kalırsa hata; `multipleFacesFailure` hakkından düşer |

Varsayılanlar: selfie ve selfie+canlılık `.warn`, canlılık ve görüşme `.off`.

| Modül | Nasıl ölçülür |
|---|---|
| `selfie`, `selfieWithLiveness` (kamera yolu) | Vision. En büyük yüz kullanıcınındır; diğerleri `minFaceAreaRatio`'dan büyükse sayılır |
| `selfieWithLiveness` (ARKit yolu), `livenessDetection` | ARKit iki yüz izler (TrueDepth gerekir) |
| `waitScreen` | Görüşme canlılığı analizcisi iki yüz izler; ölçüm kameraya en yakın yüzden yapılır |

Görüşmede iki mod da görüşmeyi kesmez. `.warn` uyarıyı hemen, `.fail` `failAfter` sonra
gösterir; yüz tek kalınca uyarı kalkar. Görüşmede çoklu yüz açıksa ARKit, sunucu
`liveness_report` göndermese de başlar. TrueDepth'siz cihazda görüşmede denetim çalışmaz.

Kısa video (`videoRecord`) modülünde çoklu yüz denetimi yok.

---

## 8) Kendi ekranınızı yazdıysanız

- Hata: view model'in `errorMessage` alanı eskisi gibi dolar. Ayrıntı `lastError` alanındadır.
  Hatayı kapatırken `dismissError()` çağırın; bekleyen iş (yeniden deneme, atlama, bitirme)
  çalışır. `errorMessage = nil` + `consumePendingAlertAction()` de aynı işi yapar.
- Canlılık: süre ve yanlış hareket denetimi ekranın bildirdiği olaylarla çalışır.
  ARKit oturumunu açınca `trackingDidStart()`, duraklatınca `trackingDidPause()`, yüz
  kadraja girip çıktıkça `faceVisibilityChanged(_:)`, başka bir adımın hareketini
  görünce `reportWrongAction(_:)`, iki yüz görünce `multipleFacesChanged(_:)` çağırın.
  Çağırmazsanız bu denetimler çalışmaz, akış eskisi gibi sürer.
- Selfie+canlılık ARKit yolu: iki yüz izleniyorsa `analyzeFace(_:)` yerine
  `analyzeMultipleFaces()` çağırın.

---

## 9) Davranış değişiklikleri

Ayar vermeyen entegrasyonda şunlar değişir:

1. Karşılaştırma sayaçları modül başına ayrıldı.
2. NFC okuma hatası sınırı dolunca modül atlanmaz, anahtar düzeltme ekranı açılır.
3. Canlılıkta her adımın 10 sn süresi var ve başka bir adımın hareketi hata sayılıyor.
4. Canlılık kaydı hataları sayılıyor; üçüncüde modülün hak bitti kuralı uygulanır.
5. Selfie ve selfie+canlılıkta ikinci yüz kendi metniyle uyarılıyor; arkadaki küçük yüzler
   çekimi engellemiyor. Selfie+canlılığın ARKit yolu ikinci yüzü artık görüyor.
