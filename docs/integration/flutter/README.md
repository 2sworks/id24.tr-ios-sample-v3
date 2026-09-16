# IdentifySDK — Flutter Entegrasyonu

Bu rehber, `IdentifySDK` (iOS KYC kimlik doğrulama SDK'sı) için bir **Flutter plugin
köprüsü** kurmayı ve SDK'nın **birleşik olay akışını** (SDKEvent) Dart tarafında bir
`Stream` olarak dinlemeyi anlatır. Köprü iskeleti bu klasördedir.

> SDK yalnızca iOS'tur. Android için ayrı bir SDK gerekir (bu pakette yoktur);
> plugin'i `Platform.isIOS` ile koşullayın.

---

## 1) Kurulum

### iOS native bağımlılığı
`ios/Runner.xcworkspace` → **File → Add Packages** →
`https://github.com/2sworks/id24.tr-ios-sdk-spm`
(XCFramework + OpenSSL/Starscream/WebRTC/SwiftSignatureView/PermissionsKit).

**Dependency Rule `Exact Version` olmalı** (ör. `3.0.0`). 2.x ve 3.x aynı depodan dağıtılır;
Xcode'un varsayılan *Up to Next Major* kuralı en son etiketten başladığı için yanlış
sürümü çekebilir. Ayrıntı: [ana README §1](../../../README.md#1-paketi-ekleyin-swift-package-manager).

`ios/Runner/Info.plist` izinleri:

```xml
<key>NSCameraUsageDescription</key><string>Kimlik doğrulama için kamera</string>
<key>NSMicrophoneUsageDescription</key><string>Görüntülü görüşme için mikrofon</string>
<key>NFCReaderUsageDescription</key><string>Kimlik/pasaport çipi okuma</string>
```

### Köprü dosyaları
| Dosya | Konum | Görev |
|---|---|---|
| `IdentifySdkPlugin.swift` | plugin: `ios/Classes/` — doğrudan uygulama: `ios/Runner/` | MethodChannel (`setupSDK`, `setTheme`, `resetTheme`, `reportAbandoned`) + EventChannel (olaylar) |
| `identify_sdk.dart`       | `lib/identify_sdk.dart` | Dart sarmalayıcı + `SDKEvent` modeli + `Stream` |
| `../theme.example.json`   | `assets/identify_theme.json` (+ `pubspec.yaml` → `assets:`) | isteğe bağlı başlangıç teması; `setTheme` ile gönderilir |

Plugin'i `Runner` içine koyduysanız `AppDelegate`'te kaydedin:
`IdentifySdkPlugin.register(with: registrar(forPlugin: "IdentifySdkPlugin")!)`.

Plugin dört metot açar:

| Dart | Native karşılığı | Ne zaman |
|---|---|---|
| `IdentifySdk.setTheme(map)` → `unknownKeys` | `SDKTheme.shared.apply(dict)` | `setupSDK`'dan **önce**; hot reload yeter, derleme yok |
| `IdentifySdk.resetTheme()` | `SDKTheme.shared.resetAppearance()` | SDK varsayılanlarına dönüş |
| `IdentifySdk.setupSDK(...)` | `IdentifyManager.shared.setupSDK(...)` + akışı sunar | akışı başlatır |
| `IdentifySdk.events` (`Stream<SDKEvent>`) | `SDKEventListener` → `EventChannel` | `listen` **önce**, sonra `setupSDK` |
| `IdentifySdk.reportAbandoned(reason)` | `IdentifyManager.shared.reportSessionAbandoned(reason:)` | kullanıcı akışı Dart tarafından terk ettiğinde |

### Örnek uygulamadan kopyalanacaklar (iOS tarafı)

Köprü dosyaları dışında örnekten alınacak bir şey yoktur; ekranlar XCFramework'ün içindedir.
İki istisna:

| Kaynak | Hedef | Ne zaman |
|---|---|---|
| `IdentifySample/SupportingFiles/*.cer` | `ios/Runner/` + *Copy Bundle Resources* | `useSslPinning: true` ise zorunlu |
| `IdentifySample/Modules/<Modül>/<Modül>CustomView.swift` (kamera kullananlar için ek olarak `IdentifySample/Modules/CustomKit/CustomCameraPreview.swift` + `CustomComponents.swift`) | `ios/Runner/Modules/` | bir SDK ekranını **native tarafta** kendi tasarımınızla değiştirecekseniz (`registry.override`): SDK ekranının public API ile yazılmış birebir, çalışan kopyası; özelleştirme bu dosya üzerinde yapılır. Dart'tan ekran override edilemez |

`IdentifySample/Modules/Login/LoginViewModel.swift` ile `App/RootView.swift` kopyalanmaz ama
referans olarak okunmalıdır: `prepareForSetup()` → `setupSDK` → `start()` sıralaması ve akışın
`SDKFlowHostView` ile sunumu orada çalışır hâlde durur.

**Dart'tan yapılamayan üç şey**, `IdentifySdkPlugin.swift` içinde yapılır:

| Ne | Nerede |
|---|---|
| Yeni bir görsel (logo) eklemek | iOS asset kataloğu; Dart yalnız **adını** gönderir (`icons.headerLogo`) |
| Dil ve metin override'ı | `setupSDK` dalının başına `IdentifyManager.shared.setSDKLang(lang:)` ve `SDKLocalization.shared.registerOverrides([.tr: ["IdVerifyTitle": "…"]])`; isterseniz `setupSDK` argümanlarına `language` ekleyip Dart'tan geçirin |
| Cihaz yeteneği politikası (TrueDepth/NFC yoksa) | bkz. [§2.2](#22-cihaz-yetenekleri--native-tarafta-ayarlanır) |

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

`setupSDK` geri çağrısındaki hata parametresi **her zaman doludur**; başarılı kurulumda
`errorMessages` boş string olur. Köprüde `if let error = error { ... }` yazılırsa akış
hiç başlamadan `E_SETUP` ile başarısız olur. Doğru kontrol mesajın dolu olmasıdır:

```swift
if let message = error?.errorMessages, !message.isEmpty {
    result(FlutterError(code: "E_SETUP", message: message, details: nil)); return
}
guard socket?.isConnected == true, roomResponse.result == true else { ... }
```

---

## 2.1) Tema — native derleme olmadan

SDK'nın hazır ekranlarının görünümü Dart'tan uygulanır; renk/logo/köşe denemesi için
**yeniden derleme gerekmez**, hot reload yeterlidir.

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

Renk değeri `'#RRGGBB'` ya da `{'light': ..., 'dark': ...}`; köşe `'capsule'` ya da sayı.
Bölümler: `colors`, `fonts`, `metrics`, `buttons`, `navBar`, `selection`, `alerts`,
`banners`, `fields`, `sheets`, `capture`, `controls`, `call`, `motion`, `icons`.
Tüm anahtarlar: [Tema Rehberi](../../guides/theming.md) ·
örnek sözlük: [theme.example.json](../theme.example.json).

> **Header'daki marka işareti** `icons.logo` değil `icons.headerLogo`'dur. `logo` giriş
> ekranı ve kamera üstü başlıkta kullanılır.

## 2.2) Cihaz yetenekleri — native tarafta ayarlanır

Bunlar tema değil **akış politikasıdır** ve köprüden geçmez; `IdentifySdkPlugin.swift`
içinde, `setupSDK` çağrısından **önce** ayarlanır:

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
| `faceTrackingFallback` | Cihaz ARKit yüz takibini desteklemiyorsa (TrueDepth'siz A11 ve öncesi): `livenessDetection` / `selfieWithLiveness` yerine ne konacağını belirler — `.selfie` (varsayılan) ya da `.skip` |
| `selfieWithLivenessTrueDepth` | Selfie + canlılık ekranının derinlik kullanımı: `.automatic` (varsayılan), `.required` (yalnız TrueDepth kamerada), `.disabled` (ARKit yok, Vision ile her cihazda — derinlik koruması yok). [Ayrıntı](../../../IdentifySample/Modules/SelfieWithLiveness/SelfieWithLiveness.md#truedepth-modu) |
| NFC | iPad'de ve NFC'siz iPhone'larda modül otomatik çıkarılır; panele `NFCStatus = notAvailable` gider. Bilgi sayfası için `setupSDK(..., showNFCNotFoundPage: true)` |
| `SDKHapticConfig` | Çekim rampası + canlılık adım darbesi; ikisi de kapatılabilir |

Dart tarafında bu durumları olaylardan izlersiniz: atlanan adım `module.<Modül>.skipped`
olarak gelir.

SDK iPhone ve iPad'de çalışır, yönelim ikisinde de portrait'e kilitlidir.
Ayrıntı: [iPad Desteği](../../guides/ipad-support.md).

---

## 3) Olay (SDKEvent) yapısı

EventChannel, native `SDKEvent.toDictionary()` çıktısını **olduğu gibi** Dart'a iletir.
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
| `module.<Modül>.completed` | module | Modül bitince | Adım başarıyla tamamlandı |
| `module.<Modül>.failed` | module | Modül hata | Adım başarısız |
| `module.<Modül>.skipped` | module | Atlanınca | Adım atlandı |
| `call.connected` | call | Çağrı başlayınca | Görüşme başladı |
| `call.ended` | call | Çağrı bitince | Görüşme bitti (metadata['statusSummary']) |
| `session.finished` | session | Oturum nasıl biterse bitsin, bir kez | Nihai sonuç: `metadata['result']`, `endReason`, `terminateReason`, `statusSummary`, `lastModule` (3.1.0) |
| `session.completed` | session | `result == approved` | Oturum **başarıyla** kapandı (status `success`) |
| `session.failed` | session | `rejected` · `neutral` · `notCompleted` · `error` | Oturum **başarısız** kapandı |
| `session.abandoned` | session | `cancelled` | Kullanıcı ya da host çıktı (metadata['lastScreen'] = nerede kaldı) |

Metadata anahtarlarının tamamı: [Event Sistemi → Oturum Sonucu Olayları](../../guides/events.md#oturum-sonucu-olayları-301) · tüm çıkış yolları ve kapanış sonrası yönlendirme: [Oturum Çıkışları](../../guides/session-exit.md#95-react-native--flutter).

> **Geriye uyumluluk:** Bu birleşik akış, SDK'nın mevcut `IdentifyTrackingListener`
> mekanizmasının **yanına** eklenmiştir; mevcut entegrasyonları bozmaz.
