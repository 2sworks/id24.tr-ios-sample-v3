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

### Fonksiyon callback'leri: thread garantisi yok

Aşağıdaki fonksiyonların `callBack` / `completion` closure'ı düz tiptedir. Ana thread garantisi
yoktur. Callback çağrıyı yaptığınız thread'de, ağ kuyruğunda ya da görüntü işleme kuyruğunda
gelebilir. Ekrana dokunmadan önce ana thread'e geçin, ya da aynı fonksiyonun async karşılığını
kullanın. async karşılıkların hepsi ana thread'de döner.

| Fonksiyon | Callback'in geldiği yer |
|---|---|
| `startNFC`, `updateReadNFCKeys`, `notifyLivenessCompleted` | Ana thread (SDK içeride taşıyor) |
| `probeMRZPresence` | Arka plan kuyruğu (`userInitiated`) |
| `startFrontIdOcr`, `startBackIdOcr`, `startPassportMrzKey`, `detectHumanFace`, `twoFacesCompare` | Görüntü işleme kuyruğu ya da çağıran thread |
| `uploadIdPhoto`, `upload5SecVideo`, `uploadLivenessVideo`, `uploadAddressInfo`, `uploadAddressInfoWithPdf`, `transcribeSpeech`, `smsVerification` | Ağ kuyruğu ya da ana thread, yola göre değişir |
| `startSpeedTest`, `startConnectionSpeedTest` | Ağ kuyruğu |
| `acceptCall`, `killSDKByUser`, `terminateCallByUser`, `getNextLivenessTest` | Çağıran thread ya da soket kuyruğu |

Örnek:

```swift
// Closure: ana thread'e kendiniz geçersiniz.
IdentifyManager.shared.uploadIdPhoto(idPhoto: image) { response in
    DispatchQueue.main.async { self.showResult(response) }
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
3. Thread garantisi olmayan fonksiyon callback'lerini async karşılıklarıyla değiştirin. Swift 6
   derleyicisi bu closure'larda ekrana dokunmanıza izin vermez, async biçimde bu sorun yoktur.
4. `onFlowFinished` gibi `@MainActor` closure'larda ekranı doğrudan güncelleyebilirsiniz.

### Sırada ne var

İki adım daha var. İkisi de 3.x içinde, public imzaları bozmadan yapılır. Sizin tarafınızda
bir değişiklik gerektirmez.

| Adım | İçerik |
|---|---|
| İç temizlik | SDK'nın iç kodu strict concurrency denetiminde uyarısız hale gelir |
| SDK Swift 6 modu | SDK'nın kendisi `SWIFT_VERSION = 6` ile derlenir. Yeni uyarıyı yakalayan derleme kapısı eklenir |

Swift 5 desteği, müşterilerin hepsi Swift 6'ya geçtikten sonra kaldırılacak. Öncesinde ayrıca
duyurulur.
