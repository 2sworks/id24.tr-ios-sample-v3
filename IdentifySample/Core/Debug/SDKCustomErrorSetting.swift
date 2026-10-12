//
//  SDKCustomErrorSetting.swift
//  IdentifySample
//
//  SDK hatalarını host'un kendi gösterimiyle sunma örneği (`SDKErrorConfig.presentation = .custom`).
//
//  Anahtar açıkken SDK popup açmaz; hata `onError` ile buraya gelir ve SDK'nın popup
//  bileşeniyle (`idAlert`) ekranın ortasında gösterilir. Kullanıcı "Tamam"a basınca `dismiss()` çağrılır ve akış kaldığı
//  yerden sürer (aynı adımı yeniden dener, modülü atlar ya da akışı bitirir).
//  Rehber: docs/guides/errors-and-limits.md
//

import SwiftUI
import IdentifySDK

/// Ayarlar menüsündeki "Hataları kendim göster" anahtarı.
enum SDKCustomErrorSetting {

    /// Diskteki anahtar. `@AppStorage` sabit metin istediği için arayüz tarafında aynı
    /// değer birebir yazılır.
    static let storageKey = "sdkCustomErrorEnabled"

    /// Kullanıcının tercihi. Yazıldığında hem diske işlenir hem SDK'ya uygulanır.
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: storageKey)
            apply()
        }
    }

    /// Kayıtlı tercihi SDK'ya işler.
    static func apply() {
        let config = SDKErrorConfig.shared
        if isEnabled {
            config.presentation = .custom
            config.onError = { info, dismiss in
                CustomErrorPresenter.shared.show(info, dismiss: dismiss)
            }
        } else {
            config.presentation = .sdkPopup
            config.onError = nil
            CustomErrorPresenter.shared.clear()
        }
    }
}

/// Ekrandaki hatayı tutar.
final class CustomErrorPresenter: ObservableObject {

    static let shared = CustomErrorPresenter()

    @Published private(set) var info: SDKErrorInfo?
    private var dismiss: (() -> Void)?

    func show(_ info: SDKErrorInfo, dismiss: @escaping () -> Void) {
        withAnimation(.spring(response: 0.4)) { self.info = info }
        self.dismiss = dismiss
    }

    /// Kullanıcı hatayı kapattı: SDK'ya bildirilir, akış sürer.
    func close() {
        let action = dismiss
        clear()
        action?()
    }

    func clear() {
        withAnimation(.spring(response: 0.4)) { info = nil }
        dismiss = nil
    }
}

/// Hatayı SDK'nın hazır popup'ıyla (`idAlert`) ekranın ortasında gösterir. "Tamam"a
/// basılınca `dismiss()` çağrılır.
private struct CustomErrorPopupModifier: ViewModifier {

    @ObservedObject var presenter = CustomErrorPresenter.shared

    func body(content: Content) -> some View {
        content.idAlert(item: Binding(
            get: {
                presenter.info.map { info in
                    var message = info.message
                    if let left = info.attemptsLeft, left > 0 { message += "\n\nKalan hak: \(left)" }
                    return IDAlertModel(type: .error,
                                        title: String(.coreError),
                                        message: message,
                                        actions: [IDAlertAction(title: String(.coreOk), style: .cancel)])
                }
            },
            set: { if $0 == nil { presenter.close() } }
        ))
    }
}

extension View {
    /// "Hataları kendim göster" açıkken gelen hatayı ortada popup olarak gösterir.
    func customErrorPopup() -> some View {
        modifier(CustomErrorPopupModifier())
    }
}
