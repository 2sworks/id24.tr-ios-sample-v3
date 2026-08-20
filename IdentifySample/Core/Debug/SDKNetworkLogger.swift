//
//  SDKNetworkLogger.swift
//  IdentifySample
//

import Foundation
import UIKit

// MARK: - NFXDebugState

final class NFXDebugState: ObservableObject {
    static let shared = NFXDebugState()

    /// Anahtarın diskteki karşılığı. Diğer geliştirici ayarlarıyla aynı adlandırma.
    private static let storageKey = "sdkNetworkDebugEnabled"

    /// Login ekranındaki "Network Debug (Netfox)" anahtarı. Açıldığında log paneli
    /// kurulur, kapatıldığında tüm katmanlar sökülür.
    ///
    /// Değer `UserDefaults`'ta saklanır; uygulama yeniden açıldığında anahtar bırakıldığı
    /// yerden devam eder.
    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            UserDefaults.standard.set(isEnabled, forKey: Self.storageKey)
            SDKLogPanel.setEnabled(isEnabled)
        }
    }

    private init() {
        // init içindeki atama `didSet` tetiklemez; paneli AppDelegate kuruyor.
        isEnabled = UserDefaults.standard.bool(forKey: Self.storageKey)
    }
}

// MARK: - SDKWindow

class SDKWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake, NFXDebugState.shared.isEnabled else { return }
        NotificationCenter.default.post(name: .sdkNetworkDebugShake, object: nil)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let sdkNetworkDebugShake = Notification.Name("SDKNetworkDebugShake")
}
