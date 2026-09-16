//
//  CustomScreensView.swift
//  IdentifySample
//
//  Hamburger menü → "Tam Özel Ekranlar". İki iş yapar:
//    1) Anahtar: akış başlatıldığında SDK ekranları yerine bu projedeki XxxCustomView'lar kullanılır
//       (`CustomScreens.register` her ekran açılışında anahtarı okur).
//    2) Liste: her özel ekranı tek başına canlı açar — kamera/ARKit gerçek çalışır, ama oturum
//       olmadığı için yükleme/ilerleme yoktur. Uçtan uca davranış için anahtarı açıp akışı başlatın.
//

import SwiftUI
import IdentifySDK

struct CustomScreensView: View {

    @AppStorage(CustomScreens.storageKey) private var isEnabled = false
    @AppStorage(CustomScreens.idCardSingleScreenKey) private var isIdCardSingleScreen = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private struct Entry: Identifiable {
        let id: String
        let title: String
        let file: String
        let icon: String
        let build: () -> AnyView
    }

    private let entries: [Entry] = [
        .init(id: "prepare", title: "Hazırlık", file: "PrepareCustomView.swift", icon: "checklist") { AnyView(PrepareCustomView()) },
        .init(id: "idCard", title: "Kimlik (OCR)", file: "IdCardCustomView.swift", icon: "person.text.rectangle") { AnyView(IdCardCustomView()) },
        .init(id: "idCardSingle", title: "Kimlik — Tek Ekran Tarama", file: "IdCardSingleScreenCustomView.swift", icon: "rectangle.on.rectangle") { AnyView(IdCardSingleScreenCustomView()) },
        .init(id: "ovd", title: "Kimlik + OVD", file: "IdCardOVDCustomView.swift", icon: "sparkles.rectangle.stack") { AnyView(IdCardOVDCustomView()) },
        .init(id: "nfc", title: "NFC", file: "NfcCustomView.swift", icon: "wave.3.right") { AnyView(NfcCustomView()) },
        .init(id: "selfie", title: "Selfie", file: "SelfieCustomView.swift", icon: "person.crop.square") { AnyView(SelfieCustomView()) },
        .init(id: "swl", title: "Canlılıkla Selfie", file: "SelfieWithLivenessCustomView.swift", icon: "faceid") { AnyView(SelfieWithLivenessCustomView()) },
        .init(id: "liveness", title: "Canlılık", file: "LivenessCustomView.swift", icon: "faceid") { AnyView(LivenessCustomView()) },
        .init(id: "speech", title: "Konuşma", file: "SpeechCustomView.swift", icon: "waveform") { AnyView(SpeechCustomView()) },
        .init(id: "address", title: "Adres Onayı", file: "AddressConfirmCustomView.swift", icon: "house") { AnyView(AddressConfirmCustomView()) },
        .init(id: "signature", title: "İmza", file: "SignatureCustomView.swift", icon: "signature") { AnyView(SignatureCustomView()) },
        .init(id: "video", title: "Kısa Video", file: "VideoRecorderCustomView.swift", icon: "video") { AnyView(VideoRecorderCustomView()) },
        .init(id: "call", title: "Görüntülü Görüşme", file: "CallScreenCustomView.swift", icon: "phone.and.waveform") { AnyView(CallScreenCustomView()) },
        .init(id: "signLang", title: "İşaret Dili", file: "SignLangCustomView.swift", icon: "hands.sparkles") { AnyView(SignLangCustomView(onFinish: {})) },
        .init(id: "lost", title: "Bağlantı Koptu", file: "LostConnectionCustomView.swift", icon: "wifi.slash") { AnyView(LostConnectionCustomView()) },
        .init(id: "thankYou", title: "Teşekkürler", file: "ThankYouCustomView.swift", icon: "checkmark.seal") { AnyView(ThankYouCustomView(status: .completed)) },
    ]

    var body: some View {
        NavigationView {
            ZStack {
                IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: IDSpacing.lg) {
                            toggleCard
                            idCardSingleScreenToggle
                            Text("Bu ekranlar SDK ekranlarının yalnızca public API ile yazılmış birebir kopyasıdır. Listeden açılan ekran kamerayı gerçekten çalıştırır; oturum olmadığı için yükleme ve ilerleme olmaz. Uçtan uca davranış için anahtar açılır ve giriş yapılır.")
                                .font(IDFont.caption(.regular))
                                .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                                .lineSpacing(3)
                            VStack(spacing: IDSpacing.sm) {
                                ForEach(entries) { entry in
                                    NavigationLink {
                                        CustomScreenPreview(title: entry.title) { entry.build() }
                                    } label: {
                                        row(entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, IDSpacing.lg)
                        .padding(.bottom, IDSpacing.xxl)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tam Özel Ekranlar")
                    .font(IDFont.bodyLarge(.semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                Text("registry.override ile takılan XxxCustomView örnekleri")
                    .font(IDFont.caption())
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal, IDSpacing.xl)
        .padding(.top, IDSpacing.lg)
        .padding(.bottom, IDSpacing.md)
    }

    private var toggleCard: some View {
        HStack(spacing: IDSpacing.md) {
            Image(systemName: "paintbrush.pointed.fill")
                .foregroundColor(IDColor.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Akışta özel ekranları kullan")
                    .font(IDFont.bodyRegular(.semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                Text(isEnabled ? "Giriş yapınca tüm modüller özel ekranlarla açılır." : "Kapalı: SDK'nın kendi ekranları kullanılır.")
                    .font(IDFont.caption())
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            }
            Spacer()
            Toggle("", isOn: $isEnabled).labelsHidden().tint(IDColor.primary)
        }
        .padding(IDSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: IDRadius.lg)
                .fill(IDColor.adaptiveSurface(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: IDRadius.lg)
                    .stroke(isEnabled ? IDColor.primary.opacity(0.4) : IDColor.adaptiveBorder(for: colorScheme), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }

    private var idCardSingleScreenToggle: some View {
        HStack(spacing: IDSpacing.md) {
            Image(systemName: "rectangle.on.rectangle")
                .foregroundColor(IDColor.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Kimlik: tek ekran tarama")
                    .font(IDFont.bodyRegular(.semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                Text(isIdCardSingleScreen ? "Kimlik modülü ön + arka yüzü tek tam ekranda çeker." : "Kapalı: kimlik modülü yukarıdaki anahtara göre açılır.")
                    .font(IDFont.caption())
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            }
            Spacer()
            Toggle("", isOn: $isIdCardSingleScreen).labelsHidden().tint(IDColor.primary)
        }
        .padding(IDSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: IDRadius.lg)
                .fill(IDColor.adaptiveSurface(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: IDRadius.lg)
                    .stroke(isIdCardSingleScreen ? IDColor.primary.opacity(0.4) : IDColor.adaptiveBorder(for: colorScheme), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.2), value: isIdCardSingleScreen)
    }

    private func row(_ entry: Entry) -> some View {
        HStack(spacing: IDSpacing.md) {
            Image(systemName: entry.icon)
                .font(.system(size: 18))
                .foregroundColor(IDColor.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(IDFont.bodyRegular(.semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                Text(entry.file)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(IDColor.inkMid)
        }
        .padding(IDSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: IDRadius.md)
                .fill(IDColor.adaptiveSurface(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: IDRadius.md).stroke(IDColor.adaptiveBorder(for: colorScheme), lineWidth: 1))
        )
    }
}

// MARK: - Tek ekran canlı önizleme

/// Özel ekranı boş (mock) bir coordinator ile tam ekran çizer. Ekranın kendi geri butonu
/// coordinator'a gittiği için burada işe yaramaz; kapatma sağ üstteki ayrı düğmeyle yapılır.
private struct CustomScreenPreview<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content()
            .showcaseHost()
            .navigationBarHidden(true)
            // Kapatma düğmesi modülün parçası değildir: SDK nav bar'ından ayrı, sağ üstte,
            // rehber rengiyle (mor) ve beyaz çerçeveyle belirgin.
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(IDColor.accentPurple))
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                }
                .padding(.trailing, IDSpacing.md)
                .padding(.top, IDSpacing.sm)
            }
    }
}

#Preview {
    CustomScreensView()
}
