# Loglama — SDKLog Mantığı

SDK'daki bütün loglar `SDKLog` üzerinden yazılır. Bu rehber logların nereye gittiğini, satırlara
eklenen önem derecesi ve kategori etiketlerini, sunucuya log gönderimini ve hassas verinin
loglardan nasıl ayıklandığını anlatır.

← [README'ye dön](../../README.md) · İlgili: [Event Sistemi](events.md) · [Sunucu & API](server-api.md)

---

## İki Kanal: Konsol ve Online

Bir log satırı iki yere gidebilir:

- Konsol: Xcode çıktısı. Geliştirirken buradan okursunuz.
- Online kuyruk: loglar biriktirilip `RoomResponse.data?.sdk_log_api_url` adresine gönderilir. Sahada
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

### `logHandler`

`IdentifyManager.shared.logHandler` her log satırını uygulamanıza da verir, ör. logları kendi
ekranınızda göstermek için. Seviyeden bağımsız çalışır (`.noLog` dahil) ve satırı
`IdentifyLogEntry` olarak (`date`, `message`, `severity`, `category`, `isSilent`) logu üreten
thread'de verir. Arayüzü güncelleyecekseniz ana thread'e geçin.

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

`lifecycle` hazır akışta uygulamanın hangi modülde arka plana alındığını, uygulamanın kapatılmasını,
oturumun kapanışını ve akış sonucunu kaydeder. "Kullanıcı NFC okurken uygulamayı arka plana aldı"
gibi durumları bu kategoriden görürsünüz. Ön plana dönüş ve arka planda geçen süre `general`
kategorisindedir.

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
| Log gönderiminin kendi hata satırları | Gönderim katmanına hiç girmez, aşağıya bakın |

`.onlineSilent`'te de `logOnlineSecretKey` boşsa satır kuyruğa girmez, ama konsola uyarı da
basılmaz: loglar sessizce düşer. Eksik anahtar `lastKeyReport`'ta görünür: durum `.missing`
(SAĞLANMADI), `hasProblem` `true`. `verifyKeysOnServer()` bu durumda sunucuya sormaz, aynı raporu
döndürür.

Kuyruğa giren satır hemen gitmez. Gönderim her yeni satırdan sonra 0,25 sn bekler,
`flushLogsNow()` da aynı beklemeyle çalışır. `closeSDK` kuyruğu bu süre dolmadan kapattığı için
kapanıştan hemen önce yazılan satırlar ("Oturum sonlandı", akış sonunda ve `quitSDK`'de
"Akış sonucu") o oturum sürerken gitmeyebilir. Gitmeyen satırlar cihazda saklanır ve aynı cihazda
sonraki oturum açılınca gönderilir. Her satır kendi oturum kimliğini taşıdığı için kendi oturumunun
kaydına düşer. 30 dakikadan eski satırlar gönderilmeden silinir.

### Log gönderiminin kendi hataları

Log gönderimi hata verdiğinde bu hatanın satırı da online kuyruğa girerse yeni bir gönderim
denemesi başlar, o da hata verirse döngü hiç bitmez. Bu yüzden gönderimin kendi hataları yalnız
konsola yazılır, kuyruğa girmez. Satırın biçimi diğer loglarla aynıdır.

```
[identify] ⚠️ WARN  · NETWORK  · 2026-08-11 02:49:41 › Log gönderimi tamamlanamadı. Sunucuya ulaşılamadı. Neden: …
```

---

## Hassas Veri Redaksiyonu

Mesajın içinde uzun bir Base64 bloğu (görsel ya da video verisi) varsa log altyapısı onu
otomatik kısaltır. Böylece kimlik fotoğrafı ya da selfie online loglara taşınmaz; logda yalnızca
verinin gönderildiği ve boyutu kalır.

Kişisel veriler de maskelenir: TCKN `‹tckn›`, MRZ satırı `‹mrz›`, tarih `‹tarih›`, 6 haneli sayı
`‹6 hane›`, belge numarası `‹belge no›`, `token=` değeri `‹gizli›` olarak yazılır. Konsol, online
kuyruk ve `logHandler` aynı maskeli metni alır. `getSocketLogs()` dökümünde bu maskeleme yoktur,
yalnız uzun Base64 blokları kısaltılır.

---

## Soket Trafiği Logları

Giden soket mesajları `socket`, gelenler `general` kategorisiyle yazılır. Satırda yön ➡️ (giden) ve
⬅️ (gelen) ile görünür. Yönü `incoming`/`outgoing` olarak tutan kayıt
`IdentifyManager.shared.getSocketLogs()`'tadır. Bu dökümde SDP ve ICE aday mesajları IP
adresleriyle tam metin durur. Döküm uygulama süreci boyunca birikir, oturum kapanınca temizlenmez.
Sessiz gönderilen mesajlar yalnız konsola basılır; online kuyruğa, `logHandler`'a ve
`getSocketLogs()`'a girmez. Bir akış sorununu incelerken
çoğunlukla en çok işe yarayan kayıtlar bunlardır: agent'ın ne gönderdiğini ve SDK'nın ne cevap
verdiğini sırasıyla görürsünüz.

---

## Modül Tanı Raporu — `[SONUÇ]` (3.3.0)

Her modül ekranı kapanırken loga tek bir blok yazar. Blok `[SONUÇ] <modül>: <sonuç>`
satırıyla başlar. Sonuç `geçti`, `başarısız`, `atlandı` ya da `yarıda kaldı` olur. Kullanıcı
ekrandan geri dönerse ya da uygulama kapanırsa `yarıda kaldı` yazılır. `geçti` dışındaki
sonuçlar `warning`, `geçti` ise `info` seviyesiyle gider.

Rapor ekran ziyareti başına bir kez yazılır, aynı ziyaretteki yeniden denemeler aynı rapora
eklenir. Ayrıca bir şey açmanız gerekmez.

| Madde | İçerik |
|---|---|
| 1. Süre | Ekranda geçen süre ve ilk uygun karenin geldiği an |
| 2. Cihaz | Model, iOS sürümü, uygulama sürümü |
| 3. Yol | Modülün çalıştığı yol (ör. ARKit, standart) |
| 4. İzin | Modülün istediği izinler ve durumları. İzin istemeyen modülde `gerekmiyor` |
| 5. Kesinti | Arka plana geçiş, ekranın yeniden açılması gibi kesintiler |
| 6. Mesajlar | Ekranda çıkan yönergeler ve ne kadar kaldıkları |
| 7. Engeller | Aşılamayan koşullar ve ölçüleri |
| 8. Tutma | Kararlı tutmanın kaç kez başladığı ve bozulduğu |
| 9. Gevşetme | Devreye giren yedek kurallar |
| 10. Sunucu | Sunucudan dönen sonuçlar |
| 11. Gösterilen hata | Kullanıcıya gösterilen hata metinleri |
| 12. Modül | Modülün kendi ölçüleri (aşağıdaki tablo) |

| Modül | 12. maddede |
|---|---|
| Selfie | Kare koşulu sayıları, yüz bulunamadı, çoklu yüz, telefonun yan tutulması, sunucu sonucu |
| Selfie + canlılık | Son kare (oval, uzaklık, merkez sapması, eğim), ısınma kare sayısı, büyük ovale geçiş |
| Canlılık | Her adımın sonucu ve süresi, takıldığı adım, adımın en yüksek ölçüsü ve eşiği, ARKit yüz takibi kaybı |
| Kimlik | Yüz başına tarama sayısı, son tarama, kare ölçüleri (netlik, parlama, titreme, MRZ okunan kare), eksik alan, OCR hatası, sunucu sonucu |
| Kimlik OVD | Adım süreleri, belge türü, takıldığı adım, hologram en yüksek ölçüsü ve eşikleri |
| NFC | Okuma başladı mı, her deneme (PACE/BAC, aşama, okunan gruplar, hata, sistem kodu), pasif doğrulama, anahtar düzeltme ekranı |
| Okuma testi | Kayıt süresi ve sınırı, mikrofon engeli, okuma eşleşmesi (skor, eşik, metinler), sunucu sonucu |
| Konuşma | Dinleme sayısı, son eşleşme (beklenen ve tanınan metin) |
| İmza | Çizim ve temizleme sayısı, imzanın boş olup olmadığı, sunucu sonucu |
| Adres onayı | Belge türü ve boyutu, PDF okunamadı, PDF boyut sınırı, eksik alan, sunucu sonucu |
| İşaret dili | Tercih (talep edildi / edilmedi) |
| Görüntülü görüşme | İlk çağrı ve ilk bağlantı süresi, son durum, ağ kalitesi sayıları, kopma sayısı ve son kopma nedeni, yeniden bağlanma, cevapsız çağrı, kapanış nedeni, kamera ve ARKit yeniden başlatma |

Örnek:

```
[SONUÇ] İşaret dili: geçti
1. Süre: 4.2 sn, ilk uygun kare: hiç gelmedi
...
11. Gösterilen hata: yok
12. Modül:
   - işaret dili: talep edildi
```

Görüşmedeki ağ kalitesini SDK uzak görüntünün genişliğinden çıkarır (320 px ve altı `bad`,
360-479 px `medium`, 480 px ve üstü `good`) ve panele bildirir. NFC denemeleri oturum başında
sıfırlanır; aynı oturumda NFC ekranına ikinci kez gelinirse önceki denemeler de rapora girer.

---

## Log mu Event mi?

- Log serbest metindir ve geliştirici içindir. Sorun ayıklarken okunur.
- Event (`SDKEvent`) yapılandırılmış bir olaydır ve analitik ile izleme için kullanılır.

"Kullanıcı selfie adımında kaç kez başarısız oldu?" gibi soruların cevabı loglarda değil,
[Event Sistemi](events.md)'nde bulunur.
