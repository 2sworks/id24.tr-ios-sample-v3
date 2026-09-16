//
//  SignLangCustomView.swift
//  IdentifySample
//
//  İŞARET DİLİ TERCİHİ — TAM ÖZEL EKRAN ÖRNEĞİ
//
//  SDK'nın `SDKSignLangView` ekranının public API ile yazılmış birebir karşılığıdır.
//  Bu ekran bir akış rotası değildir: görüşme ekranı, sunucu işaret dili desteği istediğinde
//  (`SDKCallScreenViewModel.showSignLangGate`) açar. Özel görüşme ekranında kullanımı:
//
//      .fullScreenCover(isPresented: $viewModel.showSignLangGate) {
//          SignLangCustomView { viewModel.signLangCompleted() }
//      }
//
//  ViewModel kullanımı:
//    isSignLangEnabled          kullanıcının tercihi (Toggle'a bağlanır)
//    continueAction(onFinish:)  tercihi sunucuya bildirir, sonra onFinish çağrılır
//

import SwiftUI
import IdentifySDK

struct SignLangCustomView: View {

    let onFinish: () -> Void

    @StateObject private var viewModel = SDKSignLangViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            IDColor.adaptiveBackground(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                illustration
                    .padding(.bottom, IDSpacing.xxl)

                VStack(spacing: IDSpacing.sm) {
                    Text(.signLangTitle)
                        .font(IDFont.displayMedium(.semibold))
                        .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                    Text(.signLangDesc)
                        .font(IDFont.bodyRegular(.regular))
                        .foregroundColor(IDColor.adaptiveSubtitle(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, IDSpacing.lg)
                .padding(.bottom, IDSpacing.xxl)

                toggleRow
                    .padding(.horizontal, IDSpacing.lg)

                Spacer()

                SDKButton(title: String(.continuePage), style: .primary) {
                    viewModel.continueAction(onFinish: onFinish)
                }
                .padding(.horizontal, IDSpacing.lg)
                .padding(.bottom, IDSpacing.xxl)
            }
        }
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : IDColor.primary.opacity(0.08))
                .frame(width: 160, height: 160)
            Image.sdk(.signLang)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundColor(colorScheme == .dark ? .white : IDColor.primary)
        }
    }

    private var toggleRow: some View {
        HStack(spacing: IDSpacing.md) {
            Text(.coreSignLang)
                .font(IDFont.bodyRegular(.regular))
                .foregroundColor(IDColor.adaptiveTitle(for: colorScheme))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $viewModel.isSignLangEnabled)
                .tint(IDColor.primary)
                .labelsHidden()
        }
        .padding(IDSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: IDRadius.lg)
                .fill(IDColor.adaptiveSurface(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: IDRadius.lg)
                        .stroke(viewModel.isSignLangEnabled ? IDColor.primary.opacity(0.4) : IDColor.adaptiveBorder(for: colorScheme),
                                lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSignLangEnabled)
    }
}

#Preview("İşaret Dili — Özel Ekran") {
    SDKModulePreviewHost { SignLangCustomView(onFinish: {}) }
}
