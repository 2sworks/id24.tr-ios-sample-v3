//
//  IdCardExample.swift
//  IdentifySample
//
//  SDK "Kimlik Kartı" modülü — ENTEGRASYON REHBERİ.
//  1) IdCardExample         → SDK hazır ekranı
//  2) IdCardExampleThemed   → tema override
//  3) IdCardCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (IdCardCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct IdCardExample: View {
    var body: some View { SDKIdCardView() }
}

// MARK: - 2) Tema
struct IdCardExampleThemed: View {
    var body: some View {
        SDKIdCardView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Kimlik — Varsayılan") { IdCardExample().showcaseHost() }
#Preview("Kimlik — Tema") { IdCardExampleThemed().showcaseHost() }
#Preview("Kimlik — Özel Ekran") {
    SDKModulePreviewHost { IdCardCustomView() }
}
