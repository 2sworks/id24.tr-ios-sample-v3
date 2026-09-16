//
//  NfcCustomView.swift
//  IdentifySample
//
//  NFC ÇİP OKUMA — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKNfcView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.nfc) { NfcCustomView() }
//
//  Görev dağılımı:
//    • MRZ anahtarı, çip okuma (BAC/PACE), çip ↔ form karşılaştırması, yükleme → `SDKNfcViewModel`
//    • Sistem NFC sayfası iOS tarafından açılır; bu ekran yalnızca yönerge + düzeltme formunu çizer
//
//  ViewModel kullanımı:
//    startNFC()                   okumayı başlatır; başarıda onCompleted
//    isPassport / introTtsKey     belge tipine göre metin ve sesli yönerge
//    nfcStatus / nfcCompleted     durum satırı
//    showEditScreen               MRZ okunamadıysa düzeltme formu açılır
//    serialNo / birthDate / validDate (yyMMdd) + saveManualDates()   elle düzeltme
//    SDKNfcViewModel.isSerialValid(_:isPassport:)                    seri no doğrulaması
//    onRetryFromPreviousStep      çip verisi kimlik fotoğrafıyla tutmadı → bir önceki adıma dön
//    onCompleted / onSkipRequested / onFlowFailed
//

import SwiftUI
import IdentifySDK

struct NfcCustomView: View {

    @StateObject private var viewModel = SDKNfcViewModel()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var pulseActive = false

    var body: some View {
        ZStack(alignment: .top) {
            IDColor.moduleBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 0) {
                SDKNavigationBar(style: .overlay, onBack: { coordinator.popBack() })
                cardArea
            }
        }
        .blur(radius: viewModel.showEditScreen ? 8 : 0)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showEditScreen)
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
        .idErrorAlert($viewModel.errorMessage, onDismiss: { viewModel.consumePendingAlertAction() })
        .sheet(isPresented: $viewModel.showEditScreen) {
            if #available(iOS 16.0, *) {
                NfcEditSheet(viewModel: viewModel).presentationDetents([.height(550)])
            } else {
                NfcEditSheet(viewModel: viewModel)
            }
        }
        .onAppear {
            pulseActive = true
            viewModel.onCompleted = { coordinator.advanceToNextModule() }
            viewModel.onSkipRequested = { coordinator.skipCurrentModule() }
            viewModel.onFlowFailed = { coordinator.finishFlowAsFailed() }
            // NFC ilk modülse dönülecek adım yoktur; ekranda kalınır.
            viewModel.onRetryFromPreviousStep = {
                if coordinator.path.count > 1 { coordinator.popBack() }
            }
            // Yönerge belge tipine göre değiştiği için SDK bu rotayı otomatik okumaz.
            SDKSpeechService.shared.speak(viewModel.introTtsKey, in: .nfc)
        }
        .onDisappear { pulseActive = false }
    }

    private var cardArea: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: IDSpacing.xl) {
                    VStack(alignment: .leading, spacing: IDSpacing.sm) {
                        Text(.nfcVerifyTitle)
                            .font(IDFont.displayMedium(.semibold))
                            .foregroundColor(.white)
                        Text(viewModel.isPassport ? String(.nfcChipInstructionPassport) : String(.nfcChipInstruction))
                            .font(IDFont.bodyRegular(.regular))
                            .foregroundColor(.white.opacity(0.75))
                            .lineSpacing(4)
                    }

                    cardIllustration
                        .frame(maxWidth: .infinity)

                    VStack(spacing: IDSpacing.sm) {
                        Text(.nfcScanTitle)
                            .font(IDFont.displayMedium(.semibold))
                            .foregroundColor(.white)
                        Text(viewModel.isPassport ? String(.nfcHoldInstructionPassport) : String(.nfcHoldInstruction))
                            .font(IDFont.bodyRegular(.regular))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity)

                    if !viewModel.nfcStatus.isEmpty {
                        Text(viewModel.nfcStatus)
                            .font(IDFont.bodySmall(.medium))
                            .foregroundColor(viewModel.nfcCompleted ? IDColor.successBright : .white.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, IDSpacing.xxl)
                .padding(.bottom, IDSpacing.xl)
                .padding(.horizontal, IDSpacing.lg)
            }

            SDKButton(title: String(.nfcStart), style: .secondary, isLoading: viewModel.isLoading) {
                viewModel.startNFC()
            }
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
        }
        .background(IDColor.moduleBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.card))
        .sdkReadableWidth()
        .ignoresSafeArea(edges: .bottom)
    }

    private var cardIllustration: some View {
        ZStack {
            Image.sdk(.nfcBack)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 300)
                .scaleEffect(pulseActive ? 1.08 : 0.96)
                .opacity(pulseActive ? 0.55 : 0.95)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulseActive)
            Image.sdk(viewModel.isPassport ? .nfcPassportFront : .nfcFront)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 300)
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
                .padding(.trailing, IDSpacing.lg)
        }
        .frame(width: 300, height: 300)
    }
}

// MARK: - MRZ düzeltme formu

private struct NfcEditSheet: View {

    @ObservedObject var viewModel: SDKNfcViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var birthDateText = ""
    @State private var validDateText = ""

    private static var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }
    private static var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday }

    private var isSerialValid: Bool { SDKNfcViewModel.isSerialValid(viewModel.serialNo, isPassport: viewModel.isPassport) }
    private var canSave: Bool {
        guard isSerialValid,
              let birth = MRZDate.display.date(from: birthDateText),
              let valid = MRZDate.display.date(from: validDateText) else { return false }
        return birth < Self.startOfToday && valid >= Self.startOfToday
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer().frame(width: 32)
                Spacer()
                Text(.nfcEditInfoTitle)
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

            VStack(alignment: .leading, spacing: IDSpacing.xl) {
                VStack(alignment: .leading, spacing: IDSpacing.sm) {
                    Text(.nfcInfoNotRead)
                        .font(IDFont.bodyMedium(.semibold))
                        .foregroundColor(IDColor.error)
                    Text(.nfcManualEntry)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .lineSpacing(4)
                }

                VStack(alignment: .leading, spacing: IDSpacing.lg) {
                    field(title: String(viewModel.isPassport ? .serialNoPassport : .serialNoShort),
                          error: (!viewModel.serialNo.isEmpty && !isSerialValid)
                            ? String(viewModel.isPassport ? .nfcSerialInvalidPassport : .nfcSerialInvalid) : nil) {
                        ZStack(alignment: .leading) {
                            placeholder(viewModel.isPassport ? "U12345678" : "A32R17869", visible: viewModel.serialNo.isEmpty)
                            TextField("", text: $viewModel.serialNo)
                                .font(IDFont.bodySmall())
                                .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                                .keyboardType(.asciiCapable)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                        }
                    }
                    // Doğum tarihi en fazla dün, geçerlilik tarihi en erken bugün.
                    field(title: String(.coreBirthday)) {
                        dateField(text: $birthDateText, range: Date.distantPast...Self.yesterday)
                    }
                    field(title: String(.nfcExpDate)) {
                        dateField(text: $validDateText, range: Self.startOfToday...Date.distantFuture)
                    }
                }
            }
            .padding(.top, IDSpacing.xl)
            .padding(.horizontal, IDSpacing.lg)

            Spacer()

            SDKButton(title: String(.coreUpdate), style: .primary, isDisabled: !canSave) {
                viewModel.birthDate = MRZDate.toMrz(birthDateText)
                viewModel.validDate = MRZDate.toMrz(validDateText)
                viewModel.saveManualDates()
            }
            .animation(.easeInOut(duration: 0.2), value: canSave)
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .customDismissKeyboardOnTap()
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
        .idErrorAlert($viewModel.errorMessage)
        .onAppear {
            birthDateText = MRZDate.toDisplay(viewModel.birthDate)
            validDateText = MRZDate.toDisplay(viewModel.validDate)
        }
    }

    private func placeholder(_ text: String, visible: Bool) -> some View {
        Text(text)
            .font(IDFont.bodySmall())
            .foregroundColor(IDColor.inkLight)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
    }

    private func field<Content: View>(title: String, error: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: IDSpacing.sm) {
            Text(title)
                .font(IDFont.bodySmall(.medium))
                .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            content()
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

    /// SDK ekranı klavye yerine tekerlek açan bir UIKit alanı kullanır; burada SwiftUI'ın
    /// sıkıştırılmış DatePicker'ı aynı işi görür (elle yazım yok, aralık sınırlı).
    private func dateField(text: Binding<String>, range: ClosedRange<Date>) -> some View {
        let date = Binding<Date>(
            get: { MRZDate.display.date(from: text.wrappedValue) ?? Self.startOfToday },
            set: { text.wrappedValue = MRZDate.display.string(from: $0) }
        )
        return HStack {
            placeholder("dd.MM.yyyy", visible: text.wrappedValue.isEmpty)
            Spacer()
            DatePicker("", selection: date, in: range, displayedComponents: .date)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "tr_TR"))
        }
    }
}

// MARK: - MRZ tarih biçimleri

/// ViewModel tarihleri MRZ biçiminde (`yyMMdd`) tutar; form `dd.MM.yyyy` gösterir.
private enum MRZDate {
    static let display: DateFormatter = formatter("dd.MM.yyyy")
    static let mrz: DateFormatter = formatter("yyMMdd")

    static func toMrz(_ displayText: String) -> String {
        display.date(from: displayText).map(mrz.string(from:)) ?? ""
    }

    static func toDisplay(_ mrzText: String) -> String {
        mrz.date(from: mrzText).map(display.string(from:)) ?? ""
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "tr_TR")
        return f
    }
}

#Preview("NFC — Özel Ekran") {
    SDKModulePreviewHost { NfcCustomView() }
}
