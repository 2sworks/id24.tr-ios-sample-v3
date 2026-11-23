//
//  IdScanAlert.swift
//  IdentifySample
//
//  Kimlik taraması belirlenen süreyi aşınca uygulamanın kendi uyarı penceresini açması.
//  "iOS SDK 3.2.1 Kimlik Taramasında Uyarı Penceresi" kılavuzunun örneği.
//
//  1) IdScanAlert: SDK'nın kimlik ekranıyla. Süre onGuidance ile tutulur, pencere tarayıcının üstünde açılır.
//  2) IdScanScreen: kendi tarama ekranınızla (IdentityScannerView, pausesDetection).
//
//  Kılavuzdaki UIAlertController yerine pencere SDK'nın uyarı bileşeniyle (`idAlert`) çizilir.
//

import SwiftUI
import UIKit
import IdentifySDK

// MARK: - 1) SDK'nın kimlik ekranıyla

/// Ayarlar menüsündeki "Kimlik Taramasında Uyarı" anahtarı bu sınıfı açar ve kapatır.
/// Açıkken `onGuidance` kurulur; kapalıyken kapanış kaldırılır.
@MainActor
final class IdScanAlert {

    static let shared = IdScanAlert()

    /// Diskteki anahtar; arayüzdeki `@AppStorage` aynı değeri kullanır.
    static let storageKey = "idScanAlertEnabled"

    /// Pencerenin açılacağı süre (saniye).
    var timeout: TimeInterval = 10

    private var timer: Task<Void, Never>?
    private weak var scanScreen: UIViewController?
    private weak var alertController: UIViewController?

    /// Kayıtlı tercihi SDK'ya işler. Uygulama açılışında ve anahtar değişince çağrılır.
    static func apply() {
        if UserDefaults.standard.bool(forKey: storageKey) {
            shared.install()
        } else {
            shared.uninstall()
        }
    }

    /// SDK akışını başlatmadan önce bir kez çağrılır.
    /// `onGuidance` tek kapanış tutar: başka amaçla da kullanılıyorsa iki iş aynı kapanışta yapılır.
    func install() {
        SDKErrorConfig.shared.onGuidance = { info in
            // SDK bu kapanışı ana kuyrukta çağırır.
            MainActor.assumeIsolated {
                guard info.module == .idCard, let state = info.state else { return }
                IdScanAlert.shared.handle(state)
            }
        }
    }

    func uninstall() {
        SDKErrorConfig.shared.onGuidance = nil
        stop()
    }

    private func handle(_ state: String) {
        if alertController == nil { scanScreen = Self.topViewController() }
        switch state {
        case "preparing":   // tarayıcı açıldı
            startTimer()
        case "locked":      // fotoğraf çekildi
            stop()
        default:
            break
        }
    }

    private func stop() {
        timer?.cancel()
        timer = nil
        alertController?.dismiss(animated: false)
    }

    private func startTimer() {
        timer?.cancel()
        let seconds = timeout
        timer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.showAlert()
        }
    }

    private func showAlert() {
        // Pencere yalnız tarama ekranı en üstteyken onun üstünde açılır.
        guard alertController == nil, let screen = scanScreen, screen === Self.topViewController() else { return }
        let model = IDAlertModel(
            type: .error,
            title: "Kimlik Doğrulanamadı",
            message: "Kimliğinin üzerinde parlama veya gölge olmadığından "
                + "ve bilgilerin net bir şekilde göründüğünden emin ol.",
            actions: [IDAlertAction(title: "Tekrar Dene") { [weak self] in
                self?.alertController?.dismiss(animated: false)
                self?.startTimer()
            }]
        )
        let host = UIHostingController(rootView: IdScanAlertOverlay(model: model))
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        alertController = host
        screen.present(host, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Tarayıcının üstüne saydam bir katman açar ve SDK'nın uyarı bileşenini gösterir.
private struct IdScanAlertOverlay: View {
    @State var model: IDAlertModel?

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .idAlert(item: $model)
    }
}

// MARK: - 2) Kendi tarama ekranınızla

/// Kimlik ekranı `SDKViewRegistry` ile değiştirildiyse süre ve pencere bu ekranda yönetilir.
/// `pausesDetection` true iken kamera açık kalır ve tarama bekler; false olunca tarama baştan başlar.
/// Profil `.turkishIDFront` ya da `.turkishIDBack` verilir.
struct IdScanScreen: View {
    let profile: DocumentProfile
    let onDocument: (RecognizedDocument) -> Void

    @State private var paused = false
    @State private var showAlert = false
    @State private var attempt = 0
    @State private var captured = false

    var body: some View {
        IdentityScannerView(profile: profile, pausesDetection: paused) { result in
            if case .success(let document) = result {
                captured = true
                onDocument(document)
            }
        }
        .task(id: attempt) {
            try? await Task.sleep(nanoseconds: 10_000_000_000)     // 10 saniye
            guard !Task.isCancelled, !captured else { return }
            paused = true
            showAlert = true
        }
        .idAlert(isPresented: $showAlert, alert: IDAlertModel(
            type: .error,
            title: "Kimlik Doğrulanamadı",
            message: "Kimliğinin üzerinde parlama veya gölge olmadığından "
                + "ve bilgilerin net bir şekilde göründüğünden emin ol.",
            actions: [IDAlertAction(title: "Tekrar Dene") {
                paused = false
                attempt += 1
            }]
        ))
    }
}
