import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private var didPresent = false

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Present once, after layout, so the scene gets the real screen size
        // and safe-area insets (notch / Dynamic Island / home indicator).
        guard !didPresent, let skView = view as? SKView, skView.bounds.width > 0 else { return }
        didPresent = true
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 120   // ProMotion runs 120; others clamp to 60
        let scene = GameScene(size: skView.bounds.size)
        scene.safeInsets = skView.safeAreaInsets
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .black
        skView.presentScene(scene)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
