# SignLang — İşaret Dili Kapısı

Bağımsız bir akış modülü değil, bir **kapı (gate)** ekranıdır: görüşme öncesinde kullanıcıya
"işaret dili destekli temsilci ister misiniz?" diye sorar. Tercih, backend'e sokete bildirilir
ve kullanıcı doğru temsilci kuyruğuna yönlendirilir — erişilebilirlik için küçük ama önemli
bir adım.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md) · İlgili: [CallScreen](../CallScreen/CallScreen.md)

---

## Bir Bakışta

|              |                                                                       |
| ------------ | --------------------------------------------------------------------- |
| Backend key  | — (CallScreen alt-ekranı; ayrı rota yok)                              |
| Tetikleyici  | `SDKCallScreenViewModel.checkSignLangIfNeeded()` → `showSignLangGate` |
| Drop-in view | `SDKSignLangView`                                                     |
| ViewModel    | `SDKSignLangViewModel`                                                |
| Dış dünya    | **Soket** (`sendStep`)                                                |

Kapının görünmesi için `setupSDK(signLangSupport: true)` verilmeli ve `signLangPreference`
boş (`nil`) bırakılmalıdır.

---

## Tanımlama

```swift
IdentifyManager.shared.setupSDK(
    identId: identId,
    baseApiUrl: baseApiUrl,
    networkOptions: SDKNetworkOptions(timeoutIntervalForRequest: nil,
                                      timeoutIntervalForResource: nil,
                                      useSslPinning: false),
    kpsData: nil,
    signLangSupport: true,          // görüşme ekranı açılınca kapı gösterilir
    ...
)
```

| `signLangSupport` | Davranış |
|---|---|
| `false` | Kapı açılmaz. Bekleme ekranına gelindiği anda `stepChanged` gider, müşteri paneldeki bekleme odasına düşer (`sign_language: false`). |
| `true` | Görüşme ekranı açılınca kapı gösterilir. `stepChanged`, kullanıcı **Devam**'a basana kadar **gönderilmez**; müşteri panelde bu seçimden sonra görünür. |

- Toggle varsayılan olarak **kapalı** gelir (`isSignLangEnabled = false`). `setupSDK`'da bunu
  önceden açan bir parametre yoktur; açık gelmesini istiyorsanız kendi ekranınızda
  `vm.isSignLangEnabled = true` atayın.
- Tercihi kendi ekranınızda topladıysanız `setupSDK(signLangPreference:)` verin (ya da
  `setupSDK`'dan sonra, görüşmeden önce `IdentifyManager.shared.signLangPreference` atayın).
  Kapı açılmaz, değer `sign_language` olarak gider. `setupSDK` bu değeri her oturumda sıfırlar.

## Sunucuya Giden Veri

Tercih, `stepChanged` aksiyonunun `steps` nesnesinde `sign_language` alanıyla gider:

```json
{
  "action": "stepChanged",
  "location": "Call Wait Screen",
  "room": "<customer_uid>",
  "steps": {
    "language": "TR",
    "sign_language": true,
    "...": "diğer modül adımları"
  }
}
```

| Alan | Tip | Değer |
|---|---|---|
| `steps.sign_language` | `Bool` | `signLangPreference` verildiyse o değer; verilmediyse kullanıcı toggle'ı açıp **Devam**'a bastıysa `true`, aksi hâlde `false` |

Temsilci havuzu seçimi bu alana göre sunucu tarafında yapılır.

## Metinler

Ekrandaki metinler `SDKLocalization` anahtarlarıyla değiştirilir
([Lokalizasyon](../../../docs/guides/localization.md)):

| Anahtar | Yer | Varsayılan (TR) |
|---|---|---|
| `.signLangTitle` (`SignLangTitle`) | Başlık | İşaret Dili Desteği |
| `.signLangDesc` (`SignLangDesc`) | Açıklama | Görüntülü görüşme sürecinde size işaret dili bilen bir müşteri temsilcisi bağlamak ister misiniz? |
| `.coreSignLang` (`CoreSignLang`) | Toggle etiketi | İşaret dili bilen bir müşteri temsilcisi ile görüşmek istiyorum |

```swift
SDKLocalization.shared.setOverride(key: .signLangTitle, language: .tr, value: "Erişilebilir Görüşme")
```

Simge: `SDKTheme` ikonu `.signLang` (`person.wave.2.fill`).

---

## ViewModel Referansı — `SDKSignLangViewModel`

VM o kadar küçük ki tamamını gösterebiliriz:

```swift
@MainActor
public final class SDKSignLangViewModel: SDKBaseModuleViewModel {
    @Published public var isSignLangEnabled: Bool = false

    public func continueAction(onFinish: @escaping @MainActor () -> Void) {
        manager.connectToSignLang = isSignLangEnabled
        manager.signLangPreference = isSignLangEnabled   // kapı geçildi
        manager.sendStep()        // [SOKET] tercihi backend'e bildir
        onFinish()                // (log ve rapor satırları gösterilmedi)
    }
}
```

| Üye | Tip | Anlam |
|---|---|---|
| `isSignLangEnabled` | `Bool` (r/w) | İşaret dili desteği isteniyor mu |
| `continueAction(onFinish:)` | metot | Tercihi kaydeder + `sendStep` (soket) + `onFinish` |

> Diğer modüllerin aksine `onCompleted` closure'u yoktur; `continueAction` doğrudan bir
> `onFinish` parametresi alır.

## Sinyal Zinciri — Perde Arkası

```
isSignLangEnabled = true/false           (kullanıcı tercihi)
continueAction(onFinish:)
   → manager.connectToSignLang = isSignLangEnabled
   → manager.signLangPreference = isSignLangEnabled
   → manager.sendStep()                  [SOKET]
   → onFinish()                          → CallScreen.signLangCompleted() / kapıyı kapat
```

---

## Kendi Tasarımınızla

> **Çalışan tam örnek:** [SignLangCustomView.swift](SignLangCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Bu ekran bir rota değildir; özel görüşme ekranı ([CallScreenCustomView.swift](../CallScreen/CallScreenCustomView.swift)) içinden açılır.
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


Toggle'ınız nasıl görünürse görünsün, tercih **mutlaka** `continueAction`'dan geçmeli:

```swift
struct MySignLangView: View {
    @StateObject private var vm = SDKSignLangViewModel()
    let onFinish: () -> Void

    var body: some View {
        VStack {
            Toggle("İşaret dili desteği istiyorum", isOn: $vm.isSignLangEnabled)
            Button("Devam") {
                vm.continueAction(onFinish: onFinish)   // ✅ connectToSignLang + sendStep
            }
        }
    }
}
```

> ❌ **Bypass yapmayın:** `manager.connectToSignLang`'ı elle set edip geçmeyin —
> `continueAction` çağrılmazsa `sendStep` gitmez ve backend tercihi hiç görmez;
> kullanıcı yanlış kuyruğa düşer.

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class SignLangHostViewModel: HostModuleViewModel {
    let sdk = SDKSignLangViewModel()
    override init() { super.init(); bridge(sdk) }

    var isEnabled: Bool {
        get { sdk.isSignLangEnabled }
        set { sdk.isSignLangEnabled = newValue; log("signlang_toggle_\(newValue)") }
    }
    func applyDefault(_ enabled: Bool) { sdk.isSignLangEnabled = enabled }
    func proceed() {
        sdk.continueAction(onFinish: { [weak self] in self?.onCompleted?() })
    }
}
```

---

## Sesli Okuma (Read-Aloud)

Bu ekran bir **overlay**'dir ve akış rotası olmadığından **otomatik sesli okuma uygulanmaz.**
Gerekirse elle okutun:

```swift
SDKSpeechService.shared.speak(text: "İşaret dili desteği ister misiniz?")
SDKSpeechService.shared.stop()
```

Genel bilgi: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Kapı hiç görünmüyor:** `signLangSupport: true` verilmiş mi? `signLangPreference` verildiyse
  kapı açılmaz. Kapıyı CallScreen açar (`checkSignLangIfNeeded()`); tek başına bir rota yoktur.
- **Kuyruk etkisi:** İşaret dili seçen kullanıcı normal görüşme kuyruğuna düşmez —
  doğru temsilci havuzuna yönlendirilir.
