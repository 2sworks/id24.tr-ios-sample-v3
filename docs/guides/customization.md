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

Sunucuya sonraki modül, son custom ekran `advanceExternal()` çağırınca bildirilir. `before: .callScreen`
ile eklenen ekran açıkken kullanıcı henüz paneldeki bekleme odasında değildir. Görüşmeden önce
bağlantı ölçen bir ekran örneği: [Bağlantı Hız Testi](speed-test.md#4-modülden-önce-ölçüm-ekranı).

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

### Ara ekrandan ilerlemek: `advanceExternal()`

Akışta iki tür ekran vardır ve ikisi farklı metotla ilerler:

| | SDK modül ekranı | Araya eklenen ekran |
|---|---|---|
| Nereden gelir | Sunucunun modül listesinden (selfie, NFC, görüşme…) | Sizin `insert` ya da `showExternalScreen` çağrınızdan |
| Sunucu biliyor mu | Evet, her geçiş sunucuya bildirilir | Hayır, ekran yalnızca cihazda vardır |
| Adım sayacı (`moduleStepOrder`) ve ilerleme çubuğu | İlerler | Değişmez |
| İlerlemek için | `coordinator.advanceToNextModule()`. Hazır ekranlarda ve `XxxCustomView` kopyalarında bunu ViewModel akışı çağırır | `coordinator.advanceExternal()` |

```text
SDK modül ekranı (Selfie, NFC, override edilenler dahil) ──> advanceToNextModule()
Araya eklenen ekran (insert / showExternalScreen)         ──> advanceExternal()

Araya eklenen ekranda advanceToNextModule() çağrılırsa:
    çağrı yok sayılır + konsola uyarı düşer, kullanıcı ekranda kalır
```

`advanceToNextModule()` modüle geçmeden önce "sıradaki modülün önüne eklenmiş ekran var mı" diye
bakar, varsa onu açar. Araya eklenen ekranın içinden çağrılırsa aynı ekranı yeniden bulur ve akış
ilerlemez. `advanceExternal()` bu yüzden ayrıdır: bekleyen ekranların listesini tutar, liste
bitince sunucuya asıl geçişi yapar.

`advanceExternal()` her çağrıldığında durumdan birini seçer:

1. Aynı noktaya eklenmiş başka ekran bekliyorsa onu açar. Sunucuya bir şey gitmez.
2. Bekleyen ekran kalmadıysa sıradaki modüle geçer. Sunucuya sonraki modül bu anda bildirilir.
   Sıradaki modül görüntülü görüşmeyse kullanıcı paneldeki bekleme odasına da bu anda alınır.
3. Ekran `showExternalScreen(_:)` ile açıldıysa `advanceToNextModule()` gibi davranır: sıradaki
   modüle geçer, o modülün önüne eklenmiş ekran varsa önce onu açar. Ekranın açıldığı modüle
   geri dönülmez.

```text
advanceExternal()
      │
      ▼
Kuyrukta bekleyen ara ekran var mı?
      ├─ evet ──> (1) Sıradaki ara ekranı açar. Sunucuya bir şey gitmez.
      │
      └─ hayır
            │
            ▼
      Bu ekranlar insert ile mi açıldı?
            ├─ evet ──> (2) Sıradaki modüle geçer. Sunucuya bildirilir;
            │               görüşmeyse kullanıcı bekleme odasına girer.
            │
            └─ hayır (showExternalScreen ile açıldı)
                    ──> (3) advanceToNextModule() gibi davranır.
```

#### Örnek: selfie, ölçüm ekranı, görüşme

```swift
registry.custom("speedCheck") { SpeedCheckBeforeView() }
coordinator.insert(["speedCheck"], before: .callScreen)
```

| Ne olur | Sunucunun gördüğü modül |
|---|---|
| Selfie biter, ViewModel `advanceToNextModule()` çağırır. SDK sıradaki modülün görüşme olduğunu görür ve önce `speedCheck`'i açar | Selfie |
| `speedCheck` ölçer, sonuç geçer, ekran `advanceExternal()` çağırır. Bekleyen ekran yok, SDK görüşmeye geçer | Görüşme; kullanıcı bekleme odasında |
| Ölçüm engellerse ekran `advanceExternal()` çağırmaz, "Tekrar Dene" gösterir | Hâlâ selfie; kullanıcı bekleme odasına girmez |

Ölçüm geçerse:

```text
EKRAN   [ Selfie ] ─────────────────> [ speedCheck ] ───────────────> [ Görüşme ]
          SDK modülü                    ara ekran, ölçüm               SDK modülü
                 advanceToNextModule()                advanceExternal()
                 (Selfie VM çağırır)                  (ekran çağırır)
                                                            │
                                                            ▼ sonraki modül burada bildirilir
PANEL   ├──────────── Selfie ──────────────────────────────┤├─ Görüşme (bekleme odası) ─┤
```

Ölçüm engellerse:

```text
EKRAN   [ Selfie ] ─────────────────> [ speedCheck ] ──X──> [ Görüşme ]  (açılmaz)
                 advanceToNextModule()   │    ▲
                                         └────┘ Tekrar Dene
                                    advanceExternal() hiç çağrılmaz

PANEL   ├──────────── Selfie ──────────────────────────────────────────────────┤
                      (kullanıcı bekleme odasına girmez)
```

Aynı noktaya iki ekran:

```swift
coordinator.insert(["networkInfo", "speedCheck"], before: .callScreen)
```

```text
[ Selfie ] ──────> [ networkInfo ] ──────> [ speedCheck ] ──────> [ Görüşme ]
   advanceToNextModule()   advanceExternal()      advanceExternal()
                           (1) kuyruktan açar     (2) modüle geçer

PANEL: ├──────────── Selfie ───────────────────────────────┤├── Görüşme ──┤
```

Selfie bitince `networkInfo` açılır. Onun `advanceExternal()` çağrısı `speedCheck`'i açar
(1. durum). `speedCheck`'in çağrısı görüşmeye geçirir (2. durum). Bir modülün arkasına `after:`
ile eklenen ekranlar ile sıradaki modülün önüne `before:` ile eklenenler aynı listeye girer;
önce `after` ekranları gösterilir.

#### Kurallar

- Araya eklenen ekranın ileri giden her yolu (buton, otomatik geçiş, zamanlayıcı)
  `advanceExternal()` çağırır.
- Bu ekranlarda `advanceToNextModule()` çağırmayın. Çağrı yok sayılır ve konsola uyarı düşer;
  kullanıcı ekranda kalır.
- `registry.override` ile değiştirdiğiniz SDK modül ekranları araya eklenen ekran sayılmaz.
  Onlar `advanceToNextModule()` ile ilerler.
- `advanceExternal()` hiç çağrılmazsa akış o ekranda durur ve sunucu önceki modülü görmeye devam
  eder. Ölçüm ya da onay gibi engelleyen ekranlarda istenen davranış budur.
- Ara ekrandan geri dönülürse (`popBack()`) önceki modül ekranı açılır. O modül yeniden
  bitince ara ekran tekrar gösterilir.
- `insert` çağrıları birikir ve `resetFlow()` ile silinmez. Uygulama açılışında bir kez
  çağırın; her oturumda çağrılırsa ekran art arda iki kez açılır.

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
