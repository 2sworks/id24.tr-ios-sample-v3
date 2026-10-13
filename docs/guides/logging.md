# Loglama — SDKLog Mantığı

SDK'daki bütün loglar `SDKLog` üzerinden yazılır. Bu rehber logların nereye gittiğini, satırlara
eklenen önem derecesi ve kategori etiketlerini, sunucuya log gönderimini ve hassas verinin
loglardan nasıl ayıklandığını anlatır.

← [README'ye dön](../../README.md) · İlgili: [Event Sistemi](events.md) · [Sunucu & API](server-api.md)

---

## İki Kanal: Konsol ve Online

Bir log satırı iki yere gidebilir:

- Konsol: Xcode çıktısı. Geliştirirken buradan okursunuz.
- Online kuyruk: loglar biriktirilip `RoomResponse.sdk_log_api_url` adresine gönderilir. Sahada
  yaşanan bir sorunu kullanıcının cihazına erişmeden incelemek için bunu kullanırsınız.

Hangi kanalın açık olacağını `setupSDK(logLevel:)` belirler:

| `SDKLogLevel` | Konsol | Online | Ne zaman |
|---|---|---|---|
| `.all` (varsayılan) | ✅ | ❌ | Geliştirme |
| `.online` | ✅ | ✅ | Debug sırasında canlı izleme |
| `.onlineSilent` | ❌ | ✅ | Canlı ortam. Kullanıcının cihazında konsol boş kalır, loglar yine size gelir |
| `.noLog` | ❌ | ❌ | Log istemiyorsanız |

Online gönderim `logOnlineSecretKey` olmadan çalışmaz.

```swift
IdentifyManager.shared.setupSDK(
    ...,
    logLevel: .onlineSilent,
    logOnlineSecretKey: "LOG-ANAHTARINIZ",
    ...
)
```

---

## Severity ve Kategori

Her satırın bir önem derecesi (severity) ve bir kategorisi vardır:

```swift
SDKLog.debug("frame alındı", .liveness)
SDKLog.info("oda kuruldu", .general)
SDKLog.warning("token süresi doldu, yenileniyor", .socket)
SDKLog.error("çip okunamadı", .nfc)
```

| Severity | Etiket | Konsol işareti |
|---|---|---|
| `.debug` | DEBUG | 🔍 |
| `.info` | INFO | ℹ️ |
| `.warning` | WARN | ⚠️ |
| `.error` | ERROR | 🔴 |

> Severity sadece bir etikettir, online gönderimi etkilemez. Neyin gönderileceğini satır
> değil kanal belirler (`SDKLogLevel`).

Kategori, online log kaydındaki `type` alanına yazılır ve panelde bu alana göre filtreleme
yaparsınız:

`general` · `socket` · `nfc` · `ocr` · `webrtc` · `network` · `liveness` · `offer` · `lifecycle`

`lifecycle` uygulamanın ön plana ve arka plana geçişlerini kaydeder. "Kullanıcı NFC okurken
uygulamayı arka plana aldı" gibi durumları bu kategoriden görürsünüz.

---

## Silent Bayrağı — 🔕

Bazı satırları geliştirirken görmek istersiniz ama sunucuya gitmelerine gerek yoktur: giden
isteklerin gövdeleri ya da saniyede birkaç kez üretilen ölçümler gibi. Bunlar için satıra
`silent` verilir:

```swift
SDKLog.debug("liveness skoru: \(score)", .liveness, silent: true)
```

`silent: true` olan satır konsolda görünür, online kuyruğa girmez. `.online` seviyesinde konsola
`🔕` ekiyle basılır. `.onlineSilent` seviyesinde konsol zaten kapalı olduğundan satır hiçbir
yere yazılmaz.

İki ayar birbirinden bağımsızdır. `SDKLogLevel` oturum boyunca hangi kanalların açık olduğunu
belirler; `silent` ise tek bir satırı online kuyruğun dışında tutar.

Seviye `.online` olsa bile şu durumlarda satır kuyruğa girmez:

| Durum | Sonuç |
|---|---|
| `logOnlineSecretKey` boş | Konsola "Online log devre dışı: secKey boş" uyarısı basılır |
| Oturum kapandı (`closeSDK` sonrasında gelen loglar) | Konsola basılır. Kuyruk kapalı olduğu için gönderilmez |
| `SDKLog.console(...)` ile yazılan satırlar | Gönderim katmanına hiç girmez, aşağıya bakın |

### `SDKLog.console` — yalnızca konsol

Log gönderimi hata verdiğinde bu hatanın satırı da online kuyruğa girerse yeni bir gönderim
denemesi başlar, o da hata verirse döngü hiç bitmez. Bu yüzden gönderimin kendi hataları
`SDKLog.console(severity, category, mesaj)` ile yazılır. Biçimi ve maskeleme kuralları diğer
loglarla aynıdır; farkı kuyruğa hiç uğramamasıdır.

```
[identify] ⚠️ WARN  · NETWORK  · 2026-08-11 02:49:41 › Log gönderimi tamamlanamadı. Sunucuya ulaşılamadı. Neden: …
```

---

## Hassas Veri Redaksiyonu

Mesajın içinde uzun bir Base64 bloğu (görsel ya da video verisi) varsa log altyapısı onu
otomatik kısaltır. Böylece kimlik fotoğrafı ya da selfie online loglara taşınmaz; logda yalnızca
verinin gönderildiği ve boyutu kalır.

---

## Soket Trafiği Logları

Gelen ve giden her soket mesajı `socket` kategorisiyle, yönü (`incoming` / `outgoing`)
işaretlenerek loglanır. Bir akış sorununu incelerken çoğunlukla en çok işe yarayan kayıtlar
bunlardır: agent'ın ne gönderdiğini ve SDK'nın ne cevap verdiğini sırasıyla görürsünüz.

---

## Log mu Event mi?

- Log serbest metindir ve geliştirici içindir. Sorun ayıklarken okunur.
- Event (`SDKEvent`) yapılandırılmış bir olaydır ve analitik ile izleme için kullanılır.

"Kullanıcı selfie adımında kaç kez başarısız oldu?" gibi soruların cevabı loglarda değil,
[Event Sistemi](events.md)'nde bulunur.
