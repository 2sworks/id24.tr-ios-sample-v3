# IdentifySDK — React Native Entegrasyonu

Bu rehber, `IdentifySDK` (iOS KYC kimlik doğrulama SDK'sı) için bir **React Native köprü
modülü** kurmayı ve SDK'nın **birleşik olay akışını** (SDKEvent) JS tarafında dinlemeyi
anlatır. Köprü iskeleti bu klasördedir; kopyalayıp projenize uyarlayabilirsiniz.

> SDK yalnızca iOS'tur. Bu köprü iOS native tarafını sarar; Android için ayrı bir SDK
> gerekir (bu pakette yoktur).

---

## 1) Kurulum

`IdentifySDK` bir XCFramework olup Swift Package Manager ile dağıtılır.

### Swift Package Manager (önerilen)
React Native projenizin iOS `Podfile`'ı varsa bile SDK'yı SPM ile ekleyebilirsiniz:
Xcode → **File → Add Packages** →

```
https://github.com/2sworks/id24.tr-ios-sdk-spm
```

Bu paket runtime bağımlılıklarını da getirir: OpenSSL, Starscream, WebRTC,
SwiftSignatureView, PermissionsKit.

### CocoaPods (alternatif)
`ios/Podfile` içine binary framework'ü ve bağımlılıklarını ekleyin, ardından:

```bash
cd ios && pod install
```

`Info.plist` izinleri (kamera/NFC/mikrofon) gereklidir:

```xml
<key>NSCameraUsageDescription</key><string>Kimlik doğrulama için kamera</string>
<key>NSMicrophoneUsageDescription</key><string>Görüntülü görüşme için mikrofon</string>
<key>NFCReaderUsageDescription</key><string>Kimlik/pasaport çipi okuma</string>
```
NFC için ayrıca `*.entitlements` dosyasına `com.apple.developer.nfc.readersession.formats`.

---

## 2) Native köprü dosyaları

Bu klasördeki dosyaları `ios/` altına kopyalayın:

| Dosya | Görev |
|---|---|
| `IdentifySdkModule.swift` | `RCTEventEmitter` köprüsü: `setupSDK` + olay yayını |
| `IdentifySdkModule.m`     | Obj-C `RCT_EXTERN_MODULE` köprü kaydı |
| `IdentifySdk.ts`          | JS/TS sarmalayıcı + tip tanımlı `SDKEvent` |

`AppDelegate` köprü başlığına (`<App>-Bridging-Header.h`) ekleyin:

```objc
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
```

---

## 3) Kullanım (JS/TS)

```ts
import { IdentifySdk, SDKEvent } from './IdentifySdk';

// 1) Olay akışına abone ol — SDK'nın "nerede ne yaptığını" tek akıştan al
const sub = IdentifySdk.addEventListener((event: SDKEvent) => {
  console.log(event.name, event.category, event.status, event.screen);

  switch (event.name) {
    case 'session.started':   /* oturum başladı */ break;
    case 'session.completed': /* başarıyla kapandı (event.status === 'success') */ break;
    case 'session.failed':    /* başarısız (event.metadata.reason) */ break;
    case 'session.abandoned': /* kullanıcı terk etti (event.metadata.lastScreen) */ break;
  }
});

// 2) SDK'yı başlat
await IdentifySdk.setupSDK({
  identId: 'XXXX-XXXX',
  baseApiUrl: 'https://api.example.com/',
  turnKey: 'turn-secret',
  signLangSupport: false,
  nfcMaxErrorCount: 3,
  selectedModules: [],          // boş = backend'in döndürdüğü sıra
  showThankYouPage: true,
});

// 3) Temizlik
sub.remove();
```

### Hata kontrolü — `E_SETUP` tuzağı

`setupSDK` geri çağrısındaki hata parametresi **her zaman doludur**; başarılı kurulumda
`errorMessages` boş string olur. Bu yüzden köprüde

```swift
if let error = error { reject("E_SETUP", ...) }   // YANLIŞ — başarıda da çalışır
```

yazılırsa akış hiç başlamadan `E_SETUP` ile reddedilir ve JS tarafında mesajı boş bir
hata görülür. Doğru kontrol mesajın dolu olup olmadığıdır:

```swift
if let message = error?.errorMessages, !message.isEmpty { reject("E_SETUP", message, nil); return }
guard socket?.isConnected == true, roomResponse.result == true else { ... }
```

`IdentifySdkModule.swift` bu kontrolü zaten doğru yapar; kendi köprünüzü yazarken aynı
deseni koruyun.

---

## 3.1) Tema — native derleme olmadan

SDK'nın hazır ekranlarının görünümü JS'ten uygulanır; renk/logo/köşe denemesi için
**yeniden derleme gerekmez**, JS reload yeterlidir.

```ts
const { unknownKeys } = await IdentifySdk.setTheme({
  colors: {
    primary: '#0F172A',
    pageBackground: { light: '#F8FAFC', dark: '#0B1120' },
    selectedItemBackground: '#1D4ED8',
    headerBackground: { light: '#0F172A', dark: '#0B1120' },
    headerTitle: '#FFFFFF',
  },
  navBar: { preset: 'centered', showsDivider: true },  // classic | centered | minimal | prominent
  buttons: { corner: 12, height: 54, styles: { secondary: { borderWidth: 1 } } },
  icons: { headerLogo: 'my_mark' },   // iOS asset kataloğundaki görsel adı
});

if (unknownKeys.length) console.warn('Tema: tanınmayan anahtar', unknownKeys);

IdentifySdk.resetTheme();   // SDK varsayılanlarına dön
```

Şemanın tamamı `IdentifySdk.ts` içindeki `SDKThemeConfig` tipindedir; bölümler:
`colors`, `fonts`, `metrics`, `buttons`, `navBar`, `selection`, `alerts`, `banners`,
`fields`, `sheets`, `capture`, `controls`, `call`, `motion`, `icons`.

> **Header'daki marka işareti** `icons.logo` değil `icons.headerLogo`'dur. `logo` giriş
> ekranı ve kamera üstü başlıkta kullanılır.

`icons` değerleri host uygulamanızın **asset kataloğundaki** görsel adlarıdır; yeni bir
görsel eklemek native tarafı ilgilendirir, ama var olan görseller arasında geçiş ve tüm
renk/ölçü ayarları JS'ten yapılır.

## 3.2) Akışın kapanış animasyonu

SDK akışı kendini sunmaz ve **kapatmaz** — sunum da kapanış da host uygulamaya aittir.
"Ekran animasyonsuz kapanıyor" durumu, akışın barındığı görünümün animasyonsuz
kaldırılmasından gelir.

React Native tarafında akışı bir modal içinde gösteriyorsanız:

```tsx
<Modal visible={flowVisible} animationType="slide" presentationStyle="fullScreen">
  {/* akış */}
</Modal>
```

Native tarafta kendi controller'ınızı sunuyorsanız:

```swift
host.modalPresentationStyle = .fullScreen
host.modalTransitionStyle = .coverVertical     // yukarıdan aşağı kapanış
presenter.present(host, animated: true)
...
host.dismiss(animated: true)                   // animated: false ANINDA kapatır
```

Akış içindeki adım geçişlerinin süresi tema üzerinden ayarlanır:

```ts
await IdentifySdk.setTheme({ motion: { transitionDuration: 0.35 } });
```

## 3.3) Cihaz yetenekleri — native tarafta ayarlanır

Bunlar tema değil **akış politikasıdır** ve köprüden geçmez; `IdentifySdkModule.swift`
içinde, `setupSDK` çağrısından **önce** ayarlanır:

```swift
// IdentifySdkModule.swift — setupSDK'dan önce
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

JS tarafında bu durumları olaylardan izlersiniz: atlanan adım
`module.<Modül>.skipped` olarak gelir.

SDK iPhone ve iPad'de çalışır, yönelim ikisinde de portrait'e kilitlidir.
Ayrıntı: [iPad Desteği](../../guides/ipad-support.md).

## 4) Olay (SDKEvent) yapısı

Köprü, native `SDKEvent.toDictionary()` çıktısını **olduğu gibi** JS'e iletir:

```ts
interface SDKEvent {
  name: string;        // "session.started", "module.Selfie.completed", "call.ended"
  category: 'session' | 'module' | 'call' | 'network' | 'error' | 'navigation';
  status: 'info' | 'presented' | 'completed' | 'failed'
        | 'skipped' | 'success' | 'abandoned' | 'notFound';
  module?: string;     // "Selfie", "Mrz & Nfc Screen" ...
  screen?: string;     // kullanıcının o anki/son ekranı
  sessionId: string;
  timestampMs: number;
  message?: string;
  metadata: Record<string, string>;  // reason, statusSummary, lastScreen ...
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
| `call.connected` | call | Çağrı başlayınca | Temsilciyle görüşme başladı |
| `call.ended` | call | Çağrı bitince | Görüşme bitti (metadata.statusSummary) |
| `session.completed` | session | Onay | Oturum **başarıyla** kapandı (status `success`) |
| `session.failed` | session | Ret | Oturum **başarısız** kapandı |
| `session.abandoned` | session | Terk/kapatma | Kullanıcı yarıda bıraktı (metadata.lastScreen = nerede kaldı) |

> **Geriye uyumluluk:** Bu birleşik akış, SDK'nın mevcut `IdentifyTrackingListener`
> mekanizmasının **yanına** eklenmiştir; mevcut entegrasyonları bozmaz.
