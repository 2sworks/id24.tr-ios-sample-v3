# ThankYou — Sonuç Ekranı

Akışın son durağı. Kullanıcıya KYC sürecinin sonucunu gösterir: tamamlandı ya da
tamamlanamadı. **Tamamen pasiftir** — hiçbir soket/HTTP çağrısı yapmaz;
bu yüzden özelleştirme riski en düşük ekrandır.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.thankU` |
| Rota | `SDKModuleRoute.thankYou(ThankYouStatus?)` |
| Drop-in view | `SDKThankYouView` |
| ViewModel | `SDKThankYouViewModel` |
| Dış dünya | — (pasif terminal; soket/HTTP yok) |
| Ses anahtarı | `ThankYouTts` |

## İki Biçimde Gelir

- **Statüsüz** — `SDKThankYouView()`: `.completed` ekranını çizer (`init(status:)` varsayılanı).
- **Statülü** — `SDKThankYouView(status:)`: görüşme sonucu (`.completed` / `.notCompleted`).
  Panel karar verince ya da kullanıcı görüşmeyi bitirince CallScreen ekranı
  `coordinator.pushThankYouDirectly(status:)` ile açar.
  Görüşme soketten bitince sonucu `coordinator.pendingThankYouStatus`'a yazar; statü rotaya gömülür.

```swift
public enum ThankYouStatus: Hashable, Sendable {
    case completed      // Başarılı tamamlama
    case missedCall     // Çağrı cevapsız (3.3.0'da SDK bu statüyü üretmez)
    case notCompleted   // Tamamlanamadı
}
```

Cevapsız çağrıda SDK kullanıcıyı bekleme odasına döndürür; `.thankYou(.missedCall)` rotası açılmaz.

---

## Kullanım

```swift
// Drop-in (statüsüz)
SDKThankYouView()

// Drop-in (statülü)
SDKThankYouView(status: .completed)

// Görüşme akışından doğrudan geçiş
coordinator.pushThankYouDirectly(status: .completed)
```

`SDKFlowHostView` rotayı statüye göre çizer:

```swift
case .thankYou(let status):
    if let status { SDKThankYouView(status: status) }
    else          { SDKThankYouView() }
```

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [ThankYouCustomView.swift](ThankYouCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için dört rota değerinin hepsini kaydedin (`.thankYou(nil)`, `.completed`, `.missedCall`, `.notCompleted`); örnek: [CustomScreens.swift](../CustomKit/CustomScreens.swift)
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


```swift
registry.override(.thankYou(.completed)) {
    MyThankYouView(status: .completed)
}
```

> **Dikkat:** `.thankYou(_)` rotası **associated value** taşır — override belirli bir statü
> için kaydedilir. Tüm statüleri tek tasarımla karşılamak istiyorsanız her olası statü için
> ayrı `registry.override` kaydı ekleyin (ya da drop-in kullanıp
> [tema](../../../docs/guides/theming.md) ile `thankYouSuccess`/`thankYouFail`
> illüstrasyonlarını değiştirin).

---

## ViewModel Referansı — `SDKThankYouViewModel`

### Init
```swift
public init(status: ThankYouStatus = .completed)
```

### State (`@Published`, salt-okunur)
| Üye | Tip | Anlam |
|---|---|---|
| `status` | `ThankYouStatus` | Gösterilen sonuç |
| `isSelfieIdentification` | `Bool` | Selfie-only kimlik akışı mıydı |
| `kycCompleted` | `Bool` | Ekran açılmadan önce KYC tamamlanmış mıydı (`manager.kycIsCompleted`; VM açılışta bunu `true` yapar) |

Bu VM'in **girdi metodu veya çıktı closure'u yoktur** — terminal ekrandır. Modül sırası
tükendiğinde SDK bağlantıyı kendisi kapatır (kod 4100, `flowCompleted`); ekrandan sonra
`advanceToNextModule` yoktur.

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında sonuç mesajı otomatik seslendirilebilir (`SDKFlowHostView` yapar).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .thankU)         // Siri/sistem sesi
// veya kendi kaydınız: bundle'a ThankYouTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .thankU)    // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .thankYouTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **Bu ekran gösterilmesin istiyorum:** `setupSDK(showThankYouPage: false)` — hiçbir çıkış
  yolunda (akış sonu, panel kararı, modül hatası, kullanıcının görüşmeyi bitirmesi) açılmaz;
  SDK bulunduğu ekrandan aşağı kayarak kapanır ve sonuç `onFinished`'a gelir. Parametre
  verilmezse varsayılan `true`'dur. İstisna `quitSDK`: bu ayara bakmadan ThankYou ekranını
  döndürür; `false` verdiyseniz dönen ekranı göstermeyin. Yönlendirme kalıpları:
  [Oturum Çıkışları](../../../docs/guides/session-exit.md#9-kapanıştan-sonra-yönlendirme--kodu-nereye-yazacağım).
- **Ekrandayken sonucu okumak:** `IdentifyManager.shared.lastFlowOutcome` — ThankYou açıldığında
  sonuç bildirilmiştir (`result`, `reason`, panelin `terminateReason` / `statusSummary`'si).
- **Özelleştirmesi risksiz mi?** Evet — pasif olduğundan yerine/arasına ne koyarsanız koyun
  akış bozulmaz.
- **Kapanış kim yapar?** SDK yapar; ekran bunu tetiklemez. Akış sonunda bağlantı 4100
  (`flowCompleted`) koduyla kapanır.
