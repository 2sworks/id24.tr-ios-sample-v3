//
//  SwlExample.swift
//  IdentifySample
//
//  SDK "Canlılıkla Selfie" modülü — ENTEGRASYON REHBERİ.
//  1) SwlExample          → SDK hazır ekranı (mod: IdentifyManager.shared.selfieWithLivenessTrueDepth)
//  2) SwlExampleThemed    → tema override
//  3) Tam özel ekran YOK: SDK 3.1.0 bu modül için public ViewModel sunmuyor (bkz. SelfieWithLiveness.md)
//  4) SwlExampleTrueDepth → ekran bazında TrueDepth modu (.automatic / .required / .disabled)
//
//  ⚠️ Gerçek cihaz gerekir (simülatörde kamera ve ARKit yok).
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan
struct SwlExample: View {
    var body: some View { SDKSelfieWithLivenessView() }
}

// MARK: - 2) Tema
struct SwlExampleThemed: View {
    var body: some View {
        SDKSelfieWithLivenessView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - 4) TrueDepth modu — yalnız bu ekran
/// Akışın tamamı için `IdentifyManager.shared.selfieWithLivenessTrueDepth` setupSDK'dan önce
/// ayarlanır. Burada verilen değer yalnız ekranın yolunu seçer; modülün A11 ve öncesi cihazda
/// akışta kalması için global değer de `.disabled` olmalıdır.
///
///     registry.override(.selfieWithLiveness) { SwlExampleTrueDepth(mode: .disabled) }
struct SwlExampleTrueDepth: View {
    let mode: SDKTrueDepthMode

    var body: some View { SDKSelfieWithLivenessView(trueDepthMode: mode) }
}

// MARK: - Previews
#Preview("Canlılıkla Selfie — Varsayılan") { SwlExample().showcaseHost() }
#Preview("Canlılıkla Selfie — Tema") { SwlExampleThemed().showcaseHost() }
