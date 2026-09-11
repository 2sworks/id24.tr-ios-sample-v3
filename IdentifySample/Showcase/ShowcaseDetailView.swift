//
//  ShowcaseDetailView.swift
//  IdentifySample
//
//  Bir SDK modülünün rehber detayı: canlı ekran (mock veriyle), ekranı dolduracak
//  şekilde. Senaryo kontrolleri navigation bar'daki butondan popup olarak açılır.
//  Entegrasyon/özelleştirme kodu burada gösterilmez — docs/ altındaki rehberlerdedir.
//

import SwiftUI
import IdentifySDK

struct ShowcaseDetailView: View {

    let item: ShowcaseItem
    @Environment(\.colorScheme) private var colorScheme

    /// Başlık bloğu açık mı. Kapatılınca modül ekranın tamamını kaplar — modülü
    /// gerçek akıştaki hâliyle görmek için.
    @State private var showsInfo = true
    @State private var showsScenarios = false

    /// Bu modül için tanımlı senaryo kontrolleri; yoksa buton gösterilmez.
    private var scenarios: [ShowcaseScenarioGroup] { ShowcaseScenarios.groups(for: item.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: IDSpacing.sm) {

            if showsInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.subtitle)
                        .font(IDFont.bodyRegular())
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                    Text("Ekran örnek (mock) oturum verisiyle çizilir. Kamera gerçek cihazda çalışır; yükleme ve NFC/WebRTC adımları backend olmadığı için tamamlanmaz.")
                        .font(IDFont.bodySmall())
                        .foregroundColor(IDColor.inkLight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, IDSpacing.lg)
                .padding(.top, IDSpacing.sm)
            }

            ShowcaseLivePreview { item.liveView() }
                .showcaseScenarioCooldown()
                // Modül her açılışta akışın başındaymış gibi davranır: tamamlanma sayacı
                // sıfırlanır, yoksa birkaç tamamlanmadan sonra SDK akış-sonu dalına girip
                // `closeSDK()` çağırırdı. Bkz. ShowcaseMockData.apply().
                .onAppear { IdentifyManager.shared.moduleStepOrder = 0 }
        }
        .background(IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !scenarios.isEmpty {
                    Button {
                        showsScenarios = true
                    } label: {
                        Label("Senaryo", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Senaryo ayarları")
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showsInfo.toggle() }
                } label: {
                    Image(systemName: showsInfo ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                }
                .accessibilityLabel(showsInfo ? "Tam ekran" : "Bilgiyi göster")
            }
        }
        .sheet(isPresented: $showsScenarios) {
            ShowcaseScenarioSheet(groups: scenarios)
        }
    }
}
