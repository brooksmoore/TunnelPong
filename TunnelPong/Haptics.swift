import UIKit

/// Pre-made feedback generators so gameplay events never allocate.
final class Haptics {
    static let shared = Haptics()

    private let light  = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    func prepare() {
        light.prepare(); medium.prepare(); heavy.prepare(); notify.prepare()
    }

    func paddleHit()    { light.impactOccurred() }
    func wallBounce()   { medium.impactOccurred() }
    func lifeLost()     { heavy.impactOccurred() }
    func pointScored()  { notify.notificationOccurred(.success) }
    func levelUp()      { notify.notificationOccurred(.success) }
}
