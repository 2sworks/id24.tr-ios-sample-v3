# Örnek: Kimlik Tarama Yönlendirme Metinleri

Kimlik taramasında gösterilen yönlendirme metinlerini ("Telefonunu biraz daha yaklaştır" gibi)
değiştirmenin ve metni ekranın üst kısmında göstermenin yolları.

← [README'ye dön](../../README.md) · İlgili: [IdentityScanner](../guides/identity-scanner.md) · [Hatalar ve Sınırlar](../guides/errors-and-limits.md) · [Lokalizasyon](../guides/localization.md)

---

## Durumlar ve anahtarlar

| Durum | Örnek metin | SDK anahtarı | Varsayılan metin (TR) |
|---|---|---|---|
| Kimlik çok uzakta | "Telefonunu biraz daha yaklaştır." | `.scannerTooFarId` | "Kimliği biraz yaklaştırın" |
| Kimlik çok yakında | "Telefonunu biraz daha uzaklaştır." | `.scannerTooCloseId` | "Kimliği biraz uzaklaştırın" |
| Kimlik eğik (3.2.1+) | "Kimliğini düz tut." | `.scannerTiltedId` | "Kimlik eğik duruyor, düzeltin" |
| Kimlik çerçevede, çekim bekleniyor | "Telefonunu sabit tutarak bekle." | `.scannerAlignId` | "Kimliği düz tutun" |
| Görüntü net değil | "Telefonunu sabit tutarak bekle." | `.scannerFocusing` | "Odaklanıyor…" |

`.scannerTooFarId` ve `.scannerCentreId` yalnız sabit çerçeve modunda (`.fixedFrame`) gösterilir.
Kimlik ekranının varsayılanı bu moddur.

3.2.1 öncesinde eğik kimlik için ayrı durum yoktur. Eğik ya da hareket eden kimlik çoğunlukla
`.scannerAlignId`, bulanık görüntü `.scannerFocusing` metnini gösterir. Bu sürümlerde ikisine
aynı "sabit tut" metnini vermek iyi sonuç verir.

## Metinleri değiştirme

```swift
let loc = SDKLocalization.shared
loc.setOverride(key: .scannerTooFarId,   language: .tr, value: "Telefonunu biraz daha yaklaştır.")
loc.setOverride(key: .scannerTooCloseId, language: .tr, value: "Telefonunu biraz daha uzaklaştır.")
loc.setOverride(key: .scannerTiltedId,   language: .tr, value: "Kimliğini düz tut.")          // 3.2.1+
loc.setOverride(key: .scannerAlignId,    language: .tr, value: "Telefonunu sabit tutarak bekle.")
loc.setOverride(key: .scannerFocusing,   language: .tr, value: "Telefonunu sabit tutarak bekle.")
```

- Ön ve arka yüz aynı metinleri kullanır. Bir kez tanımlamak yeterli.
- `.scannerFocusing` pasaport ve belge taramasında da kullanılır.
- Pasaport karşılıkları: `.scannerTooFarPassport`, `.scannerTooClosePassport`,
  `.scannerAlignPassport`.
- Okunan metin ekrandaki metindir. Ses için ayrı cümle gerekiyorsa
  [IdentityScanner rehberindeki](../guides/identity-scanner.md#yönergelerin-seslendirilmesi)
  `Tts` anahtarlarına bakın.

## Diğer yönlendirme metinleri

| Anahtar | Ne zaman gösterilir | Varsayılan metin (TR) |
|---|---|---|
| `.scannerIdleId` | Kamera açık, kimlik henüz bulunmadı | "Kimliğinizi çerçeve içine hizalayın" |
| `.scannerCentreId` | Kimlik doğru boyutta ama çerçevenin bir yanında | "Kimliği çerçeveye ortalayın" |
| `.scannerReadingId` | Kimlik üzerindeki bilgiler okunuyor | "Kimlik okunuyor…" |
| `.scannerLockedId` | Çekim yapıldı | "Kimlik tespit edildi" |
| `.scannerGlare` | Kimlik üzerinde parlama var | "Parlama var — belgeyi ışığa göre hafifçe eğin" |
| `.scannerManualCapture` | Manuel çekim düğmesi | "Manuel Çek" |
| `.scannerManualFailTitle` | Otomatik çekim tekrar tekrar başarısız olduğunda | "Otomatik okuma başarısız oldu" |
| `.scannerCancel` | İptal düğmesi | "İptal" |

## Metni ekranın üst kısmında gösterme (3.2.1+)

SDK yönlendirme metnini tarama ekranının altında gösterir. Metni üstte ya da kalın vurgularla
göstermek için SDK'nın metnini kapatıp kendi görünümünüzde çizin. 3.2.1 öncesinde metin alta
sabittir, gizlenemez.

**1. SDK'nın metnini kapatın.** Bütün taramalar için:

```swift
ScannerConfiguration.showsGuidanceDefault = false
```

Yalnız kendi tarama ekranınızda:

```swift
var configuration = ScannerConfiguration.default
configuration.showsGuidance = false
```

**2. Metni `SDKErrorConfig.shared.onGuidance` ile alın.** SDK bu fonksiyonu ana thread'de, metin
her değiştiğinde çağırır. `info.state` durumun adını (`"tooFar"`, `"tooClose"`, `"tilted"`,
`"align"`, `"focusing"` …), `info.message` ekrandaki metni taşır.

```swift
struct KimlikTaramaEkrani: View {
    @State private var yonlendirme: SDKGuidanceInfo?

    var body: some View {
        ZStack(alignment: .top) {
            IdentityScannerView(/* mevcut kurulumunuz */)

            if let yonlendirme {
                yonlendirmeMetni(yonlendirme)
                    .font(.title3)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 120)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            SDKErrorConfig.shared.onGuidance = { info in
                guard info.module == .idCard else { return }
                yonlendirme = info
            }
        }
        .onDisappear {
            SDKErrorConfig.shared.onGuidance = nil
        }
    }

    private func yonlendirmeMetni(_ info: SDKGuidanceInfo) -> Text {
        switch info.state {
        case "tooFar":
            return Text("Telefonunu biraz daha\n") + Text("yaklaştır.").bold()
        case "tooClose":
            return Text("Telefonunu biraz daha\n") + Text("uzaklaştır.").bold()
        case "tilted":
            return Text("Kimliğini ") + Text("düz tut.").bold()
        case "align", "focusing":
            return Text("Telefonunu ") + Text("sabit tutarak").bold() + Text(" bekle.")
        default:
            return Text(info.message)
        }
    }
}
```

- `.padding(.top, 120)` değerini fener ve kapatma düğmelerinin altına gelecek şekilde ayarlayın.
- `.allowsHitTesting(false)` metnin dokunarak odaklamayı engellememesi için.
- `state`, metinden geriye bulunur. İki durum aynı metni taşıyorsa ilki gelir (`focusing`,
  `align`'dan önce). Bu yüzden örnek ikisini birlikte ele alır.
- `onGuidance` tek fonksiyon tutar. Başka yerde de kullanıyorsanız ekran kapanınca eski değerine
  döndürün.
- Sesli yönlendirme bu ayardan etkilenmez.

## Notlar

- Override'ları tarama başlamadan önce, örneğin uygulama açılışında tanımlayın.
- Override'lar dil bazında çalışır. `.en`, `.de`, `.az` ve `.ru` için ayrıca tanımlayın.
