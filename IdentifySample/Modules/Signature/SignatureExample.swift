//
//  SignatureExample.swift
//  IdentifySample
//
//  SDK "İmza" modülü — ENTEGRASYON REHBERİ.
//  3) SignatureCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (SignatureCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct SignatureExample: View {
    var body: some View { SDKSignatureView() }
}

// MARK: - 2) Tema
struct SignatureExampleThemed: View {
    var body: some View {
        SDKSignatureView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("İmza — Varsayılan") { SignatureExample().showcaseHost() }
#Preview("İmza — Tema") { SignatureExampleThemed().showcaseHost() }
#Preview("İmza — Özel Ekran") {
    SDKModulePreviewHost { SignatureCustomView() }
}
