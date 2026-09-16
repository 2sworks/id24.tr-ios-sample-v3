//
//  PrepareExample.swift
//  IdentifySample
//
//  SDK "Hazırlık" modülü — ENTEGRASYON REHBERİ.
//  1) PrepareExample         → SDK hazır ekranı
//  2) PrepareExampleThemed   → tema override
//  3) PrepareCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (PrepareCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct PrepareExample: View {
    var body: some View { SDKPrepareView() }
}

// MARK: - 2) Tema
struct PrepareExampleThemed: View {
    var body: some View {
        SDKPrepareView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Hazırlık — Varsayılan") { PrepareExample().showcaseHost() }
#Preview("Hazırlık — Tema") { PrepareExampleThemed().showcaseHost() }
#Preview("Hazırlık — Özel Ekran") {
    SDKModulePreviewHost { PrepareCustomView() }
}
