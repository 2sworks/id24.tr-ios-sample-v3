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
alınır (servisin anahtarı `RoomResponse.ws_secret_key`). Kimliklerin nasıl kullanılacağını
backend'den gelen iki bayrak belirler.

### 1. Düz kimlik (varsayılan)
`encrypted_turn_credential ≠ "1"` ise servisin döndüğü `username` ve `credential` olduğu gibi
kullanılır. Bu modda `turnKey` kullanılmaz.

### 2. Şifreli kimlik — `encrypted_turn_credential == "1"`
Servis kimlikleri AES-256-CBC ile şifreli gönderir, SDK da bunları sizin `turnKey`'inizle çözer.

> ⚠️ Bu modda `turnKey` boşsa görüşme kurulmaz ve konsolda `⚠️ turn key gerekli` yazar.

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
| `bigCustomerCam` | `setupSDK` parametresi | Müşterinin kamerası büyük pencerede gösterilir |
| `agent_view_scale` | `RoomResponse` | Agent görüntüsünün ölçeği (dikey gösterim dahil) |
| `hide_call_answer_screen` | `RoomResponse` | Çağrı cevaplama ekranı atlanır |
| `signLangSupport` | `setupSDK` parametresi | Görüşmeden önce işaret dili tercihi sorulur ([SignLang](../../IdentifySample/Modules/SignLang/SignLang.md)) |

---

## Kopma Durumunda WebRTC

Görüşme sırasında ICE bağlantısı `.disconnected` ya da `.failed` olursa görüşme hemen sonlandırılır:
`terminateCall("TURN_DISCONNECTED")` yayınlanır ve LostConnection/yeniden bağlanma akışı başlar.
`.closed` durumu yalnızca loglanır. Üç durumun da birleşik kapanma kodu var: 4140
`turnDisconnected` · 4141 `turnFailed` · 4142 `turnClosed`
([WebSocket → Birleşik Kapanma Kodları](websocket.md#birleşik-kapanma-kodları--sdksocketclosecode-4100)).

### Sinyal (WebSocket) koptuğunda

Görüşme sürüyor olsun ya da olmasın davranış aynıdır. Medya oturumu tamamen kapanır (peer
connection kapanır, kamera ve mikrofon durur), soket kapatılır ve kullanıcı "Bağlantı Koptu"
ekranını görür.

### Neden toparlanma penceresi YOK?

Bir süre hem ICE hem WebSocket kopmaları için bir toparlanma penceresi vardı. Kopma anında görüşme
askıya alınıyor, medya susturuluyor ama peer connection kapatılmıyor, SDK da arka planda sessizce
yeniden bağlanmaya çalışıyordu. Sunucu ve panel bunu desteklemediği için bu yapı kaldırıldı:

- Sunucu askıdaki oturumu hâlâ açık saydığından sessiz yeniden abonelik `subRejected`
  ("Oda dolu") ile reddediliyordu.
- Panel çağrı oturumunu kapatmıyor, süre saymaya devam ediyordu.
- Cihaz testinde ident statüsü bu yüzden `Reddedildi` oldu.

Şimdi tek bir davranış var: bağlantı kopunca her şey kapatılır, "Bağlantı Koptu" ekranı açılır,
kullanıcı yeniden bağlanır ve prosedür baştan işler. Yeniden bağlanırken `imOnline`,
`getIdentStatus`, `subscribe` ve `stepChanged` gönderilir. Panel henüz karar vermediyse (statü id
`< 0`) müşteri bekleme odasına döner ve temsilci onu yeniden arayabilir. Karar verildiyse başarılı
ya da başarısız ThankYou ekranı açılır.

Kullanıcı yeniden bağlandığında (`reconnectToSocket`) WebRTC oturumu yalnızca kullanıcı görüşme
ekranındaysa yeniden kurulur (video, ses ve data channel) ve `sendStep()` ile hangi adımda olduğu
bildirilir. Kopma başka bir modüldeyken olduysa WebRTC'ye dokunulmaz.
Ayrıntı: [WebSocket → Bağlantı Kopması](websocket.md#bağlantı-kopması-ve-toparlanma).

---

## Sorun Giderme

- Görüşme hiç kurulmuyor: `turnKey` doğru mu? `encrypted_turn_credential` modunda `turnKey` boşsa
  loglarda `turn key gerekli` görürsünüz ([Loglama](logging.md)).
- Ses ya da görüntü tek yönlü: çoğunlukla TURN kimliği geçersizdir, yani backend'in modu ile
  sizin ayarınız uyuşmuyordur. `webrtc` kategorisindeki loglara bakın.
- Simülatör: kamera olmadığı için görüşmeyi uçtan uca ancak gerçek cihazda test edebilirsiniz.
