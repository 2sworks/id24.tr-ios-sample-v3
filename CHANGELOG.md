# Sürüm Geçmişi

Bu dosya, **IdentifySDK** ve **Sample App** sürüm notlarını içerir.
Güncel kurulum ve dökümantasyon için [README](README.md)'ye dönebilirsiniz.

---

## IdentifySDK

### Yayınlanmamış (v3)

Sürüm numarası yayın anında verilir. v3, SDK'yı "başsız" (headless) bir çekirdek + hazır
SwiftUI ekranları olan bir yapıya taşıyan kapsamlı bir revizyondur.

**Yeni**
- **DefaultUI** — tüm modül ekranları SDK'nın içine taşındı. Her modül için drop-in
  `View` + `ViewModel` çifti; host uygulama isterse yalnızca temayı ezer, isterse kendi
  ekranını yazıp aynı ViewModel'i kullanır.
- **Pasaport desteği** — TD3 MRZ ayrıştırma, tek sayfa yükleme (`doc_type=passport`),
  yandan çekim yönlendirmesi, MRZ doğrulamalı oryantasyon düzeltmesi.
- **IdentityScanner** — kimliği gerçek zamanlı yakalayan tarayıcı katmanı; düşük ışık ve
  düşük kontrast desteği, kare seçimi (en hemfikir dörtgen).
- **Sesli okuma (TTS)** — modül bazında `SDKSpeechConfig`; native `AVSpeech` ya da kendi
  ses paketiniz (`.customAudio`).
- **Kısa videoda sesli doğrulama** — kullanıcının okuduğu metin sunucuda çözümlenip
  eşleştirilir (`speech_expected_sentence`, benzerlik eşiği).
- **Birleşik `SDKLog` facade'i** — severity + kategori etiketleri, Base64 redaksiyonu,
  `silent` bayrağı; ayrıntı için [Loglama rehberi](docs/guides/logging.md).
- **`SDKEvent` katmanı** — modül/oturum olaylarının tek akışta yayınlanması.
- **`SDKKeyDiagnostics`** — anahtarların (log, TURN, WS) sunucu yanıtına dayalı doğrulama
  raporu; `sdk_logs` 401 gibi sessiz hataları başlangıçta yakalar.
- **Global bağlantı kopması katmanı** — kullanıcı hangi modülde olursa olsun devreye giren
  "Bağlantı Koptu" overlay'i + kaldığı yerden devam.
- **Çift yönlü PING/PONG heartbeat** — varsayılan açık; oturum yalnızca PONG gelmediğinde
  düşer (kuyruk zaman aşımı kaldırıldı).

**Değişti**
- **Kısa videoda sesli doğrulamayı artık metin açar:** `video_record_read_text` (yoksa
  `speech_expected_sentence`) doluysa doğrulama açılır ve metin ekranda gösterilir; boşsa
  kapalıdır. `video_record_speech` bayrağı belirleyici değildir — panel metni doldurduğu
  hâlde bayrağı `0`/eksik gönderdiğinde metin ekranda hiç görünmüyordu.
- **`video_record_duration` milisaniye kabul edilir** (6000 → 6 sn); saniye gönderen eski
  projeler için birim değere göre ayırt edilir, sonuç 3–120 sn aralığına sıkıştırılır.
- **Askı / toparlanma penceresi kaldırıldı.** Görüşme sırasında sinyal ya da ICE koparsa
  toparlanma beklenmez: görüşme biter, bağlantılar kapatılır, "Bağlantı Koptu" ekranı
  çıkar. Bekleme yapısı sunucu askıdaki oturumu canlı saydığı için `subRejected`
  üretiyordu. `SDKCallScreenViewModel.isCallSuspended` ve
  `IdentifyManager.callSuspensionHandler` **kaldırıldı**.
- **Karşılaştırma sonucu tek kapıda toplandı** (`SDKComparisonGate`) — uyuşmazlıkta modül
  sessizce geçilmiyor; hak bitince atlama/`notCompleted` kuralı tek yerden işletiliyor.
- **Birleşik socket kapanma kodları 4100+** — 4105 arka plan zaman aşımı, 4106 heartbeat
  zaman aşımı dahil.
- **Bağlantı logları tekrarsız** — ağ durumu yalnızca değişimde yazılır; "İnternet erişimi
  geri geldi" satırı yalnızca gerçekten kopma bildirilmişken basılır.
- **Log gönderim hatası** ham `print` yerine `SDKLog.console` ile diğer loglarla aynı
  biçimde basılır; bu satırlar online kuyruğa girmez (sonsuz döngü koruması).

**Düzeltildi**
- OCR ön yüzde doğum ↔ geçerlilik tarihi karışması (kronolojik atama) ve "no-data" durumu.
- Selfie onaylanmadan panele yükleniyordu (ITR-2015).
- OVD hata ekranı açıkken çekim döngüsü dönmeye devam ediyordu (ITR-1881).
- Buton sesi ile yönerge sesi ayrımı, OVD seçim ekranında TTS (ITR-1903).
- Canlılık video kaydında ARKit kare havuzu tükenince yaşanan donma.
- Kamera, bekleme odasında açılıyordu; capture artık yalnızca çağrı kabul edilince başlar.

### 2.5.9
- Gelen aramada **sistem zil sesi ve titreşim**; sessiz modda titreşim desteklenir.
- Bekleme ekranındaki PING sayacı görüşmeyi kesiyordu; sezgisel kaldırıldı.
- Çalma zaman aşımı (4108) ve 4xxx kapanış kodları eklendi.
- Sinyal kopunca WebRTC oturumu tamamen kapatılıyor, medya susturuluyor.
- Reconnect zaman aşımı 10 sn'ye çekildi; başarısız deneme host'a bildiriliyor.
- **Görüşme sağlık raporu** eklendi (socket kopma sayısı, ICE kesinti/başarısızlık/
  toparlanma, ağ geçişleri, en uzun sunucu sessizliği).
- Canlılıkla selfie: iki fazlı oval (küçük→büyük), çekim anı flaşı, mesh gizleme, oval dış
  karartma koyulaştırıldı.
- Görüşme ekranında canlılık kaydı popup'ı düzeltildi.
- Minimum iOS sürümü 15'e güncellendi.

### 2.5.8
- **Birleşik socket kapanma kodları (4100+)** ve arka plan oturum zaman aşımı eklendi.
- Socket kapanma loglarına kategori bazlı belirteçler eklendi; yalnızca 41xx kodları
  raporlanıyor (RFC 1000'li referanslar kaldırıldı).
- Bağlantı logları herkesin anlayacağı dile çevrildi.
- Reconnect akışında birden çok düzeltme (`sendStep` döngüsü, yeniden bağlanma sonrası
  takılmalar).
- `hideCallAnswerScreen` mantık hatası giderildi.
- Kimlikte doğum tarihi ↔ geçerlilik tarihi karışması düzeltildi.

### 2.5.7
- Görüşmede yerel/gelen video akışı düzeltmeleri.
- `queueStats` gecikmesi giderildi.
- `selfieWithLiveness` modülündeki debug etiketi kaldırıldı.

### 2.5.6
- **`selfieWithLiveness` modülü** eklendi: doğrulama akışı, `withLiveness` parametresi ve
  karşılaştırma için yeniden deneme hakkı.
- Gözlüklü kullanıcıların canlılıkla selfie'yi geçememesi sorunu giderildi.
- Görüşme içi canlılık için eşik değerleri ve kamera alanı güncellendi.
- `currentVersion` dinamik hale getirildi.
- Xcode Cloud için workspace ve CI script eklendi.
- WebRTC tarafında hata düzeltmesi.

### 2.5.5
- MRZ OCR iyileştirmeleri yapıldı.
- NFC okuma anahtarı hatası giderildi.
- NFC alanlarının sunucuya gönderimi güncellendi.
- Log ve genel hata düzeltmeleri.

### 2.5.4
- `iceTransportPolicy` relay'den `.all`'a çekildi.
- `sdkLogApiUrl` hatası giderildi.
- NFC iyileştirmesi yapıldı; algılama seviyeleri değiştirilip stabilizasyon sağlandı.
- `SendIdentStatusInfo` ile görüntülü görüşme kopması esnasında sunucudan gönderilen verinin tanımlanması sağlandı.
- `uploadAddressInfo`'da sıkıştırma ayarları güncellendi.
- `socket_auth` ile token'lı bağlantı sürece dahil edildi; artık müşteri ile agent arasında token ile görüntülü görüşme sağlanabiliyor.
- `liveStreamModuleController` ismi `callWaitModuleController` olarak değiştirildi.
- Socket mesajında gönderilen "Live Stream" ismi "Call Wait Screen" ile değiştirildi.

### 2.5.3
- SDK log API URL eklendi.

### 2.5.2
- Kimlik OCR — Ad Soyad alanında özel karakterlerin algılanması engellendi.

### 2.5.1
- TURN şifrelemeyi destekleme bilgisi backend'e gönderildi.
- `enableDebugPrint` ile print loglarını açıp kapatabilme opsiyonu eklendi.

### 2.5.0
- OCR kimlik ön yüz ve arka yüz iyileştirmeleri yapıldı.
- TURN için `encryptedTurnCredential` ve `shortTermUsage` parametreleri eklendi.
- `terminateCall` fonksiyonuna `terminateReason` ve `statusSummaryType` eklendi.
- Response messages düzenlemeleri yapıldı.
- SDK online log iyileştirmeleri yapıldı.

### 2.3.15
- Selfie modülünde sadece tek yüz algılandığında ilerlenmesi sağlandı.

### 2.3.14
- `disableEndCallButton` socket aksiyonu eklendi.
- `enableAutoRotateOCR` SDK parametresi eklendi.
- `active_comparison_result_skip_module` eklendi.

### 2.3.9
- `appVersion`, `appBuild`, `sdkVersion` bilgilerinin gönderilmesi sağlandı.
- `agentViewScale` desteği eklendi.
- `ident_id` trim eklendi.
- `doc_type` desteği eklendi.

### 2.3.1
- Sunucudan maksimum dosya yükleme boyutunu alma eklendi.

### 2.3.0
- Adres modülüne PDF yükleme seçeneği eklendi.
- Canlılık modülüne ekran kaydı desteği eklendi.

### 2.2.0
- `IdentifyTrackingListener` tarafına `HTTP_RESPONSE_TRACKING_EVENT` ve `HTTP_REQUEST_TRACKING_EVENT` eklendi.
- TURN sunucu için short-term auth servisi eklendi.

### 2.1.0
- SDK tarafına yeni bir `IdentifyTrackingListener` eklendi; örnek kullanım için `SDKBaseViewController` dosyasını inceleyebilirsiniz.

### 2.0.6
- Network sınıfında SSL pinning için ekstra log eklendi.

### 2.0.5
- Yeni dil desteği eklendi.

### 2.0.4
- `closeSDK` metodu güncellendi.
- `endReconnectSubscribe` eklendi.

### 2.0.3
> Xcode 15.3 sürümü ayrıca eklenmiştir, dökümantasyonu mutlaka kontrol edin.
- Network sınıfı güncellendi.
- SSL pinning desteği eklendi.

### 2.0.2
- WS credential web servisten gelecek hale getirildi, dökümanlar güncellendi.

### 2.0.1
- Active result desteği eklendi.
- OCR alanında güncellemeler yapıldı.

### 1.9.8
- Bağlantı hızına bağlı olarak kamera güncellemesi düzenlendi.
- Prepare modülünün panele attığı istek eklendi.

### 1.9.7
- Prepare modülü eklendi.
- `forceQuitSDK` eklendi.
- Socket disconnect olunca socket listener için metot eklendi (`.connectionErr`).
- OCR tarafında güncelleme yapıldı.

---

## Sample App

### Yayınlanmamış (v3 · build 23)

> Not: v3 ile birlikte örnek uygulama sıfırdan numaralandı (`CURRENT_PROJECT_VERSION` 23);
> aşağıdaki "Build 178" ve öncesi eski numaralandırmaya aittir.

- Örnek uygulama **SDK tüketen bir geliştirici rehberine** dönüştürüldü: her ekran için
  Preview + View + ViewModel, SDK yeteneklerinin showcase'i.
- Her modül için entegrasyon rehberi (`NewTest/Modules/<Module>/<Module>.md`) ve
  `docs/guides/` altında 10 konu rehberi (soket, TURN/WebRTC, loglama, event, sunucu &
  API, yerelleştirme, tema…).
- Tek referans doküman: kökte `FULL-INTERGATION.md`.
- Event örgüsü ekranı + React Native / Flutter köprü iskeletleri (`docs/integration`).
- Sesli okuma (TTS) showcase'i ve giriş ekranında TTS anahtarı.
- Ağ trafiğini incelemek için netfox entegrasyonu.

### Build 178
- NFC'de iyileştirmeler yapıldı.
- Adres modülündeki görselin sunucuya gönderilirken kalitesinin düşmesine sebep olan ayarlar yükseltildi.
- Bağlantı koptuğunda durum seçilmediyse bekleme odasına yönlendirme geliştirmesi yapıldı ("-3" durum kodu ile).
- `liveStreamModuleController` ismi `callWaitModuleController` olarak değiştirildi.
- WebSocket secret key geliştirmesi yapıldı; isteğe göre görüntülü görüşme token ile peer-to-peer güvenlik seviyesine çıkarıldı.
- WS token generate hatası giderildi.

### Build 166
- OVD modülünde iyileştirmeler yapıldı.

### Build 165
- Adres fotoğraflarının daha kaliteli gönderilmesi sağlandı.

### Build 162
- `enableDebugPrint` eklendi.

### Build 160
- TURN için şifreli kullanım opsiyonu eklendi.
- Görüntülü görüşme sonlandırma senaryoları için sebep ve durum bilgileri eklendi.
- Sunucudan gelen hata mesajlarının gösteriminde düzenlemeler yapıldı.
- Kimlik çekim ekranındaki flaş çalışmama hatası düzeltildi.
- OVD (beta) ekranı eklendi.

### Build 141
- Kimlik çekimlerinde otomatik yön düzeltme seçeneği eklendi.
- Aktif karşılaştırmada modül atlama kontrolü eklendi.
- Agent durum seçtiğinde arama butonunun devre dışı bırakılması sağlandı.
- OCR, NFC ve Selfie adımlarında tekrar deneme sayısı kontrolleri eklendi.

### Build 126
- Kimlik çekimlerinde yeni cihazlardaki yakınlaştırma modu uyumu sağlandı.
- İşaret dili seçimi ekranında görüntülü görüşme kuyruğuna düşmemesi sağlandı.
- Agent görüntüsünün dikey ölçüde gösterilebilmesi sağlandı.
- Süresi geçmiş ident için hata mesajı gösterimi eklendi.
- İlgili ekranlara kamera, mikrofon ve konuşma izni kontrolleri eklendi.
- "Tekrar Bağlan" butonuna internet bağlantısı kontrolü eklendi.

### Build 107
- SDK'yı işlemler tamamlanmadan kapatabilme özelliği eklendi.
- Müşterinin çağrıyı sonlandırabilmesi eklendi.

### Build 106
- Sunucudan maksimum dosya yükleme boyutunu alma eklendi.

### Build 103
- Canlılık modülünü kaydetme seçeneği eklendi.

### Build 101
- Adres modülüne PDF yükleme seçeneği eklendi.

### Build 100
- `IdentifyTrackingListener` kullanımı eklendi (yalnızca 2.1.0 ve üstü sürümler için geçerli).

### Build 97
- Yeni dil desteği eklendi.

### Build 89
- Yeni canlılık testi kodları eklendi.
- SSL pinning örnek sertifikası eklendi.
- Privacy info dosyası eklendi.

### Build 84
- Scanner ekranında kimliğin yatay olma zorunluluğu iptal edildi.
- Login ekranı yeni SDK kurulumuna göre düzenlendi.
- Login ekranında socket hata vermesi durumunda ekstra durum bildirimi eklendi.

### Build 80
- Scanner ekranında daha hızlı fotoğraf çekimi sağlandı.
- Active result için `NfcViewController`, `CardreaderViewController` ve `ThankYouViewController` güncellendi.
- Scanner için yatay fotoğraf çekilmesi zorunluluğu eklendi.
- Dil dosyaları güncellendi.

### Build 75
- Scanner ve onu çağıran ekranlar güncellendi.
- Prepare modülü için örnek ekran eklendi.
- Missed Call için yeni status eklendi.
- Teşekkür ekranı güncellendi.

### Build 73
- Prepare modülünün örnek tasarımı eklendi.
- `socketListener` tarafına `connectionErr` eklendi.
- Buton tiplerine loader eklendi.
- Socket bağlantısı kopması durumunda çıkan ekran güncellendi.
