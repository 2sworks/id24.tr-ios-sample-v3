//
//  AppDelegate.swift
//  IdentifySample
//
//  Created by Emir Beytekin on 10.10.2022.
//

import UIKit
import SwiftUI
import netfox
import IdentifySDK
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UIApplication.shared.isIdleTimerDisabled = true
        // Debug ekranından açılan tanılama katmanları kalıcıdır; kayıtlı değerler SDK'ya
        // burada işlenir. Çağrılmazsa katmanlar kapalı varsayılanlarıyla çalışır.
        SDKDebugSettings.shared.apply()
        SDKReadAloudSetting.apply()
        // Panelde hangi sekmelerin açılacağı burada belirlenir; panel yalnız login
        // ekranındaki "Network Debug (Netfox)" anahtarı açıldığında kurulur.
        SDKLogPanel.configure(requests: true, console: true, socket: true)
        SDKLogPanel.setEnabled(NFXDebugState.shared.isEnabled)
        NotificationCenter.default.addObserver(forName: .sdkNetworkDebugShake, object: nil, queue: .main) { _ in
            NFX.sharedInstance().show()
        }
        return true
    }

    // Kısa kenarı 600 pt'yi geçen telefon ekranında (iPhone Duo iç ekranı) yatay da açılır.
    // Kamera açan modüllerde SDK dikey kilit ister.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let ekran = window?.windowScene?.screen.bounds.size,
              min(ekran.width, ekran.height) >= 600 else { return .portrait }
        return SDKLayout.supportedOrientations
    }

    // iOS 27 SDK'sıyla derlenen uygulama sahne yaşam döngüsü olmadan açılmıyor.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Env")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

// MARK: - Scene

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = SDKWindow(windowScene: windowScene)
        // Tüm akış SDK'dan gelir: SDKFlowHostView(coordinator:registry:) { LoginView() }
        window.rootViewController = UIHostingController(rootView: RootView())
        self.window = window
        // SDK 3.2.0 ve öncesi uyarı penceresini uygulama delegesinden okuyor.
        (UIApplication.shared.delegate as? AppDelegate)?.window = window
        window.makeKeyAndVisible()
    }
}
