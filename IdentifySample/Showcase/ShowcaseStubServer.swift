//
//  ShowcaseStubServer.swift
//  IdentifySample
//
//  Showcase için yerel dummy API sunucusu.
//
//  Sorun: showcase'te `setupSDK` çalışmadığı için `SDKNetwork.shared.BASE_URL` boştur.
//  Modüller yükleme yapmaya kalkınca istek adresi "mobile/upload" gibi şemasız bir metin
//  oluyor ve URLSession `unsupported URL` (-1002) hatası veriyor; ekranda "yükleme
//  başarısız" görünüyordu — yani çekim sonrası hiçbir modül tamamlanamıyordu.
//
//  Çözüm: uygulamanın içinde 127.0.0.1 üzerinde küçük bir HTTP sunucusu açıp SDK'nın istek
//  adresini ona çeviriyoruz. Gerçek sunucu sözleşmesiyle aynı alanları taşıyan sabit (dummy)
//  JSON yanıtlar döndüğü için modüller uçtan uca tamamlanabiliyor.
//
//  Kapsam: SDK'ya dokunulmaz. `SDKNetwork.shared` internal olduğundan adres doğrudan
//  yazılamaz; tek public yol `setupSDK`'dır — ayrıntı `bindBaseURL()` yorumunda. Katalog
//  kapanınca sunucu durur; adres bir sonraki GERÇEK `setupSDK` çağrısında zaten yeniden
//  atanır (giriş ekranı her oturumda çağırıyor).
//

import Foundation
import Network
import IdentifySDK

// MARK: - ShowcaseStubServer

/// Showcase açıkken çalışan yerel dummy API.
@MainActor
final class ShowcaseStubServer {

    static let shared = ShowcaseStubServer()

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "showcase.stub.server")

    /// Sunucu çalışıyor mu.
    var isRunning: Bool { listener != nil }

    /// Dinlenen adres (tanılama için).
    private(set) var baseURL: String = ""

    private init() {}

    // MARK: Başlat / durdur

    /// Sunucuyu açar ve SDK'nın BASE_URL'ini ona çevirir.
    func start() {
        guard listener == nil else {
            print("[ShowcaseStub] Zaten çalışıyor: \(baseURL)")
            return
        }
        print("[ShowcaseStub] Sunucu açılıyor…")

        do {
            // Port 0: işletim sistemi boş bir port verir, sabit port çakışması olmaz.
            let listener = try NWListener(using: .tcp, on: .any)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                print("[ShowcaseStub] Dinleyici durumu: \(state)")
                guard case .ready = state else { return }
                Task { @MainActor in
                    self?.bindBaseURL()
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            print("[ShowcaseStub] Sunucu açılamadı: \(error.localizedDescription)")
        }
    }

    /// SDK'nın istek adresini dinlenen porta çevirir.
    ///
    /// `SDKNetwork.shared` internal olduğundan BASE_URL'e doğrudan yazılamaz; adresi
    /// ayarlamanın tek public yolu `setupSDK`'dır. `setupSDK` BASE_URL'i **ilk satırlarda**
    /// atar, oda isteğini ise sonra yapar — bu yüzden oda isteği başarısız olsa bile adres
    /// yerine oturur. Dummy sunucu oda isteğine bilinçli olarak `result: false` döner:
    /// böylece SDK socket/WebRTC kurmaya hiç girişmez, yalnız HTTP adresi bizde kalır.
    private func bindBaseURL() {
        guard let port = listener?.port?.rawValue else { return }
        baseURL = "http://127.0.0.1:\(port)/"

        print("[ShowcaseStub] Dummy API adresi: \(baseURL)")
        IdentifyManager.shared.setupSDK(
            identId: "showcase-dummy-session",
            baseApiUrl: baseURL,
            networkOptions: SDKNetworkOptions(timeoutIntervalForRequest: 10,
                                             timeoutIntervalForResource: 10,
                                             useSslPinning: false),
            kpsData: nil,
            signLangSupport: false,
            nfcMaxErrorCount: 5,
            logLevel: .all,
            turnKey: "showcase",
            callback: { _, _, err in
                // Oda isteğinin başarısız olması beklenir; adres zaten atandı.
                print("[ShowcaseStub] Dummy oturum yanıtı (beklenen hata): \(err?.errorMessages ?? "-")")
            }
        )
    }

    /// Sunucuyu kapatır ve BASE_URL'i geri yükler.
    func stop() {
        listener?.cancel()
        listener = nil
        baseURL = ""
    }

    // MARK: Bağlantı

    nonisolated private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    /// İstek tamamlanana kadar okur: başlıklar bitince `Content-Length` kadar gövde beklenir.
    nonisolated private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if error != nil {
                connection.cancel()
                return
            }

            if let request = HTTPRequest(buffer: buffer) {
                self.respond(to: request, on: connection)
                return
            }

            if isComplete {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buffer)
        }
    }

    nonisolated private func respond(to request: HTTPRequest, on connection: NWConnection) {
        let body = Self.response(for: request.path)
        var head = "HTTP/1.1 200 OK\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"

        var payload = Data(head.utf8)
        payload.append(body)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
        print("[ShowcaseStub] \(request.method) \(request.path) → 200")
    }

    // MARK: Dummy yanıtlar

    /// Yola göre sabit yanıt. Tanınmayan yol için genel başarı döner.
    ///
    /// Gerçek sunucu sözleşmesiyle aynı ALANLARI taşır; değerler sabittir. Yeni bir uç
    /// eklemek gerekirse buraya bir satır eklenir.
    nonisolated static func response(for path: String) -> Data {
        let json: String

        switch true {
        // Sesli okuma doğrulaması: eşleşti kabul edilir.
        case path.contains("speech/transcribe"):
            json = #"{"text":"kendi rızamla kimliğimi onaylıyorum","match":true,"score":0.94}"#

        // Yükleme uçları (selfie, kimlik, canlılık karesi, adres, video):
        // `data.comparison = true` → karşılaştırma kapısı geçer.
        case path.contains("mobile/upload"), path.contains("mobile/uploadVideo5Sec"):
            json = #"{"result":true,"messages":[],"data":{"comparison":true}}"#

        // NFC doğrulama ve anahtar güncelleme.
        case path.contains("mobile/nfc_verify"),
             path.contains("mobile/updateNFCReadKeys"),
             path.contains("mobile/setDocType"),
             path.contains("mobile/mrz_info"):
            json = #"{"result":true,"messages":[],"data":{"comparison":true}}"#

        // SMS/TAN doğrulama.
        case path.contains("mobile/verifyTan"):
            json = #"{"result":true,"messages":[]}"#

        // Oda isteği (oturum açılışı): BİLEREK başarısız.
        //
        // Başarılı dönseydi SDK WebSocket ve WebRTC kurmaya çalışır, bağlanamayınca
        // showcase'te bağlantı koptu ekranını açardı. Tek ihtiyacımız HTTP adresinin
        // atanması; oturum kurulması değil.
        case path.contains("mobile/getIdentDetails"):
            json = #"{"result":false,"messages":["Showcase dummy oturumu — oda açılmaz"]}"#

        // Log yükleme — sessizce yut.
        case path.contains("sdk_logs"), path.contains("logs/ingest"):
            json = #"{"result":true}"#

        default:
            json = #"{"result":true,"messages":[]}"#
        }
        return Data(json.utf8)
    }
}

// MARK: - Asgari HTTP istek çözümleyici

/// Yalnız yol ve metot gerekiyor; gövde okunur ama kullanılmaz.
private struct HTTPRequest {
    let method: String
    let path: String

    /// Tampon tam bir istek içeriyorsa çözer, yetmiyorsa `nil` döner.
    init?(buffer: Data) {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let header = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8) else { return nil }

        let lines = header.components(separatedBy: "\r\n")
        let parts = lines.first?.components(separatedBy: " ") ?? []
        guard parts.count >= 2 else { return nil }

        // Gövde tamamlanmadıysa bekle: eksik gövdeyle yanıt verirsek istemci bağlantıyı
        // yarıda kopmuş sayıyor.
        let contentLength = lines
            .first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "") } ?? 0
        let bodyCount = buffer.count - headerEnd.upperBound
        if bodyCount < contentLength { return nil }

        self.method = parts[0]
        self.path = parts[1]
    }
}
