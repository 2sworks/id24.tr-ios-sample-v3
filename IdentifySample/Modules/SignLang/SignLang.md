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

Kapının görünmesi için `setupSDK(signLangSupport: true)` verilmelidir.

---

## Tanımlama

```swift
IdentifyManager.shared.setupSDK(
    identId: identId,
    baseApiUrl: baseApiUrl,
    networkOptions: SDKNetworkOptions(),
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
| `steps.sign_language` | `Bool` | Kullanıcı toggle'ı açıp **Devam**'a bastıysa `true`, aksi hâlde `false` |

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
public final class SDKSignLangViewModel: SDKBaseModuleViewModel {
    @Published public var isSignLangEnabled: Bool = false

    public func continueAction(onFinish: @escaping () -> Void) {
        manager.connectToSignLang = isSignLangEnabled
        manager.sendStep()        // [SOKET] tercihi backend'e bildir
        onFinish()
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
   → manager.sendStep()                  [SOKET]
   → onFinish()                          → CallScreen.signLangCompleted() / kapıyı kapat
```

---

## Kendi Tasarımınızla

> **Çalışan tam örnek:** [SignLangCustomView.swift](SignLangCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Bu ekran bir rota değildir; özel görüşme ekranı ([CallScreenCustomView.swift](../CallScreen/CallScreenCustomView.swift)) içinden açılır.
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Özel Ekranlar** ile açılıp kapatılır.


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

- **Kapı hiç görünmüyor:** `signLangSupport: true` verilmiş mi? Kapıyı CallScreen açar
  (`checkSignLangIfNeeded()`); tek başına bir rota yoktur.
- **Kuyruk etkisi:** İşaret dili seçen kullanıcı normal görüşme kuyruğuna düşmez —
  doğru temsilci havuzuna yönlendirilir.
