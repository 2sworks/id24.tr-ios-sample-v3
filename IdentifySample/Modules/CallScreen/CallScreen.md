# CallScreen — Görüntülü Görüşme

SDK'nın kalbi ve en karmaşık modülü: müşteri ile temsilci (agent) arasındaki **canlı WebRTC
görüşmesi**. Bekleme odası, çağrı kabul, SMS doğrulama, görüşme sırasında uzaktan NFC,
işaret dili kapısı ve bağlantı-koptu kurtarma — hepsi bu ekranda buluşur. Görüşme bittiğinde
sonuç statüsü ThankYou ekranına taşınır.

Altyapıyı anlamak için: [TURN & WebRTC](../../../docs/guides/turn-webrtc.md) ·
[WebSocket](../../../docs/guides/websocket.md)

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.waitScreen` |
| Rota | `SDKModuleRoute.callScreen` |
| Drop-in view | `SDKCallScreenView` |
| ViewModel | `SDKCallScreenViewModel` |
| Dış dünya | **WebRTC** + **soket** (çağrı aksiyonları) + HTTP |
| Ses anahtarı | `CallScreenTts` |

> Önemli: Bu modül çalışırken **soket dinleyicisini coordinator'dan devralır.** Ekrandan
> ayrılırken `coordinator.restoreSocketListener()` ile geri verilir. SDK ekranı bunu
> `onDisappear` içinde yapar; kendi ekranınızda bu çağrıyı siz yaparsınız.

## Kullanıcı Ne Yaşar?

1. Bekleme odasına düşer; sıradaki konumu ve tahmini bekleme süresini görür.
2. Temsilci aradığında çağrı ekranı gelir; kabul edince görüntülü görüşme başlar.
3. Görüşme sırasında temsilci SMS kodu isteyebilir, fotoğraf alabilir, uyarı/kimlik çemberi
   açabilir, hatta uzaktan NFC okuma başlatabilir.
4. Görüşme biter; sonuç (tamamlandı/tamamlanamadı) ThankYou'da gösterilir.

---

## Kullanım — Drop-in Şiddetle Önerilir

```swift
// Hiçbir şey yazmayın; rota gelince SDK çizer:
case .callScreen: SDKCallScreenView()
```

WebRTC peer connection, ICE aday değişimi, data channel ve soket aksiyon eşlemesi VM içinde
sıkı bağlıdır — yeniden yazmaya değmez. Marka uyumu için önce [Tema](../../../docs/guides/theming.md)'yı deneyin.

## Kendi Tasarımınızla (Override) — Dikkatli İlerleyin

> **Çalışan tam örnek:** [CallScreenCustomView.swift](CallScreenCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.callScreen) { CallScreenCustomView() }`
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


Tasarım değiştirilecekse iki kesin kural vardır:
**(1)** video katmanlarını VM'den alın, **(2)** tüm çağrı eylemleri VM'den geçsin.

```swift
registry.override(.callScreen) { MyCallView() }

struct MyCallView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKCallScreenViewModel()

    var body: some View {
        ZStack {
            // WebRTC video katmanları — kendiniz peer connection KURMAYIN:
            if let remote = vm.remoteVideoView { MyVideoHost(view: remote) }   // ✅
            if let local  = vm.localVideoView  { MyVideoHost(view: local) }    // ✅

            VStack {
                Text("Sıra: \(vm.queuePosition)")
                if vm.callState == .ringing {
                    Button("Kabul Et") { vm.acceptCall() }                 // ✅ soket + WebRTC
                }
                TextField("SMS", text: $vm.smsCode)
                Button("Doğrula") { vm.verifySMS() }
                    .disabled(!vm.isSMSCodeValid)                          // ✅
                Button("Bitir") { vm.terminateCall(coordinator: coordinator) }  // ✅
                    .disabled(!vm.endCallEnabled)
            }
        }
        .onAppear {
            IdentifyManager.shared.socketMessageListener = vm      // ✅ soket aksiyonları bu VM'e
            IdentifyManager.shared.replayPendingQueueStats()        // ekrandan önce gelen sıra bilgisi
            vm.checkSignLangIfNeeded()     // showSignLangGate'i açar; kapıyı siz gösterirsiniz
        }
        .onDisappear {
            coordinator.restoreSocketListener()                     // ✅ dinleyiciyi geri ver
            vm.cleanup()
        }
        .onChange(of: vm.socketThankYouStatus) { status in         // endCall, ret
            guard status != nil else { return }
            coordinator.advanceToNextModule()
        }
        .onChange(of: vm.directThankYouStatus) { status in         // panel kararı, kopma sınırı
            guard let status else { return }
            vm.finishSDKForDirectThankYou()                         // SDK'yı kapatır (4103)
            coordinator.pushThankYouDirectly(status: status)
        }
    }
}
```

`coordinator.pendingThankYouStatus`'ın setter'ı host'a açık değildir. Kendi ekranınızdan
çağrılan `advanceToNextModule()` ThankYou rotasını statüsüz (`.thankYou(nil)`) açar; SDK'nın
ThankYou ekranı bunu `.completed` olarak çizer. Statüyü kendi ThankYou ekranınıza siz taşıyın
(örnek uygulama `CustomScreens.pendingThankYouStatus` kullanır).

Video katmanları için bilmeniz gerekenler:

- `remoteVideoView` / `localVideoView` kendini boyutlayan kapsayıcılardır: görüntünün en-boy
  oranını SDK korur. Kendi `UIViewRepresentable`'ınızda view'ı **dört kenara sabitleyin**,
  frame'ini elle vermeyin ve `contentMode` ile oynamayın (render view bunu dikkate almaz).
- İki özellik `@Published` değildir; görüşme başlamadan `nil` olabilir. Görünümü
  `vm.callState` değişiminde yeniden okuyun.
- Her görüşmede view yeniden yaratılır; bir önceki görüşmenin view referansını saklamayın.

```swift
struct MyVideoHost: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ container: UIView, context: Context) {
        guard view.superview !== container else { return }
        view.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}
```

---

## ViewModel Referansı — `SDKCallScreenViewModel`

### Tipler
```swift
public enum SDKCallState { case waiting, ringing, connected, smsVerification, nfcReading, ended }
public enum SDKCallNetworkQuality { case none, bad, medium, good }
```

### Çağrı durumu (`@Published`, salt-okunur)
| Üye | Tip | Anlam |
|---|---|---|
| `callState` | `SDKCallState` | Bekliyor / bağlı / bitti |
| `queuePosition` | `String` | Sıradaki konum |
| `estimatedWait` | `String` | Tahmini bekleme |
| `networkQuality` | `SDKCallNetworkQuality` | Ağ kalitesi |
| `endCallEnabled` | `Bool` | "Görüşmeyi bitir" aktif mi (agent kilitleyebilir) |
| `callCompleted` | `Bool` | Görüşme tamamlandı mı |
| `socketThankYouStatus` | `ThankYouStatus?` | Soketten gelen sonuç statüsü |
| `directThankYouStatus` | `ThankYouStatus?` | Panel karar verdiyse ya da kopma sınırı dolduysa sonuç; ThankYou doğrudan açılır |
| `photoTakenToast` | `String?` | "Fotoğraf alındı" bildirimi |
| `lostConnectionCallCompleted` | `Bool` | Kopma sonrası görüşme tamamlandı mı |

### SMS doğrulama
| Üye | Tip | Anlam |
|---|---|---|
| `smsCode` | `String` (r/w) | Girilen SMS kodu |
| `isSMSCodeValid` | `Bool` | Kod 6 haneli mi |

### Uzaktan NFC (temsilci tetikler)
| Üye | Tip | Anlam |
|---|---|---|
| `nfcStatusMessage` | `String` | NFC durum metni |
| `showNFCEdit` | `Bool` (r/w) | MRZ düzenleme ekranı |
| `nfcEditSerial / nfcEditBirth / nfcEditValid` | `String` (r/w) | Düzenlenebilir MRZ alanları |

### İşaret dili / kopma
| Üye | Tip | Anlam |
|---|---|---|
| `showSignLangGate` | `Bool` (r/w) | İşaret dili kapısını göster |
| `showLostConnection` | `Bool` (r/w) | Bağlantı-koptu overlay'i |

### Video (WebRTC)
| Üye | Anlam |
|---|---|
| `remoteVideoView: UIView?` | Uzak (temsilci) video katmanı |
| `localVideoView: UIView?` | Yerel (kullanıcı) video katmanı |

### Arka kamera odağı (3.3.0)
| Üye | Tip | Anlam |
|---|---|---|
| `isBackCameraFocusAvailable` | `Bool` (`@Published`) | Arka kamera açık ve odak kullanılabilir mi |
| `focusMark` | `SDKFocusMark?` | Son dokunulan nokta (`point`, önizlemeye oranla 0...1). Odak karesini çizmek için |
| `isBackCameraActive` | `Bool` | Arka kamera açık mı |
| `agentIsLarge` | `Bool` | Büyük ekranda temsilci mi var |
| `focusBackCameraAtCenter()` | `Bool` | Görüntünün ortasına bir kez odaklar |
| `focusBackCamera(at:)` | `Bool` | Verilen noktaya odaklar, (0,0) sol üst. Arka kamera kapalıysa `false` |

Ayrıntı: [Arka Kamera Odağı](#arka-kamera-odağı-330).

### Metotlar
| Metot | Etki |
|---|---|
| `checkSignLangIfNeeded()` | Kapı bekliyorsa (`signLangSupport: true`, `signLangPreference` `nil`) işaret dili kapısını açar |
| `signLangCompleted()` | İşaret dili adımını tamamlar |
| `acceptCall()` | Çağrıyı kabul eder (`manager.acceptCall`) — TURN kimliği + SDP offer. Çalan çağrı yoksa ya da bağlantı kapanıyorsa **başarısız döner** ve `errorMessage` dolar |
| `terminateCall(coordinator:)` | Görüşmeyi bitirir + ThankYou'yu `.notCompleted` ile açar (`showThankYouPage: false` ise akış aşağı kayarak kapanır). Dinleyiciyi geri vermez. Sonuç: `onFinished` → `notCompleted` / `userEndedCall`. Panelin kapatması (`terminateCall`) için: [Görüşmenin Kapanışı](../../../docs/guides/websocket.md#görüşmenin-kapanışı--terminatecall) |
| `verifySMS()` | SMS kodunu doğrular (`manager.smsVerification`) |
| `startRemoteNFC(birthDate:validDate:docNo:)` | Uzaktan NFC okumayı başlatır |
| `saveAndRestartRemoteNFC(serial:birth:valid:)` | MRZ'yi düzeltip NFC'yi yeniden başlatır |
| `handleReconnectCompleted()` / `handleReconnectCompletedWithStatus(...)` | Kopma sonrası kurtarma |
| `finishSDKForDirectThankYou()` | `directThankYouStatus` gelince SDK'yı kapatır (`forceQuitSDK`, soket 4103). `pushThankYouDirectly`'den önce çağrılır |
| `cleanup()` | Kaynakları temizler (ekrandan ayrılırken). Dinleyiciyi geri vermez |

### Soket dinleyici
```swift
nonisolated public func listenSocketMessage(message: SDKCallActions)
```
CallScreen aktifken soket mesajlarını **doğrudan bu VM** işler (coordinator yerine).
Ekran açılınca `IdentifyManager.shared.socketMessageListener = vm` atanır, kapanınca
`coordinator.restoreSocketListener()` çağrılır.
Aksiyonların tam listesi: [WebSocket → Aksiyon Kataloğu](../../../docs/guides/websocket.md#aksiyon-kataloğu--sdkcallactions).

## Gelen Arama Zili ve Çalma Penceresi

Zil (sistem sesi + titreşim) tamamen SDK'nın sorumluluğundadır — kendi çağrı ekranınızı
yazsanız bile zili siz başlatmaz/durdurmazsınız. Çalma durumunun sahibi
`IdentifyManager.isRinging`'dir; çalma hangi yoldan biterse bitsin (yanıtlama, endCall,
terminateCall, imOffline, çalma zaman aşımı, kopma, SDK kapanışı) zil de susar.

```swift
let m = IdentifyManager.shared
m.incomingCallRingtoneEnabled  = true   // sistem sesi (sessiz modda iOS çalmaz)
m.incomingCallVibrationEnabled = true   // CoreHaptics — sessiz modda da hissedilir
m.incomingCallRingtoneInterval = 2.5    // iki zil arası (sn)
m.ringingTimeout               = 300    // yanıtlanmazsa sonlandırma süresi (sn)
```

- **Sessiz mod:** Sistem sesi iOS kısıtı gereği çalmaz; titreşim CoreHaptics üzerinden
  verildiği için sessiz anahtarından etkilenmez. Dokunsallık donanımı olmayan cihazlarda
  (iPhone 7 ve öncesi) eski `AudioServicesPlaySystemSound` yoluna düşülür.
- **`hideCallAnswerScreen` açıkken zil hiç çalmaz.** Bayrak sunucunun `hide_call_answer_screen`
  ayarından gelir; `setupSDK` oda yanıtını alınca değeri yeniden yazar, önceden verdiğiniz değer
  ezilir. Hazır görüşme ekranı bu durumda çağrıyı kendisi yanıtlar. Kendi görüşme ekranınızda
  bayrak açıksa `acceptCall()`'u siz çağırın. Çağırmazsanız çağrı zilsiz çalar ve
  `ringingTimeout` dolunca 4108 ile düşer.
- **Çalma zaman aşımı (4108):** Temsilci tarafı çağrıyı iptal edemediğinden yanıtlanmayan
  çağrının bir üst sınırı vardır. Süre `initCall` anından ölçülür; dolduğunda
  `terminateCall("RINGING_TIMEOUT")` yayınlanır.
- **Yinelenen `initCall`** yok sayılır: görüşme sürerken ikinci bir çalma ekranı açılmaz.

### Çağrı durumu (salt-okunur)

```swift
IdentifyManager.shared.isRinging     // temsilci aradı, henüz yanıtlanmadı
IdentifyManager.shared.isCallActive  // görüşme sürüyor
```

## Görüşme Sağlık Raporu

Görüşme bittiğinde SDK tek satırlık bir sağlık özeti üretir; sunucuya `call_health`
tipiyle gider ve host'a da açıktır:

```swift
if let r = IdentifyManager.shared.lastCallHealthReport {
    print(r.durationText, r.isHealthy, r.socketDropCount, r.iceDisconnectCount)
}
```

Rapor; socket kopma sayısı ve çevrimdışı süre, ICE kesinti/başarısızlık/toparlanma
sayıları ve kesintili süre, cihazın internet kaybı ile WiFi↔hücresel geçiş sayısı, en uzun
sunucu sessizliği ve bitişteki ICE durumunu içerir. Saha sorunlarını ("görüşme koptu")
tek kayıttan teşhis etmek içindir.

## Sinyal Zinciri — Perde Arkası

```
(görünür) → socketMessageListener = vm
          → checkSignLangIfNeeded() → signLangGatePending ? showSignLangGate
acceptCall()         → manager.acceptCall [SOKET] + WebRTC peer connection kurulur
                       remoteVideoView / localVideoView (WebRTC track'leri)
verifySMS()          → manager.smsVerification [SOKET]
startRemoteNFC(...)  → manager.startRemoteNFC (CoreNFC) → nfcMsgHandler
listenSocketMessage  → çağrı aksiyonları (sonuç statüsü, foto alındı, kopma...)
terminateCall(coordinator:)
   → manager.terminateCallByUser [SOKET]
   → callState = .ended
   → coordinator.pushThankYouDirectly(status: .notCompleted)
socketThankYouStatus (endCall, ret)
   → coordinator.pendingThankYouStatus = status
   → coordinator.advanceToNextModule()  →  .thankYou(status)
directThankYouStatus (panel kararı, kopma sınırı)
   → finishSDKForDirectThankYou()       (soket 4103)
   → coordinator.pushThankYouDirectly(status:)
(kaybolur) → coordinator.restoreSocketListener() → cleanup()
```

## Host VM ile Gözlem (Composition) — Güvenli

```swift
@MainActor
final class CallHostViewModel: HostModuleViewModel {
    let sdk = SDKCallScreenViewModel()
    override init() { super.init(); bridge(sdk) }
    var state: SDKCallState { sdk.callState }
    var queue: String { sdk.queuePosition }
    var quality: SDKCallNetworkQuality { sdk.networkQuality }
}
```

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .waitScreen)         // Siri/sistem sesi
// veya kendi kaydınız: bundle'a CallScreenTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .waitScreen)    // dosya yoksa native'e düşer
```

> ⚠️ Okuma, WebRTC sesiyle çakışmasın diye `.duckOthers` ile kısılır; canlı görüşme
> başladıktan sonra bu modülde `.off` önerilir.

Metni ezmek: `SDKLocalization.shared.setOverride(key: .callScreenTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Arka Kamera Odağı (3.3.0)

Temsilci kullanıcıdan belgeyi arka kameraya göstermesini istediğinde kamera yakına odaklanır.
Sürekli otomatik odak açıktır. Önizlemeye dokunulunca o noktaya odaklanılır ve sarı bir kare
çıkar. Arka kamera açıkken kullanıcının görüntüsü büyük ekrana geçer, temsilci küçük pencereye
iner. Ön kameraya dönülünce `bigCustomerCam` ile seçilen yerleşim geri gelir.

Üç ayar var, üçü de varsayılan açık:

```swift
let m = IdentifyManager.shared
m.backCameraFocusEnabled = true    // false: kameranın kendi odağı, dokunma ve focusBackCamera çalışmaz
m.tapToFocusEnabled = true         // false: dokunmayı host yakalar, focusBackCamera(at:) ile odaklar
m.swapsLayoutOnBackCamera = true   // false: arka kamerada yerleşim değişmez (görüşmeden önce verin)
```

`backCameraFocusEnabled` görüşme sırasında `false` yapılırsa hemen eski odağa dönülür. `true`
yapılırsa arka kamera bir sonraki açılışta odaklanır.

Odağı host'tan istemek ve durumu izlemek için:

```swift
m.onBackCameraFocusAvailabilityChanged = { available in
    focusButton.isHidden = !available      // ön kamera, kamera kapalı ya da odak kapalıysa false
}
m.onBackCameraFocusTapped = { point in
    // dokunulan nokta, kullanıcının görüntüsüne oranla (0...1)
}
m.focusBackCameraAtCenter()                       // ortaya bir kez odaklanır, sonra sürekli odağa döner
m.focusBackCamera(at: CGPoint(x: 0.5, y: 0.3))    // görüntü dışı ya da ön kamerada false döner
```

Bu üyeler `@MainActor` üzerindedir. Anlık durum için `m.isBackCameraFocusAvailable` okunur.

Odak karesinin görünümü temadan değişir:

```swift
SDKTheme.shared.setFocusIndicator { size in       // size varsayılan 68, küçük önizlemede daha küçük
    Circle().stroke(.white, lineWidth: 2).frame(width: size, height: size)
}
SDKTheme.shared.resetFocusIndicator()             // varsayılan sarı kare
SDKTheme.shared.capture.focusIndicatorColor = .green  // yalnız rengi değiştirmek için
SDKTheme.shared.capture.showsFocusIndicator = false   // kare çizilmez, odak yine çalışır
```

Görüşme sırasında kamera durursa görüntü kendiliğinden yeniden açılır. Kullanıcıya uyarı
çıkmaz.

---

## Sık Sorulanlar & Dikkat Edilecekler

- **`terminateCall(coordinator:)`'ı asla atlamayın.** Panele `terminateCallOnMobile`
  gönderir (bağlantı yoksa görüşmeyi yalnız cihazda kapatır) ve sonucu bildirir. Dinleyiciyi
  ekranın `onDisappear`'ındaki `coordinator.restoreSocketListener()` geri verir; bu çağrı
  eksik kalırsa sonraki ekranlar soket mesajı almaz.
- **İşaret dili:** `signLangSupport: true` ise `checkSignLangIfNeeded()` kapıyı açar;
  `signLangPreference` verildiyse açmaz. Ayrıntı:
  [SignLang rehberi](../SignLang/SignLang.md).
- **Bağlantı koparsa:** `showLostConnection` overlay'i devreye girer —
  [LostConnection rehberi](../LostConnection/LostConnection.md).
- **Görüşme kurulamıyor / tek yönlü medya:** Neredeyse her zaman TURN kimlik sorunudur —
  [TURN & WebRTC → Sorun Giderme](../../../docs/guides/turn-webrtc.md#sorun-giderme).
- **Simülatör:** Kamera yok — görüşme yalnızca gerçek cihazda test edilir. Zil titreşimi
  ve ICE kopma davranışı da yalnızca cihazda doğrulanabilir.
- **`acceptCall()` başarısız dönebilir:** Yeniden bağlanma sonrası ekranda asılı kalmış eski
  bir çalma ekranından "yanıtla"ya basılırsa SDK `startCall` göndermez ve hata döner. Kendi
  ekranınızı yazıyorsanız bu yolu mutlaka ele alın — aksi halde kullanıcı sonsuz "bağlanıyor"
  durumunda kalır.
- **Zili siz yönetmeyin:** `SDKRingtonePlayer` SDK'ya özeldir; çalma/susturma `isRinging`
  üzerinden tek noktadan yapılır. Kendi çağrı ekranınızda zil başlatmaya çalışmayın.
