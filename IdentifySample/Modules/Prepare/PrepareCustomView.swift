//
//  PrepareCustomView.swift
//  IdentifySample
//
//  HAZIRLIK — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKPrepareView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.prepare) { PrepareCustomView() }
//
//  Görev dağılımı:
//    • İzin istekleri (kamera/mikrofon/konuşma), ayarlar yönlendirmesi, hız testi,
//      hazırlığın sunucuya bildirilmesi → `SDKPrepareViewModel` (SDK)
//    • Kontrol listesi (kimlik yanımda / yalnızım / ortam uygun) ve çizim → bu dosya
//
//  ViewModel kullanımı:
//    checkCamera() / checkMicrophone() / checkSpeech()   izin satırına dokunulunca
//    cameraAuthorized / micAuthorized / speechAuthorized
//    needsSpeedTest / speedCheckDone / connectionQuality / startSpeedTest()
//    showSettingsAlert + settingsAlertMessage + settingsOpenAction   reddedilmiş izin
//    completePrepare()  → onCompleted → coordinator.advanceToNextModule()
//
//  Kopyalanacak dosyalar: bu dosya + CustomKit/CustomComponents.swift (başarı banner'ı)
//

import SwiftUI
import IdentifySDK

struct PrepareCustomView: View {

    @StateObject private var viewModel = SDKPrepareViewModel()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    // Sunucuya gitmeyen, yalnızca kullanıcının onayladığı maddeler.
    @State private var hasID = false
    @State private var isAlone = false
    @State private var hasGoodConditions = false

    private var allChecklistSelected: Bool {
        viewModel.cameraAuthorized && viewModel.micAuthorized && viewModel.speechAuthorized
            && hasID && isAlone && hasGoodConditions
    }

    var body: some View {
        ZStack(alignment: .top) {
            IDColor.moduleBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 0) {
                SDKNavigationBar(
                    style: .progress(steps: coordinator.progressTotal, current: coordinator.progressStep),
                    title: String(.idVerifyTitle),
                    subtitle: String(.prepareEnvSubtitle),
                    onBack: { coordinator.popBack() }
                )
                cardArea
                    .sdkReadableWidth()
            }
        }
        .onAppear {
            viewModel.onCompleted = { coordinator.advanceToNextModule() }
        }
        .customSuccessBanner(String(.speedBannerOk),
                             isVisible: viewModel.speedCheckDone && viewModel.connectionQuality == .good)
        .idAlert(isPresented: $viewModel.showSettingsAlert, alert: IDAlertModel(
            type: .info,
            title: String(.permissionRequired),
            message: viewModel.settingsAlertMessage,
            actions: [
                IDAlertAction(title: String(.coreCancel), style: .cancel),
                IDAlertAction(title: String(.coreSettings), style: .primary) { viewModel.settingsOpenAction?() }
            ]
        ))
    }

    private var cardArea: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: IDSpacing.xl) {
                    VStack(alignment: .leading, spacing: IDSpacing.sm) {
                        Text(viewModel.speedCheckDone ? String(.whichDocument) : String(.scanPrepareList))
                            .font(IDFont.displayMedium(.semibold))
                            .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                        Text(viewModel.speedCheckDone ? String(.docAddressDesc) : String(.readyChecklistDesc))
                            .font(IDFont.bodyRegular(.regular))
                            .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                            .lineSpacing(4)
                    }

                    VStack(spacing: IDSpacing.sm) {
                        PrepareCheckRow(icon: .permCamera, title: String(.prepareCam), isChecked: viewModel.cameraAuthorized) {
                            viewModel.checkCamera()
                        }
                        PrepareCheckRow(icon: .permMic, title: String(.prepareMic), isChecked: viewModel.micAuthorized) {
                            viewModel.checkMicrophone()
                        }
                        PrepareCheckRow(icon: .permSpeech, title: String(.prepareSpeech), isChecked: viewModel.speechAuthorized) {
                            viewModel.checkSpeech()
                        }
                        PrepareCheckRow(icon: .permIdCard, title: String(.idNear), isChecked: hasID) { hasID.toggle() }
                        PrepareCheckRow(icon: .permAlone, title: String(.aloneForVerification), isChecked: isAlone) { isAlone.toggle() }
                        PrepareCheckRow(icon: .permConditions, title: String(.lightSoundCont), isChecked: hasGoodConditions) {
                            hasGoodConditions.toggle()
                        }
                    }
                }
                .padding(.top, IDSpacing.xxl)
                .padding(.bottom, IDSpacing.xl)
                .padding(.horizontal, IDSpacing.lg)
            }

            SDKButton(
                title: viewModel.isLoading
                    ? ""
                    : (viewModel.needsSpeedTest && !viewModel.speedCheckDone ? String(.measureSpeedContinue) : String(.continuePage)),
                isLoading: viewModel.isLoading,
                isDisabled: !allChecklistSelected || viewModel.isLoading
            ) {
                guard allChecklistSelected else { return }
                if viewModel.needsSpeedTest && !viewModel.speedCheckDone {
                    viewModel.startSpeedTest()
                } else {
                    viewModel.completePrepare()
                }
            }
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
        }
        .background(IDColor.adaptiveSurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.card))
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Kontrol satırı

private struct PrepareCheckRow: View {
    let icon: SDKIconKey
    let title: String
    let isChecked: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var selection: SDKSelectionAppearance { SDKTheme.shared.selection }

    var body: some View {
        let textColor = isChecked ? IDColor.selectedItemText(for: colorScheme) : IDColor.unselectedItemText(for: colorScheme)
        Button(action: action) {
            HStack(spacing: 12) {
                Image.sdk(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(textColor)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(IDFont.bodyRegular(.regular))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: selection.checkboxCornerRadius ?? 6)
                        .fill(isChecked ? IDColor.selectedItemText(for: colorScheme)
                                        : (colorScheme == .dark ? IDColor.darkMuted : IDColor.divider))
                        .frame(width: selection.checkboxSize ?? 20, height: selection.checkboxSize ?? 20)
                    if isChecked {
                        Image.sdk(.checkmark)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(selection.checkmarkColor ?? IDColor.primary)
                    }
                }
            }
            .padding(.horizontal, IDSpacing.lg)
            .frame(minHeight: selection.rowMinHeight ?? 48)
            .background(
                RoundedRectangle(cornerRadius: selection.cornerRadius ?? IDRadius.md)
                    .fill(isChecked ? IDColor.selectedItemBackground(for: colorScheme)
                                    : IDColor.unselectedItemBackground(for: colorScheme))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Hazırlık — Özel Ekran") {
    SDKModulePreviewHost { PrepareCustomView() }
}
