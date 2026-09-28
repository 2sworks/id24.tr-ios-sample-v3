# Özelleştirme — SDK Ekranlarını Kendi Tasarımınızla Çalıştırmak

SDK'nın modül ekranları hazır gelir; tek satır arayüz kodu yazmadan akış çalışır. Kendi
tasarımınızı kullanmak istediğinizde üç yol var. Bu rehber üçünü de anlatıyor ve hepsinde
geçerli olan tek kuralı açıklıyor: iş mantığını SDK'nın dışından yürütmeyin ("bypass yok").

← [README'ye dön](../../README.md) · İlgili: [Mimari](architecture.md) · [Tema](theming.md)

---

## Önce Kendinize Sorun: Hangi Seviye?

> Yalnızca görünümü değiştirmek istiyorsanız (renk, köşe, başlık çubuğu, logo, font, seçili
> satır rengi) bu rehbere gerek yok. [theming.md](theming.md)'deki tema sözlüğü bunların hepsini
> karşılar ve React Native ile Flutter'da native derleme istemez. Kendi ekranınızı ancak akış ya
> da içerik değişecekse yazmanız gerekir.


| İhtiyaç | Çözüm | Efor |
|---|---|---|
| "Renkler/font/logo bizim olsun" | [Tema](theming.md), ekran yazmadan | ⭐ |
| "Şu ekranın tasarımı tamamen bizim olsun" | A) Override (bu rehber) | ⭐⭐ |
| "Akışın arasına kendi ekranımı sokayım" | B) Custom ekran ekleme | ⭐⭐ |
| "SDK ekranı kalsın ama olup biteni izleyeyim" | C) Host VM composition | ⭐ |

Aynı projede üç yöntemi birlikte kullanabilirsiniz.

---

## A) Tam Ekran Override

Bir SDK ekranının yerine kendi SwiftUI view'ınızı koyarsınız:

```swift
registry.override(.selfie) { MyCustomSelfieView() }
```

Bundan sonra selfie rotası geldiğinde `SDKFlowHostView` sizin ekranınızı çizer. Arayüz sizin
olur, iş mantığı SDK'da kalır; ekranınız SDK'nın ViewModel'ini kullanmaya devam eder:

```swift
struct MyCustomSelfieView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKSelfieViewModel()

    var body: some View {
        VStack {
            MyBrandedCameraView { captured in
                vm.processSelfie(image: captured)    // ✅ yüz tespiti + upload SDK'da
            }
            if let err = vm.errorMessage { Text(err) }
            Button("Devam") { coordinator.advanceToNextModule() }  // ✅ adım sinyali SDK'da
                .disabled(!vm.canContinue)
        }
        .onAppear { vm.onSkipRequested = { coordinator.skipCurrentModule() } }
    }
}
```

Her modülün VM API'si (state, metotlar, closure'lar) o modülün rehberinde tablo olarak duruyor.
[Modül Kataloğu](../../README.md#modül-kataloğu)'ndan ilgili modüle geçebilirsiniz.

### Sıfırdan yazmak yerine: `XxxCustomView.swift`

Yukarıdaki örnek yalnızca yöntemi gösteriyor. Gerçek bir ekranda çok daha fazlası var: kamera
önizlemesi, oval maske, deneme sayacı, hata uyarısı, sesli okuma, ilerleme çubuğu. Bunları
sıfırdan yazmanız gerekmiyor. Örnek uygulamada her modülün klasöründe bir `XxxCustomView.swift`
bulunuyor. Bu dosya SDK'nın hazır ekranının yalnızca public API kullanılarak yazılmış, çalışan bir
kopyası. Hiç değiştirmeden bağlarsanız SDK ekranıyla aynı sonucu alırsınız; özelleştirmeyi bu
dosyanın üzerinde yaparsınız.

| Rota | Dosya | Ek bağımlılık |
|---|---|---|
| `.prepare` | `Modules/Prepare/PrepareCustomView.swift` | — |
| `.selfie` | `Modules/Selfie/SelfieCustomView.swift` | CustomKit |
| `.selfieWithLiveness` | `Modules/SelfieWithLiveness/SelfieWithLivenessCustomView.swift` | CustomKit + `SelfieCameraController` (Vision yolu) |
| `.idCard` | `Modules/IdCard/IdCardCustomView.swift` | — (`documentScanner` modifier SDK'da) |
| `.idCard` (tek ekran) | `Modules/IdCard/IdCardSingleScreenCustomView.swift` | ön ve arka yüz tek tam ekranda; `keepsCameraRunning` + `scanSession` |
| `.idCardOVD` | `Modules/IdCardOVD/IdCardOVDCustomView.swift` | CustomKit |
| `.nfc` | `Modules/NFC/NfcCustomView.swift` | — |
| `.liveness` | `Modules/Liveness/LivenessCustomView.swift` | CustomKit (ARKit) |
| `.speech` | `Modules/Speech/SpeechCustomView.swift` | — |
| `.addressConfirm` | `Modules/AddressConfirm/AddressConfirmCustomView.swift` | — |
| `.signature` | `Modules/Signature/SignatureCustomView.swift` | — (PencilKit) |
| `.videoRecorder` | `Modules/VideoRecorder/VideoRecorderCustomView.swift` | CustomKit |
| `.callScreen` | `Modules/CallScreen/CallScreenCustomView.swift` | `SignLangCustomView`, `LostConnectionCustomView` |
| `.thankYou(_)` | `Modules/ThankYou/ThankYouCustomView.swift` | — |
| (görüşme içi) | `Modules/SignLang/SignLangCustomView.swift` | — |
| (katman) | `Modules/LostConnection/LostConnectionCustomView.swift` | — |

CustomKit iki dosyadan oluşuyor: `Modules/CustomKit/CustomCameraPreview.swift` ve
`CustomComponents.swift`. Kamera kullanan ekranların ortak önizleme katmanı (iOS 17
`RotationCoordinator` ile dikey açı düzeltmesi), oval ve çerçeve maskeleri ve yardımcılar
buradadır. Kamera kullanan bir `CustomView`'ı kopyalarken bu iki dosyayı da kopyalayın.

Kullanım:

```swift
registry.override(.selfie) { SelfieCustomView() }     // dosya olduğu gibi projeye alınır
```

Her `XxxCustomView.swift` dosyasının başında hangi işin VM'de, hangisinin dosyada yapıldığı,
ViewModel'in nasıl kullanıldığı ve hangi dosyaların kopyalanacağı yazıyor.

Çalışırken görmek için örnek uygulamada hamburger menüden **Tam Özel Ekranlar**'ı açın. Anahtar
açıkken akıştaki her ekran `XxxCustomView` ile çizilir (`registry.override` çağrılarının hepsi
`CustomKit/CustomScreens.swift`'te); kapalıyken SDK ekranları çalışır. Aynı ekrandaki listeden her
modülün özel sürümünü akışa girmeden tek tek önizleyebilirsiniz.

> Selfie + Canlılık (`.selfieWithLiveness`) için `SDKSelfieWithLivenessViewModel` public
> (ARKit ve Vision yolu). ViewModel ile neler yapılıp neler yapılamadığı:
> [SelfieWithLiveness.md](../../IdentifySample/Modules/SelfieWithLiveness/SelfieWithLiveness.md#viewmodelde-ne-yapılabilir).

> Teşekkür ekranı ve bitiş durumu: görüşme socket üzerinden bittiğinde SDK'nın görüşme ekranı
> bitiş durumunu `coordinator.pendingThankYouStatus`'a yazar. Bu alanın setter'ı 3.1.0'da public
> değil. Bu yüzden özel görüşme ekranı durumu kendisi tutar (`CustomScreens.pendingThankYouStatus`),
> `.thankYou(nil)` rotasındaki özel teşekkür ekranı da oradan okur. Örneği
> `CallScreenCustomView.swift` ve `ThankYouCustomView.swift` içinde bulabilirsiniz.

---

## B) Araya Custom Ekran Ekleme

Akışa kendi ekranlarınızı eklersiniz: hoş geldin ekranı, sözleşme onayı, ara başarı ekranı gibi.

```swift
// 1) Ekranı tanımla
registry.custom("welcome") { MyIntroView() }

// 2) Nereye geleceğini söyle
coordinator.insert(["welcome"], before: .selfie)     // Selfie'den önce
coordinator.insert(["success1"], after: .idCard)     // Kimlikten sonra

// 3) Custom ekranın "Devam" butonu:
Button("Devam") { coordinator.advanceExternal() }
```

Akış sırasını değiştirmeden bir ekranı o an göstermek de mümkün:

```swift
coordinator.showExternalScreen("kvkk")   // dönüşte yine advanceExternal()
```

Bu ekranlar pasiftir: backend'in modül sayacını (`moduleStepOrder`) değiştirmez ve soketle
konuşmaz. Soket ve WebRTC `IdentifyManager` singleton'ında tutulduğu için araya giren ekranlar
bağlantıyı etkilemez; istediğiniz kadar ekleyebilirsiniz.

Aynı noktaya birden fazla ekran ekleyebilirsiniz. Ekranlar dizideki sırayla gösterilir. Aynı rota
için ikinci bir `insert` çağrısı öncekini silmez, sıranın sonuna ekler:

```swift
coordinator.insert(["intro1", "intro2"], before: .nfc)   // intro1 → intro2 → NFC
```

Ekran yerine modül eklemek istiyorsanız (bir adımın sonucuna göre akışın uzadığı senaryolar)
`appendModules` kullanın. Eklenen modüller kalanların sonuna gider ve ilerleme çubuğu
(`progressTotal`) kendiliğinden güncellenir:

```swift
coordinator.appendModules([.idCard, .waitScreen])
coordinator.advanceToNextModule()
```

---

## C) Host VM Composition — Gözlemleyerek Zenginleştirme

SDK ekranını değiştirmeden olup biteni izlemek istiyorsanız (log, analitik, kendi state'iniz)
SDK'nın VM'ini kendi VM'inizle sarın:

```swift
@MainActor
final class SelfieHostViewModel: HostModuleViewModel {
    let sdk = SDKSelfieViewModel()

    override init() {
        super.init()
        bridge(sdk)                                    // child'ın objectWillChange'ini yukarı ilet
        sdk.onSkipRequested = { [weak self] in self?.log("selfie_skip") }
    }

    var canContinue: Bool { sdk.canContinue }          // state'i dışarı aç

    func process(_ img: UIImage) {
        log("selfie_scan")                             // sizin tarafınız
        sdk.processSelfie(image: img)                  // işi SDK yapar
    }
}
```

> Modül VM'leri `public final`, yani onlardan sınıf türetemezsiniz. Davranışı değiştirmek yerine
> VM'i sarıp izlersiniz. Bunu bilerek böyle yaptık: iş mantığı dışarıdan değiştirilirse sunucudaki
> akışla uyumsuzluk çıkar.

Sample App'teki her `XxxHostViewModel` bu yöntemin çalışan bir örneği.

---

## "Bypass Yok" Kuralı

Custom ekran yazarken tarama, yükleme ve sonraki modüle geçme gibi her adım işini SDK'nın VM
metotlarıyla yapmalısınız. Her VM metodu işin yanında backend'e ilerleme sinyali de gönderir
(`sendStep`, `modulePresented`). Kendi HTTP isteğinizi atıp kendi geçişinizi yaparsanız ekranda
her şey aynı görünür ama sunucudaki akış ilerlemez ve agent panelinde müşteri takılmış gibi
görünür.

| ✅ Doğru | ❌ Bypass |
|---|---|
| `vm.scanFront(image:)` → OCR + upload + adım sinyali | Kendi OCR'ınız + kendi `POST`'unuz |
| `coordinator.advanceToNextModule()` | `path.append(...)` ile kendi geçişiniz |
| `vm.uploadSignature(image:)` | Görseli kendiniz yüklemek |
| `coordinator.skipCurrentModule()` | Modülü sessizce atlamak |

B yöntemindeki pasif ekranlar bu kuralın dışında kalır, çünkü hiçbir VM metodu çağırmazlar.

---

## Kontrol Listesi — Custom Ekran Yayına Çıkmadan Önce

- [ ] Ekran ilgili `XxxCustomView.swift`'ten başlatıldı (sıfırdan yazılmadı) ve dosyanın başındaki "Kopyalanacak dosyalar" listesindeki her şey projede
- [ ] Ekran iş adımlarında yalnızca SDK VM metotlarını çağırıyor
- [ ] Geçişler `coordinator` üzerinden yapılıyor (`advanceToNextModule` / `advanceExternal` / `skipCurrentModule`)
- [ ] `vm.errorMessage` ve `vm.isLoading` kullanıcıya gösteriliyor
- [ ] Modülün closure'ları bağlandı (`onSkipRequested` vb., modül rehberine bakın)
- [ ] Deneme hakkının bittiği durum test edildi (comparison count'lar sunucudan gelir)
- [ ] Akış gerçek cihazda baştan sona denendi (NFC ve görüşme simülatörde çalışmaz)
