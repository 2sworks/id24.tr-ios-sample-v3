//
//  LivenessCustomView.swift
//  IdentifySample
//
//  CANLILIK — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKLivenessView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.liveness) { LivenessCustomView() }
//
//  Görev dağılımı:
//    • Adım sırası, adım metni, sesli komut, kare yükleme, yüz karşılaştırma, ekran kaydı
//      ve video yükleme → `SDKLivenessViewModel` (SDK)
//    • ARKit yüz takibi ve ifade algılama (göz kırpma / gülümseme / sola-sağa dönme) ve çizim
//      → bu dosya (host kodu). Eşikler bu dosyada.
//
//  ViewModel kullanımı:
//    prepareRecording()      ekran açılınca; kayıt hazır olunca onRecordingReady gelir → ARKit'i O ZAMAN aç
//    currentStep / allowX    hangi ifadenin beklendiği
//    uploadFrame(image:)     ifade algılanınca o anın karesi; başarıda sonraki adım gelir
//    allStepsCompleted       ARKit'i kapatın; kayıt yüklemesini ViewModel yapar
//    noteWillResignActive() / noteDidBecomeActive()  uygulama aktifliği (kayıt kesintisi tespiti)
//    abandonRecording()      ekrandan çıkarken
//    reportFaceTrackingUnsupported()  cihaz ARKit yüz takibi desteklemiyorsa
//    onCompleted / onSkipRequested / onFlowFailed → coordinator
//
//  Kopyalanacak dosyalar: bu dosya + CustomKit/CustomCameraPreview.swift (yer tutucu için)
//

import SwiftUI
import ARKit
import IdentifySDK

struct LivenessCustomView: View {

    @StateObject private var viewModel = SDKLivenessViewModel()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.sdkPreviewMode) private var sdkPreviewMode

    var body: some View {
        cameraLayer
            .overlay(alignment: .bottom) { bottomInfoArea }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                SDKNavigationBar(style: .overlay, onBack: { coordinator.popBack() })
            }
            .overlay {
                if viewModel.isLoading { loadingOverlay }
            }
            .holdUprightWarning(isActive: !sdkPreviewMode, topPadding: 72)
            .onAppear {
                viewModel.onCompleted = { coordinator.advanceToNextModule() }
                viewModel.onSkipRequested = { coordinator.skipCurrentModule() }
                viewModel.onFlowFailed = { coordinator.finishFlowAsFailed() }
            }
            .idErrorAlert($viewModel.errorMessage, onDismiss: { viewModel.consumePendingAlertAction() })
    }

    @ViewBuilder
    private var cameraLayer: some View {
        if sdkPreviewMode || CustomRuntime.isXcodePreview {
            CustomCameraPlaceholder(systemIcon: "faceid")
        } else {
            LivenessARView(viewModel: viewModel)
        }
    }

    private var bottomInfoArea: some View {
        HStack(spacing: 12) {
            if let iconName = stepIconName {
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(viewModel.stepInstruction)
                .foregroundColor(.white)
                .font(IDFont.custom(20, .semibold))
                .multilineTextAlignment(.center)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.stepInstruction)
        }
        .frame(maxWidth: .infinity, minHeight: 151)
        .background(Color.black.opacity(0.5).clipShape(LivenessTopRoundedShape(radius: 30)))
    }

    private var stepIconName: String? {
        switch viewModel.currentStep {
        case .turnLeft:  return "arrow.left"
        case .turnRight: return "arrow.right"
        case .blinkEyes: return "eye"
        case .smile:     return "face.smiling"
        default:         return nil
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(SDKTheme.shared.capture.maskOpacity ?? 0.45).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.4)
        }
    }
}

// MARK: - ARKit yüz takibi

struct LivenessARView: UIViewRepresentable {

    @ObservedObject var viewModel: SDKLivenessViewModel

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        sceneView.automaticallyUpdatesLighting = true
        context.coordinator.sceneView = sceneView
        context.coordinator.start()
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.syncFlags(from: viewModel)
        if viewModel.allStepsCompleted {
            // Adımlar bitti: kamera bırakılır, kayıt yüklemesini ViewModel yürütür.
            uiView.session.pause()
        }
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    final class Coordinator: NSObject, ARSCNViewDelegate {

        let viewModel: SDKLivenessViewModel
        weak var sceneView: ARSCNView?

        private let configuration = ARFaceTrackingConfiguration()
        /// Kare yüklendikten sonra yüz takibinin kapalı kalacağı süre: kullanıcı yükleme sürerken
        /// bir sonraki ifadeyi yapıp adımı yanlışlıkla tetikleyemesin.
        private let waitSecs: TimeInterval = 2.0
        /// Ekran kaydı hazır olduktan sonra ARKit'in açılması için beklenen süre.
        private let sessionWarmupSecs: TimeInterval = 1.0
        private var appStateObservers: [NSObjectProtocol] = []

        // ARKit delegesi render thread'inde çalışır; ViewModel'den kopyalanan bayraklar.
        private var step: LivenessTestStep?
        private var allowBlink = false, allowSmile = false, allowLeft = false, allowRight = false
        private var isCapturing = false

        init(viewModel: SDKLivenessViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            appStateObservers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        @MainActor func syncFlags(from vm: SDKLivenessViewModel) {
            step = vm.currentStep
            allowBlink = vm.allowBlink
            allowSmile = vm.allowSmile
            allowLeft = vm.allowLeft
            allowRight = vm.allowRight
        }

        /// Sıra önemli: önce ekran kaydı, kayıt hazır olunca ARKit.
        @MainActor func start() {
            guard ARFaceTrackingConfiguration.isSupported else {
                viewModel.reportFaceTrackingUnsupported()
                return
            }
            let center = NotificationCenter.default
            appStateObservers = [
                center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [viewModel] _ in
                    Task { @MainActor in viewModel.noteWillResignActive() }
                },
                center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [viewModel] _ in
                    Task { @MainActor in viewModel.noteDidBecomeActive() }
                }
            ]
            viewModel.onRecordingReady = { [weak self] in
                guard let self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + self.sessionWarmupSecs) { [weak self] in
                    guard let self, !self.viewModel.allStepsCompleted else { return }
                    self.sceneView?.session.run(self.configuration)
                }
            }
            viewModel.prepareRecording()
        }

        @MainActor func stop() {
            appStateObservers.forEach { NotificationCenter.default.removeObserver($0) }
            appStateObservers = []
            sceneView?.session.pause()
            viewModel.abandonRecording()
        }

        // MARK: ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let device = sceneView?.device, let mesh = ARSCNFaceGeometry(device: device) else { return nil }
            let node = SCNNode(geometry: mesh)
            node.geometry?.firstMaterial?.transparency = 0   // yüz ağı çizilmez, yalnızca takip
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let face = anchor as? ARFaceAnchor, let geometry = node.geometry as? ARSCNFaceGeometry else { return }
            geometry.update(from: face.geometry)
            detectExpression(face)
        }

        // MARK: İfade algılama (eşikler SDK ile aynı)

        private func detectExpression(_ face: ARFaceAnchor) {
            guard !isCapturing, let step else { return }
            func value(_ key: ARFaceAnchor.BlendShapeLocation) -> Float { face.blendShapes[key]?.floatValue ?? 0 }

            let jawLeft = abs(value(.jawLeft)), jawRight = abs(value(.jawRight))
            let triggered: Bool
            switch step {
            case .turnLeft where allowLeft:
                triggered = jawLeft > 0.12
            case .turnRight where allowRight:
                triggered = jawRight > 0.12
            case .blinkEyes where allowBlink:
                triggered = abs(value(.eyeBlinkLeft)) > 0.35 && abs(value(.eyeBlinkRight)) > 0.35
                    && jawLeft < 0.03 && jawRight < 0.03
            case .smile where allowSmile:
                triggered = value(.mouthSmileLeft) + value(.mouthSmileRight) > 1.2
                    && jawLeft < 0.03 && jawRight < 0.03
            default:
                triggered = false
            }
            if triggered { captureAndUpload() }
        }

        /// İfadenin kanıt karesini alır ve yükler; bekleme süresince takip kapalı kalır.
        private func captureAndUpload() {
            guard !isCapturing, let sceneView else { return }
            isCapturing = true
            allowLeft = false; allowRight = false; allowBlink = false; allowSmile = false

            Task { @MainActor in
                let image = sceneView.snapshot()
                sceneView.session.pause()
                self.viewModel.uploadFrame(image: image)
                try? await Task.sleep(nanoseconds: UInt64(self.waitSecs * 1_000_000_000))
                if !self.viewModel.allStepsCompleted {
                    sceneView.session.run(self.configuration)
                }
                self.isCapturing = false
            }
        }
    }
}

// MARK: - Alt panel şekli

private struct LivenessTopRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Canlılık — Özel Ekran") {
    SDKModulePreviewHost { LivenessCustomView() }
}
