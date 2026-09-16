//
//  OvdExample.swift
//  IdentifySample
//
//  SDK "Kimlik OVD" (hologram/gökkuşağı) modülü — ENTEGRASYON REHBERİ.
//  1) OvdExample         → SDK hazır ekranı (kimlik: ön→hologram→arka)
//  2) OvdExamplePassport → pasaport varyantı (ön→hologram, ARKA YOK — tek veri sayfası)
//  3) OvdExampleThemed   → tema override
//  4) IdCardOVDCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (IdCardOVDCustomView.swift)
//
//  Not: Gerçek hologram/OVD tespiti SDK'da (OVDAnalyzer + Vision + CMMotion) canlı çalışır;
//  gerçek cihaz + uygun ışık gerektirir. Sesli yönerge TTS açıksa okunur, kapalıysa ekran metni.
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Varsayılan (kimlik)
struct OvdExample: View {
    var body: some View { SDKIdCardOVDView() }
}

// MARK: - 2) Pasaport (ön yüz + hologram, arka yok)
struct OvdExamplePassport: View {
    var body: some View { SDKIdCardOVDView(documentType: .passport) }
}

// MARK: - 2) Tema
struct OvdExampleThemed: View {
    var body: some View {
        SDKIdCardOVDView().showcaseThemed(primary: IDColor.accentPurple)
    }
}

// MARK: - Previews
#Preview("OVD — Kimlik") { OvdExample().showcaseHost() }
#Preview("OVD — Pasaport (ön yüz)") { OvdExamplePassport().showcaseHost() }
#Preview("OVD — Tema") { OvdExampleThemed().showcaseHost() }
#Preview("OVD — Özel Ekran") {
    SDKModulePreviewHost { IdCardOVDCustomView() }
}
