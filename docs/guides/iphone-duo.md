# iPhone Duo Desteği

iPhone Duo katlanan bir telefon: kapalıyken dar bir dış ekran, açıkken geniş bir iç ekran
kullanılıyor. SDK'nın modül ekranları iki ekranda da dikey ve yatay duruşta yerine oturuyor. Bu
rehber, kendi ekranlarınızı ve uygulama kabuğunuzu Duo'ya hazırlarken dikkat etmeniz gerekenleri
anlatıyor.

---

## Özet

| Konu | Yapılacak |
|---|---|
| Uygulama yaşam döngüsü | Sahne (`UIScene`) yaşam döngüsü kullanın. iOS 27 SDK'sıyla derlenen ve sahne kullanmayan uygulama Duo'da açılmıyor |
| Pencere | Pencereyi etkin sahneden alın: `SDKLayout.activeWindow` |
| Ölçü | Genişliği ve yüksekliği pencereden alın: `SDKLayout.bounds` |
| Güvenli alan | Dış ekranda durum çubuğu sağ kenarda durur, sağda yaklaşık 88 pt pay vardır |
| Yönelim | Dikey kilit ve `UIRequiresFullScreen = YES`; iç ekranda uygulama ortada dikey bir sütun olarak açılır. İsterseniz yalnız iç ekranda yatay açılış ekleyin |
| Uzun içerik | Kısa dış ekranda taşabilecek içeriği `ScrollView` içine koyun |

---

## Sahne yaşam döngüsü

iOS 27 SDK'sıyla derlenen bir uygulama sahne kullanmıyorsa Duo'da açılış anında kapanır. Çökme
kaydında şu satır görünür:

```
_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption
```

Pencereyi `AppDelegate` yerine bir sahne delegesinde kurun. Örnek uygulama bunu şöyle yapıyor
([AppDelegate.swift](../../IdentifySample/App/AppDelegate.swift)):

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = SDKWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: RootView())
        self.window = window
        // SDK 3.2.0 ve öncesi uyarı penceresini uygulama delegesinden okuyor.
        (UIApplication.shared.delegate as? AppDelegate)?.window = window
        window.makeKeyAndVisible()
    }
}
```

Info.plist'e sahne bildirimini ekleyin:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
</dict>
```

Kendi `UIWindow` alt sınıfınızı da `init(windowScene:)` ile kurun. Örnekteki `SDKWindow`,
sallayınca ağ kaydını açan hata ayıklama penceresi; sahneye geçince de aynı şekilde çalışıyor.

SDK'nın kendi uyarıları (soket hatası gibi) pencereyi etkin sahneden bulur. 3.2.0 ve önceki
sürümlerde uyarılar `AppDelegate.window` üzerinden açıldığı için örnekteki gibi pencereyi oraya
da yazın.

---

## Pencere ve ölçü

Duo'da ekran katlanınca uygulama dış ekrandan iç ekrana geçer ve pencere o anda yeniden
boyutlanır. Ölçüyü her zaman pencereden alın:

| Kullanın | Kullanmayın |
|---|---|
| `SDKLayout.bounds` | `UIScreen.main.bounds` |
| `SDKLayout.activeWindow` | `UIApplication.shared.keyWindow`, `UIApplication.shared.delegate?.window` |
| `SDKLayout.activeWindow?.screen` | `UIScreen.main` (parlaklık gibi ekran ayarları) |
| SwiftUI'de `GeometryReader` | Açılışta bir kez okunup saklanan genişlik |

Sahne kullanan uygulamada `UIApplication.shared.delegate?.window` boş kalır, `keyWindow` da
iOS 13'ten beri kullanımdan kalktı. Bu yollarla pencere arayan kod sessizce hiçbir şey göstermez.
Uyarı, popup ya da tam ekran sunumu `SDKLayout.activeWindow?.rootViewController` üzerinden açın.

Genişliği bir kez hesaplayıp saklamayın. Katlama sırasında SwiftUI görünümü yeniden çizer, saklanan
değer ise eski ekranın ölçüsünde kalır.

---

## Güvenli alan

Duo'nun dış ekranında durum çubuğu üstte değil, sağ kenarda bir sütunda durur. Güvenli alanın
sağ payı yaklaşık 88 pt, üst payı sıfırdır.

Bir çerçeveyi güvenli alanın içinde ortalıyorsanız genişliğini hesaplarken sol ve sağ payı da
düşün:

```swift
let pay = SDKLayout.activeWindow?.safeAreaInsets ?? .zero
let genislik = min(SDKLayout.bounds.width - pay.left - pay.right - 64,
                   SDKLayout.maxCaptureGuideWidth)
```

Payları düşmeyen hesapta çerçeve güvenli alandan geniş çıkar ve sol kenarı ekranın dışına taşar.
SDK'nın OVD kimlik çekim çerçevesi bu hesapla çiziliyor.

SwiftUI'de `.ignoresSafeArea()` yalnız arka plan ve kamera önizlemesi gibi kenara kadar uzanması
gereken katmanlarda kullanılsın. Düğme ve metin güvenli alanın içinde kalsın.

---

## Yönelim

SDK ekranları dikey konuma göre tasarlandı. En sade kurulum uygulamayı dikey kilitli bırakmak:

```
UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait
UISupportedInterfaceOrientations~ipad = UIInterfaceOrientationPortrait
UIRequiresFullScreen = YES
```

İç ekran yatayken sistem dikey kilitli uygulamayı ekranın ortasında dikey bir sütun olarak açar.
SDK ekranları bu sütunda düzgün yerleşir. Kendi ekranlarınızda da pencere ölçüsüyle çalıştığınız
sürece ek bir şey yapmanız gerekmez.

### İç ekranda yatay açılış

Örnek uygulama iç ekranda yatay da açılıyor; dış ekranda ve diğer iPhone'larda dikey kalıyor.
Aynısını yapmak için Info.plist'te iPhone'a yatay yönleri ekleyin. iPad dikey kalsın,
`UIRequiresFullScreen` da açık kalsın:

```
UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight
UISupportedInterfaceOrientations~ipad = UIInterfaceOrientationPortrait
UIRequiresFullScreen = YES
```

Yatay açılışı uygulama delegesinde iç ekranla sınırlayın. Bugünkü telefonlarda kısa kenarı 600 pt'yi
geçen tek ekran Duo'nun iç ekranı ([AppDelegate.swift](../../IdentifySample/App/AppDelegate.swift)):

```swift
func application(_ application: UIApplication,
                 supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    guard UIDevice.current.userInterfaceIdiom == .phone,
          let ekran = window?.windowScene?.screen.bounds.size,
          min(ekran.width, ekran.height) >= 600 else { return .portrait }
    return .allButUpsideDown
}
```

Yatayda SDK ekranları şöyle davranır:

- Modül ekranları ölçüyü pencereden aldığı için yatay pencereye de yerleşir.
- Kimlik okuma etkilenmez. Tarayıcı kareyi arayüzün yönünden bağımsız, sabit açıyla alır; okunan
  alanlar görüntüdeki karta göre ölçülür.
- Kimlik tarayıcının önizlemesi dikey konuma sabittir. İç ekran yatayken önizleme yan görünür.
- Selfie ve video kaydı açıyı her yerleşimde yeniden okur, önizleme dik kalır.

Okunabilir genişlik için iPad rehberindeki `.sdkReadableWidth()` aynı şekilde çalışır
([iPad Desteği](ipad-support.md)).

---

## Kısa dış ekran

Dış ekran yaklaşık 466 x 678 pt; düz bir iPhone'dan kısa. Uzun açıklama, form ya da birden çok
düğme içeren ekranları `ScrollView` içine koyun. SDK'nın giriş ve NFC ekranları da böyle: içerik
sığmazsa kaydırılarak okunur.

---

## SSS

**Uygulamam Duo'da açılır açılmaz kapanıyor. Neden?**
iOS 27 SDK'sıyla derlenen uygulama sahne yaşam döngüsü kullanmıyorsa Duo'da açılmıyor. Çökme
kaydında `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption` görünür.
[Sahne yaşam döngüsü](#sahne-yaşam-döngüsü) bölümündeki gibi bir `SceneDelegate` ekleyin.

**Sahneye geçtim, SDK'nın uyarıları artık çıkmıyor.**
3.2.0 ve önceki sürümler uyarı penceresini `AppDelegate.window` üzerinden buluyor. Sahne
delegesinde kurduğunuz pencereyi oraya da yazın. Sonraki sürümlerde SDK pencereyi etkin sahneden
alıyor.

**Kendi popup'ım ya da tam ekran sunumum görünmüyor.**
Pencereyi `UIApplication.shared.keyWindow` ya da `delegate.window` ile arıyorsanız sahneli
uygulamada boş gelir. `SDKLayout.activeWindow?.rootViewController` kullanın.

**Çerçevem dış ekranda sola taşıyor.**
Dış ekranda sağda yaklaşık 88 pt güvenli alan payı var. Genişliği pencereden alıp çerçeveyi
güvenli alanda ortalıyorsanız sol ve sağ payı genişlikten düşün.

**Üstteki başlığım dış ekranda durum çubuğunun altında kalır mı?**
Kalmaz. Dış ekranda durum çubuğu sağ kenarda olduğu için üst pay sıfır. Başlığı güvenli alana
göre yerleştirdiyseniz sağdaki sütunun solunda kalır.

**Ekranı katlayınca yerleşimim bozuluyor.**
Genişliği açılışta bir kez okuyup saklıyor olabilirsiniz. `SDKLayout.bounds` ya da
`GeometryReader` ile her çizimde pencereden okuyun.

**`UIScreen.main.bounds` kullanabilir miyim?**
Duo'da iki ekran var, `UIScreen.main` hangisini kastettiğinizi bilmez. Pencere ölçüsü için
`SDKLayout.bounds`, ekran ayarı için `SDKLayout.activeWindow?.screen` kullanın.

**Selfie ekranında parlaklığı artırıyorum. Bunu nasıl yapmalıyım?**
Parlaklığı pencerenin bağlı olduğu ekrandan ayarlayın:
`SDKLayout.activeWindow?.screen.brightness`. Ekrandan çıkarken eski değeri aynı ekrana geri yazın.

**İç ekranda uygulama ortada dar bir sütun olarak açılıyor. Bu doğru mu?**
Uygulama dikey kilitliyse doğru. İç ekran yatayken sistem uygulamayı dikey bir sütun olarak çizer,
SDK ekranları bu sütuna göre yerleşir. İç ekranın tamamını kullanmak için
[Yönelim](#yönelim) bölümündeki yatay açılışa bakın.

**Yatay yerleşim desteklemem gerekiyor mu?**
Hayır. Dikey kilit yeterli. İç ekranda yatay açılış isteğe bağlı; açarsanız kimlik tarayıcının
önizlemesi yatayda yan görünür, okuma yine çalışır.

**Dış ekranda alt metin düğmenin arkasında kalıyor.**
Dış ekran düz bir iPhone'dan kısa. İçeriği `ScrollView` içine koyun.
