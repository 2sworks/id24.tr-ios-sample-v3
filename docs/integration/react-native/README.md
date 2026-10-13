# IdentifySDK — React Native Entegrasyonu

Bu rehber, iOS KYC SDK'sı `IdentifySDK` için bir React Native köprü modülünün nasıl kurulacağını
ve SDK'nın olay akışının (SDKEvent) JS tarafında nasıl dinleneceğini anlatır. Köprünün iskelet
dosyaları bu klasörde; kopyalayıp projenize uyarlayabilirsiniz.

> SDK yalnızca iOS'ta çalışır. Bu köprü iOS native tarafını sarar. Android için ayrı bir SDK
> gerekir ve bu pakette yoktur.

---

## 1) Kurulum

`IdentifySDK` bir XCFramework ve Swift Package Manager ile dağıtılıyor.

### Swift Package Manager (önerilen)
React Native projenizin iOS tarafında `Podfile` olsa bile SDK'yı SPM ile ekleyebilirsiniz:
`ios/<App>.xcworkspace` → **File → Add Packages** →

```
https://github.com/2sworks/id24.tr-ios-sdk-spm
```

Dependency Rule'u `Exact Version` yapın (ör. `3.0.0`). 2.x ve 3.x aynı depodan dağıtılıyor;
Xcode'un varsayılan *Up to Next Major* kuralı en son etiketten başladığı için yanlış sürümü
çekebilir. Ayrıntı: [ana README §1](../../../README.md#1-paketi-ekleyin-swift-package-manager).

Paket çalışma zamanı bağımlılıklarını da beraberinde getirir: OpenSSL, Starscream, WebRTC,
SwiftSignatureView, PermissionsKit.

### CocoaPods (alternatif)
`ios/Podfile` içine binary framework'ü ve bağımlılıklarını ekleyin, ardından:

```bash
cd ios && pod install
```

`Info.plist`'e kamera, NFC ve mikrofon izinlerini ekleyin:

```xml
<key>NSCameraUsageDescription</key><string>Kimlik doğrulama için kamera</string>
<key>NSMicrophoneUsageDescription</key><string>Görüntülü görüşme için mikrofon</string>
<key>NFCReaderUsageDescription</key><string>Kimlik/pasaport çipi okuma</string>
```
NFC için `*.entitlements` dosyasına ayrıca `com.apple.developer.nfc.readersession.formats` ekleyin.

---

## 2) Native köprü dosyaları

Bu klasördeki dosyaları aşağıdaki konumlara kopyalayın. Swift ve Obj-C dosyalarını Xcode'da
uygulama target'ına ekleyin: sürükleyip bırakırken "Copy items if needed" ve target kutusunu
işaretleyin (Target Membership açık olmalı).

| Dosya | Hedef | Görev |
|---|---|---|
| `IdentifySdkModule.swift` | `ios/<App>/IdentifySdkModule.swift` | `RCTEventEmitter` köprüsü: `setupSDK` + `setTheme` + olay yayını |
| `IdentifySdkModule.m`     | `ios/<App>/IdentifySdkModule.m` | Obj-C `RCT_EXTERN_MODULE` köprü kaydı |
| `IdentifySdk.ts`          | `src/native/IdentifySdk.ts` | JS/TS sarmalayıcı + tip tanımlı `SDKEvent` + `SDKThemeConfig` |
| `../theme.example.json`   | `src/theme/identifyTheme.json` | İsteğe bağlı başlangıç teması; `setTheme` ile gönderilir |

Köprünün JS'e açtığı metotlar:

| JS/TS | Native karşılığı | Ne zaman |
|---|---|---|
| `IdentifySdk.setTheme(config)` → `{ unknownKeys }` | `SDKTheme.shared.apply(dict)` | `setupSDK`'dan önce. JS reload yeterli, derleme gerekmez |
| `IdentifySdk.resetTheme()` | `SDKTheme.shared.resetAppearance()` | SDK varsayılanlarına dönmek için |
| `IdentifySdk.setupSDK(options)` | `IdentifyManager.shared.setupSDK(...)` + akışı sunar | Akışı başlatır |
| `IdentifySdk.addEventListener(h)` | `SDKEventListener` → `RCTEventEmitter` | `setupSDK`'dan önce bağlayın |
| `IdentifySdk.reportAbandoned(reason)` | `IdentifyManager.shared.reportSessionAbandoned(reason:)` | Kullanıcı akışı JS tarafında terk ettiğinde |

### Örnek uygulamadan kopyalanacaklar (iOS tarafı)

Ekranlar XCFramework'ün içinde olduğu için köprü dosyaları dışında örnekten bir şey almanız
gerekmez. İki istisna var:

| Kaynak | Hedef | Ne zaman |
|---|---|---|
| `IdentifySample/SupportingFiles/*.cer` | `ios/<App>/` + *Copy Bundle Resources* | `useSslPinning: true` ise zorunlu |
| `IdentifySample/Modules/<Modül>/<Modül>CustomView.swift` (kamera kullananlarda ayrıca `IdentifySample/Modules/CustomKit/CustomCameraPreview.swift` + `CustomComponents.swift`) | `ios/<App>/Modules/` | Bir SDK ekranını native tarafta kendi tasarımınızla değiştirecekseniz (`registry.override`). Bu dosya SDK ekranının public API ile yazılmış, çalışan bir kopyasıdır; özelleştirmeyi bunun üzerinde yaparsınız. JS'ten ekran değiştirilemez |

`IdentifySample/Modules/Login/LoginViewModel.swift` ile `App/RootView.swift`'i kopyalamanız
gerekmez ama okuyun: `prepareForSetup()` → `setupSDK` → `start()` sırası ve akışın
`SDKFlowHostView` ile gösterilmesi orada çalışan haliyle duruyor.

JS'ten yapılamayan üç şeyi `IdentifySdkModule.swift` içinde yaparsınız:

| Ne | Nerede |
|---|---|
| Yeni bir görsel (logo) eklemek | iOS asset kataloğu. JS yalnızca görselin adını gönderir (`icons.headerLogo`) |
| Dil ve metin override'ı | `setupSDK` dalının başına `IdentifyManager.shared.setSDKLang(lang:)` ve `SDKLocalization.shared.registerOverrides([.tr: ["IdVerifyTitle": "…"]])` ekleyin. İsterseniz `options.language` alanı ekleyip dili JS'ten geçirin (3 satır) |
| Cihaz yeteneği politikası (TrueDepth ya da NFC yoksa) | bkz. [§3.3](#33-cihaz-yetenekleri--native-tarafta-ayarlanır) |

Köprü başlığına (`<App>-Bridging-Header.h`) şunları ekleyin:

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
    case 'session.finished':  /* NİHAİ sonuç, oturum başına bir kez:
                                 event.metadata.result    → approved | rejected | neutral | notCompleted | cancelled | error
                                 event.metadata.endReason → agentDecision | userEndedCall | moduleFailed | …
                                 event.metadata.terminateReason / statusSummary → panel kapattıysa birebir */ break;
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
  showThankYouPage: true,       // false: sonuç ekranı yok, SDK kapanır — sonucu 'session.finished' ile alın
});

// 3) Temizlik
sub.remove();
```

### Hata kontrolü — `E_SETUP` tuzağı

`setupSDK` geri çağrısındaki hata parametresi hiçbir zaman `nil` gelmez; kurulum başarılıysa
`errorMessages` boş string olur. Köprüde şöyle yazarsanız:

```swift
if let error = error { reject("E_SETUP", ...) }   // YANLIŞ — başarıda da çalışır
```

akış daha başlamadan `E_SETUP` ile reddedilir ve JS tarafında mesajı boş bir hata görürsünüz.
Mesajın dolu olup olmadığına bakın:

```swift
if let message = error?.errorMessages, !message.isEmpty { reject("E_SETUP", message, nil); return }
guard socket?.isConnected == true, roomResponse.result == true else { ... }
```

`IdentifySdkModule.swift` bu kontrolü zaten doğru yapıyor. Kendi köprünüzü yazarsanız aynı deseni
kullanın.

---

## 3.1) Tema — native derleme olmadan

SDK'nın hazır ekranlarının görünümünü JS'ten ayarlarsınız. Renk, logo ya da köşe denerken yeniden
derlemeniz gerekmez; JS reload yeterli.

```ts
const { unknownKeys } = await IdentifySdk.setTheme({
  colors: {
    primary: '#0F172A',
    pageBackground: { light: '#F8FAFC', dark: '#0B1120' },
    selectedItemBackground: '#1D4ED8',
    headerBackground: { light: '#0F172A', dark: '#0B1120' },
    headerTitle: '#FFFFFF',
  },
  navBar: { preset: 'centered', showsDivider: true,     // classic | centered | minimal | prominent
           brandTitle: 'Acme Bank', titleMode: 'brandWithModule' },  // marka: üst satır marka, alt satır adım adı
  buttons: { corner: 12, height: 54, styles: { secondary: { borderWidth: 1 } } },
  icons: { headerLogo: 'my_mark' },   // iOS asset kataloğundaki görsel adı
});

if (unknownKeys.length) console.warn('Tema: tanınmayan anahtar', unknownKeys);

IdentifySdk.resetTheme();   // SDK varsayılanlarına dön
```

Şemanın tamamı `IdentifySdk.ts` içindeki `SDKThemeConfig` tipinde. Bölümler:
`colors`, `fonts`, `metrics`, `buttons`, `navBar`, `selection`, `alerts`, `banners`,
`fields`, `sheets`, `capture`, `controls`, `call`, `motion`, `icons`.

> Başlık çubuğundaki marka işaretinin anahtarı `icons.headerLogo`. `icons.logo` giriş ekranında
> ve kamera ekranlarının üstündeki başlıkta kullanılır.

`icons` değerleri host uygulamanızın asset kataloğundaki görsel adlarıdır. Yeni bir görsel eklemek
native tarafta yapılır; var olan görseller arasında geçişi ve bütün renk ve ölçü ayarlarını ise
JS'ten yaparsınız.

Başlık çubuğundaki geri, yardım ("?") ve menü düğmelerini `navBar.buttons` ile gizleyebilirsiniz
(`showsBack`, `showsHelp`, `showsMenu`). Kendi düğmenizi eklemek ve yardım düğmesine iş bağlamak
Swift closure'ı gerektirdiği için `IdentifySdkModule.swift` içinde yapılır. Ayrıntı:
[Tema Rehberi → Başlık Çubuğu Düğmeleri](../../guides/theming.md#başlık-çubuğu-düğmeleri).

## 3.2) Akışın kapanış animasyonu

SDK akışı kendisi sunmaz ve kendisi kapatmaz; ikisi de host uygulamanın işi. Ekran animasyonsuz
kapanıyorsa sebep, akışın içinde durduğu görünümün animasyonsuz kaldırılmasıdır.

React Native'de akışı bir modal içinde gösteriyorsanız:

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

Akış içindeki adım geçişlerinin süresini temadan ayarlarsınız:

```ts
await IdentifySdk.setTheme({ motion: { transitionDuration: 0.35 } });
```

## 3.3) Cihaz yetenekleri — native tarafta ayarlanır

Bu ayarlar tema değil, akış politikası; köprüden geçmez. `IdentifySdkModule.swift` içinde
`setupSDK` çağrısından önce ayarlanır:

```swift
// IdentifySdkModule.swift — setupSDK'dan önce
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

JS tarafında bu durumları olaylardan takip edersiniz: atlanan adım `module.<Modül>.skipped`
olarak gelir.

SDK iPhone ve iPad'de çalışır; ekran ikisinde de dikey konuma kilitlidir.
Ayrıntı: [iPad Desteği](../../guides/ipad-support.md).

## 4) Olay (SDKEvent) yapısı

Köprü, native `SDKEvent.toDictionary()` çıktısını değiştirmeden JS'e iletir:

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
| `module.<Modül>.completed` | module | Modül bittiğinde | Adım başarıyla tamamlandı |
| `module.<Modül>.failed` | module | Modül hata verdiğinde | Adım başarısız |
| `module.<Modül>.skipped` | module | Modül atlandığında | Adım atlandı |
| `call.connected` | call | Çağrı başladığında | Temsilciyle görüşme başladı |
| `call.ended` | call | Çağrı bittiğinde | Görüşme bitti (metadata.statusSummary) |
| `session.finished` | session | Oturum nasıl biterse bitsin, bir kez | Nihai sonuç: `metadata.result`, `endReason`, `terminateReason`, `statusSummary`, `lastModule` (3.1.0) |
| `session.completed` | session | `result == approved` | Oturum başarıyla kapandı (status `success`) |
| `session.failed` | session | `rejected` · `neutral` · `notCompleted` · `error` | Oturum başarısız kapandı |
| `session.abandoned` | session | `cancelled` | Kullanıcı ya da host çıktı (metadata.lastScreen kullanıcının kaldığı ekran) |

Metadata anahtarlarının tamamı: [Event Sistemi → Oturum Sonucu Olayları](../../guides/events.md#oturum-sonucu-olayları-310) · bütün çıkış yolları ve kapanıştan sonra yönlendirme: [Oturum Çıkışları](../../guides/session-exit.md#95-react-native--flutter).

> Bu olay akışı SDK'daki `IdentifyTrackingListener`'ın yanına eklendi, onun yerini almadı.
> Mevcut entegrasyonlar olduğu gibi çalışmaya devam eder.
