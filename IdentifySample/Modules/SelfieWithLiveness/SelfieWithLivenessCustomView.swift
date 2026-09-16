//
//  SelfieWithLivenessCustomView.swift
//  IdentifySample
//
//  CANLILIKLA SELFİE — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKSelfieWithLivenessView` ekranının public API ile yazılmış birebir karşılığıdır.
//  Değişiklik yapmadan takıldığında SDK ekranıyla aynı sonucu verir; özelleştirme bu dosya üzerinde yapılır.
//
//      registry.override(.selfieWithLiveness) { SelfieWithLivenessCustomView() }
//
//  Görev dağılımı:
//    • İş mantığı (iki fazlı oval durum makinesi, ışık/eğim/mesafe/konum eşikleri, tutma süresi,
//      yükleme, karşılaştırma kararı, deneme hakkı) → `SDKSelfieWithLivenessViewModel` (SDK)
//    • ARKit / kamera oturumu, yüz konumunun ekrana projeksiyonu, oval maske, halka, flaş, çizim
//      → bu dosya (host kodu)
//
//  ViewModel kullanımı:
//    path                             .arkit (ARKit yüz takibi) / .vision (ön kamera + Vision) / .unsupported
//    updatePreviewSize(_:)            önizleme boyutu (oval hesabı için) — ZORUNLU
//    beginSession()                   ekran görününce; hata alert'i kapanınca ViewModel kendisi yeniden çağırır
//    isSessionActive / sessionGeneration   AR/kamera oturumu açılır (yeni nesil) ya da duraklatılır
//    analyzeFace(_:) / analyzeNoFace()     .arkit: her takip karesinde (ekran koordinatı + metre)
//    analyzeFrame(_:cameraPosition:)       .vision: her kamera karesinde
//    phase / ovalPhase / ovalScale / guidanceText / holdProgress / isFaceMeshHidden  çizim girdileri
//    shouldCapture == true            → kare alınır (flaş burada) ve presentCaptured(image:) çağrılır
//    isLoading / canContinue          yükleme sürüyor / kabul edildi
//    onCompleted / onSkipRequested / onFlowFailed → coordinator
//    errorMessage + consumePendingAlertAction()  hata alert'i kapanınca bekleyen aksiyon
//    noteWillResignActive() / noteDidBecomeActive() / endSession()  uygulama aktifliği ve çıkış
//
//  Kopyalanacak dosyalar: bu dosya + Selfie/SelfieCustomView.swift (SelfieCameraController, Vision yolu için)
//                         + CustomKit/CustomCameraPreview.swift
//
//  ⚠️ Gerçek cihaz gerekir (simülatörde kamera ve ARKit yok).
//

import SwiftUI
import ARKit
import IdentifySDK

struct SelfieWithLivenessCustomView: View {

    @StateObject private var viewModel: SDKSelfieWithLivenessViewModel
    @StateObject private var camera = SelfieCameraController()
    @StateObject private var snapshotter = FaceCaptureSnapshotter()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.sdkPreviewMode) private var sdkPreviewMode

    /// Oval büyüme animasyonunun sürdüğü çizim ölçeği (mantık ovali anında büyür).
    @State private var drawnOvalScale: CGFloat = 0.5
    @State private var spinnerDashPhase: CGFloat = 0
    @State private var flashOpacity: Double = 0
    @State private var isCapturing = false
    @State private var isCameraRunning = false

    private static let ovalGrowDuration: Double = 0.35
    private static let flashDuration: Double = 0.3

    /// - Parameter trueDepthMode: `nil` → `IdentifyManager.shared.selfieWithLivenessTrueDepth`.
    init(trueDepthMode: SDKTrueDepthMode? = nil) {
        _viewModel = StateObject(wrappedValue: SDKSelfieWithLivenessViewModel(trueDepthMode: trueDepthMode))
    }

    var body: some View {
        ZStack {
            cameraLayer
                .ignoresSafeArea()
            GeometryReader { geo in
                let oval = SDKSelfieWithLivenessViewModel.ovalRect(in: geo.size, scale: drawnOvalScale)
                ZStack {
                    if !isCapturing {
                        ovalMask(oval: oval)
                        if viewModel.phase != .warmingUp {
                            progressRing(oval: oval)
                        }
                    }
                }
                .onAppear { viewModel.updatePreviewSize(geo.size) }
                .onChange(of: geo.size) { viewModel.updatePreviewSize($0) }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                SDKNavigationBar(style: .overlay, onBack: { coordinator.popBack() }, onHelp: {})
                Spacer()
                instructionLabel
                    .padding(.horizontal, IDSpacing.lg)
                    .padding(.bottom, IDSpacing.xxl)
            }

            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
                .allowsHitTesting(false)

            if viewModel.isLoading { loadingOverlay }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .holdUprightWarning(isActive: !sdkPreviewMode && !isCapturing, topPadding: 72)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
        .onChange(of: viewModel.ovalScale) { scale in
            withAnimation(.easeInOut(duration: Self.ovalGrowDuration)) { drawnOvalScale = scale }
        }
        .onChange(of: viewModel.sessionGeneration) { _ in
            drawnOvalScale = viewModel.ovalScale
            isCapturing = false
            startCameraIfVision()
        }
        .onChange(of: viewModel.isSessionActive) { active in
            if !active { stopCameraIfVision() }
        }
        .onChange(of: viewModel.shouldCapture) { shouldCapture in
            guard shouldCapture else { return }
            captureWithFlash()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewModel.noteWillResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.noteDidBecomeActive()
        }
        .idErrorAlert($viewModel.errorMessage, onDismiss: { viewModel.consumePendingAlertAction() })
    }

    // MARK: - Yaşam döngüsü

    private func start() {
        viewModel.onCompleted = { coordinator.advanceToNextModule() }
        viewModel.onSkipRequested = { coordinator.skipCurrentModule() }
        viewModel.onFlowFailed = { coordinator.finishFlowAsFailed() }
        guard !sdkPreviewMode else { return }
        if viewModel.path == .vision {
            camera.onSessionError = { [viewModel] message in
                viewModel.endSession()
                viewModel.errorMessage = message
            }
            camera.setFrameHandler { [viewModel] buffer, position in
                viewModel.analyzeFrame(buffer, cameraPosition: position)
            }
        }
        viewModel.beginSession()
        startCameraIfVision()
    }

    private func stop() {
        viewModel.endSession()
        stopCameraIfVision()
        camera.setFrameHandler(nil)
    }

    private func startCameraIfVision() {
        guard viewModel.path == .vision, !sdkPreviewMode, viewModel.isSessionActive, !isCameraRunning else { return }
        isCameraRunning = true
        camera.start()
    }

    private func stopCameraIfVision() {
        guard viewModel.path == .vision, isCameraRunning else { return }
        isCameraRunning = false
        camera.stop()
    }

    // MARK: - Çekim

    /// Çekim anı flaşı: ön kamerada donanım feneri olmadığından ekran kısa süre beyaz yanıp yüzü
    /// aydınlatır; kamera bu ışıkla pozladıktan sonra kare alınır. Beyaz katman kareye girmez.
    private func captureWithFlash() {
        guard !isCapturing else { return }
        isCapturing = true
        let previousBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
        withAnimation(.easeIn(duration: Self.flashDuration)) { flashOpacity = 1 }

        let finish: (UIImage?) -> Void = { image in
            withAnimation(.easeOut(duration: Self.flashDuration)) { flashOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.flashDuration) {
                UIScreen.main.brightness = previousBrightness
            }
            viewModel.presentCaptured(image: image)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flashDuration) {
            switch viewModel.path {
            case .arkit:
                finish(snapshotter.take?())
            case .vision:
                camera.capturePhoto { image in finish(image) }
            case .unsupported:
                finish(nil)
            @unknown default:
                finish(nil)
            }
        }
    }
}

// MARK: - Alt görünümler

private extension SelfieWithLivenessCustomView {

    @ViewBuilder var cameraLayer: some View {
        if sdkPreviewMode || CustomRuntime.isXcodePreview {
            CustomCameraPlaceholder(systemIcon: "faceid")
        } else {
            switch viewModel.path {
            case .arkit:
                FaceTrackingCameraView(viewModel: viewModel, snapshotter: snapshotter)
            case .vision:
                CustomCameraPreview(session: camera.session, placeholderIcon: "faceid")
            case .unsupported:
                Color.black
            @unknown default:
                Color.black
            }
        }
    }

    /// Karartılmış zemin, ortası oval kesik.
    func ovalMask(oval: CGRect) -> some View {
        Color.black.opacity(0.80)
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
    }

    /// İçte tutma ilerlemesi (kesik çizgi, dolunca yeşil), dışta yüz beklenirken dönen halka.
    func progressRing(oval: CGRect) -> some View {
        let verified = viewModel.phase == .verified
        let ringColor: Color = verified ? .green : .white
        return ZStack {
            CustomTopStartOval()
                .trim(from: 0, to: viewModel.holdProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [30, 40]))
                .frame(width: oval.width, height: oval.height)
                .position(x: oval.midX, y: oval.midY)
                .animation(verified ? .easeInOut(duration: 0.3) : nil, value: viewModel.holdProgress)
            CustomTopStartOval()
                .stroke(verified ? Color.green : Color.white.opacity(0.6),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [12, 20], dashPhase: spinnerDashPhase))
                .frame(width: oval.width + 20, height: oval.height + 20)
                .position(x: oval.midX, y: oval.midY)
                .onAppear {
                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                        spinnerDashPhase = -32
                    }
                }
        }
        .animation(.easeInOut(duration: 0.4), value: verified)
    }

    var instructionLabel: some View {
        Text(viewModel.guidanceText)
            .font(IDFont.custom(16, .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.7), radius: 4)
            .frame(maxWidth: .infinity)
    }

    var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(SDKTheme.shared.capture.maskOpacity ?? 0.45)
                .ignoresSafeArea()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.4)
        }
    }
}

// MARK: - Üstten başlayan oval

/// Başlangıç noktası ovalin TEPESİNDE olan, saat yönünde ilerleyen oval yolu. SwiftUI `Ellipse`
/// sağ ortadan başladığı için tutma ilerlemesi ve dönen halka orada başlayıp biterdi; UIKit
/// ekranındaki (`makeBezierOval`) gibi tepeden başlar.
struct CustomTopStartOval: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY, rx = rect.width / 2, ry = rect.height / 2
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - ry))
        p.addCurve(to: CGPoint(x: cx + rx, y: cy),
                   control1: CGPoint(x: cx + rx * 0.55, y: cy - ry),
                   control2: CGPoint(x: cx + rx, y: cy - ry * 0.55))
        p.addCurve(to: CGPoint(x: cx, y: cy + ry),
                   control1: CGPoint(x: cx + rx, y: cy + ry * 0.55),
                   control2: CGPoint(x: cx + rx * 0.55, y: cy + ry))
        p.addCurve(to: CGPoint(x: cx - rx, y: cy),
                   control1: CGPoint(x: cx - rx * 0.55, y: cy + ry),
                   control2: CGPoint(x: cx - rx, y: cy + ry * 0.55))
        p.addCurve(to: CGPoint(x: cx, y: cy - ry),
                   control1: CGPoint(x: cx - rx, y: cy - ry * 0.55),
                   control2: CGPoint(x: cx - rx * 0.55, y: cy - ry))
        p.closeSubpath()
        return p
    }
}

// MARK: - Anlık görüntü köprüsü

/// Kamera katmanının "kare al" işlevini SwiftUI ekranına taşır.
final class FaceCaptureSnapshotter: ObservableObject {
    var take: (() -> UIImage?)?
}

// MARK: - ARKit kamera katmanı

/// ARKit yolu: `ARSCNView` + yüz mesh'i; her takip karesini ekran koordinatına çevirip
/// ViewModel'e verir. Oturum `viewModel.isSessionActive` / `sessionGeneration` ile açılıp duraklatılır.
struct FaceTrackingCameraView: UIViewRepresentable {

    @ObservedObject var viewModel: SDKSelfieWithLivenessViewModel
    let snapshotter: FaceCaptureSnapshotter

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        sceneView.automaticallyUpdatesLighting = true
        context.coordinator.sceneView = sceneView
        snapshotter.take = { [weak sceneView] in sceneView?.snapshot() }
        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async { viewModel.reportFaceTrackingUnsupported() }
            return sceneView
        }
        context.coordinator.applySession()
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.applySession()
        context.coordinator.setFaceMeshHidden(viewModel.isFaceMeshHidden)
    }

    /// Açık kalan AR oturumu kamerayı tutar; ekran kapanınca duraklatılır.
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    final class Coordinator: NSObject, ARSCNViewDelegate {

        let viewModel: SDKSelfieWithLivenessViewModel
        weak var sceneView: ARSCNView?

        private let configuration = ARFaceTrackingConfiguration()
        private var appliedGeneration = 0
        private var isRunning = false
        private var faceNode: SCNNode?
        /// Mesh gizleme materyal transparency=0 ile yapılır (isHidden bazı cihazlarda çizimi durdurmuyor).
        private var faceMeshHidden = false

        @MainActor
        init(viewModel: SDKSelfieWithLivenessViewModel) {
            self.viewModel = viewModel
            super.init()
        }

        /// ViewModel'in oturum isteğini AR oturumuna uygular: yeni nesil → `run`, pasif → `pause`.
        @MainActor func applySession() {
            guard let sceneView, ARFaceTrackingConfiguration.isSupported else { return }
            if viewModel.isSessionActive {
                if !isRunning || appliedGeneration != viewModel.sessionGeneration {
                    appliedGeneration = viewModel.sessionGeneration
                    isRunning = true
                    sceneView.session.run(configuration)
                }
            } else if isRunning {
                isRunning = false
                sceneView.session.pause()
            }
        }

        func setFaceMeshHidden(_ hidden: Bool) {
            guard faceMeshHidden != hidden else { return }
            faceMeshHidden = hidden
            applyFaceMeshVisibility(to: faceNode)
        }

        private func applyFaceMeshVisibility(to node: SCNNode?) {
            node?.isHidden = faceMeshHidden
            node?.geometry?.firstMaterial?.transparency = faceMeshHidden ? 0 : 0.55
        }

        // MARK: ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor, let device = sceneView?.device else { return nil }
            let faceMesh = ARSCNFaceGeometry(device: device)
            let node = SCNNode(geometry: faceMesh)
            let material = node.geometry?.firstMaterial
            material?.fillMode = .lines
            material?.diffuse.contents = UIColor.white
            material?.isDoubleSided = true
            faceNode = node
            applyFaceMeshVisibility(to: node)
            return node
        }

        /// Her takip karesi: 3B yüz konumu ekrana projekte edilir, metre ve eğimle birlikte ViewModel'e verilir.
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }
            faceGeometry.update(from: faceAnchor.geometry)
            let isTracked = faceAnchor.isTracked
            let transform = faceAnchor.transform
            DispatchQueue.main.async { [weak self] in
                guard let self, let sceneView = self.sceneView else { return }
                guard isTracked else { self.viewModel.analyzeNoFace(); return }
                let col = transform.columns.3
                let proj = sceneView.projectPoint(SCNVector3(col.x, col.y, col.z))
                let ambient = sceneView.session.currentFrame?.lightEstimate?.ambientIntensity
                self.viewModel.analyzeFace(SDKFaceObservation(
                    center: CGPoint(x: CGFloat(proj.x), y: CGFloat(proj.y)),
                    depthMeters: abs(col.z),
                    pitch: CGFloat(transform.columns.2.y),
                    ambientIntensity: ambient.map { CGFloat($0) }
                ))
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            guard anchor is ARFaceAnchor else { return }
            DispatchQueue.main.async { [weak self] in self?.viewModel.analyzeNoFace() }
        }
    }
}

#Preview("Canlılıkla Selfie — Özel Ekran") {
    SDKModulePreviewHost { SelfieWithLivenessCustomView() }
}
