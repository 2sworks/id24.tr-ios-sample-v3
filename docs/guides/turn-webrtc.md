# TURN & WebRTC — Görüntülü Görüşme Altyapısı

Görüntülü görüşme modülü ([CallScreen](../../IdentifySample/Modules/CallScreen/CallScreen.md))
[stasel/WebRTC](https://github.com/stasel/WebRTC) üzerine kurulu. Bu rehber görüşmenin hangi
adımlarla kurulduğunu ve TURN kimliklerinin üç modunu anlatır. `turnKey` parametresinin ne işe
yaradığını da burada bulursunuz.

> 3.1.1'den itibaren WebRTC sürümü 153 (`exact: "153.0.0"`). Görüntü Metal tabanlı
> `RTCMTLVideoView` ile çiziliyor; `RTCEAGLVideoView` bu sürümde kaldırıldı. Kendi görüşme
> ekranınızda video view kullanıyorsanız `RTCMTLVideoView`'a geçin.

← [README'ye dön](../../README.md) · İlgili: [WebSocket](websocket.md) · [Sunucu & API](server-api.md)

---

## Parçalar

| Parça | Görev |
|---|---|
| `WebRTCClient` | Peer connection, yerel ve uzak video track'leri, data channel, ICE adayları |
| STUN/TURN sunucuları | NAT arkasındaki cihazlar arasında medyanın akmasını sağlar; adresleri backend verir |
| WebSocket | Sinyal kanalı: SDP offer/answer ve ICE adayları buradan taşınır |

`WebRTCClient`'ı `IdentifyManager` tutar, bu yüzden ekran değişimlerinden etkilenmez.
`iceTransportPolicy = .all` olduğu için hem doğrudan bağlantı hem TURN üzerinden bağlantı denenir.

---

## TURN Kimlikleri — Üç Mod

STUN/TURN adresleri ve kimlikleri, soket kurulmadan hemen önce `getWSCredential` servisinden
alınır (servisin anahtarı `RoomResponse.data?.ws_secret_key`). Kimliklerin nasıl kullanılacağını
backend'den gelen iki bayrak belirler.

### 1. Düz kimlik (varsayılan)
`encrypted_turn_credential ≠ "1"` ise servisin döndüğü `username` ve `credential` olduğu gibi
kullanılır. Bu modda `turnKey` kullanılmaz.

### 2. Şifreli kimlik — `encrypted_turn_credential == "1"`
Servis kimlikleri AES-256-CBC ile şifreli gönderir, SDK da bunları sizin `turnKey`'inizle çözer.

> ⚠️ Bu modda `turnKey` boşsa görüşme kurulmaz ve konsolda `⚠️turn key gerekli` yazar.

### 3. Kısa ömürlü kimlik — `short_term_usage == "1"`
SDK, çağrı cevaplanırken (`acceptCall`) kimliği cihazda üretir:

```
username = "<şimdi + 15 dk unix zaman>:<identId>"
password = base64( HMAC-SHA1(username, turnKey) )
```

Kimlik her çağrıda yeniden üretildiği için ele geçirilen bir kimlik 15 dakika sonra geçersiz olur.

---

## Görüşme Akışı — Uçtan Uca

```
Müşteri CallScreen'e girer
  └─ bekleme odası: updateQueue(sıra, toplam) soketten akar
Agent aramayı başlatır
  └─ soket: incomingCall ──► çağrı ekranı
Müşteri kabul eder → acceptCall()
  ├─ (short_term_usage) taze TURN kimliği üret
  ├─ WebRTCClient.connect() → SDP offer oluştur
  ├─ soket: "startCall" + SDP offer gönder
  ├─ karşı taraf answer + ICE adayları ──► medya akışı başlar
  └─ data channel açılır (agent komutları: fotoğraf çek, çember aç...)
Görüşme biter
  ├─ agent bitirirse: terminateCall(reason, statusSummary) — karar tablosu: websocket.md → Görüşmenin Kapanışı
  ├─ müşteri bitirebilir (disableEndCallButton ile kilitlenebilir)
  └─ sonuç → ThankYou ekranı (pushThankYouDirectly)
```

Agent'ın görüşme sırasında gönderebileceği komutların listesi:
[WebSocket → Aksiyon Kataloğu](websocket.md#aksiyon-kataloğu--sdkcallactions).

---

## Görüşme Deneyimini Etkileyen Ayarlar

| Ayar | Kaynak | Etki |
|---|---|---|
| `bigCustomerCam` | `setupSDK` parametresi | `true` (verilmezse de böyle): temsilci tam ekran, kullanıcının kamerası küçük pencerede. `false`: tersi |
| `agent_view_scale` | `RoomResponse` | Agent görüntüsünün ölçeği (dikey gösterim dahil) |
| `hide_call_answer_screen` | `RoomResponse` | Çağrı cevaplama ekranı atlanır, zil çalmaz. Hazır görüşme ekranı çağrıyı kendisi yanıtlar; kendi ekranınızda `acceptCall()`'u siz çağırın, yoksa çağrı `ringingTimeout` dolunca 4108 ile düşer |
| `signLangSupport` | `setupSDK` parametresi | Görüşmeden önce işaret dili tercihi sorulur. `signLangPreference` verildiyse sorulmaz ([SignLang](../../IdentifySample/Modules/SignLang/SignLang.md)) |
| `backCameraFocusEnabled` | `IdentifyManager` (3.3.0) | `true` (varsayılan): arka kamera yakına sürekli odaklanır. `false`: kameranın kendi odağı |
| `tapToFocusEnabled` | `IdentifyManager` (3.3.0) | `true` (varsayılan): önizlemeye dokununca o noktaya odaklanır. `false`: dokunmayı host yakalar |
| `swapsLayoutOnBackCamera` | `IdentifyManager` (3.3.0) | `true` (varsayılan): arka kamerada kullanıcının görüntüsü büyük ekrana geçer. Ayrıntı: [Arka Kamera Odağı](../../IdentifySample/Modules/CallScreen/CallScreen.md#arka-kamera-odağı-330) |

---

## Kopma Durumunda WebRTC

Görüşme sırasında ICE durumuna göre:

| ICE durumu | Ne olur | Kapanma kodu |
|---|---|---|
| `.disconnected` | 5 sn toparlanması beklenir. Bu sürede `.connected` olursa görüşme kesintisiz sürer. Olmazsa görüşme biter, `terminateCall("TURN_DISCONNECTED")` yayınlanır ve yeniden bağlanma akışı başlar. | 4140 `turnDisconnected` |
| `.failed` | Görüşme hemen biter, akış `.disconnected`'daki gibi sürer. | 4141 `turnFailed` |
| `.closed` | Loglanır. Sinyalsiz süren bir görüşmede medya hattı kapanırsa görüşme biter. | 4142 `turnClosed` |

5 saniye sabittir, ayarlanamaz. Bekleme yalnızca medya hattı içindir, sokete mesaj gönderilmez.
Kodlar: [WebSocket → Birleşik Kapanma Kodları](websocket.md#birleşik-kapanma-kodları--sdksocketclosecode-4100).

### Sinyal (WebSocket) koptuğunda

Medya hattı ayaktaysa soket kopması görüşmeyi hemen bitirmez. Görüşme
`IdentifyManager.shared.signallessCallGracePeriod` boyunca (varsayılan 10 sn) sinyalsiz sürer:

- SDK bu sürede soketi kendiliğinden bağlamaz; bu arada istenen bir yeniden bağlanma da görüşmeyi
  bitirir.
- Süre dolunca görüşme cihazda biter ve "Bağlantı Koptu" ekranı açılır. Sinyal yokken panelin
  `endCall` / `terminateCall` komutları cihaza ulaşmaz, görüşme bu yüzden süresiz bırakılmaz.
- Bu sürede ICE de koparsa görüşme yukarıdaki tabloya göre biter.
- Sunucu soketi normal kodla kapatırsa (4110, 4111, 4112) bu süre başlamaz. Görüşme medya hattı
  kapanana kadar sinyalsiz sürer, sonra yukarıdaki tabloya göre biter.

Görüşme dışındaki kopmada (ya da medya hattı zaten düşmüşse) medya oturumu tamamen kapanır, soket
kapatılır ve "Bağlantı Koptu" ekranı açılır. Sunucunun normal kapanışı (4110, 4111, 4112) görüşme
dışında yalnızca loglanır. Kopma sayısı sınırı ve otomatik yeniden bağlanma
`SDKAttemptLimits.shared.connection` (`SDKConnectionPolicy`) ile ayarlanır.

### Neden sessiz yeniden abonelik yok?

Bir dönem kopma anında görüşme askıya alınıyor, SDK da arka planda odaya kendiliğinden yeniden
abone oluyordu. Sunucu ve panel bunu desteklemediği için bu yapı kaldırıldı:

- Sunucu askıdaki oturumu hâlâ açık saydığından sessiz yeniden abonelik `subRejected`
  ("Oda dolu") ile reddediliyordu.
- Panel çağrı oturumunu kapatmıyor, süre saymaya devam ediyordu.
- Cihaz testinde ident statüsü bu yüzden `Reddedildi` oldu.

Yukarıdaki iki bekleme süresinde SDK odaya yeniden abone olmaz.
Görüşme bittiğinde kullanıcı "Bağlantı Koptu" ekranından yeniden bağlanır ve prosedür baştan
işler. Yeniden bağlanırken sırasıyla `getIdentStatus`, `subscribe` ve `stepChanged` gönderilir.
`imOnline` sunucu `newSub` ile isteyince gider. Kayıtlı statü `positive` ise (id -3, -4 ve -5
hariç) oturum biter ve başarılı ThankYou ekranı açılır. Diğer durumların hepsinde müşteri bekleme
odasına döner, temsilci onu yeniden arayabilir. Olumsuz karar için panel `terminateCall`
göndermelidir.

Kullanıcı yeniden bağlandığında (`reconnectToSocket`) akışta görüntülü görüşme (bekleme odası)
modülü varsa WebRTC oturumu yeniden kurulur (video, ses ve data channel) ve `sendStep()` ile hangi
adımda olduğu bildirilir. Kopmanın hangi modülde olduğu fark etmez. İşaret dili sorusu cevap
beklerken ikisi de yapılmaz.
Ayrıntı: [WebSocket → Bağlantı Kopması](websocket.md#bağlantı-kopması-ve-toparlanma).

---

## Sorun Giderme

- Görüşme hiç kurulmuyor: `turnKey` doğru mu? `encrypted_turn_credential` modunda `turnKey` boşsa
  loglarda `turn key gerekli` görürsünüz ([Loglama](logging.md)).
- Ses ya da görüntü tek yönlü: çoğunlukla TURN kimliği geçersizdir, yani backend'in modu ile
  sizin ayarınız uyuşmuyordur. `webrtc` kategorisindeki loglara bakın.
- Simülatör: kamera olmadığı için görüşmeyi uçtan uca ancak gerçek cihazda test edebilirsiniz.
