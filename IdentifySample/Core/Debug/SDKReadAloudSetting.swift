//
//  SDKReadAloudSetting.swift
//  IdentifySample
//
//  "Sesli Okuma (TTS)" tercihinin saklanması ve SDK'ya işlenmesi.
//

import Foundation
import IdentifySDK

/// Ayarlar menüsündeki "Sesli Okuma (TTS)" anahtarı.
///
/// Değer `UserDefaults`'ta saklanır; uygulama yeniden açıldığında anahtar bırakıldığı
/// yerden devam eder. Tercihin SDK'ya işlenmesi `apply()` ile olur ve uygulama
/// açılışında bir kez çağrılır — aksi hâlde tercih ancak login ekranı görününce
/// etkili olurdu.
enum SDKReadAloudSetting {

    /// Diskteki anahtar. `@AppStorage` sabit metin istediği için arayüz tarafında
    /// aynı değer birebir yazılır.
    static let storageKey = "sdkReadAloudEnabled"

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
        SDKSpeechConfig.shared.defaultMode = isEnabled ? .native : .off
    }
}
