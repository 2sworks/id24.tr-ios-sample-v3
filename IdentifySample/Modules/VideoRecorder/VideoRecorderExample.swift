//
//  VideoRecorderExample.swift
//  IdentifySample
//
//  SDK "Video Kayıt" modülü — ENTEGRASYON REHBERİ.
//  3) VideoRecorderCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (VideoRecorderCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct VideoRecorderExample: View {
    var body: some View { SDKVideoRecorderView() }
}

// MARK: - 2) Tema
struct VideoRecorderExampleThemed: View {
    var body: some View {
        SDKVideoRecorderView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Video — Varsayılan") { VideoRecorderExample().showcaseHost() }
#Preview("Video — Tema") { VideoRecorderExampleThemed().showcaseHost() }
#Preview("Video — Özel Ekran") {
    SDKModulePreviewHost { VideoRecorderCustomView() }
}
