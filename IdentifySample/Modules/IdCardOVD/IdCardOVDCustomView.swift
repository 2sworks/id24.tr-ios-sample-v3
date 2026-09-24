//
//  IdCardOVDCustomView.swift
//  IdentifySample
//
//  KİMLİK + OVD (HOLOGRAM) — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKIdCardOVDView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.idCardOVD) { IdCardOVDCustomView() }
//
//  Görev dağılımı:
//    • Belge / netlik / sabitlik / hologram kapıları, OCR, yükleme, adım sırası, sesli yönerge,
//      çekim anı titreşimi → `SDKIdCardOVDViewModel`
//    • Arka kamera (canlı kare + yüksek çözünürlüklü fotoğraf + fener + lens/odak) ve çizim → bu dosya
//
//  ViewModel kullanımı:
//    documentType + notifyDocumentSelectionShown() / notifyCaptureStarted()
//    ingest(ciImage:roi:)        canlı kare (~5 fps yeterli); ROI = ekrandaki kılavuz kutusunun karedeki karşılığı
//    motionFeed                  HER kare (30 fps) — görüntü tabanlı sabitlik kapısı; bağlanmazsa yalnız IMU kullanılır
//    onRequestCapture            → yüksek çözünürlüklü fotoğraf çek → handleCaptured(_:roi:)
//    onSetTorch(Bool)            hologram adımı için fener
//    onRequestLensSwitch         lens netleyemiyor → sıradaki lens
//    onRequestFocusNudge / focusProbe   odak dürtme ve odak durumu
//    startMotion() / stopMotion()       IMU
//    step / instruction / guideDetected / rainbowProgress / totalSteps / completedSteps / isUploading / canContinue
//
//  Kopyalanacak dosyalar: bu dosya + CustomKit/CustomCameraPreview.swift
//

import SwiftUI
import AVFoundation
import CoreImage
import IdentifySDK

struct IdCardOVDCustomView: View {

    private enum Phase { case typeSelection, capturing }

    @StateObject private var viewModel: SDKIdCardOVDViewModel
    @StateObject private var camera = OVDCamera()
    @ObservedObject private var speech = SDKSpeechService.shared
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.sdkPreviewMode) private var sdkPreviewMode
    @Environment(\.colorScheme) private var colorScheme

    @State private var phase: Phase
    @State private var selectedType: OVDDocumentType
    /// Seçim ekranından mı gelindi? (geri tuşu: seçime dön vs. modülü kapat)
    private let showsTypeSelection: Bool
    /// Seçim ekranı yoksa çekim konumu ("Id Card OVD" / "Passport OVD") bir kez, açılışta gönderilir.
    @State private var didReportCaptureLocation = false
    @State private var showSuccess = false
    @State private var didAutoAdvance = false
    /// Çizilen kılavuz kutusunun ekrandaki yeri; analiz ROI'si bundan türetilir.
    @State private var guideRectOnScreen: CGRect = .zero

    /// Seçim ekranı `SDKDocumentSelectionConfig.shared.ovd` ile kapatılabilir ya da tek seçenek
    /// kaldığında atlanır; atlandığında tip baştan yazılır ve çekim konumu açılışta gönderilir.
    init() {
        let vm = SDKIdCardOVDViewModel()
        if let skipped = vm.skippedDocumentType {
            vm.documentType = skipped
            _phase = State(initialValue: .capturing)
            showsTypeSelection = false
        } else {
            _phase = State(initialValue: .typeSelection)
            showsTypeSelection = true
        }
        _selectedType = State(initialValue: vm.initialDocumentType)
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        switch phase {
        case .typeSelection: typeSelectionView
        case .capturing:     captureView
        }
    }

    // MARK: - Faz 1: belge tipi

    private var typeSelectionView: some View {
        ZStack(alignment: .top) {
            IDColor.moduleBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 0) {
                SDKNavigationBar(
                    style: .progress(steps: coordinator.progressTotal, current: coordinator.progressStep),
                    title: String(.idVerifyTitle),
                    subtitle: String(.selectMethodContinue),
                    onBack: { coordinator.popBack() }
                )
                .padding(.top, IDSpacing.sm)

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: IDSpacing.xl) {
                            VStack(alignment: .leading, spacing: IDSpacing.sm) {
                                Text(.scanType)
                                    .font(IDFont.displayMedium(.semibold))
                                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                                Text(.scanTypeDesc)
                                    .font(IDFont.bodyRegular(.regular))
                                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                                    .lineSpacing(4)
                            }
                            VStack(spacing: IDSpacing.sm) {
                                // Satırlar `SDKDocumentSelectionConfig.shared.ovd.options` ile belirlenir.
                                ForEach(viewModel.selectionOptions, id: \.self) { type in
                                    typeRow(icon(for: type), title(for: type), selectedType == type) { selectedType = type }
                                }
                            }
                        }
                        .padding(.top, IDSpacing.xxl)
                        .padding(.bottom, IDSpacing.xl)
                        .padding(.horizontal, IDSpacing.lg)
                    }

                    SDKButton(title: String(.continuePage)) {
                        viewModel.documentType = selectedType
                        viewModel.notifyCaptureStarted()
                        // Modul ici ekran degisimi de bir gecistir: secim ekraninin yonergesi
                        // kesilmezse cekim ekraninda okunmaya devam eder.
                        SDKSpeechService.shared.stop()
                        withAnimation { phase = .capturing }
                    }
                    .padding(.horizontal, IDSpacing.lg)
                    .padding(.bottom, IDSpacing.xxl)
                }
                .background(IDColor.adaptiveSurface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: IDRadius.card))
                .sdkReadableWidth()
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    viewModel.notifyDocumentSelectionShown()
                    // SDK bu rotayı otomatik okumaz: seçim ve çekim fazlarının yönergesi farklıdır.
                    if SDKDocumentSelectionConfig.shared.ovd.speaksOnScreen {
                        SDKSpeechService.shared.speak(.idCardOVDTts, in: .idcard_w_ovd)
                    }
                }
            }
        }
    }

    private func icon(for type: OVDDocumentType) -> SDKIconKey {
        type == .passport ? .idTypePassport : .idTypeChip
    }

    private func title(for type: OVDDocumentType) -> String {
        type == .passport ? String(.passport) : String(.chippedIdCard)
    }

    private func typeRow(_ icon: SDKIconKey, _ title: String, _ isSelected: Bool, action: @escaping () -> Void) -> some View {
        let unchecked = colorScheme == .dark ? IDColor.darkMuted : IDColor.divider
        let textColor = isSelected || colorScheme == .dark ? IDColor.primaryLight : IDColor.darkMuted
        return Button(action: action) {
            HStack(spacing: 12) {
                Image.sdk(icon).renderingMode(.template).resizable().scaledToFit()
                    .foregroundColor(textColor)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(IDFont.bodyRegular(.regular))
                    .foregroundColor(textColor)
                Spacer()
                ZStack {
                    Circle().stroke(isSelected ? IDColor.primaryLight : unchecked, lineWidth: 2).frame(width: 20, height: 20)
                    if isSelected { Circle().fill(IDColor.primaryLight).frame(width: 10, height: 10) }
                }
            }
            .padding(.horizontal, IDSpacing.lg)
            .frame(minHeight: 48)
            .background(RoundedRectangle(cornerRadius: IDRadius.md).fill(isSelected ? IDColor.primary : unchecked.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Faz 2: canlı çekim

    private var captureView: some View {
        ZStack {
            CustomCameraPreview(session: camera.session, placeholderIcon: "creditcard.fill").ignoresSafeArea()
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: 0) {
                SDKNavigationBar(style: .overlay, onBack: {
                    camera.stop()
                    viewModel.stopMotion()
                    guard showsTypeSelection else { coordinator.popBack(); return }
                    viewModel.reset()
                    SDKSpeechService.shared.stop()
                    withAnimation { phase = .typeSelection }
                })
                HStack(spacing: 6) {
                    ForEach(0..<max(viewModel.totalSteps, 1), id: \.self) { i in
                        Capsule()
                            .fill(i < viewModel.completedSteps ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 5)
                    }
                }
                .padding(.horizontal, IDSpacing.xl)
                .padding(.top, IDSpacing.sm)

                Spacer()
                guideFrame
                Spacer()

                Text(viewModel.instruction)
                    .font(IDFont.bodyMedium(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, IDSpacing.xl)
                    .padding(.bottom, IDSpacing.lg)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.instruction)
                    .padding(.bottom, 40)
            }

            if viewModel.isUploading {
                ZStack {
                    Color.black.opacity(SDKTheme.shared.capture.maskOpacity ?? 0.45).ignoresSafeArea()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.3)
                }
            }
        }
        .onPreferenceChange(GuideRectKey.self) { guideRectOnScreen = $0 }
        .idErrorAlert($viewModel.errorMessage, onDismiss: { viewModel.consumePendingAlertAction() })
        .onAppear {
            // Seçim ekranı yoksa çekim konumu ("Id Card OVD" / "Passport OVD") modül açılır açılmaz gider.
            if !showsTypeSelection, !didReportCaptureLocation {
                didReportCaptureLocation = true
                viewModel.notifyCaptureStarted()
            }
            viewModel.onSkipRequested = { coordinator.skipCurrentModule() }
            viewModel.onFlowFailed = { coordinator.finishFlowAsFailed() }
            viewModel.onRequestCapture = { camera.capturePhoto() }
            viewModel.onSetTorch = { camera.setTorch(on: $0) }
            viewModel.onRequestLensSwitch = { camera.cycleToNextLens() }
            viewModel.onRequestFocusNudge = { camera.nudgeFocus() }
            viewModel.focusProbe = { camera.focusProbe() }
            camera.setMotionFeed(viewModel.motionFeed)
            camera.onFrame = { ci in viewModel.ingest(ciImage: ci, roi: roi(for: ci)) }
            camera.onPhoto = { ci in viewModel.handleCaptured(ci, roi: roi(for: ci)) }

            guard !sdkPreviewMode else { return }
            camera.start()
            viewModel.startMotion()
            SDKSpeechService.shared.speak(.ovdScanFrontSide, in: .idcard_w_ovd, whenCameraReady: true)
        }
        .onDisappear {
            camera.stop()
            viewModel.stopMotion()
        }
        .onChange(of: viewModel.canContinue) { done in
            guard done else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { showSuccess = true }
            // "Tamamlandı" görünsün/duyulsun: en az ~0.9 sn, konuşma sürüyorsa en fazla ~6 sn bekle.
            Task { @MainActor in
                let start = Date()
                try? await Task.sleep(nanoseconds: 900_000_000)
                while speech.isSpeaking, Date().timeIntervalSince(start) < 6 {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                guard !didAutoAdvance else { return }
                didAutoAdvance = true
                coordinator.advanceToNextModule()
            }
        }
    }

    /// Kimlik (ID-1) 0.63, pasaport veri sayfası (TD3) 0.70.
    private var guideAspect: CGFloat { viewModel.documentType == .passport ? 0.70 : 0.63 }
    private var guideWidth: CGFloat { min(SDKLayout.bounds.width - 64, SDKLayout.maxCaptureGuideWidth) }

    private var guideFrame: some View {
        RoundedRectangle(cornerRadius: IDRadius.lg)
            .stroke((viewModel.guideDetected || showSuccess) ? IDColor.successBright : .white, lineWidth: 3)
            .frame(width: guideWidth, height: guideWidth * guideAspect)
            .background(GeometryReader { g in Color.clear.preference(key: GuideRectKey.self, value: g.frame(in: .global)) })
            .overlay {
                if viewModel.step == .frontHologram {
                    VStack(spacing: 8) {
                        Image.sdk(.sparkles)
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white.opacity(0.85))
                        ProgressView(value: viewModel.rainbowProgress)
                            .tint(.white)
                            .frame(width: 120)
                    }
                }
            }
            .animation(.easeInOut, value: viewModel.guideDetected)
            .animation(.easeInOut, value: viewModel.step)
    }

    /// Ekrandaki kılavuz kutusunu kameranın karesine taşır (önizleme ekranı aspectFill ile dolduruyor).
    /// Kutunun her kenarına %15 pay eklenir: belge kutudan biraz taşsa da tespit düşmesin.
    private func roi(for ci: CIImage) -> CGRect {
        let e = ci.extent
        let screen = SDKLayout.bounds
        let fallback: CGRect = {
            let w = e.width * 0.85, h = w * guideAspect
            return CGRect(x: e.midX - w / 2, y: e.midY - h / 2, width: w, height: h)
        }()
        guard guideRectOnScreen.width > 1, screen.width > 1, e.width > 1 else { return fallback }

        let scale = max(screen.width / e.width, screen.height / e.height)
        let offX = (screen.width - e.width * scale) / 2
        let offY = (screen.height - e.height * scale) / 2
        var r = CGRect(x: (guideRectOnScreen.minX - offX) / scale, y: (guideRectOnScreen.minY - offY) / scale,
                       width: guideRectOnScreen.width / scale, height: guideRectOnScreen.height / scale)
        r = r.insetBy(dx: -r.width * 0.15, dy: -r.height * 0.15)
        // Üst-sol kökenden CIImage'ın alt-sol kökenine.
        let mapped = CGRect(x: e.origin.x + r.minX, y: e.origin.y + e.height - r.maxY, width: r.width, height: r.height)
            .intersection(e)
        return mapped.isNull || mapped.width < 8 || mapped.height < 8 ? fallback : mapped
    }
}

private struct GuideRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 1 { value = next }
    }
}

// MARK: - Arka kamera

@MainActor
final class OVDCamera: NSObject, ObservableObject {

    let session = AVCaptureSession()
    var onFrame: ((CIImage) -> Void)?
    var onPhoto: ((CIImage) -> Void)?

    private enum Lens { case wide, telephoto, ultraWide }

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "sample.ovd.frames")
    private var device: AVCaptureDevice?
    private var lenses: [Lens: AVCaptureDevice] = [:]
    private var currentLens: Lens = .wide
    private var ultraWideRetired = false
    private var lastEmit = Date.distantPast
    private var isCapturing = false
    private var subjectAreaObserver: NSObjectProtocol?

    /// Hareket ölçeri besleyicisi kamera kuyruğundan çağrılır.
    private nonisolated let feedLock = NSLock()
    private nonisolated(unsafe) var motionFeed: ((CVPixelBuffer) -> Void)?

    nonisolated func setMotionFeed(_ feed: ((CVPixelBuffer) -> Void)?) {
        feedLock.lock(); motionFeed = feed; feedLock.unlock()
    }

    func start() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.configure()
            await MainActor.run { if !self.session.isRunning { self.session.startRunning() } }
        }
    }

    func stop() {
        setTorch(on: false)
        if let subjectAreaObserver { NotificationCenter.default.removeObserver(subjectAreaObserver) }
        subjectAreaObserver = nil
        // Yakın odak kısıtı cihazda kalır; sonraki kamera ekranına taşınmasın.
        if let device, (try? device.lockForConfiguration()) != nil {
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .none }
            if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = true }
            device.isSubjectAreaChangeMonitoringEnabled = false
            device.unlockForConfiguration()
        }
        session.stopRunning()
    }

    /// Lens odak ararken çekim yapılmaz; en fazla ~0.6 sn beklenir.
    func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        Task { @MainActor in
            var waited = 0
            while device?.isAdjustingFocus == true, waited < 12 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                waited += 1
            }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func setTorch(on: Bool) {
        guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        if on {
            try? device.setTorchModeOn(level: min(0.6, AVCaptureDevice.maxAvailableTorchLevel))
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.setExposureTargetBias(-0.7, completionHandler: nil)
        } else {
            device.torchMode = .off
        }
        device.unlockForConfiguration()
    }

    /// Tercih sırası: geniş → tele → ultra geniş (başarısız ultra geniş oturum boyunca emekliye ayrılır).
    func cycleToNextLens() {
        if currentLens == .ultraWide { ultraWideRetired = true }
        let order = [Lens.wide, .telephoto, .ultraWide].filter { lenses[$0] != nil && !($0 == .ultraWide && ultraWideRetired) }
        guard let index = order.firstIndex(of: currentLens) ?? order.indices.first else { return }
        let next = order[(index + 1) % order.count]
        guard next != currentLens, let nextDevice = lenses[next] else { return }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        if let input = try? AVCaptureDeviceInput(device: nextDevice), session.canAddInput(input) {
            session.addInput(input)
            device = nextDevice
            currentLens = next
            applyFocusDefaults(nextDevice)
        }
        applyRotation()
        session.commitConfiguration()
    }

    func nudgeFocus() {
        guard let device, device.isFocusModeSupported(.autoFocus), !device.isAdjustingFocus,
              (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
        device.focusMode = .autoFocus
        device.unlockForConfiguration()
    }

    /// (odak arıyor mu, lens konumu, asgari odak mesafesi mm, en yakın uçta mı)
    func focusProbe() -> (Bool, Float, Int?, Bool) {
        guard let device else { return (false, 0.5, nil, false) }
        let position = device.lensPosition
        return (device.isAdjustingFocus, position, device.minimumFocusDistance > 0 ? device.minimumFocusDistance : nil, position <= 0.03)
    }

    private func configure() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video, position: .back)
        for d in discovery.devices {
            switch d.deviceType {
            case .builtInWideAngleCamera: lenses[.wide] = d
            case .builtInTelephotoCamera: lenses[.telephoto] = d
            case .builtInUltraWideCamera: lenses[.ultraWide] = d
            default: break
            }
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        if let wide = lenses[.wide], let input = try? AVCaptureDeviceInput(device: wide), session.canAddInput(input) {
            session.addInput(input)
            device = wide
            currentLens = .wide
            applyFocusDefaults(wide)
        }
        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            if #available(iOS 17.0, *) { photoOutput.maxPhotoQualityPrioritization = .quality }
        }
        if !session.outputs.contains(videoOutput), session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            session.addOutput(videoOutput)
        }
        applyRotation()
        session.commitConfiguration()
    }

    /// Belge çekimine uygun odak: yakın mesafe, yumuşak AF kapalı, sahne değişimi izleme açık.
    private func applyFocusDefaults(_ device: AVCaptureDevice) {
        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = false }
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            device.isSubjectAreaChangeMonitoringEnabled = true
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        }
        if let subjectAreaObserver { NotificationCenter.default.removeObserver(subjectAreaObserver) }
        // Tek atış odak dürtmesinden sonra sahne değişince sürekli moda dön.
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceSubjectAreaDidChange, object: device, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let device = self?.device, device.focusMode != .continuousAutoFocus,
                      (try? device.lockForConfiguration()) != nil else { return }
                if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                device.unlockForConfiguration()
            }
        }
    }

    /// Arka kamera sensörü tüm iPhone'larda yatay monte; analiz ve fotoğraf dik (90°) alınır.
    private func applyRotation() {
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)].compactMap({ $0 }) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }
}

extension OVDCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Sabitlik ölçümü her karede; analiz ~5 fps.
        feedLock.lock(); let feed = motionFeed; feedLock.unlock()
        feed?(buffer)
        let ci = CIImage(cvPixelBuffer: buffer)
        Task { @MainActor in
            let now = Date()
            guard now.timeIntervalSince(self.lastEmit) >= 0.18 else { return }
            self.lastEmit = now
            self.onFrame?(ci)
        }
    }
}

extension OVDCamera: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        SDKCaptureHaptics.shared.finish()
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { Task { @MainActor in self.isCapturing = false } }
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        // Fotoğraf canlı kareyle aynı (dik) koordinat uzayında olmalı; yön piksele gömülür.
        let upright: UIImage
        if image.imageOrientation == .up {
            upright = image
        } else {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = image.scale
            format.opaque = true
            upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }
        let ci = CIImage(image: upright) ?? CIImage()
        Task { @MainActor in self.onPhoto?(ci) }
    }
}

#Preview("Kimlik + OVD — Özel Ekran") {
    SDKModulePreviewHost { IdCardOVDCustomView() }
}
