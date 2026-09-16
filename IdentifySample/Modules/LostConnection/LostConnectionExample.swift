//
//  LostConnectionExample.swift
//  IdentifySample
//
//  SDK "Bağlantı Koptu" (yeniden bağlanma) ekranı — ENTEGRASYON REHBERİ.
//  Görüşme sırasında internet/socket koptuğunda SDK bu ekranı otomatik sunar.
//  1) LostConnectionExample         → SDK hazır ekranı
//  2) LostConnectionExampleThemed   → tema override
//  3) LostConnectionCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (LostConnectionCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct LostConnectionExample: View {
    var body: some View { SDKLostConnectionView() }
}

// MARK: - 2) Tema
struct LostConnectionExampleThemed: View {
    var body: some View {
        SDKLostConnectionView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Bağlantı Koptu — Varsayılan") { LostConnectionExample().showcaseHost() }
#Preview("Bağlantı Koptu — Tema") { LostConnectionExampleThemed().showcaseHost() }
#Preview("Bağlantı Koptu — Özel Ekran") {
    SDKModulePreviewHost { LostConnectionCustomView() }
}
