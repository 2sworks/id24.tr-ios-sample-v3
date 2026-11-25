# VideoRecorder — Kısa Video Kaydı

Kullanıcı, ekrandaki metni sesli okurken kısa bir video çeker (varsayılan 5 sn). Sunucu
istiyorsa, okunan metin **konuşma tanıma ile doğrulanır** — böylece videonun gerçekten o
oturumda ve o kişi tarafından çekildiği kanıtlanır. Video HTTP ile yüklenir.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.videoRecord` |
| Rota | `SDKModuleRoute.videoRecorder` |
| Drop-in view | `SDKVideoRecorderView` |
| ViewModel | `SDKVideoRecorderViewModel` |
| Dış dünya | **HTTP** (`upload5SecVideo`) + isteğe bağlı konuşma doğrulama (sunucuda) |
| Ses anahtarı | `VideoRecorderTts` |

## Kullanıcı Ne Yaşar?

1. Ekranda okunacak metni görür (metin sunucudan gelir).
2. Kayda başlar, metni sesli okur; süre dolunca kayıt biter.
3. (Sesli doğrulama açıksa) okunan metin arka planda eşleştirilir; tutmuyorsa yeniden çeker.
4. Kaydı izleyebilir; onay düğmesine basınca video yüklenir, akış ilerler.

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKVideoRecorderView` çizilir.

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [VideoRecorderCustomView.swift](VideoRecorderCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.videoRecorder) { VideoRecorderCustomView() }`
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


Kamera/kayıt UI'ı sizin; sunucu ayarı, transkripsiyon ve yükleme SDK'da kalır:

```swift
registry.override(.videoRecorder) { MyVideoView() }

struct MyVideoView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKVideoRecorderViewModel()

    var body: some View {
        VStack {
            if let text = vm.readingText { Text(text) }       // okunacak metin
            MyRecorderView(maxDuration: vm.videoTimeLimit) { recordedURL in
                vm.videoSelected(url: recordedURL)            // ✅ okuma metni varsa transkripsiyon
            }
            Button("Tekrar çek") { vm.deleteVideo() }
            Button("Gönder") { vm.uploadVideo() }             // ✅ manager.upload5SecVideo
                .disabled(vm.videoData == nil && vm.videoURL == nil)
        }
        .onAppear {
            vm.onCompleted = { coordinator.advanceToNextModule() }   // ✅
            vm.configureFromSDK()                                    // ✅ süre, okuma metni, eşik sunucudan
        }
    }
}
```

---

## ViewModel Referansı — `SDKVideoRecorderViewModel`

### State
| Üye | Tip | Erişim | Anlam |
|---|---|---|---|
| `videoData` | `Data?` | r/w | Çekilen video verisi |
| `videoURL` | `URL?` | r/w | Çekilen video dosya yolu |
| `uploadCompleted` | `Bool` | salt-okunur | Yükleme tamamlandı mı |
| `readingText` | `String?` | salt-okunur | Okunacak metin |
| `recognizedText` | `String` | salt-okunur | Tanınan metin (konuşma) |
| `speechSuccess` | `Bool` | salt-okunur | Metin eşleşti mi |
| `isTranscribing` | `Bool` | salt-okunur | Transkripsiyon sürüyor mu |

### Sabit
| Üye | Değer | Anlam |
|---|---|---|
| `videoTimeLimit` | `5.0` | Maksimum kayıt süresi (sn), salt-okunur. Sunucudaki süreyi `configureFromSDK()` yazar; kaydı bu sürede durdurmak kayıt ekranının işidir |

### Metotlar
| Metot | Etki |
|---|---|
| `configureFromSDK()` | Sunucudan gelen süreyi, okuma metnini ve eşleşme eşiğini uygular. Hazır ekran kendisi çağırır; kendi ekranınızda `onAppear`'da çağırın (metni `updateReadingText` ile siz vermiyorsanız) |
| `updateReadingText(_ text: String)` | Okunacak metni günceller |
| `videoSelected(url: URL)` | Videoyu alır; okuma metni varsa sesi ayırıp sunucuda yazıya döktürür |
| `deleteVideo()` | Videoyu siler (yeniden çekim) |
| `uploadVideo()` | Videoyu sunucuya gönderir → `onCompleted` |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onCompleted: (() -> Void)?` | Yükleme başarılı |

## Sinyal Zinciri — Perde Arkası

```
configureFromSDK()      → videoTimeLimit / readingText / eşik (sunucu ayarından)
updateReadingText(_:)   → readingText (UI)
videoSelected(url:)     → videoData/videoURL → (readingText varsa) manager.transcribeSpeech [HTTP] → speechSuccess
uploadVideo()           → manager.upload5SecVideo [HTTP] → onCompleted?()
host: → coordinator.advanceToNextModule() [modulePresented]
```

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class VideoRecorderHostViewModel: HostModuleViewModel {
    let sdk = SDKVideoRecorderViewModel()
    override init() {
        super.init(); bridge(sdk)
        sdk.onCompleted = { [weak self] in self?.log("video_done") }
    }
    var prompt: String { sdk.readingText ?? "" }
    func picked(_ url: URL) { sdk.videoSelected(url: url) }
    func upload() { sdk.uploadVideo() }
}
```

---

## Sesli Okuma (Read-Aloud)

Hazır ekran yönergeyi kendisi okur: okuma metni varsa `VideoRecorderReadingTts`, yoksa
`VideoRecorderTts`. `SDKFlowHostView` bu rotada otomatik okuma yapmaz. Kendi ekranınızda
`SDKSpeechService.shared.speak(.videoRecorderTts, in: .videoRecord, whenCameraReady: true)` çağırın.

```swift
SDKSpeechConfig.shared.setMode(.native, for: .videoRecord)        // Siri/sistem sesi
// veya kendi kaydınız: bundle'a VideoRecorderTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .videoRecord)   // dosya yoksa native'e düşer
```

> ⚠️ Kayıt sırasında mikrofon açıktır; native okuma kayda karışabilir. Yönergeyi kayıt
> **başlamadan** okutun ya da bu modülde `.customAudio` / `.off` tercih edin.

Metni ezmek: `SDKLocalization.shared.setOverride(key: .videoRecorderTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Sesli doğrulama nasıl açılır?** Sunucu tarafından — okunacak metin, eşleşme eşiği ve
  süre sunucudan gelir
  ([Sunucu & API](../../../docs/guides/server-api.md#roomresponse--akışı-şekillendiren-alanlar)).
  Kararı **metin** verir: `video_record_read_text` (yoksa `speech_expected_sentence`)
  doluysa doğrulama açılır ve metin ekranda gösterilir; boşsa okunacak bir şey olmadığı
  için kapalıdır. `video_record_speech` bayrağı belirleyici değildir — panel metni
  doldurduğu hâlde bayrağı `0`/eksik gönderdiğinde metin ekranda hiç görünmüyordu.
- **Kayıt süresi birimi:** `video_record_duration` sunucudan **milisaniye** gelir
  (6000 → 6 sn). SDK saniyeye çevirir ve 3–120 sn aralığına sıkıştırır.
- **Video reddediliyor:** `videoSelected` kaydı boyutuna bakmadan alır; bu modülde SDK
  `requestMaxBodySize` sınırını uygulamaz. Sunucu yüklemeyi reddederse `uploadVideo` hata
  mesajı gösterir ve `onCompleted` çağrılmaz. Süreyi ve çözünürlüğü düşürün.
- **`speechSuccess` ne zaman anlamlı?** Yalnızca okuma-metni senaryosunda; doğrulama
  kapalıysa bu alanları yok sayın.
- **Yardım (?) düğmesi:** 3.3.0'dan beri varsayılan kapalı. Yalnız bu ekranda açmak için
  `SDKTheme.shared.navBar.routeButtons[.videoRecorder] = SDKNavBarButtons(showsHelp: true)`. SDK düğmeye işlev
  bağlamaz, `onHelp` vermezseniz basılınca bir şey olmaz;
  işlev vermek ya da kendi düğmenizi eklemek için [Başlık Çubuğu Düğmeleri](../Modules.md#başlık-çubuğu-düğmeleri).
