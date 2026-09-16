//
//  CallScreenExample.swift
//  IdentifySample
//
//  SDK "Görüşme" modülü — ENTEGRASYON REHBERİ.
//  3) CallScreenCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (CallScreenCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct CallScreenExample: View {
    var body: some View { SDKCallScreenView() }
}

// MARK: - 2) Tema
struct CallScreenExampleThemed: View {
    var body: some View {
        SDKCallScreenView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Görüşme — Varsayılan") { CallScreenExample().showcaseHost() }
#Preview("Görüşme — Tema") { CallScreenExampleThemed().showcaseHost() }
#Preview("Görüşme — Özel Ekran") {
    SDKModulePreviewHost { CallScreenCustomView() }
}
