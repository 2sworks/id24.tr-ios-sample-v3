//
//  VideoRecorderCustomView.swift
//  IdentifySample
//
//  KISA VİDEO (+ SESLİ OKUMA) — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKVideoRecorderView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.videoRecorder) { VideoRecorderCustomView() }
//
//  Görev dağılımı:
//    • Süre sınırı, okunacak cümle (sunucudan), sesli doğrulama (sunucu transkripsiyonu),
//      mikrofon izni, video yükleme → `SDKVideoRecorderViewModel`
//    • Ön kamera + mikrofon ile kayıt, geri sayım, oynatma ve çizim → bu dosya
//
//  ViewModel kullanımı:
//    configureFromSDK()             ekran açılınca (süre / okuma metni / eşik sunucudan)
//    ensureMicPermissionForSpeech() sesli doğrulama açıksa mikrofon izni
//    videoTimeLimit                 kayıt süresi (sn)
//    videoSelected(url:)            kayıt bitince; okuma testi varsa transkripsiyon başlar
//    readingText / isTranscribing / recognizedText / speechSuccess / speechScore
//    showSpeechFailSheet            eşleşme yok → "tekrar dene" sayfası
//    deleteVideo()                  yeniden çek
//    uploadVideo()                  onayla → onCompleted → coordinator.advanceToNextModule()
//    micBlocked / showMicSettingsAlert / micSettingsMessage / micSettingsAction
//
//  Kopyalanacak dosyalar: bu dosya + CustomKit/CustomCameraPreview.swift + CustomKit/CustomComponents.swift
//

import SwiftUI
import AVFoundation
import IdentifySDK

struct VideoRecorderCustomView: View {

    @StateObject private var viewModel = SDKVideoRecorderViewModel()
    @StateObject private var camera = VideoRecorderCamera()
    @ObservedObject private var speech = SDKSpeechService.shared
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.sdkPreviewMode) private var sdkPreviewMode

    @State private var isCameraActive = true
    @State private var player: AVPlayer?
    @State private var isVideoPlaying = false
    @State private var containerHeight: CGFloat = 0

    private let readingGreen = Color(red: 0.18, green: 0.82, blue: 0.44)

    var body: some View {
        ZStack {
            backgroundLayer
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 12) {
                    if viewModel.readingText != nil && viewModel.videoURL == nil { readingCard }
                    infoText
                    if viewModel.readingText != nil && viewModel.videoURL != nil { recognizedCard }
                    actionButtons
                }
                .padding(.bottom, 48)
            }
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(SDKTheme.shared.capture.maskOpacity ?? 0.45).ignoresSafeArea()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.4)
                }
            }
            if viewModel.showSpeechFailSheet {
                Color.black.opacity(SDKTheme.shared.capture.maskOpacity ?? 0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(9)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    SpeechFailSheet(detectedText: viewModel.recognizedText, score: viewModel.speechScore) { retake() }
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom))
                .zIndex(10)
            }
        }
        .ignoresSafeArea()
        .background(GeometryReader { geo in Color.clear.onAppear { containerHeight = geo.size.height } })
        .animation(.easeInOut(duration: 0.35), value: viewModel.showSpeechFailSheet)
        .overlay(alignment: .top) {
            SDKNavigationBar(style: .overlay, onBack: { coordinator.popBack() })
        }
        .holdUprightWarning(isActive: viewModel.videoURL == nil && !sdkPreviewMode, topPadding: 72)
        .onAppear {
            viewModel.onCompleted = { coordinator.advanceToNextModule() }
            camera.onSessionError = { viewModel.errorMessage = $0 }
            viewModel.configureFromSDK()
            guard !sdkPreviewMode else { return }
            camera.start()
            viewModel.ensureMicPermissionForSpeech()
            // Okuma testinde cümle seslendirilmez (mikrofona karışır); yalnızca yönerge okunur.
            let key: SDKKeyword = (viewModel.readingText?.isEmpty == false) ? .videoRecorderReadingTts : .videoRecorderTts
            SDKSpeechService.shared.speak(key, in: .videoRecord, whenCameraReady: true)
        }
        .onDisappear {
            camera.stop()
            player?.pause()
            player = nil
            if coordinator.navDirection == .back { SDKSpeechService.shared.stop() }
        }
        .onChange(of: viewModel.videoURL) { url in
            guard let url else {
                player?.pause(); player = nil; isVideoPlaying = false
                return
            }
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            isVideoPlaying = true
            // Kamera oturumunun ses donanımını bırakması için kısa bekleme.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard newPlayer === player else { return }
                newPlayer.play()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
        .idErrorAlert($viewModel.errorMessage)
        .idAlert(isPresented: $viewModel.showMicSettingsAlert, alert: IDAlertModel(
            type: .info,
            title: String(.permissionRequired),
            message: viewModel.micSettingsMessage,
            actions: [
                IDAlertAction(title: String(.coreCancel), style: .cancel),
                IDAlertAction(title: String(.coreSettings), style: .primary) { viewModel.micSettingsAction?() }
            ]
        ))
    }

    private func retake() {
        player?.pause()
        player = nil
        isVideoPlaying = false
        viewModel.deleteVideo()
        isCameraActive = true
        camera.start()
    }

    // MARK: - Katmanlar

    private var backgroundLayer: some View {
        Group {
            if isCameraActive {
                CustomCameraPreview(session: camera.session, placeholderIcon: "video.fill").ignoresSafeArea()
            } else if let player {
                VideoPlayerLayerView(player: player).ignoresSafeArea()
            } else {
                Color(white: 0.12).ignoresSafeArea()
            }
        }
    }

    /// Uzun cümlede yazı küçülür; alan ekranın ~%32'sini aşarsa kaydırılır.
    private func readingFontSize(_ text: String) -> CGFloat {
        switch text.count {
        case 0...30:    return 22
        case 31...60:   return 19
        case 61...100:  return 16
        case 101...160: return 14
        default:        return 12
        }
    }

    private var readingCard: some View {
        VStack(spacing: IDSpacing.lg) {
            VStack(spacing: 6) {
                Text(.readingTestTitle)
                    .font(IDFont.bodyLarge(.semibold))
                    .foregroundColor(.white)
                Text(.readingTestDesc)
                    .font(IDFont.bodySmall(.regular))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: IDSpacing.sm) {
                Text(.sentenceToReadLabel)
                    .font(IDFont.custom(12, .regular))
                    .foregroundColor(.white.opacity(0.65))
                ScrollView(showsIndicators: true) {
                    Text(viewModel.readingText ?? "")
                        .font(IDFont.custom(readingFontSize(viewModel.readingText ?? ""), .bold))
                        .foregroundColor(readingGreen)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: containerHeight > 0 ? containerHeight * 0.32 : 220)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(IDSpacing.lg)
            .background(IDColor.successBright.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: IDRadius.md))
            .overlay(RoundedRectangle(cornerRadius: IDRadius.md)
                .strokeBorder(readingGreen.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
        }
        .padding(.horizontal, IDSpacing.xl)
        .transition(.opacity)
    }

    private var recognizedCard: some View {
        VStack(alignment: .leading, spacing: IDSpacing.sm) {
            if viewModel.isTranscribing {
                HStack(spacing: IDSpacing.sm) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85)
                    Text(.voiceVerifying)
                        .font(IDFont.caption(.medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            } else {
                HStack(spacing: 6) {
                    Image.sdk(.successCircle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(readingGreen)
                    Text(.youSaidLabel)
                        .font(IDFont.custom(12, .regular))
                        .foregroundColor(.white.opacity(0.65))
                }
                Text(viewModel.recognizedText.isEmpty ? "—" : viewModel.recognizedText)
                    .font(IDFont.custom(readingFontSize(viewModel.recognizedText), .bold))
                    .foregroundColor(readingGreen)
                    .lineSpacing(4)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(IDSpacing.lg)
        .background(IDColor.successBright.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.md))
        .overlay(RoundedRectangle(cornerRadius: IDRadius.md)
            .strokeBorder(readingGreen.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
        .padding(.horizontal, IDSpacing.xl)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isTranscribing)
    }

    /// Okuma testinde yönerge kartta yazdığı için alt metin boş kalır.
    private var infoText: some View {
        let text: String
        if camera.isRecording {
            text = viewModel.readingText != nil ? "" : String(.recording)
        } else if viewModel.videoURL != nil {
            text = viewModel.readingText != nil ? "" : String(.videoRecordedConfirmOrRetry)
        } else {
            text = viewModel.readingText != nil ? "" : String(format: String(.videoLimitDescFmt), "\(Int(viewModel.videoTimeLimit))")
        }
        return Text(text)
            .font(IDFont.custom(14, .regular))
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.3), value: camera.isRecording)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Group {
            if viewModel.videoURL != nil {
                let confirmActive = !viewModel.isLoading
                    && (viewModel.readingText == nil || (!viewModel.isTranscribing && viewModel.speechSuccess))
                HStack(spacing: 24) {
                    CustomCircleButton(background: .white.opacity(0.2), size: 64, action: retake) {
                        Image.sdk(.retry).font(.system(size: 20, weight: .medium)).foregroundColor(.white)
                    }
                    CustomCircleButton(background: confirmActive ? IDColor.primary : .white.opacity(0.15), size: 72,
                                       action: { viewModel.uploadVideo() }) {
                        Image.sdk(.checkmark)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(confirmActive ? .white : .white.opacity(0.4))
                    }
                    .disabled(!confirmActive)
                    CustomCircleButton(background: .white.opacity(0.2), size: 64, action: togglePlayback) {
                        Image.sdk(isVideoPlaying ? .pause : .play)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .offset(x: isVideoPlaying ? 0 : 2)
                    }
                }
            } else {
                let active = camera.isReady && !camera.isRecording && !viewModel.micBlocked
                CustomCircleButton(
                    background: camera.isRecording
                        ? (SDKTheme.shared.controls.recordingColor ?? IDColor.error)
                        : (active ? (SDKTheme.shared.controls.shutterFill ?? IDColor.primary) : .white.opacity(0.15)),
                    size: (SDKTheme.shared.controls.shutterSize ?? 72) + (camera.isRecording ? 20 : 0),
                    action: startRecording
                ) {
                    if camera.isRecording {
                        Text("\(camera.remainingSeconds)")
                            .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(.white)
                    } else {
                        Image.sdk(.video)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(active ? .white : .white.opacity(0.4))
                    }
                }
                .disabled(!active)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.videoURL != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: camera.isRecording)
        .animation(.easeInOut(duration: 0.2), value: isVideoPlaying)
        .animation(.easeInOut(duration: 0.2), value: viewModel.speechSuccess)
    }

    private func startRecording() {
        // Yönergenin sesi mikrofondan videoya karışmasın.
        SDKSpeechService.shared.stop()
        camera.startRecording(maxDuration: viewModel.videoTimeLimit) { url in
            guard let url else { return }
            viewModel.videoSelected(url: url)
            isCameraActive = false
            camera.stop()
        }
    }

    private func togglePlayback() {
        if isVideoPlaying {
            player?.pause()
        } else {
            player?.seek(to: .zero)
            player?.play()
        }
        isVideoPlaying.toggle()
    }
}

// MARK: - Sesli doğrulama başarısız sayfası

private struct SpeechFailSheet: View {
    let detectedText: String
    let score: Double
    let onRetry: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var sheet: SDKSheetAppearance { SDKTheme.shared.sheets }
    private var percent: Int { max(0, min(100, Int((score * 100).rounded()))) }

    private var bottomSafeInset: CGFloat {
        SDKLayout.activeWindow?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(sheet.handleColor?.resolve(scheme) ?? (scheme == .dark ? .white.opacity(0.18) : IDColor.inkBorder))
                .frame(width: sheet.handleWidth ?? 44, height: sheet.handleHeight ?? 5)
                .padding(.top, IDSpacing.sm)
                .padding(.bottom, IDSpacing.xl)

            Image.sdk(.thankYouFail)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .padding(.bottom, IDSpacing.lg)

            Text(.speechNoMatchTitle)
                .font(IDFont.displaySmall(.semibold))
                .foregroundColor(IDColor.error)
                .multilineTextAlignment(.center)
                .padding(.horizontal, IDSpacing.xl)
                .padding(.bottom, IDSpacing.xl)

            VStack(alignment: .leading, spacing: IDSpacing.sm) {
                Text(.detectedTextLabel)
                    .font(IDFont.custom(12, .regular))
                    .foregroundColor(IDColor.accentWarning)
                Text(detectedText.isEmpty ? "—" : detectedText.uppercased(with: Locale(identifier: IdentifyManager.shared.sdkLang?.sttLanguageCode ?? "tr")))
                    .font(IDFont.custom(detectedText.count > 60 ? 16 : 22, .bold))
                    .foregroundColor(IDColor.accentWarning)
                    .lineSpacing(4)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(IDSpacing.lg)
            .background(IDColor.accentWarning.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: IDRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: IDRadius.lg)
                .strokeBorder(IDColor.accentWarning, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            .padding(.horizontal, IDSpacing.xl)
            .padding(.bottom, IDSpacing.xl)

            VStack(spacing: IDSpacing.sm) {
                HStack {
                    Text(.similarityLabel)
                    Spacer()
                    Text("%\(percent)")
                }
                .font(IDFont.bodyMediumPlus(.regular))
                .foregroundColor(IDColor.inkSubtitle)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(scheme == .dark ? .white.opacity(0.14) : IDColor.inkBorder)
                        Capsule().fill(IDColor.accentWarning).frame(width: geo.size.width * CGFloat(percent) / 100)
                    }
                }
                .frame(height: IDSpacing.sm)
            }
            .padding(.horizontal, IDSpacing.xl)
            .padding(.bottom, IDSpacing.lg)

            Rectangle()
                .fill(scheme == .dark ? .white.opacity(0.08) : IDColor.inkBorder)
                .frame(height: 1)
                .padding(.bottom, IDSpacing.lg)

            Button(action: onRetry) {
                Text(.coreTryAgain)
                    .font(IDFont.bodyLarge(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(IDColor.primary)
                    .clipShape(SDKButtonShape.themed())
            }
            .padding(.horizontal, IDSpacing.xl)
            .padding(.bottom, IDSpacing.lg + bottomSafeInset)
        }
        .background(scheme == .dark ? IDColor.darkBgSecondary : .white)
        .clipShape(CustomTopRoundedShape(radius: IDRadius.xl))
        .shadow(color: .black.opacity(0.18), radius: 20, y: -4)
    }
}

// MARK: - Kamera (ön kamera + mikrofon, süre sınırlı kayıt)

@MainActor
final class VideoRecorderCamera: NSObject, ObservableObject {

    let session = AVCaptureSession()
    @Published private(set) var isRecording = false
    @Published private(set) var isReady = false
    @Published private(set) var remainingSeconds = 0
    var onSessionError: ((String) -> Void)?

    private let movieOutput = AVCaptureMovieFileOutput()
    private var device: AVCaptureDevice?
    private var completion: ((URL?) -> Void)?
    private var timer: Timer?

    func start() {
        isReady = false
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.configure()
            await MainActor.run {
                self.session.startRunning()
                self.isReady = true
            }
        }
    }

    func stop() {
        isReady = false
        stopCountdown()
        if movieOutput.isRecording { movieOutput.stopRecording() }
        let session = session
        Task.detached {
            session.stopRunning()
            // Kamera kapanınca ses oturumunu çalmaya bırak (oynatma ve sesli yönerge için);
            // süren bir görüşmenin ses oturumuna dokunulmaz.
            if !IdentifyManager.shared.isCallActive {
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        }
    }

    func startRecording(maxDuration: TimeInterval, completion: @escaping (URL?) -> Void) {
        guard !isRecording else { return }
        // Kayıt açısı önizlemenin aynı cihaz için ölçtüğü açıdır; kaydedilen video ekranda görülenle aynı olur.
        if let connection = movieOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if let device, let angle = CustomSensorRotation.angle(for: device), connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        self.completion = completion
        movieOutput.maxRecordedDuration = CMTime(seconds: maxDuration, preferredTimescale: 600)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true

        remainingSeconds = Int(ceil(maxDuration))
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remainingSeconds = max(0, self.remainingSeconds - 1)
                if self.remainingSeconds == 0 { self.stopCountdown() }
            }
        }
    }

    private func stopCountdown() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = 0
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            onSessionError?(String(.mediaAccessError))
            return
        }
        session.addInput(videoInput)
        device = videoDevice

        // Ses kanalı sesli okuma doğrulaması için gereklidir.
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        } else {
            onSessionError?(String(.mediaAccessError))
        }

        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        if let connection = movieOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        session.commitConfiguration()
        NotificationCenter.default.post(name: .customCameraReconfigured, object: session)
    }
}

extension VideoRecorderCamera: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection], error: Error?) {
        // Süre sınırına ulaşmak hata değildir.
        let succeeded = error == nil || (error as? AVError)?.code == .maximumDurationReached
        Task { @MainActor in
            self.isRecording = false
            self.stopCountdown()
            self.completion?(succeeded ? outputFileURL : nil)
            self.completion = nil
        }
    }
}

// MARK: - Oynatıcı

private struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.playerLayer.player !== player { uiView.playerLayer.player = player }
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

#Preview("Kısa Video — Özel Ekran") {
    SDKModulePreviewHost { VideoRecorderCustomView() }
}
