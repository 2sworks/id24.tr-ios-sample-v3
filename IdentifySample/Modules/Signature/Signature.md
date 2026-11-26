# Signature — Islak İmza

Kullanıcı parmağıyla ekrana imzasını atar; imza görseli sunucuya yüklenir. Modüllerin en
sadesi: WebRTC yok — yalnızca bir tuval ve bir HTTP yüklemesi; sonucu SDK sokete kendisi
bildirir. Bu yüzden custom ekran yazmayı öğrenmek için de en iyi başlangıç noktasıdır.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.signature` |
| Rota | `SDKModuleRoute.signature` |
| Drop-in view | `SDKSignatureView` (+ `SDKSignatureCanvas`) |
| ViewModel | `SDKSignatureViewModel` |
| Dış dünya | **HTTP** (`uploadIdPhoto`) + soket durum mesajı `uploadSignature`; WebRTC yok |
| Ses anahtarı | `SignatureTts` |

Hazır tuval PencilKit (`PKCanvasView`) üzerine kuruludur.

## Kullanıcı Ne Yaşar?

1. Boş bir imza alanı görür; parmağıyla imzasını çizer.
2. Beğenmezse çöp kutusu düğmesiyle alanı temizler.
3. "Devam Et"e basınca imza yüklenir ve akış ilerler.

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKSignatureView` çizilir.

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [SignatureCustomView.swift](SignatureCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.signature) { SignatureCustomView() }`
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


Kendi tuvalinizi bile kullanabilirsiniz — tek şart, görselin SDK üzerinden yüklenmesi:

```swift
registry.override(.signature) { MySignatureView() }

struct MySignatureView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKSignatureViewModel()

    var body: some View {
        VStack {
            MyCanvas(onDraw: { vm.signatureDidDraw() })       // çizim başladı işareti
            HStack {
                Button("Temizle") { myCanvasClear(); vm.clearSignature() }  // tuvali siz temizlersiniz
                Button("Gönder") {
                    let rendered = myCanvasRenderedImage()    // tuvali UIImage'a çevirin
                    vm.uploadSignature(image: rendered)       // ✅ uploadIdPhoto
                }
                .disabled(!vm.signatureDrawn)
            }
        }
        .onAppear { vm.onCompleted = { coordinator.advanceToNextModule() } }  // ✅
    }
}
```

> ❌ **Bypass yapmayın:** İmza görselini kendi `POST`'unuzla yüklemeyin — `uploadSignature`
> kullanılmazsa backend imzayı bu oturumla ilişkilendiremez.
> Kural: [bypass yok](../../../docs/guides/customization.md#bypass-yok-kuralı).

---

## ViewModel Referansı — `SDKSignatureViewModel`

### State
| Üye | Tip | Erişim | Anlam |
|---|---|---|---|
| `signatureDrawn` | `Bool` | r/w | En az bir çizim yapıldı mı |
| `uploadCompleted` | `Bool` | salt-okunur | Yükleme tamamlandı mı |

### Metotlar
| Metot | Etki |
|---|---|
| `signatureDidDraw()` | Çizim başladığını işaretler (`signatureDrawn = true`) |
| `clearSignature()` | İmza durumunu sıfırlar: `signatureDrawn` ve `uploadCompleted` `false` olur, hata silinir. Tuvale dokunmaz; SDK tuvalini `SDKSignatureActions.clear()` temizler |
| `uploadSignature(image: UIImage)` | İmza görselini yükler → `onCompleted` |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onCompleted: (() -> Void)?` | Yükleme başarılı |

## Sinyal Zinciri — Perde Arkası

```
signatureDidDraw()       → signatureDrawn = true (UI durumu)
uploadSignature(image:)  → manager.uploadIdPhoto [HTTP] → onCompleted?()
host: → coordinator.advanceToNextModule() [modulePresented]
```

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class SignatureHostViewModel: HostModuleViewModel {
    let sdk = SDKSignatureViewModel()
    override init() {
        super.init(); bridge(sdk)
        sdk.onCompleted = { [weak self] in self?.log("signature_done") }
    }
    var canUpload: Bool { sdk.signatureDrawn }
    func upload(_ img: UIImage) { sdk.uploadSignature(image: img) }
}
```

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .signature)         // Siri/sistem sesi
// veya kendi kaydınız: bundle'a SignatureTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .signature)    // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .signatureTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **"Gönder" pasif kalıyor:** `signatureDidDraw()` çağrılmamıştır — kendi tuvalinizde ilk
  dokunuşta bu metodu çağırın.
- **İmza görüntü formatı:** Tuvali beyaz zeminli, okunaklı bir `UIImage`'a render edin;
  şeffaf zemin agent panelinde kötü görünebilir.
