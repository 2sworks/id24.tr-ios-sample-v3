# Sürüm Geçmişi

Bu dosya, **IdentifySDK** ve **Sample App** sürüm notlarını içerir.
Güncel kurulum ve dökümantasyon için [README](README.md)'ye dönebilirsiniz.

---

## IdentifySDK

### 3.1.0 — Tema ve özelleştirme paketi

Tamamı eklemeli: hiçbir tema ayarı vermeyen projede ekranlar 3.0.0 ile birebir aynıdır.
Ayrıntı ve geçiş adımları: [3.1.0 Değişiklik Rehberi](docs/guides/migration-3.1.0.md).

**Yeni**
- **Buton görünümü** — `SDKTheme.shared.buttons`: köşe (`.capsule` / `.radius(x)`), yükseklik,
  padding, font, arka plan/metin rengi, kenarlık, gölge, disabled opaklığı, basılı ölçek,
  haptik; stil bazlı override (`buttons[.secondary]`). Kendi ekranlarınız için
  `SDKButtonShape.themed()`.
- **Başlık çubuğu tasarımları** — `navBar.preset`: `.classic` · `.centered` · `.minimal` ·
  `.prominent`; yükseklik, logo/ikon ölçüleri, ilerleme çubuğu ve ayırıcı token'ları.
- **Rol renkleri** — `SDKAdaptiveColor` (light/dark ayrı) ile 18 rol: `pageBackground`,
  `moduleBackground`, `surface`, `title`, `subtitle`, `border`, `header*`, `progress*`,
  `selectedItem*`, `unselectedItem*`. Ayrıca `colors.accentWarning`.
- **Bileşen görünüm kapları** — `selection`, `alerts`, `banners`, `fields`, `sheets`,
  `capture`, `controls`, `call`, `motion`.
- **Tek sözlükle tema** — `SDKTheme.shared.apply(_:)`, `apply(json:)`,
  `applyTheme(named:in:)`, `resetAppearance()`; tanınmayan anahtarların listesini döndürür.
- **React Native / Flutter `setTheme`** — tema JS/Dart tarafından uygulanır, renk-logo
  denemesi için **native derleme gerekmez**. Örnek: `docs/integration/theme.example.json`.
- **`IDFont.custom(size:weight:)`** — ölçek dışı boyutlar da tema fontunu kullanır.

**Yeni**
- **Canlılık adımlarında onay titreşimi geri geldi:** her adım onaylandığında çok kısa tek
  darbe çalınır. `SDKHapticConfig.shared.stepFeedbackEnabled` ile kapatılabilir,
  `stepFeedbackIntensity` ile şiddeti ayarlanır (varsayılan açık, 0.6).

**iPad desteği**
- SDK ve örnek uygulama artık **iPad'de çalışır** (`TARGETED_DEVICE_FAMILY = "1,2"`);
  yönelim iPad'de de portrait'e kilitlidir. Ayrıntı:
  [iPad Desteği rehberi](docs/guides/ipad-support.md).
- **Yetenek tabanlı modül ikamesi:** cihazda TrueDepth kamera yoksa (Touch ID'li iPad'ler,
  Face ID'siz iPhone'lar) `livenessDetection` ve `selfieWithLiveness` yerine **normal selfie
  modülü** ile doğrulama yapılır; akışta selfie zaten varsa desteklenmeyen modül yalnızca
  çıkarılır. Karar akış kurulurken verilir, kullanıcı desteklenmeyen ekranı görmez.
  Face ID'li iPad Pro / iPad Air'de her iki modül de olduğu gibi çalışır.
- **`IdentifyManager.shared.faceTrackingFallback`** — yedek davranışı entegrasyon belirler:
  `.selfie` (varsayılan) veya `.skip` (modülü tamamen çıkar). `setupSDK`'dan önce ayarlanır,
  son kullanıcıya sorulmaz. `.livenessDetection` değeri kabul edilir ancak canlılık ekranı da
  aynı donanımı istediğinden `.selfie` gibi davranır ve log'a yazılır.
- **NFC'siz cihazlarda** modül akıştan çıkarılırken panele `NFCStatus = notAvailable`
  bildirilir (önceden yalnız log yazılıyordu).
- Canlılık ekranı desteklenmeyen cihazda artık sessizce donmuyor: uyarı gösterilip modül
  atlanıyor.
- **Ölçüler ekran yerine pencere tabanlı** (`SDKLayout.bounds`): Split View / Stage Manager
  altında kamera kırpma alanı ve canlılık ekran kaydı doğru boyutlanır.
- Metin ve form sütunları geniş ekranda okunabilir genişlikte ortalanır
  (`.sdkReadableWidth()`); kimlik kılavuz çerçevesi (`SDKLayout.maxGuideWidth`) ve selfie /
  canlılık ekranlarındaki yüz ovali (`SDKLayout.maxFaceGuideWidth`) tablette üst sınırla
  kesilir.

**Başlık çubuğunda marka adı**
- `navBar.brandTitle` / `brandSubtitle` / `titleMode` (`.module` · `.brand` ·
  `.brandWithModule`): çubuk adım adı yerine markanızı yazabilir; kamera üstü ekranlarda
  logonun yanına gelir. JSON anahtarları aynı adla. `.prominent` yüksekliği 92 pt oldu
  (56'da iki satırlı başlık alttaki bileşene biniyordu).

**Çekim kalitesi — bulanık ve parlamalı kare yüklenmez**
- **Sabitlik kapısı** (kimlik tarayıcı + OVD): çekim, ardışık kareler arası fark ve cihaz
  IMU'su birlikte sakin okuyana kadar bekler; koşul tutunca 0.5 sn ertelenir. Amaç hareket
  yasağı değil, hareket bulanıklığını engellemektir — daha önce sabit çerçeve modu sabitliği
  koşulsuz "var" sayıyordu.
- **Parlama kapısı** (tarayıcı, yeni): belgede patlamış piksel oranı eşiği aşınca çekim
  bekletilir; HUD metni `ScannerGuidanceTexts.glare`. OVD'de alan ortalaması yerine aynı
  oran ölçülür — yerel parlama artık kaçmıyor.
- **OVD still netlik tabanı**: çekilen kare bulanıksa kullanıcıya gösterilmeden en fazla
  iki kez yeniden çekilir (daha önce OVD'de netlik kontrolü yoktu).
- **Hologram adımında belge kapısı**: gökkuşağı efekti yalnız ön yüzde onaylanan belge
  çerçevede kaldığı sürece sayılır; kart çekilir ya da renkli başka bir yüzey girerse adım
  sıfırlanır. Çekim kör zamanlayıcı yerine sakinlik penceresinde alınır (0.75–2.5 sn).
- **Sabit çerçeve üst genişliği**: `ScannerFixedFrame.maxWidth` ve OVD
  `SDKLayout.maxCaptureGuideWidth` (varsayılan 630 pt). iPad'de yan boşluk kuralı ~790 pt
  çerçeve çiziyor, belge lensin yakın odak sınırına girmeden çerçeveyi dolduramıyor ve
  otomatik çekim tetiklenmiyordu. Mesafe kararı boyut/konum ayrımı ve histerezisle
  "yaklaştır / uzaklaştır" arasında titremiyor.
- **Otomatik netleme**: sabit çerçevede belge oturunca tek atış odak dürtmesi (aynı noktaya
  ikinci yazım sürekli AF'te hiçbir şey yapmıyordu); lens yakın sınırda ve netlik yoksa
  "uzaklaştırın" yönergesi. OVD odak ayarları tarayıcıyla hizalandı (yumuşak AF kapalı,
  yakın aralık, sahne değişimi izleme). `SDKIdCardOVDViewModel.debugLive` kapı değerlerini
  tanılama için yayınlar.
- **`SDKIdCardOVDViewModel.motionFeed`**: kendi kamerasıyla OVD ekranı yazan entegrasyon
  hareket ölçerini buradan besler. Beslenmezse görüntü sabitlik kapısı atlanır ve yalnız IMU
  kullanılır (log uyarısı yazılır) — önceden bu durumda otomatik çekim hiç tetiklenmiyordu.
- **`SDKSpeechRecViewModel.confirmSpeech()`** artık ifade doğrulanmadan bildirim yapmıyor;
  özel ekranda onay düğmesi başarıya bağlanmasa bile söylenmeyen ifade tamamlandı sayılmaz.

**Selfie + canlılık: TrueDepth modu**
- **`IdentifyManager.shared.selfieWithLivenessTrueDepth`** (`SDKTrueDepthMode`) ve ekran bazında
  **`SDKSelfieWithLivenessView(trueDepthMode:)`**:
  `.automatic` (varsayılan, önceki davranış) · `.required` (yalnız gerçek TrueDepth kamerasında ARKit;
  TrueDepth'siz A12+ cihazda yedek modül) · `.disabled` (ARKit yok; ön kamera + Vision ile her cihazda).
- Vision yolu aynı deneyimi sunar: iki fazlı oval, 3 sn tutma, ekran flaşı, aynı metinler ve
  karşılaştırma kuralı. Derinlik tabanlı sahtecilik koruması yoktur; baş eğimi ölçülmez.
- Kullanılan yol `sdk_logs`'a yazılır (`arkit-truedepth` / `arkit-rgb` / `vision`).
- Düzeltme: dokümanlar TrueDepth'siz A12+ cihazları (iPhone SE 2/3, A12+ Touch ID'li iPad'ler)
  "desteklenmiyor" sayıyordu; bu cihazlarda ARKit derinliksiz çalışır.

**Akış sonucu — oturum nasıl biterse bitsin tek yerden**
- **`setupSDK(onFinished:)`**, **`IdentifyManager.shared.onFlowFinished`** ve
  **`flowResultDelegate`** (`IdentifyFlowResultListener`): oturum başına tam bir kez, karar
  anında `SDKFlowOutcome` gelir — `result` (`approved` · `rejected` · `neutral` ·
  `notCompleted` · `cancelled` · `error`), `reason` (`SDKFlowEndReason`), `lastModule`,
  panelin `terminateReason`'ı ve `statusSummary`'si birebir, `closeCode`, `toDictionary()`.
- **`SDKFlowOutcome.skippedModules`**: doğrulanmadan geçilen modüller (atlandı, cihazda/belgede
  bulunamadı, NFC okuma hata sınırı, manuel MRZ düzeltmesinin tükenmesi). Akış `approved`
  bitse bile burada modül olabilir.
- Yeni rehber: [Oturum Çıkışları](docs/guides/session-exit.md) — tüm çıkış yolları, kapanış
  verileri, tek modüllü / üç modüllü / görüntülü görüşmeli akış senaryoları, modül bazında çıkış
  kataloğu (12 modül), SwiftUI/UIKit/RN-Flutter yönlendirme kalıpları.
- Olay akışına **`session.finished`** eklendi (metadata: `result`, `endReason`,
  `terminateReason`, `statusSummary`, `lastModule`…).
- **`showThankYouPage: false`** artık her yolda geçerli: sonuç ekranı hiç açılmaz, SDK
  bulunduğu ekrandan (ör. görüntülü görüşme) aşağı kayarak kapanır.
- `terminateCall` karar kuralı `SDKTerminateClassifier`'da tek yerde; varsayılan görüşme ekranı
  ve sonuç bildirimi aynı kuralı kullanır.

**Dokümantasyon — override sözleşmeleri netleştirildi**
- OVD, Liveness, Selfie, Görüşme, Adres, NFC, Konuşma ve Kimlik rehberlerinde "override
  ederseniz sizde kalanlar" açıkça yazıldı: zorunlu kancalar, iş parçacığı kuralları,
  değiştirilemeyen parçalar (tarayıcı HUD'u, iOS NFC sayfası, canlılık algılaması).

**Değişti**
- **Header'daki marka işaretinin anahtarı `.headerLogo`** oldu; önceki `.langButton` adı
  yanlıştı ve `.logo`'yu ezmek header'ı değiştirmiyordu. Eski override'lar çalışmaya
  devam eder.
- **İngilizce dil kodu `.eng` → `.en`.** `.eng` deprecated alias olarak derlenir,
  `SDKLang(rawValue: "eng")` kabul edilir, ses kliplerinde `_eng` eki yedek olarak denenir.
  Tek kırılma: host kodunda `switch` içindeki `case .eng:` deseni derlenmez.
- **Sayfa arka planları override edilebilir** — açık temadaki sabit beyaz ve modül
  ekranlarının `primary` zemini rol token'ına bağlandı.
- **Seçim satırları** (izin listesi, belge türü) artık `selectedItem*` / `unselectedItem*`
  rollerinden beslenir; `primary` ile zorunlu olarak birlikte değişmez.
- Sabit ölçüler token'landı: seçim satırı, form alanları, uyarı kartı, sheet tutamağı,
  kamera maskesi ve kılavuz renkleri, kayıt butonu.
- **`setupSDK(showThankYouPage:)` varsayılanı `true`.** 3.0.0'da varsayılan `false` idi ama
  görüşme sonu yolları bayrağa bakmadığı için sonuç ekranı yine açılıyordu; görünür davranış
  korunur. Kendi UIKit akışında `getNextModule` kullanıp parametreyi vermeyen host'a son
  adımda boş controller yerine `thankYouViewController` döner.
- **`session.completed` / `session.failed`** yalnızca gerçek bir bitişte yayınlanır.
  3.0.0'da her `terminateCall`'da gidiyor ve başarıyı `success`/`approve` içeren statüde
  arıyordu (panel `positive` gönderdiğinden onaylanan oturumlar `failed` görünüyordu);
  karar içermeyen, yeniden bağlanmaya düşen sonlandırmalarda da `failed` gidiyordu.

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

### Yayınlanmamış (v3 · build 44)

> Not: v3 ile birlikte örnek uygulama sıfırdan numaralandı (`CURRENT_PROJECT_VERSION` 23);
> aşağıdaki "Build 178" ve öncesi eski numaralandırmaya aittir.

**Build 24–44**
- Hamburger menüsü: **SDK Modül Rehberi** (showcase: tasarım kataloğu, nav bar marka/ikon
  örnekleri, tema JSON köprüsü, senaryolu dummy API) ve **Debug Değerleri** ekranı
  (`SDKDebugSettings`, tümü varsayılan kapalı; OVD kapı paneli dahil).
- Birleşik log paneli: netfox forku ile Requests / Console / Socket sekmeleri; netfox ve TTS
  tercihleri kalıcı. Panel kapatılırken oluşan `deinit` çökmesi giderildi.
- iPad: ikon seti ve `UIRequiresFullScreen = YES` (SDK portrait kilitli; App Store çoklu
  görev şartı bu anahtarla karşılanır).
- Proje adı `NewTest` → `IdentifySample`; SDK uzak SPM paketi yerine kaynağa bağlanır,
  arşiv `-workspace` ile alınır; 2sworks TestFlight imzası.
- Canlılık yeni adımları için sunucusuz deneme anahtarı.
- Dokümanlar: README'ye SPM `Exact Version` uyarısı, tema/metin API tablosu ve
  "örnekten hangi dosyalar kopyalanır" bölümü; RN/Flutter rehberlerinde kopyalama hedefleri.

**Build 23**
- Örnek uygulama **SDK tüketen bir geliştirici rehberine** dönüştürüldü: her ekran için
  Preview + View + ViewModel, SDK yeteneklerinin showcase'i.
- Her modül için entegrasyon rehberi (`IdentifySample/Modules/<Module>/<Module>.md`) ve
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
