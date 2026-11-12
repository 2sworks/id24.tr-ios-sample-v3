//
//  PrepareHostViewModel.swift
//  IdentifySample
//
//  Hazırlık modülü host VM'i. SDKPrepareViewModel'i sarar; dışarıdan event log ekler.
//

import SwiftUI
import IdentifySDK

@MainActor
final class PrepareHostViewModel: HostModuleViewModel {
    let sdk = SDKPrepareViewModel()

    override init() {
        super.init()
        bridge(sdk)
        sdk.onCompleted = { [weak self] in
            self?.log("prepare_completed")
            self?.onCompleted?()
        }
    }

    var cameraAuthorized: Bool { sdk.cameraAuthorized }
    var micAuthorized: Bool { sdk.micAuthorized }
    var speechAuthorized: Bool { sdk.speechAuthorized }
    var allPermissionsGranted: Bool { sdk.allPermissionsGranted }

    func checkPermissions() {
        log("check_permissions")
        if sdk.requiredPermissions.contains(.camera) { sdk.checkCamera() }
        if sdk.requiredPermissions.contains(.microphone) { sdk.checkMicrophone() }
        if sdk.requiredPermissions.contains(.speechRecognition) { sdk.checkSpeech() }
    }
    func complete() { sdk.completePrepare() }
}
