//
//  ThankYouExample.swift
//  IdentifySample
//
//  SDK "Teşekkür/Sonuç" modülü — ENTEGRASYON REHBERİ.
//  3) ThankYouCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (ThankYouCustomView.swift)
//
//  Not: ThankYou TERMİNAL ekrandır (sonraki modül yoktur); sadece sonucu gösterir.
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct ThankYouExample: View {
    var body: some View { SDKThankYouView() }
}

// MARK: - 2) Tema
struct ThankYouExampleThemed: View {
    var body: some View {
        SDKThankYouView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("Teşekkür — Varsayılan") { ThankYouExample().showcaseHost() }
#Preview("Teşekkür — Tema") { ThankYouExampleThemed().showcaseHost() }
#Preview("Teşekkür — Özel Ekran") {
    SDKModulePreviewHost { ThankYouCustomView(status: .completed) }
}
