//
//  LostConnectionCustomView.swift
//  IdentifySample
//
//  BAĞLANTI KOPTU — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın `SDKLostConnectionView` ekranının public API ile yazılmış birebir karşılığıdır.
//  Bu ekran bir akış rotası değildir:
//    • Görüşme sırasında: görüşme ekranı `SDKCallScreenViewModel.showLostConnection` ile açar
//      (bkz. CallScreenCustomView).
//    • Görüşme dışındaki modüllerde: `SDKFlowHostView` SDK ekranını kendisi açar
//      (`coordinator.showLostConnection`); bu kapak şu an registry ile değiştirilemez.
//
//  ViewModel kullanımı:
//    reconnect()                        yeniden bağlanmayı başlatır
//    isReconnecting / isNetworkAvailable / canReconnect   buton durumu
//    onReconnectCompleted               socket yeniden bağlandı (görüşme dışı akış)
//    onReconnectCompletedWithStatus     (bekleme odasına mı dönülecek, panel statüsü) — görüşme içi
//

import SwiftUI
import IdentifySDK

struct LostConnectionCustomView: View {

    var onReconnectCompleted: (() -> Void)? = nil
    var onReconnectCompletedWithStatus: ((Bool, String?) -> Void)? = nil

    @StateObject private var viewModel = SDKLostConnectionViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image.sdk(.lostConnection)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 144, height: 144)
                    .padding(.bottom, IDSpacing.xxl)

                VStack(spacing: IDSpacing.sm) {
                    Text(.connectionLostTitle)
                        .font(IDFont.displayMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                    Text(.connectionLostDesc)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, IDSpacing.xxl)
                }

                Spacer()

                reconnectButton
                    .padding(.horizontal, IDSpacing.lg)
            }
            .sdkReadableWidth()
        }
        .onAppear {
            viewModel.onReconnectCompleted = onReconnectCompleted
            viewModel.onReconnectCompletedWithStatus = onReconnectCompletedWithStatus
        }
    }

    private var reconnectButton: some View {
        Button(action: { viewModel.reconnect() }) {
            HStack(spacing: 8) {
                if viewModel.isReconnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                }
                Text(buttonTitle)
                    .font(IDFont.bodyRegular(.semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(viewModel.canReconnect ? IDColor.successBright : IDColor.successBright.opacity(0.35))
            .clipShape(SDKButtonShape.themed(.success))
        }
        .disabled(!viewModel.canReconnect)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isReconnecting)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isNetworkAvailable)
    }

    private var buttonTitle: String {
        if viewModel.isReconnecting { return String(.connecting) }
        if !viewModel.isNetworkAvailable { return String(.noInternet) }
        return String(.coreReConnect)
    }
}

#Preview("Bağlantı Koptu — Özel Ekran") {
    SDKModulePreviewHost { LostConnectionCustomView() }
}
