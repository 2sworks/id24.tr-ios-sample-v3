//
//  ShowcaseDesignSystem.swift
//  IdentifySample
//
//  SDK'nın TASARIM SİSTEMİ yetenekleri — modüllerin ötesinde, SDK'nın sunduğu
//  ortak UI primitifleri. Geliştirici bunları görüp kendi temasını/override'ını kurar:
//    • Renkler   → IDColor / SDKTheme.shared.colors
//    • Tipografi → IDFont   / SDKTheme.shared.fonts (registerFont)
//    • Nav Bar   → SDKNavigationBar (5 stil)
//    • Buton     → SDKButton (4 stil + durumlar)
//

import SwiftUI
import IdentifySDK

// MARK: - Renkler

struct ColorsShowcaseView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var swatches: [(String, Color)] {
        [
            ("primary", IDColor.primary), ("primaryDark", IDColor.primaryDark), ("primaryLight", IDColor.primaryLight),
            ("success", IDColor.success), ("successBright", IDColor.successBright), ("error", IDColor.error),
            ("accentPurple", IDColor.accentPurple), ("accentTeal", IDColor.accentTeal),
            ("inkDarkest", IDColor.inkDarkest), ("inkMid", IDColor.inkMid), ("inkLight", IDColor.inkLight),
            ("inkBorder", IDColor.inkBorder), ("inkSurface", IDColor.inkSurface), ("divider", IDColor.divider)
        ]
    }
    private let cols = [GridItem(.adaptive(minimum: 120), spacing: IDSpacing.md)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: cols, spacing: IDSpacing.md) {
                ForEach(swatches, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: IDRadius.md)
                            .fill(color)
                            .frame(height: 56)
                            .overlay(RoundedRectangle(cornerRadius: IDRadius.md).stroke(IDColor.inkBorder, lineWidth: 1))
                        Text("IDColor." + name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .padding(IDSpacing.lg)
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
    }
}

// MARK: - Tipografi

struct FontsShowcaseView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var scale: [(String, Font)] {
        [
            ("displayLarge", IDFont.displayLarge()), ("displayMedium", IDFont.displayMedium()),
            ("displaySmall", IDFont.displaySmall()), ("bodyLarge", IDFont.bodyLarge()),
            ("bodyMedium", IDFont.bodyMedium()), ("bodyRegular", IDFont.bodyRegular()),
            ("bodySmall", IDFont.bodySmall()), ("caption", IDFont.caption())
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: IDSpacing.lg) {
                ForEach(scale, id: \.0) { name, font in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Identify SDK")
                            .font(font)
                            .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                        Text("IDFont." + name + "  (aktif aile: " + (SDKTheme.shared.fonts.familyName ?? "sistem") + ")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(IDSpacing.xl)
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
    }
}

// MARK: - Navigation Bar

struct NavBarShowcaseView: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Hazır başlık tasarımları — host tek satırla seçer.
    @State private var preset: SDKNavBarPreset = SDKTheme.shared.navBar.preset
    @State private var showsLogo = SDKTheme.shared.navBar.showsLogo ?? true
    @State private var showsDivider = SDKTheme.shared.navBar.showsDivider ?? false
    /// Marka başlığı: boş bırakılırsa SDK adım adını yazar; dolu ise çubuk markayı yazar.
    @State private var brandTitle = ""
    @State private var titleMode: SDKNavBarTitleMode = .brandWithModule
    @State private var revision = 0

    /// İkon override örnekleri. Boş seçenek = SDK varsayılanı (`resetIcon`).
    /// Host gerçek kullanımda `Image("kendi_asset")` verir; burada SF Symbol'ler yeter.
    private struct IconChoice: Identifiable, Hashable {
        let id: String       // SF Symbol adı; "" = SDK varsayılanı
        let label: String
    }
    private static let backChoices  = [IconChoice(id: "", label: "SDK"), IconChoice(id: "arrow.left", label: "ok"),
                                       IconChoice(id: "arrow.backward.circle.fill", label: "daire"), IconChoice(id: "xmark", label: "kapat")]
    private static let menuChoices  = [IconChoice(id: "", label: "SDK"), IconChoice(id: "ellipsis", label: "üç nokta"),
                                       IconChoice(id: "square.grid.2x2", label: "ızgara"), IconChoice(id: "person.crop.circle", label: "profil")]
    private static let helpChoices  = [IconChoice(id: "", label: "SDK"), IconChoice(id: "info.circle", label: "bilgi"),
                                       IconChoice(id: "lifepreserver", label: "destek"), IconChoice(id: "bubble.left", label: "sohbet")]
    private static let logoChoices  = [IconChoice(id: "", label: "SDK"), IconChoice(id: "building.columns.fill", label: "banka"),
                                       IconChoice(id: "shield.checkered", label: "kalkan"), IconChoice(id: "leaf.fill", label: "yaprak")]
    @State private var backIcon = ""
    @State private var menuIcon = ""
    @State private var helpIcon = ""
    @State private var logoIcon = ""

    /// Örneklerin hangi renk şemasıyla çizileceği. Başlık çubuğu renkleri light/dark
    /// ayrı token'lardan gelir; ikisini cihaz ayarını değiştirmeden karşılaştırmak için.
    private enum PreviewScheme: String, CaseIterable, Identifiable {
        case system = "Cihaz"
        case light  = "Açık"
        case dark   = "Koyu"
        var id: String { rawValue }
    }

    @State private var previewScheme: PreviewScheme = .system

    /// Örneklere uygulanacak şema (`.system` ise cihazın şeması).
    private var resolvedScheme: ColorScheme {
        switch previewScheme {
        case .system: return colorScheme
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    private var presetTitle: String {
        switch preset {
        case .classic:   return "Solda geri + marka işareti + başlık (SDK varsayılanı)"
        case .centered:  return "Başlık ve marka işareti ortada"
        case .minimal:   return "Marka işareti yok, ince çubuk (48pt)"
        case .prominent: return "İki satır: üstte kontroller, altta büyük başlık"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: IDSpacing.xl) {

                VStack(alignment: .leading, spacing: IDSpacing.md) {
                    Text("Tasarım (preset)")
                        .font(IDFont.bodyMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    Picker("", selection: $preset) {
                        ForEach(SDKNavBarPreset.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: preset) { _ in apply() }

                    Text(presetTitle)
                        .font(IDFont.caption(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))

                    Divider().padding(.vertical, 2)

                    Text("Önizleme şeması")
                        .font(IDFont.bodyMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    Picker("", selection: $previewScheme) {
                        ForEach(PreviewScheme.allCases) { sch in
                            Text(sch.rawValue).tag(sch)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Başlık renkleri light ve dark için ayrı token'lardır (`headerBackground`, `headerTitle`, `headerIcon`); bu seçici cihaz ayarını değiştirmeden ikisini de gösterir.")
                        .font(IDFont.caption(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))

                    Divider().padding(.vertical, 2)

                    Toggle("Marka işaretini göster", isOn: $showsLogo)
                        .font(IDFont.caption(.regular))
                        .onChange(of: showsLogo) { _ in apply() }
                    Toggle("Alt ayırıcı çizgi", isOn: $showsDivider)
                        .font(IDFont.caption(.regular))
                        .onChange(of: showsDivider) { _ in apply() }

                    Divider().padding(.vertical, 2)

                    Text("İkonlar")
                        .font(IDFont.bodyMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    iconRow("Geri",   selection: $backIcon, choices: Self.backChoices)
                    iconRow("Menü",   selection: $menuIcon, choices: Self.menuChoices)
                    iconRow("Yardım", selection: $helpIcon, choices: Self.helpChoices)
                    iconRow("Logo",   selection: $logoIcon, choices: Self.logoChoices)
                    Text("Geri/menü/yardım ve marka işareti `SDKTheme.shared.setIcon(_:_:)` ile değişir; anahtarlar `.back`, `.hamburger`, `.help`, `.logo` (login + kamera üstü), `.headerLogo` (modül dairesi). Burada SF Symbol; host kendi asset'ini verir.")
                        .font(IDFont.caption(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                    if !(backIcon.isEmpty && menuIcon.isEmpty && helpIcon.isEmpty && logoIcon.isEmpty) {
                        Text(iconSnippet)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(IDColor.accentPurple)
                    }

                    Divider().padding(.vertical, 2)

                    Text("Marka başlığı")
                        .font(IDFont.bodyMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    TextField("Örn. Acme Bank (boş = adım adı)", text: $brandTitle)
                        .font(IDFont.bodyRegular())
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .onChange(of: brandTitle) { _ in apply() }
                    Picker("", selection: $titleMode) {
                        Text("Marka + adım").tag(SDKNavBarTitleMode.brandWithModule)
                        Text("Yalnız marka").tag(SDKNavBarTitleMode.brand)
                    }
                    .pickerStyle(.segmented)
                    .disabled(brandTitle.isEmpty)
                    .onChange(of: titleMode) { _ in apply() }
                    Text("Varsayılanda çubuk adım adını yazar (\"Kimlik Doğrulama\"). Marka verilince üst satır marka, alt satır adım adı olur; \"Yalnız marka\" adım adını kaldırır. Kamera üstü ekranlarda marka logonun yanına yazılır. Adım adlarının kendisi `SDKLocalization.shared.setOverride` ile değiştirilir.")
                        .font(IDFont.caption(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))

                    Text("SDKTheme.shared.navBar.preset = .\(preset.rawValue)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(IDColor.accentPurple)
                    if !brandTitle.isEmpty {
                        Text("SDKTheme.shared.navBar.brandTitle = \"\(brandTitle)\"\nSDKTheme.shared.navBar.titleMode = .\(titleMode.rawValue)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(IDColor.accentPurple)
                    }
                    Text("Header marka işareti: SDKTheme.shared.setIcon(.headerLogo, Image(\"my_mark\"))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                }
                .padding(IDSpacing.lg)
                .background(RoundedRectangle(cornerRadius: IDRadius.lg).fill(IDColor.adaptiveSurface(for: colorScheme)))
                .padding(.horizontal, IDSpacing.lg)

                // Yalnız ÖRNEKLER yeniden kurulur. `.id(revision)` sayfanın tamamındayken her
                // tuşta TextField de yeniden yaratılıyor, klavye kapanıyordu.
                Group {
                labeled(".login") {
                    themedPreview {
                        SDKNavigationBar(style: .login, onMenu: {})
                    }
                }
                labeled(".module") {
                    themedPreview {
                        SDKNavigationBar(style: .module, title: "Kimlik Doğrulama", subtitle: "Adım 2/5", onBack: {})
                    }
                }
                labeled(".progress(steps: 5, current: 2)") {
                    themedPreview {
                        SDKNavigationBar(style: .progress(steps: 5, current: 2), title: "Süreç", onBack: {})
                    }
                }
                labeled(".overlay (görüntü üstü)") {
                    SDKNavigationBar(style: .overlay, onBack: {}, onHelp: {})
                        .frame(height: 120)
                        .background(IDColor.inkDarkest)
                        .environment(\.colorScheme, .dark)   // kamera görüntüsü üstü: her zaman koyu zemin
                }
                }
                .id(revision)
            }
            .padding(.vertical, IDSpacing.lg)
        }
        .scrollDismissesKeyboardCompat()
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .onDisappear {
            // Global durumu temiz bırak: showcase dışına preset/ikon taşınmasın.
            SDKTheme.shared.navBar = SDKNavBarAppearance()
            for key in [SDKIconKey.back, .hamburger, .help, .logo, .headerLogo] { SDKTheme.shared.resetIcon(key) }
        }
    }

    /// Tek ikon seçici satırı.
    private func iconRow(_ label: String, selection: Binding<String>, choices: [IconChoice]) -> some View {
        HStack(spacing: IDSpacing.sm) {
            Text(label)
                .font(IDFont.caption(.regular))
                .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                .frame(width: 52, alignment: .leading)
            Picker("", selection: selection) {
                ForEach(choices) { c in
                    if c.id.isEmpty { Text(c.label).tag(c.id) }
                    else { Image(systemName: c.id).tag(c.id) }
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection.wrappedValue) { _ in apply() }
        }
    }

    /// Seçili ikonlar için kopyalanacak kod.
    private var iconSnippet: String {
        var lines: [String] = []
        if !backIcon.isEmpty { lines.append("SDKTheme.shared.setIcon(.back, Image(systemName: \"\(backIcon)\"))") }
        if !menuIcon.isEmpty { lines.append("SDKTheme.shared.setIcon(.hamburger, Image(systemName: \"\(menuIcon)\"))") }
        if !helpIcon.isEmpty { lines.append("SDKTheme.shared.setIcon(.help, Image(systemName: \"\(helpIcon)\"))") }
        if !logoIcon.isEmpty {
            lines.append("SDKTheme.shared.setIcon(.logo, Image(systemName: \"\(logoIcon)\"))")
            lines.append("SDKTheme.shared.setIcon(.headerLogo, Image(systemName: \"\(logoIcon)\"))")
        }
        return lines.joined(separator: "\n")
    }

    /// Seçimleri global temaya yazar ve örnekleri yeniden çizdirir.
    private func apply() {
        SDKTheme.shared.navBar.preset = preset
        SDKTheme.shared.navBar.showsLogo = showsLogo
        SDKTheme.shared.navBar.showsDivider = showsDivider
        SDKTheme.shared.navBar.brandTitle = brandTitle.isEmpty ? nil : brandTitle
        SDKTheme.shared.navBar.titleMode = titleMode
        applyIcon(.back, backIcon)
        applyIcon(.hamburger, menuIcon)
        applyIcon(.help, helpIcon)
        applyIcon(.logo, logoIcon)
        applyIcon(.headerLogo, logoIcon)
        revision += 1
    }

    private func applyIcon(_ key: SDKIconKey, _ symbol: String) {
        if symbol.isEmpty { SDKTheme.shared.resetIcon(key) }
        else { SDKTheme.shared.setIcon(key, Image(systemName: symbol)) }
    }

    /// Örneği seçilen şemada, o şemanın sayfa zemini üzerinde çizer. Başlık çubuğu
    /// varsayılanda şeffaftır (zemini sayfa verir); zemin olmadan koyu şemadaki açık
    /// metin açık zeminde kalıyor ve okunmuyordu. Host `headerBackground` verdiyse
    /// çubuk kendi zeminini zaten boyar.
    @ViewBuilder
    private func themedPreview<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        content()
            .background(IDColor.adaptiveBackground(for: resolvedScheme))
            .environment(\.colorScheme, resolvedScheme)
    }

    private func labeled<V: View>(_ title: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: IDSpacing.sm) {
            Text(title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                .padding(.horizontal, IDSpacing.lg)
            content()
        }
    }
}

// MARK: - Buton

struct ButtonsShowcaseView: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Canlı denenen köşe seçenekleri.
    private enum CornerChoice: String, CaseIterable, Identifiable {
        case capsule = "Kapsül"
        case soft    = "16 pt"
        case sharp   = "4 pt"
        case square  = "Köşeli"
        var id: String { rawValue }
        var corner: SDKButtonCorner {
            switch self {
            case .capsule: return .capsule
            case .soft:    return .radius(16)
            case .sharp:   return .radius(4)
            case .square:  return .radius(0)
            }
        }
    }

    @State private var corner: CornerChoice = .capsule
    @State private var height: Double = 0          // 0 → padding'e göre otomatik
    @State private var outlined = false            // .secondary'ye kenarlık
    @State private var shadowed = false
    @State private var haptics = true
    /// Görünüm token'ları global (SDKTheme.shared) olduğu için tetikleyici sayaç.
    @State private var revision = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: IDSpacing.xl) {

                controls

                VStack(spacing: IDSpacing.lg) {
                    SDKButton(title: ".primary", style: .primary) {}
                    SDKButton(title: ".secondary", style: .secondary) {}
                    SDKButton(title: ".success", style: .success) {}
                    SDKButton(title: ".cancel", style: .cancel) {}
                    SDKButton(title: "isLoading", style: .primary, isLoading: true) {}
                    SDKButton(title: "isDisabled", style: .primary, isDisabled: true) {}
                }
                .id(revision)

                codeBlock(snippet)

                Text("Köşe token'ı yalnızca SDKButton'ı değil, SDK'nın hazır ekranlarındaki "
                     + "tüm aksiyon butonlarını da kapsar (görüşme, ThankYou, bağlantı koptu, "
                     + "uyarı diyalogları). SDKButtonShape.themed() ile kendi ekranlarında da "
                     + "aynı biçimi kullanabilirsin.")
                    .font(IDFont.caption(.regular))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            }
            .padding(IDSpacing.xl)
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .onDisappear { SDKTheme.shared.buttons.reset() }   // global durumu temiz bırak
    }

    // MARK: Kontroller

    private var controls: some View {
        VStack(alignment: .leading, spacing: IDSpacing.md) {
            Text("Köşe (corner)")
                .font(IDFont.bodyMedium(.semibold))
                .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
            Picker("", selection: $corner) {
                ForEach(CornerChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: corner) { _ in apply() }

            HStack {
                Text("Yükseklik: " + (height == 0 ? "otomatik" : "\(Int(height)) pt"))
                    .font(IDFont.caption(.regular))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                Spacer()
            }
            Slider(value: $height, in: 0...72, step: 4) { editing in
                if !editing { apply() }
            }

            Toggle("Kenarlık (.secondary)", isOn: $outlined)
                .font(IDFont.caption(.regular))
                .onChange(of: outlined) { _ in apply() }
            Toggle("Gölge", isOn: $shadowed)
                .font(IDFont.caption(.regular))
                .onChange(of: shadowed) { _ in apply() }
            Toggle("Titreşim (haptic)", isOn: $haptics)
                .font(IDFont.caption(.regular))
                .onChange(of: haptics) { _ in apply() }
        }
        .padding(IDSpacing.lg)
        .background(RoundedRectangle(cornerRadius: IDRadius.lg).fill(IDColor.adaptiveSurface(for: colorScheme)))
    }

    /// Seçimleri global temaya yazar ve butonları yeniden çizdirir.
    private func apply() {
        var base = SDKButtonAppearance()
        base.corner = corner.corner
        base.height = height == 0 ? nil : CGFloat(height)
        base.hapticsEnabled = haptics
        if shadowed {
            base.shadowColor = Color.black.opacity(0.25)
            base.shadowRadius = 12
            base.shadowOffsetY = 6
        }
        SDKTheme.shared.buttons.reset()
        SDKTheme.shared.buttons.base = base
        if outlined {
            SDKTheme.shared.buttons[.secondary].borderWidth = 1
            SDKTheme.shared.buttons[.secondary].borderColor = IDColor.divider
        }
        revision += 1
    }

    private var snippet: String {
        var lines = ["SDKTheme.shared.buttons.base.corner = " + cornerLiteral]
        if height > 0 { lines.append("SDKTheme.shared.buttons.base.height = \(Int(height))") }
        if !haptics   { lines.append("SDKTheme.shared.buttons.base.hapticsEnabled = false") }
        if shadowed {
            lines.append("SDKTheme.shared.buttons.base.shadowColor = .black.opacity(0.25)")
            lines.append("SDKTheme.shared.buttons.base.shadowRadius = 12")
            lines.append("SDKTheme.shared.buttons.base.shadowOffsetY = 6")
        }
        if outlined {
            lines.append("SDKTheme.shared.buttons[.secondary].borderWidth = 1")
            lines.append("SDKTheme.shared.buttons[.secondary].borderColor = IDColor.divider")
        }
        return lines.joined(separator: "\n")
    }

    private var cornerLiteral: String {
        switch corner {
        case .capsule: return ".capsule"
        case .soft:    return ".radius(16)"
        case .sharp:   return ".radius(4)"
        case .square:  return ".radius(0)"
        }
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(IDSpacing.md)
            .background(RoundedRectangle(cornerRadius: IDRadius.md).fill(IDColor.adaptiveSurface(for: colorScheme)))
    }
}

// MARK: - Uyarı (Alert)

struct AlertsShowcaseView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var active: IDAlertModel?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: IDSpacing.lg) {
                SDKButton(title: ".info — tek buton", style: .secondary) {
                    active = IDAlertModel(
                        type: .info, title: "Bilgi",
                        message: "Bu işlem geri alınamaz. Devam etmek istediğinizden emin misiniz?",
                        actions: [IDAlertAction(title: "Tamam", style: .primary)]
                    )
                }
                SDKButton(title: ".error — iki buton", style: .cancel) {
                    active = IDAlertModel(
                        type: .error, title: "Bağlantı Hatası",
                        message: "Sunucuya ulaşılamıyor. Lütfen internet bağlantınızı kontrol edin.",
                        actions: [
                            IDAlertAction(title: "İptal", style: .cancel),
                            IDAlertAction(title: "Tekrar Dene", style: .primary)
                        ]
                    )
                }
                SDKButton(title: ".success", style: .success) {
                    active = IDAlertModel(
                        type: .success, title: "Kimlik Doğrulandı",
                        message: "Kimlik doğrulama işleminiz başarıyla tamamlandı.",
                        actions: [IDAlertAction(title: "Devam Et", style: .primary)]
                    )
                }
                SDKButton(title: ".normal — destructive", style: .primary) {
                    active = IDAlertModel(
                        type: .normal, title: "Görüşmeyi bitir",
                        message: "Görüşmeyi sonlandırmak istediğinize emin misiniz?",
                        actions: [
                            IDAlertAction(title: "Vazgeç", style: .cancel),
                            IDAlertAction(title: "Bitir", style: .destructive)
                        ]
                    )
                }
            }
            .padding(IDSpacing.xl)
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .idAlert(item: $active)
    }
}

// MARK: - Özelleştirme (Metin + İkon override)

/// Host'un SDK'nın hazır ekranlarındaki METİN ve İKON'ları nasıl değiştireceğini gösterir.
/// Canlı demo: "Override uygula" butonu birkaç ikonu/metni runtime'da değiştirir,
/// ekrandan çıkınca eski haline döner (global SDKTheme/SDKLocalization durumu geri alınır).
struct CustomizationShowcaseView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var applied = false

    // Demo amaçlı override edilecek ikonlar ve alternatifleri (SF Symbol).
    private let iconDemo: [(SDKIconKey, String, Image)] = [
        (.camera,    "camera",    Image(systemName: "camera.aperture")),
        (.checkmark, "checkmark", Image(systemName: "checkmark.seal.fill")),
        (.retry,     "retry",     Image(systemName: "gobackward")),
        (.close,     "close",     Image(systemName: "xmark.octagon.fill"))
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: IDSpacing.xl) {

                section("1) İkon override — SDKTheme.shared.setIcon(_:_:)") {
                    HStack(spacing: IDSpacing.xl) {
                        ForEach(iconDemo, id: \.1) { key, name, _ in
                            VStack(spacing: 6) {
                                Image.sdk(key)                 // aktif (override edilmiş olabilir) ikon
                                    .renderingMode(.template)
                                    .resizable().scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(IDColor.accentPurple)
                                Text("." + name)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                            }
                        }
                    }
                    SDKButton(title: applied ? "Varsayılana dön" : "İkon + metin override uygula",
                              style: applied ? .cancel : .primary) {
                        applied ? revert() : apply()
                    }
                }

                section("2) Metin override — mevcut SDK key'i") {
                    codeBlock("""
                    // Tek key, tek dil:
                    SDKLocalization.shared.setOverride(
                        key: .continuePage, language: .de, value: "Weiter →")

                    // Toplu (dil → [JSONKey: değer]):
                    SDKLocalization.shared.registerOverrides([
                        .tr: ["Continue": "İlerle", "IdVerifyTitle": "Kimlik"],
                        .de: ["Continue": "Weiter"]
                    ])
                    // JSON dosyasından:
                    SDKLocalization.shared.loadOverrides(from: url, language: .de)
                    """)
                    Text("Aktif “devam” metni: \(SDKKeyword.continuePage.localized)")
                        .font(IDFont.bodyMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                }

                section("3) Host'un KENDİ yeni key'i — string(forKey:)") {
                    codeBlock("""
                    // Kendi key'ini SDK dil sistemine ekle:
                    SDKLocalization.shared.registerOverrides([
                        .tr: ["MyIntroTitle": "Hoş geldin"],
                        .en: ["MyIntroTitle": "Welcome"],
                        .de: ["MyIntroTitle": "Willkommen"]
                    ])
                    // Custom ekranında oku (aktif dile göre çözülür):
                    Text(SDKLocalization.shared.string(forKey: "MyIntroTitle"))
                    """)
                    Text("MyIntroTitle → \(SDKLocalization.shared.string(forKey: "MyIntroTitle"))")
                        .font(IDFont.bodyMedium(.semibold))
                        .foregroundColor(IDColor.accentTeal)
                }

                section("4) İkon anahtarları") {
                    Text("SDKIconKey: chrome (logo/hamburger/back/help/close), aksiyon "
                         + "(camera/checkmark/retry/trash/video/chat…), izin satırı (permCamera…), "
                         + "illüstrasyon (incomingCall/nfcFront/thankYouSuccess/lostConnection…), "
                         + "durum (torchOn/play/mic/wifiGood…). Her biri setIcon ile override edilir.")
                        .font(IDFont.caption(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                }
            }
            .padding(IDSpacing.xl)
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .onDisappear { if applied { revert() } }   // global durumu temiz bırak
    }

    private func apply() {
        for (key, _, img) in iconDemo { SDKTheme.shared.setIcon(key, img) }
        SDKLocalization.shared.registerOverrides([
            .tr: ["Continue": "İlerle ▸", "MyIntroTitle": "Hoş geldin"],
            .en: ["Continue": "Proceed ▸", "MyIntroTitle": "Welcome"],
            .de: ["Continue": "Weiter ▸", "MyIntroTitle": "Willkommen"]
        ])
        applied = true
    }

    private func revert() {
        for (key, _, _) in iconDemo { SDKTheme.shared.resetIcon(key) }
        SDKLocalization.shared.clearOverrides()
        SDKLocalization.shared.clearCache()
        applied = false
    }

    @ViewBuilder
    private func section<V: View>(_ title: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: IDSpacing.md) {
            Text(title)
                .font(IDFont.bodyMedium(.semibold))
                .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
            content()
        }
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(IDSpacing.md)
            .background(RoundedRectangle(cornerRadius: IDRadius.md).fill(IDColor.adaptiveSurface(for: colorScheme)))
    }
}

// MARK: - JSON ile Tema

/// Temanın **native derleme olmadan** uygulanabildiğini gösteren ekran.
/// React Native/Flutter köprüleri aynı sözlüğü `setTheme` ile geçirir.
struct ThemeJSONShowcaseView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var json = ThemeJSONShowcaseView.samples[0].1
    @State private var report = ""
    @State private var revision = 0

    /// Hazır örnekler: (ad, JSON).
    static let samples: [(String, String)] = [
        ("Koyu kurumsal", """
        {
          "colors": {
            "primary": "#0F172A",
            "pageBackground": { "light": "#F8FAFC", "dark": "#0B1120" },
            "moduleBackground": { "light": "#0F172A", "dark": "#0B1120" },
            "headerBackground": { "light": "#0F172A", "dark": "#0B1120" },
            "headerTitle": "#FFFFFF",
            "headerIcon": "#FFFFFF",
            "selectedItemBackground": "#1D4ED8",
            "selectedItemText": "#EFF6FF"
          },
          "navBar": { "preset": "centered", "showsDivider": true },
          "buttons": { "corner": 12, "height": 54 },
          "selection": { "cornerRadius": 10 }
        }
        """),
        ("Yumuşak / pastel", """
        {
          "colors": {
            "primary": "#8C33CC",
            "accentWarning": "#F59E0B",
            "pageBackground": { "light": "#FFFBFF", "dark": "#160B1F" },
            "selectedItemBackground": "#8C33CC",
            "progressActive": "#8C33CC"
          },
          "navBar": { "preset": "prominent", "logoSize": 32 },
          "buttons": { "corner": "capsule", "shadowColor": "#8C33CC", "shadowRadius": 14, "shadowOffsetY": 6 },
          "alerts": { "cornerRadius": 28 },
          "motion": { "transitionDuration": 0.35 }
        }
        """),
        ("Köşeli / yüksek kontrast", """
        {
          "colors": {
            "primary": "#000000",
            "pageBackground": { "light": "#FFFFFF", "dark": "#000000" },
            "selectedItemBackground": "#000000",
            "selectedItemText": "#FFFFFF",
            "unselectedItemBackground": { "light": "#F1F1F1", "dark": "#1C1C1E" },
            "border": { "light": "#000000", "dark": "#FFFFFF" }
          },
          "navBar": { "preset": "minimal", "showsDivider": true },
          "buttons": { "corner": 0, "borderWidth": 2, "borderColor": "#FFFFFF" },
          "selection": { "cornerRadius": 0, "checkboxCornerRadius": 0 },
          "fields": { "cornerRadius": 0, "borderWidth": 2 }
        }
        """)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: IDSpacing.lg) {

                Text("Aşağıdaki sözlük SDK'ya olduğu gibi verilir. React Native tarafında "
                     + "IdentifySdk.setTheme(...), Flutter'da IdentifySdk.instance.setTheme(...) "
                     + "aynı şemayı kullanır — renk denemesi için native derleme gerekmez.")
                    .font(IDFont.caption(.regular))
                    .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))

                HStack(spacing: IDSpacing.sm) {
                    ForEach(Self.samples, id: \.0) { name, sample in
                        Button(name) { json = sample }
                            .font(IDFont.caption(.semibold))
                            .padding(.horizontal, IDSpacing.md)
                            .padding(.vertical, IDSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: IDRadius.sm).fill(IDColor.adaptiveSurface(for: colorScheme)))
                            .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    }
                }

                TextEditor(text: $json)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 260)
                    .padding(IDSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: IDRadius.md).fill(IDColor.adaptiveSurface(for: colorScheme)))

                HStack(spacing: IDSpacing.md) {
                    SDKButton(title: "Uygula") { applyJSON() }
                    SDKButton(title: "Sıfırla", style: .cancel) {
                        SDKTheme.shared.resetAppearance()
                        report = "Tüm görünüm override'ları silindi."
                        revision += 1
                    }
                }

                if !report.isEmpty {
                    Text(report)
                        .font(IDFont.caption(.regular))
                        .foregroundColor(report.hasPrefix("Tanınmayan") ? IDColor.error : IDColor.success)
                }

                Text("Önizleme")
                    .font(IDFont.bodyMedium(.semibold))
                    .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))

                VStack(spacing: IDSpacing.md) {
                    SDKNavigationBar(style: .progress(steps: 5, current: 2),
                                     title: "Kimlik Doğrulama", subtitle: "Adım 2/5", onBack: {})
                    SDKButton(title: "Devam") {}
                    SDKButton(title: "Vazgeç", style: .cancel) {}
                }
                .id(revision)
                .padding(IDSpacing.md)
                .background(RoundedRectangle(cornerRadius: IDRadius.lg)
                    .fill(IDColor.pageBackground(for: colorScheme)))
                .overlay(RoundedRectangle(cornerRadius: IDRadius.lg)
                    .stroke(IDColor.adaptiveBorder(for: colorScheme), lineWidth: 1))
            }
            .padding(IDSpacing.xl)
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .onDisappear { SDKTheme.shared.resetAppearance() }
    }

    /// Metindeki JSON'u SDK'ya uygular ve tanınmayan anahtarları raporlar.
    private func applyJSON() {
        guard let data = json.data(using: .utf8) else { return }
        let unknown = SDKTheme.shared.apply(json: data)
        report = unknown.isEmpty
            ? "Uygulandı — tüm anahtarlar tanındı."
            : "Tanınmayan anahtar: " + unknown.joined(separator: ", ")
        revision += 1
    }
}

// MARK: - Previews
#Preview("Özelleştirme") { CustomizationShowcaseView() }
#Preview("Renkler") { ColorsShowcaseView() }
#Preview("Tipografi") { FontsShowcaseView() }
#Preview("Nav Bar") { NavBarShowcaseView() }
#Preview("Buton") { ButtonsShowcaseView() }
#Preview("Uyarı") { AlertsShowcaseView() }
#Preview("JSON ile Tema") { ThemeJSONShowcaseView() }


// MARK: - Klavye yardımcısı

private extension View {
    /// Kaydırınca klavyeyi kapatır; iOS 16+ API'si, 15'te etkisiz kalır (zararsız).
    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) { self.scrollDismissesKeyboard(.interactively) } else { self }
    }
}
