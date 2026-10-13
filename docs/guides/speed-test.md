# Bağlantı Hız Testi

SDK'da iki hız testi var. Hangisinin çalışacağını tek bir ayar belirler:

| | Eski test | Yeni test |
|---|---|---|
| Nereye ölçer | `https://www.google.com` | Identify sunucusu (`/speedtest/*` uçları) |
| Ne ölçer | İndirme hızı | Ping, jitter, indirme, yükleme ve TURN üzerinden WebRTC ölçümü |
| Kararı kim verir | Cihaz (hız sınıfı: `good` / `poor` / `disConnected`) | Sunucu (`blockIdent`) |
| Sonuç sunucuya gider mi | Hayır | Evet, oturuma bağlı kaydedilir |
| Metot | `startSpeedTest(repeatCount:callBack:)` | `startConnectionSpeedTest(identId:baseApiUrl:callBack:)` |

Varsayılan eski testtir. Mevcut entegrasyonlarda hiçbir şey değişmez; yeni testi isteyen açar.

---

## İçindekiler

1. [Yeni testi açmak](#1-yeni-testi-açmak)
2. [Test ne zaman çalışır?](#2-test-ne-zaman-çalışır)
3. [Sonuç nasıl okunur?](#3-sonuç-nasıl-okunur)
4. [Modülden önce ölçüm ekranı](#4-modülden-önce-ölçüm-ekranı)
5. [Hazırlık ekranında ölçmek](#5-hazırlık-ekranında-ölçmek)
6. [Hazırlık ekranını kendiniz çizdiyseniz](#6-hazırlık-ekranını-kendiniz-çizdiyseniz)
7. [Testi akış başlamadan çalıştırmak](#7-testi-akış-başlamadan-çalıştırmak)
8. [Örnek uygulamada denemek](#8-örnek-uygulamada-denemek)
9. [Sık sorulanlar](#9-sık-sorulanlar)

---

## 1) Yeni testi açmak

```swift
IdentifyManager.shared.useConnectionSpeedTest = true
```

| Değer | Hazırlık ekranında çalışan test |
|---|---|
| `false` (varsayılan) | Eski test (google.com) |
| `true` | Yeni test (sunucu) |

Ayarı `coordinator.start()` çağrısından önce verin. En kolay yer `setupSDK` çağrısının hemen
öncesidir:

```swift
IdentifyManager.shared.useConnectionSpeedTest = true

IdentifyManager.shared.setupSDK(identId: identId, baseApiUrl: baseApiUrl, ...) { socket, room, error in
    guard error == nil else { return }
    coordinator.start()
}
```

Ayar oturum boyunca okunur. Hazırlık ekranı açıldıktan sonra değiştirirseniz bir sonraki ölçüm
yeni değerle çalışır.

---

## 2) Test ne zaman çalışır?

Hız testini sunucudaki akış tetikler, uygulama tarafında ayrıca bir şey açmanız gerekmez.

1. `setupSDK` odaya bağlanır, sunucu modül listesini döner.
2. Listede görüntülü görüşme (`waitScreen`) varsa SDK `needSpeedTest = true` yapar.
3. Hazırlık ekranında (`prepare`) kullanıcı izinleri verip kontrol listesini işaretler.
4. Düğme "Bağlantı Kalitemi Ölç ve Devam Et" olur. Dokununca test çalışır.

Akışta görüşme yoksa hazırlık ekranı testi atlar; düğme doğrudan "Devam Et" olur. Akışta hazırlık
ekranı yoksa test hiç çalışmaz. Ölçümü belirli bir modülün hemen önünde yapmak istiyorsanız
[bölüm 4](#4-modülden-önce-ölçüm-ekranı)'teki ara ekranı kullanın.

---

## 3) Sonuç nasıl okunur?

Yeni test `SDKSpeedTestResult` döner. Kullanıcının durdurulup durdurulmayacağını **yalnızca**
`blockIdent` belirler:

| Alan | Anlamı |
|---|---|
| `blockIdent` | `true` ise kullanıcı ilerlememeli. Tek karar alanı budur. |
| `outcome` | `.passed`, `.failed` ya da `.skipped` (ölçüm yapılamadı) |
| `gateEnabled` | Sunucuda engelleme açık mı. `false` iken `blockIdent` hep `false` gelir. |
| `failedChecks` | Eşiği geçemeyen kalemler, ör. `["uploadKbps", "rttMs"]` |
| `downloadKbps`, `uploadKbps`, `rttMs`, `jitterMs` | Ölçülen değerler; loglama ve bilgi amaçlı |
| `qualityScore`, `qualityBand` | Sunucunun verdiği puan (0 ile 100 arası) ve bandı (`good` / `fair` / `poor`) |
| `rtcOutcome`, `rtcPacketsLost`, `rtcRttMs`, … | TURN üzerinden yapılan WebRTC ölçümü |
| `connectionStatus` | Eski `SDKNetworkStatus` karşılığı: `failed` → `.poor`, sunucuya ulaşılamadı → `.disConnected`, diğerleri → `.good` |
| `summary` | Loga yazılabilecek tek satırlık özet |

Kurallar:

- Ölçülen hızları kendi eşiğinizle karşılaştırıp kullanıcıyı durdurmayın. Eşikler sunucuda
  tanımlıdır ve oturum kaydıyla birlikte tutulur.
- Test atlandığında (`outcome == .skipped`) ya da sunucuya ulaşılamadığında kullanıcı engellenmez.
  Görüşmenin kendisi bağlantı sorununu ayrıca yakalar.
- Son koşunun ayrıntılı raporu `IdentifyManager.shared.lastSpeedTestReport` üzerindedir.

Hazırlık ekranının iki test için davranışı:

| Durum | Eski test | Yeni test |
|---|---|---|
| Ölçüm bitti, engel yok | Düğme "Devam Et" olur; bağlantı iyiyse başarı bandı çıkar | Aynı; `outcome == .failed` ise bant çıkmaz ama kullanıcı ilerler |
| Engel var | Yok (eski test engellemez) | Hata uyarısı: "Tekrar Dene" testi yeniden çalıştırır, düğme "Ölç ve Devam Et" olarak kalır |

---

## 4) Modülden önce ölçüm ekranı

Ölçümü hazırlık ekranına bağlamadan, istediğiniz modülün hemen önünde yapabilirsiniz. Akışa kendi
ekranınızı eklersiniz; ekran açılınca test çalışır, sunucu geçer derse kullanıcı modüle girer,
engellerse ekranda kalır. Bu yol hazırlık ekranını ve `useConnectionSpeedTest` ayarını
kullanmaz, akışta hazırlık modülü olmasa da çalışır.

Kullanılan iki API zaten flow özelleştirmesinin parçasıdır
([Özelleştirme, bölüm B](customization.md#b-araya-custom-ekran-ekleme)):

```swift
registry.custom("speedCheck") { SpeedCheckBeforeView() }       // ekranı kaydet
coordinator.insert(["speedCheck"], before: .callScreen)         // hangi modülün önüne
```

### 4.1) Ölçüm ekranı

```swift
import SwiftUI
import IdentifySDK

struct SpeedCheckBeforeView: View {

    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var isMeasuring = false
    @State private var isBlocked = false

    var body: some View {
        ZStack {
            IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: IDSpacing.xl) {
                Spacer()
                if isBlocked {
                    Text(String(.connectionErrorRetry))
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                } else {
                    ProgressView()
                }
                Spacer()
                if isBlocked {
                    SDKButton(title: String(.coreTryAgain), isLoading: isMeasuring, isDisabled: isMeasuring) {
                        measure()
                    }
                }
            }
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
            .sdkReadableWidth()
        }
        .onAppear(perform: measure)
        .onDisappear { IdentifyManager.shared.cancelConnectionSpeedTest() }
    }

    private func measure() {
        guard !isMeasuring else { return }
        isMeasuring = true
        IdentifyManager.shared.startConnectionSpeedTest { result in
            isMeasuring = false
            if result.blockIdent {
                isBlocked = true
            } else {
                coordinator.advanceExternal()   // modüle geç
            }
        }
    }
}
```

Ekranın akıştaki davranışı:

| Durum | Ne olur |
|---|---|
| Ekran açıldı | Test hemen başlar, yükleniyor göstergesi döner |
| `blockIdent == false` | `advanceExternal()` çağrılır, kullanıcı modüle girer |
| `outcome == .skipped` (sunucuya ulaşılamadı, test kapalı) | `blockIdent` `false` gelir, kullanıcı modüle girer |
| `blockIdent == true` | Hata metni ve "Tekrar Dene" düğmesi görünür; kullanıcı modüle giremez |
| Ekran kapandı | `cancelConnectionSpeedTest()` testi durdurur |

Görünümü markanıza göre değiştirebilirsiniz. Akış yalnızca iki çağrıya bakar:
`startConnectionSpeedTest` ve test geçince `advanceExternal()`.
`advanceExternal()`'ın neden ayrı bir metot olduğu ve ne zaman çağrılacağı:
[Özelleştirme, Ara ekrandan ilerlemek](customization.md#ara-ekrandan-ilerlemek-advanceexternal).

### 4.2) Senaryo: görüntülü görüşmeden önce

Müşteri, kullanıcının zayıf bağlantıyla görüşmeye bağlanmasını istemiyor. Belgeler ve selfie
alındıktan sonra, görüşmeye girmeden hemen önce bağlantı ölçülsün; sunucu yetersiz derse
kullanıcı görüşmeye alınmasın.

Panel tarafı: akışta görüntülü görüşme (`waitScreen`) var, örnek sıra
`prepare → idCard → selfie → waitScreen`. Hız testi eşikleri ve engelleme (`gateEnabled`)
sunucuda açılır.

Uygulama tarafı:

```swift
// 1) Akış başlamadan bir kez: ekranı kaydet ve görüşmenin önüne ekle.
registry.custom("speedCheck") { SpeedCheckBeforeView() }
coordinator.insert(["speedCheck"], before: .callScreen)

// 2) Oturum açılırken:
IdentifyManager.shared.setupSDK(identId: identId, baseApiUrl: baseApiUrl, ...) { socket, room, error in
    guard error == nil else { return }
    // İsteğe bağlı: hazırlık ekranı ikinci kez ölçmesin (bkz. aşağıdaki not).
    IdentifyManager.shared.needSpeedTest = false
    coordinator.start()
}
```

Kullanıcı şunları görür:

1. Hazırlık, kimlik ve selfie adımlarını her zamanki gibi tamamlar.
2. Selfie'den sonra ölçüm ekranı açılır, test birkaç saniye sürer.
3. Sunucu geçer derse ekran kendiliğinden kapanır ve görüşme ekranı açılır.
4. Sunucu engellerse ekranda hata metni ve "Tekrar Dene" kalır. Kullanıcı başka bir ağa geçip
   tekrar dener; test geçmeden görüşmeye ulaşamaz.

Sunucu tarafında sıra şöyle işler: ölçüm ekranı açıkken panel kullanıcıyı hâlâ selfie adımında
görür. Görüşme modülüne geçiş (bekleme odasına alınma dahil) ancak ekran `advanceExternal()`
çağırınca yapılır. Engellenen kullanıcı bu yüzden temsilci kuyruğuna hiç düşmez.

Akışta `waitScreen` olduğu için SDK `needSpeedTest = true` yapar, hazırlık ekranı da ölçüm
düğmesi gösterir. Ölçümü yalnızca görüşmeden önce yapmak istiyorsanız
`setupSDK` dönüşünde, `coordinator.start()` öncesinde `needSpeedTest = false` verin. Hazırlık
ekranı o zaman düz "Devam Et" gösterir ve sunucuya hazırlık sinyalini yine kendisi gönderir.

### 4.3) Diğer modüller

Aynı ekran her modülün önüne eklenebilir; yalnızca rota değişir:

| Panel modülü | Rota |
|---|---|
| `waitScreen` (görüntülü görüşme) | `.callScreen` |
| `nfc` | `.nfc` |
| `selfie` | `.selfie` |
| `selfieWithLiveness` | `.selfieWithLiveness` |
| `idCard` | `.idCard` |
| `idcard_w_ovd` | `.idCardOVD` |
| `livenessDetection` | `.liveness` |
| `videoRecord` | `.videoRecorder` |
| `speech` | `.speech` |
| `signature` | `.signature` |
| `addressConf` | `.addressConfirm` |
| `prepare` | `.prepare` |

```swift
// Birden fazla modülün önünde ölçmek: aynı ekran, her rota için ayrı kayıt.
coordinator.insert(["speedCheck"], before: .nfc)
coordinator.insert(["speedCheck"], before: .callScreen)

// Ölçümden önce bir bilgilendirme ekranı: dizideki sırayla gösterilir.
coordinator.insert(["networkInfo", "speedCheck"], before: .callScreen)
```

Akışta olmayan bir modülün önüne eklenen ekran hiç açılmaz. Panelde modül sırası değişse bile
ekran ait olduğu modülün önünde kalır.

### 4.4) Dikkat edilecekler

- `insert` çağrıları birikir. Akış başlamadan bir kez yapın (örnekte `RootView`'ın kurulum
  bloğu); her oturumda yeniden çağırırsanız ekran art arda iki kez açılır. Kayıtlar
  `resetFlow()` sonrasında da geçerlidir.
- Ölçüm ekranı adım sayacını ilerletmez ve ilerleme çubuğunda yer kaplamaz.
- WebRTC ölçümü kamera ve mikrofon izni ister, ölçüm ekranı izin istemez. Ekranı hazırlıktan
  önce, akışın ilk modülünün önüne koyarsanız izinler henüz verilmemiş olabilir; ping, indirme ve
  yükleme yine ölçülür, `rtcOutcome` `no_media_permission` gelir.
- Ölçüm ekranı `prepareCompleted()` göndermez; bu sinyal hazırlık ekranına aittir.
- Kullanıcıya akıştan çıkış sunmak isterseniz engel durumuna kendi düğmenizi ekleyin; SDK bu
  ekranda bir kapatma düğmesi çizmez.

Tam çalışan örnek: `IdentifySample/Modules/Prepare/SpeedCheckBeforeView.swift`. Bağlantısı
`IdentifySample/App/RootView.swift` içinde kapalı örnek olarak duruyor.

---

## 5) Hazırlık ekranında ölçmek

SDK'nın kendi hazırlık ekranı da ölçüm yapabilir. Ek ekran yazmak istemiyorsanız bu yol yeterli.
Panelde akışa hazırlık (`prepare`) ve görüntülü görüşme (`waitScreen`) modülleri
eklenir, hazırlık görüşmeden önce gelir. Hız testi eşikleri ve engelleme (`gateEnabled`)
sunucuda açılır.

Uygulamada tek satır yeterli:

```swift
// Giriş ekranı, setupSDK öncesi
IdentifyManager.shared.useConnectionSpeedTest = true

IdentifyManager.shared.setupSDK(identId: identId, baseApiUrl: baseApiUrl, ...) { socket, room, error in
    guard error == nil else { return }
    coordinator.start()
}
```

Kullanıcı şunları görür:

1. Hazırlık ekranında izinleri verir, listeyi işaretler.
2. "Bağlantı Kalitemi Ölç ve Devam Et" düğmesine dokunur; düğmede yükleniyor göstergesi döner.
3. Sunucu geçer derse başarı bandı çıkar ve düğme "Devam Et" olur. Dokununca akış kimlik adımına geçer.
4. Sunucu engellerse hata uyarısı çıkar. Kullanıcı başka bir ağa geçip "Tekrar Dene" diyebilir;
   test geçmeden görüşmeye ulaşamaz.

Sonucu kendi tarafınızda loglamak isterseniz hazırlık ekranını değiştirmeden ViewModel'i
izleyebilirsiniz:

```swift
registry.override(.prepare) {
    PrepareObservingView()
}

struct PrepareObservingView: View {
    @StateObject private var vm = SDKPrepareViewModel()

    var body: some View {
        SDKPrepareView(viewModel: vm)
            .onReceive(vm.$speedTestResult.compactMap { $0 }) { result in
                Analytics.log("kyc_speed_test", [
                    "block": result.blockIdent,
                    "outcome": result.outcome.rawValue,
                    "score": result.qualityScore ?? -1
                ])
            }
    }
}
```

---

## 6) Hazırlık ekranını kendiniz çizdiyseniz

`SDKPrepareViewModel` iki testi de kendi içinde seçer. Ekranınız `startSpeedTest()` çağırıyorsa
ayar açıldığında yeni test çalışır, çağrıyı değiştirmeniz gerekmez. Eklemeniz gereken tek şey
engel uyarısıdır:

```swift
.idAlert(isPresented: $viewModel.showSpeedBlockedAlert, alert: IDAlertModel(
    type: .error,
    title: String(.coreError),
    message: String(.connectionErrorRetry),
    actions: [
        IDAlertAction(title: String(.coreCancel), style: .cancel),
        IDAlertAction(title: String(.coreTryAgain), style: .primary) { viewModel.startSpeedTest() }
    ]
))
```

ViewModel'de yeni test için iki alan var:

| Alan | Tip | Açıklama |
|---|---|---|
| `speedTestResult` | `SDKSpeedTestResult?` | Son yeni test sonucu. Eski test çalıştıysa `nil`. |
| `showSpeedBlockedAlert` | `Bool` | Sunucu `blockIdent` döndürünce `true` olur. |

`speedCheckDone`, `connectionQuality` ve `measuredSpeed` iki testte de dolar. Engel durumunda
`speedCheckDone` `false` kalır.

Tam çalışan örnek: `IdentifySample/Modules/Prepare/PrepareCustomView.swift`.

---

## 7) Testi akış başlamadan çalıştırmak

Ölçümü ilk modülden bile önce, kendi giriş ekranınızda yapmak istiyorsanız metodu `setupSDK`
dönüşünde çağırın. Bu yol `useConnectionSpeedTest` ayarına bakmaz.

```swift
IdentifyManager.shared.setupSDK(identId: identId, baseApiUrl: baseApiUrl, ...) { socket, room, error in
    guard error == nil else { return }

    showLoading(true)
    IdentifyManager.shared.startConnectionSpeedTest { result in   // ana thread'de bir kez döner
        showLoading(false)
        if result.blockIdent {
            showMessage("Bağlantınız görüntülü görüşme için yetersiz. Başka bir ağ deneyin.")
            return
        }
        coordinator.start()
    }
}
```

- `setupSDK` sonrası çağrıldığında `identId` ve `baseApiUrl` verilmez; SDK oturumdakileri kullanır.
  SSL pinning de `setupSDK` ile kurulduğu için pinning açık entegrasyonlarda bu sıra zorunludur.
- `setupSDK` öncesi çağırmak mümkündür; o zaman iki parametre de verilmelidir:
  `startConnectionSpeedTest(identId: identId, baseApiUrl: baseApiUrl) { ... }`.
- Ekran kapanırsa testi durdurun. Bekleyen geri çağrı `skipped` sonucuyla bir kez döner:

```swift
IdentifyManager.shared.cancelConnectionSpeedTest()
```

- Yeni test `prepareCompleted()` çağırmaz. Hazırlık ekranı bunu kendisi yapar; kendi ekranınızda
  çalıştırırsanız sunucuya hazırlık sinyali göndermek sizin akışınıza kalır.

Eski test de yerinde duruyor ve aynı şekilde çağrılabilir:

```swift
IdentifyManager.shared.startSpeedTest { status, kbPerSec in
    // status: .good / .poor / .disConnected
}
```

---

## 8) Örnek uygulamada denemek

Giriş ekranında sağ üstteki menü → **Hız testi → Yeni hız testi**. Açıkken hazırlık ekranı yeni
testi, kapalıyken eski testi çalıştırır. Ayar cihazda saklanır.

Kodda karşılığı:

```swift
SDKDebugSettings.shared.connectionSpeedTest = true   // IdentifyManager.shared.useConnectionSpeedTest'i de ayarlar
```

`SDKDebugSettings` örnek uygulamanın deneme menüsü içindir. Kendi uygulamanızda
`IdentifyManager.shared.useConnectionSpeedTest` kullanın.

Görüşmeden önce ölçüm ekranını denemek için `IdentifySample/App/RootView.swift` içindeki
`speedCheck` satırlarını açın. Bu ekran menüdeki ayardan bağımsız çalışır.

---

## 9) Sık sorulanlar

- **Test ne kadar sürer?** Sunucudaki test ayarına ve bağlantıya göre değişir; `result.durationMs`
  ile görebilirsiniz.
- **Sunucuda test kapalıysa ne olur?** Sonuç `skipped` gelir, kullanıcı engellenmez.
- **Simülatörde çalışır mı?** Ping, indirme ve yükleme Mac'in bağlantısıyla ölçülür. WebRTC
  ölçümü simülatörde yapılmaz (`rtcOutcome == "unsupported"`); karar yine sunucudan gelir.
- **WebRTC ölçümü izin ister mi?** Kamera ve mikrofon izni verilmiş olmalı; test izin istemez.
  Hazırlık ekranında izinler testten önce alındığı için sorun olmaz. İzin yoksa
  `rtcOutcome == "no_media_permission"` olur, diğer ölçümler yine yapılır.
- **Eski teste geri dönmek?** `useConnectionSpeedTest = false`. Başka bir değişiklik gerekmez.
