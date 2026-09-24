//
//  IdCardCustomView.swift
//  IdentifySample
//
//  KİMLİK KARTI (OCR) — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKIdCardView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.idCard) { IdCardCustomView() }
//
//  Görev dağılımı:
//    • Belge tipinin sunucuya bildirilmesi, OCR / MRZ okuma, yükleme, karşılaştırma → `SDKIdCardViewModel`
//    • Canlı belge tarayıcı (kenar bulma, netlik, otomatik çekim) → SDK'nın public `IdentityScannerView`'ı
//    • İki fazlı ekran (belge tipi seçimi → ön/arka yüz slotları) ve çizim → bu dosya
//
//  ViewModel kullanımı:
//    notifyDocumentSelectionShown()  seçim ekranı görününce
//    allowedCardTypes                sunucunun izin verdiği belge tipleri (boşsa hepsi)
//    selectCardType(_:)              taramadan ÖNCE
//    scanFront(image:) / scanBack(image:)   tarayıcıdan gelen kırpılmış görüntü
//    frontPhoto / backPhoto / canContinue / isLoading
//    onSkipRequested / onFlowFailed + errorMessage/consumePendingAlertAction()
//

import SwiftUI
import IdentifySDK

struct IdCardCustomView: View {

    private enum Phase { case typeSelection, scanning }

    @StateObject private var viewModel: SDKIdCardViewModel
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var phase: Phase
    @State private var selectedCardType: CardType
    @State private var scannerSide: IdCardSide?
    /// Seçim ekranı atlandıysa kullanılan tip; `nil` ise ekran gösterilir.
    private let skippedCardType: CardType?
    @State private var didReportSkippedType = false

    private var isPassport: Bool { selectedCardType == .passport }

    /// Seçim ekranı `SDKDocumentSelectionConfig.shared.idCard` ile kapatılabilir ya da tek seçenek
    /// kaldığında atlanır; atlandığında seçim açılışta bir kez sunucuya bildirilir.
    init() {
        let vm = SDKIdCardViewModel()
        skippedCardType = vm.skippedCardType
        _phase = State(initialValue: vm.skippedCardType == nil ? .typeSelection : .scanning)
        _selectedCardType = State(initialValue: vm.initialCardType)
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ZStack(alignment: .top) {
            IDColor.moduleBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 0) {
                SDKNavigationBar(
                    style: .progress(steps: coordinator.progressTotal, current: coordinator.progressStep),
                    title: String(.idVerifyTitle),
                    subtitle: phase == .typeSelection ? String(.selectMethodContinue) : String(.completeSteps),
                    onBack: {
                        if phase == .scanning, skippedCardType == nil {
                            SDKSpeechService.shared.stop()
                            withAnimation { phase = .typeSelection }
                        } else {
                            coordinator.popBack()
                        }
                    }
                )
                .padding(.top, IDSpacing.sm)

                switch phase {
                case .typeSelection: typeSelectionCard
                case .scanning:      scanningCard
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
        .idErrorAlert($viewModel.errorMessage, onDismiss: { viewModel.consumePendingAlertAction() })
        .fullScreenCover(item: $scannerSide) { side in
            IdCardScannerCover(side: side) { image in
                scannerSide = nil
                guard let image else { return }
                if side == .back { viewModel.scanBack(image: image) } else { viewModel.scanFront(image: image) }
            }
        }
        .onAppear {
            viewModel.onSkipRequested = { coordinator.skipCurrentModule() }
            viewModel.onFlowFailed = { coordinator.finishFlowAsFailed() }
            // Seçim ekranı yoksa seçim modül açılır açılmaz gider (stepChanged + setDocType).
            if let skippedCardType, !didReportSkippedType {
                didReportSkippedType = true
                viewModel.selectCardType(skippedCardType)
            }
        }
    }

    // MARK: - Faz 1: belge tipi

    private var typeSelectionCard: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: IDSpacing.xl) {
                    titleBlock(String(.scanType), String(.scanTypeDesc))
                    VStack(spacing: IDSpacing.sm) {
                        // Satırlar `SDKDocumentSelectionConfig.shared.idCard.options` ∩ sunucunun izin verdikleri.
                        ForEach(viewModel.selectionOptions, id: \.self) { type in
                            CardTypeRow(icon: type.selectionIcon, title: type.selectionTitle, isSelected: selectedCardType == type) {
                                selectedCardType = type
                            }
                        }
                    }
                }
                .padding(.top, IDSpacing.xxl)
                .padding(.bottom, IDSpacing.xl)
                .padding(.horizontal, IDSpacing.lg)
            }

            SDKButton(title: String(.continuePage)) {
                viewModel.selectCardType(selectedCardType)
                // Modul ici ekran degisimi de bir gecistir: hazirlik ekraninin yonergesi
                // kesilmezse tarama ekraninda okunmaya devam eder.
                SDKSpeechService.shared.stop()
                withAnimation { phase = .scanning }
            }
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
        }
        .background(IDColor.adaptiveSurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.card))
        .sdkReadableWidth()
        .ignoresSafeArea(edges: .bottom)
        .onAppear { viewModel.notifyDocumentSelectionShown() }
    }

    // MARK: - Faz 2: tarama

    private var scanningCard: some View {
        VStack(spacing: 0) {
            titleBlock(String(.idScanTitle), String(.idPhotoDesc))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, IDSpacing.xxl)
                .padding(.horizontal, IDSpacing.lg)

            ScrollView(showsIndicators: false) {
                VStack(spacing: IDSpacing.sm) {
                    ScanSlot(image: viewModel.frontPhoto,
                             placeholder: isPassport ? "passport" : "frontID",
                             buttonTitle: isPassport ? String(.scanPassport) : String(.scanIdFront)) {
                        scannerSide = .front
                    }
                    // Pasaport ve "Diğer" tek sayfadır.
                    if !selectedCardType.isSinglePage {
                        ScanSlot(image: viewModel.backPhoto, placeholder: "backID", buttonTitle: String(.scanIdBack)) {
                            scannerSide = .back
                        }
                    }
                }
                .padding(.top, IDSpacing.lg)
                .padding(.bottom, IDSpacing.xl)
                .padding(.horizontal, IDSpacing.lg)
            }

            SDKButton(title: String(.continuePage), isDisabled: !viewModel.canContinue) {
                coordinator.advanceToNextModule()
            }
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
        }
        .background(IDColor.adaptiveSurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.card))
        .sdkReadableWidth()
        .ignoresSafeArea(edges: .bottom)
    }

    private func titleBlock(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: IDSpacing.sm) {
            Text(title)
                .font(IDFont.displayMedium(.semibold))
                .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
            Text(subtitle)
                .font(IDFont.bodyRegular(.regular))
                .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                .lineSpacing(4)
        }
    }
}

// MARK: - Belge tipi satırı (radyo)

private struct CardTypeRow: View {
    let icon: SDKIconKey
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var selection: SDKSelectionAppearance { SDKTheme.shared.selection }

    var body: some View {
        let textColor = isSelected ? IDColor.selectedItemText(for: colorScheme) : IDColor.unselectedItemText(for: colorScheme)
        Button(action: action) {
            HStack(spacing: 12) {
                Image.sdk(icon)
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundColor(textColor)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(IDFont.bodyRegular(.regular))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? IDColor.selectedItemText(for: colorScheme)
                                           : (colorScheme == .dark ? IDColor.darkMuted : IDColor.divider), lineWidth: 2)
                        .frame(width: selection.checkboxSize ?? 20, height: selection.checkboxSize ?? 20)
                    if isSelected {
                        Circle()
                            .fill(IDColor.selectedItemText(for: colorScheme))
                            .frame(width: selection.radioDotSize ?? 10, height: selection.radioDotSize ?? 10)
                    }
                }
            }
            .padding(.horizontal, IDSpacing.lg)
            .frame(minHeight: selection.rowMinHeight ?? 48)
            .background(
                RoundedRectangle(cornerRadius: selection.cornerRadius ?? IDRadius.md)
                    .fill(isSelected ? IDColor.selectedItemBackground(for: colorScheme)
                                     : IDColor.unselectedItemBackground(for: colorScheme))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Ön / arka yüz slotu

private struct ScanSlot: View {
    let image: UIImage?
    /// SDK kaynak paketindeki (`Bundle.sdkUI`) örnek kart görseli.
    let placeholder: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image.sdk(.camera).font(.system(size: 12, weight: .semibold))
                        Text(.corePullAgain).font(IDFont.caption(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, IDSpacing.md)
                    .padding(.vertical, IDSpacing.xs)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                }
                .padding(IDSpacing.sm)
            } else {
                Image(placeholder, bundle: .sdkUI).resizable().scaledToFit().frame(maxWidth: .infinity)
                Button(action: action) {
                    Text(buttonTitle)
                        .font(IDFont.bodyRegular(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, IDSpacing.xl)
                        .frame(height: 44)
                        .background(IDColor.primary)
                        .clipShape(SDKButtonShape.themed())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: IDRadius.lg).stroke(IDColor.inkBorder, lineWidth: 1))
    }
}

// MARK: - Tarayıcı kapağı

/// SDK'nın public `IdentityScannerView`'ını tam ekran açar; sonuç kırpılmış görüntüdür (iptalde nil).
struct IdCardScannerCover: View {
    let side: IdCardSide
    let onResult: (UIImage?) -> Void

    @State private var isTorchOn = false
    @State private var isTorchAvailable = false

    private var cardType: CardType? { IdentifyManager.shared.selectedCardType }

    var body: some View {
        ZStack(alignment: .top) {
            IdentityScannerView(
                profile: profile,
                style: QuadrilateralStyle(
                    strokeColor: SDKTheme.shared.capture.guideStrokeColor ?? IDColor.primary.opacity(0.55),
                    lockedStrokeColor: SDKTheme.shared.capture.guideLockedColor ?? IDColor.primary,
                    lineWidth: 2.5
                ),
                configuration: configuration,
                externalTorchOn: $isTorchOn,
                onTorchAvailability: { isTorchAvailable = $0 },
                speechKey: cardType == .passport ? .passportTts : (side == .back ? .idCardBackTts : .idCardFrontTts),
                speechModule: .idCard
            ) { result in
                switch result {
                case .success(let document): onResult(document.croppedImage)
                case .failure:               onResult(nil)
                }
            }
            .ignoresSafeArea()

            SDKNavigationBar(
                style: .overlay,
                onBack: { onResult(nil) },
                trailing: isTorchAvailable && configuration.showsTorchButton ? AnyView(torchButton) : nil
            )
        }
    }

    private var profile: DocumentProfile {
        switch cardType {
        case .passport:  return .passport
        case .oldSchool: return .generic
        default:         return side == .back ? .turkishIDBack : .turkishIDFront
        }
    }

    /// Pasaport kendi HUD metinlerini, kimlik arka yüzü kendi netlik eşiklerini kullanır.
    private var configuration: ScannerConfiguration {
        let base: ScannerConfiguration
        switch cardType {
        case .passport: base = .passport
        case .oldSchool: base = .default
        default: base = side == .back ? .idBack : .default
        }
        return base.withHapticModule(.idCard)
    }

    private var torchButton: some View {
        Button { isTorchOn.toggle() } label: {
            ZStack {
                Circle()
                    .fill(SDKTheme.shared.capture.overlayButtonFill ?? Color.white.opacity(0.15))
                    .overlay(Circle().stroke(SDKTheme.shared.capture.overlayButtonBorder ?? Color.white.opacity(0.2), lineWidth: 1))
                Image.sdk(isTorchOn ? .torchOn : .torchOff)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Kimlik — Özel Ekran") {
    SDKModulePreviewHost { IdCardCustomView() }
}
