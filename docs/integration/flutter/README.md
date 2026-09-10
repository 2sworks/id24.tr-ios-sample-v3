# IdentifySDK — Flutter Entegrasyonu

Bu rehber, `IdentifySDK` (iOS KYC kimlik doğrulama SDK'sı) için bir **Flutter plugin
köprüsü** kurmayı ve SDK'nın **birleşik olay akışını** (SDKEvent) Dart tarafında bir
`Stream` olarak dinlemeyi anlatır. Köprü iskeleti bu klasördedir.

> SDK yalnızca iOS'tur. Android için ayrı bir SDK gerekir (bu pakette yoktur);
> plugin'i `Platform.isIOS` ile koşullayın.

---

## 1) Kurulum

### iOS native bağımlılığı
Plugin'inizin `ios/` tarafında `IdentifySDK`'yı Swift Package Manager veya CocoaPods
ile ekleyin (XCFramework + OpenSSL/Starscream/WebRTC/SwiftSignatureView/PermissionsKit).

`ios/Runner/Info.plist` izinleri:

```xml
<key>NSCameraUsageDescription</key><string>Kimlik doğrulama için kamera</string>
<key>NSMicrophoneUsageDescription</key><string>Görüntülü görüşme için mikrofon</string>
<key>NFCReaderUsageDescription</key><string>Kimlik/pasaport çipi okuma</string>
```

### Köprü dosyaları
| Dosya | Konum | Görev |
|---|---|---|
| `IdentifySdkPlugin.swift` | `ios/Classes/` | MethodChannel (setupSDK) + EventChannel (olaylar) |
| `identify_sdk.dart`       | `lib/`         | Dart sarmalayıcı + `SDKEvent` modeli + `Stream` |

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
  showThankYouPage: true,
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
  'navBar': {'preset': 'centered', 'showsDivider': true},  // classic | centered | minimal | prominent
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

SDKHapticConfig.shared.stepFeedbackEnabled = true       // canlılık adım titreşimi (vars. açık)
SDKHapticConfig.shared.stepFeedbackIntensity = 0.6      // 0…1
```

| Ne | Ne zaman devreye girer |
|---|---|
| `faceTrackingFallback` | Cihazda TrueDepth kamera yoksa (Touch ID'li iPad, Face ID'siz iPhone): `livenessDetection` / `selfieWithLiveness` yerine ne konacağını belirler — `.selfie` (varsayılan) ya da `.skip` |
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
| `session.completed` | session | Onay | Oturum **başarıyla** kapandı (status `success`) |
| `session.failed` | session | Ret | Oturum **başarısız** kapandı |
| `session.abandoned` | session | Terk/kapatma | Kullanıcı yarıda bıraktı (metadata['lastScreen'] = nerede kaldı) |

> **Geriye uyumluluk:** Bu birleşik akış, SDK'nın mevcut `IdentifyTrackingListener`
> mekanizmasının **yanına** eklenmiştir; mevcut entegrasyonları bozmaz.
