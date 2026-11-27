# Thread modeli ve Swift 6

SDK'nın host uygulamaya hangi thread'de seslendiğini ve Swift 6'ya geçişte sizi neyin
beklediğini anlatır. SDK 3.x, Swift 5 ve Swift 6 projelerde aynı imzalarla derlenir. Swift 6'ya
geçerken SDK tarafında yapmanız gereken bir şey yok.

← [README'ye dön](../../README.md) · İlgili: [async/await API](async-await.md) ·
[Event Sistemi](events.md)

---

## Hangi bildirim hangi thread'de gelir

### Delegate'ler: hepsi ana thread'de

Delegate protokollerinin bütün metotları `@MainActor` işaretlidir. SDK bunları içerideki hangi
kuyrukta oluşursa oluşsun ana thread'e taşıyarak çağırır. Ekranı doğrudan güncelleyebilirsiniz,
`DispatchQueue.main.async` gerekmez.

| Protokol | Atandığı yer | Ne zaman, kaç kez |
|---|---|---|
| `SDKSocketListener` | `IdentifyManager.shared.socketMessageListener` | Her soket aksiyonunda bir kez. Bağlantı koptuğunda yerel `connectionErr` |
| `IdentifyListenerDelegate` | `IdentifyManager.shared.delegate` | Eski arayüz. `SDKSocketListener` ile aynı aksiyonlar. `incomingCall`, `openNFC`, `skipNFC`, `approvedSms`, `updateQueue`, `missedCall` artık çağrılmaz |
| `IdentifyManagerListener` | `IdentifyManager.shared.appListenerDelegate` | `sdkResponse` çağrılmaz |
| `SDKEventListener` | `IdentifyManager.shared.eventDelegate` | Her olayda bir kez |
| `IdentifyTrackingListener` | `IdentifyManager.shared.trackingDelegate` | Eski olay arayüzü, her olayda bir kez |
| `IdentifyFlowResultListener` | `IdentifyManager.shared.flowResultDelegate` | `identifyFlowDidFinish` oturum başına tam bir kez |
| `SDKCallLivenessListener` | `SDKCallLiveness.listener` | `onLivenessVerified` bir kez, `onContinuousTrackingProgress` saniyede bir |
| `PopUpProtocol`, `LoadingViewDelegate` | DefaultUI ekranları | Ekran olayıyla |

### Closure özellikleri: ana thread'de

Bu closure'ların tipi `@MainActor`. SDK onları ana thread'de çağırır.

| Closure | Ne zaman |
|---|---|
| `onFlowFinished` | Oturum bittiğinde, bir kez |
| `onTorchChange` | Fener açılıp kapandığında |
| `onCameraChange` | Ön ve arka kamera değiştiğinde |
| `onAudioRouteChange` | Ses çıkışı değiştiğinde (hoparlör, kulaklık, Bluetooth) |
| `setupSDK(onFinished:callback:)` | `callback` soket bağlanınca ya da kurulum hatasında, `onFinished` oturum sonunda |
| `quitSDK(callback:)`, `getNextModule(callback:)` | Ekran hazır olunca |
| `SDKErrorConfig.onError` | DefaultUI bir hata gösterdiğinde |
| `SDKViewRegistry` kurucuları, imza ve işaret dili closure'ları | Ekran kurulurken |

### Fonksiyon callback'leri: çoğu ana thread'de

SDK 3.3.0'dan beri fonksiyon callback'lerinin çoğu `@MainActor` tiplidir: ana thread'de gelir,
ekranı doğrudan güncelleyebilirsiniz. async karşılıkların hepsi de ana thread'de döner.

| Fonksiyon | Callback'in geldiği yer |
|---|---|
| `startNFC`, `updateReadNFCKeys`, `notifyLivenessCompleted`, `probeMRZPresence`, `startFrontIdOcr`, `startBackIdOcr`, `startPassportMrzKey`, `uploadIdPhoto`, `upload5SecVideo`, `uploadLivenessVideo`, `uploadAddressInfo`, `uploadAddressInfoWithPdf`, `transcribeSpeech`, `smsVerification`, `startConnectionSpeedTest`, `acceptCall` | Ana thread. Callback tipi `@MainActor` |
| `startSpeedTest` | Ana thread, her ölçümde bir kez. Callback tipi düz, sonucu SDK ana thread'e taşır |
| `detectHumanFace`, `twoFacesCompare`, `getNextLivenessTest`, `killSDKByUser`, `terminateCallByUser` | Çağrıyı yaptığınız thread, fonksiyon dönmeden. Callback tipi düz |

Örnek:

```swift
// Callback `@MainActor`: ekranı doğrudan güncelleyin.
IdentifyManager.shared.uploadIdPhoto(idPhoto: image) { response in
    self.showResult(response)
}

// async: sonuç ana thread'de döner.
let response = try await IdentifyManager.shared.uploadIdPhoto(idPhoto: image)
showResult(response)
```

---

## Swift 6 geçiş planı

### Bugün (3.x)

- Swift 5 projeler değişiklik yapmadan derlenmeye devam eder.
- Swift 6 projeler (`SWIFT_VERSION = 6`, `SWIFT_STRICT_CONCURRENCY = complete`) SDK'yı
  hatasız derler. `@preconcurrency import IdentifySDK` gerekmez.
- SDK'nın kendisi de 3.3.0'dan beri Swift 6 dil moduyla (`SWIFT_VERSION = 6`) derlenir. Bu
  modda strict concurrency denetimi tam açıktır: SDK kodundaki bir eşzamanlılık hatası
  derlemeyi durdurur.
- Public modeller (`RoomResponse`, `FrontIdInfo`, `NewBoolResponse`, `SDKEvent`,
  `SDKFlowOutcome` ve diğerleri) `Sendable`. Task'lar ve actor'ler arasında taşınabilir.
- `IdentifyManager.shared` her thread'den çağrılabilir. Sınıfın tamamı `@MainActor` değildir,
  bu yüzden arka plan kodunuzdaki mevcut çağrılar Swift 6'da da derlenir. Ana thread'e bağlı
  olan yalnız async metotlar ve yukarıdaki `@MainActor` closure'lardır.

SDK bu iki modu kendi test hedefleriyle denetler. Swift 5 modundaki örnek host mevcut
entegrasyonları temsil eder. Swift 6 ve `complete` modundaki örnek host, public API'yi ana
thread'den ve ayrı bir actor'den kullanır. SDK testleri ikisinin de hatasız
derlenmesini şart koşar.

### Swift 6'ya geçerken sizin tarafınızda

1. Delegate'lerinizi uygulayan sınıfı `@MainActor` yapın ya da metotları `@MainActor` işaretleyin.
   Protokol metotları zaten `@MainActor` olduğu için Swift bunu ister.
2. Delegate metotlarındaki `DispatchQueue.main.async { }` ve `Task { @MainActor in }` sarmalarını
   silin. Bildirim zaten ana thread'de gelir.
3. `@MainActor` tipli fonksiyon callback'lerindeki `DispatchQueue.main.async { }` sarmalarını
   silin. Callback zaten ana thread'de gelir.
4. `onFlowFinished` gibi `@MainActor` closure'larda ekranı doğrudan güncelleyebilirsiniz.

### Sırada ne var

Swift 5 desteği, müşterilerin hepsi Swift 6'ya geçtikten sonra kaldırılacak. Öncesinde ayrıca
duyurulur.
