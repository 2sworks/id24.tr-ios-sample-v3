//
//  SDKLogPanel.swift
//  IdentifySample
//
//  netfox panelinin kurulumu: HTTP, konsol ve WebSocket logları tek yerde.
//

import Foundation
import UIKit
import netfox
import IdentifySDK

/// Login ekranındaki "Network Debug (Netfox)" anahtarına bağlı log paneli.
///
/// Panel sallayarak açılır ve üç sekme taşır:
/// - **Network**: netfox'un kendi `URLSession` kaydı.
/// - **Console**: yakalanan `stdout`/`stderr` satırları ile SDK'nın yapısal log akışı.
/// - **Socket**: `IdentifyManager.getSocketLogs()` üzerinden WebSocket trafiği.
///
/// Anahtar kapalıyken hiçbir katman kurulmaz: istek kaydı tutulmaz, konsol
/// yakalanmaz, SDK'nın log akışı dinlenmez.
enum SDKLogPanel {

    private static var requestsEnabled = true
    private static var consoleEnabled = true
    private static var socketEnabled = true
    private static var isRunning = false

    /// Panelin hangi sekmeleri taşıyacağını belirler. Anahtar açılmadan önce
    /// çağrılmalıdır; varsayılan olarak üç sekme de açıktır.
    static func configure(requests: Bool = true, console: Bool = true, socket: Bool = true) {
        requestsEnabled = requests
        consoleEnabled = console
        socketEnabled = socket
    }

    /// Login ekranındaki anahtarın durumunu panele uygular.
    static func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private static func start() {
        guard !isRunning else { return }
        isRunning = true

        NFX.sharedInstance().isRequestsTabEnabled = requestsEnabled
        NFX.sharedInstance().isConsoleTabEnabled = consoleEnabled
        NFX.sharedInstance().isExternalTabEnabled = socketEnabled

        // Konsol yakalama netfox'tan önce açılır; netfox'un kendi başlangıç
        // satırları da panele düşsün.
        if consoleEnabled {
            NFX.sharedInstance().startConsoleCapture()
        }
        if socketEnabled {
            NFX.sharedInstance().externalLogSource = socketLogSource()
        }
        NFX.sharedInstance().start()

        if consoleEnabled {
            bindSDKLogHandler()
        }
    }

    private static func stop() {
        guard isRunning else { return }
        isRunning = false

        IdentifyManager.shared.logHandler = nil
        NFX.sharedInstance().stopConsoleCapture()
        NFX.sharedInstance().externalLogSource = nil
        NFX.sharedInstance().stop()
    }

    /// SDK'nın yapısal log akışını konsol sekmesine bağlar.
    ///
    /// Aynı satır `stdout` üzerinden de yakalanır; `NFXLogStore` yinelenen kaydı
    /// eler ve kategori bilgisi taşıyan yapısal olanı tutar.
    private static func bindSDKLogHandler() {
        IdentifyManager.shared.logHandler = { entry in
            NFX.sharedInstance().log(entry.message, type: entry.type)
        }
    }

    /// WebSocket kayıtlarını panelin anlayacağı biçime çevirir.
    private static func socketLogSource() -> NFXExternalLogSource {
        return NFXExternalLogSource(title: "Socket") {
            IdentifyManager.shared.getSocketLogs().map { log in
                let isIncoming = log.socketType == .incoming
                return NFXExternalLogEntry(
                    label: isIncoming ? "IN" : "OUT",
                    message: log.socketMsg ?? "",
                    tint: isIncoming
                        ? UIColor(red: 0.30, green: 0.62, blue: 0.95, alpha: 1.0)
                        : UIColor(red: 0.95, green: 0.60, blue: 0.20, alpha: 1.0)
                )
            }
        }
    }
}
