//
//  ShowcaseSupport.swift
//  IdentifySample
//
//  SDK Modül Rehberi (Showcase) için paylaşılan yardımcılar.
//
//  Amaç: Bu uygulama bir ENTEGRASYON REHBERİDİR. Geliştirici, SDK'nın her
//  modülünü (1) varsayılan haliyle, (2) tema ile özelleştirilmiş, (3) tamamen
//  kendi view'ı ile (XxxCustomView) değiştirilmiş olarak görür; ayrıca her ekran Xcode #Preview'da
//  canlı görünür.
//
//  SDK modül ekranları (SDKSelfieView vb.) `@EnvironmentObject SDKFlowCoordinator`
//  bekler. Rehber/Preview ortamında gerçek bir backend oturumu olmadığından,
//  ekranları çizebilmek için boş bir "mock" coordinator enjekte ederiz. Bu sayede
//  tasarım/UI görünür; kamera/canlı alanlar yalnızca gerçek akışta çalışır.
//

import SwiftUI
import IdentifySDK

// MARK: - Mock coordinator enjeksiyonu

extension View {
    /// SDK modül ekranını rehber/preview ortamında çizmek için boş bir
    /// `SDKFlowCoordinator` enjekte eder. Gerçek akışta coordinator LoginView'dan gelir.
    @MainActor
    func showcaseHost() -> some View {
        modifier(ShowcaseHostModifier())
    }
}

private struct ShowcaseHostModifier: ViewModifier {
    @StateObject private var coordinator = SDKFlowCoordinator()
    func body(content: Content) -> some View {
        content.environmentObject(coordinator)
    }
}

// MARK: - Tema override (özelleştirme örneği)

extension View {
    /// Bu ekran görünürken SDKTheme primary rengini geçici olarak değiştirir,
    /// çıkışta eski rengi geri yükler. (SDKTheme observable olmadığından `.id` ile
    /// tek seferlik yeniden çizim tetiklenir.) Tema-override örneği için kullanılır.
    @MainActor
    func showcaseThemed(primary: Color) -> some View {
        modifier(ShowcaseThemeOverride(primary: primary))
    }
}

private struct ShowcaseThemeOverride: ViewModifier {
    let primary: Color
    @State private var applied = false
    @State private var original: Color? = nil

    func body(content: Content) -> some View {
        content
            .id(applied)
            .onAppear {
                if original == nil { original = SDKTheme.shared.colors.primary }
                SDKTheme.shared.colors.primary = primary
                applied = true
                
            }
            .onDisappear {
                if let original { SDKTheme.shared.colors.primary = original }
            }
    }
}

// MARK: - Canlı önizleme kutusu

/// SDK modül ekranını sabit yükseklikte, çerçeveli bir "cihaz önizlemesi" içinde gösterir.
/// (Tam ekran göstermek katalog navigasyonu ile çakışırdı; modülün kendi geri butonu
///  mock coordinator üzerinde çalışır, kataloğu etkilemez.)
///
/// İçerik kendi `NavigationView`'ına sarılır: bazı SDK ekranları
/// `.navigationBarHidden(true)` çağırır (Liveness, ThankYou, SelfieWithLiveness,
/// LostConnection). Sarmalanmazsa bu modifier KATALOĞUN nav bar'ını gizler ve
/// detay sayfasında geri butonu kaybolur. İç NavigationView bu etkiyi izole eder.
struct ShowcaseLivePreview<Content: View>: View {
    private let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        NavigationView {
            content()
                .showcaseHost()
                .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // Kart değil: kalan dikey alanın tamamını kaplar ve ekranın altına kadar iner.
        // Modül ekranları gerçek akıştaki ölçüsüyle görünsün diye (iPhone + iPad).
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(ShowcaseTopRoundedRect(radius: 20))
        .overlay(
            ShowcaseTopRoundedRect(radius: 20)
                .stroke(IDColor.inkBorder, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Text("CANLI")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(IDColor.primary, in: Capsule())
                .foregroundColor(.white)
                .padding(10)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Üstten yuvarlatılmış çerçeve

/// Yalnız üst köşeleri yuvarlatır. Önizleme ekranın alt kenarına dayandığı için alt
/// köşelerin yuvarlatılması cihaz kenarında boşluk gibi görünürdü.
struct ShowcaseTopRoundedRect: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect,
                          byRoundingCorners: [.topLeft, .topRight],
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

// MARK: - Kod bloğu

/// Entegrasyon/özelleştirme kod parçacığını monospace bir kart içinde gösterir (kopyalanabilir).
struct ShowcaseCodeBlock: View {
    let title: String
    let code: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: IDSpacing.sm) {
            HStack {
                Text(title)
                    .font(IDFont.bodyRegular(.semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Kopyalandı" : "Kopyala",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    .padding(IDSpacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: IDRadius.md)
                    .fill(IDColor.adaptiveSurface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: IDRadius.md)
                    .stroke(IDColor.inkBorder, lineWidth: 1)
            )
        }
    }
}
