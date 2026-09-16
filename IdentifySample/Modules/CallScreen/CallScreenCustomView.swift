//
//  CallScreenCustomView.swift
//  IdentifySample
//
//  GÖRÜNTÜLÜ GÖRÜŞME — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın `SDKCallScreenView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.callScreen) { CallScreenCustomView() }
//
//  Görev dağılımı:
//    • Socket mesajları, çağrı durumu, WebRTC, SMS doğrulama, uzaktan NFC, yeniden bağlanma,
//      görüşme sonu kararları → `SDKCallScreenViewModel` (SDK)
//    • Durum başına ekran çizimi ve video görünümlerinin yerleşimi → bu dosya
//
//  ViewModel kullanımı:
//    onAppear:   IdentifyManager.shared.socketMessageListener = viewModel   ← ZORUNLU (socket mesajları VM'e gelsin)
//                IdentifyManager.shared.replayPendingQueueStats()          ← ekran açılmadan gelen sıra bilgisi
//                viewModel.checkSignLangIfNeeded()
//    onDisappear: coordinator.restoreSocketListener(); viewModel.cleanup()   ← ZORUNLU
//    callState                    .waiting / .ringing / .connected / .smsVerification / .nfcReading / .ended
//    acceptCall()                 gelen çağrıyı kabul et
//    remoteVideoView / localVideoView   WebRTC görüntüleri (UIView) — CustomVideoFeedView ile yerleştirilir
//    smsCode + verifySMS()        SMS doğrulama
//    endCallEnabled + terminateCall(coordinator:)   görüşmeyi bitir
//    showNFCEdit + saveAndRestartRemoteNFC(...)     panelin istediği MRZ düzeltmesi
//    showSignLangGate + signLangCompleted()         işaret dili tercihi
//    showLostConnection + handleReconnectCompleted / handleReconnectCompletedWithStatus
//    socketThankYouStatus  → coordinator.advanceToNextModule()
//    directThankYouStatus  → viewModel.finishSDKForDirectThankYou(); coordinator.pushThankYouDirectly(status:)
//
//  Not (3.1.0): SDK ekranı `socketThankYouStatus`'u teşekkür ekranına taşımak için
//  `coordinator.pendingThankYouStatus`'a yazar; bu alanın setter'ı public değil. Bu örnek değeri
//  `CustomScreens.pendingThankYouStatus`'ta bırakır, ThankYouCustomView oradan okur.
//
//  Kopyalanacak dosyalar: bu dosya + CustomKit/CustomComponents.swift + CustomKit/CustomScreens.swift
//  (+ LostConnectionCustomView.swift ve SignLangCustomView.swift; gerekirse yerine SDK'nın
//  SDKLostConnectionView / SDKSignLangView ekranları kullanılır)
//

import SwiftUI
import IdentifySDK

struct CallScreenCustomView: View {

    @StateObject private var viewModel = SDKCallScreenViewModel()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sdkPreviewMode) private var sdkPreviewMode

    @State private var showEndCallAlert = false
    @State private var nfcPulseActive = false

    var body: some View {
        ZStack {
            Group {
                switch viewModel.callState {
                case .waiting, .ended:  waitingScreen
                case .ringing:          ringingScreen
                case .connected:        connectedScreen
                case .smsVerification:  connectedScreen.overlay(smsOverlay)
                case .nfcReading:       connectedScreen.overlay(nfcOverlay)
                @unknown default:       waitingScreen
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.callState)

            errorToast
            photoTakenBanner
        }
        .onAppear {
            CustomScreens.pendingThankYouStatus = nil
            guard !sdkPreviewMode else { return }
            IdentifyManager.shared.socketMessageListener = viewModel
            IdentifyManager.shared.replayPendingQueueStats()
            UIApplication.shared.isIdleTimerDisabled = true
            viewModel.checkSignLangIfNeeded()
        }
        .onDisappear {
            guard !sdkPreviewMode else { return }
            coordinator.restoreSocketListener()
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.cleanup()
        }
        .onChange(of: viewModel.socketThankYouStatus) { status in
            guard let status else { return }
            CustomScreens.pendingThankYouStatus = status
            coordinator.advanceToNextModule()
        }
        .onChange(of: viewModel.directThankYouStatus) { status in
            guard let status else { return }
            // Panel karar verdi: oturum bitti, sıradaki modüle geçilmez.
            viewModel.finishSDKForDirectThankYou()
            coordinator.pushThankYouDirectly(status: status)
        }
        .idAlert(isPresented: $showEndCallAlert, alert: IDAlertModel(
            type: .normal,
            title: String(.callEndTitle),
            message: String(.callEndConfirm),
            actions: [
                IDAlertAction(title: String(.coreGiveUp), style: .cancel),
                IDAlertAction(title: String(.finish), style: .destructive) {
                    viewModel.terminateCall(coordinator: coordinator)
                }
            ]
        ))
        .sheet(isPresented: $viewModel.showNFCEdit) {
            CallNFCEditCustomSheet(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.showSignLangGate) {
            SignLangCustomView { viewModel.signLangCompleted() }
        }
        .fullScreenCover(isPresented: $viewModel.showLostConnection) {
            LostConnectionCustomView(
                onReconnectCompleted: { viewModel.handleReconnectCompleted() },
                onReconnectCompletedWithStatus: { isWaitingRoom, statusType in
                    viewModel.handleReconnectCompletedWithStatus(
                        isWaitingRoom: isWaitingRoom, statusType: statusType, coordinator: coordinator)
                }
            )
        }
    }

    // MARK: - Bekleme

    private var waitingScreen: some View {
        ZStack {
            IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : IDColor.primary.opacity(0.1))
                        .frame(width: 144, height: 144)
                    Image.sdk(.logo)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 96)
                        .foregroundColor(colorScheme == .dark ? .white : IDColor.primary)
                }
                .padding(.bottom, IDSpacing.xl)

                VStack(spacing: IDSpacing.sm) {
                    Text(.corePlsWait)
                        .font(IDFont.displayMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    Text(.callConnectingInfo)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, IDSpacing.lg)
                .padding(.bottom, IDSpacing.xl)

                queueInfoCard
                    .padding(.horizontal, IDSpacing.lg)
                    .sdkReadableWidth()

                Spacer()
            }
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
    }

    private var queueInfoCard: some View {
        Group {
            if !viewModel.queuePosition.isEmpty && viewModel.queuePosition != "0" {
                VStack(spacing: 4) {
                    Text(String(format: String(.callQueuePositionFmt), viewModel.queuePosition))
                        .font(IDFont.bodyMediumPlus(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                    Text(String(format: String(.callEstimatedWaitFmt), viewModel.estimatedWait))
                        .font(IDFont.caption(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(IDSpacing.lg)
                .background(cardBackground)
            } else {
                Text(.callScreenWaitRepresentative)
                    .font(IDFont.bodySmall(.medium))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(IDSpacing.lg)
                    .background(cardBackground)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: IDRadius.lg)
            .fill(IDColor.adaptiveSurface(for: colorScheme))
            .overlay(RoundedRectangle(cornerRadius: IDRadius.lg).stroke(IDColor.adaptiveBorder(for: colorScheme), lineWidth: 1))
    }

    // MARK: - Gelen çağrı

    private var ringingScreen: some View {
        ZStack {
            IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image.sdk(.incomingCall)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 144, height: 144)
                    .padding(.bottom, IDSpacing.xl)

                VStack(spacing: IDSpacing.sm) {
                    Text(.callTitle)
                        .font(IDFont.displayMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    Text(.callDescription)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, IDSpacing.lg)
                }
                .padding(.bottom, IDSpacing.xxl)

                Spacer()

                Button(action: { viewModel.acceptCall() }) {
                    Image.sdk(.incomingCallButton)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78, height: 78)
                }
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Görüşme

    private var connectedScreen: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                CustomVideoFeedView(videoView: viewModel.remoteVideoView)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()

            LinearGradient(colors: [Color.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 180)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    networkQualityIndicator
                        .padding(.top, IDSpacing.xl)
                    Spacer()
                    CustomVideoFeedView(videoView: viewModel.localVideoView)
                        .frame(width: 126, height: 155)
                        .clipShape(RoundedRectangle(cornerRadius: IDRadius.sm))
                        .overlay(RoundedRectangle(cornerRadius: IDRadius.sm).stroke(Color.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
                        .padding(.top, IDSpacing.xl)
                        .padding(.trailing, IDSpacing.lg)
                }
                Spacer()
                bottomCallPanel
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var networkQualityIndicator: some View {
        switch viewModel.networkQuality {
        case .none:   EmptyView()
        case .bad:    qualityIcon(.wifiBad, color: .red)
        case .medium: qualityIcon(.wifiGood, color: .yellow)
        case .good:   qualityIcon(.wifiGood, color: .green)
        @unknown default: EmptyView()
        }
    }

    private func qualityIcon(_ icon: SDKIconKey, color: Color) -> some View {
        Image.sdk(icon)
            .renderingMode(.template)
            .resizable().scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundColor(color)
            .padding(8)
            .background(.ultraThinMaterial, in: Circle())
            .padding(.leading, IDSpacing.lg)
    }

    private var bottomCallPanel: some View {
        VStack(spacing: IDSpacing.lg) {
            Capsule()
                .fill(SDKTheme.shared.call.handleColor ?? Color.white.opacity(0.4))
                .frame(width: 44, height: 5)

            Button(action: { if viewModel.endCallEnabled { showEndCallAlert = true } }) {
                VStack {
                    ZStack {
                        Circle()
                            .fill(IDColor.error)
                            .frame(width: 72, height: 72)
                            .opacity(viewModel.endCallEnabled ? 1 : 0.35)
                        Image.sdk(.close)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(.callEndCall)
                        .font(IDFont.bodySmall(.medium))
                        .foregroundColor(.white)
                }
            }
            .disabled(!viewModel.endCallEnabled)
            .animation(.easeInOut(duration: 0.2), value: viewModel.endCallEnabled)

            Spacer().frame(height: IDSpacing.lg)
        }
        .padding(.top, IDSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color(.sRGB, red: 0.22, green: 0.22, blue: 0.22, opacity: 0.35)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
        .clipShape(CustomTopRoundedShape(radius: IDRadius.lg))
    }

    // MARK: - Uzaktan NFC

    private var nfcOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: IDSpacing.lg) {
                ZStack {
                    Image.sdk(.nfcBack)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 300)
                        .scaleEffect(nfcPulseActive ? 1.08 : 0.96)
                        .opacity(nfcPulseActive ? 0.55 : 0.95)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: nfcPulseActive)
                    Image.sdk(viewModel.isPassport ? .nfcPassportFront : .nfcFront)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 300)
                        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
                        .padding(.trailing, IDSpacing.lg)
                }
                .frame(width: 300, height: 300)

                VStack(spacing: IDSpacing.sm) {
                    Text(.nfcScanTitle)
                        .font(IDFont.displayMedium(.semibold))
                        .foregroundColor(.white)
                    Text(.nfcHoldInstruction)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                if !viewModel.nfcStatusMessage.isEmpty {
                    Text(viewModel.nfcStatusMessage)
                        .font(IDFont.bodySmall(.medium))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(IDSpacing.xl)
        }
        .onAppear { nfcPulseActive = true }
        .onDisappear { nfcPulseActive = false }
    }

    // MARK: - SMS

    private var smsOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: IDSpacing.xl) {
                VStack(spacing: IDSpacing.sm) {
                    Image.sdk(.chat)
                        .font(.system(size: 32))
                        .foregroundColor(IDColor.primary)
                    Text(.smsCodeTitle)
                        .font(IDFont.displayMedium(.semibold))
                        .foregroundColor(.white)
                    Text(.smsCodeInstruction)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                TextField("· · · · · ·", text: $viewModel.smsCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    .frame(maxWidth: 200)
                    .padding(.vertical, IDSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: IDRadius.md)
                            .fill(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: IDRadius.md).stroke(IDColor.primary.opacity(0.5), lineWidth: 2))
                    )

                Button(action: { viewModel.verifySMS() }) {
                    Text(.coreVerify)
                        .font(IDFont.bodyRegular(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(viewModel.isSMSCodeValid ? IDColor.primary : IDColor.primary.opacity(0.35))
                        .clipShape(SDKButtonShape.themed())
                }
                .disabled(!viewModel.isSMSCodeValid)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isSMSCodeValid)
            }
            .padding(IDSpacing.xl)
            .background(RoundedRectangle(cornerRadius: IDRadius.card).fill(IDColor.darkBgSecondary))
            .padding(.horizontal, IDSpacing.lg)
        }
    }

    // MARK: - Bildirimler

    @ViewBuilder
    private var errorToast: some View {
        if let msg = viewModel.errorMessage {
            VStack {
                Spacer()
                Text(msg)
                    .font(IDFont.bodySmall(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, IDSpacing.lg)
                    .padding(.vertical, IDSpacing.md)
                    .background(IDColor.error.opacity(0.9))
                    .clipShape(SDKButtonShape.themed(.cancel))
                    .padding(.bottom, IDSpacing.xl)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: viewModel.errorMessage)
        }
    }

    @ViewBuilder
    private var photoTakenBanner: some View {
        if let msg = viewModel.photoTakenToast {
            VStack {
                CustomSuccessBanner(message: msg)
                    .padding(.horizontal, IDSpacing.lg)
                    .padding(.top, IDSpacing.sm)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: viewModel.photoTakenToast)
        }
    }
}

// MARK: - Uzaktan NFC için MRZ düzeltme sayfası (panel .editNfcProcess ile açar)

private struct CallNFCEditCustomSheet: View {

    @ObservedObject var viewModel: SDKCallScreenViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var serial = ""
    @State private var birth = ""
    @State private var valid = ""

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "tr_TR")
        return f
    }()
    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private var isSerialValid: Bool { SDKNfcViewModel.isSerialValid(serial, isPassport: viewModel.isPassport) }
    private var isBirthValid: Bool { Self.dateParser.date(from: birth).map { $0 < startOfToday } ?? false }
    private var isValidDateValid: Bool { Self.dateParser.date(from: valid).map { $0 >= startOfToday } ?? false }
    private var canSave: Bool { isSerialValid && isBirthValid && isValidDateValid }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: IDSpacing.xl) {
                VStack(alignment: .leading, spacing: IDSpacing.sm) {
                    Text(.mrzEditTitle)
                        .font(IDFont.bodyMedium(.semibold))
                        .foregroundColor(IDColor.error)
                    Text(.mrzEditDesc)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .lineSpacing(4)
                }
                field(title: String(viewModel.isPassport ? .serialNoPassport : .serialNoShort),
                      error: (!serial.isEmpty && !isSerialValid) ? String(viewModel.isPassport ? .nfcSerialInvalidPassport : .nfcSerialInvalid) : nil,
                      placeholder: viewModel.isPassport ? "U12345678" : "A32R17869", text: $serial, keyboard: .asciiCapable)
                field(title: String(.coreBirthday),
                      error: (!birth.isEmpty && !isBirthValid) ? String(.nfcBirthDateInvalid) : nil,
                      placeholder: "dd.MM.yyyy", text: $birth, keyboard: .numbersAndPunctuation)
                field(title: String(.nfcExpDate),
                      error: (!valid.isEmpty && !isValidDateValid) ? String(.nfcValidDateInvalid) : nil,
                      placeholder: "dd.MM.yyyy", text: $valid, keyboard: .numbersAndPunctuation)
            }
            .padding(.top, IDSpacing.xl)
            .padding(.horizontal, IDSpacing.lg)

            Spacer()

            Button(action: { viewModel.saveAndRestartRemoteNFC(serial: serial, birth: birth, valid: valid) }) {
                Text(.coreUpdate)
                    .font(IDFont.bodyRegular(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSave ? IDColor.inkDarkest : IDColor.inkDarkest.opacity(0.35))
                    .clipShape(SDKButtonShape.themed())
            }
            .disabled(!canSave)
            .animation(.easeInOut(duration: 0.2), value: canSave)
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .customDismissKeyboardOnTap()
        .onAppear {
            serial = viewModel.nfcEditSerial
            birth = viewModel.nfcEditBirth
            valid = viewModel.nfcEditValid
        }
    }

    private var header: some View {
        HStack {
            Spacer().frame(width: 32)
            Spacer()
            Text(.mrzEditNavTitle)
                .font(IDFont.bodyMedium(.semibold))
                .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
            Spacer()
            Button(action: { dismiss() }) {
                Image.sdk(.close)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(IDColor.adaptiveSurface(for: colorScheme)))
            }
        }
        .padding(.horizontal, IDSpacing.lg)
        .padding(.top, IDSpacing.lg)
        .padding(.bottom, IDSpacing.md)
    }

    private func field(title: String, error: String?, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: IDSpacing.sm) {
            Text(title)
                .font(IDFont.bodySmall(.medium))
                .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            ZStack(alignment: .leading) {
                Text(placeholder)
                    .font(IDFont.bodySmall())
                    .foregroundColor(IDColor.inkLight)
                    .opacity(text.wrappedValue.isEmpty ? 1 : 0)
                    .allowsHitTesting(false)
                TextField("", text: text)
                    .font(IDFont.bodySmall())
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    .keyboardType(keyboard)
                    .autocapitalization(keyboard == .asciiCapable ? .allCharacters : .none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, IDSpacing.lg)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: IDRadius.md)
                    .fill(IDColor.adaptiveSurface(for: colorScheme))
                    .overlay(RoundedRectangle(cornerRadius: IDRadius.md).stroke(IDColor.inkBorder, lineWidth: 1))
            )
            if let error {
                Text(error)
                    .font(IDFont.caption(.regular))
                    .foregroundColor(IDColor.error)
            }
        }
    }
}

#Preview("Görüşme — Özel Ekran") {
    SDKModulePreviewHost { CallScreenCustomView() }
}
