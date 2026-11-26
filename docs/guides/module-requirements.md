# Modül Gereksinimleri

Bu tablo, her modülün host uygulamada istediği Info.plist anahtarlarını, ek ayarları, kütüphaneleri
ve cihaz yeteneklerini gösterir. Modül listesi oturum başında backend'den gelir, bu yüzden uygulamanıza kendi akışınızda
çıkabilecek bütün modüllerin anahtarlarını ekleyin.

## Modüller

| Modül (`SdkModules`) | Info.plist anahtarı | Ek ayar | Paket | Sistem framework'ü | Cihaz yeteneği |
|---|---|---|---|---|---|
| Hazırlık (`prepare`) | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | | | `AVFoundation`, `Speech` | Kamera, mikrofon |
| Kimlik (`idCard`) | `NSCameraUsageDescription` | | | `AVFoundation`, `Vision` | Arka kamera |
| Kimlik OVD (`idcard_w_ovd`) | `NSCameraUsageDescription` | | | `AVFoundation`, `Vision` | Arka kamera |
| NFC (`nfc`) | `NFCReaderUsageDescription`, `com.apple.developer.nfc.readersession.iso7816.select-identifiers` listesinde `A0000002471001` | Near Field Communication Tag Reading yeteneği: `com.apple.developer.nfc.readersession.formats` içinde `TAG` | `OpenSSL` | `CoreNFC` | NFC. iPad'de yok, modül akıştan çıkarılır. `setupSDK(showNFCNotFoundPage: true)` verilirse ekran akışta kalır |
| Selfie (`selfie`) | `NSCameraUsageDescription` | | | `AVFoundation`, `Vision` | Ön kamera |
| Canlılıklı selfie (`selfieWithLiveness`) | `NSCameraUsageDescription` | | | `AVFoundation`, `ARKit` | ARKit yüz takibi: TrueDepth kamera ya da A12+ çip. Yoksa `faceTrackingFallback`'e göre selfie gelir ya da adım çıkar. `selfieWithLivenessTrueDepth = .required` iken TrueDepth şart. `.disabled` iken ARKit gerekmez, adım Vision ile her cihazda, derinlik koruması olmadan çalışır |
| Canlılık (`livenessDetection`) | `NSCameraUsageDescription` | | | `ARKit`, `ReplayKit` | ARKit yüz takibi: TrueDepth kamera ya da A12+ çip. Yoksa `faceTrackingFallback`'e göre selfie gelir ya da adım çıkar |
| Video kayıt (`videoRecord`) | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` | | | `AVFoundation` | Kamera, mikrofon |
| Konuşma (`speech`) | `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | | | `AVFoundation`, `Speech` | Mikrofon |
| Görüntülü görüşme (`waitScreen`) | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` | | `WebRTC` | `AVFoundation` | Kamera, mikrofon. Kamera bulunamazsa görüşme kamerasız sürer |
| İmza (`signature`) | Yok | | | | Yok |
| Adres onayı (`addressConf`) | `NSCameraUsageDescription` (belge tarayıcısı için) | | | `PhotosUI`, `AVFoundation`, `Vision` | Arka kamera (belge tarayıcısı) |
| Giriş (`login`), Teşekkür (`thankU`) | Yok | | | | Yok |

Adres onayı fotoğrafı sistem seçicisiyle (`PHPickerViewController`) alır, bu yüzden fotoğraf arşivi
izni istemez. Belge tarayıcısı ise kamera ister.

Canlılık modülü ekranı `ReplayKit` ile kaydeder. Mikrofon bu kayıtta kapalıdır.

## Hazırlık ekranı üç izni birden ister

Hazırlık modülü akıştaysa kamera, mikrofon ve konuşma tanıma izinlerinin üçü de verilmeden sonraki
adıma geçilmez. Akışta konuşma modülü olmasa da bu böyledir. Hazırlık ekranını kullanan her uygulama
`NSSpeechRecognitionUsageDescription` anahtarını da eklemelidir.

## Modül açılınca izin istenir

Her modül gereken izni ekranı açılırken ister; akışta Hazırlık modülü olmasa da bu böyledir. İzin verilmezse ayarlara yönlendiren popup çıkar. Kullanıcı "Vazgeç"e basarsa popup, izin verilene kadar uygulamaya her dönüşte yeniden çıkar.

Adres onayı bu kuralın dışında kalır. Ekran açılırken izin istemez. Kamera iznini belge tarayıcısı
açılırken doğrudan sistemden ister (`AVCaptureDevice.requestAccess`). İzin verilmezse popup
çıkmaz; tarayıcı kapanır ve adres ekranı bir şey göstermez.

Sistem izin penceresindeki açıklama uygulamanın Info.plist dosyasından gelir. Uygulama birden fazla dil destekliyorsa bu metinleri `InfoPlist.strings` ya da `InfoPlist.xcstrings` ile her dile çevirin. Çevrilmezse pencere her dilde aynı metni gösterir.

İzinleri kendiniz yönetiyorsanız `SDKPermissionConfig.shared.provider` ile kendi izin katmanınızı
bağlayabilirsiniz. Adres ekranındaki belge tarayıcısının kamera isteği bu katmandan geçmez.

## Paket bağımlılıkları

| Paket | Sürüm | Kullanan |
|---|---|---|
| [OpenSSL](https://github.com/krzyzanowskim/OpenSSL) | `exact: "3.6.5000"` | NFC kripto ve sertifika doğrulama |
| [WebRTC](https://github.com/stasel/WebRTC) | `exact: "153.0.0"` | Görüntülü görüşme |

SDK tek bir ikili dosya olarak dağıtılır. Bu iki paket, akışınızda NFC ya da görüşme olmasa da
projeye gelir, modül başına çıkarılamaz.

`PermissionsKit` ve `SwiftSignatureView` 3.2.1'den itibaren SDK ile gelmez.

`Starscream` 3.3.0'dan itibaren SDK ile gelmez: `IdentifyManager.shared.socket` SDK'nın kendi
`SDKWebSocket` tipindedir. `import Starscream` satırlarını kaldırın.

## Tablo nasıl güncel kalır

SDK'da bir modülün izni, Info.plist anahtarı, paketi ya da cihaz yeteneği değişirse bu tablo aynı
değişiklikte güncellenir ve değişiklik CHANGELOG'da sürüm notuna yazılır. SDK'nın birim testleri
bu sayfayı kodla karşılaştırır: SDK'daki her modülün tabloda bir satırı olmalı, paket sürümleri de
SDK projesindeki ve yayın betiğindeki sürümlerle aynı olmalı. Biri tutmazsa test kırmızıya döner.

## Diğer ayarlar

iPad hedefi ve sahne ayarları modülden bağımsızdır. Ayrıntı için [iPad Desteği](ipad-support.md) ve
[iPhone Duo Desteği](iphone-duo.md) rehberlerine bakın.
