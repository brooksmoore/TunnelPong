import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private var didPresent = false
    private weak var gameScene: GameScene?

    override func loadView() {
        #if targetEnvironment(macCatalyst)
        // Use controller bounds (window), not the full display.
        view = SKView(frame: .zero)
        #else
        view = SKView(frame: UIScreen.main.bounds)
        #endif
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let skView = view as? SKView, skView.bounds.width > 0 else { return }

        let insets = effectiveSafeInsets(for: skView)

        // First layout: present the scene at the real window size.
        if !didPresent {
            didPresent = true
            skView.ignoresSiblingOrder = true
            #if targetEnvironment(macCatalyst)
            skView.preferredFramesPerSecond = 60
            #else
            skView.preferredFramesPerSecond = 120   // ProMotion runs 120; others clamp to 60
            #endif
            let scene = GameScene(size: skView.bounds.size)
            scene.safeInsets = insets
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .black
            skView.presentScene(scene)
            gameScene = scene
            // Second pass after safe-area settles (notch / Mac titlebar).
            DispatchQueue.main.async { [weak self, weak skView, weak scene] in
                guard let self, let skView, let scene else { return }
                scene.safeInsets = self.effectiveSafeInsets(for: skView)
                scene.applyChromeLayout()
            }

            #if targetEnvironment(macCatalyst)
            // Paddle follows mouse without holding click (trackpad-friendly).
            let hover = UIHoverGestureRecognizer(target: self, action: #selector(macHover(_:)))
            skView.addGestureRecognizer(hover)
            #endif
            return
        }

        // Resize / rotation / safe-area updates: keep scene + chrome in sync.
        if let scene = gameScene {
            let newSize = skView.bounds.size
            let sizeChanged = abs(scene.size.width - newSize.width) > 0.5
                || abs(scene.size.height - newSize.height) > 0.5
            scene.safeInsets = insets
            if sizeChanged {
                scene.size = newSize
            }
            // Always re-layout chrome: safe insets can change without size (notch side).
            scene.applyChromeLayout()
        }
    }

    #if targetEnvironment(macCatalyst)
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Host NSWindow is reliably attached once we're on-screen.
        (UIApplication.shared.delegate as? AppDelegate)?.refreshMacWindowPolicy()
    }
    #endif

    /// Notch / home indicator on phone; titlebar reserve on Mac Catalyst.
    private func effectiveSafeInsets(for skView: SKView) -> UIEdgeInsets {
        var insets = skView.safeAreaInsets
        // Prefer view controller's safe area (includes additionalSafeAreaInsets).
        let vcInsets = view.safeAreaInsets
        insets.top = max(insets.top, vcInsets.top)
        insets.bottom = max(insets.bottom, vcInsets.bottom)
        insets.left = max(insets.left, vcInsets.left)
        insets.right = max(insets.right, vcInsets.right)
        #if targetEnvironment(macCatalyst)
        insets.top = max(insets.top, Config.macTitlebarInset)
        #endif
        return insets
    }

    #if targetEnvironment(macCatalyst)
    @objc private func macHover(_ gesture: UIHoverGestureRecognizer) {
        guard let skView = view as? SKView, let scene = gameScene else { return }
        switch gesture.state {
        case .began, .changed:
            let viewPoint = gesture.location(in: skView)
            let scenePoint = scene.convertPoint(fromView: viewPoint)
            scene.pointerMoved(to: scenePoint)
        default:
            break
        }
    }
    #endif

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var shouldAutorotate: Bool { true }
    /// Portrait + both landscapes on phone/iPad; any orientation on Mac.
    /// Upside-down portrait omitted (awkward thumb grip / home indicator).
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        #if targetEnvironment(macCatalyst)
        return .all
        #else
        return .allButUpsideDown
        #endif
    }
}
