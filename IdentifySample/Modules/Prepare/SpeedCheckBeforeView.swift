//
//  SpeedCheckBeforeView.swift
//  IdentifySample
//
//  MODÜL ÖNCESİ HIZ TESTİ EKRANI
//
//  Herhangi bir modülün önüne eklenen, açılır açılmaz bağlantıyı ölçen ara ekran.
//  Sunucu geçer derse akış kendiliğinden modüle girer; engellerse kullanıcı burada kalır.
//
//      registry.custom("speedCheck") { SpeedCheckBeforeView() }
//      coordinator.insert(["speedCheck"], before: .callScreen)   // görüntülü görüşmeden önce
//
//  Rehber: docs/guides/speed-test.md, bölüm 4.
//

import SwiftUI
import IdentifySDK

struct SpeedCheckBeforeView: View {

    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var isMeasuring = false
    @State private var isBlocked = false
    @State private var measureTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: IDSpacing.xl) {
                Spacer()
                if isBlocked {
                    Text(String(.connectionErrorRetry))
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                } else {
                    ProgressView()
                }
                Spacer()
                if isBlocked {
                    SDKButton(title: String(.coreTryAgain), isLoading: isMeasuring, isDisabled: isMeasuring) {
                        measure()
                    }
                }
            }
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
            .sdkReadableWidth()
        }
        .onAppear(perform: measure)
        .onDisappear {
            measureTask?.cancel()
            IdentifyManager.shared.cancelConnectionSpeedTest()
        }
    }

    private func measure() {
        guard !isMeasuring else { return }
        isMeasuring = true
        measureTask = Task {
            let result = try? await IdentifyManager.shared.startConnectionSpeedTest()
            isMeasuring = false
            // Ekran kapanınca görev iptal edilir; o zaman karar verilmez.
            guard let result else { return }
            // Karar yalnızca blockIdent'ten okunur; atlanan test kullanıcıyı durdurmaz.
            if result.blockIdent {
                isBlocked = true
            } else {
                coordinator.advanceExternal()
            }
        }
    }
}

#Preview("Modül öncesi hız testi") {
    SDKModulePreviewHost { SpeedCheckBeforeView() }
}
