//
//  SelfieCustomView.swift
//  IdentifySample
//
//  SELFIE — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKSelfieView` ekranının public API ile yazılmış birebir karşılığıdır.
//  Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır.
//
//      registry.override(.selfie) { SelfieCustomView() }
//
//  Görev dağılımı:
//    • İş mantığı (yüz yönlendirme, otomatik çekim zamanlaması, yükleme, karşılaştırma) →
//      `SDKSelfieViewModel` (SDK)
//    • Kamera, çizim ve navigasyon → bu dosya (host kodu)
//
//  ViewModel kullanımı:
//    updatePreviewSize(_:)            önizleme boyutu (oval hesabı için) — ZORUNLU
//    analyzeFrame(_:cameraPosition:)  her kamera karesi — ZORUNLU
//    shouldAutoCapture == true        → fotoğraf çekilir ve presentCaptured(image:) çağrılır
//    confirmSelfie()                  kullanıcı onayı → yükleme
//    reset()                          tekrar çek
//    canContinue == true              → coordinator.advanceToNextModule()
//    onSkipRequested / onFlowFailed   → coordinator.skipCurrentModule() / finishFlowAsFailed()
//    errorMessage + consumePendingAlertAction()  hata alert'i kapanınca bekleyen aksiyon
//
//  Kopyalanacak dosyalar: bu dosya + CustomKit/CustomCameraPreview.swift + CustomKit/CustomComponents.swift
//

import SwiftUI
import AVFoundation
import IdentifySDK

struct SelfieCustomView: View {

    @StateObject private var viewModel = SDKSelfieViewModel()
    @StateObject private var camera = SelfieCameraController()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.sdkPreviewMode) private var sdkPreviewMode

    @State private var isCameraActive = true

    var body: some View {
        ZStack {
            backgroundLayer
            if isCameraActive {
                faceOvalOverlay
            }
            VStack(spacing: 0) {
                SDKNavigationBar(style: .overlay, onBack: { coordinator.popBack() })
                Spacer()
                bottomInfoArea
                if hasActionButtons {
                    actionButtons
                        .padding(.bottom, 32)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: hasActionButtons)
        }
        .onAppear {
            viewModel.onSkipRequested = { coordinator.skipCurrentModule() }
            viewModel.onFlowFailed = { coordinator.finishFlowAsFailed() }
            camera.onSessionError = { viewModel.errorMessage = $0 }
            // Kareler kamera kuyruğundan gelir; analyzeFrame nonisolated olduğu için doğrudan verilir.
            camera.setFrameHandler { [viewModel] buffer, position in
                viewModel.analyzeFrame(buffer, cameraPosition: position)
            }
            if !sdkPreviewMode { camera.start() }
        }
        .onDisappear {
            camera.setFrameHandler(nil)
            camera.stop()
        }
        // ViewModel yüz ovale oturup yeterince sabit kalınca bu bayrağı açar.
        .onChange(of: viewModel.shouldAutoCapture) { shouldCapture in
            guard shouldCapture, isCameraActive else { return }
            captureNow()
        }
        // Karşılaştırma tutmazsa ViewModel kendisi reset() çağırır; canlı kameraya dön.
        .onChange(of: viewModel.selfieImage == nil) { photoCleared in
            guard photoCleared, !viewModel.canContinue else { return }
            isCameraActive = true
        }
        // Yükleme başarılı: ~1 sn onay işareti, sonra sonraki modül.
        .onChange(of: viewModel.canContinue) { success in
            guard success else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                coordinator.advanceToNextModule()
            }
        }
        .holdUprightWarning(isActive: isCameraActive && !sdkPreviewMode, topPadding: 72)
        .idErrorAlert($viewModel.errorMessage, onDismiss: { viewModel.consumePendingAlertAction() })
    }

    // MARK: - Durum

    /// Fotoğraf önizlemede, henüz yüklenmedi ve yükleme sürmüyor → Tekrar Çek + Onayla.
    private var isPreviewingCapture: Bool {
        viewModel.selfieImage != nil && !viewModel.canContinue && !viewModel.isLoading
    }

    private var hasActionButtons: Bool { isPreviewingCapture || viewModel.isLoading || viewModel.canContinue }

    /// Kareyi alır ve ONAY için önizlemeye verir. Yükleme burada yapılmaz; kullanıcı onaylayınca olur.
    private func captureNow() {
        camera.capturePhoto { image in
            guard let image else {
                viewModel.reset()
                return
            }
            isCameraActive = false
            viewModel.presentCaptured(image: image)
        }
    }

    // MARK: - Katmanlar

    private var backgroundLayer: some View {
        Group {
            if isCameraActive {
                CustomCameraPreview(session: camera.session, placeholderIcon: "person.crop.square")
                    .ignoresSafeArea()
            } else if let img = viewModel.selfieImage {
                GeometryReader { geo in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(colors: [.clear, .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            } else {
                Color(white: 0.12).ignoresSafeArea()
            }
        }
    }

    /// Sabit oval: dışı karartılır, yüz oturunca kenar yeşile döner.
    /// Oval ölçüsü SDK'nın analizde kullandığıyla AYNI olmalıdır, yoksa yönlendirme kayar.
    private var faceOvalOverlay: some View {
        GeometryReader { geo in
            let oval = Self.ovalRect(in: geo.size)
            ZStack {
                Color.black.opacity(SDKTheme.shared.capture.maskOpacity ?? 0.55)
                    .mask(
                        ZStack {
                            Rectangle()
                            Ellipse()
                                .frame(width: oval.width, height: oval.height)
                                .position(x: oval.midX, y: oval.midY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )

                Ellipse()
                    .stroke(
                        viewModel.isFaceAligned
                            ? (SDKTheme.shared.capture.faceAlignedColor ?? .green)
                            : (SDKTheme.shared.capture.faceIdleColor ?? .white.opacity(0.6)),
                        lineWidth: SDKTheme.shared.capture.guideLineWidth ?? 4
                    )
                    .frame(width: oval.width, height: oval.height)
                    .position(x: oval.midX, y: oval.midY)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isFaceAligned)
            }
            .onAppear { viewModel.updatePreviewSize(geo.size) }
            .onChange(of: geo.size) { viewModel.updatePreviewSize($0) }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// SDK analizindeki oval geometrisi: genişlik = yüz kılavuzu × 0.75, yükseklik = genişlik × 1.35,
    /// merkezin 20 pt yukarısı.
    static func ovalRect(in size: CGSize) -> CGRect {
        let width = SDKLayout.faceGuideWidth(in: size.width) * 0.75
        let height = width * 1.35
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2 - 20, width: width, height: height)
    }

    private var bottomInfoArea: some View {
        VStack(spacing: 8) {
            Text(.selfieTitle)
                .font(IDFont.custom(18, .semibold))
                .foregroundColor(.white)

            Group {
                if viewModel.canContinue {
                    Text(.selfieSuccessDesc).foregroundColor(.white.opacity(0.85))
                } else if isPreviewingCapture {
                    Text(.selfieConfirmPrompt).foregroundColor(.white.opacity(0.9))
                } else {
                    Text(viewModel.guidanceText).foregroundColor(.white.opacity(0.9))
                }
            }
            .font(IDFont.custom(15, .medium))
            .multilineTextAlignment(.center)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: viewModel.guidanceText)
            .animation(.easeInOut(duration: 0.3), value: viewModel.canContinue)
            .animation(.easeInOut(duration: 0.3), value: isPreviewingCapture)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        ZStack {
            HStack {
                if isPreviewingCapture {
                    CustomCircleButton(background: .white.opacity(0.2), size: 56, action: {
                        viewModel.reset()
                        isCameraActive = true
                    }) {
                        Image.sdk(.retry)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.trailing, 170)

            Group {
                if viewModel.canContinue {
                    filledCircle { Image.sdk(.checkmark).font(.system(size: 22, weight: .bold)).foregroundColor(.white) }
                } else if viewModel.isLoading {
                    filledCircle { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.2) }
                } else if isPreviewingCapture {
                    CustomCircleButton(
                        background: SDKTheme.shared.controls.shutterFill ?? IDColor.primary,
                        size: (SDKTheme.shared.controls.shutterSize ?? 72) + 8,
                        action: { viewModel.confirmSelfie() }
                    ) {
                        Image.sdk(.checkmark).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPreviewingCapture)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.canContinue)
    }

    private func filledCircle<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Circle().fill(IDColor.primary).frame(width: 80, height: 80)
            content()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Kamera

/// Ön kamera: canlı kare akışı (analiz) + tam çözünürlüklü fotoğraf.
@MainActor
final class SelfieCameraController: NSObject, ObservableObject {

    let session = AVCaptureSession()
    var onSessionError: ((String) -> Void)?

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameQueue = DispatchQueue(label: "sample.selfie.frames")
    private var device: AVCaptureDevice?
    private var rotationCoordinator: Any?
    private var captureCompletion: ((UIImage?) -> Void)?
    private var errorObserver: NSObjectProtocol?

    /// Kare işleyicisi kamera kuyruğundan okunur; kilitle korunur.
    private nonisolated let frameLock = NSLock()
    private nonisolated(unsafe) var frameHandler: ((CVPixelBuffer, AVCaptureDevice.Position) -> Void)?

    nonisolated func setFrameHandler(_ handler: ((CVPixelBuffer, AVCaptureDevice.Position) -> Void)?) {
        frameLock.lock(); frameHandler = handler; frameLock.unlock()
    }

    func start() {
        errorObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionRuntimeError, object: session, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onSessionError?(String(.cameraAccessError)) }
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.configure()
        }
    }

    func stop() {
        if let errorObserver { NotificationCenter.default.removeObserver(errorObserver) }
        errorObserver = nil
        session.stopRunning()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard captureCompletion == nil else { return }
        captureCompletion = completion
        if let connection = photoOutput.connection(with: .video) {
            if #available(iOS 17.0, *), let rc = rotationCoordinator as? AVCaptureDevice.RotationCoordinator {
                let angle = rc.videoRotationAngleForHorizonLevelCapture
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    private func configure() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            onSessionError?(String(.cameraAccessError))
            return
        }
        session.addInput(input)

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        if !session.outputs.contains(videoOutput), session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
            session.addOutput(videoOutput)
        }
        // Analiz ham (aynalanmamış) kare bekler; fotoğraf ise ön kamerada aynalanır.
        if let c = videoOutput.connection(with: .video), c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = false
        }
        if let c = photoOutput.connection(with: .video), c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = true
        }

        self.device = device
        if #available(iOS 17.0, *) {
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        }
        session.commitConfiguration()
        NotificationCenter.default.post(name: .customCameraReconfigured, object: session)
        session.startRunning()
    }
}

extension SelfieCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameLock.lock(); let handler = frameHandler; frameLock.unlock()
        handler?(buffer, .front)
    }
}

extension SelfieCameraController: AVCapturePhotoCaptureDelegate {
    /// Deklanşör anı: SDK'nın çekim öncesi titreşimi burada biter.
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        SDKCaptureHaptics.shared.finish()
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:)).map(Self.normalizedUp)
        Task { @MainActor in
            self.captureCompletion?(error == nil ? image : nil)
            self.captureCompletion = nil
        }
    }

    /// Yönü piksele gömer (`.up`); önizleme ve yükleme aynı görüntüyü kullanır.
    nonisolated private static func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

#Preview("Selfie — Özel Ekran") {
    SDKModulePreviewHost { SelfieCustomView() }
}
