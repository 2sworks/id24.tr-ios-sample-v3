# Event Sistemi — Akışı Veriyle İzlemek

Kullanıcı hangi adımda, selfie kaç kez başarısız oldu, görüşme kuruldu mu? Bunları SDK'nın olay
(event) akışından öğrenirsiniz. Host uygulama bu akışa abone olup olayları kendi analitik
altyapısına (Firebase, Adjust ya da kendi paneliniz) gönderebilir.

← [README'ye dön](../../README.md) · İlgili: [Loglama](logging.md)

---

## İki API, Tek Akış

İki dinleyici var ve ikisi de çalışıyor. Yeni projelerde `SDKEventListener`'ı öneriyoruz:

| API | Model | Durum |
|---|---|---|
| `SDKEventListener` (yeni) | Ayrıntılı `SDKEvent` nesnesi | ✅ Önerilen |
| `IdentifyTrackingListener` (eski) | `TrackingEventType` enum'ı | Geriye uyum için duruyor |

Eski `TrackingEventType` olayları SDK içinde yeni `SDKEvent` modeline çevrilir. HTTP izleme olayları
(`HTTP_REQUEST_TRACKING_EVENT`, `HTTP_RESPONSE_TRACKING_EVENT`) yalnız `trackingDelegate` ile gelir.
Diğer eski olayların hepsi `SDKEvent` olarak da gelir.

---

## Hızlı Başlangıç

```swift
final class MyAnalytics: SDKEventListener {
    func onSDKEvent(_ event: SDKEvent) {
        // Örnek: Firebase'e ilet. Firebase olay adında yalnız harf, rakam ve alt çizgi
        // kabul eder, en çok 40 karakter.
        let ad = String(event.name.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "_" }.prefix(40))
        Analytics.logEvent(ad, parameters: event.toDictionary())
    }
}

let analytics = MyAnalytics()
IdentifyManager.shared.eventDelegate = analytics   // weak tutulur — referansı siz saklayın
```

> `eventDelegate` weak tutulur. Dinleyiciyi kendi tarafınızda güçlü bir referansla saklayın;
> saklamazsanız nesne serbest kalır ve hiçbir olay gelmez, bir hata da görmezsiniz.

---

## SDKEvent — Olayın Anatomisi

| Alan          | Tip                | Anlamı                                                                                           |
| ------------- | ------------------ | ------------------------------------------------------------------------------------------------ |
| `name`        | `String`           | Olay adı: `module.<modül>.<durum>`, `session.<durum>`, `call.<durum>` gibi (ör. `module.Selfie.completed`). Modül adı `SdkModules` ham değeriyle yazılır, boşluk ve & içerebilir: `module.Mrz & Nfc Screen.completed` |
| `category`    | `SDKEventCategory` | `session` · `module` · `call` · `network` · `error` · `navigation`                               |
| `status`      | `SDKEventStatus`   | `info` · `presented` · `completed` · `failed` · `skipped` · `success` · `abandoned` · `notFound` |
| `module`      | `String?`          | Olayın ait olduğu modül. Modül olaylarında ham ad (`Mrz & Nfc Screen`), `error.shown`'da kısa ad (`nfc`) |
| `screen`      | `String?`          | Olayın ait olduğu ekran                                                                          |
| `sessionId`   | `String`           | Oturum kimliği; bir oturumun bütün olaylarını gruplamak için                                     |
| `timestampMs` | `Int64`            | Olay zamanı (ms)                                                                                 |
| `message`     | `String?`          | Açıklama                                                                                         |
| `metadata`    | `[String: String]` | Ek bilgi                                                                                         |

### Tipik Olay Örüntüsü — Modül Yaşam Döngüsü

Her modül dört temel durumdan geçer. Funnel analizini bu durumlarla kurabilirsiniz:

```
presented ──► completed        (Happy path)
          ├─► failed           (deneme başarısız — tekrar deneyebilir)
          └─► skipped          (hak tükendi / modül atlandı)
```

NFC'nin bir durumu daha var: cihaz NFC okuyamıyorsa `notFound` gelir ve modül `skippedModules`'a
girer. NFC anahtar düzeltme hakkı bitince `skipped` olayı gelmez; NFC için `.fail` verilmediyse
modül yine `skippedModules`'a girer. Oturum düzeyinde `success` (akış bitti) ve `abandoned`
(yarıda bırakıldı) gelir.

### Bağlantı & Yaşam Döngüsü Olayları

Soket ve TURN kapanmaları ile uygulamanın ön plana ya da arka plana geçmesi de olay üretir:

| Olay | Kategori | Ne zaman | Önemli metadata |
|---|---|---|---|
| `socket.closed` | `network` | Soket her kapandığında (bilerek kapatıldığında da, koptuğunda da) | `code` (4100+), `case`, `category`, `deliberate`, `reason` |
| `turn.dropped` | `call` | Oturum sürerken ICE bağlantısı kapandığında (4142) | aynı alanlar |
| `sdk.detected` | 4140, 4141 ve 4142'de `call`, diğerlerinde `network` | Soket kapanmadan SDK'nın kendi fark ettiği sonlar: ICE toparlanmadı (4140), ICE kurulamadı (4141), sinyalsiz süren görüşmede ICE kapandı (4142), çağrı yanıtlanmadı (4108), WS anahtarı reddedildi (4119), bağlantı verilen sürede kurulamadı (4133). `status` her zaman `failed` | `code`, `case`, `category`, `reason` (`deliberate` yok) |
| `session.background` | `session` | Uygulama arka plana geçtiğinde | `timeoutSeconds`, `socketConnected` |
| `session.foreground` | `session` | Uygulama ön plana döndüğünde | `elapsedSeconds`, `socketConnected` |
| `app.background` | `navigation` | DefaultUI'da arka plana geçiş, modül bilgisiyle | `state` |

### Başlangıç, Görüşme ve Hata Olayları

| Olay | Kategori | Ne zaman | Önemli alanlar |
|---|---|---|---|
| `session.started` | `session` | `setupSDK` çağrıldığında, oda yanıtı beklenmeden | yok |
| `call.connected` | `call` | Çağrı çalmaya başladığında. Kullanıcı yanıtlamasa da gelir | yok |
| `call.ended` | `call` | Sunucudan `endCall` ya da `terminateCall` geldiğinde | `terminateCall`'da `message` sebebi taşır, `metadata`: `reason`, `statusSummary` |
| `call.liveness.faceFound` | `call` | Görüşme canlılığı yüzü gördüğünde | yok |
| `call.liveness.faceLost` | `call` | Yüz birkaç kare üst üste görünmeyince | yok |
| `call.liveness.verified` | `call` | Gereken hareketler yapıldı ve yüz yeterli süre göründü. `status` `completed` | `actions` |
| `error.shown` | `error` | Bir modül hata bildirdiğinde, `SDKErrorConfig` gösterimi kapalı olsa da. `status` `failed` | `module` kısa adla (`nfc`), `message`, `metadata`: `code`, `source`, varsa `captureMode` ve `attemptsLeft` |

### Oturum Sonucu Olayları (3.1.0)

Oturum nasıl biterse bitsin iki olay tam bir kez gönderilir: sonucu taşıyan `session.finished` ve
sonuca göre `session.completed`, `session.failed` ya da `session.abandoned`. Aynı sonucu
`setupSDK(onFinished:)`, `IdentifyManager.shared.onFlowFinished` ve `flowResultDelegate`
üzerinden tipli olarak (`SDKFlowOutcome`) da alabilirsiniz.
Bkz. [FULL-INTERGATION → Akış Sonucu](../../FULL-INTERGATION.md#akış-sonucu--onfinished-310);
bütün çıkış yolları ve yönlendirme için [Oturum Çıkışları](session-exit.md).

| Olay | `status` | Ne zaman |
|---|---|---|
| `session.finished` | sonuca göre | Her bitişte |
| `session.completed` | `success` | `result == approved` |
| `session.failed` | `failed` | `rejected` · `neutral` · `notCompleted` · `error` |
| `session.abandoned` | `abandoned` | `cancelled` (kullanıcı ya da host çıktı, uygulama kapatıldı) |

| Metadata | Anlamı |
|---|---|
| `result` | `approved` · `rejected` · `neutral` · `notCompleted` · `cancelled` · `error` |
| `endReason` | `agentDecision` · `allModulesCompleted` · `userEndedCall` · `moduleFailed` · `userExited` · `hostQuit` · `hostExit` · `hostForceQuit` · `appTerminated` · `roomOccupied` · `connectionLost` · `setupFailed` |
| `reason` | Panelin gönderdiği `terminateReason`; yoksa `endReason` (3.0.0 uyumu için) |
| `terminateReason`, `statusSummary`, `statusId` | Oturumu panel kapattıysa panelin gönderdiği değerler |
| `lastScreen`, `lastModule`, `stepIndex`, `totalSteps` | Oturumun bittiği yer |
| `skippedModules` | Doğrulanmadan geçilen modüller, virgülle ayrılmış (hiç yoksa anahtar gelmez) |
| `isFullyVerified` | `"true"` ya da `"false"`: oturum onaylandı, atlanan modül yok ve hiçbir çip kontrolü başarısız olmadı |
| `closeCode`, `errorMessage` | Son kapanış kodu ve setup hatası |
| `nfcCertificateChain`, `nfcDocumentSignature`, `nfcDataIntegrity`, `nfcChipAuthentication`, `nfcActiveAuthentication` | Son NFC okumasının çip kontrolleri: `passed` · `failed` · `notPerformed` (çip okunmadıysa anahtar gelmez). NFC modülünün `nfcModuleCompleted` ve `nfcModuleFailed` olaylarında da gelir |
| `nfcFailureReasons` | Kontrollerin kalma nedenleri, virgülle ayrılmış (neden yoksa anahtar gelmez). Bkz. [Çip doğrulama ayrıntısı](session-exit.md#çip-doğrulama-ayrıntısı) |
| `verificationWarnings` | Yapılmayan ama oturumu bozmayan kontroller, virgülle ayrılmış (yoksa anahtar gelmez). Şu an tek değer `nfcCertificateChainNotChecked`: çip okundu, sertifika zinciri kontrol edilmedi (`nfcCertificateChain` `notPerformed`) |

> 3.0.0'da `session.completed` ve `session.failed` her `terminateCall`'da gönderiliyordu. Başarı
> da statünün içinde `success` ya da `approve` aranarak belirleniyordu. Panel `positive`
> gönderdiği için onaylanan oturumlar da `failed` görünüyordu. Artık bu olaylar yalnızca gerçek bir
> karar ya da başka bir bitiş olduğunda gönderiliyor; karar içermeyen sonlandırmalar olay üretmiyor.

`status` alanı bilerek yapılan kapanışlarda `info`, kopmalarda `failed` olur. Kodların tam listesi:
[WebSocket rehberi → Birleşik Kapanma Kodları](websocket.md#birleşik-kapanma-kodları--sdksocketclosecode-4100).

---

## Eski API — IdentifyTrackingListener

Bu API ile entegrasyonunuz varsa değiştirmeniz gerekmiyor:

```swift
IdentifyManager.shared.trackingDelegate = self   // IdentifyTrackingListener

func eventReceived(event: TrackingEvent) { ... }
```

`TrackingEventType` her modül için `...ModulePresented / Failed / Completed / Skipped` case'lerini
ve HTTP izleme olaylarını (`HTTP_REQUEST_TRACKING_EVENT`, `HTTP_RESPONSE_TRACKING_EVENT`) içerir.
Yeni bir projede bunun yerine `SDKEventListener` kullanın.

---

## Canlı Görmek İçin: Sample App Showcase

Sample App'teki Event Journey ekranı (`Showcase/EventJourney/`) akış boyunca üretilen olayları
zaman sırasıyla listeler. Olay modelini öğrenmenin en kısa yolu, bir oturumu baştan sona
tamamlayıp bu ekrana bakmaktır. `SDKEventRecorder` örnek bir `SDKEventListener`; kopyalayıp kendi
analitik bağlantınıza uyarlayabilirsiniz.

---

## Event mi Log mu?

- Ürün ya da analitik sorusu ("kaç kullanıcı NFC'de takıldı?") için event'lere bakın.
- Teknik sorun ("NFC neden takıldı?") için [Log](logging.md)'lara bakın (`nfc` kategorisi).
