# async/await API

SDK 3.3.0'dan beri closure'lı API'nin yanında her bekleme için bir `async` karşılık da sunar.
İkisi aynı iç akışı kullanır, aynı oturumu yönetir. Closure API'si yerinde durur. 3.3.0'da
callback'lerin çoğu `@MainActor` tipli oldu, soketin tipi de `SDKWebSocket` oldu; `Starscream`
import eden kodu güncelleyin ([Thread modeli ve Swift 6](concurrency.md)). async'e istediğiniz
ekrandan başlayarak geçebilirsiniz.

← [README'ye dön](../../README.md) · İlgili: [Thread modeli ve Swift 6](concurrency.md) ·
[Oturum Çıkışları](session-exit.md)

---

## Kurallar

- Bütün async metotlar `@MainActor`. Sonuç ana thread'de döner, ekranı doğrudan
  güncelleyebilirsiniz. Arka plandan çağırırsanız Swift çağrıyı kendisi ana thread'e taşır.
- Ağa, donanıma ya da kullanıcıya bağlı her bekleme `throws` ve iptal edilebilir.
- Yerel ve her zaman dönen beklemeler (`nextModule`, `detectHumanFace`, `probeMRZPresence`,
  `notifyLivenessCompleted`) hata fırlatmaz.
- Swift 5 ve Swift 6 projelerde aynı imzalar geçerlidir.

---

## Oturum: kurulum ve sonuç

```swift
@MainActor
final class LoginViewModel: ObservableObject {
    private var setupTask: Task<Void, Never>?

    func connect(coordinator: SDKFlowCoordinator) {
        coordinator.prepareForSetup()               // setupSDK'dan önce
        setupTask?.cancel()
        setupTask = Task {
            do {
                let room = try await IdentifyManager.shared.setupSDK(
                    identId: identId,
                    baseApiUrl: apiUrl,
                    networkOptions: SDKNetworkOptions(timeoutIntervalForRequest: 30, timeoutIntervalForResource: 30, useSslPinning: false),
                    kpsData: nil,
                    signLangSupport: false,
                    nfcMaxErrorCount: 3,
                    turnKey: turnKey
                )
                guard room.result == true else { return showError("Oturum açılamadı") }
                coordinator.start()
            } catch is CancellationError {
                return
            } catch {
                return showError(error.localizedDescription)
            }

            let outcome = await IdentifyManager.shared.outcome()
            print("KYC sonucu: \(outcome.result.rawValue), sebep: \(outcome.reason.rawValue)")
        }
    }
}
```

- Sıra: `prepareForSetup()`, `setupSDK`, `start()`. `prepareForSetup()` atlanırsa modüller
  hiç başlamaz.
- `setupSDK` soket bağlandığında `RoomResponse` döner. Oda açılmazsa ya da soket bağlanmazsa
  `SDKSetupError` fırlatır. Kurulum hatasında oturum yine `.setupFailed` sebebiyle biter,
  `outcome()` bu sonucu da verir.
- async `setupSDK`'da `onFinished` parametresi yoktur. Oturumun sonucunu `outcome()` ya da
  `outcomes` ile alırsınız.
- `outcome()` oturum bitmişse hemen döner, bitmemişse bekler. Birden çok yerden çağrılabilir.
  Hepsi aynı sonucu alır.
- `outcomes` her oturumun sonucunu bir kez veren bir akıştır. Uygulama boyunca açık kalan bir
  dinleyici için kullanılır. Her erişim yeni bir akış açar.

```swift
.task {
    for await outcome in IdentifyManager.shared.outcomes {
        analytics.log(outcome)
    }
}
```

Closure (`onFlowFinished`, `IdentifyFlowResultListener`), `outcome()` ve `outcomes` aynı sonucu
alır ve her biri bir oturumda yalnız bir kez çağrılır.

---

## İptal

Task'ı iptal etmek yalnız beklemeyi bitirir. Oturum, closure yolunda olduğu gibi devam eder:
soket açık kalır, sunucu oturumu sürer. Oturumu kapatmak için ayrıca çağırın:

```swift
setupTask?.cancel()
IdentifyManager.shared.exitSDK()
```

- İptal edilen bekleme `CancellationError` fırlatır.
- Task çağrıdan önce iptal edilmişse `setupSDK` oturumu hiç başlatmaz.
- `outcome()` iptalle bitmez. Oturum bitene kadar bekler.
- SwiftUI'da `.task { }` ekran kapanınca kendini iptal eder. `SpeedCheckBeforeView` ekran
  kapanınca task'ı iptal eder ve ölçümü `cancelConnectionSpeedTest()` ile ayrıca durdurur.

---

## Olaylar

`eventDelegate`'in async karşılığı `events` akışıdır. Her erişim ayrı bir akış açar, bu yüzden
birden çok ekran aynı anda dinleyebilir. Olaylar ana thread'de gelir, akışta en yeni 256 olay
tamponda tutulur.

```swift
@MainActor
final class SDKEventRecorder: ObservableObject {
    @Published private(set) var events: [SDKEvent] = []

    func listen() async {
        for await event in IdentifyManager.shared.events {
            events.append(event)
        }
    }
}

// Görünümde:
.task { await recorder.listen() }
```

Döngü, task iptal edilene kadar sürer. `.task` ile bağlandığında ekran kapanınca biter.

---

## Hata tipleri

| Hata | Ne zaman | İçinde ne var |
|---|---|---|
| `SDKSetupError` | `setupSDK` oda açamadı, soket bağlanmadı ya da oturum kurulum bitmeden kapandı | `message` |
| `SDKWebError` | Yükleme ve sunucu çağrıları | `errorMessages`, closure'ın verdiği nesnenin aynısı |
| `SDKError` | `acceptCall`, `twoFacesCompare`, `reconnectToSocket` | `errorMessages` |
| `SDKPartialError<Value>` | Hata, okunmuş veriyle birlikte geldiğinde (OCR, NFC) | `message`, `partial`, `underlying` |
| `CancellationError` | Bekleyen task iptal edildi | - |

`CancellationError` dışındakilerde `localizedDescription` kullanıcıya gösterilecek mesajı verir.

OCR'da hata, okunabilen alanlarla birlikte gelir:

```swift
do {
    let info = try await IdentifyManager.shared.startFrontIdOcr(frontImg: image)
    show(info)
} catch let error as SDKPartialError<FrontIdInfo> {
    // TCKN okunamadı ama ad ve soyad okunmuş olabilir.
    show(error.partial, warning: error.message)
}
```

NFC'de `partial` sunucu yanıtıdır (`NewBoolResponse`), `underlying` ise okuyucunun hatasıdır.
`message` sunucunun mesajı, yoksa okuyucunun mesajıdır.

---

## Bütün async API'ler

| async API | Dönüş | Fırlatır |
|---|---|---|
| `setupSDK(...)` | `RoomResponse` | `SDKSetupError` |
| `outcome()` | `SDKFlowOutcome` | fırlatmaz |
| `outcomes`, `events` | `AsyncStream` | - |
| `quitSDK()` | ThankYou ekranı (`UIViewController`). `showThankYouPage: false` iken de döner, o zaman göstermeyin | fırlatmaz |
| `killSDKByUser()`, `terminateCallByUser()` | `Bool` | `CancellationError` |
| `nextModule()` | `UIViewController` | fırlatmaz |
| `reconnectToSocket(statusCallback:)` | `Bool` (soket bağlandı mı) | `SDKError` (deneme zaten sürüyor ya da oturum kapalı), `CancellationError` |
| `selectDocType(_:)` | yok | `SDKWebError` |
| `acceptCall()` | `Bool` (SDP gönderildi mi) | `SDKError` |
| `smsVerification(tan:)` | `Bool` | `CancellationError` |
| `startNFC()` | `(card, status, response)` | `SDKPartialError<NewBoolResponse>` |
| `updateReadNFCKeys(serialNo:birthDate:expireDate:)` | yok | `SDKWebError` |
| `startFrontIdOcr(frontImg:)`, `startPassportMrzKey(frontImg:cominData:)` | `FrontIdInfo` | `SDKPartialError<FrontIdInfo>` |
| `startBackIdOcr(frontImg:)` | `BackIdInfo` | `SDKPartialError<BackIdInfo>` |
| `twoFacesCompare()` | `(distance, samePerson, images)` | `SDKError` (belge fotoğrafı yok), `CancellationError` |
| `detectHumanFace(comingPhoto:)`, `probeMRZPresence(in:roi:)` | `Bool` | fırlatmaz |
| `uploadIdPhoto` | `NewBoolResponse` | `CancellationError` |
| `upload5SecVideo`, `uploadLivenessVideo` | `NewBoolResponse` | `SDKWebError` |
| `uploadAddressInfo`, `uploadAddressInfoWithPdf` | yok | `SDKWebError` |
| `transcribeSpeech(mediaData:expectedText:threshold:)` | `SpeechTranscribeResponse` | `SDKWebError` |
| `notifyLivenessCompleted(timeout:)` | yok | fırlatmaz, kendi süre sınırı var |
| `nextLivenessTest()` | `LivenessTestStep?` | eşzamanlı, bekleme yok. Bilinmeyen adım atlanır |
| `startSpeedTest(repeatCount:)` | `AsyncStream<(status, kbPerSec)>` | Ölçümler sırayla yapılır. Akış `repeatCount` ölçümden sonra biter, en az bir ölçüm yapılır |
| `startConnectionSpeedTest(identId:baseApiUrl:)` | `SDKSpeedTestResult` | `CancellationError`. İptal ölçümü durdurmaz, `cancelConnectionSpeedTest()` durdurur |
| `verifyKeysOnServer()` | `SDKKeyReport` | `CancellationError` |

Yüklemelerde `NewBoolResponse.result` `false` gelebilir. Sunucunun reddi hata sayılmaz, sonucu
siz okursunuz.

### Oturum kapandıktan sonra

`exitSDK()` ya da `quitSDK()` oturumu kapatınca uçuştaki istekler iptal edilir. Kapanıştan
sonra gelen yanıtlar callback'e iletilmez, iptal hatası da gelmez. O sırada bekleyen yükleme ve
sunucu çağrıları (`uploadIdPhoto`, `smsVerification` ve diğerleri) hiç dönmez. Bu çağrıları
ekranın ömrüne bağlı bir task içinde yapın, oturumu kapatmadan önce task'ı iptal edin. Bekleyen
`setupSDK` ise döner ve "Kurulum tamamlanmadan oturum kapatıldı" mesajlı `SDKSetupError` fırlatır.

`killSDKByUser()` soket kopukken de döner: panele haber verilemez, oturum cihazda kapanır ve
sonuç `true` olur.

---

## Closure API'den geçiş

| Closure | async |
|---|---|
| `setupSDK(..., onFinished:callback:)` | `try await setupSDK(...)` + `await outcome()` |
| `onFlowFinished = { }` | `for await o in outcomes` |
| `eventDelegate = self` | `for await e in events` |
| `quitSDK { vc in }` | `let vc = await quitSDK()` |
| `getNextModule { vc in }` | `let vc = await nextModule()` |
| `getNextLivenessTest { step, _ in }` | `let step = nextLivenessTest()` |
| `startSpeedTest { status, kb in }` | `for await (status, kb) in startSpeedTest()` |
| `startConnectionSpeedTest { result in }` | `try await startConnectionSpeedTest()` |

Closure tarafında `DispatchQueue.main.async { }` ya da `Task { @MainActor in }` ile yaptığınız
sarmaları async tarafında silebilirsiniz. Sonuç zaten ana thread'de döner.
