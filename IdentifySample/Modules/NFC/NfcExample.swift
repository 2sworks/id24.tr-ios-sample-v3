//
//  NfcExample.swift
//  IdentifySample
//
//  SDK "NFC" modülü — ENTEGRASYON REHBERİ.
//  1) NfcExample         → SDK hazır ekranı
//  2) NfcExampleThemed   → tema override
//  3) NfcCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (NfcCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct NfcExample: View {
    var body: some View { SDKNfcView() }
}

// MARK: - 2) Tema
struct NfcExampleThemed: View {
    var body: some View {
        SDKNfcView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("NFC — Varsayılan") { NfcExample().showcaseHost() }
#Preview("NFC — Tema") { NfcExampleThemed().showcaseHost() }
#Preview("NFC — Özel Ekran") {
    SDKModulePreviewHost { NfcCustomView() }
}
