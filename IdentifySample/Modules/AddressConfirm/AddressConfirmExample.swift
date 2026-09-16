//
//  AddressConfirmExample.swift
//  IdentifySample
//
//  SDK "Adres Onayı" modülü — ENTEGRASYON REHBERİ örneği.
//
//  Bu modül, rehberdeki CANLI / AKTİF örnektir: RootView.configureIfNeeded()
//  içinde `registry.override(.addressConfirm) { AddressConfirmExample() }` ile
//  gerçek akışa kayıtlıdır. Yani uygulama bu adıma geldiğinde mor temayla gelir.
//
//  Üç kullanım biçimi + #Preview:
//    1) AddressConfirmExample          → SDK ekranı + tema (renk) override (AKTİF)
//    2) AddressConfirmExampleDefault   → hiç dokunmadan SDK'nın hazır ekranı
//  3) AddressConfirmCustomView → tam özel ekran: SDK ekranının public API ile birebir kopyası (AddressConfirmCustomView.swift)
//

import SwiftUI
import IdentifySDK

// MARK: - 1) Tema ile özelleştirilmiş (AKTİF — RootView'da kayıtlı)

struct AddressConfirmExample: View {
    var body: some View {
        SDKAddressConfirmView()
    }
}

// MARK: - 2) Varsayılan (dokunulmamış) SDK ekranı

struct AddressConfirmExampleDefault: View {
    var body: some View {
        SDKAddressConfirmView()
    }
}

// MARK: - Previews

#Preview("Adres Onayı — Tema (aktif)") {
    AddressConfirmExample().showcaseHost()
}

#Preview("Adres Onayı — Varsayılan") {
    AddressConfirmExampleDefault().showcaseHost()
}
#Preview("Adres Onayı — Özel Ekran") {
    SDKModulePreviewHost { AddressConfirmCustomView() }
}
