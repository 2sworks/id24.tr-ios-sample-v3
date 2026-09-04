//
//  IdentifySdkPlugin.swift
//  Flutter plugin köprüsü — IdentifySDK
//
//  MethodChannel ile setupSDK'yı, EventChannel ile birleşik olay akışını (SDKEvent)
//  Dart tarafına bağlar. Bu bir İSKELETTİR; projenize uyarlayın.
//

import Flutter
import UIKit
import IdentifySDK

public class IdentifySdkPlugin: NSObject, FlutterPlugin, SDKEventListener, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = IdentifySdkPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "identify_sdk/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "identify_sdk/events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    // MARK: FlutterStreamHandler (olay akışı)

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        IdentifyManager.shared.eventDelegate = self
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        if IdentifyManager.shared.eventDelegate === self {
            IdentifyManager.shared.eventDelegate = nil
        }
        return nil
    }

    // MARK: SDKEventListener

    public func onSDKEvent(_ event: SDKEvent) {
        // toDictionary() JSON-güvenli → EventSink ile doğrudan Dart'a.
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event.toDictionary())
        }
    }

    // MARK: MethodChannel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setupSDK":
            setupSDK(call.arguments as? [String: Any] ?? [:], result: result)
        case "reportAbandoned":
            let reason = (call.arguments as? [String: Any])?["reason"] as? String
            IdentifyManager.shared.reportSessionAbandoned(reason: reason)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupSDK(_ args: [String: Any], result: @escaping FlutterResult) {
        guard
            let identId = args["identId"] as? String,
            let baseApiUrl = args["baseApiUrl"] as? String,
            let turnKey = args["turnKey"] as? String
        else {
            result(FlutterError(code: "E_ARGS", message: "identId, baseApiUrl ve turnKey zorunludur", details: nil))
            return
        }

        let moduleRaws = args["selectedModules"] as? [String] ?? []
        let selectedModules = moduleRaws.compactMap { SdkModules(rawValue: $0) }

        IdentifyManager.shared.setupSDK(
            identId: identId,
            baseApiUrl: baseApiUrl,
            networkOptions: SDKNetworkOptions(
                timeoutIntervalForRequest: 30,
                timeoutIntervalForResource: 30,
                useSslPinning: args["useSslPinning"] as? Bool ?? false
            ),
            kpsData: nil,
            signLangSupport: args["signLangSupport"] as? Bool ?? false,
            nfcMaxErrorCount: args["nfcMaxErrorCount"] as? Int ?? 3,
            selectedModules: selectedModules,
            turnKey: turnKey,
            wsSecretKey: args["wsSecretKey"] as? String,
            showThankYouPage: args["showThankYouPage"] as? Bool ?? false,
            showNFCNotFoundPage: args["showNFCNotFoundPage"] as? Bool ?? false,
            supportU18: args["supportU18"] as? Bool ?? false
        ) { socket, roomResponse, error in
            // DİKKAT: setupSDK hata parametresini HER ZAMAN dolu gönderir; başarılı
            // kurulumda `errorMessages` boş string olur. Bu yüzden `if let error = error`
            // başarıda da doğrudur ve akış hiç başlamadan E_SETUP ile reddedilir.
            // Doğru kontrol, mesajın dolu olup olmadığıdır.
            if let message = error?.errorMessages, !message.isEmpty {
                result(FlutterError(code: "E_SETUP", message: message, details: nil))
                return
            }
            guard socket?.isConnected == true, roomResponse.result == true else {
                result(FlutterError(code: "E_SETUP", message: "Socket bağlantısı kurulamadı", details: nil))
                return
            }
            result(["result": true])
        }
    }
}
