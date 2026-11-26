# Speech — Konuşma Doğrulama

Kullanıcıya bir hedef kelime/metin gösterilir (ör. "Berlin"); kullanıcı bunu mikrofona
söyler, Apple **Speech** framework'ü tanır, SDK sonucu cihazda hedefle eşleştirir.
Amaç, mikrofonun çalıştığını ve karşıda konuşabilen gerçek bir kişinin olduğunu
görüşme öncesinde kanıtlamaktır. Sonuç, sokete `sendSpeechStatus` ile bildirilir.

> ⚠️ Karıştırmayın: Bu modül konuşma **TANIMA** adımıdır (kullanıcı konuşur, SDK dinler).
> "Sesli okuma / Read-Aloud" ise SDK'nın yönergeleri **seslendirmesidir** — ayrı özelliktir.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.speech` |
| Rota | `SDKModuleRoute.speech` |
| Drop-in view | `SDKSpeechRecView` |
| ViewModel | `SDKSpeechRecViewModel` |
| Dış dünya | Speech framework + **soket** (`sendSpeechStatus`) |
| Ses anahtarı | `SpeechTts` |

**İzinler:** `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription`.

## Kullanıcı Ne Yaşar?

1. Ekranda söylemesi gereken kelimeyi görür.
2. Mikrofon düğmesini basılı tutup kelimeyi söyler; tanınan metin canlı akar.
3. Düğmeyi bırakınca metin hedefle karşılaştırılır. Eşleşirse "Devam Et" aktifleşir; basınca
   sonuç sokete gider ve akış ilerler.

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKSpeechRecView` çizilir.

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [SpeechCustomView.swift](SpeechCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.speech) { SpeechCustomView() }`
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


```swift
registry.override(.speech) { MySpeechView() }

struct MySpeechView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKSpeechRecViewModel()

    var body: some View {
        VStack {
            Text("Söyleyin: \(vm.targetWord)")
            Text(vm.recognizedText)                          // canlı transkript
            Button(vm.isRecording ? "Durdur" : "Konuş") {
                vm.isRecording ? vm.stopRecording() : vm.startRecording()
            }
            Button("Onayla") { vm.confirmSpeech() }          // ✅ sendSpeechStatus (soket)
                .disabled(!vm.speechSuccess)
        }
        .onAppear { vm.onCompleted = { coordinator.advanceToNextModule() } }  // ✅
    }
}
```

- `targetWord` sunucudan (`speech_expected_sentence`) gelir; sunucu boş gönderirse varsayılan
  `"Berlin"` kalır.
- **Karşılaştırma cihazda yapılır** (`SDKSpeechMatcher`); sokete yalnız "tamamlandı" bilgisi
  gider. Tanınan metin SDK loguna yazılır; `.online` ve `.onlineSilent` log seviyelerinde log
  sunucusuna da gider.
- `confirmSpeech()` yalnız `speechSuccess` true iken bildirim yapar; öncesinde çağrılırsa
  hiçbir şey göndermez ve ilerlemez. Onay düğmesini yine de `speechSuccess`'e bağlayın.

> ❌ **Bypass yapmayın:** `confirmSpeech()` çağrılmadan ilerlerseniz `sendSpeechStatus`
> gitmez — backend konuşma doğrulamasını hiç görmez.
> Kural: [bypass yok](../../../docs/guides/customization.md#bypass-yok-kuralı).

---

## ViewModel Referansı — `SDKSpeechRecViewModel`

### State (`@Published`, salt-okunur)
| Üye | Tip | Anlam |
|---|---|---|
| `targetWord` | `String` | Söylenmesi gereken kelime (sunucudan gelir) |
| `isRecording` | `Bool` | Kayıt sürüyor mu |
| `recognizedText` | `String` | Tanınan metin |
| `speechSuccess` | `Bool` | Hedefle eşleşti mi |

### Metotlar
| Metot | Etki |
|---|---|
| `startRecording()` | Mikrofon + tanımayı başlatır |
| `stopRecording()` | Kaydı durdurur, sonucu değerlendirir |
| `confirmSpeech()` | `speechSuccess` ise **`manager.sendSpeechStatus` (soket)** + `onCompleted?()`; değilse yok sayılır |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onCompleted: (() -> Void)?` | Doğrulama tamamlandı |

## Sinyal Zinciri — Perde Arkası

```
startRecording()  → Speech tanıma → recognizedText / speechSuccess
stopRecording()   → değerlendirme
confirmSpeech()   → manager.sendSpeechStatus [SOKET] → onCompleted?()
host: → coordinator.advanceToNextModule() [modulePresented]
```

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class SpeechHostViewModel: HostModuleViewModel {
    let sdk = SDKSpeechRecViewModel()
    override init() {
        super.init(); bridge(sdk)
        sdk.onCompleted = { [weak self] in self?.log("speech_done") }
    }
    var word: String { sdk.targetWord }
    var heard: String { sdk.recognizedText }
    func start() { sdk.startRecording() }
    func stop()  { sdk.stopRecording() }
}
```

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .speech)         // Siri/sistem sesi
// veya kendi kaydınız: bundle'a SpeechTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .speech)    // dosya yoksa native'e düşer
```

> ⚠️ Hazır ekran yönerge okunurken mikrofonu kilitler. Kendi ekranınızda sesli okuma kayıtla
> çakışabilir: `SDKSpeechService.shared.isSpeaking` iken kaydı başlatmayın ya da bu modül için
> `.off` seçin.

Metni ezmek: `SDKLocalization.shared.setOverride(key: .speechTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Hedef kelime nereden gelir?** Sunucudan/akıştan — sabit değildir; UI'nizi uzun
  metinlere de hazırlayın.
- **Tanıma dili:** `IdentifyManager.shared.sdkLang`'e göre seçilir
  ([Lokalizasyon](../../../docs/guides/localization.md)).
- **Tanıma nerede çalışır?** Apple Speech framework'ünde. SDK `requiresOnDeviceRecognition`
  açmaz, iOS sesi Apple sunucusunda da tanıyabilir. Eşleştirme cihazda yapılır; sokete yalnızca
  başarı gider.
