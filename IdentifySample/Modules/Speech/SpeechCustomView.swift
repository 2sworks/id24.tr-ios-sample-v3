//
//  SpeechCustomView.swift
//  IdentifySample
//
//  KONUŞMA TESTİ — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKSpeechRecView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.speech) { SpeechCustomView() }
//
//  Görev dağılımı:
//    • Hedef kelime (sunucudan), mikrofon kaydı, konuşma tanıma, eşleştirme, sunucu bildirimi
//      → `SDKSpeechRecViewModel`
//    • Basılı tutarak konuşma jesti ve çizim → bu dosya
//
//  ViewModel kullanımı:
//    targetWord                        okunacak kelime
//    startRecording() / stopRecording()   basılı tutma başlangıcı / bitişi
//    recognizedText / speechSuccess    tanınan metin ve eşleşme
//    confirmSpeech()                   Devam → onCompleted → coordinator.advanceToNextModule()
//
//  Sesli yönerge okunurken (`SDKSpeechService.shared.isSpeaking`) mikrofon kilitlenir; aksi hâlde
//  kullanıcının sesi yerine yönergenin sesi kaydedilir.
//
//  Kopyalanacak dosyalar: bu dosya + CustomKit/CustomComponents.swift (başarı banner'ı)
//

import SwiftUI
import IdentifySDK

struct SpeechCustomView: View {

    @StateObject private var viewModel = SDKSpeechRecViewModel()
    @ObservedObject private var speech = SDKSpeechService.shared
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var micScale: CGFloat = 1.0

    private var accentOrange: Color { IDColor.accentWarning }
    private var isMicLocked: Bool { speech.isSpeaking }
    private var micColor: Color {
        if viewModel.isRecording { return IDColor.error }
        return isMicLocked ? accentOrange.opacity(0.4) : accentOrange
    }

    var body: some View {
        ZStack(alignment: .top) {
            IDColor.moduleBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 10) {
                SDKNavigationBar(
                    style: .progress(steps: coordinator.progressTotal, current: coordinator.progressStep),
                    title: String(.speechTestTitle),
                    subtitle: String(.speechVerifyDesc),
                    onBack: { coordinator.popBack() }
                )
                cardArea
            }
        }
        .customSuccessBanner(String(.soundRecogOk), isVisible: viewModel.speechSuccess)
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(SDKTheme.shared.capture.maskOpacity ?? 0.3).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            viewModel.onCompleted = { coordinator.advanceToNextModule() }
        }
        .idErrorAlert($viewModel.errorMessage)
    }

    private var cardArea: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: IDSpacing.xl) {
                VStack(alignment: .leading, spacing: IDSpacing.sm) {
                    Text(.speechTestTitle)
                        .font(IDFont.displayMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    Text(.speechHoldInstruction)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .lineSpacing(4)
                }

                Text(viewModel.targetWord)
                    .multilineTextAlignment(.center)
                    .font(IDFont.custom(40, .heavy))
                    .foregroundStyle(LinearGradient(colors: [.red, .orange, .green, .teal, .blue], startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, IDSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: IDRadius.lg)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    )
            }
            .padding(.top, IDSpacing.xxl)
            .padding(.horizontal, IDSpacing.lg)

            Spacer()
            micButton
            Spacer()

            VStack(alignment: .leading, spacing: IDSpacing.xs) {
                Text(.spokenWordLabel)
                    .font(IDFont.bodySmall(.regular))
                    .foregroundColor(accentOrange)
                Text(viewModel.recognizedText.isEmpty ? "—" : viewModel.recognizedText)
                    .font(IDFont.displayMedium(.bold))
                    .foregroundColor(accentOrange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(IDSpacing.lg)
            .background(RoundedRectangle(cornerRadius: IDRadius.lg).fill(accentOrange.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: IDRadius.lg)
                    .strokeBorder(accentOrange.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, 16)

            SDKButton(title: String(.continuePage), isDisabled: !viewModel.speechSuccess) {
                viewModel.confirmSpeech()
            }
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
        }
        .background(IDColor.adaptiveSurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.card))
        .sdkReadableWidth()
        .ignoresSafeArea(edges: .bottom)
    }

    /// Basılı tutunca kayıt başlar, bırakınca durur.
    private var micButton: some View {
        ZStack {
            Circle()
                .fill(micColor)
                .frame(width: 80, height: 80)
                .shadow(color: micColor.opacity(0.4), radius: 12, y: 6)
            Image.sdk(viewModel.isRecording ? .stopRecord : .mic)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
        }
        .scaleEffect(micScale)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
        .animation(.easeInOut(duration: 0.2), value: isMicLocked)
        .allowsHitTesting(!isMicLocked)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isMicLocked, !viewModel.isRecording else { return }
                    viewModel.startRecording()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { micScale = 1.15 }
                }
                .onEnded { _ in
                    viewModel.stopRecording()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { micScale = 1.0 }
                }
        )
        .onChange(of: isMicLocked) { locked in
            // Kayıt sürerken yönerge okunmaya başlarsa mikrofon bırakılır.
            guard locked, viewModel.isRecording else { return }
            viewModel.stopRecording()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { micScale = 1.0 }
        }
    }
}

#Preview("Konuşma — Özel Ekran") {
    SDKModulePreviewHost { SpeechCustomView() }
}
