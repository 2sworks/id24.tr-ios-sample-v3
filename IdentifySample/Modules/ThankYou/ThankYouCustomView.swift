//
//  ThankYouCustomView.swift
//  IdentifySample
//
//  TEŞEKKÜRLER (AKIŞ SONU) — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKThankYouView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//  Rota bitiş durumunu taşır: `.thankYou(ThankYouStatus?)`. Registry anahtarı rotanın kendisi
//  olduğu için dört değerin hepsi ayrı kaydedilir:
//
//      registry.override(.thankYou(nil))           { ThankYouCustomView() }
//      registry.override(.thankYou(.completed))    { ThankYouCustomView(status: .completed) }
//      registry.override(.thankYou(.missedCall))   { ThankYouCustomView(status: .missedCall) }
//      registry.override(.thankYou(.notCompleted)) { ThankYouCustomView(status: .notCompleted) }
//
//  ViewModel kullanımı:
//    init(status:)             bitiş durumu (ViewModel oluşturulurken KYC tamamlandı olarak işaretlenir)
//    isSelfieIdentification    selfie ile kimlik doğrulama akışıysa "sonuç bildirilecek" satırı
//    coordinator.resetFlow()   Tamam → akış kapanır, host'un kök ekranına dönülür
//

import SwiftUI
import IdentifySDK

struct ThankYouCustomView: View {

    @StateObject private var viewModel: SDKThankYouViewModel
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    init(status: ThankYouStatus = .completed) {
        _viewModel = StateObject(wrappedValue: SDKThankYouViewModel(status: status))
    }

    var body: some View {
        ZStack {
            IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Image.sdk(.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 34)
                    .frame(maxWidth: .infinity)
                    .padding(.top, IDSpacing.xl)

                Spacer()

                VStack(spacing: IDSpacing.lg) {
                    statusIcon
                    Text(content.title)
                        .font(IDFont.displaySmall(.semibold))
                        .foregroundColor(content.color)
                        .multilineTextAlignment(.center)
                    VStack(spacing: IDSpacing.sm) {
                        Text(content.subtitle)
                        if viewModel.status == .completed && viewModel.isSelfieIdentification {
                            Text(.resultWillBeNotified)
                        }
                    }
                    .font(IDFont.bodyRegular(.regular))
                    .foregroundColor(IDColor.inkMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                }
                .padding(.horizontal, IDSpacing.xxl)

                Spacer()

                Button {
                    CustomScreens.pendingThankYouStatus = nil
                    coordinator.resetFlow()
                } label: {
                    Text(.coreOk)
                        .font(IDFont.bodyRegular(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(IDColor.primary)
                        .clipShape(SDKButtonShape.themed())
                }
                .padding(.horizontal, IDSpacing.lg)
                .padding(.bottom, IDSpacing.xxl)
            }
            .sdkReadableWidth()
        }
    }

    private var content: (title: String, subtitle: String, color: Color) {
        switch viewModel.status {
        case .completed:    return (String(.thankU), String(.thankYouCompletedDesc), IDColor.success)
        case .missedCall:   return (String(.thankYouMissedTitle), String(.thankYouMissedDesc), .orange)
        case .notCompleted: return (String(.thankYouFailedTitle), String(.thankYouFailedDesc), IDColor.error)
        @unknown default:   return (String(.thankYouFailedTitle), String(.thankYouFailedDesc), IDColor.error)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch viewModel.status {
        case .completed:
            Image.sdk(.thankYouSuccess).resizable().scaledToFit().frame(width: 64, height: 64)
        case .missedCall:
            Image.sdk(.thankYouFail).renderingMode(.template).resizable().scaledToFit()
                .frame(width: 64, height: 64).foregroundColor(.orange)
        default:
            Image.sdk(.thankYouFail).resizable().scaledToFit().frame(width: 64, height: 64)
        }
    }
}

#Preview("Teşekkürler — Özel Ekran") {
    SDKModulePreviewHost { ThankYouCustomView(status: .completed) }
}
