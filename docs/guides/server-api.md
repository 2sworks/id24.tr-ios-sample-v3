# Sunucu & API — setupSDK ve Oda Yapısı

Bu rehber SDK'nın backend ile nasıl konuştuğunu anlatır: `setupSDK`'nın bütün parametreleri,
odaya bağlanınca dönen `RoomResponse`'un akışı nasıl belirlediği ve ağ ayarları (timeout, SSL
pinning).

← [README'ye dön](../../README.md) · İlgili: [Mimari](architecture.md) · [WebSocket](websocket.md)

---

## Büyük Resim

Bütün HTTP istekleri SDK içindeki `SDKNetwork` katmanından geçer (SDK'ya gömülü Alamofire).
Oturum tek bir çağrıyla başlar:

```
setupSDK(identId, baseApiUrl, ...) ──► POST connectToRoom(identId)
                                          │
                            RoomResponse ◄┘
                            ├─ modules[]        → hangi adımlar, hangi sırada
                            ├─ ws_url           → WebSocket adresi
                            ├─ socket_auth      → soket token zorunlu mu
                            ├─ *_comparison_count → deneme hakları
                            ├─ encrypted_turn_credential / short_term_usage → TURN modu
                            └─ sdk_log_api_url  → online log hedefi
```

Modüllerin sırasını backend belirler; akış `modules` dizisinde ne gelirse odur. `selectedModules`
parametresiyle bu modüllerin bir kısmını seçebilirsiniz. Boş bırakırsanız backend'in gönderdiği
sıra kullanılır.

---

## setupSDK — Tam Parametre Referansı

```swift
IdentifyManager.shared.setupSDK(
    identId: "...",
    baseApiUrl: "https://v2api.identify.com.tr/",
    networkOptions: SDKNetworkOptions(useSslPinning: false),
    kpsData: nil,
    signLangSupport: false,
    nfcMaxErrorCount: 3,
    selectedModules: [],
    turnKey: "...",
    wsSecretKey: "...",
    showThankYouPage: true
) { socket, roomResponse, error in ... }
```

| Parametre | Tip | Varsayılan | Ne işe yarar |
|---|---|---|---|
| `identId` | `String` | — | Müşteri işlem numarası; içindeki boşluklar silinir |
| `baseApiUrl` | `String` | — | Backend kök adresi |
| `networkOptions` | `SDKNetworkOptions` | — | Timeout ve SSL pinning (aşağıda) |
| `kpsData` | `SDKKpsData?` | — | NFC/BAC için kimlik verisi. `nil` ise veri sunucudan şifreli gelir (aşağıda) |
| `identCardType` | `[CardType]?` | `[.idCard, .passport, .oldSchool]` | Kabul edilen belge türleri |
| `signLangSupport` | `Bool` | — | Görüşmeden önce işaret dili sorusu gösterilsin mi |
| `nfcMaxErrorCount` | `Int` | — | NFC okuması kaç hatadan sonra bırakılır |
| `logLevel` | `SDKLogLevel?` | `.all` | Konsol ve online log ayarı → [Loglama](logging.md) |
| `logOnlineSecretKey` | `String?` | `""` | Online log imza anahtarı |
| `bigCustomerCam` | `Bool?` | `false` | Görüşmede müşterinin kamerası büyük gösterilsin mi |
| `selectedModules` | `[SdkModules]` | `[]` | Boşsa backend'in sırası, doluysa yalnızca bu modüller |
| `idCardLang` | `IDLang?` | `.TR` | OCR'a belgenin dilini söyler |
| `needCertForNfc` | `Bool?` | `false` | NFC'de sertifika zinciri doğrulansın mı |
| `turnKey` | `String` | — | TURN kimliklerinin anahtarı → [TURN & WebRTC](turn-webrtc.md) |
| `wsSecretKey` | `String?` | `nil` | `socket_auth` açıksa soket token anahtarı → [WebSocket](websocket.md) |
| `showThankYouPage` | `Bool?` | `true` | Akış sonunda SDK'nın sonuç ekranı gösterilsin mi. `false` verirseniz sonuç ekranı açılmaz, SDK aşağı kayarak kapanır ve sonuç `onFinished`'a gelir |
| `onFinished` | `((SDKFlowOutcome) -> Void)?` | `nil` | Oturum nasıl biterse bitsin tam bir kez çağrılır (3.1.0) |
| `showNFCNotFoundPage` | `Bool?` | `false` | Çipsiz belgede "NFC yok" ekranı gösterilsin mi |
| `supportU18` | `Bool?` | `false` | 18 yaş altı desteği |
| `AESKey` | `String?` | `""` | Sunucudan şifreli gelen MRZ alanlarını çözen anahtar |
| `enableAutoRotateOCR` | `Bool?` | `false` | Yamuk çekilmiş kimlik fotoğrafı düzeltilsin mi |
| `ttsEnabled` | `Bool?` | `false` | Sesli okumayı açmanın kısa yolu (`defaultMode .off` ise `.native` yapar) |
| `callback` | closure | — | `(WebSocket?, RoomResponse, SDKWebError?)` |

### Callback'te başarı kontrolü

```swift
{ socket, roomResponse, error in
    Task { @MainActor in
        if error == nil, socket?.isConnected == true, roomResponse.result == true {
            coordinator.start()
        } else {
            // error?.message kullanıcıya gösterilebilir metin içerir
        }
    }
}
```

---

## RoomResponse — Akışı Şekillendiren Alanlar

`connectToRoom` cevabındaki önemli alanlar ve ne işe yaradıkları:

| Alan | Etki |
|---|---|
| `modules` | Modüllerin sırası; akış bu listeye göre kurulur |
| `ws_url` | Soket adresi |
| `ws_secret_key` | STUN/TURN kimlik servisinin anahtarı |
| `socket_auth` | `"1"` ise soket bağlantısına HMAC token eklenir |
| `nfc/selfie/ocr_comparison_count` | Her modülün deneme hakkı. Hak bitince modül atlanabilir |
| `active_comparison_result_skip_module` | Aktif karşılaştırma sonucuna göre modül atlama |
| `encrypted_turn_credential`, `short_term_usage` | TURN kimlik modu → [TURN & WebRTC](turn-webrtc.md) |
| `liveness`, `liveness_recording`, `liveness_report*` | Canlılık adımlarının sırası, kayıt ve rapor ayarları |
| `video_record_speech*`, `speech_expected_sentence`, `video_record_duration` | Kısa videoda sesli okuma doğrulaması. `video_record_duration` milisaniye cinsinden (6000 = 6 sn). Doğrulama okunacak metne göre açılır: `video_record_read_text` (yoksa `speech_expected_sentence`) doluysa açık, boşsa kapalıdır. `video_record_speech` bayrağı bunu değiştirmez |
| `agent_view_scale` | Görüşmede agent görüntüsünün oranı |
| `hide_call_answer_screen` | Çağrı cevaplama ekranını gizler |
| `request_max_body_size` | Yükleme boyutu sınırı (sunucu belirler) |
| `sdk_log_api_url` | Online logların gönderildiği adres |

### Şifreli MRZ verisi (kpsData yerine)

`kpsData: nil` verirseniz NFC için gereken üç MRZ alanını (doğum tarihi, seri no, son geçerlilik
tarihi) backend AES-256-CBC ile şifreli gönderir ve SDK bunları `AESKey` ile çözer. Yani NFC'ye
veriyi siz de verebilirsiniz, sunucu da.

---

## SDKNetworkOptions — Ağ Ayarları

```swift
// Basit kullanım
SDKNetworkOptions(useSslPinning: false)

// Tam kontrol
SDKNetworkOptions(
    timeoutIntervalForRequest: 30,      // saniye
    timeoutIntervalForResource: 30,
    useSslPinning: true,
    sslPinningBundles: [Bundle(for: MySDKToken.self)]  // ara katman SDK'ları için
)
```

### SSL Pinning nasıl çalışır

`useSslPinning: true` olduğunda SDK `.cer` uzantılı sertifikaları şu sırayla arar:

1. `sslPinningBundles` ile verdiğiniz bundle'lar (ör. bankanın kendi ara SDK'sı)
2. IdentifySDK'nın kendi bundle'ı
3. Uygulamanın main bundle'ı

Sertifikanızı bunlardan birine koymanız yeterli. Sample App'te örnek bir sertifika var.

---

## Hata Modeli

HTTP hataları `SDKWebError` olarak döner; `message` alanını kullanıcıya gösterebilirsiniz. Sunucu
`result == false` döndürürse mesaj `RoomResponse.messages` listesinden alınır. Modül içindeki
yüklemelerde VM'ler hatayı `errorMessage`'a yazar; kendi ekranınızda
`@Published errorMessage`'ı dinlemeniz yeterli.

---

## İlgili Rehberler

- [WebSocket yapısı](websocket.md): `ws_url`, `socket_auth`, yeniden bağlanma
- [TURN & WebRTC](turn-webrtc.md): kimlik servisleri
- [Loglama](logging.md): `sdk_log_api_url` ve online log
