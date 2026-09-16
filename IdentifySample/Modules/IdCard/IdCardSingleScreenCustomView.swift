//
//  IdCardSingleScreenCustomView.swift
//  IdentifySample
//
//  KİMLİK KARTI — TEK EKRAN, TAM EKRAN TARAMA ÖRNEĞİ
//
//  `IdCardCustomView` SDK ekranının birebir kopyasıdır (belge tipi seçimi → ön/arka slotlar →
//  her yüz için ayrı tarayıcı kapağı). Bu örnek aynı `SDKIdCardViewModel` ile farklı bir akış kurar:
//  modül açılır açılmaz kamera tam ekran çalışır, ön ve arka yüz aynı ekranda sırayla çekilir.
//
//      registry.override(.idCard) { IdCardSingleScreenCustomView() }
//
//  Akış:
//    ön yüz çekilir → sunucuya yüklenir → geçerliyse "doğrulandı" → arka yüz çerçevesine geçilir
//    arka yüz çekilir → sunucuya yüklenir → geçerliyse modül tamamlanır (advanceToNextModule)
//    herhangi bir yüz reddedilirse çerçevenin altında uyarı yazısı çıkar, 2 sn sonra aynı yüz otomatik yeniden çekilir
//
//  ViewModel kullanımı:
//    selectCardType(.idCard)                 ekran açılınca (bu örnek yalnızca çipli kimlik içindir)
//    scanFront(image:) / scanBack(image:)    tarayıcıdan gelen kırpılmış görüntü
//    currentSide == .back                    ön yüz sunucuda onaylandı
//    canContinue                             arka yüz sunucuda onaylandı
//    errorMessage + consumePendingAlertAction()   ret; haklar tükendiyse aksiyon modülü atlar/bitirir
//
//  Oturum yokken (socket bağlı değilken, ör. "Tam Özel Ekranlar" listesinden açılınca) sunucu yerine
//  dummy sonuç kullanılır: her çekim kısa bir yükleme görünümünden sonra onaylanmış sayılır.
//  `IdCardSingleScreenCustomView(simulateServer: true/false)` ile zorlanabilir.
//
//  Çerçeve içindeki silik kimlik görselleri SDK kaynak paketindeki `frontID` / `backID`
//  görselleridir (opacity 0.45).
//

import SwiftUI
import IdentifySDK

struct IdCardSingleScreenCustomView: View {

    /// Ekranın o anki durumu. Tarayıcı yalnızca `.scanning`'de kameradadır; diğer durumlarda
    /// çekilen kare çerçevede donmuş hâlde gösterilir.
    private enum Stage: Equatable {
        case scanning
        case uploading(UIImage)
        case verified(UIImage)
        case rejected(UIImage?, String)
        case completed(UIImage)
    }

    @StateObject private var viewModel = SDKIdCardViewModel()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator

    @State private var side: IdCardSide = .front
    @State private var stage: Stage = .scanning
    /// Her yeni deneme tarayıcıyı baştan kurar (kamera + otomatik çekim durumu sıfırlanır).
    @State private var attempt = 0
    @State private var isTorchOn = false
    @State private var isTorchAvailable = false
    /// Sunucu yerine dummy "onaylandı" sonucu kullanılıyor mu (bkz. `init(simulateServer:)`).
    @State private var isSimulated = false

    private let simulateServer: Bool?

    /// - Parameter simulateServer: `true` sunucuya gitmeden her çekimi onaylar, `false` daima sunucuyu
    ///   kullanır; `nil` (varsayılan) socket bağlı değilse dummy sonuca düşer.
    init(simulateServer: Bool? = nil) {
        self.simulateServer = simulateServer
    }

    private let frame = ScannerFixedFrame.idCard
    /// Rozetin merkezinin ekran altına mesafesi: tarayıcının yönerge metni ("Kimlik okunuyor…")
    /// altta 44 pt boşluk + 16 pt dolgu üstünde, tek satır ~22 pt; rozet onun hemen üstünde durur.
    private static let badgeBottomInset: CGFloat = 44 + 16 + 22 + 12 + 26
    private let accent = IDColor.primary

    var body: some View {
        GeometryReader { geo in
            let rect = frameRect(in: geo.size)
            ZStack {
                Color.black

                // Tarayıcı ekran boyunca takılı kalır: kamera oturumu çekimler arasında durmaz,
                // yeni deneme `scanSession` (attempt) artırılarak aynı oturumda başlatılır.
                ScannerHost(
                    side: side,
                    scanSession: attempt,
                    isTorchOn: $isTorchOn,
                    onTorchAvailability: { isTorchAvailable = $0 },
                    onResult: handleCapture
                )

                if stage != .scanning {
                    capturedCard(rect: rect)
                }

                ghostCard(rect: rect)
                statusBadge(size: geo.size)
                instruction(rect: rect)
                retryNote(rect: rect)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { topBar }
        .animation(.easeInOut(duration: 0.3), value: stage)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: side)
        .onAppear {
            viewModel.onSkipRequested = { coordinator.skipCurrentModule() }
            viewModel.onFlowFailed = { coordinator.finishFlowAsFailed() }
            isSimulated = simulateServer ?? !IdentifyManager.shared.isSocketConnected
            if !isSimulated { viewModel.selectCardType(.idCard) }
        }
        // Sunucu sonucu üç yayından okunur: ret mesajı, ön yüz onayı (arka yüze geçiş), arka yüz onayı.
        .onChange(of: viewModel.errorMessage) { message in
            guard let message, !message.isEmpty else { return }
            reject(message)
        }
        .onChange(of: viewModel.currentSide) { newSide in
            guard side == .front, newSide == .back else { return }
            frontPassed()
        }
        .onChange(of: viewModel.canContinue) { canContinue in
            guard canContinue, side == .back else { return }
            backPassed()
        }
    }

    // MARK: - Sonuç

    private func frontPassed() {
        guard case .uploading(let image) = stage else { return }
        stage = .verified(image)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard case .verified = stage else { return }
            side = .back
            attempt += 1
            stage = .scanning
        }
    }

    private func backPassed() {
        guard case .uploading(let image) = stage else { return }
        stage = .completed(image)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            coordinator.advanceToNextModule()
        }
    }

    /// Reddi altta yazar; 2 sn sonra aynı yüzü otomatik olarak yeniden çekime açar.
    private func reject(_ message: String) {
        let failedAttempt = attempt
        stage = .rejected(capturedImage, message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard case .rejected = stage, attempt == failedAttempt else { return }
            retry()
        }
    }

    // MARK: - Çekim

    private func handleCapture(_ result: Result<RecognizedDocument, Error>) {
        guard stage == .scanning else { return }
        switch result {
        case .success(let document):
            let image = document.croppedImage
            stage = .uploading(image)
            if isSimulated {
                // Dummy sunucu: kısa bir yükleme görünümünden sonra onaylandı say.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if side == .back { backPassed() } else { frontPassed() }
                }
            } else if side == .back {
                viewModel.scanBack(image: image)
            } else {
                viewModel.scanFront(image: image)
            }
        case .failure(let error):
            reject(error.localizedDescription)
        }
    }

    private func retry() {
        // Haklar tükendiyse bekleyen aksiyon modülü atlar ya da akışı bitirir; ekran kapanır.
        if viewModel.pendingAlertAction != nil {
            viewModel.errorMessage = nil
            viewModel.consumePendingAlertAction()
            return
        }
        viewModel.errorMessage = nil
        attempt += 1
        stage = .scanning
    }

    private var capturedImage: UIImage? {
        switch stage {
        case .uploading(let image), .verified(let image), .completed(let image): return image
        case .rejected(let image, _): return image
        default: return nil
        }
    }

    // MARK: - Geometri

    /// Tarayıcının sabit çerçevesiyle aynı dikdörtgen (`ScannerFixedFrame.rect(in:)` SDK içinde
    /// internal olduğundan aynı hesap public alanlarla burada tekrarlanır).
    private func frameRect(in size: CGSize) -> CGRect {
        let aspect = max(frame.aspect, 0.01)
        var width = min(max(size.width - 2 * frame.horizontalPadding, 1), frame.maxWidth)
        var height = width / aspect
        let cap = size.height * min(max(frame.maxHeightFraction, 0.05), 1)
        if height > cap { height = cap; width = height * aspect }
        let centreY = min(max(size.height / 2 + frame.verticalOffset, height / 2), size.height - height / 2)
        return CGRect(x: (size.width - width) / 2, y: centreY - height / 2, width: width, height: height)
    }

    // MARK: - Katmanlar

    private var topBar: some View {
        VStack(spacing: IDSpacing.md) {
            SDKNavigationBar(
                style: .overlay,
                onBack: { coordinator.popBack() },
                trailing: isTorchAvailable && stage == .scanning ? AnyView(torchButton) : nil
            )
            StepTrack(side: side, stage: stageKind, accent: accent)
                .padding(.horizontal, IDSpacing.xl)
        }
    }

    /// Sonuç beklenirken çekilen kare çerçevenin içinde gösterilir; arkada kamera canlı kalır.
    @ViewBuilder
    private func capturedCard(rect: CGRect) -> some View {
        ZStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .clipShape(RoundedRectangle(cornerRadius: frame.cornerRadius))
                    .position(x: rect.midX, y: rect.midY)
            }
            RoundedRectangle(cornerRadius: frame.cornerRadius)
                .stroke(frameColor, lineWidth: 3)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
        .transition(.opacity)
    }

    /// Çerçevenin içine oturtulan silik kimlik görseli; yüz değişince görsel yumuşak geçişle değişir.
    private func ghostCard(rect: CGRect) -> some View {
        Image(side == .back ? "backID" : "frontID", bundle: .sdkUI)
            .resizable()
            .frame(width: rect.width, height: rect.height)
            .clipShape(RoundedRectangle(cornerRadius: frame.cornerRadius))
            .opacity(stage == .scanning ? 0.45 : 0)
            .position(x: rect.midX, y: rect.midY)
            .id(side)
            .transition(.opacity)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func statusBadge(size: CGSize) -> some View {
        let symbol: String? = {
            switch stage {
            case .verified, .completed: return "checkmark"
            case .rejected: return "exclamationmark"
            default: return nil
            }
        }()
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(frameColor))
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                .position(x: size.width / 2, y: size.height - Self.badgeBottomInset)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func instruction(rect: CGRect) -> some View {
        VStack(spacing: 6) {
            Text(side == .back ? "ARKA YÜZ" : "ÖN YÜZ")
                .font(IDFont.caption(.semibold))
                .kerning(1.5)
                .foregroundColor(accent)
                .padding(.horizontal, IDSpacing.md)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white))
            Text(instructionText)
                .font(IDFont.bodyLarge(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .padding(.horizontal, IDSpacing.xl)
        .frame(maxWidth: .infinity)
        .position(x: rect.midX, y: rect.minY - 60)
        .id(side)
        .transition(.opacity)
    }

    private var instructionText: String {
        switch stage {
        case .scanning:
            return side == .back ? "Kartı çevir, arka yüzü çerçeveye hizala"
                                 : "Kimlik kartının ön yüzünü çerçeveye hizala"
        case .uploading: return "Fotoğraf doğrulanıyor"
        case .verified:  return "Ön yüz doğrulandı"
        case .rejected:  return side == .back ? "Arka yüz doğrulanamadı" : "Ön yüz doğrulanamadı"
        case .completed: return "Kimlik doğrulandı"
        }
    }

    /// Ret anında çerçevenin altında düz metin: sunucu mesajı + otomatik tekrar çekim bilgisi.
    @ViewBuilder
    private func retryNote(rect: CGRect) -> some View {
        if case .rejected(_, let message) = stage {
            VStack(spacing: 6) {
                Text(message)
                    .font(IDFont.bodyRegular(.semibold))
                Text(viewModel.pendingAlertAction != nil ? "Deneme hakkı doldu, devam ediliyor…"
                                                         : "2 saniye içinde tekrar çekime yönlendiriliyorsunuz…")
                    .font(IDFont.caption())
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.5), radius: 4)
            .padding(.horizontal, IDSpacing.xl)
            .frame(maxWidth: .infinity)
            .position(x: rect.midX, y: rect.maxY + 56)
            .transition(.opacity)
        }
    }

    private var frameColor: Color {
        switch stage {
        case .verified, .completed: return IDColor.success
        case .rejected: return IDColor.error
        default: return accent
        }
    }

    private var stageKind: StepTrack.Kind {
        switch stage {
        case .scanning: return .active
        case .uploading: return .busy
        case .verified, .completed: return .done
        case .rejected: return .failed
        }
    }

    private var torchButton: some View {
        Button { isTorchOn.toggle() } label: {
            Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.15)))
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Adım göstergesi

/// Üstte iki parçalı ilerleme: ön yüz ve arka yüz. Aktif parçanın rengi aşamayı söyler.
private struct StepTrack: View {
    enum Kind { case active, busy, done, failed }

    let side: IdCardSide
    let stage: Kind
    let accent: Color

    var body: some View {
        HStack(spacing: IDSpacing.sm) {
            segment(title: "Ön Yüz", state: side == .back ? .done : stage)
            segment(title: "Arka Yüz", state: side == .back ? stage : nil)
        }
    }

    private func segment(title: String, state: Kind?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(color(for: state))
                .frame(height: 4)
            HStack(spacing: 4) {
                if state == .done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                }
                Text(title).font(IDFont.caption(.semibold))
            }
            .foregroundColor(state == nil ? Color.white.opacity(0.5) : .white)
        }
        .frame(maxWidth: .infinity)
    }

    private func color(for state: Kind?) -> Color {
        switch state {
        case .none: return Color.white.opacity(0.25)
        case .active, .busy: return accent
        case .done: return IDColor.success
        case .failed: return IDColor.error
        }
    }
}

// MARK: - Tarayıcı

/// SDK tarayıcısı ekranın parçası olarak gömülür.
/// - `dismissesOnResult: false` şarttır: varsayılan davranış çekimden sonra `dismiss` çağırır ve en yakın
///   sunumu/gezinmeyi — yani bu ekranı — kapatır.
/// - `keepsCameraRunning: true` kamerayı çekimden sonra açık tutar; `scanSession` değişince tarayıcı aynı
///   oturumda yeni profil (ön → arka) ile yeniden çekime hazırlanır.
private struct ScannerHost: View {
    let side: IdCardSide
    let scanSession: Int
    @Binding var isTorchOn: Bool
    let onTorchAvailability: (Bool) -> Void
    let onResult: (Result<RecognizedDocument, Error>) -> Void

    var body: some View {
        IdentityScannerView(
            profile: side == .back ? .turkishIDBack : .turkishIDFront,
            style: QuadrilateralStyle(
                strokeColor: SDKTheme.shared.capture.guideStrokeColor ?? IDColor.primary.opacity(0.55),
                lockedStrokeColor: SDKTheme.shared.capture.guideLockedColor ?? IDColor.primary,
                lineWidth: 2.5
            ),
            configuration: (side == .back ? ScannerConfiguration.idBack : .default).withHapticModule(.idCard),
            frameMode: .fixedFrame(.idCard),
            externalTorchOn: $isTorchOn,
            onTorchAvailability: onTorchAvailability,
            speechKey: side == .back ? .idCardBackTts : .idCardFrontTts,
            speechModule: .idCard,
            dismissesOnResult: false,
            keepsCameraRunning: true,
            scanSession: scanSession,
            onResult: onResult
        )
    }
}

#Preview("Kimlik — Tek Ekran") {
    SDKModulePreviewHost { IdCardSingleScreenCustomView() }
}
