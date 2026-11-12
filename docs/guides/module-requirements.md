# Modül Gereksinimleri

Bu tablo, her modülün host uygulamada istediği Info.plist anahtarlarını, ek ayarları ve kütüphaneleri
gösterir. Modül listesi oturum başında backend'den gelir, bu yüzden uygulamanıza kendi akışınızda
çıkabilecek bütün modüllerin anahtarlarını ekleyin.

## Modüller

| Modül (`SdkModules`) | Info.plist anahtarı | Ek ayar | Paket | Sistem framework'ü |
|---|---|---|---|---|
| Hazırlık (`prepare`) | Akıştaki modüllerin anahtarları | | | Akıştaki modüllerin çerçeveleri |
| Kimlik (`idCard`) | `NSCameraUsageDescription` | | | `AVFoundation`, `Vision` |
| Kimlik OVD (`idcard_w_ovd`) | `NSCameraUsageDescription` | | | `AVFoundation`, `Vision` |
| NFC (`nfc`) | `NFCReaderUsageDescription`, `com.apple.developer.nfc.readersession.iso7816.select-identifiers` listesinde `A0000002471001` | Near Field Communication Tag Reading yeteneği: `com.apple.developer.nfc.readersession.formats` içinde `TAG` | `OpenSSL` | `CoreNFC` |
| Selfie (`selfie`) | `NSCameraUsageDescription` | | | `AVFoundation`, `Vision` |
| Canlılıklı selfie (`selfieWithLiveness`) | `NSCameraUsageDescription` | | | `AVFoundation`, `ARKit` |
| Canlılık (`livenessDetection`) | `NSCameraUsageDescription` | | | `ARKit`, `ReplayKit` |
| Video kayıt (`videoRecord`) | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` | | | `AVFoundation` |
| Konuşma (`speech`) | `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | | | `AVFoundation`, `Speech` |
| Görüntülü görüşme (`waitScreen`) | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` | | `WebRTC` | `AVFoundation` |
| İmza (`signature`) | Yok | | | |
| Adres onayı (`addressConf`) | Yok | | | `PhotosUI` |
| Giriş (`login`), Teşekkür (`thankU`) | Yok | | | |

Adres onayı fotoğrafı sistem seçicisiyle (`PHPickerViewController`) alır, bu yüzden fotoğraf arşivi
izni istemez.

Canlılık modülü ekranı `ReplayKit` ile kaydeder. Mikrofon bu kayıtta kapalıdır.

## İzinler modül açılınca istenir

Her modül kendi iznini ekranı açılırken ister. Kullanıcı izni vermezse ayarlara yönlendiren popup
çıkar.

Hazırlık modülü akıştaysa yalnız akıştaki modüllerin izinlerini listeler ve bunlar verilmeden sonraki
adıma geçilmez. Akışta konuşma modülü yoksa konuşma tanıma izni istenmez,
`NSSpeechRecognitionUsageDescription` anahtarı da gerekmez.

İzinleri kendiniz yönetiyorsanız `SDKPermissionConfig.shared.provider` ile kendi izin katmanınızı
bağlayabilirsiniz.

## Paket bağımlılıkları

| Paket | Sürüm | Kullanan |
|---|---|---|
| [OpenSSL](https://github.com/krzyzanowskim/OpenSSL) | `exact: "3.6.5000"` | NFC kripto ve sertifika doğrulama |
| [WebRTC](https://github.com/stasel/WebRTC) | `exact: "153.0.0"` | Görüntülü görüşme |

SDK tek bir ikili dosya olarak dağıtılır. Bu iki paket, akışınızda NFC ya da görüşme olmasa da
projeye gelir, modül başına çıkarılamaz.

`PermissionsKit` ve `SwiftSignatureView` 3.2.1'den itibaren SDK ile gelmez.

## Diğer ayarlar

iPad hedefi ve sahne ayarları modülden bağımsızdır. Ayrıntı için [iPad Desteği](ipad-support.md) ve
[iPhone Duo Desteği](iphone-duo.md) rehberlerine bakın.
