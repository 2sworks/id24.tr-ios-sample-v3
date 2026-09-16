//
//  SpeechExample.swift
//  IdentifySample
//
//  SDK "Konuşma" modülü — ENTEGRASYON REHBERİ.
//  3) SpeechCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (SpeechCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct SpeechExample: View {
    var body: some View { SDKSpeechRecView() }
}

// MARK: - 2) Tema
struct SpeechExampleThemed: View {
    var body: some View {
        SDKSpeechRecView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Konuşma — Varsayılan") { SpeechExample().showcaseHost() }
#Preview("Konuşma — Tema") { SpeechExampleThemed().showcaseHost() }
#Preview("Konuşma — Özel Ekran") {
    SDKModulePreviewHost { SpeechCustomView() }
}
