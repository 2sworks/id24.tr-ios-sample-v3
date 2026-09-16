//
//  SignLangExample.swift
//  IdentifySample
//
//  SDK "İşaret Dili" (opt-in) modülü — ENTEGRASYON REHBERİ.
//  CallScreen başında, sunucu işaret dili desteği istediğinde fullScreenCover olarak sunulur.
//  1) SignLangExample         → SDK hazır ekranı (onFinish closure'ı ile)
//  2) SignLangExampleThemed   → tema override
//  3) SignLangCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (SignLangCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct SignLangExample: View {
    var body: some View { SDKSignLangView(onFinish: {}) }
}

// MARK: - 2) Tema
struct SignLangExampleThemed: View {
    var body: some View {
        SDKSignLangView(onFinish: {}).showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("İşaret Dili — Varsayılan") { SignLangExample().showcaseHost() }
#Preview("İşaret Dili — Tema") { SignLangExampleThemed().showcaseHost() }
#Preview("İşaret Dili — Özel Ekran") {
    SDKModulePreviewHost { SignLangCustomView(onFinish: {}) }
}
