# WebSocket — Canlı Sinyal Kanalı

SDK oturum boyunca backend'le açık bir WebSocket bağlantısı tutar. Gelen çağrı, SMS onayı, agent
komutları ve adım bildirimleri bu kanaldan gelip gider. Bu rehberde bağlantının nasıl kurulduğunu,
token'lı bağlantıyı (`socket_auth`), aksiyon listesini ve bağlantı koptuğunda ne olduğunu
bulacaksınız.

← [README'ye dön](../../README.md) · İlgili: [Sunucu & API](server-api.md) · [TURN & WebRTC](turn-webrtc.md)

---

## Bağlantının Kurulması

Soket adresini (`ws_url`) siz vermezsiniz; `connectToRoom` cevabından gelir. İstemci olarak
[Starscream](https://github.com/daltoniam/Starscream) WebSocket kullanılır.

```
RoomResponse.ws_url ──► WebSocket(url:)
                          │  socket_auth == "1" ise: ws_url + "?token=<HMAC token>"
                          ▼
                        connect() ──► sendFirstSubscribe()   (odaya kayıt)
```

Bağlantı yaklaşık 30 saniye içinde kurulamazsa `setupSDK` callback'ine hata döner.

### `socket_auth` — Token'lı Bağlantı

Backend `socket_auth = "1"` gönderirse SDK soket adresine kısa ömürlü, imzalı bir token ekler. Bu
durumda `setupSDK`'ya `wsSecretKey` vermeniz zorunlu.

Token şöyle üretilir (bilgi için; SDK bunu kendisi yapar):

```
payload   = "<form_uid>:<şimdi + 60sn unix zaman>:<4 bayt rastgele hex>"
imza      = HMAC-SHA256(payload, wsSecretKey)     → hex
token     = base64("payload.imza")
soket URL = ws_url + "?token=" + token
```

Token 60 saniye geçerli ve her yeniden bağlanmada yenisi üretilir. `wsSecretKey` yanlışsa soket
hiç bağlanmaz ve giriş aşamasında "WS key hatası" görürsünüz.

---

## Aksiyon Kataloğu — `SDKCallActions`

Soketten gelen mesajlar `SDKCallActions` enum'ına çevrilip dinleyicilere iletilir. DefaultUI
kullanıyorsanız hazır ekranlar bunların hepsini zaten işler. Kendi ekranınızı yazıyorsanız
ilgilendiğiniz aksiyonları dinlersiniz.

| Aksiyon | Anlamı |
|---|---|
| `incomingCall` | Agent arıyor; çağrı ekranı açılmalı |
| `endCall` | Görüşme kapandı. Öncesinde `terminateCall` gelmediyse görüşmeyi müşteri kapatmıştır ([Görüşmenin Kapanışı](#görüşmenin-kapanışı--terminatecall)) |
| `missedCall` | Çağrı cevapsız kaldı. Oturum bitmez, müşteri bekleme odasında kalır |
| `terminateCall(reason, statusSummary)` | Panel görüşmeyi sonlandırdı. Sebebe ve statüye göre oturum biter ya da yeniden bağlanma başlar ([karar tablosu](#görüşmenin-kapanışı--terminatecall)) |
| `comingSms` / `approveSms(Bool)` | SMS doğrulama akışı |
| `openWarningCircle` / `closeWarningCircle` | Agent müşterinin ekranında uyarı çemberini açtı/kapattı |
| `openCardCircle` / `closeCardCircle` | Kimlik gösterme çemberi açıldı/kapandı |
| `photoTaken(String)` | Agent görüşme sırasında fotoğraf çekti |
| `updateQueue(sıra, toplam)` | Bekleme odasındaki sıra bilgisi güncellendi |
| `subscribed` | Odaya kayıt tamamlandı |
| `subrejectedDismiss(String)` | Kayıt reddedildi (ör. süresi geçmiş ident) |
| `openNfcRemote(...)` | Agent uzaktan NFC adımını başlattı |
| `editNfcProcess` | Agent NFC verisinde düzeltme istedi |
| `startTransfer` | Görüşme başka bir agent'a aktarılıyor |
| `networkQuality(String)` | Bağlantı kalitesi bildirimi |
| `disableEndCallButton` | Müşterinin "Görüşmeyi bitir" butonu kilitlendi |
| `imOffline` | Karşı taraf çevrimdışı |
| `connectionErr` | Bağlantı koptu (aşağıya bakın) |
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

> DefaultUI'da bu dinleyiciyi `SDKFlowCoordinator` yönetir. CallScreen gibi dinleyiciyi bir süre
> kendine alan ekranlar kapanırken `coordinator.restoreSocketListener()` çağırır.

---

## Modül → Sunucu Sinyalleri

Soket yalnızca sunucudan komut almak için kullanılmaz; SDK her modül geçişinde sunucuya durum da
bildirir:

| Sinyal | Ne zaman gider |
|---|---|
| `sendStep()` | Modül adımı tamamlandığında ya da konum değiştiğinde |
| `sendPreparetatus(isCompleted:)` | Hazırlık modülünün sonucu |
| `sendSpeechStatus(isCompleted:)` | Konuşma modülünün sonucu |
| `modulePresented` (adım bildirimi) | `advanceToNextModule()` içinde |

`stepChanged` gövdesindeki `steps.sign_language` alanı işaret dili tercihini taşır.
`signLangSupport: true` iken bekleme ekranındaki `stepChanged`, kullanıcı işaret dili sorusunu
geçene kadar gönderilmez. Ayrıntı: [SignLang](../../IdentifySample/Modules/SignLang/SignLang.md#sunucuya-giden-veri).

Custom ekranların SDK VM metotlarını kullanması bu yüzden şart. Kendi geçişlerinizi yaparsanız bu
sinyaller gitmez ve agent panelinde akış takılmış gibi görünür.
Ayrıntı: [Özelleştirme → bypass yok kuralı](customization.md#bypass-yok-kuralı).

---

## Bağlantı Kopması ve Toparlanma

SDK kopmayı birbirinden bağımsız iki kaynaktan anlar:

1. Reachability izleyicisi: oturum başlarken açılır. İnternet `.notReachable` olursa (ve KYC
   bitmemişse) devreye girer.
2. Soket kopması: Starscream'in disconnect bildirimi.

İki kaynak da aynı noktaya çıkar. `.connectionErr` yalnızca bir kez gönderilir, tekrarlar yok
sayılır. Yeniden bağlantı başarılı olunca bayrak sıfırlanır.

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

`reconnectToSocket` aynı anda iki kez çağrılırsa ikincisi çalışmaz (`isReconnecting` kontrolü).
Kullanıcının gördüğü taraf için: [LostConnection rehberi](../../IdentifySample/Modules/LostConnection/LostConnection.md).

---

## Görüşmenin Kapanışı — `terminateCall`

Panel görüşmeyi yalnızca `terminateCall` ile bitirir. Temsilci görüşmeyi kapatmaya hazırlanırken
önce `disableEndCallButton` gönderir (müşterinin "Görüşmeyi bitir" butonu kilitlenir), ardından
her durumda `terminateCall` gelir. `terminateCall` gelmeden kapanan bir görüşmeyi müşteri
kapatmıştır.

Mesajda iki bilgi var:

| Alan | Anlamı |
|---|---|
| `terminateReason` | Görüşmenin nasıl kapandığı (ör. `NORMAL_CLOSE_BY_AGENT`) |
| `statusSummary` | Temsilcinin panelde seçtiği karar: `id`, `type` (`positive` · `negative` · `neutral`), `status`, `name_tr` / `name_en` / `name_de` |

`type` kararın yönünü, `id` hangi statünün seçildiğini söyler. Statü listesi ve id'leri panelde
tanımlanır. SDK statü adlarına bakmaz; yalnızca `type`'ı ve aşağıdaki sabit id'leri yorumlar.

### Host bu bilgiyi nereden alır?

| Kanal | Ne zaman gelir | Ne taşır |
|---|---|---|
| `setupSDK(onFinished:)` / `onFlowFinished` / `flowResultDelegate` | Yalnızca oturumu bitiren kapanışlarda, bir kez | `result`, `reason = .agentDecision`, `terminateReason` ve `statusSummary` birebir |
| `eventDelegate` → `session.finished` | Aynı anda | metadata: `result`, `endReason`, `terminateReason`, `statusSummary`, `statusId` |
| `eventDelegate` → `call.ended` | Her `terminateCall`'da | metadata: `reason`, `statusSummary` (type) |
| `delegate.terminateCall(terminateReason:statusSummaryType:)` | Her `terminateCall`'da, ham | sebep + `type` |
| `socketMessageListener` → `.terminateCall(reason, type)` | Her `terminateCall`'da, ham | sebep + `type` (DefaultUI'da görüşme ekranı dinler) |
| `IdentifyManager.shared.lastStatusSummary` | Son `terminateCall`'dan sonra | `StatusSummary`'nin tamamı (id dahil) |

> Sonuca göre iş yapacaksanız `onFinished`'ı kullanın. Ham kanallar karar içermeyen ve yeniden
> bağlanmayla devam eden kapanışlarda da tetiklenir.

### SDK hangi değere göre ne yapar?

Kural `SDKTerminateClassifier` içinde. Tablo yukarıdan aşağı okunur ve eşleşen ilk satır uygulanır.
Varsayılan görüşme ekranı da `onFinished` da aynı kuralı kullanır.

| # | `terminateReason` | Koşul | SDK ne yapar | Ekran | `onFinished` |
|---|---|---|---|---|---|
| 1 | `TURN_DISCONNECTED` · `RINGING_TIMEOUT` | Bu değerleri panel değil SDK üretir (medya bağlantısı düştü / çağrı yanıtlanmadı) | Yeniden bağlanma ekranı; socket 4104 / 4108 ile kapanır | Bağlantı Koptu | Yok (oturum sürer) |
| 2 | `NORMAL_CLOSE_BY_AGENT` | `type` bir karar (`positive` · `negative` · `neutral`) ve `id ≠ -3` | Oturum biter, SDK kapanır (4103) | ThankYou: `positive` → başarılı, diğerleri → tamamlanamadı. `showThankYouPage: false` ise ekran yok | `approved` · `rejected` · `neutral` |
| 3 | `NORMAL_CLOSE_BY_AGENT` | `id == -3` ("Durum Seçilmedi") ya da statü yok / `type` tanınmıyor | Karar yok: yeniden bağlanma → bekleme odası | Bağlantı Koptu | Yok |
| 4 | `ADMIN_DISCONNECTED_TURN` · `AGENT_SOCKET_NETWORK_PROBLEM` · `AGENT_FORCE_DISCONNECT_FOR_AUTO_CLOSE` · `UNKNOW` / `UNKNOWN` | Statü ne olursa olsun (panelin kendiliğinden yazdığı `negative` tipli `id 8` "Müşteri cevap vermedi" dahil) | Temsilci karar vermemiştir: yeniden bağlanma → bekleme odası | Bağlantı Koptu | Yok |
| 5 | `CLIENT_IS_DISCONNECTED` | Socket açıksa | Panelin yanlış alarmı sayılır, görüşme sürer | Değişmez | Yok |
| | | Socket kapalıysa | Yeniden bağlanma | Bağlantı Koptu | Yok |
| 6 | Diğer bütün değerler (ör. `PING_TIMEOUT`) | `type` bir kararsa | Oturum biter (2. satırdaki gibi) | ThankYou | `approved` · `rejected` · `neutral` |
| | | Karar yoksa | Yeniden bağlanma (`PING_TIMEOUT` → 4107, diğerleri 4104) | Bağlantı Koptu | Yok |

Sabit statü id'leri:

| `id` | Anlamı | SDK'nın yorumu |
|---|---|---|
| `-3` | Durum Seçilmedi | Karar sayılmaz; `type` gelse bile oturumu bitirmez |
| `-4` | Auto Approved | `positive` tipinde gelir; yeniden bağlanmadan sonra da oturumu bitirir |
| `8` | Müşteri cevap vermedi | Panelin kendiliğinden yazdığı etiket; 4. satırdaki sebeplerle gelirse karar sayılmaz |

Yeniden bağlandıktan sonra panelde kayıtlı statü sorgulanır (`SendIdentStatusInfo`). Bu bir karar
değil, sorgudur: oturumu yalnızca `positive` bitirir (`onFinished` → `approved`). `negative`,
`neutral` ve `-3` müşteriyi bekleme odasına döndürür. Olumsuz bir karar vermek için panel
`terminateCall` göndermelidir.

Kapanışla ilgili diğer aksiyonlar:

| Aksiyon | SDK ne yapar | `onFinished` |
|---|---|---|
| `missedCall` | Oturumu bitirmez; zil susar, müşteri bekleme odasında kalır | Yok |
| `endCall` (`terminateCall` olmadan) | Görüşmeyi müşteri kapatmıştır. Akış sıradaki modüle, sıradaki modül yoksa ThankYou'ya (tamamlanamadı) geçer | Akış sonunda `notCompleted` / `userEndedCall` |
| Müşteri "Görüşmeyi bitir"e basar | Panele `terminateCallOnMobile` gider, SDK kapanır | `notCompleted` / `userEndedCall` |

### Örnek: temsilci şüpheli bir durum görüp görüşmeyi sonlandırdı

Temsilci görüşmede şüpheli bir durum fark eder (ör. belgedeki fotoğraf yüzle uyuşmuyor ya da belge
bir ekrandan gösteriliyor) ve panelde bu durum için tanımlanmış olumsuz statüyü seçip görüşmeyi
kapatır. Soketten şuna benzer bir mesaj gelir; statünün adı ve id'si panelinizdeki tanıma göre
değişir:

```json
{
  "action": "terminateCall",
  "terminateReason": "NORMAL_CLOSE_BY_AGENT",
  "statusSummary": { "id": 12, "type": "negative", "name_tr": "Şüpheli İşlem", "name_en": "Suspicious Transaction" }
}
```

SDK şunları yapar (tablodaki 2. satır):

1. Oturum biter; socket kapatılır, görüşmenin medyası bırakılır.
2. `onFinished` karar anında çağrılır: `result = .rejected`, `reason = .agentDecision`,
   `terminateReason = "NORMAL_CLOSE_BY_AGENT"`, `statusSummary` mesajda geldiği gibi.
3. Müşteri ThankYou ekranında "tamamlanamadı" mesajını görür; şüphe sebebi müşteriye gösterilmez.
   `showThankYouPage: false` ise ekran açılmaz, SDK aşağı kayarak kapanır.
4. `sdk_logs`'a sebep, statü ve id yazılır:

   ```
   Akış sonucu — sonuç: rejected, sebep: agentDecision, son modül: Call Wait Screen, adım: 5/5, panel sebebi: NORMAL_CLOSE_BY_AGENT, panel statüsü: negative (id 12).
   Görüşme sonlandırma bildirimi alındı — sebep: NORMAL_CLOSE_BY_AGENT, panel statüsü: negative (id 12)
   Sonlandırma sonucu: temsilci normal kapattı, oturum panelin statüsüyle bitiriliyor (negative)
   Oturum sonlandı — son modül: Call Wait Screen, akış tamamlandı, sebep: 4103 (forceQuit): forceQuitSDK — zorla kapatma
   ```

Host tarafında şüpheli kapanışı diğer retlerden statü id'siyle ayırın. Statü adları dile göre
değişir ve panelden düzenlenebilir; `type` ise yalnızca kararın yönünü söyler:

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

Olay akışını kullanıyorsanız (RN ve Flutter köprüleri dahil) aynı ayrımı `session.finished`
olayının `metadata.result == "rejected"` ve `metadata.statusId` alanlarıyla yaparsınız.

---

## Birleşik Kapanma Kodları — `SDKSocketCloseCode` (4100+)

Soket ve TURN kapanmalarının hepsi SDK'ya özel tek bir kod aralığında toplanır (RFC 6455'in
"private use" için ayırdığı 4000–4999 aralığı). Son kapanışı şöyle okursunuz:

```swift
IdentifyManager.shared.lastSocketCloseCode          // SDKSocketCloseCode?
IdentifyManager.shared.lastSocketCloseCode?.rawValue // örn. 4105
```

Her kapanışta ayrıca `socket.closed` (TURN için `turn.dropped`) SDKEvent'i gönderilir. Metadata'da
`code`, `case`, `category`, `deliberate` ve varsa `reason` bulunur.
Ayrıntı: [Event Sistemi](events.md).

### 4100–4109 · Bilinçli kapanışlar
Bu kapanışları SDK kendisi yapar ve kod close frame ile sunucuya da gider.

| Kod | Case | Ne zaman |
|---|---|---|
| 4100 | `flowCompleted` | Son modül tamamlandı, teşekkür ekranına geçiliyor |
| 4101 | `hostQuit` | `quitSDK()` |
| 4102 | `hostExit` | `exitSDK()` |
| 4103 | `forceQuit` | `forceQuitSDK()` |
| 4104 | `reconnectCycle` | Yeniden bağlanmadan önce eski bağlantı kapatılıyor |
| 4105 | `backgroundTimeout` | Uygulama arka planda izin verilen süreyi aştı (aşağıya bakın) |
| 4106 | `callCompleted` | Görüşme tamamlandı, sonraki modüle geçiliyor (`disconnectSocket(reason:)`) |
| 4107 | `pingTimeout` | Ayrılmış; bu sürümde ölü bağlantı 4109 ile tespit ediliyor |
| 4108 | `ringingTimeout` | Çağrı çaldı ama `ringingTimeout` süresince (varsayılan 300 sn) yanıtlanmadı |
| 4109 | `heartbeatTimeout` | Üst üste 3 PING'e PONG gelmedi, bağlantı ölü sayıldı |

> ⚠️ Sürüm notu: `4106` önceden `heartbeatTimeout` idi. Heartbeat zaman aşımı 4109'a taşındı,
> 4106 artık `callCompleted`. Sunucu tarafındaki eşlemeyi güncelleyin.

### 4110–4119 · Sunucu/protokol kaynaklı (gelen standart kodun etiketi)

| Kod | Case | Kaynak | Davranış |
|---|---|---|---|
| 4110 | `serverNormal` | 1000 | Yalnızca log |
| 4111 | `serverGoingAway` | 1001 | Yalnızca log |
| 4112 | `noStatusReceived` | 1005 | Yalnızca log |
| 4113 | `protocolError` | 1002 | Dinleyiciye `.connectionErr` |
| 4114 | `unsupportedFrame` | 1003 | Dinleyiciye `.connectionErr` |
| 4115 | `encodingError` | 1007 | Dinleyiciye `.connectionErr` |
| 4116 | `policyViolated` | 1008 | Dinleyiciye `.connectionErr` |
| 4117 | `messageTooBig` | 1009 | Dinleyiciye `.connectionErr` |
| 4118 | `unknownWsError` | diğer | Dinleyiciye `.connectionErr` (hatanın türü reason'da) |
| 4119 | `authRejected` | — | WS anahtarı ya da oturum doğrulaması reddedildi; bağlantı hiç kurulamadı |

> Önceden hata kodlarında son `sdkSocketActions` değeri yeniden gönderiliyordu. Kopma anındaki bu
> değer kopmayla ilgisiz olduğu için yeniden bağlanma ekranı açılmıyordu. Artık her beklenmedik
> kopmada `.connectionErr` gönderiliyor ve arkada açık kalan WebSocket/WebRTC bağlantıları elle
> kapatılıyor.

### 4130–4133 · Ağ kaynaklı — hepsi LostConnection overlay'ini tetikler

| Kod | Case | Kaynak |
|---|---|---|
| 4130 | `networkUnreachable` | Reachability: internet erişimi yok |
| 4131 | `transportError` | SSL, proxy ya da firewall hatası |
| 4132 | `unexpectedDrop` | Hata olmadan kopma; sunucu bağlantıyı sessizce kapattı |
| 4133 | `connectTimeout` | Bağlantı verilen sürede kurulamadı (ilk bağlantıda 30 sn, yeniden bağlanmada 10 sn) |

### 4140–4142 · TURN / ICE (WebRTC)

| Kod | Case | Kaynak | Davranış |
|---|---|---|---|
| 4140 | `turnDisconnected` | ICE `.disconnected` | Hemen `terminateCall("TURN_DISCONNECTED")` |
| 4141 | `turnFailed` | ICE `.failed` | Hemen `terminateCall("TURN_DISCONNECTED")` |
| 4142 | `turnClosed` | ICE `.closed` | Log + event |

> ICE ya da WebSocket koptuğu anda görüşme biter, bütün bağlantılar kapatılır ve kullanıcı
> "Bağlantı Koptu" ekranını görür; toparlanma için beklenmez. Bir süre görüşmeyi askıya alıp
> bekleyen bir yapı denendi ve geri alındı. Sunucu askıdaki oturumu hâlâ açık saydığı için yeniden
> abonelik `subRejected` ("Oda dolu") ile reddediliyor, panel de çağrı oturumunu kapatmıyordu.
> Ayrıntı: [TURN & WebRTC → Neden toparlanma penceresi YOK?](turn-webrtc.md).

### Arka Plan Zaman Aşımı (4105)

Oturum sürerken uygulama arka plana geçerse SDK süre tutar. Süre sınırı aşılırsa soket 4105 ile
kapatılır ve kullanıcı uygulamaya döndüğünde LostConnection/yeniden bağlanma ekranını görür.
Sistem uygulamayı erken dondurursa eksik kalan süre uygulama ön plana dönünce hesaba katılır.

Kuralın istisnası yok; çalan çağrı ya da süren görüşme de bu kurala tabi. Süre dolunca görüşme
biter, kullanıcı yeniden bağlanma ekranına alınır ve oradan tam prosedürle bekleme odasına döner
(temsilci onu yeniden arayabilir). Önceden süren çağrılar bu kuraldan muaftı; bu yüzden süre sınırı
görüşme sırasında hiç işlemiyordu ve mobil uygulama ile panel farklı durumlarda kalıyordu.

```swift
IdentifyManager.shared.backgroundTimeoutSeconds = 30   // varsayılan 30 sn
IdentifyManager.shared.isBackgroundTimeoutEnabled = true // kapatmak için false
```

Arka plana ve ön plana geçişler de olay üretir: `session.background` (süre sınırı ve soket durumu)
ve `session.foreground` (arka planda geçen süre).

---

## Soket Trafiğini İzleme

Gelen ve giden bütün soket mesajları log altyapısına `socket` kategorisiyle yazılır (`SocketLog`:
`incoming`/`outgoing`). Konsolda görmek için `logLevel: .all` yeterli; online'a da göndermek için
`.online` kullanın. Ayrıntı: [Loglama](logging.md).
