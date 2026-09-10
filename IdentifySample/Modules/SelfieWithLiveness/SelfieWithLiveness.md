# SelfieWithLiveness — Selfie + Canlılık (Birleşik)

Selfie çekimi ile canlılık testini **tek ekranda** birleştiren varyant: kullanıcı tek
oturuşta hem yüz fotoğrafını verir hem canlı olduğunu kanıtlar. Akışı kısaltmak isteyen
kurumlar için idealdir.

Diğer modüllerden önemli bir farkı var: bu modül **UIKit controller tabanlıdır**
(`SDKSelfieWithLivenessController`) ve henüz ayrı bir public ViewModel yüzeyi yoktur.

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.selfieWithLiveness` |
| Rota | `SDKModuleRoute.selfieWithLiveness` |
| Drop-in view | `SDKSelfieWithLivenessView` (controller'ı saran SwiftUI) |
| Controller | `SDKSelfieWithLivenessController` (UIKit) |
| Dış dünya | Yüz/canlılık (cihazda) + **HTTP** |
| Ses anahtarı | `SelfieWithLivenessTts` |
| Donanım | **TrueDepth kamera (ARKit yüz takibi) zorunlu** — yoksa modül akışa hiç girmez |

## Kullanıcı Ne Yaşar?

1. Ön kamera açılır; kullanıcı yüzünü çerçeveye alır.
2. Aynı ekranda canlılık talimatları gelir (göz kırp, gülümse...).
3. Selfie + canlılık kanıtı birlikte yüklenir; akış ilerler.

---

## Kullanım — Drop-in Önerilir

```swift
// Hiçbir şey yazmayın; rota gelince SDK çizer:
case .selfieWithLiveness: SDKSelfieWithLivenessView()
```

İç mantık `SDKSelfieWithLivenessController` (UIKit) içindedir; SwiftUI sarmalayıcı bunu
köprüler. **Composition deseni bu modülde henüz yok** — diğer modüllerdeki gibi
`let sdk = SDKXxxViewModel()` sarma yapısı sunulmuyor.

## Özelleştirme — Dürüst Durum Değerlendirmesi

- **Tema** her zaman çalışır: renk/font/ikon değişimi için ekran yazmanıza gerek yok
  ([Tema rehberi](../../../docs/guides/theming.md)).
- **Tam override teknik olarak mümkün** (`registry.override(.selfieWithLiveness) {...}`),
  ama temiz bir public VM yüzeyi olmadığından iş mantığını tetiklemek zordur —
  **şimdilik önermiyoruz.**
- **Ekranları gerçekten özelleştirmek istiyorsanız:** backend'de bu birleşik modül yerine
  ayrık `.selfie` + `.livenessDetection` modüllerini kullanın. İkisinin de tam VM API'si
  vardır: [Selfie](../Selfie/Selfie.md) · [Liveness](../Liveness/Liveness.md).

## Cihaz Desteği

Modül ARKit yüz takibiyle çalışır, yani **TrueDepth kamera ister**:

| Cihaz | Durum |
|---|---|
| Face ID'li iPhone | Çalışır |
| **Face ID'li iPad Pro / iPad Air** | **Çalışır** — ekran portrait'e kilitli, yüz ovali `SDKLayout.maxFaceGuideWidth` ile sınırlı |
| Touch ID'li iPad / temel iPad | Çalışmaz — yedek modül devreye girer |
| Face ID'siz iPhone (ör. SE) | Çalışmaz — yedek modül devreye girer |
| Simülatör | Çalışmaz (ARKit yüz takibi yalnız gerçek cihazda) |

Kontrol akış kurulurken yapılır (`ARFaceTrackingConfiguration.isSupported`); desteklenmeyen
cihazda kullanıcı bu ekranı hiç görmez. Yerine ne geleceğini entegrasyon belirler:

```swift
IdentifyManager.shared.faceTrackingFallback = .selfie   // varsayılan: selfie ile doğrula
IdentifyManager.shared.faceTrackingFallback = .skip     // adımı tamamen çıkar
// setupSDK'dan ÖNCE
```

Akışta zaten selfie varsa `.selfie` yeni adım eklemez, bu modülü yalnızca çıkarır. Olay:
`status == .skipped`, modül `Selfie With Liveness`. `.livenessDetection` değeri kabul edilir
ama canlılık modülü de aynı donanımı istediğinden `.selfie` gibi davranır.
Ayrıntı: [iPad Desteği](../../../docs/guides/ipad-support.md).

## Yol Haritası

Diğer modüllerle tutarlılık için ileride `SDKSelfieWithLivenessViewModel`
(`: SDKBaseModuleViewModel`) çıkarılması planlanabilir; o zaman bu rehber de
Selfie/Liveness ile aynı VM-referans formatına geçer.

---

## Sesli Okuma (Read-Aloud)

Ekran açıldığında yönerge otomatik seslendirilebilir (`SDKFlowHostView` yapar, kod gerekmez).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .selfieWithLiveness)        // Siri/sistem sesi
// veya kendi kaydınız: bundle'a SelfieWithLivenessTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .selfieWithLiveness)   // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .selfieWithLivenessTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)
