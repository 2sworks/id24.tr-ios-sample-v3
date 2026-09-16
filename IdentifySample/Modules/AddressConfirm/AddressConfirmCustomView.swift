//
//  AddressConfirmCustomView.swift
//  IdentifySample
//
//  ADRES DOĞRULAMA — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın hazır `SDKAddressConfirmView` ekranının public API ile yazılmış birebir karşılığıdır.
//
//      registry.override(.addressConfirm) { AddressConfirmCustomView() }
//
//  Görev dağılımı:
//    • Adres + belge (fotoğraf / PDF) doğrulama, PDF boyut sınırı, yükleme → `SDKAddressConfirmViewModel`
//    • Belge tarayıcı → SDK'nın public `documentScanner` modifier'ı
//    • Galeri ve dosya seçiciler, form ve çizim → bu dosya
//
//  ViewModel kullanımı:
//    addressText                          metin alanına bağlanır
//    showDocumentOptions                  "Belge ekle" seçenekleri
//    openScanner() → showScanner          kamera ile tarama
//    openPDFPicker() → showPDFPicker      dosya seçici
//    photoSelected(_:) / pdfSelectedFromURL(_:)   seçilen belge
//    docPhoto / canSubmit / submit()      → onCompleted → coordinator.advanceToNextModule()
//

import SwiftUI
import PhotosUI
import IdentifySDK

struct AddressConfirmCustomView: View {

    @StateObject private var viewModel = SDKAddressConfirmViewModel()
    @EnvironmentObject private var coordinator: SDKFlowCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var showGallery = false
    @FocusState private var isAddressFocused: Bool

    // Alan görünümü SDK teması üzerinden (SDKTheme.shared.fields).
    private var fields: SDKFieldAppearance { SDKTheme.shared.fields }

    var body: some View {
        ZStack(alignment: .top) {
            IDColor.moduleBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 0) {
                SDKNavigationBar(
                    style: .progress(steps: coordinator.progressTotal, current: coordinator.progressStep),
                    title: String(.addressVerifyTitle),
                    subtitle: String(.addressVerifyDesc),
                    onBack: { coordinator.popBack() }
                )
                cardArea
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .confirmationDialog(String(.addDocument), isPresented: $viewModel.showDocumentOptions, titleVisibility: .visible) {
            Button(String(.takePhoto)) { viewModel.openScanner() }
            Button(String(.choosePhoto)) { showGallery = true }
            Button(String(.chooseFile)) { viewModel.openPDFPicker() }
            Button(String(.coreGiveUp), role: .cancel) {}
        }
        .sheet(isPresented: $showGallery) {
            PhotoPicker { image in
                viewModel.photoSelected(image)
                showGallery = false
            }
        }
        .documentScanner(
            isPresented: $viewModel.showScanner,
            profile: .generic,
            style: QuadrilateralStyle(strokeColor: IDColor.primary.opacity(0.55), lockedStrokeColor: IDColor.primary, lineWidth: 2.5),
            configuration: ScannerConfiguration.document.withHapticModule(.addressConf),
            navOverlay: {
                SDKNavigationBar(style: .overlay, onBack: { viewModel.showScanner = false })
            }
        ) { result in
            if case .success(let document) = result {
                viewModel.photoSelected(document.croppedImage)
            }
        }
        .fileImporter(isPresented: $viewModel.showPDFPicker, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            viewModel.pdfSelectedFromURL(url)
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        .onAppear {
            viewModel.onCompleted = { coordinator.advanceToNextModule() }
        }
        .idErrorAlert($viewModel.errorMessage)
    }

    private var cardArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: IDSpacing.sm) {
                        Text(.coreAddrDesc)
                            .font(IDFont.displayMedium(.semibold))
                            .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                        Text(.coreInvoicePhoto)
                            .font(IDFont.bodyRegular(.regular))
                            .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                            .lineSpacing(4)
                    }
                    .padding(.top, IDSpacing.xl)
                    .padding(.horizontal, IDSpacing.lg)

                    addressEditor
                        .padding(.top, IDSpacing.xl)
                        .padding(.horizontal, IDSpacing.lg)

                    documentRow
                        .padding(.top, IDSpacing.lg)
                        .padding(.horizontal, IDSpacing.lg)

                    Text(.addressFileFormats)
                        .font(IDFont.caption(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.top, IDSpacing.sm)
                        .padding(.horizontal, IDSpacing.lg)
                }
                .padding(.bottom, IDSpacing.lg)
            }
            .simultaneousGesture(DragGesture().onChanged { _ in isAddressFocused = false })

            SDKButton(title: String(.continuePage), isDisabled: !viewModel.canSubmit) {
                viewModel.submit()
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
            .padding(.horizontal, IDSpacing.lg)
            .padding(.bottom, IDSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IDColor.adaptiveSurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: IDRadius.card))
        .sdkReadableWidth()
    }

    private var addressEditor: some View {
        let radius = fields.cornerRadius ?? 9.5
        return ZStack(alignment: .topLeading) {
            if viewModel.addressText.isEmpty {
                Text(.coreAddrDesc)
                    .font(IDFont.bodyRegular(.regular))
                    .foregroundColor(IDColor.inkMid.opacity(0.6))
                    .padding(.top, 9)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $viewModel.addressText)
                .font(IDFont.bodyRegular(.regular))
                .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                .frame(height: 93)
                .hiddenTextEditorBackground()
                .focused($isAddressFocused)
                // Tek satırlık adres: Enter klavyeyi kapatır.
                .onChange(of: viewModel.addressText) { newValue in
                    guard newValue.contains("\n") else { return }
                    viewModel.addressText = newValue.replacingOccurrences(of: "\n", with: "")
                    isAddressFocused = false
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button { isAddressFocused = false } label: { Image(systemName: "checkmark") }
                    }
                }
        }
        .padding(.horizontal, IDSpacing.sm)
        .padding(.vertical, IDSpacing.xs)
        .background(RoundedRectangle(cornerRadius: radius)
            .fill(fields.background?.resolve(colorScheme) ?? IDColor.inkBorder.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: radius)
            .stroke(fields.borderColor?.resolve(colorScheme) ?? IDColor.inkBorder, lineWidth: fields.borderWidth ?? 1))
    }

    private var documentRow: some View {
        let rowRadius = fields.cornerRadius ?? 12
        let previewRadius = fields.cornerRadius ?? 14
        return Button(action: {
            isAddressFocused = false
            withAnimation { viewModel.showDocumentOptions = true }
        }) {
            HStack(spacing: IDSpacing.lg) {
                if let image = viewModel.docPhoto {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: previewRadius))
                } else {
                    RoundedRectangle(cornerRadius: previewRadius)
                        .fill(Color(uiColor: .systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image.sdk(.uploadFile)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(IDColor.inkMid)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.docPhoto != nil ? String(.documentAdded) : String(.uploadFile))
                        .font(IDFont.bodyRegular(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                    Text(viewModel.docPhoto != nil ? String(.tapToChange) : String(.selectFromDevice))
                        .font(IDFont.caption(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                }

                Spacer()

                Image.sdk(.chevronRight)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(IDColor.inkMid)
            }
            .padding(IDSpacing.lg)
            .frame(minHeight: 85)
            .background(RoundedRectangle(cornerRadius: rowRadius).fill(IDColor.inkBorder.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: rowRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(Color.primary.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: viewModel.docPhoto != nil)
    }
}

private extension View {
    /// TextEditor'ın sistem arka planını gizler (iOS 16+ API; iOS 15'te UITextView görünümü).
    @ViewBuilder
    func hiddenTextEditorBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            onAppear { UITextView.appearance().backgroundColor = .clear }
        }
    }
}

// MARK: - Galeri seçici

private struct PhotoPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { self.parent.onImage(image) }
            }
        }
    }
}

#Preview("Adres — Özel Ekran") {
    SDKModulePreviewHost { AddressConfirmCustomView() }
}
