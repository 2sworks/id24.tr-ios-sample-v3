# Oturum Çıkışları — SDK Nasıl Kapandı, Nereye Yönlendireyim?

SDK bir oturumu birçok yoldan bitirebilir: temsilci karar verir, modüller biter, kullanıcı geri
çıkar, bir modülün deneme hakkı tükenir, bağlantı kurulamaz, uygulama kapatılır… Bu rehber
**her çıkış yolunu tek yerde** anlatır: hangi yoldan çıkıldığını nerede görürsünüz, sonuç hangi
verilerle gelir, kapanıştan sonra kendi uygulamanızda nereye ve nasıl yönlendirirsiniz.

> 3.1.0 ile gelir. Görüşme kapanışındaki `terminateReason` / statü karar tablosu:
> [WebSocket → Görüşmenin Kapanışı](websocket.md#görüşmenin-kapanışı--terminatecall).

---

## İçindekiler

1. [Tek kural: sonucu `onFinished`'tan okuyun](#1-tek-kural-sonucu-onfinishedtan-okuyun)
2. [Sonucu nerede görürüm?](#2-sonucu-nerede-görürüm)
3. [`SDKFlowOutcome` — kapanış verileri](#3-sdkflowoutcome--kapanış-verileri)
4. [Tüm çıkış yolları](#4-tüm-çıkış-yolları)
5. [Senaryo 1 — Tek modüllü akış (X modülü, örnek: NFC)](#5-senaryo-1--tek-modüllü-akış-müşteri-adımı-tamamladı-sdk-işini-bitirdi)
6. [Senaryo 2 — Üç modüllü akış (Kimlik → NFC → Selfie)](#6-senaryo-2--üç-modüllü-akış-kimlik--nfc--selfie)
7. [Senaryo 3 — Görüntülü görüşmeli üç modüllü akış (Kimlik → Selfie → Görüşme)](#7-senaryo-3--görüntülü-görüşmeli-üç-modüllü-akış-kimlik--selfie--görüşme)
8. [Modül bazında çıkış kataloğu — her modül için ne olur?](#8-modül-bazında-çıkış-kataloğu--her-modül-için-ne-olur)
9. [Kapanıştan sonra yönlendirme — kodu nereye yazacağım?](#9-kapanıştan-sonra-yönlendirme--kodu-nereye-yazacağım)
10. [Kurallar ve tuzaklar](#10-kurallar-ve-tuzaklar)
11. [Doğrulama listesi](#11-doğrulama-listesi)

---

## 1) Tek kural: sonucu `onFinished`'tan okuyun

```swift
IdentifyManager.shared.setupSDK(
    ...,
    showThankYouPage: false,          // sonuç ekranını siz göstereceksiniz
    onFinished: { outcome in          // oturum nasıl biterse bitsin TAM BİR KEZ
        AppRouter.shared.handleKyc(outcome)
    }
) { socket, room, error in ... }
```

- **Her çıkışta** çağrılır — kurulum hatası dahil. Oturum başına **bir kez**.
- **Main thread**'de, **karar anında** gelir (ör. temsilci kapattığı an); sonuç ekranının
  kapatılmasını beklemez.
- Oturumu **bitirmeyen** olaylarda çağrılmaz: bağlantı kopması ve yeniden bağlanma, arka plana
  geçiş, cevapsız çağrı, karar içermeyen `terminateCall`. Bu durumlarda kullanıcı akışta kalır.

---

## 2) Sonucu nerede görürüm?

| Nerede | Ne zaman kullanılır |
|---|---|
| `setupSDK(onFinished:)` | **Önerilen.** Oturumu başlattığınız yerde sonucu da yakalarsınız |
| `IdentifyManager.shared.onFlowFinished` | Sonucu `setupSDK`'dan farklı bir katmanda (ör. uygulama router'ı) dinleyecekseniz |
| `IdentifyManager.shared.flowResultDelegate` | UIKit / delegate tarzı mimari (`IdentifyFlowResultListener`, **weak** — referansı saklayın) |
| `eventDelegate` → `session.finished` | Analitik, React Native / Flutter köprüleri (metadata ile) |
| `IdentifyManager.shared.lastFlowOutcome` | Sonradan okumak için (ör. sonuç ekranı override'ında, bir sonraki `setupSDK`'ya kadar) |
| `sdk_logs` → `Akış sonucu — …` satırı | Sunucu tarafında destek/inceleme; host'un dinleyici bağlamasına gerek yok |

Üç kanal (`onFinished`, `onFlowFinished`, `flowResultDelegate`) aynı `SDKFlowOutcome`'u alır;
birlikte kullanılabilir.

```swift
// Delegate ile
final class KycResultHandler: IdentifyFlowResultListener {
    func identifyFlowDidFinish(_ outcome: SDKFlowOutcome) {
        AppRouter.shared.handleKyc(outcome)
    }
}
let resultHandler = KycResultHandler()                       // güçlü referans sizde
IdentifyManager.shared.flowResultDelegate = resultHandler    // setupSDK'dan ÖNCE
```

Sunucu logunda aynı sonuç şöyle görünür:

```
Akış sonucu — sonuç: approved, sebep: allModulesCompleted, son modül: Mrz & Nfc Screen, adım: 1/1.
Oturum sonlandı — son modül: Mrz & Nfc Screen, akış tamamlandı, sebep: 4100 (flowCompleted): Akış tamamlandı — bağlantı normal kapatıldı
```

---

## 3) `SDKFlowOutcome` — kapanış verileri

| Alan | Tip | Anlamı |
|---|---|---|
| `result` | `SDKFlowResult` | **Kararınızı buna göre verin:** `approved` · `rejected` · `neutral` · `notCompleted` · `cancelled` · `error` |
| `reason` | `SDKFlowEndReason` | Hangi yoldan çıkıldı (bkz. [Tüm çıkış yolları](#4-tüm-çıkış-yolları)) |
| `lastModule` | `SdkModules?` | Oturumun bittiği modül (henüz modül açılmadıysa `nil`) |
| `modules` | `[SdkModules]` | Bu oturumda akışa alınan modüller (cihazda çalışamayanlar hariç) |
| `skippedModules` | `[SdkModules]` | **Doğrulanmadan geçilen** modüller — atlandı, cihazda/belgede bulunamadı, NFC hata sınırı |
| `stepIndex` / `totalSteps` | `Int` | Adım sayacı |
| `terminateReason` | `String?` | Panel kapattıysa sebep, birebir |
| `statusSummary` | `StatusSummary?` | Panel kararı: `id`, `type`, `name_tr` / `name_en` / `name_de` |
| `closeCode` | `SDKSocketCloseCode?` | Sonuç anında kayıtlı son socket kapanış kodu. Karar anında bildirilen yollarda genellikle boştur; kesin kapanış kodu `IdentifyManager.shared.lastSocketCloseCode` ve `sdk_logs`'taki `Oturum sonlandı` satırındadır |
| `errorMessage` | `String?` | `setupFailed` için hata metni |
| `sessionId` / `timestampMs` | | Oturum kimliği ve zaman |
| `isSuccess` | `Bool` | Yalnızca `.approved` için `true` |
| `toDictionary()` | | RN/Flutter için sözlük |

> ⚠️ **`approved` + `skippedModules`:** Görüşmesiz bir akışta modüllerin hepsi geçildiğinde
> sonuç `approved / allModulesCompleted` olur — bir modül **atlanmış** olsa bile (backend atlamaya
> izin veriyorsa). Her adımın doğrulanmış olması gerekiyorsa `skippedModules`'ın boş olduğunu
> ayrıca kontrol edin. Nihai onay her durumda sunucudadır.

---

## 4) Tüm çıkış yolları

Sütunlar: **Ekran** = `showThankYouPage: true` iken kullanıcının gördüğü (`false` iken hiçbir
yolda sonuç ekranı açılmaz, SDK bulunduğu ekrandan aşağı kayarak kapanır). **Kapanış** =
`sdk_logs` / `lastSocketCloseCode`'daki socket kodu.

### 4.1 Akış tamamlandı / panel karar verdi

| `reason` | `result` | Tetikleyen | Ekran | Kapanış | Dolu gelen alanlar |
|---|---|---|---|---|---|
| `allModulesCompleted` | `approved` | Son modül bitti, sıradaki adım yok (görüşmesiz akış; ya da modüller görüşmeden sonra da devam ediyor) | ThankYou — başarılı | 4100 | `lastModule`, `skippedModules` |
| `agentDecision` | `approved` | Panel `terminateCall` + `positive` statü | ThankYou — başarılı | 4103 | `terminateReason`, `statusSummary` |
| `agentDecision` | `rejected` | Panel `terminateCall` + `negative` statü | ThankYou — tamamlanamadı | 4103 | `terminateReason`, `statusSummary` |
| `agentDecision` | `neutral` | Panel `terminateCall` + `neutral` statü | ThankYou — tamamlanamadı | 4103 | `terminateReason`, `statusSummary` |
| `agentDecision` | `approved` | Bağlantı koptu → yeniden bağlanıldı → panelin kayıtlı statüsü `positive` | ThankYou — başarılı | 4103 | `statusSummary` (`terminateReason` yok) |

### 4.2 Akış tamamlanamadı

| `reason` | `result` | Tetikleyen | Ekran | Kapanış | Dolu gelen alanlar |
|---|---|---|---|---|---|
| `moduleFailed` | `notCompleted` | Bir modülün (Selfie, Kimlik, OVD, NFC, Canlılık, Selfie+Canlılık) karşılaştırma hakkı bitti, backend atlamaya **izin vermiyor** | ThankYou — tamamlanamadı | 4101 | `lastModule` = başarısız modül |
| `userEndedCall` | `notCompleted` | Kullanıcı "Görüşmeyi bitir"e bastı | ThankYou — tamamlanamadı | 4101 | `lastModule` |
| `userEndedCall` | `notCompleted` | Görüşme `terminateCall` gelmeden kapandı (`endCall`) ve akış sona ulaştı | ThankYou — tamamlanamadı | 4100 | `lastModule` |

### 4.3 Bilinçli çıkış

| `reason` | `result` | Tetikleyen | Ekran | Kapanış |
|---|---|---|---|---|
| `userExited` | `cancelled` | İlk ekranda geri butonu (`coordinator.popBack()`) | Host'un kök ekranı | 4102 |
| `userExited` | `cancelled` | `IdentifyManager.shared.killSDKByUser` (panele `quitSDKOnMobile` gider) | — | 4101 |
| `hostQuit` | `cancelled` | Host `quitSDK(callback:)` çağırdı (önceden sonuç yoksa) | callback'teki controller | 4101 |
| `hostExit` | `cancelled` | Host `exitSDK()` çağırdı | — | 4102 |
| `hostForceQuit` | `cancelled` | Host `forceQuitSDK()` çağırdı | — | 4103 |
| `appTerminated` | `cancelled` | Oturum açıkken uygulama kapatıldı (sistem izin verdiği sürece; log bir sonraki oturumda gönderilir) | — | — |

### 4.4 Oturum kurulamadı / sürdürülemedi

| `reason` | `result` | Tetikleyen | Ekran | Kapanış | Dolu gelen alanlar |
|---|---|---|---|---|---|
| `setupFailed` | `error` | `setupSDK` hata döndü (geçersiz `identId`, sunucuya ulaşılamadı, WS anahtarı reddedildi) | Host'un giriş ekranı (akış hiç başlamadı) | — | `errorMessage` |
| `roomOccupied` | `error` | Oda başka bir oturumda (yeniden denemeler de reddedildi) | "Oturum meşgul" uyarısı → onayla kök ekran | 4120 | `closeCode` = 4120 |
| `connectionLost` | `error` | Bağlantı kopmuşken akışın sonuna gelindi ya da oturum başka bir kodla kapandı | ThankYou | 4104–4142 | `closeCode` |

### 4.5 Sonuç ÜRETMEYENLER (oturum sürer)

| Olay | Kullanıcı ne görür | Ne olur |
|---|---|---|
| Bağlantı kopması (ağ, heartbeat 4109, ping 4107, TURN 4140–4142) | Bağlantı Koptu | Yeniden bağlanınca modül baştan başlar |
| Uygulama 30 sn'den uzun arka planda (4105) | Dönüşte Bağlantı Koptu | Aynı |
| Çağrı yanıtlanmadı (4108) / `missedCall` | Bekleme odası | Sıraya devam |
| Karar içermeyen `terminateCall` (statü yok, id `-3`, sorunlu kapanış sebepleri) | Bağlantı Koptu → bekleme odası | Temsilci yeniden arayabilir |
| Modül atlandı (hak tükendi, atlama izinli) | Sıradaki modül | `skippedModules`'a eklenir |

Kullanıcı bu durumlardan hiç dönmezse sonuç, host'un sonraki `exitSDK` / `forceQuitSDK`
çağrısında ya da uygulama kapanışında üretilir.

---

## 5) Senaryo 1 — Tek modüllü akış: müşteri adımı tamamladı, SDK işini bitirdi

Bu bölüm tek bir senaryoyu **baştan sona** izler: panelde akışa yalnızca bir modül eklenmiş,
müşteri o adımı yapmış ve SDK işini bitirmiştir. Bundan sonra çıkış nasıl olur, developer bunu
nerede görür, nasıl yakalar ve kendi uygulamasında nereye yönlendirir?

Örnek modül **NFC**; NFC yerine akıştaki herhangi bir modülü ("X modülü") koyabilirsiniz —
kapanış aynı yoldan işler. Her modülün kendine özgü çıkışları:
[8) Modül bazında çıkış kataloğu](#8-modül-bazında-çıkış-kataloğu--her-modül-için-ne-olur).

### 5.1 Başlangıç

- Panelde akışa yalnızca **NFC** eklendi (`RoomResponse.modules = ["nfc"]`).
- Host uygulama `setupSDK`'yı `showThankYouPage: false` ve `onFinished` ile çağırıyor; sonuç
  ekranını kendisi gösterecek.

```swift
coordinator.prepareForSetup()
IdentifyManager.shared.setupSDK(
    identId: identId,
    ...,
    showThankYouPage: false,
    onFinished: { outcome in
        KycRouter.shared.handle(outcome)            // ← çıkışın yakalandığı tek yer
    }
) { socket, room, error in
    if socket?.isConnected == true, room.result == true { coordinator.start() }
}
```

### 5.2 Müşteri NFC'yi taratıyor

1. `coordinator.start()` ilk (ve tek) modülü açar: **NFC ekranı**.
   Olay: `module.Mrz & Nfc Screen.presented`.
2. Müşteri kimliği telefonun arkasına tutar; çip okunur ve sunucuda karşılaştırılır.
3. Karşılaştırma geçer. Panele NFC sonucu gider.
   Olay: `module.Mrz & Nfc Screen.completed` · log: `Modül sonucu — Mrz & Nfc Screen: tamamlandı.`

### 5.3 SDK işini bitiriyor — çıkış nasıl oluyor?

NFC ekranı başarıyı bildirir (`onCompleted`) ve coordinator sıradaki modülü ister. Sırada
modül yoktur; SDK oturumu kapatır. Sıra şöyledir:

| # | Ne olur | Nerede görünür |
|---|---|---|
| 1 | Akışın sonuna gelindi: sonuç üretilir → `approved / allModulesCompleted` | — |
| 2 | Sonuç sunucu loguna yazılır | `sdk_logs`: `Akış sonucu — sonuç: approved, sebep: allModulesCompleted, son modül: Mrz & Nfc Screen, adım: 1/1.` |
| 3 | `session.finished` ve `session.completed` olayları yayınlanır | `eventDelegate`, RN/Flutter köprüsü |
| 4 | **`onFinished(outcome)` çağrılır** (main thread), ardından `onFlowFinished` ve `flowResultDelegate` | Sizin kodunuz |
| 5 | Socket **4100** (`flowCompleted`) ile kapatılır; panel oturumun normal bittiğini görür | `lastSocketCloseCode` |
| 6 | Sonuç ekranı açılmaz: NFC ekranı **aşağı kayarak** kalkar, altta `SDKFlowHostView`'e verdiğiniz kök ekran görünür | Ekran |
| 7 | Oturum kaynakları bırakılır (socket, görüşme bağlantısı, dinleyiciler, log kuyruğu) | `sdk_logs`: `Oturum sonlandı — son modül: Mrz & Nfc Screen, akış tamamlandı, sebep: 4100 (flowCompleted)…` |
| 8 | Akış durumu sıfırlanır; yeni oturum için tekrar `setupSDK` gerekir | `IdentifyManager.shared.isSessionClosed == true` |

`showThankYouPage: true` olsaydı 6. adımda ThankYou "başarılı" açılırdı; kullanıcı butona
basınca akış kök ekrana dönerdi. `onFinished` yine 2. adımda, ThankYou açılırken gelirdi.

### 5.4 Developer çıkışı nerede görüyor, hangi verilerle?

`onFinished`'a gelen `SDKFlowOutcome`:

| Alan | Değer |
|---|---|
| `result` | `.approved` |
| `reason` | `.allModulesCompleted` |
| `lastModule` | `.nfc` |
| `modules` | `[.nfc]` |
| `skippedModules` | `[]` — NFC gerçekten doğrulandı |
| `stepIndex` / `totalSteps` | `1` / `1` |
| `terminateReason` / `statusSummary` | `nil` — görüşme yok, panel kararı yok |
| `closeCode` | `nil` — sonuç socket kapanmadan hemen önce üretilir; kod sonrasında `lastSocketCloseCode`'da `.flowCompleted` olur |
| `sessionId` | `setupSDK` ile üretilen oturum kimliği |

Aynı bilgi başka yerlerden de okunabilir:

- `IdentifyManager.shared.lastFlowOutcome` — bir sonraki `setupSDK`'ya kadar.
- `eventDelegate` → `session.finished`, metadata: `result=approved`, `endReason=allModulesCompleted`,
  `lastModule=Mrz & Nfc Screen`, `stepIndex=1`, `totalSteps=1`.
- Sunucuda `sdk_logs` — 5.3'teki satırlar.

### 5.5 Developer çıkışı nasıl yakalıyor ve nereye yönlendiriyor?

Yönlendirme `onFinished`'ta başlar. Kapanış animasyonu ile aynı anda çalışır: SDK kendi ekranını
kaldırırken siz kök ekranınızın state'ini değiştirirsiniz.

```swift
@MainActor
final class KycRouter: ObservableObject {
    static let shared = KycRouter()
    @Published var destination: Destination?

    enum Destination: Identifiable {
        case identityVerified            // çip okundu ve doğrulandı
        case identityNotVerified         // akış bitti ama NFC doğrulanmadı
        case verificationFailed          // hak bitti, atlama kapalı
        case error(String?)
        var id: String { String(describing: self) }
    }

    func handle(_ outcome: SDKFlowOutcome) {
        switch outcome.result {
        case .approved where outcome.skippedModules.isEmpty:
            destination = .identityVerified                 // ← bu senaryo
        case .approved:
            destination = .identityNotVerified
        case .notCompleted, .rejected, .neutral:
            destination = .verificationFailed
        case .error:
            destination = .error(outcome.errorMessage)
        case .cancelled:
            destination = nil                                // kullanıcı vazgeçti, kök ekranda kalır
        }
    }
}

// SDKFlowHostView'e kök olarak verdiğiniz ekran:
struct HomeView: View {
    @ObservedObject var router = KycRouter.shared
    var body: some View {
        content
            .fullScreenCover(item: $router.destination) { destination in
                switch destination {
                case .identityVerified:    AccountOpeningView()        // kendi uygulamanızda devam
                case .identityNotVerified: ManualReviewInfoView()
                case .verificationFailed:  RetryLaterView()
                case .error(let message):  ErrorView(message: message)
                }
            }
    }
}
```

SDK'yı bir modal / `fullScreenCover` / `UIHostingController` içinde sunuyorsanız önce kabı
kapatın, kapanınca yönlendirin: [9.2](#92-swiftui--sdk-bir-fullscreencover-içinde) ·
[9.3](#93-uikit). React Native / Flutter: [9.5](#95-react-native--flutter).

### 5.6 Aynı senaryo başka bir modülle

Özet tablo aşağıda; her modülün tüm çıkışları, özel durumları ve log örnekleri:
[8) Modül bazında çıkış kataloğu](#8-modül-bazında-çıkış-kataloğu--her-modül-için-ne-olur).

Panelde tek modül açık ve müşteri adımı tamamladığında akış her modülde aynı yoldan kapanır:
`approved / allModulesCompleted`, socket 4100, `lastModule` = o modül. Yalnızca modüle özgü
"işler farklı giderse" dalları değişir:

| Tek açık modül | Müşteri adımı tamamladı | Hak bitti, atlama kapalı | Hak bitti, atlama izinli | Cihaz desteklemiyor |
|---|---|---|---|---|
| NFC (`nfc`) | `approved` | `notCompleted / moduleFailed` | `approved` + `skippedModules [nfc]` | `approved` + `skippedModules [nfc]`, `modules []` |
| Selfie (`selfie`) | `approved` | `notCompleted / moduleFailed` | `approved` + `skippedModules [selfie]` | — |
| Kimlik (`idCard`) / OVD (`idcard_w_ovd`) | `approved` | `notCompleted / moduleFailed` | `approved` + `skippedModules` | — |
| Canlılık (`livenessDetection`) / Selfie + Canlılık | `approved` | `notCompleted / moduleFailed` | `approved` + `skippedModules` | `faceTrackingFallback` ile selfie gelir ya da modül çıkar |
| Video kayıt · İmza · Konuşma · Adres | `approved` | — (karşılaştırma yok) | — | — |
| Görüntülü görüşme (`waitScreen`) | Sonucu **panel** verir: `agentDecision` + `terminateReason` / `statusSummary` — [WebSocket → Görüşmenin Kapanışı](websocket.md#görüşmenin-kapanışı--terminatecall) | | | |

Her modülde ortak olan çıkışlar: ilk ekranda geri → `cancelled / userExited`, uygulama
kapatıldı → `cancelled / appTerminated`, bağlantı kopması → sonuç yok (yeniden bağlanma).

### 5.7 NFC'de işler farklı giderse

Aynı başlangıçla, müşteri NFC'yi **başarıyla** tamamlayamazsa:

| Ne oldu | `onFinished` | `skippedModules` | Kapanış |
|---|---|---|---|
| Çip ile belge verisi uyuşmadı, hak var | çağrılmaz — uyarı, NFC ekranında tekrar denenir | | |
| Karşılaştırma hakkı bitti, atlama **izinli** | `approved / allModulesCompleted` | `[nfc]` | 4100 |
| Karşılaştırma hakkı bitti, atlama **kapalı** | `notCompleted / moduleFailed` | `[]` | 4101 |
| Çip okunamadı, `nfcMaxErrorCount` sınırı | `approved / allModulesCompleted` | `[nfc]` | 4100 |
| Manuel MRZ düzeltmesi üst üste başarısız | `approved / allModulesCompleted` | `[nfc]` | 4100 |
| Cihazda NFC yok (`showNFCNotFoundPage: false`) | `approved / allModulesCompleted`, `modules = []` | `[nfc]` | 4100 |
| NFC ekranında geri butonu | `cancelled / userExited` | `[]` | 4102 |
| Uygulama kapatıldı | `cancelled / appTerminated` | `[]` | — |
| Bağlantı koptu / 30 sn'den uzun arka plan | çağrılmaz — Bağlantı Koptu, dönüşte NFC baştan | | |

Atlama izinli yoldaki log:

```
Modül sonucu — Mrz & Nfc Screen: atlandı.
Akış sonucu — sonuç: approved, sebep: allModulesCompleted, son modül: Mrz & Nfc Screen, adım: 1/1, atlanan modüller: Mrz & Nfc Screen.
```

---

## 6) Senaryo 2 — Üç modüllü akış (Kimlik → NFC → Selfie)

Çok modüllü akışta temel kural değişmez: **modüller arasında `onFinished` çağrılmaz**, sonuç
yalnızca oturum bittiğinde bir kez gelir. Fark şudur: oturum **herhangi bir adımda** bitebilir;
hangi adımda bittiğini `lastModule` ve `stepIndex / totalSteps` söyler, hangi adımların
doğrulanmadan geçildiğini `skippedModules`.

### 6.1 Başlangıç

- Panelde akış sırası: **Kimlik** (`idCard`) → **NFC** (`nfc`) → **Selfie** (`selfie`).
  Sırayı panel belirler; SDK `RoomResponse.modules` sırasını izler.
- Host kodu Senaryo 1 ile **aynıdır** — modül sayısı entegrasyonu değiştirmez:

```swift
coordinator.prepareForSetup()
IdentifyManager.shared.setupSDK(
    identId: identId,
    ...,
    showThankYouPage: false,
    onFinished: { outcome in KycRouter.shared.handle(outcome) }
) { socket, room, error in
    if socket?.isConnected == true, room.result == true { coordinator.start() }
}
```

### 6.2 Akış ilerlerken ne olur?

| Adım | Ekran | Müşteri | SDK | Host'a gelen | `onFinished` |
|---|---|---|---|---|---|
| 1/3 | Kimlik | Ön ve arka yüzü çeker | OCR + yükleme; panele ekran bilgisi gider | `module.Id Card.presented` → `module.Id Card.completed` | — |
| 2/3 | NFC | Çipi okutur | Çip okunur, sunucuda karşılaştırılır | `module.Mrz & Nfc Screen.presented` → `….completed` | — |
| 3/3 | Selfie | Yüzünü çeker | Yükleme + yüz karşılaştırması | `module.Selfie.presented` → `module.Selfie.completed` | — |
| son | — | — | Sıradaki modül yok → oturum kapanır | `session.finished`, `session.completed` | **çağrılır** |

Akış sürerken ilerlemeyi göstermek isterseniz `coordinator.progressStep` /
`coordinator.progressTotal` ya da `module.*` olaylarını kullanın; `onFinished` bunun için değildir.

### 6.3 Mutlu yol — üç adım da tamamlandı

Selfie tamamlanınca coordinator sıradaki modülü ister, sırada modül yoktur. Kapanış Senaryo 1'deki
8 adımın **aynısıdır** ([5.3](#53-sdk-işini-bitiriyor--çıkış-nasıl-oluyor)): sonuç üretilir →
log → olaylar → `onFinished` → socket 4100 → Selfie ekranı aşağı kayar → kaynaklar bırakılır.

| Alan | Değer |
|---|---|
| `result` / `reason` | `.approved` / `.allModulesCompleted` |
| `lastModule` | `.selfie` |
| `modules` | `[.idCard, .nfc, .selfie]` |
| `skippedModules` | `[]` |
| `stepIndex` / `totalSteps` | `3` / `3` |

```
Akış sonucu — sonuç: approved, sebep: allModulesCompleted, son modül: Selfie, adım: 3/3.
Oturum sonlandı — son modül: Selfie, akış tamamlandı, sebep: 4100 (flowCompleted): Akış tamamlandı — bağlantı normal kapatıldı
```

### 6.4 Akış ortada bitti — NFC'de hak tükendi, atlama kapalı

Müşteri Kimlik adımını tamamladı. NFC'de çip verisi belgeyle uyuşmadı ve karşılaştırma hakkı bitti;
panelde "sonuca rağmen modülü atla" **kapalı**.

1. NFC ekranında hata mesajı gösterilir; müşteri "Tamam"a basar.
2. SDK oturumu **başarısız** olarak kapatır — **Selfie adımı hiç açılmaz**.
3. `onFinished` çağrılır, socket **4101** ile kapanır.
4. `showThankYouPage: false` → NFC ekranı aşağı kayarak kalkar. (`true` → ThankYou "tamamlanamadı".)

| Alan | Değer |
|---|---|
| `result` / `reason` | `.notCompleted` / `.moduleFailed` |
| `lastModule` | `.nfc` — başarısız olan adım |
| `stepIndex` / `totalSteps` | `2` / `3` — akış 2. adımda bitti |
| `skippedModules` | `[]` |

```
Akış sonucu — sonuç: notCompleted, sebep: moduleFailed, son modül: Mrz & Nfc Screen, adım: 2/3.
```

```swift
case .notCompleted where outcome.reason == .moduleFailed:
    // Hangi adımda takıldığını kullanıcıya söyleyebilirsiniz
    router.show(.verificationFailed(step: outcome.lastModule))    // .nfc
```

### 6.5 Adım atlandı, akış devam etti — NFC'de hak tükendi, atlama izinli

Aynı durum, ama panelde atlama **açık**:

1. NFC atlanır (`module.Mrz & Nfc Screen.skipped`), akış **Selfie'ye geçer**. `onFinished` çağrılmaz.
2. Müşteri Selfie'yi tamamlar, oturum normal kapanır.

| Alan | Değer |
|---|---|
| `result` / `reason` | `.approved` / `.allModulesCompleted` |
| `lastModule` | `.selfie` |
| `skippedModules` | `[.nfc]` — **NFC doğrulanmadı** |
| `stepIndex` / `totalSteps` | `3` / `3` |

```swift
case .approved where outcome.skippedModules.isEmpty:
    router.show(.verified)
case .approved:
    router.show(.pendingManualReview(missing: outcome.skippedModules))   // [.nfc]
```

### 6.6 Kullanıcı geri butonuna bastı

| Nerede | Ne olur | `onFinished` |
|---|---|---|
| 3. adım (Selfie) ya da 2. adım (NFC) | **Bir önceki modüle döner**; panele konum güncellemesi gider, oturum sürer | çağrılmaz |
| 1. adım (Kimlik) — akışın ilk ekranı | Oturumdan çıkılır, socket **4102**, host'un kök ekranı görünür | `cancelled / userExited`, `lastModule = .idCard`, `stepIndex = 1` |

Yani çok modüllü akışta kullanıcı geri geri giderek ilk ekrana gelip oradan çıkabilir; ara
adımlardaki geri butonu oturumu bitirmez.

### 6.7 Bağlantı koptu ya da uygulama arka plana gitti

Müşteri 3. adımda (Selfie) iken bağlantı koptu:

1. **Bağlantı Koptu** ekranı açılır. `onFinished` **çağrılmaz**.
2. Müşteri yeniden bağlanırsa **Selfie baştan başlar** (Kimlik ve NFC tekrarlanmaz).
3. Müşteri bu ekrandayken uygulamayı kapatırsa: `cancelled / appTerminated`, `lastModule = .selfie`,
   `stepIndex = 3`.

Uygulama 30 saniyeden kısa arka planda kalırsa hiçbir şey olmaz; daha uzun kalırsa dönüşte aynı
Bağlantı Koptu ekranı gelir (4105).

### 6.8 NFC'si olmayan cihaz (iPad)

Akış kurulurken NFC modülü **akışa alınmaz**, panele `NFCStatus = notAvailable` gider. Akış
Kimlik → Selfie olarak iki adım sürer:

| Alan | Değer |
|---|---|
| `result` / `reason` | `.approved` / `.allModulesCompleted` |
| `modules` | `[.idCard, .selfie]` |
| `skippedModules` | `[.nfc]` |
| `stepIndex` / `totalSteps` | `2` / `2` |

### 6.9 Özet — üç modüllü akışın tüm çıkışları

| Ne oldu | `result / reason` | `lastModule` | `stepIndex` | `skippedModules` | Kapanış |
|---|---|---|---|---|---|
| Üç adım tamamlandı | `approved / allModulesCompleted` | `.selfie` | 3/3 | `[]` | 4100 |
| Bir adım atlandı (izinli), akış bitti | `approved / allModulesCompleted` | `.selfie` | 3/3 | `[atlanan]` | 4100 |
| Kimlik'te hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `.idCard` | 1/3 | `[]` | 4101 |
| NFC'de hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `.nfc` | 2/3 | `[]` | 4101 |
| Selfie'de hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `.selfie` | 3/3 | `[]` | 4101 |
| İlk ekranda geri | `cancelled / userExited` | `.idCard` | 1/3 | `[]` | 4102 |
| Uygulama kapatıldı | `cancelled / appTerminated` | o anki adım | o anki | o ana kadar atlananlar | — |
| NFC'siz cihaz, akış bitti | `approved / allModulesCompleted` | `.selfie` | 2/2 | `[.nfc]` | 4100 |
| Ara adımda geri / bağlantı kopması / kısa arka plan | **sonuç yok** — oturum sürer | | | | |

---

## 7) Senaryo 3 — Görüntülü görüşmeli üç modüllü akış (Kimlik → Selfie → Görüşme)

Görüntülü görüşme (`waitScreen`) akıştaki diğer modüllerden farklıdır: görüşmenin sonucunu
**temsilci** verir. Görüşme adımına kadar her şey Senaryo 2 ile aynıdır; görüşmede oturum
panelin kararıyla biter ve sonuç panelin sebep/statü bilgisini taşır.

### 7.1 Başlangıç ve ilk iki adım

- Panelde akış sırası: **Kimlik** → **Selfie** → **Görüntülü görüşme**.
- Host kodu Senaryo 1–2 ile aynıdır.
- Kimlik ve Selfie Senaryo 2'deki gibi ilerler; bu adımlarda hak tükenirse oturum aynı şekilde
  `moduleFailed` ile biter ve görüşme adımına hiç gelinmez.

### 7.2 Görüşme adımı

| Aşama | Müşteri ne görür | Host'a gelen | `onFinished` |
|---|---|---|---|
| Bekleme odası | Sıra bilgisi | `module.Call Wait Screen.presented` | — |
| Çağrı geliyor | Zil + "Cevapla" | `call.connected` | — |
| Görüşme | Temsilci ile görüntülü görüşme | — | — |
| Temsilci kapatmaya hazırlanıyor | "Görüşmeyi bitir" butonu kilitlenir | `delegate.disableEndCallButton()` | — |
| Temsilci karar verip kapatır | — | `call.ended` (metadata: `reason`, `statusSummary`) | **çağrılır** |

### 7.3 Temsilci onayladı

Temsilci panelde olumlu statüyü seçip görüşmeyi kapatır. Soketten gelen:
`terminateCall` · `terminateReason = NORMAL_CLOSE_BY_AGENT` · `statusSummary.type = positive`.

1. SDK kararı sınıflandırır → oturumu bitiren bir karar.
2. `onFinished` **karar anında** çağrılır.
3. Oturum kapatılır (socket **4103**), görüşme medyası bırakılır.
4. `showThankYouPage: false` → görüşme ekranı aşağı kayarak kalkar. (`true` → ThankYou "başarılı".)

| Alan | Değer |
|---|---|
| `result` / `reason` | `.approved` / `.agentDecision` |
| `lastModule` | `.waitScreen` |
| `stepIndex` / `totalSteps` | `3` / `3` |
| `terminateReason` | `"NORMAL_CLOSE_BY_AGENT"` |
| `statusSummary` | `id`, `type = "positive"`, `name_tr` … (panelde seçilen statü) |

```
Akış sonucu — sonuç: approved, sebep: agentDecision, son modül: Call Wait Screen, adım: 3/3, panel sebebi: NORMAL_CLOSE_BY_AGENT, panel statüsü: positive (id …).
Görüşme sonlandırma bildirimi alındı — sebep: NORMAL_CLOSE_BY_AGENT, panel statüsü: positive (id …)
Sonlandırma sonucu: temsilci normal kapattı, oturum panelin statüsüyle bitiriliyor (positive)
```

### 7.4 Görüşmenin diğer sonları

| Ne oldu | `result / reason` | `terminateReason` / `statusSummary` | Kapanış | Ekran (`true`) |
|---|---|---|---|---|
| Temsilci reddetti (`negative`) | `rejected / agentDecision` | dolu | 4103 | ThankYou — tamamlanamadı |
| Temsilci nötr statüyle kapattı (`neutral`) | `neutral / agentDecision` | dolu | 4103 | ThankYou — tamamlanamadı |
| Temsilci şüpheli bir durum için tanımlı olumsuz statüyü seçti | `rejected / agentDecision` | dolu — `statusSummary.id` ile ayırın | 4103 | ThankYou — tamamlanamadı (sebep gösterilmez) |
| Müşteri "Görüşmeyi bitir"e bastı | `notCompleted / userEndedCall` | `nil` | 4101 | ThankYou — tamamlanamadı |
| Temsilci statü seçmeden kapattı / bağlantı sorunu | **sonuç yok** — Bağlantı Koptu → bekleme odası | | | |
| Çağrı cevaplanmadı / cevapsız çağrı | **sonuç yok** — bekleme odasında kalır | | | |
| Görüşme sırasında bağlantı koptu, yeniden bağlanıldı, panelin kayıtlı statüsü `positive` | `approved / agentDecision` | `statusSummary` dolu, `terminateReason` `nil` | 4103 | ThankYou — başarılı |

Tüm `terminateReason` değerleri ve şüpheli kapanış örneği:
[WebSocket → Görüşmenin Kapanışı](websocket.md#görüşmenin-kapanışı--terminatecall).

### 7.5 Görüşme akışın ortasındaysa (Kimlik → Görüşme → İmza)

| Ne oldu | Sonraki adım (İmza) | `onFinished` |
|---|---|---|
| Temsilci karar verip kapattı (`terminateCall`) | **Açılmaz** — oturum görüşmede biter | `approved` / `rejected` / `neutral` · `agentDecision`, `lastModule = .waitScreen`, `stepIndex = 2/3` |
| Müşteri "Görüşmeyi bitir"e bastı | **Açılmaz** | `notCompleted / userEndedCall`, `stepIndex = 2/3` |
| Görüşme `terminateCall` gelmeden kapandı (`endCall`) | **Açılır**, müşteri İmza'yı tamamlar | akış sonunda `notCompleted / userEndedCall`, `lastModule = .signature`, `stepIndex = 3/3` |

### 7.6 Host kodu — görüşmeli akış

```swift
onFinished: { outcome in
    switch (outcome.result, outcome.reason) {
    case (.approved, .agentDecision):
        router.show(.approvedByAgent)
    case (.rejected, .agentDecision) where suspiciousStatusIds.contains(outcome.statusSummary?.id ?? -1):
        fraud.flag(outcome.sessionId, statusId: outcome.statusSummary?.id)
        router.show(.failedGeneric)                         // sebep müşteriye gösterilmez
    case (.rejected, _), (.neutral, _):
        router.show(.rejected(status: outcome.statusSummary?.name_tr))
    case (.notCompleted, .userEndedCall):
        router.show(.callEndedByUser)                       // tekrar denemeyi önerin
    case (.notCompleted, .moduleFailed):
        router.show(.failedAt(outcome.lastModule))          // görüşmeye gelinmeden bitti
    case (.cancelled, _):
        router.popToHome()
    default:
        router.show(.error(outcome.errorMessage))
    }
}
```

---

## 8) Modül bazında çıkış kataloğu — her modül için ne olur?

Senaryo 1'deki NFC örneğinin aynısı, **her modül için** ayrı ayrı. Bir modülü "X modülü" olarak
düşünün: tablolar X'in akışta **tek (ya da son) modül** olduğu durumu anlatır. X akışın ortasındaysa
"tamamlandı" ve "atlandı" satırlarında `onFinished` çağrılmaz, akış sıradaki modüle geçer; oturumu
bitiren satırlar (hak bitti + atlama kapalı, ilk ekranda geri, uygulama kapatıldı) her konumda
aynı sonucu verir, yalnızca `stepIndex` değişir.

### 8.0 Tüm modüllerde ortak olan çıkışlar

| Ne oldu | `onFinished` | Kapanış |
|---|---|---|
| Müşteri adımı tamamladı ve sırada modül yok | `approved / allModulesCompleted`, `lastModule = X` | 4100 |
| Akışın **ilk** ekranında geri butonu | `cancelled / userExited`, `lastModule = X` | 4102 |
| Ara ekranda geri butonu | **çağrılmaz** — bir önceki modüle dönülür | — |
| Uygulama kapatıldı | `cancelled / appTerminated`, `lastModule = X` | — |
| Bağlantı koptu / 30 sn'den uzun arka plan | **çağrılmaz** — Bağlantı Koptu, yeniden bağlanınca X baştan başlar | — |
| Host `exitSDK()` / `forceQuitSDK()` çağırdı | `cancelled / hostExit` · `hostForceQuit` | 4102 · 4103 |

Modüller iki gruba ayrılır:

- **Karşılaştırmalı modüller** — Kimlik, OVD, NFC, Selfie, Canlılık, Selfie + Canlılık. Sunucu
  sonucu belgeyle ya da önceki verilerle karşılaştırır. Karşılaştırma hakkı vardır; hak biterse
  panelde **"sonuca rağmen modülü atla"** ayarına göre modül atlanır ya da oturum `moduleFailed`
  ile biter.
- **Karşılaştırmasız modüller** — Hazırlık, Video kayıt, İmza, Konuşma, Adres. Hata olursa
  kullanıcıya mesaj gösterilir ve **aynı ekranda tekrar denenir**; bu modüller oturumu kendiliğinden
  bitirmez.

Tüm modüllerde host'un yazacağı kod aynıdır; modüle göre ayrım `lastModule` ve `skippedModules`
ile yapılır:

```swift
onFinished: { outcome in
    switch outcome.result {
    case .approved where outcome.skippedModules.isEmpty:
        router.show(.verified)
    case .approved:
        router.show(.pendingReview(unverified: outcome.skippedModules))   // hangi adımlar doğrulanmadı
    case .notCompleted, .rejected, .neutral:
        router.show(.failed(at: outcome.lastModule))                      // hangi adımda takıldı
    case .cancelled:
        router.popToHome()
    case .error:
        router.show(.error(outcome.errorMessage))
    }
}
```

Loglardaki modül adları `SdkModules` ham değerleridir (`lastModule.rawValue`).

---

### 8.1 Kimlik (`idCard`) — log adı `Id Card`

Müşteri belge türünü seçer (kimlik / pasaport / diğer), ön ve arka yüzü çeker; OCR sonucu sunucuda
karşılaştırılır.

| Ne oldu | Tek/son modülse `onFinished` | `skippedModules` | Ekran (`showThankYouPage: true`) | Kapanış |
|---|---|---|---|---|
| Çekim ve karşılaştırma geçti | `approved / allModulesCompleted` | `[]` | ThankYou — başarılı | 4100 |
| Veri uyuşmadı, hak var | çağrılmaz — uyarı, tekrar çekim | | | |
| Hak bitti, atlama izinli | `approved / allModulesCompleted` | `[idCard]` | ThankYou — başarılı | 4100 |
| Hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `[]` | ThankYou — tamamlanamadı | 4101 |
| İlk ekranda (belge türü seçimi) geri | `cancelled / userExited` | `[]` | Kök ekran | 4102 |

```
Akış sonucu — sonuç: notCompleted, sebep: moduleFailed, son modül: Id Card, adım: 1/1.
```

### 8.2 Kimlik OVD (`idcard_w_ovd`) — log adı `Id Card OVD`

Ön yüz, hologram (ışık altında kartı çevirme) ve arka yüz adımlarıyla kimlik doğrulaması. Pasaport
seçilirse panelde adım `Passport OVD` olarak görünür; `lastModule` yine `.idcard_w_ovd`'dir.

| Ne oldu | Tek/son modülse `onFinished` | `skippedModules` | Ekran | Kapanış |
|---|---|---|---|---|
| Tüm OVD adımları ve karşılaştırma geçti | `approved / allModulesCompleted` | `[]` | ThankYou — başarılı | 4100 |
| Çekim koşulu sağlanmıyor (hareket, parlama, netlik) | çağrılmaz — ekranda yönerge, çekim bekler | | | |
| Veri uyuşmadı, hak var | çağrılmaz — uyarı, tekrar | | | |
| Hak bitti, atlama izinli | `approved / allModulesCompleted` | `[idcard_w_ovd]` | ThankYou — başarılı | 4100 |
| Hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `[]` | ThankYou — tamamlanamadı | 4101 |

### 8.3 NFC (`nfc`) — log adı `Mrz & Nfc Screen`

Ayrıntılı anlatım Senaryo 1'dedir: [5.7 NFC'de işler farklı giderse](#57-nfcde-işler-farklı-giderse).

| Ne oldu | Tek/son modülse `onFinished` | `skippedModules` | Kapanış |
|---|---|---|---|
| Çip okundu ve doğrulandı | `approved / allModulesCompleted` | `[]` | 4100 |
| Veri uyuşmadı, hak var | çağrılmaz — önceki adıma dönülür (NFC ilk ekransa ekranda kalınır) | | |
| Hak bitti, atlama izinli | `approved / allModulesCompleted` | `[nfc]` | 4100 |
| Hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `[]` | 4101 |
| Çip okunamadı, `nfcMaxErrorCount` sınırı | `approved / allModulesCompleted` | `[nfc]` | 4100 |
| Manuel MRZ düzeltmesi üst üste başarısız | `approved / allModulesCompleted` | `[nfc]` | 4100 |
| **Cihazda NFC yok** | Modül akışa alınmaz; akışta başka modül yoksa `approved`, `modules = []` | `[nfc]` | 4100 |

### 8.4 Selfie (`selfie`) — log adı `Selfie`

Müşteri yüzünü çeker; yüz, belgedeki vesikalıkla karşılaştırılır.

| Ne oldu | Tek/son modülse `onFinished` | `skippedModules` | Ekran | Kapanış |
|---|---|---|---|---|
| Çekim ve yüz karşılaştırması geçti | `approved / allModulesCompleted` | `[]` | ThankYou — başarılı | 4100 |
| Yüz uyuşmadı, hak var | çağrılmaz — ipuçlarıyla tekrar çekim | | | |
| Hak bitti, atlama izinli | `approved / allModulesCompleted` | `[selfie]` | ThankYou — başarılı | 4100 |
| Hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `[]` | ThankYou — tamamlanamadı | 4101 |
| Kamera izni yok | çağrılmaz — izin uyarısı; müşteri geri çıkabilir | | | |

```
Modül sonucu — Selfie: atlandı.
Akış sonucu — sonuç: approved, sebep: allModulesCompleted, son modül: Selfie, adım: 1/1, atlanan modüller: Selfie.
```

### 8.5 Canlılık (`livenessDetection`) — log adı `Liveness Detection`

Müşteri ekrandaki yönergeleri (göz kırp, gülümse, başını çevir…) uygular; ekran kaydı yüklenir ve
yüz karşılaştırması yapılır. ARKit yüz takibi ister.

| Ne oldu | Tek/son modülse `onFinished` | `skippedModules` | Ekran | Kapanış |
|---|---|---|---|---|
| Adımlar, kayıt ve karşılaştırma geçti | `approved / allModulesCompleted` | `[]` | ThankYou — başarılı | 4100 |
| Kayıt izni yok / kayıt başlamadı / kesildi / yüklenemedi | çağrılmaz — uyarı, test baştan | | | |
| Yüz uyuşmadı, hak var | çağrılmaz — tekrar | | | |
| Hak bitti, atlama izinli | `approved / allModulesCompleted` | `[livenessDetection]` | ThankYou — başarılı | 4100 |
| Hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `[]` | ThankYou — tamamlanamadı | 4101 |
| **Cihaz yüz takibini desteklemiyor**, `faceTrackingFallback = .selfie` (varsayılan) | Canlılık yerine **Selfie** akışa girer; sonuç Selfie'ye göre üretilir | `[livenessDetection]` | | |
| Aynısı, `faceTrackingFallback = .skip` | Modül akıştan çıkarılır | `[livenessDetection]` | | |

Canlılık kaydı panelde kapalıysa yükleme atlanır; adım yine tamamlanmış sayılır ve
`skippedModules`'a eklenmez.

### 8.6 Selfie + Canlılık (`selfieWithLiveness`) — log adı `Selfie With Liveness`

Yüz ovale oturtulur, kısa canlılık kontrolü yapılır, selfie çekilip karşılaştırılır. Derinlik
kullanımı `selfieWithLivenessTrueDepth` ile seçilir (`.automatic` · `.required` · `.disabled`).

| Ne oldu | Tek/son modülse `onFinished` | `skippedModules` | Ekran | Kapanış |
|---|---|---|---|---|
| Çekim ve karşılaştırma geçti | `approved / allModulesCompleted` | `[]` | ThankYou — başarılı | 4100 |
| Yüz uyuşmadı, hak var | çağrılmaz — ipuçlarıyla tekrar | | | |
| Hak bitti, atlama izinli | `approved / allModulesCompleted` | `[selfieWithLiveness]` | ThankYou — başarılı | 4100 |
| Hak bitti, atlama kapalı | `notCompleted / moduleFailed` | `[]` | ThankYou — tamamlanamadı | 4101 |
| **Cihaz seçilen modu desteklemiyor** (akış kurulurken) | `faceTrackingFallback`'e göre Selfie gelir ya da modül çıkar | `[selfieWithLiveness]` | | |
| Cihazın desteklemediği ekranın içinde anlaşıldı | Uyarıdan sonra ekran kapanır: ilk ekransa `cancelled / userExited`, değilse önceki modüle dönülür | `[]` | | 4102 |

### 8.7 Hazırlık (`prepare`) — log adı `Prepare`

İzinlerin (kamera, mikrofon…) istendiği bilgilendirme adımı. Karşılaştırma yoktur.

| Ne oldu | Tek/son modülse `onFinished` | Kapanış |
|---|---|---|
| Müşteri "Devam"a bastı | `approved / allModulesCompleted` | 4100 |
| İlk ekranda geri | `cancelled / userExited` | 4102 |

Hazırlık çoğunlukla akışın ilk ekranıdır; müşteri daha başlamadan vazgeçtiğinde
`cancelled / userExited` + `lastModule = .prepare` gelir.

### 8.8 Video kayıt (`videoRecord`) — log adı `Video Recorder`

Müşteri kısa bir video çeker; panelde okuma metni tanımlıysa metni sesli okur ve konuşma doğrulanır.

| Ne oldu | Tek/son modülse `onFinished` | Kapanış |
|---|---|---|
| Video yüklendi (ve okuma doğrulandı) | `approved / allModulesCompleted` | 4100 |
| Okuma doğrulanamadı / konuşma algılanmadı | çağrılmaz — mesaj, tekrar kayıt | |
| Yükleme hatası | çağrılmaz — mesaj, tekrar | |

### 8.9 İmza (`signature`) — log adı `Signature`

| Ne oldu | Tek/son modülse `onFinished` | Kapanış |
|---|---|---|
| İmza yüklendi | `approved / allModulesCompleted` | 4100 |
| Yükleme hatası | çağrılmaz — mesaj, tekrar | |

### 8.10 Konuşma (`speech`) — log adı `Speech Recognition`

Müşteri ekrandaki ifadeyi sesli söyler.

| Ne oldu | Tek/son modülse `onFinished` | Kapanış |
|---|---|---|
| İfade doğrulandı | `approved / allModulesCompleted` | 4100 |
| İfade söylenmedi / tanınmadı | çağrılmaz — mesaj, tekrar | |
| Mikrofon izni yok | çağrılmaz — izin uyarısı; müşteri geri çıkabilir | |

### 8.11 Adres (`addressConf`) — log adı `Address Confirm`

Müşteri adresini girer ve belge (PDF / fotoğraf) yükler.

| Ne oldu | Tek/son modülse `onFinished` | Kapanış |
|---|---|---|
| Adres ve belge gönderildi | `approved / allModulesCompleted` | 4100 |
| Dosya okunamadı / PDF boyut sınırını aştı / yükleme hatası | çağrılmaz — mesaj, tekrar | |

### 8.12 Görüntülü görüşme (`waitScreen`) — log adı `Call Wait Screen`

Sonucu temsilci verir; ayrıntı [7) Senaryo 3](#7-senaryo-3--görüntülü-görüşmeli-üç-modüllü-akış-kimlik--selfie--görüşme)
ve [WebSocket → Görüşmenin Kapanışı](websocket.md#görüşmenin-kapanışı--terminatecall).

| Ne oldu | `onFinished` | Kapanış |
|---|---|---|
| Temsilci onayladı / reddetti / nötr kapattı | `approved` · `rejected` · `neutral` / `agentDecision` + `terminateReason`, `statusSummary` | 4103 |
| Müşteri "Görüşmeyi bitir"e bastı | `notCompleted / userEndedCall` | 4101 |
| Görüşme `terminateCall` gelmeden kapandı, akış bitti | `notCompleted / userEndedCall` | 4100 |
| Temsilci statü seçmeden / bağlantı sorunuyla kapattı | çağrılmaz — Bağlantı Koptu → bekleme odası | |
| Çağrı cevaplanmadı / cevapsız çağrı | çağrılmaz — bekleme odasında kalır | |
| Oda başka bir oturumda | `error / roomOccupied` | 4120 |

---

## 9) Kapanıştan sonra yönlendirme — kodu nereye yazacağım?

Kural: **yönlendirmeyi `onFinished` içinde başlatın.** Nasıl yapacağınız SDK'yı nasıl
sunduğunuza ve sonuç ekranını isteyip istemediğinize bağlıdır.

| Sunum | `showThankYouPage` | Yönlendirme nerede |
|---|---|---|
| `SDKFlowHostView` uygulamanın kökünde (örnek uygulamadaki gibi) | `false` | `onFinished` → kök ekranınızın state'i |
| `SDKFlowHostView` bir `fullScreenCover` / modal içinde | `false` | `onFinished` → kabı kapat + yönlendir |
| UIKit `UIHostingController` ile sunulmuş | `false` | `onFinished` → `dismiss(animated:)` tamamlanınca yönlendir |
| Herhangi biri | `true` (sonuç ekranı görünsün) | `onFinished`'ta sonucu **saklayın**; kullanıcı ThankYou'daki butona basıp akış köke dönünce yönlendirin |
| React Native / Flutter | ikisi de | `session.finished` olayında |

### 9.1 SwiftUI — SDK uygulamanın kökünde

`SDKFlowHostView` yığın boşken sizin kök view'ınızı (ör. giriş ekranı) çizer. `showThankYouPage: false`
iken SDK son ekranı aşağı kaydırıp kaldırır ve kök view'ınız görünür; yönlendirme o view'ın
state'idir:

```swift
@MainActor
final class KycLauncherViewModel: ObservableObject {
    @Published var destination: KycDestination?          // kök view bunu gözler

    func start(coordinator: SDKFlowCoordinator) {
        coordinator.prepareForSetup()
        IdentifyManager.shared.setupSDK(
            ...,
            showThankYouPage: false,
            onFinished: { [weak self] outcome in
                self?.destination = KycDestination(outcome)   // aşağı kayma animasyonuyla aynı anda
            }
        ) { socket, room, error in
            if let message = error?.errorMessages, !message.isEmpty { return }   // setupFailed ayrıca onFinished'a da gelir
            if socket?.isConnected == true, room.result == true { coordinator.start() }
        }
    }
}

struct LoginView: View {
    @StateObject var vm = KycLauncherViewModel()
    var body: some View {
        content
            .fullScreenCover(item: $vm.destination) { KycResultView(destination: $0) }
            // ya da NavigationStack path'inize ekleyin
    }
}
```

### 9.2 SwiftUI — SDK bir `fullScreenCover` içinde

```swift
@State private var showKyc = false
@State private var kycOutcome: SDKFlowOutcome?

.fullScreenCover(isPresented: $showKyc, onDismiss: {
    if let outcome = kycOutcome { router.handleKyc(outcome) }   // kap kapandıktan SONRA yönlendir
}) {
    KycFlowRoot()        // içinde SDKFlowHostView; setupSDK(onFinished:) oradan çağrılır
}

// setupSDK içinde:
onFinished: { outcome in
    kycOutcome = outcome
    showKyc = false      // kabı kapat
}
```

### 9.3 UIKit

```swift
final class KycCoordinator: IdentifyFlowResultListener {
    private weak var presenter: UIViewController?
    private var host: UIViewController?
    private let coordinator = SDKFlowCoordinator()
    private let registry = SDKViewRegistry()

    func start(from presenter: UIViewController) {
        self.presenter = presenter
        IdentifyManager.shared.flowResultDelegate = self          // setupSDK'dan ÖNCE
        let flow = SDKFlowHostView(coordinator: coordinator, registry: registry) { EmptyView() }
        let host = UIHostingController(rootView: flow)
        host.modalPresentationStyle = .fullScreen
        presenter.present(host, animated: true)
        self.host = host
        // setupSDK(..., showThankYouPage: false) ...
    }

    func identifyFlowDidFinish(_ outcome: SDKFlowOutcome) {
        host?.dismiss(animated: true) { [weak self] in
            self?.route(outcome)                                   // kap kapandıktan sonra
        }
    }

    private func route(_ outcome: SDKFlowOutcome) {
        switch outcome.result {
        case .approved where outcome.skippedModules.isEmpty:
            presenter?.navigationController?.pushViewController(SuccessViewController(), animated: true)
        case .approved, .rejected, .neutral, .notCompleted:
            presenter?.navigationController?.pushViewController(ReviewViewController(outcome: outcome), animated: true)
        case .cancelled, .error:
            break                                                  // kullanıcı bulunduğu ekranda kalır
        }
    }
}
```

### 9.4 Sonuç ekranı görünsün, ardından yönlendir (`showThankYouPage: true`)

`onFinished` sonuç ekranı **açılırken** gelir. Kabı o anda kapatırsanız kullanıcı ThankYou'yu
görmez. Sonucu saklayın ve kullanıcı ThankYou'daki butona basıp akış köke döndüğünde
yönlendirin:

```swift
@State private var pendingOutcome: SDKFlowOutcome?

SDKFlowHostView(coordinator: coordinator, registry: registry) { LoginView() }
    .onChange(of: coordinator.path.isEmpty) { isEmpty in
        guard isEmpty, let outcome = pendingOutcome else { return }
        pendingOutcome = nil
        router.handleKyc(outcome)
    }

// setupSDK içinde:
onFinished: { outcome in pendingOutcome = outcome }
```

### 9.5 React Native / Flutter

Köprüler `eventDelegate`'i dinler; sonuç `session.finished` olayında gelir:

```ts
IdentifySdk.addEventListener((event) => {
  if (event.name !== 'session.finished') return;
  const { result, endReason, skippedModules, terminateReason, statusId } = event.metadata;
  navigation.replace(result === 'approved' && !skippedModules ? 'KycSuccess' : 'KycReview',
                     { result, endReason, terminateReason, statusId });
});
```

`skippedModules` metadata'da virgülle ayrılmış metin olarak gelir (boşsa anahtar yoktur).
Kabı `<Modal>` ile sunuyorsanız `showThankYouPage: false` verip bu olayda `Modal`'ı kapatın.

---

## 10) Kurallar ve tuzaklar

- **Oturumun sonucu tektir.** Aynı oturumda ikinci bir çağrı gelmez; `quitSDK` / `exitSDK` gibi
  kapanış çağrıları sonuç zaten üretildiyse yeni bir sonuç üretmez.
- **`onFinished` içinde `setupSDK` çağırmayın.** Yeni oturumu yönlendirme tamamlandıktan sonra,
  kullanıcı eylemiyle başlatın.
- **`onFinished` içinde `exitSDK` / `forceQuitSDK` gerekmez** — oturum kapanmış ya da kapanmaktadır.
- **Sonuç ekranını kendiniz gösterecekseniz `showThankYouPage: false` verin.** Parametre
  verilmezse varsayılan `true`'dur ve ThankYou açılır.
- **Karar sunucudadır.** `approved` SDK tarafında akışın başarıyla bittiğini söyler; kritik iş
  kararlarını (limit artırımı, hesap açma) sunucunuzdaki doğrulama sonucuna bağlayın.
- **Şüpheli/ret ayrımını statü id'siyle yapın**, statü adıyla değil:
  [WebSocket → Şüpheli kapanış örneği](websocket.md#örnek-temsilci-şüpheli-bir-durum-görüp-görüşmeyi-sonlandırdı).
- **Delegate weak tutulur.** `flowResultDelegate`'e verdiğiniz nesneyi siz saklayın.

---

## 11) Doğrulama listesi

Yayına çıkmadan önce en az şu çıkışları gerçek cihazda deneyin ve `onFinished` değerini
loglayın:

| Deneme | Beklenen |
|---|---|
| Akışı sonuna kadar tamamla | `approved / allModulesCompleted`, `skippedModules` boş |
| Görüşmede temsilci onaylasın / reddetsin | `approved` / `rejected` + `terminateReason`, `statusSummary` |
| Kullanıcı görüşmeyi bitirsin | `notCompleted / userEndedCall` |
| Bir modülde hakları bitir (atlama kapalı) | `notCompleted / moduleFailed`, `lastModule` doğru |
| Bir modülde hakları bitir (atlama açık) | `approved`, `skippedModules` o modülü içerir |
| İlk ekranda geri çık | `cancelled / userExited` |
| Geçersiz `identId` | `error / setupFailed` + `errorMessage` |
| `showThankYouPage: false` | Sonuç ekranı yok, SDK aşağı kayarak kapanır, yönlendirmeniz çalışır |
| Uçak modu açıp kapat | `onFinished` **çağrılmaz**, Bağlantı Koptu ekranı gelir |
