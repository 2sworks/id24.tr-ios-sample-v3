# IdentifySDK — Flutter Entegrasyonu

Bu rehber, iOS KYC SDK'sı `IdentifySDK` için bir Flutter plugin köprüsünün nasıl kurulacağını ve
SDK'nın olay akışının (SDKEvent) Dart tarafında bir `Stream` olarak nasıl dinleneceğini anlatır.
Köprünün iskelet dosyaları bu klasörde.

> SDK yalnızca iOS'ta çalışır. Android için ayrı bir SDK gerekir ve bu pakette yoktur.
> Plugin çağrılarını `Platform.isIOS` kontrolünün içine alın.

---

## 1) Kurulum

### iOS native bağımlılığı
`ios/Runner.xcworkspace` → **File → Add Packages** →
`https://github.com/2sworks/id24.tr-ios-sdk-spm`
(XCFramework + OpenSSL/Starscream/WebRTC/SwiftSignatureView/PermissionsKit).

Dependency Rule'u `Exact Version` yapın (ör. `3.0.0`). 2.x ve 3.x aynı depodan dağıtılıyor;
Xcode'un varsayılan *Up to Next Major* kuralı en son etiketten başladığı için yanlış sürümü
çekebilir. Ayrıntı: [ana README §1](../../../README.md#1-paketi-ekleyin-swift-package-manager).

`ios/Runner/Info.plist` izinleri:

```xml
<key>NSCameraUsageDescription</key><string>Kimlik doğrulama için kamera</string>
<key>NSMicrophoneUsageDescription</key><string>Görüntülü görüşme için mikrofon</string>
<key>NFCReaderUsageDescription</key><string>Kimlik/pasaport çipi okuma</string>
```

### Köprü dosyaları
| Dosya | Konum | Görev |
|---|---|---|
| `IdentifySdkPlugin.swift` | plugin olarak: `ios/Classes/`; doğrudan uygulamada: `ios/Runner/` | MethodChannel (`setupSDK`, `setTheme`, `resetTheme`, `reportAbandoned`) + EventChannel (olaylar) |
| `identify_sdk.dart`       | `lib/identify_sdk.dart` | Dart sarmalayıcı + `SDKEvent` modeli + `Stream` |
| `../theme.example.json`   | `assets/identify_theme.json` (+ `pubspec.yaml` → `assets:`) | İsteğe bağlı başlangıç teması; `setTheme` ile gönderilir |

Plugin'i `Runner` içine koyduysanız `AppDelegate`'te kaydedin:
`IdentifySdkPlugin.register(with: registrar(forPlugin: "IdentifySdkPlugin")!)`.

Plugin'in Dart'a açtığı metotlar:

| Dart | Native karşılığı | Ne zaman |
|---|---|---|
| `IdentifySdk.setTheme(map)` → `unknownKeys` | `SDKTheme.shared.apply(dict)` | `setupSDK`'dan önce. Hot reload yeterli, derleme gerekmez |
| `IdentifySdk.resetTheme()` | `SDKTheme.shared.resetAppearance()` | SDK varsayılanlarına dönmek için |
| `IdentifySdk.setupSDK(...)` | `IdentifyManager.shared.setupSDK(...)` + akışı sunar | Akışı başlatır |
| `IdentifySdk.events` (`Stream<SDKEvent>`) | `SDKEventListener` → `EventChannel` | Önce `listen`, sonra `setupSDK` |
| `IdentifySdk.reportAbandoned(reason)` | `IdentifyManager.shared.reportSessionAbandoned(reason:)` | Kullanıcı akışı Dart tarafında terk ettiğinde |

### Örnek uygulamadan kopyalanacaklar (iOS tarafı)

Ekranlar XCFramework'ün içinde olduğu için köprü dosyaları dışında örnekten bir şey almanız
gerekmez. İki istisna var:

| Kaynak | Hedef | Ne zaman |
|---|---|---|
| `IdentifySample/SupportingFiles/*.cer` | `ios/Runner/` + *Copy Bundle Resources* | `useSslPinning: true` ise zorunlu |
| `IdentifySample/Modules/<Modül>/<Modül>CustomView.swift` (kamera kullananlarda ayrıca `IdentifySample/Modules/CustomKit/CustomCameraPreview.swift` + `CustomComponents.swift`) | `ios/Runner/Modules/` | Bir SDK ekranını native tarafta kendi tasarımınızla değiştirecekseniz (`registry.override`). Bu dosya SDK ekranının public API ile yazılmış, çalışan bir kopyasıdır; özelleştirmeyi bunun üzerinde yaparsınız. Dart'tan ekran değiştirilemez |

`IdentifySample/Modules/Login/LoginViewModel.swift` ile `App/RootView.swift`'i kopyalamanız
gerekmez ama okuyun: `prepareForSetup()` → `setupSDK` → `start()` sırası ve akışın
`SDKFlowHostView` ile gösterilmesi orada çalışan haliyle duruyor.

Dart'tan yapılamayan üç şeyi `IdentifySdkPlugin.swift` içinde yaparsınız:

| Ne | Nerede |
|---|---|
| Yeni bir görsel (logo) eklemek | iOS asset kataloğu. Dart yalnızca görselin adını gönderir (`icons.headerLogo`) |
| Dil ve metin override'ı | `setupSDK` dalının başına `IdentifyManager.shared.setSDKLang(lang:)` ve `SDKLocalization.shared.registerOverrides([.tr: ["IdVerifyTitle": "…"]])` ekleyin. İsterseniz `setupSDK` argümanlarına `language` ekleyip dili Dart'tan geçirin |
| Cihaz yeteneği politikası (TrueDepth ya da NFC yoksa) | bkz. [§2.2](#22-cihaz-yetenekleri--native-tarafta-ayarlanır) |

---

## 2) Kullanım (Dart)

```dart
import 'package:identify_sdk/identify_sdk.dart';

final sdk = IdentifySdk();

// 1) Olay akışına abone ol
final sub = sdk.events.listen((SDKEvent event) {
  debugPrint('${event.name} ${event.category} ${event.status} ${event.screen}');

  switch (event.name) {
    case 'session.started':   break;
    case 'session.finished':  /* NİHAİ sonuç, oturum başına bir kez:
                                 event.metadata['result']    → approved | rejected | neutral | notCompleted | cancelled | error
                                 event.metadata['endReason'] → agentDecision | userEndedCall | moduleFailed | …
                                 event.metadata['terminateReason'] → panel kapattıysa birebir */ break;
    case 'session.completed': /* event.status == SDKEventStatus.success */ break;
    case 'session.failed':    /* event.metadata['reason'] */ break;
    case 'session.abandoned': /* event.metadata['lastScreen'] */ break;
  }
});

// 2) SDK'yı başlat
final result = await sdk.setupSDK(SetupOptions(
  identId: 'XXXX-XXXX',
  baseApiUrl: 'https://api.example.com/',
  turnKey: 'turn-secret',
  signLangSupport: false,
  nfcMaxErrorCount: 3,
  selectedModules: const [],     // boş = backend sırası
  showThankYouPage: true,        // false: sonuç ekranı yok, SDK kapanır — sonucu 'session.finished' ile alın
));

// 3) Temizlik
await sub.cancel();
```

### Hata kontrolü — `E_SETUP` tuzağı

`setupSDK` geri çağrısındaki hata parametresi hiçbir zaman `nil` gelmez; kurulum başarılıysa
`errorMessages` boş string olur. Köprüde `if let error = error { ... }` yazarsanız akış daha
başlamadan `E_SETUP` hatasıyla biter. Mesajın dolu olup olmadığına bakın:

```swift
if let message = error?.errorMessages, !message.isEmpty {
    result(FlutterError(code: "E_SETUP", message: message, details: nil)); return
}
guard socket?.isConnected == true, roomResponse.result == true else { ... }
```

---

## 2.1) Tema — native derleme olmadan

SDK'nın hazır ekranlarının görünümünü Dart'tan ayarlarsınız. Renk, logo ya da köşe denerken
yeniden derlemeniz gerekmez; hot reload yeterli.

```dart
final unknownKeys = await IdentifySdk.instance.setTheme({
  'colors': {
    'primary': '#0F172A',
    'pageBackground': {'light': '#F8FAFC', 'dark': '#0B1120'},
    'selectedItemBackground': '#1D4ED8',
    'headerBackground': {'light': '#0F172A', 'dark': '#0B1120'},
    'headerTitle': '#FFFFFF',
  },
  'navBar': {'preset': 'centered', 'showsDivider': true,   // classic | centered | minimal | prominent
             'brandTitle': 'Acme Bank', 'titleMode': 'brandWithModule'},  // marka: üst satır marka, alt satır adım adı
  'buttons': {'corner': 12, 'height': 54, 'styles': {'secondary': {'borderWidth': 1}}},
  'icons': {'headerLogo': 'my_mark'},   // iOS asset kataloğundaki görsel adı
});

if (unknownKeys.isNotEmpty) debugPrint('Tema: tanınmayan anahtar $unknownKeys');

await IdentifySdk.instance.resetTheme();   // SDK varsayılanlarına dön
```

Renkler `'#RRGGBB'` ya da `{'light': ..., 'dark': ...}` olarak, köşeler `'capsule'` ya da sayı
olarak verilir. Bölümler: `colors`, `fonts`, `metrics`, `buttons`, `navBar`, `selection`, `alerts`,
`banners`, `fields`, `sheets`, `capture`, `controls`, `call`, `motion`, `icons`.
Bütün anahtarlar: [Tema Rehberi](../../guides/theming.md) ·
örnek sözlük: [theme.example.json](../theme.example.json).

> Başlık çubuğundaki marka işaretinin anahtarı `icons.headerLogo`. `icons.logo` giriş ekranında
> ve kamera ekranlarının üstündeki başlıkta kullanılır.

Başlık çubuğundaki geri, yardım ("?") ve menü düğmelerini `navBar.buttons` ile gizleyebilirsiniz
(`showsBack`, `showsHelp`, `showsMenu`). Kendi düğmenizi eklemek ve yardım düğmesine iş bağlamak
Swift closure'ı gerektirdiği için `IdentifySdkPlugin.swift` içinde yapılır. Ayrıntı:
[Tema Rehberi → Başlık Çubuğu Düğmeleri](../../guides/theming.md#başlık-çubuğu-düğmeleri).

## 2.2) Cihaz yetenekleri — native tarafta ayarlanır

Bu ayarlar tema değil, akış politikası; köprüden geçmez. `IdentifySdkPlugin.swift` içinde
`setupSDK` çağrısından önce ayarlanır:

```swift
// IdentifySdkPlugin.swift — setupSDK'dan önce
IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan
// IdentifyManager.shared.faceTrackingFallback = .skip  // adımı tamamen çıkar
IdentifyManager.shared.selfieWithLivenessTrueDepth = .automatic  // .required | .disabled

SDKHapticConfig.shared.stepFeedbackEnabled = true       // canlılık adım titreşimi (vars. açık)
SDKHapticConfig.shared.stepFeedbackIntensity = 0.6      // 0…1
```

| Ne | Ne zaman devreye girer |
|---|---|
| `faceTrackingFallback` | Cihaz ARKit yüz takibini desteklemiyorsa (TrueDepth kamerası olmayan A11 ve öncesi). `livenessDetection` / `selfieWithLiveness` yerine ne konacağını belirler: `.selfie` (varsayılan) ya da `.skip` |
| `selfieWithLivenessTrueDepth` | Selfie + canlılık ekranının derinlik kamerasını nasıl kullanacağı: `.automatic` (varsayılan), `.required` (yalnızca TrueDepth kamerası olan cihazlarda), `.disabled` (ARKit kullanılmaz, Vision ile her cihazda çalışır ama derinlik kontrolü olmaz). [Ayrıntı](../../../IdentifySample/Modules/SelfieWithLiveness/SelfieWithLiveness.md#truedepth-modu) |
| NFC | iPad'de ve NFC'siz iPhone'larda modül kendiliğinden çıkarılır ve panele `NFCStatus = notAvailable` gider. Kullanıcıya bilgi sayfası göstermek için `setupSDK(..., showNFCNotFoundPage: true)` |
| `SDKHapticConfig` | Çekim sırasındaki artan titreşim ve canlılık adımlarındaki titreşim; ikisi de kapatılabilir |

Dart tarafında bu durumları olaylardan takip edersiniz: atlanan adım `module.<Modül>.skipped`
olarak gelir.

SDK iPhone ve iPad'de çalışır; ekran ikisinde de dikey konuma kilitlidir.
Ayrıntı: [iPad Desteği](../../guides/ipad-support.md).

---

## 3) Olay (SDKEvent) yapısı

EventChannel, native `SDKEvent.toDictionary()` çıktısını değiştirmeden Dart'a iletir.
`SDKEvent.fromMap` bunu modele çevirir:

```dart
class SDKEvent {
  final String name;             // "session.started", "module.Selfie.completed" ...
  final SDKEventCategory category;
  final SDKEventStatus status;
  final String? module;          // "Selfie", "Mrz & Nfc Screen" ...
  final String? screen;          // kullanıcının o anki/son ekranı
  final String sessionId;
  final int timestampMs;
  final String? message;
  final Map<String, String> metadata;  // reason, statusSummary, lastScreen ...
}
```

### SDK nerede ne yapıyor — olay akış tablosu

| Olay adı | Kategori | Ne zaman | Anlam |
|---|---|---|---|
| `session.started` | session | `setupSDK` | Oturum başladı |
| `module.<Modül>.presented` | module | Ekran açıldığında | Kullanıcı o ekranda (lastScreen güncellenir) |
| `module.<Modül>.completed` | module | Modül bittiğinde | Adım başarıyla tamamlandı |
| `module.<Modül>.failed` | module | Modül hata verdiğinde | Adım başarısız |
| `module.<Modül>.skipped` | module | Modül atlandığında | Adım atlandı |
| `call.connected` | call | Çağrı başladığında | Görüşme başladı |
| `call.ended` | call | Çağrı bittiğinde | Görüşme bitti (metadata['statusSummary']) |
| `session.finished` | session | Oturum nasıl biterse bitsin, bir kez | Nihai sonuç: `metadata['result']`, `endReason`, `terminateReason`, `statusSummary`, `lastModule` (3.1.0) |
| `session.completed` | session | `result == approved` | Oturum başarıyla kapandı (status `success`) |
| `session.failed` | session | `rejected` · `neutral` · `notCompleted` · `error` | Oturum başarısız kapandı |
| `session.abandoned` | session | `cancelled` | Kullanıcı ya da host çıktı (metadata['lastScreen'] kullanıcının kaldığı ekran) |

Metadata anahtarlarının tamamı: [Event Sistemi → Oturum Sonucu Olayları](../../guides/events.md#oturum-sonucu-olayları-310) · bütün çıkış yolları ve kapanıştan sonra yönlendirme: [Oturum Çıkışları](../../guides/session-exit.md#95-react-native--flutter).

> Bu olay akışı SDK'daki `IdentifyTrackingListener`'ın yanına eklendi, onun yerini almadı.
> Mevcut entegrasyonlar olduğu gibi çalışmaya devam eder.
