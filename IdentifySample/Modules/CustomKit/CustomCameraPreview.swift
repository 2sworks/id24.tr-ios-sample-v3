//
//  CustomCameraPreview.swift
//  IdentifySample
//
//  Özel ekranların paylaştığı kamera önizlemesi (AVCaptureVideoPreviewLayer).
//
//  SDK'nın kendi önizlemesiyle aynı davranır: ekran portrait'e kilitli olduğu için önizleme
//  cihaz eğimiyle dönmez; açı iOS 17+ `RotationCoordinator`'dan okunur (iPhone 17 ailesinde
//  ön sensör portrait monte edildiği için sabit 90° yazmak görüntüyü yan çevirir).
//
//  Kullanım:
//      CustomCameraPreview(session: camera.session)
//          .ignoresSafeArea()
//
//  Bu dosya yalnızca SwiftUI + AVFoundation kullanır; host projeye olduğu gibi kopyalanır.
//

import SwiftUI
import AVFoundation
import IdentifySDK

// MARK: - Önizleme (Xcode Preview'da yer tutucu)

struct CustomCameraPreview: View {
    let session: AVCaptureSession
    var placeholderIcon: String = "camera.fill"

    /// SDK'nın önizleme ortamı bayrağı (`SDKModulePreviewHost` açar). Açıkken kamera yerine yer tutucu çizilir.
    @Environment(\.sdkPreviewMode) private var sdkPreviewMode

    var body: some View {
        if sdkPreviewMode || CustomRuntime.isXcodePreview {
            CustomCameraPlaceholder(systemIcon: placeholderIcon)
        } else {
            CustomCameraLayerView(session: session)
        }
    }
}

/// Kamera çalışmadığı ortamlarda (Xcode Preview, simülatör) gösterilen koyu yer tutucu.
struct CustomCameraPlaceholder: View {
    var systemIcon: String = "camera.fill"

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.20), Color(white: 0.07)], startPoint: .top, endPoint: .bottom)
            Image(systemName: systemIcon)
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.45))
        }
    }
}

enum CustomRuntime {
    static var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// MARK: - Cihaz başına ölçülen önizleme açısı

/// Önizleme katmanına göre ölçülen video açısı, kamera cihazı başına saklanır.
/// Video kaydı gibi çıktılar da aynı açıyı kullanmalıdır (bkz. VideoRecorderCustomView).
enum CustomSensorRotation {
    private static var angles: [String: CGFloat] = [:]
    static func store(_ angle: CGFloat, for device: AVCaptureDevice) { angles[device.uniqueID] = angle }
    static func angle(for device: AVCaptureDevice) -> CGFloat? { angles[device.uniqueID] }
}

// MARK: - UIKit katmanı

struct CustomCameraLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.startObserving()
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.applyPortraitRotation()
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: ()) {
        uiView.stopObserving()
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        private var observers: [NSObjectProtocol] = []
        private var coordinator: Any?
        private var coordinatorDevice: AVCaptureDevice?

        deinit { stopObserving() }

        /// Oturum başladığında ya da girişleri değiştiğinde bağlantı yeniden yaratılır; açı yeniden yazılır.
        func startObserving() {
            guard observers.isEmpty else { return }
            for name in [Notification.Name.AVCaptureSessionDidStartRunning, .customCameraReconfigured] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.coordinator = nil
                    self?.coordinatorDevice = nil
                    self?.applyPortraitRotation()
                })
            }
        }

        func stopObserving() {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            applyPortraitRotation()
        }

        func applyPortraitRotation() {
            guard let connection = previewLayer.connection else { return }
            if #available(iOS 17.0, *) {
                if coordinator == nil,
                   let device = previewLayer.session?.inputs
                    .compactMap({ ($0 as? AVCaptureDeviceInput)?.device })
                    .first(where: { $0.hasMediaType(.video) }) {
                    coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
                    coordinatorDevice = device
                }
                guard let rc = coordinator as? AVCaptureDevice.RotationCoordinator,
                      let device = coordinatorDevice else { return }
                let target = rc.videoRotationAngleForHorizonLevelPreview
                CustomSensorRotation.store(target, for: device)
                if connection.videoRotationAngle != target, connection.isVideoRotationAngleSupported(target) {
                    connection.videoRotationAngle = target
                }
            } else if connection.isVideoOrientationSupported, connection.videoOrientation != .portrait {
                connection.videoOrientation = .portrait
            }
        }
    }
}

extension Notification.Name {
    /// Kamera denetleyicileri girişleri yeniden kurduktan sonra gönderir; önizleme açıyı yeniler.
    static let customCameraReconfigured = Notification.Name("CustomCameraReconfigured")
}
