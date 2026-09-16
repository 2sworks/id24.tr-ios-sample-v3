//
//  LivenessExample.swift
//  IdentifySample
//
//  SDK "Canlılık" modülü — ENTEGRASYON REHBERİ.
//  3) LivenessCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (LivenessCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct LivenessExample: View {
    var body: some View { SDKLivenessView() }
}

// MARK: - 2) Tema
struct LivenessExampleThemed: View {
    var body: some View {
        SDKLivenessView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Canlılık — Varsayılan") { LivenessExample().showcaseHost() }
#Preview("Canlılık — Tema") { LivenessExampleThemed().showcaseHost() }
#Preview("Canlılık — Özel Ekran") {
    SDKModulePreviewHost { LivenessCustomView() }
}
