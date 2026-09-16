//
//  CustomComponents.swift
//  IdentifySample
//
//  Özel ekranların paylaştığı küçük görsel bileşenler. Hepsi SDK'nın public tema
//  token'larıyla (IDColor, IDFont, IDRadius, SDKTheme) çizilir; SDK ekranlarıyla aynı görünür.
//

import SwiftUI
import UIKit
import IdentifySDK

// MARK: - Üst köşeleri yuvarlak şekil (alt paneller)

struct CustomTopRoundedShape: Shape {
    let radius: CGFloat

    /// iOS 15 uyumlu (`UnevenRoundedRectangle` iOS 16+).
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius,
                    startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Yuvarlak aksiyon butonu (çekim ekranları)

struct CustomCircleButton<Icon: View>: View {
    let background: Color
    let size: CGFloat
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(background).frame(width: size, height: size)
                icon()
            }
        }
    }
}

// MARK: - Başarı banner'ı

struct CustomSuccessBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var banner: SDKBannerAppearance { SDKTheme.shared.banners }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: IDRadius.sm)
                    .fill(IDColor.success.opacity(banner.iconCircleOpacity ?? 0.15))
                    .frame(width: banner.iconCircleSize ?? 38, height: banner.iconCircleSize ?? 38)
                Image.sdk(.checkmark)
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundColor(IDColor.success)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(.coreSuccess)
                    .font(IDFont.bodyRegular(.semibold))
                    .foregroundColor(IDColor.success)
                Text(message)
                    .font(IDFont.caption(.regular))
                    .foregroundColor(IDColor.success)
            }
            Spacer()
            if let onDismiss {
                Button(action: onDismiss) {
                    Image.sdk(.close)
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundColor(IDColor.success.opacity(0.7))
                        .padding(8)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: banner.cornerRadius ?? IDRadius.lg)
                .fill(colorScheme == .dark ? IDColor.darkBgSecondary : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: banner.cornerRadius ?? IDRadius.lg)
                        .strokeBorder(colorScheme == .dark ? IDColor.success.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08),
                radius: banner.shadowRadius ?? 8, x: 0, y: banner.shadowOffsetY ?? 4)
    }
}

extension View {
    /// Üstte ~2 sn görünüp kendiliğinden kapanan başarı banner'ı.
    func customSuccessBanner(_ message: String, isVisible: Bool) -> some View {
        modifier(CustomSuccessBannerModifier(message: message, isVisible: isVisible))
    }

    /// Boş alana dokununca klavyeyi kapatır.
    func customDismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

private struct CustomSuccessBannerModifier: ViewModifier {
    let message: String
    let isVisible: Bool
    @State private var isDismissed = false

    private var shouldShow: Bool { isVisible && !isDismissed }

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if shouldShow {
                CustomSuccessBanner(message: message) { isDismissed = true }
                    .padding(.horizontal, IDSpacing.lg)
                    .padding(.top, IDSpacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        isDismissed = true
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShow)
        .onChange(of: isVisible) { if $0 { isDismissed = false } }
    }
}

// MARK: - WebRTC video görünümü

/// `SDKCallScreenViewModel.remoteVideoView` / `localVideoView` UIView'larını SwiftUI'a bağlar.
/// WebRTC render view'ı en-boy oranını kendisi yönetir; burada yalnızca kapsayıcıya sabitlenir.
struct CustomVideoFeedView: UIViewRepresentable {
    let videoView: UIView?

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let videoView else {
            uiView.subviews.forEach { $0.removeFromSuperview() }
            return
        }
        guard videoView.superview !== uiView else { return }
        videoView.removeFromSuperview()
        videoView.translatesAutoresizingMaskIntoConstraints = false
        uiView.addSubview(videoView)
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: uiView.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
        ])
    }
}
