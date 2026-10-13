# Mimari — SDK'nın Büyük Resmi

Bu rehber IdentifySDK'nın parçalarını ve bunların birbirine nasıl bağlandığını anlatır: hangi
parça neyi yönetir, bir modül ekranı nasıl açılır, soket ve görüntülü görüşme neden ekranlardan
ayrı tutulur.

← [README'ye dön](../../README.md)

---

## Katmanlar

```
┌─────────────────────────────────────────────────────────┐
│  Host Uygulama (sizin kodunuz)                          │
│  RootView · LoginView · (isteğe bağlı) custom ekranlar  │
├─────────────────────────────────────────────────────────┤
│  DefaultUI (SDK içinde, SwiftUI)                        │
│  SDKFlowHostView · SDKFlowCoordinator · SDKViewRegistry │
│  Modül ekranları (SDKSelfieView...) + ViewModel'leri    │
├─────────────────────────────────────────────────────────┤
│  Çekirdek — IdentifyManager.shared (singleton)          │
│  Modül hattı · oturum durumu · iş mantığı (OCR, NFC...) │
├──────────────┬──────────────────┬───────────────────────┤
│  SDKNetwork  │  WebSocket       │  WebRTCClient         │
│  (HTTP)      │  (Starscream)    │  (görüntülü görüşme)  │
└──────────────┴──────────────────┴───────────────────────┘
                        │
                 Identify Backend
```

Soket ve WebRTC bağlantıları ekranlarda değil, `IdentifyManager` singleton'ında tutulur. Ekranlar
açılıp kapanır, bağlantılar bundan etkilenmez. Akışın ortasına kendi ekranınızı eklediğinizde
bağlantının kopmamasının sebebi budur.

---

## Oturumun Yaşam Döngüsü

Bir KYC oturumu şu adımlardan geçer:

1. `coordinator.prepareForSetup()`: DefaultUI, SDK'nın beklediği yer tutucu controller'ları
   kaydeder. `setupSDK`'dan önce çağrılmazsa modüller hiç başlamaz.
2. `setupSDK(identId:...)`: SDK, `baseApiUrl` üzerinden odaya bağlanır (`connectToRoom`).
3. Backend `RoomResponse` döner. Oturum için gereken her şey bunun içindedir: `modules` (hangi
   adımlar, hangi sırayla), `ws_url` (soket adresi), karşılaştırma hakları, TURN ve soket
   güvenlik bayrakları. Ayrıntı: [Sunucu & API](server-api.md).
4. SDK, `modules` listesinden `modulesControllersArray` ve `identifyModules` dizilerini oluşturur
   (`addWebModules` → `addModules`).
5. Soket bağlanır, gerekiyorsa token ile (`socket_auth`). Ayrıntı: [WebSocket](websocket.md).
6. `coordinator.start()`: ilk modülün rotası `path`'e eklenir ve ekran açılır.
7. Modüller sırayla ilerler. Bir modül bittiğinde `advanceToNextModule()` çağrılır, SDK backend'e
   adım sinyali gönderir ve sıradaki ekran açılır.
8. Akış ThankYou ekranında biter ve sonucu (başarılı, reddedildi ya da beklemede) gösterir.

---

## DefaultUI Üçlüsü

SwiftUI tarafı üç yapının üzerine kurulu:

| Yapı | Tip | Görev |
|---|---|---|
| `SDKFlowCoordinator` | `ObservableObject` | Akışı yönetir: modül geçişleri (ileri, atla, geri), navigasyon `path`'i, ilerleme sayacı ve `IdentifyManager` ile bağlantı |
| `SDKViewRegistry` | sınıf | Hangi rotada hangi ekranın açılacağını tutar; override ve custom ekran kayıtları burada |
| `SDKFlowHostView` | `View` | Kök view. `coordinator.path`'teki rotayı çizer: önce registry'ye bakar, kayıt yoksa SDK'nın hazır ekranını gösterir |

Her rota için ekran aynı sırayla seçilir:

```
rota geldi → registry.override(...) kaydı var mı? ─ evet → sizin ekranınız
                                                  └ hayır → SDK'nın drop-in ekranı
```

### Modül ViewModel'leri

Her modülün bir `SDKXxxViewModel`'i var ve hepsi şu sınıftan türüyor:

```swift
@MainActor open class SDKBaseModuleViewModel: ObservableObject {
    @Published public var isLoading: Bool
    @Published public var errorMessage: String?
    let manager = IdentifyManager.shared
}
```

VM'ler `public final` olduğu için davranışlarını değiştiremezsiniz, yalnızca kendi kodunuzla
sarabilirsiniz. Kendi ekranınızı yazsanız da tarama, yükleme ve adım sinyali gibi işleri yine bu
VM'ler yapar. Bu kuralın adı ["bypass yok" kuralı](customization.md#bypass-yok-kuralı).

### Coordinator API — sık kullanılanlar

| Üye | Görev |
|---|---|
| `prepareForSetup()` | `setupSDK`'dan önce çağrılır; yer tutucu controller'ları kaydeder |
| `start()` | İlk modülü açar |
| `advanceToNextModule()` | Sıradaki modüle geçer. Araya eklenmiş custom ekran varsa önce onu açar |
| `skipCurrentModule()` | Modülü atlar (`manager.skipModule()` ve ardından ilerleme) |
| `insert(_:before:)` / `insert(_:after:)` | Bir rotanın önüne ya da arkasına custom ekran ekler. Eklenen ekran `advanceExternal()` ile ilerler |
| `appendModules(_:)` / `appendModules(moduleList:)` | Akışın sonuna yeni SDK modülü ekler. Dallanan senaryolar için; `progressTotal` kendiliğinden güncellenir |
| `showExternalScreen(_:)` / `advanceExternal()` | O an bir custom ekran gösterir / custom ekrandan akışa devam eder. Ayrıntı: [Özelleştirme, advanceExternal](customization.md#ara-ekrandan-ilerlemek-advanceexternal) |
| `popBack()` | Bir geri gider; ilk ekrandaysa `exitSDK()` çağırır |
| `pushThankYouDirectly(status:)` | Görüşme sonucuyla doğrudan sonuç ekranını açar. `showThankYouPage: false` ise sonuç ekranı açılmaz, akış aşağı kayarak kapanır |
| `resetFlow()` | Her şeyi sıfırlar |

Host uygulamanın bağlanabileceği yayınlanan değerler: `path`, `activeModule`, `progressStep`,
`progressTotal`, `sdkError`, `subRejected`, `pendingThankYouStatus`. Kendi ilerleme çubuğunuzu
bunlarla çizebilirsiniz.

### Akışın çizimi

Örneklerde sunucunun sırası Prepare → Kimlik → NFC → Selfie → Görüşme, yani 5 adım.
`┌─┐` SDK modülü, `╭┄╮` `insert` ile araya eklenen ekrandır. PANEL satırı sunucunun kullanıcıyı
nerede gördüğünü gösterir. Bu satır değişmiyorsa sunucuya bir şey gitmemiştir.

#### Ekleme yokken

```
        ┌─────────┐  advanceToNextModule()  ┌────────┐  advanceToNextModule()  ┌─────┐
 EKRAN  │ Prepare │ ──────────────────────> │ Kimlik │ ──────────────────────> │ NFC │
        └─────────┘                         └────────┘                         └─────┘
 PANEL    prepare                             idCard                             nfc
 ADIM       1/5                                 2/5                              3/5
```

#### Modülün önüne ekran

`insert(["kimlikIpucu"], before: .idCard)`. Ara ekran açıkken panel ve sayaç önceki modülde
kalır. Sunucu Kimlik'i ancak `advanceExternal()` çağrılınca öğrenir.

```
        ┌─────────┐  advanceToNextModule()  ╭┄┄┄┄┄┄┄┄┄┄┄┄┄╮  advanceExternal()  ┌────────┐
 EKRAN  │ Prepare │ ──────────────────────> ┆ kimlikIpucu ┆ ──────────────────> │ Kimlik │
        └─────────┘                         ╰┄┄┄┄┄┄┄┄┄┄┄┄┄╯                     └────────┘
 PANEL    prepare                               prepare                           idCard
 ADIM       1/5                                   1/5                               2/5
```

#### Modülün arkasına ekran

`insert(["cipOkundu"], after: .nfc)`. NFC bitmiştir ama sunucu Selfie'ye geçildiğini henüz bilmez.

```
        ┌─────┐  advanceToNextModule()  ╭┄┄┄┄┄┄┄┄┄┄┄╮  advanceExternal()  ┌────────┐
 EKRAN  │ NFC │ ──────────────────────> ┆ cipOkundu ┆ ──────────────────> │ Selfie │
        └─────┘                         ╰┄┄┄┄┄┄┄┄┄┄┄╯                     └────────┘
 PANEL    nfc                                nfc                            selfie
 ADIM     3/5                                3/5                              4/5
```

#### Önüne ve arkasına aynı geçişte

`insert(["cipOkundu"], after: .nfc)` ile `insert(["selfieIpucu"], before: .selfie)` tek kuyruk
olur ve önce `after` ile eklenen açılır. Kuyrukta ekran kaldıkça `advanceExternal()` sıradaki ara
ekranı açar; sunucuya haber kuyruk bitince gider.

```
        ┌─────┐  advanceToNextModule()  ╭┄┄┄┄┄┄┄┄┄┄┄╮  advanceExternal()  ╭┄┄┄┄┄┄┄┄┄┄┄┄┄╮  advanceExternal()  ┌────────┐
 EKRAN  │ NFC │ ──────────────────────> ┆ cipOkundu ┆ ──────────────────> ┆ selfieIpucu ┆ ──────────────────> │ Selfie │
        └─────┘                         ╰┄┄┄┄┄┄┄┄┄┄┄╯                     ╰┄┄┄┄┄┄┄┄┄┄┄┄┄╯                     └────────┘
 PANEL    nfc                                nfc                                nfc                             selfie
 ADIM     3/5                                3/5                                3/5                               4/5
```

#### Prepare'in önüne

`insert(["kvkkOnay"], before: .prepare)` çalışır, çünkü `start()` ilk geçişte de eklenen ekranlara
bakar. Yığında yalnızca bu ekran olduğu için orada geri basmak oturumu kapatır. `after: .prepare`
ise sıradan bir arkasına eklemedir ve hız testinden sonra açılır.

```
                   ╭┄┄┄┄┄┄┄┄┄┄╮  advanceExternal()  ┌─────────┐
 EKRAN  start() ─> ┆ kvkkOnay ┆ ──────────────────> │ Prepare │
                   ╰┄┄┄┄┄┄┄┄┄┄╯                     └─────────┘
 PANEL                   -                            prepare
 ADIM                    -                              1/5
```

#### Geri gitme ve `path`

`insert(["nfcRehber"], before: .nfc)` eklenmiş, kullanıcı NFC ekranında geri basıyor. Her satırda
en sağdaki kutu ekrandaki ekrandır. SDK modülünden geri gelince imleç bir adım geri sarılır, ara
ekrandan geri gelince yerinde kalır. Panele geri dönüş yalnızca yeni tepedeki ekran bir SDK modülü
olduğunda bildirilir.

```
        ┌─────────┐ ┌────────┐ ╭┄┄┄┄┄┄┄┄┄┄┄╮ ┌─────┐
 path   │ prepare │ │ idCard │ ┆ nfcRehber ┆ │ nfc │   imleç 3 · panel nfc
        └─────────┘ └────────┘ ╰┄┄┄┄┄┄┄┄┄┄┄╯ └─────┘
            │
            │ popBack()   NFC modül: imleç bir geri
            ▼
        ┌─────────┐ ┌────────┐ ╭┄┄┄┄┄┄┄┄┄┄┄╮
 path   │ prepare │ │ idCard │ ┆ nfcRehber ┆   imleç 2 · panel nfc      (üstte ara ekran, bildirilmez)
        └─────────┘ └────────┘ ╰┄┄┄┄┄┄┄┄┄┄┄╯
            │
            │ popBack()   ara ekran: imleç aynı
            ▼
        ┌─────────┐ ┌────────┐
 path   │ prepare │ │ idCard │   imleç 2 · panel idCard   (reportBackNavigation)
        └─────────┘ └────────┘
            │
            │ popBack()
            ▼
        ┌─────────┐
 path   │ prepare │   imleç 1 · panel prepare
        └─────────┘
            │
            │ popBack()   yığında tek ekran
            ▼
        oturum kapanır (exitSDK, sonuç: cancelled)
```

Kullanıcı ara ekrana geri dönüp oradan yeniden ilerlerse aynı ekran bir kez daha açılır:

```
        ┌─────────┐ ┌────────┐ ╭┄┄┄┄┄┄┄┄┄┄┄╮
 path   │ prepare │ │ idCard │ ┆ nfcRehber ┆   kullanıcı geri geldi
        └─────────┘ └────────┘ ╰┄┄┄┄┄┄┄┄┄┄┄╯
            │
            │ advanceExternal()
            ▼
        ┌─────────┐ ┌────────┐ ╭┄┄┄┄┄┄┄┄┄┄┄╮ ╭┄┄┄┄┄┄┄┄┄┄┄╮
 path   │ prepare │ │ idCard │ ┆ nfcRehber ┆ ┆ nfcRehber ┆   aynı ekran ikinci kez açıldı
        └─────────┘ └────────┘ ╰┄┄┄┄┄┄┄┄┄┄┄╯ ╰┄┄┄┄┄┄┄┄┄┄┄╯
            │
            │ advanceExternal()
            ▼
        ┌─────────┐ ┌────────┐ ╭┄┄┄┄┄┄┄┄┄┄┄╮ ╭┄┄┄┄┄┄┄┄┄┄┄╮ ┌─────┐
 path   │ prepare │ │ idCard │ ┆ nfcRehber ┆ ┆ nfcRehber ┆ │ nfc │
        └─────────┘ └────────┘ ╰┄┄┄┄┄┄┄┄┄┄┄╯ ╰┄┄┄┄┄┄┄┄┄┄┄╯ └─────┘
```

#### Entegratör neyi yapabilir, neyi yapamaz

```
 ✓ insert(before:/after:)   modülün önüne ya da arkasına kendi ekranı
 ✓ showExternalScreen       akış sırasında anlık bir ekran
 ✓ appendModules            akışın SONUNA SDK modülü
 ✓ override                 SDK ekranının görünümü (iş yine VM'de)
 ✓ skipCurrentModule        modülü atlamak (panel görür)
 ✓ path, progressStep       okuyup kendi ilerleme çubuğunu çizmek

 ✗ sunucunun modül sırasını değiştirmek
 ✗ iki modülün arasına SDK modülü sokmak
 ✗ path'e yazmak (dışarıya salt okunur)
 ✗ ara ekrandan sunucuya adım göndermek ya da sayacı ilerletmek
 ✗ ara ekrandan advanceToNextModule()   → yok sayılır, uyarı loglanır
 ✗ override ekranda VM'i atlamak
```

#### Sınırlar

- `insert` çağrıları birikir ve `resetFlow()` bunları silmez. Uygulama açılışında bir kez çağırın.
- Ara ekranın her ileri yolu `advanceExternal()` ile bitmeli. Bitmezse akış orada kalır.
- Görüşmenin arkasına ya da Teşekkür'ün önüne ekran eklemeyin. Panel kararıyla biten görüşme
  doğrudan sonuca gider ve eklenen ekranları atlar; soketle biten görüşme onları gösterir.
- `advanceExternal()` düğmesini ilk dokunuşta kilitleyin. Kuyrukta bekleyen ekran varken çift
  dokunuş bir ara ekranı atlatabilir.
- Geri dönüşte ara ekranın ikinci kez açılması yalnızca geri gidilebilen bir modülün önüne
  eklenen ekranda olur.

---

## Modüllerin Dış Dünya Bağımlılıkları

Modüllerin hepsi aynı altyapıyı kullanmıyor; bazıları tamamen cihazda çalışıyor:

| Bağımlılık | Modüller |
|---|---|
| Yalnızca cihaz üzerinde (soket yok) | IdCard (OCR), IdCardOVD, Selfie, Liveness (kare analizi), Prepare (izinler) |
| HTTP upload (sonuç sunucuya gider) | IdCard, IdCardOVD, NFC, Selfie, Liveness, Signature, VideoRecorder, AddressConfirm |
| Soket sinyali (adım/durum bildirimi) | Prepare, SignLang, Speech, CallScreen |
| WebRTC (canlı görüntü + data channel) | CallScreen |

ThankYou ve sizin tanıtım ya da başarı ekranlarınız gibi pasif ekranlar hiçbir sinyal göndermez.
Bunları akışın herhangi bir yerine güvenle ekleyebilirsiniz.

---

## Kesişen Sistemler

Bütün modülleri ilgilendiren konuların kendi rehberleri var:

- [WebSocket yapısı ve reconnect](websocket.md): bağlantı kopması dahil
- [TURN & WebRTC](turn-webrtc.md): görüşme altyapısı
- [Loglama](logging.md) · [Event sistemi](events.md): izleme
- [Tema](theming.md) · [Lokalizasyon](localization.md): görünüm ve dil
- Sesli okuma (Read-Aloud): [ReadAloud rehberi](../../IdentifySample/Modules/ReadAloud.md)
