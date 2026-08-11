# Loglama — SDKLog Mantığı

SDK'nın tek log giriş noktası `SDKLog` facade'idir. Bu rehber log seviyelerini (nereye yazılır),
severity/kategori etiketlerini, online log akışını ve hassas veri redaksiyonunu anlatır.

← [README'ye dön](../../README.md) · İlgili: [Event Sistemi](events.md) · [Sunucu & API](server-api.md)

---

## İki Kanal: Konsol ve Online

Her log satırı iki kanaldan birine ya da ikisine gidebilir:

- **Konsol** — Xcode çıktısı; geliştirme sırasında okursunuz.
- **Online kuyruk** — loglar toplanıp `RoomResponse.sdk_log_api_url` adresine gönderilir;
  sahadaki bir sorunu müşteri cihazına dokunmadan incelemenizi sağlar.

Hangi kanalın açık olduğunu `setupSDK(logLevel:)` belirler:

| `SDKLogLevel` | Konsol | Online | Ne zaman kullanın |
|---|---|---|---|
| `.all` (varsayılan) | ✅ | ❌ | Geliştirme |
| `.online` | ✅ | ✅ | Debug + canlı izleme |
| `.onlineSilent` | ❌ | ✅ | **Prod** — kullanıcı cihazında gürültüsüz, siz yine görürsünüz |
| `.noLog` | ❌ | ❌ | Log istemiyorum |

Online gönderim için `logOnlineSecretKey` parametresini de vermeniz gerekir.

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

Her log satırı bir **önem derecesi** ve bir **kategori** taşır:

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

> Severity yalnızca **etikettir** — online gönderimi etkilemez. Filtreleme kanal bazındadır
> (`SDKLogLevel`), satır bazında değildir.

Kategoriler, online payload'daki `type` alanına yazılır; panelde buna göre filtrelersiniz:

`general` · `socket` · `nfc` · `ocr` · `webrtc` · `network` · `liveness` · `offer` · `lifecycle`

(`lifecycle`, uygulamanın ön/arka plan geçişlerini izler — "kullanıcı NFC sırasında uygulamayı
arka plana attı" gibi durumları yakalamak için birebirdir.)

---

## Silent Bayrağı — 🔕

Bazı satırlar geliştirirken görülmeli ama sunucuya taşınmamalıdır (ör. giden istek
gövdeleri, saniyede birkaç kez üretilen ölçümler). Bunun için satır bazında `silent`:

```swift
SDKLog.debug("liveness skoru: \(score)", .liveness, silent: true)
```

`silent: true` = **konsolda görünür, online kuyruğa girmez.** `.online` seviyesinde satır
`🔕` ekiyle basılır ve orada durur; `.onlineSilent` seviyesinde konsol zaten kapalı olduğu
için satır tamamen düşer.

Yani iki eksen birbirinden bağımsızdır: `SDKLogLevel` hangi kanalların açık olduğunu
oturum boyunca belirler, `silent` ise tek bir satırın online kuyruğa girme hakkını alır.

**Online kanalı sessizce kapatan diğer durumlar** — seviye `.online` olsa bile satır
kuyruğa girmez:

| Durum | Sonuç |
|---|---|
| `logOnlineSecretKey` boş | Konsola "Online log devre dışı: secKey boş" uyarısı basılır |
| Oturum kapandı (`closeSDK` sonrası artçı loglar) | Konsola basılır, kuyruk kapalı olduğu için sessizce atlanır |
| `SDKLog.console(...)` ile yazılan satırlar | Taşıma katmanına hiç girmez — aşağıya bakın |

### `SDKLog.console` — yalnızca konsol

Log gönderiminin **kendi** hata satırı online kuyruğa girerse yeni bir gönderim hatası
doğurur ve sonsuz döngü kurar. Bu satırlar `SDKLog.console(severity, category, mesaj)`
ile yazılır: biçim diğer tüm loglarla birebir aynıdır (redaksiyon dahil), tek farkı
kuyruğa hiç uğramamasıdır.

```
[identify] ⚠️ WARN  · NETWORK  · 2026-08-11 02:49:41 › Log gönderimi tamamlanamadı. Sunucuya ulaşılamadı. Neden: …
```

---

## Hassas Veri Redaksiyonu

Log altyapısı, mesaj içindeki **uzun Base64 blokları** (görsel/video payload'ları) otomatik
kısaltır. Böylece online loglarda müşteri kimlik fotoğrafı ya da selfie verisi taşınmaz;
sadece payload'ın var olduğu ve boyutu izlenebilir kalır.

---

## Soket Trafiği Logları

Gelen/giden her soket mesajı `socket` kategorisiyle loglanır (`incoming` / `outgoing` yönü
işaretlenir). Bir akış sorununu incelerken genellikle en bilgilendirici kayıtlar bunlardır:
agent'ın ne gönderdiğini ve SDK'nın ne cevap verdiğini kronolojik görürsünüz.

---

## Log mu Event mi?

- **Log** = serbest metin, geliştirici için; sorun ayıklarken okunur.
- **Event** = yapılandırılmış olay (`SDKEvent`), analitik/izleme için; koda değil veriye bakılır.

"Kullanıcı selfie adımını kaç kere başarısız yaptı?" sorusunun cevabı loglarda değil,
[Event Sistemi](events.md)'ndedir.
