# Özelleştirme — SDK Ekranlarını Kendi Tasarımınızla Çalıştırmak

SDK'nın her modül ekranı **drop-in**'dir: hiçbir şey yazmadan hazır akış çalışır. Ama hiçbir
banka aynı görünmek istemez. Bu rehber, üç özelleştirme yöntemini derinlemesine anlatır ve
hepsinin üstündeki tek altın kuralı açıklar: **"bypass yok."**

← [README'ye dön](../../README.md) · İlgili: [Mimari](architecture.md) · [Tema](theming.md)

---

## Önce Kendinize Sorun: Hangi Seviye?

> **Sıfırıncı seviye — tema.** Ekranı değiştirmeden yalnız görünümü ayarlamak istiyorsanız
> (renk, köşe, başlık çubuğu tasarımı, logo, font, seçili satır rengi) buraya gerek yok:
> [theming.md](theming.md) tek sözlükle bunların tümünü karşılar ve React Native/Flutter'da
> native derleme gerektirmez. Custom ekran, ancak akış veya içerik değişecekse gerekir.


| İhtiyaç | Çözüm | Efor |
|---|---|---|
| "Renkler/font/logo bizim olsun" | [Tema](theming.md) — ekran yazmadan | ⭐ |
| "Şu ekranın tasarımı tamamen bizim olsun" | **A) Override** (bu rehber) | ⭐⭐ |
| "Akışın arasına kendi ekranımı sokayım" | **B) Custom ekran ekleme** | ⭐⭐ |
| "SDK ekranı kalsın ama olup biteni izleyeyim" | **C) Host VM composition** | ⭐ |

Yöntemler birbirini dışlamaz — aynı projede üçünü birden kullanabilirsiniz.

---

## A) Tam Ekran Override

Bir SDK ekranını kendi SwiftUI view'ınızla değiştirirsiniz:

```swift
registry.override(.selfie) { MyCustomSelfieView() }
```

Artık `SDKFlowHostView`, selfie rotası geldiğinde sizin ekranınızı çizer. Kritik nokta:
**UI sizin, iş mantığı SDK'nın.** Ekranınız SDK ViewModel'ini kullanmaya devam eder:

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

Her modülün VM API'si (state / metotlar / closure'lar) kendi rehberinde tablo halinde
verilir — [Modül Kataloğu](../../README.md#modül-kataloğu)ndan ilgili modüle gidin.

### Sıfırdan yazmak yerine: `XxxCustomView.swift`

Yukarıdaki kısa örnek yöntemi gösterir; gerçek bir ekran çok daha fazlasını içerir (kamera
önizlemesi, oval maske, deneme sayacı, hata alert'i, sesli okuma, ilerleme çubuğu…).
Bunların hiçbirini sıfırdan yazmak gerekmez. Örnek uygulamada her modülün klasöründe
`XxxCustomView.swift` vardır: SDK'nın hazır ekranının **yalnızca public API ile** yazılmış,
çalışan birebir kopyası. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir;
özelleştirme bu dosya üzerinde yapılır.

| Rota | Dosya | Ek bağımlılık |
|---|---|---|
| `.prepare` | `Modules/Prepare/PrepareCustomView.swift` | — |
| `.selfie` | `Modules/Selfie/SelfieCustomView.swift` | CustomKit |
| `.selfieWithLiveness` | `Modules/SelfieWithLiveness/SelfieWithLivenessCustomView.swift` | CustomKit + `SelfieCameraController` (Vision yolu) |
| `.idCard` | `Modules/IdCard/IdCardCustomView.swift` | — (`documentScanner` modifier SDK'da) |
| `.idCard` (tek ekran) | `Modules/IdCard/IdCardSingleScreenCustomView.swift` | ön + arka yüz tek tam ekranda; `keepsCameraRunning` + `scanSession` |
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

**CustomKit** (`Modules/CustomKit/CustomCameraPreview.swift`, `CustomComponents.swift`):
kamera kullanan ekranların paylaştığı önizleme katmanı (iOS 17 `RotationCoordinator` ile
portrait açı düzeltmesi), oval/çerçeve maskeleri ve ortak yardımcılar. Kamera kullanan bir
`CustomView` kopyalandığında bu iki dosya da kopyalanır.

Kullanım:

```swift
registry.override(.selfie) { SelfieCustomView() }     // dosya olduğu gibi projeye alınır
```

Her `XxxCustomView.swift` dosyasının başında görev dağılımı (hangi iş VM'de, hangisi
dosyada), ViewModel kullanımı ve kopyalanacak dosyalar listelenir.

**Çalışırken görmek:** örnek uygulamada hamburger menü → **Tam Özel Ekranlar**. Anahtar
açıkken akıştaki her ekran `XxxCustomView` ile çizilir (`CustomKit/CustomScreens.swift`
`registry.override` çağrılarını toplu yapar); kapalıyken SDK ekranları çalışır. Aynı
ekrandaki listeden her modülün özel sürümü akışa girmeden tek tek önizlenir.

> **Selfie + Canlılık (`.selfieWithLiveness`)** için `SDKSelfieWithLivenessViewModel` public'tir
> (ARKit ve Vision yolu). ViewModel'de neyin yapılıp neyin yapılamadığı: [SelfieWithLiveness.md](../../IdentifySample/Modules/SelfieWithLiveness/SelfieWithLiveness.md#viewmodelde-ne-yapılabilir).

> **Teşekkür ekranı ve bitiş durumu:** görüşme socket üzerinden bittiğinde SDK'nın kendi
> görüşme ekranı bitiş durumunu `coordinator.pendingThankYouStatus`'a yazar; bu alanın
> setter'ı 3.1.0'da public değildir. Özel görüşme ekranı durumu kendi tarafında tutar
> (`CustomScreens.pendingThankYouStatus`) ve `.thankYou(nil)` rotasındaki özel teşekkür
> ekranı oradan okur. Kalıp `CallScreenCustomView.swift` / `ThankYouCustomView.swift`
> içindedir.

---

## B) Araya Custom Ekran Ekleme

Akışa kendi ekranlarınızı sokarsınız — hoş geldin, sözleşme onayı, ara başarı ekranı...

```swift
// 1) Ekranı tanımla
registry.custom("welcome") { MyIntroView() }

// 2) Nereye geleceğini söyle
coordinator.insert(["welcome"], before: .selfie)     // Selfie'den önce
coordinator.insert(["success1"], after: .idCard)     // Kimlikten sonra

// 3) Custom ekranın "Devam" butonu:
Button("Devam") { coordinator.advanceExternal() }
```

Anlık gösterim de mümkündür (akış sırasını değiştirmeden):

```swift
coordinator.showExternalScreen("kvkk")   // dönüşte yine advanceExternal()
```

Bu ekranlar **pasiftir**: backend'in modül sayacını (`moduleStepOrder`) etkilemez, soketle
konuşmaz. Bu yüzden istediğiniz kadar ekleyebilirsiniz — soket ve WebRTC
`IdentifyManager` singleton'ında yaşadığı için araya giren ekranlar bağlantıyı etkilemez.

Birden fazla ekranı aynı noktaya zincirleyebilirsiniz — dizi sırası gösterim sırasıdır,
aynı rotaya ikinci `insert` çağrısı kuyruğun sonuna ekler (ezmez):

```swift
coordinator.insert(["intro1", "intro2"], before: .nfc)   // intro1 → intro2 → NFC
```

**Ekran değil MODÜL eklemek istiyorsanız** (dallanan senaryolar — bir adımın sonucuna
göre akışın uzaması), `appendModules` kullanın; eklenenler kalan modüllerin sonuna gider
ve ilerleme şeridi (`progressTotal`) otomatik güncellenir:

```swift
coordinator.appendModules([.idCard, .waitScreen])
coordinator.advanceToNextModule()
```

---

## C) Host VM Composition — Gözlemleyerek Zenginleştirme

SDK ekranını değiştirmek istemiyorsanız ama olup biteni izlemek (log, analitik, kendi
state'iniz) istiyorsanız, SDK VM'ini kendi VM'inizle **sarın**:

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

> **Tasarım kararı:** Modül VM'leri `public final`'dır — subclass'lanamaz. Davranış ezmek
> yerine sarmalayıp gözlemlersiniz. Bu bilinçli bir tercihtir: dış geliştiricinin iş mantığını
> değiştirmesi, sunucu tarafı akışla uyumsuzluk yaratır.

Sample App'te her modülün `XxxHostViewModel`'i bu desenin çalışan örneğidir.

---

## "Bypass Yok" Kuralı

Custom ekran yazarken her adım eylemini — **tara, yükle, sonraki modüle geç** —
**SDK VM metoduna indirmelisiniz.** Nedeni basit: her VM metodu, işin yanında backend'e
ilerleme sinyali de gönderir (`sendStep`, `modulePresented`). Kendi HTTP isteğinizi atar,
kendi navigasyonunuzu kurarsanız görüntü aynı olur ama **sunucu akışı ilerlemez** —
agent panelinde müşteri "takılı" görünür.

| ✅ Doğru | ❌ Bypass |
|---|---|
| `vm.scanFront(image:)` → OCR + upload + adım sinyali | Kendi OCR'ınız + kendi `POST`'unuz |
| `coordinator.advanceToNextModule()` | `path.append(...)` ile kendi geçişiniz |
| `vm.uploadSignature(image:)` | Görseli kendiniz yüklemek |
| `coordinator.skipCurrentModule()` | Modülü sessizce atlamak |

Pasif ekranlar (B yöntemi) bu kuralın dışındadır — zaten hiçbir VM metodu çağırmazlar.

---

## Kontrol Listesi — Custom Ekran Yayına Çıkmadan Önce

- [ ] Başlangıç noktası ilgili `XxxCustomView.swift` (sıfırdan yazılmadı); dosya başındaki "Kopyalanacak dosyalar" listesi eksiksiz
- [ ] Ekran, iş eylemlerinde yalnızca SDK VM metotlarını çağırıyor
- [ ] Geçişler `coordinator` üzerinden (`advanceToNextModule` / `advanceExternal` / `skipCurrentModule`)
- [ ] `vm.errorMessage` ve `vm.isLoading` kullanıcıya yansıtılıyor
- [ ] Modülün closure'ları bağlandı (`onSkipRequested` vb. — modül rehberine bakın)
- [ ] Deneme hakkı tükenme senaryosu test edildi (comparison count'lar sunucudan gelir)
- [ ] Gerçek cihazda uçtan uca akış koşturuldu (NFC/görüşme simülatörde çalışmaz)
