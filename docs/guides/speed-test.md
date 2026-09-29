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
4. [Senaryo: görüntülü görüşmeden önce hız testi](#4-senaryo-görüntülü-görüşmeden-önce-hız-testi)
5. [Hazırlık ekranını kendiniz çizdiyseniz](#5-hazırlık-ekranını-kendiniz-çizdiyseniz)
6. [Testi SDK ekranları dışında çalıştırmak](#6-testi-sdk-ekranları-dışında-çalıştırmak)
7. [Örnek uygulamada denemek](#7-örnek-uygulamada-denemek)
8. [Sık sorulanlar](#8-sık-sorulanlar)

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
ekranı yoksa test hiç çalışmaz. Bu durumda testi kendiniz çağırabilirsiniz, bkz.
[bölüm 6](#6-testi-sdk-ekranları-dışında-çalıştırmak).

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

## 4) Senaryo: görüntülü görüşmeden önce hız testi

Müşteri, kullanıcının zayıf bağlantıyla görüşmeye bağlanmasını istemiyor. Görüşme
başlamadan bağlantı ölçülsün, sunucu yetersiz derse kullanıcı ilerlemesin.

Panelde akışa hazırlık (`prepare`) ve görüntülü görüşme (`waitScreen`) modülleri
eklenir, hazırlık görüşmeden önce gelir. Örnek sıra: `prepare → idCard → selfie → waitScreen`.
Hız testi eşikleri ve engelleme (`gateEnabled`) sunucuda açılır.

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

## 5) Hazırlık ekranını kendiniz çizdiyseniz

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

## 6) Testi SDK ekranları dışında çalıştırmak

Akışta hazırlık ekranı yoksa ya da ölçümü akış başlamadan kendi ekranınızda yapmak istiyorsanız
metodu doğrudan çağırın. Bu yol `useConnectionSpeedTest` ayarına bakmaz.

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

## 7) Örnek uygulamada denemek

Giriş ekranında sağ üstteki menü → **Hız testi → Yeni hız testi**. Açıkken hazırlık ekranı yeni
testi, kapalıyken eski testi çalıştırır. Ayar cihazda saklanır.

Kodda karşılığı:

```swift
SDKDebugSettings.shared.connectionSpeedTest = true   // IdentifyManager.shared.useConnectionSpeedTest'i de ayarlar
```

`SDKDebugSettings` örnek uygulamanın deneme menüsü içindir. Kendi uygulamanızda
`IdentifyManager.shared.useConnectionSpeedTest` kullanın.

---

## 8) Sık sorulanlar

- **Test ne kadar sürer?** Sunucudaki test ayarına ve bağlantıya göre değişir; `result.durationMs`
  ile görebilirsiniz.
- **Sunucuda test kapalıysa ne olur?** Sonuç `skipped` gelir, kullanıcı engellenmez.
- **Simülatörde çalışır mı?** Ping, indirme ve yükleme Mac'in bağlantısıyla ölçülür. WebRTC
  ölçümü simülatörde yapılmaz (`rtcOutcome == "unsupported"`); karar yine sunucudan gelir.
- **WebRTC ölçümü izin ister mi?** Kamera ve mikrofon izni verilmiş olmalı; test izin istemez.
  Hazırlık ekranında izinler testten önce alındığı için sorun olmaz. İzin yoksa
  `rtcOutcome == "no_media_permission"` olur, diğer ölçümler yine yapılır.
- **Eski teste geri dönmek?** `useConnectionSpeedTest = false`. Başka bir değişiklik gerekmez.
