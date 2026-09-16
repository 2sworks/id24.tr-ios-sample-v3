//
//  SignatureCustomView.swift
//  IdentifySample
//
//  İMZA — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKSignatureView` ekranının public API ile yazılmış karşılığıdır.
//
//      registry.override(.signature) { SignatureCustomView() }
//
//  Görev dağılımı:
//    • İmzanın sunucuya yüklenmesi → `SDKSignatureViewModel`
//    • İmza tuvali ve çizim → bu dosya. SDK ekranı SwiftSignatureView paketini kullanır; bu örnek
//      ek bağımsızlık gerektirmesin diye sistemin PencilKit'ini kullanır. Tuval başka bir
//      kütüphaneyle değiştirilebilir — SDK'ya giden tek şey bir `UIImage`'dir.
//
//  ViewModel kullanımı:
//    signatureDidDraw() / clearSignature()   Devam butonunun durumu (signatureDrawn)
//    uploadSignature(image:)                 kırpılmış, beyaz zemin üzerine koyu imza
//    onCompleted → coordinator.advanceToNextModule()
//

import SwiftUI
import PencilKit
import IdentifySDK

struct SignatureCustomView: View {

    @StateObject private var viewModel = SDKSignatureViewModel()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var pad = SignaturePad()
    private var canvas: PKCanvasView { pad.canvas }

    var body: some View {
        ZStack(alignment: .top) {
            IDColor.moduleBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 10) {
                SDKNavigationBar(
                    style: .progress(steps: coordinator.progressTotal, current: coordinator.progressStep),
                    title: String(.signatureVerifyTitle),
                    subtitle: String(.signatureVerifyDesc),
                    onBack: { coordinator.popBack() }
                )
                cardArea
            }
        }
        .onAppear {
            viewModel.onCompleted = { coordinator.advanceToNextModule() }
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(SDKTheme.shared.capture.maskOpacity ?? 0.3).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .idErrorAlert($viewModel.errorMessage)
    }

    private var cardArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: IDSpacing.sm) {
                Text(.signatureTitle)
                    .font(IDFont.displayMedium(.semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                Text(.signatureInfo)
                    .font(IDFont.bodyRegular(.regular))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                    .lineSpacing(4)
            }
            .padding(.top, IDSpacing.xl)
            .padding(.horizontal, IDSpacing.lg)

            signatureBox
                .padding(.top, IDSpacing.xl)
                .padding(.horizontal, IDSpacing.lg)

            Spacer()

            SDKButton(title: String(.continuePage), isDisabled: !viewModel.signatureDrawn) {
                guard let image = signatureImageForServer() else { return }
                viewModel.uploadSignature(image: image)
            }
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IDColor.adaptiveSurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.card))
        .sdkReadableWidth()
        .ignoresSafeArea(edges: .bottom)
    }

    private var signatureBox: some View {
        ZStack(alignment: .topLeading) {
            SignatureCanvas(canvas: canvas, isDark: colorScheme == .dark) {
                viewModel.signatureDidDraw()
            }
            .clipShape(RoundedRectangle(cornerRadius: IDRadius.xl))

            Button(action: {
                canvas.drawing = PKDrawing()
                viewModel.clearSignature()
            }) {
                Image.sdk(.trash)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(IDColor.inkMid)
                    .frame(width: 39, height: 39)
                    .background(
                        Circle()
                            .fill(colorScheme == .dark ? Color(white: 0.2) : Color.white)
                            .overlay(Circle().stroke(IDColor.divider, lineWidth: 1))
                    )
            }
            .padding(.top, IDSpacing.lg)
            .padding(.leading, IDSpacing.lg)
        }
        .frame(height: 189)
        .background(colorScheme == .dark ? Color(white: 0.12) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: IDRadius.xl).stroke(IDColor.inkBorder, lineWidth: 1))
    }

    /// Mürekkebe göre kırpılmış imza; sunucu her zaman beyaz zemin üzerine siyah imza bekler.
    private func signatureImageForServer() -> UIImage? {
        let drawing = canvas.drawing
        guard !drawing.bounds.isEmpty else { return nil }
        let rect = drawing.bounds.insetBy(dx: -8, dy: -8)
        // Karanlık modda çizgiler beyaz olduğundan önce açık renk arayüzde üretilir.
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: UIScreen.main.scale)
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
    }
}

// MARK: - PencilKit tuvali

/// Tuval ekran boyunca tek örnek kalır (temizleme ve görüntü alma aynı nesneye yapılır).
private final class SignaturePad: ObservableObject {
    let canvas = PKCanvasView()
}

private struct SignatureCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    let isDark: Bool
    let onDraw: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        apply()
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.onDraw = onDraw
        apply()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onDraw: onDraw) }

    /// PencilKit siyah mürekkebi karanlık modda otomatik olarak beyaza çevirir.
    private func apply() {
        canvas.backgroundColor = isDark ? UIColor(white: 0.12, alpha: 1) : .white
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDraw: () -> Void
        init(onDraw: @escaping () -> Void) { self.onDraw = onDraw }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if !canvasView.drawing.bounds.isEmpty { onDraw() }
        }
    }
}

#Preview("İmza — Özel Ekran") {
    SDKModulePreviewHost { SignatureCustomView() }
}
