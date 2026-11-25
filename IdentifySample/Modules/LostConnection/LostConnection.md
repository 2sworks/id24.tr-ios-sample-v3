# LostConnection — Bağlantı Koptu Ekranı

İnternet ya da soket bağlantısı koptuğunda kullanıcıyı karşılayan kurtarma ekranı. Bağımsız
bir akış modülü değildir — kullanıcı **hangi modülde olursa olsun** devreye girebilen bir
overlay'dir. Amaç basit: paniği önle, yeniden bağlan, kullanıcıyı **kaldığı modülden** devam ettir.

Kopmanın nasıl tespit edildiği ve reconnect'in perde arkası için:
[WebSocket → Bağlantı Kopması](../../../docs/guides/websocket.md#bağlantı-kopması-ve-toparlanma)

← [Modül İndeksi](../Modules.md) · [README](../../../README.md)

---

## Bir Bakışta

| | |
|---|---|
| Backend key | — (overlay; ayrı rota yok) |
| Tetikleyici | Global `.connectionErr` yayını (reachability veya soket kopması) / `SDKCallScreenViewModel.showLostConnection` |
| Drop-in view | `SDKLostConnectionView` |
| ViewModel | `SDKLostConnectionViewModel` |
| Dış dünya | **Soket** reconnect (`manager.reconnectToSocket`) |

## Kullanıcı Ne Yaşar?

1. Bağlantı gider; ekranda "Bağlantı koptu" overlay'i belirir.
2. Ağ yoksa düğmede "İnternet Yok" yazar (`isNetworkAvailable` izlenir). Düğme ağa göre
   kilitlenmez; yalnız bir deneme sürerken pasiftir.
3. Butona basınca reconnect denenir; başarıda overlay kapanır. Görüşme dışındaki modül
   baştan başlar, görüşme ekranındaki kullanıcı bekleme odasına döner.
4. Kopma görüşme sırasındaysa ve temsilci bu arada olumlu karar girdiyse, kullanıcı doğrudan
   sonuç ekranına taşınır.

---

## Kullanım

```swift
// Drop-in (overlay olarak)
if vm.showLostConnection {
    SDKLostConnectionView()
}
```

DefaultUI kullanıyorsanız bunun için kod yazmanız gerekmez — global `.connectionErr`
yayını overlay'i otomatik tetikler.

## Kendi Tasarımınızla

> **Çalışan tam örnek:** [LostConnectionCustomView.swift](LostConnectionCustomView.swift) — SDK ekranının yalnızca public API ile yazılmış birebir karşılığı. Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır. Bu ekran bir rota değildir; özel görüşme ekranı ([CallScreenCustomView.swift](../CallScreen/CallScreenCustomView.swift)) içinden açılır.
>
> Paylaşılan parçalar (kamera önizlemesi, video görünümü, banner) [CustomKit](../CustomKit/) klasöründedir. Örnek uygulamada hamburger menü → **Modül Özelleştirme → Tam Özel Ekranlar** ile açılıp kapatılır.


```swift
struct MyLostConnectionView: View {
    @StateObject private var vm = SDKLostConnectionViewModel()

    var body: some View {
        VStack {
            Text(vm.isNetworkAvailable ? "Bağlantı koptu" : "İnternet bağlantınız yok")
            if vm.isReconnecting { ProgressView() }
            Button("Yeniden bağlan") { vm.reconnect() }       // ✅ reconnectToSocket
                .disabled(!vm.canReconnect)
        }
        .onAppear {
            vm.onReconnectCompleted = { /* overlay'i kapat */ }
            vm.onReconnectCompletedWithStatus = { isWaitingRoom, statusType in
                /* isWaitingRoom false ise panel olumlu karar vermiştir: sonuç ekranına geç */
            }
            vm.startAutoRetry()     // SDKAttemptLimits.shared.connection izin veriyorsa kendisi dener
        }
        .onDisappear { vm.stopAutoRetry() }
    }
}
```

---

## ViewModel Referansı — `SDKLostConnectionViewModel`

### State (`@Published`, salt-okunur)
| Üye | Tip | Anlam |
|---|---|---|
| `isReconnecting` | `Bool` | Yeniden bağlanma sürüyor mu |
| `isNetworkAvailable` | `Bool` | Cihazın ağ erişimi var mı |

### Hesaplanan
| Üye | Anlam |
|---|---|
| `canReconnect: Bool` | Denenebilir mi (deneme sürmüyorsa `true`; ağ durumuna bakmaz) |

### Metotlar
| Metot | Etki |
|---|---|
| `reconnect()` | Soketi yeniden bağlar (`manager.reconnectToSocket`) |
| `startAutoRetry()` | Kullanıcı dokunmadan, `SDKAttemptLimits.shared.connection` ayarındaki sayı ve aralıkla dener (`autoReconnectAttempts` varsayılanı 0: kapalı) |
| `stopAutoRetry()` | Otomatik denemeyi durdurur (ekran kapanırken) |

### Closure'lar
| Üye | Ne zaman |
|---|---|
| `onReconnectCompleted: (() -> Void)?` | Soket yeniden bağlandı (önce bu gelir) |
| `onReconnectCompletedWithStatus: ((Bool, String?) -> Void)?` | Panelin statü yanıtı geldi: `(isWaitingRoom, statusType)`. `isWaitingRoom` `false` ise panel olumlu karar vermiştir, oturum biter |

## Sinyal Zinciri — Perde Arkası

```
(internet gitti / soket koptu) → .connectionErr (tek sefer) → overlay görünür
reconnect()  → manager.reconnectToSocket [SOKET]
   ├─ socket_auth aktifse yeni token üretilir
   ├─ bağlandı                  → onReconnectCompleted?()
   └─ panel statüsü geldi       → onReconnectCompletedWithStatus?(isWaitingRoom, statusType)
coordinator: overlay kapanır, aktif modül baştan başlar (restartCurrentModule)
CallScreen:  bekleme odasına döner; isWaitingRoom == false ise ThankYou açılır
```

CallScreen tarafında bu closure'lar `handleReconnectCompleted()` /
`handleReconnectCompletedWithStatus(...)` metotlarına bağlanır.

---

## Sesli Okuma (Read-Aloud)

Bu ekran bir **overlay**'dir ve akış rotası olmadığından **otomatik sesli okuma uygulanmaz.**
Gerekirse elle okutun:

```swift
SDKSpeechService.shared.speak(text: "Bağlantınız koptu, lütfen yeniden bağlanın.")
SDKSpeechService.shared.stop()
```

Genel bilgi: [ReadAloud](../ReadAloud.md)

## Sık Sorulanlar & Dikkat Edilecekler

- **"Yeniden bağlan" hep pasif:** Düğme yalnız deneme sürerken (`isReconnecting`) pasiftir,
  ağ durumuna bakmaz. Ağ yoksa (`isNetworkAvailable == false`) kullanıcıyı Wi-Fi/hücresel
  ayarlarına yönlendirin.
- **Reconnect ile ne geri gelir?** Soket bağlantısı ve oda aboneliği. Akışta bekleme odası
  modülü varsa ve işaret dili sorusu beklenmiyorsa SDK WebRTC'yi yeniden hazırlar ve adım
  bilgisini (`stepChanged`) yeniden gönderir. Kopmadan önceki görüşme bitmiştir; yeni görüşme
  yeni bir çağrıyla başlar.
- **Sürekli başarısızsa:** SDK kendiliğinden vazgeçmez; ekran açık kalır, kullanıcı yeniden
  dener. Başarısız denemeler sayılmaz. Oturumdaki kopma sayısına sınır
  `SDKAttemptLimits.shared.connection` (`SDKConnectionPolicy`) ile konur: `maxDrops` dolunca
  `onExceeded: .exit` akışı bitirir. Yeni oturum için `setupSDK` yeniden çağrılır.
- **Overlay her modülde çıkar mı?** Evet — kopma tespiti globaldir (reachability + soket);
  KYC tamamlandıktan sonra tetiklenmez. Görüşme medyası ayaktayken yalnız sinyal koparsa
  ekran hemen açılmaz; sinyal `signallessCallGracePeriod` (varsayılan 10 sn) içinde dönmezse açılır.
