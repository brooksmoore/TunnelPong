import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if targetEnvironment(macCatalyst)
        // Start portrait-ish; sizeRestrictions unlock free resize (no AppKit KVC —
        // value(forKey:) on missing keys raises and crashes Catalyst).
        let startSize = CGSize(width: 420, height: 860)
        let window = UIWindow(frame: CGRect(origin: .zero, size: startSize))
        #else
        let window = UIWindow(frame: UIScreen.main.bounds)
        #endif
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window

        #if targetEnvironment(macCatalyst)
        // Scene is often still nil mid-launch; re-apply once it exists.
        applyMacWindowPolicy()
        DispatchQueue.main.async { [weak self] in self?.applyMacWindowPolicy() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.applyMacWindowPolicy()
        }
        #endif
        return true
    }

    #if targetEnvironment(macCatalyst)
    func applicationDidBecomeActive(_ application: UIApplication) {
        applyMacWindowPolicy()
    }

    /// Called from GameViewController once the host window is on-screen.
    func refreshMacWindowPolicy() {
        applyMacWindowPolicy()
    }

    /// Official Catalyst free-resize: UIWindowScene.sizeRestrictions only.
    private func applyMacWindowPolicy() {
        let scene = window?.windowScene
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let scene else { return }

        scene.title = "CyberPong"
        guard let restrictions = scene.sizeRestrictions else { return }
        restrictions.minimumSize = CGSize(width: 360, height: 300)
        restrictions.maximumSize = CGSize(width: 4096, height: 4096)
    }
    #endif
}
