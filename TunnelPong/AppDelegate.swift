import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if targetEnvironment(macCatalyst)
        // Phone-shaped window for desktop play (no Simulator).
        let phoneSize = CGSize(width: 390, height: 844)
        let window = UIWindow(frame: CGRect(origin: .zero, size: phoneSize))
        #else
        let window = UIWindow(frame: UIScreen.main.bounds)
        #endif
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window

        #if targetEnvironment(macCatalyst)
        // Phone-shaped bounds; user can still resize within min/max.
        if let scene = window.windowScene {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 320, height: 568)
            scene.sizeRestrictions?.maximumSize = CGSize(width: 500, height: 1100)
            scene.title = "Tunnel Pong"
        }
        #endif
        return true
    }
}
