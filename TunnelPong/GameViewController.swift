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
            scene.safeInsets = skView.safeAreaInsets
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .black
            skView.presentScene(scene)
            gameScene = scene

            #if targetEnvironment(macCatalyst)
            // Paddle follows mouse without holding click (trackpad-friendly).
            let hover = UIHoverGestureRecognizer(target: self, action: #selector(macHover(_:)))
            skView.addGestureRecognizer(hover)
            #endif
            return
        }

        // Mac: keep scene size in sync when the window is resized.
        if let scene = gameScene, scene.size != skView.bounds.size {
            scene.size = skView.bounds.size
            scene.safeInsets = skView.safeAreaInsets
        }
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
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        #if targetEnvironment(macCatalyst)
        return .all
        #else
        return .portrait
        #endif
    }
}
