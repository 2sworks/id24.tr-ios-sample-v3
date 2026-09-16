//
//  SelfieExample.swift
//  IdentifySample
//
//  SDK "Selfie" modülü — ENTEGRASYON REHBERİ.
//  1) SelfieExample         → SDK hazır ekranı
//  2) SelfieExampleThemed   → tema override
//  3) SelfieCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (SelfieCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct SelfieExample: View {
    var body: some View { SDKSelfieView() }
}

// MARK: - 2) Tema
struct SelfieExampleThemed: View {
    var body: some View {
        SDKSelfieView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Selfie — Varsayılan") { SelfieExample().showcaseHost() }
#Preview("Selfie — Tema") { SelfieExampleThemed().showcaseHost() }
#Preview("Selfie — Özel Ekran") {
    SDKModulePreviewHost { SelfieCustomView() }
}
