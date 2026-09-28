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

Eski `TrackingEventType` olayları SDK içinde yeni `SDKEvent` modeline çevrilir. Yeni API'ye abone
olduğunuzda eski API'nin gönderdiği olayların hepsini de alırsınız.

---

## Hızlı Başlangıç

```swift
final class MyAnalytics: SDKEventListener {
    func onSDKEvent(_ event: SDKEvent) {
        // Örnek: Firebase'e ilet
        Analytics.logEvent(event.name, parameters: event.toDictionary())
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
| `name`        | `String`           | Olay adı: `module.<modül>.<durum>` ya da `session.<durum>` (ör. `module.Selfie.completed`)       |
| `category`    | `SDKEventCategory` | `session` · `module` · `call` · `network` · `error` · `navigation`                               |
| `status`      | `SDKEventStatus`   | `info` · `presented` · `completed` · `failed` · `skipped` · `success` · `abandoned` · `notFound` |
| `module`      | `String?`          | Olayın ait olduğu modül                                                                          |
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

NFC'nin bir durumu daha var: çipsiz belgeler için `notFound`. Oturum düzeyinde `success` (akış
bitti) ve `abandoned` (yarıda bırakıldı) gelir.

### Bağlantı & Yaşam Döngüsü Olayları

Soket ve TURN kapanmaları ile uygulamanın ön plana ya da arka plana geçmesi de olay üretir:

| Olay | Kategori | Ne zaman | Önemli metadata |
|---|---|---|---|
| `socket.closed` | `network` | Soket her kapandığında (bilerek kapatıldığında da, koptuğunda da) | `code` (4100+), `case`, `category`, `deliberate`, `reason` |
| `turn.dropped` | `call` | TURN/ICE bağlantısı düştüğünde (4140–4142) | aynı alanlar |
| `session.background` | `session` | Uygulama arka plana geçtiğinde | `timeoutSeconds`, `socketConnected` |
| `session.foreground` | `session` | Uygulama ön plana döndüğünde | `elapsedSeconds`, `socketConnected` |
| `app.background` | `navigation` | DefaultUI'da arka plana geçiş, modül bilgisiyle | `state` |

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
| `closeCode`, `errorMessage` | Son kapanış kodu ve setup hatası |

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
