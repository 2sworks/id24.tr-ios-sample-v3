# IdentifySDK — iOS Sample App & Geliştirici Rehberi

**IdentifySDK**, uçtan uca dijital kimlik doğrulama (KYC) akışını uygulamanıza gömmenizi sağlayan
bir iOS SDK'sıdır: kimlik kartı/pasaport tarama (OCR), NFC çip okuma, selfie + canlılık testi,
sesli okuma doğrulaması, imza, adres belgesi ve **agent ile canlı görüntülü görüşme** — hepsi
tek bir akış içinde, sunucu tarafından yönetilen modül sırasıyla çalışır.

Bu depo, SDK'yı edinen bir geliştiricinin **ilk bakacağı yer** olarak tasarlandı:

- **Çalışan bir örnek uygulama** (`IdentifySample/`) — her modülün hazır ekranı ve host-tarafı örneği
- **Modül bazlı entegrasyon rehberleri** — her ekran için "kendi tasarımınla nasıl çalıştırırsın"
- **Kavram rehberleri** — sunucu yapısı, WebSocket, TURN/WebRTC, log, event, tema, dil

---

## İçindekiler

1. [Başlangıç](#başlangıç)
2. [SDK Nasıl Çalışır](#sdk-nasıl-çalışır)
3. [Modül Kataloğu](#modül-kataloğu)
4. [Kavram Rehberleri](#kavram-rehberleri)
5. [Ekranları Özelleştirme](#ekranları-özelleştirme)
6. [Kesişen Özellikler](#kesişen-özellikler)
7. [React Native & Flutter](#react-native--flutter)
8. [Örnek Uygulamanın Yapısı](#örnek-uygulamanın-yapısı)
9. [Sürüm Geçmişi](#sürüm-geçmişi)

---

## Başlangıç

### 1. Paketi ekleyin (Swift Package Manager)

Xcode → *File → Add Package Dependencies* →

```
https://github.com/2sworks/id24.tr-ios-sdk-spm
```

**Dependency Rule olarak mutlaka `Exact Version` seçin** ve sürümü elle yazın (ör. `3.0.0`).

Sebebi: **2.x ve 3.x aynı depodan dağıtılır.** Bunlar iki ayrı sürüm ailesidir — 3.x, hazır
SwiftUI ekranlarını (DefaultUI) SDK'nın içine taşıyan farklı bir entegrasyon modelidir ve
2.x ile kaynak uyumlu değildir. Xcode'un varsayılan kuralı (*Up to Next Major*) en son
etiketten başlar; 2.x kullanan bir projeye paketi varsayılanla eklerseniz 3.x çekilir ve
proje derlenmez. `Exact Version` ayrıca sürüm yükseltmesini bilinçli bir karar hâline
getirir: bağımlılık kümesi sürüme göre farklıdır (3.x ayrıca `PermissionsKit` ve
`SwiftSignatureView` getirir) ve `Package.resolved` sessizce kaymaz.

| Sürüm | Etiket aralığı | Ne zaman |
|---|---|---|
| 3.x | `3.0.0` ve üzeri | Bu depodaki rehberlerin anlattığı sürüm — hazır ekranlar SDK'nın içinde |
| 2.x | `2.5.x` | Eski entegrasyon; ekranlar host uygulamada |

Paket, SDK ile birlikte çalışma zamanı bağımlılıklarını da getirir: `OpenSSL` (NFC kripto),
`Starscream` (WebSocket), `WebRTC` (görüntülü görüşme), `PermissionsKit` ve
`SwiftSignatureView` (3.x).

### 2. İzinleri tanımlayın

| İzin | Anahtar | Hangi modül için |
|---|---|---|
| Kamera | `NSCameraUsageDescription` | Kimlik, Selfie, Canlılık, Video, Görüşme |
| Mikrofon | `NSMicrophoneUsageDescription` | Görüşme, Video kayıt, Konuşma |
| Konuşma tanıma | `NSSpeechRecognitionUsageDescription` | Konuşma (Speech) modülü |
| NFC | `com.apple.developer.nfc.readersession.formats` → `TAG` (entitlement) + Info.plist'e `com.apple.developer.nfc.readersession.iso7816.select-identifiers` → `A0000002471001` | NFC çip okuma |
| iPad hedefi | `UIRequiresFullScreen` → `YES` | SDK portrait kilitlidir; bu anahtar olmadan App Store yüklemesi iPad çoklu görev şartıyla reddedilir ([iPad Desteği](docs/guides/ipad-support.md)) |

### 3. Akışı başlatın

Uygulamanızın kökünde `SDKFlowHostView` kurun, sonra `setupSDK` çağırın.
**Sıralama kritik:** `coordinator.prepareForSetup()` her zaman `setupSDK`'dan **önce** çağrılmalı.

```swift
import IdentifySDK
import SwiftUI

struct RootView: View {
    @StateObject private var coordinator = SDKFlowCoordinator()
    @State private var registry = SDKViewRegistry()

    var body: some View {
        SDKFlowHostView(coordinator: coordinator, registry: registry) {
            LoginView()                      // sizin giriş ekranınız (kök)
                .environmentObject(coordinator)
        }
    }
}

func connect(coordinator: SDKFlowCoordinator) {
    coordinator.prepareForSetup()            // 1) setupSDK'dan ÖNCE

    IdentifyManager.shared.setupSDK(
        identId: "MÜŞTERİ-İŞLEM-NO",
        baseApiUrl: "https://v2api.identify.com.tr/",
        networkOptions: SDKNetworkOptions(useSslPinning: false),
        kpsData: nil,
        signLangSupport: false,
        nfcMaxErrorCount: 3,
        selectedModules: [],                 // boş = sırayı backend belirler
        turnKey: "TURN-ANAHTARINIZ",
        wsSecretKey: "WS-ANAHTARINIZ",
        showThankYouPage: true
    ) { socket, roomResponse, error in
        Task { @MainActor in
            if error == nil, socket?.isConnected == true, roomResponse.result == true {
                coordinator.start()          // 2) ilk modüle geç
            }
        }
    }
}
```

Bu kadar. Backend'in `modules` listesinde ne varsa, ekranlar o sırayla otomatik gelir.
Hiçbir modül ekranı yazmanıza gerek yok — hepsinin hazır (drop-in) SwiftUI sürümü SDK'nın içindedir.
Tam parametre listesi için: [Sunucu & API Rehberi](docs/guides/server-api.md).

> Minimum iOS sürümü: **iOS 14** (örnek uygulama iOS 15 hedefler).

### 4. Görünümü ve metinleri ayarlayın

Görünüm ve dil **`setupSDK`'dan önce** verilir; ekranlar ilk çizimde bu değerleri okur.
Kaynak dosya kopyalamanız gerekmez — tek isteğe bağlı dosya, projenize ekleyip
`applyTheme(named:)` ile yükleyebileceğiniz [`docs/integration/theme.example.json`](docs/integration/theme.example.json).

| İstediğiniz | Çağrı |
|---|---|
| Marka renkleri | `SDKTheme.shared.colors.primary = Color("Brand")` (`success`, `error`, `accentWarning`…) |
| Zemin / seçili satır / başlık — light+dark | `SDKTheme.shared.colors.pageBackground = SDKAdaptiveColor(light:dark:)`; `selectedItemBackground`, `headerBackground`, `headerTitle` |
| Font ailesi | `SDKTheme.shared.fonts.familyName = "Inter"` |
| Köşe / boşluk | `SDKTheme.shared.metrics.radiusMD = 12`, `metrics.radiusCard = 24`, `metrics.spacingLG = 16` |
| Buton biçimi | tümü: `SDKTheme.shared.buttons.base.corner = .radius(12)`, `buttons.base.height = 54` · tek stil: `SDKTheme.shared.buttons[.secondary].borderWidth = 1` |
| Başlık çubuğu tasarımı | `SDKTheme.shared.navBar.preset = .centered` (`classic / centered / minimal / prominent`) |
| Başlık çubuğunda marka adı | `SDKTheme.shared.navBar.brandTitle = "Acme Bank"` + `navBar.titleMode = .brandWithModule` |
| Logo / geri / yardım / menü ikonu | `SDKTheme.shared.setIcon(.headerLogo, Image("my_mark"))` — anahtarlar `SDKIconKey`; geri al: `resetIcon(_:)` |
| Titreşim | `SDKHapticConfig.shared.stepFeedbackEnabled = false` · per-modül `setEnabled(false, for: .selfie)` · hepsi `setEnabledForAll(false)` |
| Her şeyi tek JSON'la | `SDKTheme.shared.applyTheme(named: "IdentifyTheme")` / `apply(dict)` / `apply(json:)` → **tanınmayan anahtarları döner**, geliştirmede loglayın |
| Varsayılanlara dön | `SDKTheme.shared.resetAppearance()` |
| Dil | `IdentifyManager.shared.setSDKLang(lang: .tr)` (`.tr .en .de .az .ru`) |
| Tek metni değiştir | `SDKLocalization.shared.setOverride(key: .idVerifyTitle, language: .tr, value: "Kimlik Kontrolü")` |
| Toplu metin | `SDKLocalization.shared.registerOverrides([.tr: ["IdVerifyTitle": "…"]])` · dosyadan: `loadOverrides(from:language:)` |

Ekranın **kendisini** değiştirmek ayrı bir seviyedir (`SDKViewRegistry`) — aşağıdaki
[Ekranları Özelleştirme](#ekranları-özelleştirme) bölümüne bakın.
Derinlemesine: [Tema](docs/guides/theming.md) · [Lokalizasyon](docs/guides/localization.md).

### 5. Örnekten hangi dosyaları kopyalayacaksınız

Drop-in kullanımda **hiçbir dosya kopyalamanız gerekmez** — adım 3'teki kurulum yeterlidir.
Aşağıdakiler ihtiyaca göre alınır. Hedef yollar sizin projenizdeki karşılıklarıdır.

| Kaynak (bu depo) | Hedef | Ne zaman |
|---|---|---|
| `IdentifySample/App/RootView.swift` | `<App>/App/RootView.swift` | `SDKFlowHostView` + coordinator + registry kurulumunun çalışan hâli. Kendi kök view'ınıza adım 3'teki kodu yazmak da aynı işi görür. **Opsiyonel** |
| `IdentifySample/Modules/Login/LoginView.swift`, `LoginViewModel.swift` | `<App>/Modules/Login/` | `prepareForSetup()` → `setupSDK` → `start()` sıralamasının ve hata durumlarının referansı. Kendi giriş ekranınıza uyarlayın. **Referans** |
| `IdentifySample/SupportingFiles/*.cer` | app target → *Copy Bundle Resources* | `useSslPinning: true` ise sunucu sertifikası bundle'da olmak zorundadır. **Pinning açıksa zorunlu** |
| `IdentifySample/Modules/<Modül>/<Modül>Example.swift`, `<Modül>HostViewModel.swift`, `<Modül>Config.swift` | `<App>/Modules/<Modül>/` | O ekranı kendi tasarımınızla değiştirecekseniz (`registry.override`). Üçü bir kalıptır: *Example* = view, *HostViewModel* = SDK ViewModel sarmalayıcı, *Config* = dışarıdan verilen ayarlar. **Opsiyonel** |
| `IdentifySample/Showcase/HostModuleViewModel.swift`, `ShowcaseSupport.swift` | `<App>/Modules/Shared/` | Üstteki üçlüyü kopyaladıysanız **zorunlu**: `HostModuleViewModel` taban sınıfı ile `IDColor` / `showcaseThemed()` yardımcıları buradadır |
| `IdentifySample/Core/Debug/SDKLogPanel.swift`, `SDKNetworkLogger.swift` | `<App>/Core/Debug/` | Geliştirme sırasında SDK logunu ve ağ trafiğini cihazda görmek için. `SDKLogPanel` netfox ister. **Opsiyonel** |
| `docs/integration/theme.example.json` | `<App>/Resources/IdentifyTheme.json` | Temayı kod yerine JSON ile vermek isterseniz (`applyTheme(named:)`). **Opsiyonel** |

Kopyalamayın, gerekmez: modül ekranları, kamera HUD'ları, dil dosyaları, ikonlar ve sesler
XCFramework'ün içindedir. `Assets.xcassets`, `Info.plist`, `Env.xcdatamodeld` ve
`Vendor/netfox/` örnek uygulamaya özeldir; kendi projenizdekiler kullanılır.

Kopyaladığınız her `.swift` dosyasını Xcode'da **uygulama target'ına** eklemeyi unutmayın
(*Target Membership* işaretli olmalı).

---

## SDK Nasıl Çalışır

```
Host App                         IdentifySDK                        Identify Backend
────────                         ───────────                        ────────────────
setupSDK(identId, ...)  ───────► connectToRoom ────────────────────► oda + modül listesi
                                 RoomResponse.modules ◄─────────────  (RoomResponse)
coordinator.start()     ───────► SDKFlowCoordinator
                                   │  path'e rota push eder
                                   ▼
                                 SDKFlowHostView ─► registry'de override var mı?
                                   │                   evet → sizin ekranınız
                                   │                   hayır → SDK'nın hazır ekranı
                                   ▼
                                 Modül VM'i (OCR / NFC / upload / soket sinyali)
                                   │
                                   ▼
                                 advanceToNextModule() ────────────► adım tamamlandı sinyali
                                   (son modülden sonra ThankYou)
```

Üç yapı taşını tanımak yeterli:

| Yapı | Ne işe yarar |
|---|---|
| `IdentifyManager.shared` | Tek orkestratör: HTTP, WebSocket ve WebRTC burada yaşar. Ekranlardan bağımsızdır. |
| `SDKFlowCoordinator` | Akışın beyni: hangi modüldeyiz, ileri/atla/geri, ilerleme yüzdesi. |
| `SDKViewRegistry` | Ekran defteri: bir SDK ekranını kendi tasarımınızla değiştirmek veya araya ekran sokmak için. |

Derinlemesine anlatım: [Mimari Rehberi](docs/guides/architecture.md).

---

## Modül Kataloğu

Her modülün kendi rehberi vardır: ekranın ne yaptığı, kullanıcının ne yaşadığı, hazır ekranı
kullanma, **kendi tasarımınla değiştirme** ve ViewModel referansı — hepsi tek dosyada.

| Modül             | Ne yapar                                                             | Rehber                                                                         |
| ----------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Hazırlık          | İzinleri ve bağlantı hızını kontrol eder, kullanıcıyı akışa hazırlar | [Prepare](IdentifySample/Modules/Prepare/Prepare.md)                                  |
| Kimlik (OCR)      | Kimlik kartının ön/arka yüzünü çeker, cihaz üzerinde okur            | [IdCard](IdentifySample/Modules/IdCard/IdCard.md)                                     |
| Kimlik (OVD)      | Hologram/optik doğrulama ile sahte kimlik tespiti                    | [IdCardOVD](IdentifySample/Modules/IdCardOVD/IdCardOVD.md)                            |
| NFC               | Kimlik/pasaport çipini okur (ICAO: BAC/PACE/CA)                      | [NFC](IdentifySample/Modules/NFC/NFC.md)                                              |
| Selfie            | Selfie çeker, cihaz üzerinde yüz tespiti yapar                       | [Selfie](IdentifySample/Modules/Selfie/Selfie.md)                                     |
| Selfie + Canlılık | Selfie ile canlılık testini birleştirir                              | [SelfieWithLiveness](IdentifySample/Modules/SelfieWithLiveness/SelfieWithLiveness.md) |
| Canlılık          | Sola dön / göz kırp / gülümse adımlarıyla canlılık testi             | [Liveness](IdentifySample/Modules/Liveness/Liveness.md)                               |
| Konuşma           | Ekrandaki metni sesli okutup doğrular (STT)                          | [Speech](IdentifySample/Modules/Speech/Speech.md)                                     |
| İmza              | Ekranda imza alır ve yükler                                          | [Signature](IdentifySample/Modules/Signature/Signature.md)                            |
| Video Kayıt       | Kısa video kaydı alır ve yükler                                      | [VideoRecorder](IdentifySample/Modules/VideoRecorder/VideoRecorder.md)                |
| Adres Onayı       | Adres belgesi fotoğrafı/PDF'i yükler                                 | [AddressConfirm](IdentifySample/Modules/AddressConfirm/AddressConfirm.md)             |
| Görüntülü Görüşme | Agent ile canlı WebRTC görüşmesi                                     | [CallScreen](IdentifySample/Modules/CallScreen/CallScreen.md)                         |
| Teşekkür          | Akış sonucu ekranı (başarılı/başarısız/beklemede)                    | [ThankYou](IdentifySample/Modules/ThankYou/ThankYou.md)                               |
| İşaret Dili       | Görüşme öncesi işaret dili tercihi kapısı                            | [SignLang](IdentifySample/Modules/SignLang/SignLang.md)                               |
|  Bağlantı Koptu   | Bağlantı kopunca çıkan overlay + otomatik toparlanma                 | [LostConnection](IdentifySample/Modules/LostConnection/LostConnection.md)             |

➡️ Ortak kurallar (kurulum, üç özelleştirme yöntemi, "bypass yok" kuralı) için önce
**[Modül Rehberleri İndeksi](IdentifySample/Modules/Modules.md)**'ni okuyun.

> Not: Bu rehberler kasıtlı olarak **SampleApp (public repo)** içindedir. SDK, ikili (binary)
> XCFramework olarak dağıtıldığından SDK kaynak ağacına konan dokümanlar tüketici tarafından
> okunamaz; tek kaynak burasıdır.

---

## Kavram Rehberleri

Modüllerin altında yatan sistemleri anlamak için:

| Rehber | İçerik |
|---|---|
| [Full Integration (Tek Referans)](FULL-INTERGATION.md) | **Tüm özelleştirme yetenekleri tek yerde** — tema, font, ikon, metin, TTS, akış, ekran override, olaylar, log, `setupSDK` |
| [Mimari](docs/guides/architecture.md) | `IdentifyManager`, modül hattı, DefaultUI üçlüsü, yaşam döngüsü |
| [Sunucu & API](docs/guides/server-api.md) | `setupSDK` tüm parametreleri, `RoomResponse`, modül sırası, SSL pinning |
| [WebSocket](docs/guides/websocket.md) | Soket aksiyonları, `socket_auth` token'ı, reconnect ve LostConnection katmanı |
| [TURN & WebRTC](docs/guides/turn-webrtc.md) | STUN/TURN kimlik üretimi, şifreli TURN, görüşme akışı |
| [Loglama](docs/guides/logging.md) | `SDKLog` facade'i, severity/kategori, online log, redaksiyon |
| [Event Sistemi](docs/guides/events.md) | `SDKEvent`, `IdentifyTrackingListener`, analitik entegrasyonu |
| [Tema](docs/guides/theming.md) | `SDKTheme` — renk/font/ikon/metrik/bileşen override, rol renkleri, JSON ile tema |
| [3.0.1 Değişiklikleri](docs/guides/migration-3.0.1.md) | Tema paketiyle gelen yenilikler, değişenler ve geçiş adımları |
| [iPad Desteği](docs/guides/ipad-support.md) | Cihaz yetenekleri (NFC / TrueDepth), modül ikamesi, yönelim ve tablet yerleşimi |
| [Lokalizasyon](docs/guides/localization.md) | 5 dil (TR/EN/DE/AZ/RU), metin override |
| [Özelleştirme](docs/guides/customization.md) | Üç özelleştirme yöntemi derinlemesine + "bypass yok" kuralı |
| [IdentityScanner](docs/guides/identity-scanner.md) | Gerçek zamanlı belge tarama motoru: profiller, alan OCR, TCKN/MRZ doğrulama, bağımsız kullanım |

---

## Ekranları Özelleştirme

Kısa özet — üç seviye vardır, dilediğinizde karıştırabilirsiniz:

```swift
// A) Hiçbir şey yapma → SDK'nın hazır ekranları çalışır (drop-in)

// B) Bir ekranı kendi tasarımınla değiştir
registry.override(.selfie) { MySelfieView() }

// C) Araya kendi ekranını sok (tanıtım, sözleşme, başarı...)
registry.custom("welcome") { MyIntroView() }
coordinator.insert(["welcome"], before: .selfie)
```

Tek altın kural: custom ekranınız **iş mantığını SDK ViewModel'ine bırakmalı**
(taramayı `vm.scanFront(image:)`, geçişi `coordinator.advanceToNextModule()` yapar).
Kendi HTTP isteğinizi atarsanız backend akışı ilerlemez.
Ayrıntı: [Özelleştirme Rehberi](docs/guides/customization.md).

---

## Kesişen Özellikler

Modüllerden bağımsız, akışın tamamına dokunan yetenekler:

- **Sesli okuma (Read-Aloud)** — her modül ekranı açıldığında yönergesi otomatik seslendirilebilir;
  modül başına `.native` (Siri sesi) / `.customAudio` (kendi ses kaydınız) / `.off` seçilir.
  → [ReadAloud Rehberi](IdentifySample/Modules/ReadAloud.md)
- **Tema** — tüm renk/font/ikon/metrik token'ları `SDKTheme.shared` üzerinden değiştirilebilir.
  → [Tema Rehberi](docs/guides/theming.md)
- **Dil** — TR, EN, DE, AZ, RU; her metni tek tek ezebilirsiniz.
  → [Lokalizasyon Rehberi](docs/guides/localization.md)
- **Log & İzleme** — konsol + online log, kategori bazlı; `TrackingEventType` ile her modülün
  gösterildi/tamamlandı/atlandı olaylarını dinlersiniz.
  → [Loglama](docs/guides/logging.md) · [Event Sistemi](docs/guides/events.md)

---

## React Native & Flutter

SDK'yı köprüleyerek RN/Flutter uygulamalarında da kullanabilirsiniz. Hazır köprü iskeletleri:

- [React Native entegrasyonu](docs/integration/react-native/README.md)
- [Flutter entegrasyonu](docs/integration/flutter/README.md)

---

## Örnek Uygulamanın Yapısı

```
IdentifySample/
├── App/            AppDelegate + RootView (SDKFlowHostView kurulumu)
├── Core/           Debug araçları, extension'lar
├── Modules/        Modül başına: örnek ekran + HostViewModel + <Modül>.md rehberi
│   ├── Login/      Host'un giriş ekranı örneği (identId girişi + setupSDK)
│   ├── Selfie/     SelfieExample, SelfieHostViewModel, Selfie.md ...
│   └── ...
├── Showcase/       Yetenek vitrini: event akış ekranı, sesli okuma denemesi,
│                   cross-platform rehber ekranı, tasarım kataloğu
└── SupportingFiles/ Info.plist, entitlements, asset'ler
```

Hangi dosyanın kopyalanacağı ve nereye konacağı: [§5 Örnekten hangi dosyaları
kopyalayacaksınız](#5-örnekten-hangi-dosyaları-kopyalayacaksınız).

Uygulamayı açıp `IdentifySample.xcodeproj` ile derleyin; Login ekranına bir `identId` girip
tüm akışı cihazda uçtan uca deneyimleyebilirsiniz (NFC ve görüşme için gerçek cihaz gerekir).

---

## Sürüm Geçmişi

SDK ve Sample App sürüm notlarının tamamı için: **[CHANGELOG.md](CHANGELOG.md)**
