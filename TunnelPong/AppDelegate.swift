import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if targetEnvironment(macCatalyst)
        // Tall phone-shaped window (extra height so titlebar doesn't clip HUD).
        let phoneSize = CGSize(width: 400, height: 920)
        let window = UIWindow(frame: CGRect(origin: .zero, size: phoneSize))
        #else
        let window = UIWindow(frame: UIScreen.main.bounds)
        #endif
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window

        #if targetEnvironment(macCatalyst)
        if let scene = window.windowScene {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 340, height: 700)
            scene.sizeRestrictions?.maximumSize = CGSize(width: 520, height: 1200)
            scene.title = "CyberPong"
        }
        #endif
        return true
    }
}
