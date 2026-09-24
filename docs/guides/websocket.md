# WebSocket — Canlı Sinyal Kanalı

SDK, oturum boyunca backend ile açık bir WebSocket bağlantısı tutar. Gelen çağrı, SMS onayı,
agent komutları, adım bildirimleri — hepsi bu kanaldan akar. Bu rehber bağlantının nasıl
kurulduğunu, token güvenliğini (`socket_auth`), aksiyon kataloğunu ve **bağlantı koptuğunda
ne olduğunu** anlatır.

← [README'ye dön](../../README.md) · İlgili: [Sunucu & API](server-api.md) · [TURN & WebRTC](turn-webrtc.md)

---

## Bağlantının Kurulması

Soket adresi (`ws_url`) sizin verdiğiniz bir şey değildir; `connectToRoom` cevabından gelir.
İstemci [Starscream](https://github.com/daltoniam/Starscream) WebSocket'idir.

```
RoomResponse.ws_url ──► WebSocket(url:)
                          │  socket_auth == "1" ise: ws_url + "?token=<HMAC token>"
                          ▼
                        connect() ──► sendFirstSubscribe()   (odaya kayıt)
```

Bağlantı denemesi ~30 saniye içinde başarısız olursa `setupSDK` callback'ine hata döner.

### `socket_auth` — Token'lı Bağlantı

Backend `socket_auth = "1"` gönderiyorsa, SDK soket URL'ine kısa ömürlü bir imzalı token ekler.
Bunun çalışması için `setupSDK`'ya **`wsSecretKey`** vermeniz zorunludur.

Token şu şekilde üretilir (bilgi amaçlı — hepsi SDK içinde otomatiktir):

```
payload   = "<form_uid>:<şimdi + 60sn unix zaman>:<4 bayt rastgele hex>"
imza      = HMAC-SHA256(payload, wsSecretKey)     → hex
token     = base64("payload.imza")
soket URL = ws_url + "?token=" + token
```

Token 60 saniye geçerlidir; **her reconnect'te otomatik olarak yenisi üretilir.**
`wsSecretKey` yanlışsa soket hiç bağlanmaz — Login aşamasında "WS key hatası" görürsünüz.

---

## Aksiyon Kataloğu — `SDKCallActions`

Soketten gelen mesajlar `SDKCallActions` enum'ına çevrilir ve dinleyicilere iletilir.
DefaultUI kullanıyorsanız bunların hepsi zaten hazır ekranlarca işlenir; kendi ekranınızı
yazıyorsanız ilgilendiğiniz aksiyonları dinlersiniz.

| Aksiyon | Anlamı |
|---|---|
| `incomingCall` | Agent arıyor — çağrı ekranı açılmalı |
| `endCall` | Görüşme kapandı — `terminateCall` gelmediyse müşteri kapatmıştır ([Görüşmenin Kapanışı](#görüşmenin-kapanışı--terminatecall)) |
| `missedCall` | Çağrı cevapsız kaldı — oturumu bitirmez, müşteri bekleme odasında kalır |
| `terminateCall(reason, statusSummary)` | Panel görüşmeyi sonlandırdı — sebep ve statüye göre oturum biter ya da yeniden bağlanmaya düşer ([karar tablosu](#görüşmenin-kapanışı--terminatecall)) |
| `comingSms` / `approveSms(Bool)` | SMS doğrulama akışı |
| `openWarningCircle` / `closeWarningCircle` | Agent, müşteri ekranında uyarı çemberi açtı/kapadı |
| `openCardCircle` / `closeCardCircle` | Kimlik gösterme çemberi açıldı/kapandı |
| `photoTaken(String)` | Agent görüşme sırasında fotoğraf aldı |
| `updateQueue(sıra, toplam)` | Bekleme odasında sıra bilgisi güncellendi |
| `subscribed` | Odaya kayıt tamam |
| `subrejectedDismiss(String)` | Kayıt reddedildi (ör. süresi geçmiş ident) |
| `openNfcRemote(...)` | Agent, uzaktan NFC adımı başlattı |
| `editNfcProcess` | Agent, NFC verisinde düzeltme istedi |
| `startTransfer` | Görüşme başka agent'a aktarılıyor |
| `networkQuality(String)` | Bağlantı kalite bildirimi |
| `disableEndCallButton` | Müşterinin "görüşmeyi bitir" butonu kilitlendi |
| `imOffline` | Karşı taraf çevrimdışı |
| `connectionErr` | **Bağlantı koptu** (aşağıya bakın) |
| `wrongSocketActionErr(String)` | Tanınmayan soket mesajı |

### Dinleme

```swift
// Soket aksiyonlarını dinlemek (host tarafı)
IdentifyManager.shared.socketMessageListener = self   // SDKSocketListener

extension MyController: SDKSocketListener {
    func listenSocketMessage(message: SDKCallActions) {
        if case .connectionErr = message { /* ... */ }
    }
}
```

> DefaultUI'da `SDKFlowCoordinator` bu dinleyiciyi zaten yönetir; CallScreen gibi
> dinleyiciyi devralan ekranlar ayrılırken `coordinator.restoreSocketListener()` çağırır.

---

## Modül → Sunucu Sinyalleri

Soket yalnızca sunucudan komut almak için değildir; SDK her modül geçişinde durum bildirir:

| Sinyal | Ne zaman gider |
|---|---|
| `sendStep()` | Modül adımı tamamlandı / konum değişti |
| `sendPreparetatus(isCompleted:)` | Hazırlık modülü sonucu |
| `sendSpeechStatus(isCompleted:)` | Konuşma modülü sonucu |
| `modulePresented` (adım bildirimi) | `advanceToNextModule()` içinde |

`stepChanged` gövdesindeki `steps.sign_language` alanı işaret dili tercihini taşır.
`signLangSupport: true` iken bekleme ekranındaki `stepChanged`, kullanıcı işaret dili
kapısını geçene kadar bekletilir — ayrıntı: [SignLang](../../IdentifySample/Modules/SignLang/SignLang.md#sunucuya-giden-veri).

**Bu yüzden custom ekranlar SDK VM metotlarını atlayamaz** — kendi navigasyonunuzu kurarsanız
bu sinyaller gitmez ve agent panelinde akış "takılı" görünür.
Ayrıntı: [Özelleştirme → bypass yok kuralı](customization.md#bypass-yok-kuralı).

---

## Bağlantı Kopması ve Toparlanma

SDK, kopmayı **iki bağımsız kaynaktan** tespit eder:

1. **Reachability izleyicisi** — oturum başlarken açılır; internet `.notReachable`
   olursa (ve KYC bitmemişse) devreye girer.
2. **Soket kopması** — Starscream disconnect bildirimi.

İki kaynak da aynı kapıya çıkar: `.connectionErr` **yalnızca bir kez** yayınlanır
(tekrarlar bastırılır), başarılı yeniden bağlantıda bayrak sıfırlanır.

```
internet gitti ──┐
                 ├──► emitConnectionLost() ──► .connectionErr ──► LostConnection overlay
soket koptu   ───┘         (tek sefer)
                                                    │ kullanıcı "Tekrar Bağlan"
                                                    ▼
                                          reconnectToSocket()
                                            ├─ socket_auth ise yeni token üret
                                            ├─ sendImOnline + sendReconnectSubscribe
                                            ├─ (görüşme ekranındaysa) WebRTC yeniden kur + sendStep
                                            └─ kaldığı modülden devam
```

`reconnectToSocket` eşzamanlı çift çağrıya karşı korumalıdır (`isReconnecting` guard'ı).
Kullanıcı deneyimi tarafı için: [LostConnection rehberi](../../IdentifySample/Modules/LostConnection/LostConnection.md).

---

## Görüşmenin Kapanışı — `terminateCall`

Panel görüşmeyi **yalnızca `terminateCall`** ile bitirir. Temsilci kapatmaya hazırlanırken önce
`disableEndCallButton` gönderir (müşterinin "Görüşmeyi bitir" butonu kilitlenir), ardından her
durumda `terminateCall` gelir. `terminateCall` gelmeden kapanan görüşmeyi müşteri kapatmıştır.

Mesaj iki bilgi taşır:

| Alan | Anlamı |
|---|---|
| `terminateReason` | Görüşmenin **nasıl** kapandığı (ör. `NORMAL_CLOSE_BY_AGENT`) |
| `statusSummary` | Temsilcinin panelde seçtiği **karar**: `id`, `type` (`positive` · `negative` · `neutral`), `status`, `name_tr` / `name_en` / `name_de` |

`type` kararın yönünü, `id` ise **hangi** statünün seçildiğini söyler. Statü listesi (ve
id'leri) panelde tanımlanır; SDK statü adlarına bakmaz, yalnızca `type` ve aşağıdaki sabit
id'leri yorumlar.

### Host bu bilgiyi nereden alır?

| Kanal | Ne zaman gelir | Ne taşır |
|---|---|---|
| `setupSDK(onFinished:)` / `onFlowFinished` / `flowResultDelegate` | Yalnızca **oturumu bitiren** kapanışlarda, bir kez | `result`, `reason = .agentDecision`, `terminateReason` ve `statusSummary` birebir |
| `eventDelegate` → `session.finished` | Aynı an | metadata: `result`, `endReason`, `terminateReason`, `statusSummary`, `statusId` |
| `eventDelegate` → `call.ended` | **Her** `terminateCall`'da | metadata: `reason`, `statusSummary` (type) |
| `delegate.terminateCall(terminateReason:statusSummaryType:)` | **Her** `terminateCall`'da, ham | sebep + `type` |
| `socketMessageListener` → `.terminateCall(reason, type)` | **Her** `terminateCall`'da, ham | sebep + `type` (DefaultUI'da görüşme ekranı devralır) |
| `IdentifyManager.shared.lastStatusSummary` | Son `terminateCall`'dan sonra | tüm `StatusSummary` (id dahil) |

> Sonuca göre iş yapacaksanız `onFinished` kullanın: ham kanallar karar içermeyen, yeniden
> bağlanmaya düşen kapanışlarda da tetiklenir.

### SDK hangi değere göre ne yapar?

Kural `SDKTerminateClassifier` içindedir ve **yukarıdan aşağı ilk eşleşen satır** uygulanır.
Varsayılan görüşme ekranı ve `onFinished` aynı kuralı kullanır.

| # | `terminateReason` | Koşul | SDK ne yapar | Ekran | `onFinished` |
|---|---|---|---|---|---|
| 1 | `TURN_DISCONNECTED` · `RINGING_TIMEOUT` | — (bu değerleri panel değil **SDK üretir**: medya hattı düştü / çağrı yanıtlanmadı) | Yeniden bağlanma ekranı; socket 4104 / 4108 ile kapanır | Bağlantı Koptu | — (oturum sürer) |
| 2 | `NORMAL_CLOSE_BY_AGENT` | `type` karar (`positive` · `negative` · `neutral`) **ve** `id ≠ -3` | Oturum biter, SDK kapanır (4103) | ThankYou: `positive` → başarılı, diğerleri → tamamlanamadı · `showThankYouPage: false` ise ekran yok | `approved` · `rejected` · `neutral` |
| 3 | `NORMAL_CLOSE_BY_AGENT` | `id == -3` ("Durum Seçilmedi") **ya da** statü yok / tanınmayan `type` | Karar yok: yeniden bağlanma → bekleme odası | Bağlantı Koptu | — |
| 4 | `ADMIN_DISCONNECTED_TURN` · `AGENT_SOCKET_NETWORK_PROBLEM` · `AGENT_FORCE_DISCONNECT_FOR_AUTO_CLOSE` · `UNKNOW` / `UNKNOWN` | Statüden **bağımsız** (panelin otomatik yazdığı `id 8` "Müşteri cevap vermedi", `negative` dahil) | Temsilci hüküm vermemiştir: yeniden bağlanma → bekleme odası | Bağlantı Koptu | — |
| 5 | `CLIENT_IS_DISCONNECTED` | Socket açıksa | Panelin yanlış alarmı sayılır, görüşme **sürer** | değişmez | — |
| | | Socket kapalıysa | Yeniden bağlanma | Bağlantı Koptu | — |
| 6 | Diğer tüm değerler (ör. `PING_TIMEOUT`) | `type` karar ise | Oturum biter (satır 2 gibi) | ThankYou | `approved` · `rejected` · `neutral` |
| | | Karar yoksa | Yeniden bağlanma (`PING_TIMEOUT` → 4107, diğerleri 4104) | Bağlantı Koptu | — |

Sabit statü id'leri:

| `id` | Anlamı | SDK'nın yorumu |
|---|---|---|
| `-3` | Durum Seçilmedi | Karar değildir — `type` gelse bile oturumu bitirmez |
| `-4` | Auto Approved | `positive` tipinde gelir; yeniden bağlanmada da oturumu bitirir |
| `8` | Müşteri cevap vermedi | Panelin otomatik etiketi; satır 4'teki sebeplerle geldiğinde karar sayılmaz |

Yeniden bağlanma sonrası panelin kayıtlı statüsü sorgulanır (`SendIdentStatusInfo`). Bu bir
**sorgudur**, karar değildir: yalnızca `positive` oturumu bitirir (`onFinished` → `approved`);
`negative`, `neutral` ve `-3` müşteriyi bekleme odasına döndürür. Olumsuz karar gerekiyorsa
panel `terminateCall` gönderir.

Kapanış dışı ilgili aksiyonlar:

| Aksiyon | SDK ne yapar | `onFinished` |
|---|---|---|
| `missedCall` | Oturumu **bitirmez**, zil susar, müşteri bekleme odasında kalır | — |
| `endCall` (`terminateCall` olmadan) | Görüşmeyi müşteri kapatmıştır; akış sıradaki modüle, yoksa ThankYou'ya (tamamlanamadı) geçer | akış sonunda `notCompleted` / `userEndedCall` |
| Müşteri "Görüşmeyi bitir"e basar | Panele `terminateCallOnMobile` gider, SDK kapanır | `notCompleted` / `userEndedCall` |

### Örnek: temsilci şüpheli bir durum görüp görüşmeyi sonlandırdı

Temsilci görüşme sırasında şüpheli bir durum görür (ör. belge ile yüz uyuşmuyor, ekrandan
gösterilen belge) ve panelde bu durum için tanımlı **olumsuz** statüyü seçerek görüşmeyi
kapatır. Soketten şuna benzer bir mesaj gelir (statü adı ve id'si panelinizdeki tanıma göre
değişir):

```json
{
  "action": "terminateCall",
  "terminateReason": "NORMAL_CLOSE_BY_AGENT",
  "statusSummary": { "id": 12, "type": "negative", "name_tr": "Şüpheli İşlem", "name_en": "Suspicious Transaction" }
}
```

SDK'nın yaptıkları (tablodaki satır 2):

1. Oturum biter; socket kapatılır, görüşme medyası bırakılır.
2. `onFinished` **karar anında** çağrılır: `result = .rejected`, `reason = .agentDecision`,
   `terminateReason = "NORMAL_CLOSE_BY_AGENT"`, `statusSummary` mesajdaki haliyle.
3. Müşteriye ThankYou "tamamlanamadı" gösterilir — **şüphe sebebi müşteriye gösterilmez**.
   `showThankYouPage: false` ise ekran açılmaz, SDK aşağı kayarak kapanır.
4. `sdk_logs`'a sebep, statü ve id ile yazılır:

   ```
   Akış sonucu — sonuç: rejected, sebep: agentDecision, son modül: Call Wait Screen, adım: 5/5, panel sebebi: NORMAL_CLOSE_BY_AGENT, panel statüsü: negative (id 12).
   Görüşme sonlandırma bildirimi alındı — sebep: NORMAL_CLOSE_BY_AGENT, panel statüsü: negative (id 12)
   Sonlandırma sonucu: temsilci normal kapattı, oturum panelin statüsüyle bitiriliyor (negative)
   Oturum sonlandı — son modül: Call Wait Screen, akış tamamlandı, sebep: 4103 (forceQuit): forceQuitSDK — zorla kapatma
   ```

Host tarafında şüpheli kapanışı diğer retlerden **statü id'si** ile ayırın (adlar
yerelleştirilir ve panelde değiştirilebilir; `type` yalnızca yönü söyler):

```swift
let suspiciousStatusIds: Set<Int> = [12]   // panelinizdeki "şüpheli" statülerinin id'leri

IdentifyManager.shared.setupSDK(
    ...,
    onFinished: { outcome in
        guard outcome.reason == .agentDecision else { return handleOther(outcome) }
        let statusId = outcome.statusSummary?.id

        switch outcome.result {
        case .approved:
            router.show(.kycSuccess)
        case .rejected where statusId.map(suspiciousStatusIds.contains) == true:
            fraudService.flag(sessionId: outcome.sessionId, statusId: statusId,
                              reason: outcome.terminateReason)
            router.show(.kycFailedGeneric)          // müşteriye sebep gösterilmez
        case .rejected, .neutral:
            router.show(.kycFailed(statusName: outcome.statusSummary?.name_tr))
        default:
            break
        }
    }
) { socket, room, error in ... }
```

Olay akışıyla (RN/Flutter köprüleri dahil) aynı ayrım `session.finished` olayının
`metadata.result == "rejected"` ve `metadata.statusId` alanlarıyla yapılır.

---

## Birleşik Kapanma Kodları — `SDKSocketCloseCode` (4100+)

Soket ve TURN kapanmalarının **tamamı** SDK'ya özel tek bir kod uzayında toplanır
(RFC 6455'in "private use" 4000–4999 aralığı). Son kapanışı okumak için:

```swift
IdentifyManager.shared.lastSocketCloseCode          // SDKSocketCloseCode?
IdentifyManager.shared.lastSocketCloseCode?.rawValue // örn. 4105
```

Ayrıca her kapanışta `socket.closed` (TURN için `turn.dropped`) SDKEvent'i yayınlanır —
metadata'da `code`, `case`, `category`, `deliberate` ve varsa `reason` bulunur.
Detay: [Event Sistemi](events.md).

### 4100–4109 · Bilinçli kapanışlar
SDK'nın kendisi kapatır; kod **close frame ile sunucuya da gider**.

| Kod | Case | Ne zaman |
|---|---|---|
| 4100 | `flowCompleted` | Son modül tamamlandı, teşekkür ekranına geçiliyor |
| 4101 | `hostQuit` | `quitSDK()` |
| 4102 | `hostExit` | `exitSDK()` |
| 4103 | `forceQuit` | `forceQuitSDK()` |
| 4104 | `reconnectCycle` | Reconnect öncesi eski bağlantının kapatılması |
| 4105 | `backgroundTimeout` | Uygulama arka planda limit süreyi aştı (aşağıya bakın) |
| 4106 | `callCompleted` | Görüşme tamamlandı; sonraki modüle geçiliyor (`disconnectSocket(reason:)`) |
| 4107 | `pingTimeout` | *Rezerve* — ölü bağlantı tespiti bu sürümde 4109 ile yapılır |
| 4108 | `ringingTimeout` | Çağrı çaldı ama `ringingTimeout` (varsayılan 300 sn) boyunca yanıtlanmadı |
| 4109 | `heartbeatTimeout` | Ardışık 3 PING'e PONG gelmedi — bağlantı ölü kabul edildi |

> ⚠️ **Sürüm notu:** `4106` daha önce `heartbeatTimeout` idi. Heartbeat zaman aşımı
> **4109**'a taşındı, 4106 artık `callCompleted`. Sunucu tarafındaki eşlemeyi güncelleyin.

### 4110–4119 · Sunucu/protokol kaynaklı (gelen standart kodun etiketi)

| Kod | Case | Kaynak | Davranış |
|---|---|---|---|
| 4110 | `serverNormal` | 1000 | sadece log |
| 4111 | `serverGoingAway` | 1001 | sadece log |
| 4112 | `noStatusReceived` | 1005 | sadece log |
| 4113 | `protocolError` | 1002 | listener'a **`.connectionErr`** |
| 4114 | `unsupportedFrame` | 1003 | listener'a **`.connectionErr`** |
| 4115 | `encodingError` | 1007 | listener'a **`.connectionErr`** |
| 4116 | `policyViolated` | 1008 | listener'a **`.connectionErr`** |
| 4117 | `messageTooBig` | 1009 | listener'a **`.connectionErr`** |
| 4118 | `unknownWsError` | diğer | listener'a **`.connectionErr`** (tip detayı reason'da) |
| 4119 | `authRejected` | — | WS anahtarı/oturum doğrulaması reddedildi; bağlantı hiç kurulamadı |

> Hata kodlarında eskiden son `sdkSocketActions` yeniden yayınlanıyordu; kopma anındaki
> değer alakasız olduğu için reconnect ekranı açılmıyordu. Artık her beklenmedik kopmada
> `.connectionErr` gider ve arkada canlı kalan WebSocket/WebRTC bağlantıları elle kapatılır.

### 4130–4133 · Ağ kaynaklı — hepsi LostConnection overlay'ini tetikler

| Kod | Case | Kaynak |
|---|---|---|
| 4130 | `networkUnreachable` | Reachability: internet erişimi yok |
| 4131 | `transportError` | SSL / proxy / firewall hatası |
| 4132 | `unexpectedDrop` | Hatasız kopma — sunucu sessiz kapattı |
| 4133 | `connectTimeout` | Verilen sürede bağlantı hiç kurulamadı (ilk 30 sn · reconnect 10 sn) |

### 4140–4142 · TURN / ICE (WebRTC)

| Kod | Case | Kaynak | Davranış |
|---|---|---|---|
| 4140 | `turnDisconnected` | ICE `.disconnected` | anında `terminateCall("TURN_DISCONNECTED")` |
| 4141 | `turnFailed` | ICE `.failed` | anında `terminateCall("TURN_DISCONNECTED")` |
| 4142 | `turnClosed` | ICE `.closed` | log + event |

> **Toparlanma penceresi YOK.** ICE ya da WebSocket koptuğu anda görüşme biter, tüm
> bağlantılar kapatılır ve kullanıcıya "Bağlantı Koptu" ekranı gösterilir. Bekleme/askı
> yapısı denendi ve geri alındı: sunucu askıdaki oturumu canlı saydığı için yeniden
> abonelik `subRejected` ("Oda dolu") ile reddediliyor, panel çağrı oturumunu kapatmıyordu.
> Ayrıntı: [TURN & WebRTC → Neden toparlanma penceresi YOK?](turn-webrtc.md).

### Arka Plan Zaman Aşımı (4105)

Aktif oturum sırasında uygulama arka plana geçerse SDK süre sayar; limit aşılırsa
soket **4105** ile kapatılır ve kullanıcı döndüğünde LostConnection/reconnect ekranı
hazırdır. Sistem uygulamayı erken dondurursa süre, ön plana dönüşte telafi edilir.

Kural **istisnasız** işler: çalan çağrı ya da süren görüşme de muaf değildir. Süre dolunca
görüşme biter, kullanıcı yeniden bağlanma ekranına alınır ve oradan tam prosedürle bekleme
odasına döner (temsilci yeniden arayabilir). Eskiden canlı çağrı muaf tutuluyordu; sonuç,
limitin görüşmede hiç işlememesi ve mobil ile panelin farklı durumda kalması oldu.

```swift
IdentifyManager.shared.backgroundTimeoutSeconds = 30   // varsayılan 30 sn
IdentifyManager.shared.isBackgroundTimeoutEnabled = true // kapatmak için false
```

Geçişlerin kendisi de olay üretir: `session.background` (limit + soket durumu) ve
`session.foreground` (arka planda geçen süre).

---

## Soket Trafiğini İzleme

Gelen/giden tüm soket mesajları log altyapısına `socket` kategorisiyle düşer
(`SocketLog`: `incoming`/`outgoing`). Konsolda görmek için `logLevel: .all` yeterlidir;
online'a da göndermek için `.online`. Ayrıntı: [Loglama](logging.md).
