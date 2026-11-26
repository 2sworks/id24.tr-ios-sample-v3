# NFC — Kimlik/Pasaport Çip Okuma

Kimlik doğrulamanın en güçlü kanıtı: belgedeki **çipin** okunması. SDK, tam bir ICAO
yığını taşır (PACE ya da BAC ile anahtar anlaşması → Secure Messaging → veri grupları) ve çipteki
fotoğraf/kimlik verisini güvenle çıkarır. Çipe erişimin anahtarı, bir önceki OCR adımında
okunan üç MRZ alanıdır: **seri no + doğum tarihi + son geçerlilik tarihi**. Çip destekliyorsa
önce PACE denenir; kartta PACE bilgisi yoksa ya da PACE kurulamazsa BAC kullanılır (3.3.1).

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | `SdkModules.nfc` |
| Rota | `SDKModuleRoute.nfc` |
| Drop-in view | `SDKNfcView` |
| ViewModel | `SDKNfcViewModel` |
| Dış dünya | CoreNFC (cihazda çip) + **HTTP** (sonuç yükleme) |
| Ses anahtarı | `NfcTts` |

**Kurulum gereksinimi:** entitlement dosyasına
`com.apple.developer.nfc.readersession.formats` → `TAG`, Info.plist'e
`NFCReaderUsageDescription` ve
`com.apple.developer.nfc.readersession.iso7816.select-identifiers` → `A0000002471001`.

## Kullanıcı Ne Yaşar?

1. "Kimliğinizi telefonun arkasına yaslayın" yönergesini görür.
2. "Çipi Oku"ya dokununca sistemin NFC sayfası açılır; belgeyi telefonun üst-arka kısmına tutar.
3. Okuma sırasında durum metni akar (`nfcStatus`); başarıda otomatik ilerlenir.
4. MRZ alanları yanlışsa manuel düzeltme ekranı açılabilir; deneme hakkı tükenirse adım atlanabilir.

---

## Hazır Ekranla Kullanım (Drop-in)

Hiçbir şey yazmayın; rota gelince `SDKNfcView` çizilir. NFC illüstrasyonlarını
değiştirmek için tema anahtarları: `nfcFront`, `nfcBack` ([Tema](../../../docs/guides/theming.md)).

## Kendi Tasarımınızla (Override)

> **Çalışan tam örnek:** [NfcCustomView.swift](NfcCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Takmak için: `registry.override(.nfc) { NfcCustomView() }`
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


```swift
registry.override(.nfc) { MyNfcView() }

struct MyNfcView: View {
    @EnvironmentObject var coordinator: SDKFlowCoordinator
    @StateObject private var vm = SDKNfcViewModel()

    var body: some View {
        VStack {
            Text(vm.nfcStatus)                                      // canlı durum
            Button("Çipi Oku") { vm.startNFC() }                    // ✅ manager.startNFC
        }
        .sheet(isPresented: $vm.showEditScreen) {                   // OCR bilgisi eksikse ya da okuma hata sınırında açılır
            MyMrzForm(serial: $vm.serialNo, birth: $vm.birthDate, valid: $vm.validDate,
                      onSave: vm.saveManualDates)
                .sdkScreenCaptureProtected()                        // ekran koruması (3.3.1); presentationDetents bundan sonra
        }
        .onAppear {
            vm.onCompleted     = { coordinator.advanceToNextModule() }
            vm.onSkipRequested = { coordinator.skipCurrentModule() }
        }
    }
}
```

- İlerlemeyi **yalnız `onCompleted`** yapar; ayrıca bir "Devam" düğmesi `advanceToNextModule`
  çağırırsa akış iki adım ilerler.
- `startNFC()`, belge no / doğum / geçerlilik tarihi boşsa okuma başlatmaz,
  `showEditScreen`'i açar. Bu alanları gösteren formu siz sunarsınız.
- **Çipe dokundurma sırasında açılan sayfa iOS'a aittir** (Core NFC); tasarımı
  değiştirilemez, yalnız içindeki metinler SDK dil dosyalarından gelir.


---

## ViewModel Referansı — `SDKNfcViewModel`

### State
| Üye | Tip | Erişim | Anlam |
|---|---|---|---|
| `serialNo` | `String` | r/w | Belge seri no (MRZ) |
| `birthDate` | `String` | r/w | Doğum tarihi (MRZ) |
| `validDate` | `String` | r/w | Geçerlilik tarihi (MRZ) |
| `nfcStatus` | `String` | salt-okunur | Okuma durumu metni |
| `nfcCompleted` | `Bool` | salt-okunur | Okuma tamamlandı mı |
| `showEditScreen` | `Bool` | r/w | Manuel MRZ düzenleme ekranı |
| `canContinue` | `Bool` | salt-okunur | Devam edilebilir mi |

### Metotlar
| Metot | Etki |
|---|---|
| `startNFC()` | MRZ anahtarıyla çip okumayı başlatır (`manager.startNFC`) |
| `saveManualDates()` | Manuel girilen MRZ alanlarını `manager.sdkBackInfo`'ya yazar, `updateReadNFCKeys` ile sunucuya gönderir ve başarıda okumayı yeniden başlatır |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onCompleted: (() -> Void)?` | Okuma başarılı. Okuma hata sınırı dolunca önce anahtar düzeltme ekranı açılır. Elle düzeltilen anahtarla okuma hakkı (`SDKAttemptLimits.shared.nfcKeyEntry`, varsayılan 3) da bitince yine çağrılır ve modül doğrulanmadan geçer |
| `onSkipRequested: (() -> Void)?` | Karşılaştırma hakkı tükendi ve atlamaya izin var. Anahtar düzeltme hakkı bitince çağrılmaz |
| `onFlowFailed: (() -> Void)?` | Karşılaştırma hakkı tükendi, atlama kapalı → `coordinator.finishFlowAsFailed()`. NFC için `SDKAttemptLimits.shared.set(SDKModuleLimits(onExhausted: .fail), for: .nfc)` verildiyse anahtar düzeltme hakkı bitince de çağrılır |
| `onRetryFromPreviousStep: (() -> Void)?` | Çip ile belge verisi uyuşmadı, hak var → önceki adıma dön (NFC ilk ekransa ekranda kalınır) |

MRZ alanları VM açılışında otomatik dolar. Kaynak önceki OCR adımıdır: önce arka yüzün MRZ'si,
o yoksa ön yüzün OCR'ı. `manager.useKpsData` aktifse KPS verisi kullanılır (`manager.mrzDocNo`,
`manager.mrzBirthDay`, `manager.mrzValidDate`); sunucudan şifreli MRZ da gelebilir
([Sunucu & API → şifreli MRZ](../../../docs/guides/server-api.md#şifreli-mrz-verisi-kpsdata-yerine)).

VM kullanmadan kendi ekranınızı yazıyorsanız: KPS verisi ve sunucudan çözülen MRZ yoksa
`manager.startNFC` anahtarı her çağrıda yeniden `manager.sdkBackInfo`'dan (o yoksa ön yüz
OCR'ından) okur. `updateReadNFCKeys` ile düzelttiğiniz değerler bu okumada ezilir ve okuma eski
anahtarla tekrarlanır. Düzeltilen değerleri `sdkBackInfo.idDocumentNumberMRZ`, `idBirthDateMRZ` ve
`idValidDateMRZ` alanlarına da yazın (tarihler MRZ biçiminde, `yyMMdd`). Hazır VM bunu
`saveManualDates()`'te kendisi yapar.

## Sinyal Zinciri — Perde Arkası

```
(VM init) ← KPS: manager.mrzDocNo / mrzBirthDay / mrzValidDate; yoksa arka yüz MRZ'si, o da yoksa ön yüz OCR'ı
startNFC()  → manager.startNFC (CoreNFC çip okuma) → nfcMsgHandler (durum) → onCompleted?()
            → (nfcComparisonCount tükendi & skip izinli) → onSkipRequested?()
host: → coordinator.advanceToNextModule() [modulePresented]
```

## Host VM ile Gözlem (Composition)

```swift
@MainActor
final class NfcHostViewModel: HostModuleViewModel {
    let sdk = SDKNfcViewModel()
    override init() {
        super.init(); bridge(sdk)
        sdk.onCompleted     = { [weak self] in self?.log("nfc_done") }
        sdk.onSkipRequested = { [weak self] in self?.log("nfc_skip") }
    }
    var status: String { sdk.nfcStatus }
    func start() { log("nfc_start"); sdk.startNFC() }
}
```

---

## Sesli Okuma (Read-Aloud)

Hazır ekran açılınca yönergeyi kendisi okur: kimlikte `NfcTts`, pasaportta `NfcPassportTts`.
`SDKFlowHostView` bu modülü otomatik okumaz. Kendi ekranınızda
`SDKSpeechService.shared.speak(vm.introTtsKey, in: .nfc)` çağırın
([NfcCustomView.swift](NfcCustomView.swift) bunu yapar).

```swift
SDKSpeechConfig.shared.setMode(.native, for: .nfc)          // Siri/sistem sesi
// veya kendi kaydınız: bundle'a NfcTts.m4a koyun →
SDKSpeechConfig.shared.audioBundle = Bundle.main
SDKSpeechConfig.shared.setMode(.customAudio, for: .nfc)     // dosya yoksa native'e düşer
```

Metni ezmek: `SDKLocalization.shared.setOverride(key: .nfcTts, language: .tr, value: "...")`
· Tüm ayrıntı: [ReadAloud](../ReadAloud.md)

## NFC Sonrası Çıkış — Oturum Nasıl Biter?

NFC akışın son modülüyse (ör. panelde yalnızca NFC açık) oturum NFC ekranından sonra biter ve
sonuç `setupSDK(onFinished:)`'a gelir:

| Ne oldu | `onFinished` | `skippedModules` |
|---|---|---|
| Çip okundu ve doğrulandı | `approved` / `allModulesCompleted` | `[]` |
| Hak bitti, atlama izinli | `approved` / `allModulesCompleted` | `[nfc]` |
| Hak bitti, atlama kapalı | `notCompleted` / `moduleFailed` | `[]` |
| Okuma hata sınırından (`nfcMaxErrorCount`) sonra anahtar düzeltme hakkı da bitti (`nfcKeyEntry`; `onExhausted` `.fail` değilse) | `approved` / `allModulesCompleted` | `[nfc]` |
| Cihazda NFC yok (modül akışa alınmadı) | `approved` / `allModulesCompleted` | `[nfc]` |
| İlk ekranda geri | `cancelled` / `userExited` | `[]` |

Çipin gerçekten doğrulandığını anlamak için `result == .approved`, `!skippedModules.contains(.nfc)`
**ve** `nfcVerification?.hasFailedCheck != true` kontrol edin. Tüm ayrıntı, loglar ve yönlendirme kalıpları:
[Oturum Çıkışları → Senaryo: panelde tek modül açık](../../../docs/guides/session-exit.md#5-senaryo-1--tek-modüllü-akış-müşteri-adımı-tamamladı-sdk-işini-bitirdi).

## Sık Sorulanlar & Dikkat Edilecekler

- **Cihazda NFC yoksa?** (Tüm iPad'ler ve eski iPhone'lar.) Kontrol akış kurulurken yapılır
  (`NFCNDEFReaderSession.readingAvailable`); modül akışa alınmaz, panele bir kez
  `NFCStatus = notAvailable` bildirilir ve `sdk_logs`'a yazılır. `setupSDK(..., showNFCNotFoundPage: true, ...)` verilirse modül akışta kalır
  ve NFC ekranı açılır. Ayrı bir bilgi sayfası yoktur, okuma denemesi hata verir.
  Ayrıntı: [iPad Desteği](../../../docs/guides/ipad-support.md).

- **Simülatörde çalışmaz** — CoreNFC gerçek cihaz ister; NFC'yi test etmeden yayına çıkmayın.
- **Okuma başarısız oluyor:** Kılıfı çıkartın, belgeyi telefonun **üst-arka** kısmına tutun,
  okuma bitene kadar oynatmayın. Hata sayısı `setupSDK(nfcMaxErrorCount:)` ile sınırlanır.
- **Kart bir an koparsa (3.3.0):** okuma düşmez, kart geri konunca kaldığı yerden sürer. Kart
  geri konmazsa okuma `IdentifyManager.shared.nfcCardReturnTimeout` (varsayılan 10 sn) sonunda
  hatayla biter ve deneme hakkından düşer. `nil` verilirse süre işlemez, okumayı yalnız iOS'un
  oturum sınırı keser (iPhone 16 Pro Max'te 64,5 sn ölçüldü).
- **KPS ile okuma (3.3.0):** anahtar doğruyken okuma koparsa anahtar düzeltme ekranı açılmaz.
  Çip anahtarı kabul ettiyse ya da oturum çipe ulaşmadan kapandıysa hata, okuma sınırına ve
  anahtar hakkına sayılmaz.
- **MRZ yanlış okunmuşsa:** `showEditScreen = true` + `saveManualDates()` ile kullanıcı
  düzeltebilir; agent uzaktan da NFC düzeltme başlatabilir (`editNfcProcess` soket aksiyonu).
- **Çipsiz belge:** SDK'da çipsiz belgeye özel bir ekran ya da event durumu yok.
  `showNFCNotFoundPage` ve event akışındaki `notFound` durumu yalnız NFC donanımı olmayan
  cihazda devreye girer ([Event Sistemi](../../../docs/guides/events.md)).
- **Sertifika doğrulama:** SDK CSCA listesi taşımaz. Listeyi `setupSDK(nfcMasterList:)` ile
  PEM dosyası olarak verin; çip sertifika zinciri bu listeye karşı doğrulanır. Liste yoksa
  zincir kontrolü yapılmaz. Zincir tutmazsa okuma yine geçer, sonuç
  `nfcVerification.certificateChain` alanında `failed` olarak raporlanır.
- **Yardım (?) düğmesi:** 3.3.0'dan beri varsayılan kapalı. Yalnız bu ekranda açmak için
  `SDKTheme.shared.navBar.routeButtons[.nfc] = SDKNavBarButtons(showsHelp: true)`. SDK düğmeye işlev
  bağlamaz, `onHelp` vermezseniz basılınca bir şey olmaz;
  işlev vermek ya da kendi düğmenizi eklemek için [Başlık Çubuğu Düğmeleri](../Modules.md#başlık-çubuğu-düğmeleri).
