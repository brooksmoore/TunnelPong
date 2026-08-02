import SpriteKit
import UIKit

/// A label that draws with wide letter-tracking. SKLabelNode has no tracking of
/// its own, so text is rendered through an attributed string and re-rendered
/// whenever the text or tint changes — always set copy via `display(_:)`.
final class NeonLabel: SKLabelNode {

    private var raw = ""
    private var styleFont = Config.fontHUD
    private var styleSize: CGFloat = 14
    private var tracking: CGFloat = 0

    /// Text colour. (Assigning `fontColor` directly would be ignored while
    /// attributedText is in use, so route colour through here.)
    var tint: SKColor = .white {
        didSet { restyle() }
    }

    static func make(_ text: String, size: CGFloat, color: SKColor,
                     font: String, tracking: CGFloat) -> NeonLabel {
        let l = NeonLabel(fontNamed: font)
        l.styleFont = font
        l.styleSize = size
        l.tracking = tracking
        l.raw = text
        l.tint = color            // triggers restyle()
        l.verticalAlignmentMode = .center
        return l
    }

    func display(_ text: String) {
        guard text != raw else { return }
        raw = text
        restyle()
    }

    private func restyle() {
        let font = UIFont(name: styleFont, size: styleSize)
            ?? UIFont.systemFont(ofSize: styleSize, weight: .ultraLight)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: tint,
        ]
        if tracking != 0 { attrs[.kern] = tracking }
        let s = NSMutableAttributedString(string: raw, attributes: attrs)
        // kern also pads after the final glyph, which would throw centred text
        // off by half a track — strip it from the last character.
        if tracking != 0, raw.count > 0 {
            s.removeAttribute(.kern, range: NSRange(location: raw.count - 1, length: 1))
        }
        attributedText = s
    }
}

/// Builders for every procedural visual. No image assets anywhere — the sky and
/// the moon are drawn into textures at runtime.
enum NodeFactory {

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    // MARK: - Backdrop

    /// Distant stars on pure black, baked into one texture so the scatter costs
    /// a single node. Deterministically seeded, so a window resize re-renders
    /// the same sky instead of reshuffling it.
    static func starFieldTexture(size: CGSize) -> SKTexture {
        var seed: UInt64 = 0x5EED_CAFE
        func rnd() -> CGFloat {                 // xorshift, stable across runs
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return CGFloat(seed % 100_000) / 100_000
        }
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(SKColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<Config.starCount {
                let x = rnd() * size.width
                let y = rnd() * size.height
                let r = Config.starMinRadius
                    + rnd() * (Config.starMaxRadius - Config.starMinRadius)
                let a = Config.starMinAlpha
                    + rnd() * (Config.starMaxAlpha - Config.starMinAlpha)
                cg.setFillColor(Config.starColor.withAlphaComponent(a).cgColor)
                cg.fillEllipse(in: CGRect(x: x - r, y: y - r,
                                          width: r * 2, height: r * 2))
            }
        }
        return SKTexture(image: image)
    }

    // MARK: - Tunnel

    /// One tunnel ring: a stroked rounded rect at a given projected scale.
    /// `t` is 0 at the near plane, 1 at the far plane; it drives the fade.
    static func ring(halfW: CGFloat, halfH: CGFloat, scale: CGFloat,
                     t: CGFloat, center: CGPoint) -> SKShapeNode {
        let w = halfW * scale
        let h = halfH * scale
        let rect = CGRect(x: -w, y: -h, width: 2 * w, height: 2 * h)
        let node = SKShapeNode(rect: rect, cornerRadius: Config.ringCornerRadius * scale)
        node.position = center
        node.fillColor = .clear
        node.strokeColor = Config.ringColor
        node.lineWidth = lerp(Config.ringLineWidthNear, Config.ringLineWidthFar, t)
        node.alpha = lerp(Config.ringAlphaNear, Config.ringAlphaFar, t)
        node.isAntialiased = true
        return node
    }

    /// A faint straight line joining a court corner at z = 0 to the same
    /// corner at z = zFar. Because projection is a straight ray toward the
    /// vanishing point, this line passes through every ring's corner.
    static func cornerLine(from p0: CGPoint, to p1: CGPoint) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: p0)
        path.addLine(to: p1)
        let node = SKShapeNode(path: path)
        node.strokeColor = Config.ringColor
        node.alpha = Config.cornerLineAlpha
        node.lineWidth = 1
        node.isAntialiased = true
        return node
    }

    // MARK: - Actors

    /// Name of the bloom layer parented under every paddle.
    static let impactGlowName = "impactGlow"

    /// Softly rounded hairline rectangle, with a dormant halo child that blooms
    /// when the ball strikes it (see GameScene.flashPaddle).
    static func paddle(halfW: CGFloat, halfH: CGFloat, color: SKColor) -> SKShapeNode {
        let size = CGSize(width: halfW * 2, height: halfH * 2)
        let node = SKShapeNode(rectOf: size, cornerRadius: Config.paddleCornerRadius)
        node.fillColor = color.withAlphaComponent(0.07)
        node.strokeColor = color
        node.lineWidth = 1.6
        node.glowWidth = 4
        node.isAntialiased = true

        // Separate node because SKShapeNode.glowWidth can't be animated — the
        // halo is drawn once and its alpha/scale are what actually move.
        let glow = SKShapeNode(rectOf: size, cornerRadius: Config.paddleCornerRadius)
        glow.fillColor = .clear
        glow.strokeColor = color
        glow.lineWidth = Config.paddleGlowLineWidth
        glow.glowWidth = Config.paddleGlowWidth
        glow.isAntialiased = true
        glow.alpha = 0
        glow.zPosition = -1
        glow.name = impactGlowName
        node.addChild(glow)

        return node
    }

    /// Neon orange sphere: warm halo, body, and a hot core.
    static func ball() -> SKNode {
        let root = SKNode()
        let r = Config.ballRadius

        let halo = SKShapeNode(circleOfRadius: r * 1.30)
        halo.fillColor = Config.ballColor.withAlphaComponent(0.16)
        halo.strokeColor = .clear
        halo.zPosition = 0
        root.addChild(halo)

        let body = SKShapeNode(circleOfRadius: r)
        body.fillColor = Config.ballColor
        body.strokeColor = Config.ballStrokeColor
        body.lineWidth = 1.6
        body.glowWidth = 5
        body.isAntialiased = true
        body.zPosition = 1
        root.addChild(body)

        let core = SKShapeNode(circleOfRadius: r * 0.42)
        core.fillColor = Config.ballCoreColor
        core.strokeColor = .clear
        core.position = CGPoint(x: -r * 0.16, y: r * 0.18)
        core.zPosition = 2
        root.addChild(core)

        return root
    }

    // MARK: - Type

    static func label(_ text: String, size: CGFloat, color: SKColor,
                      alpha: CGFloat = 1,
                      font: String = Config.fontBody,
                      tracking: CGFloat = Config.hudTracking) -> NeonLabel {
        let l = NeonLabel.make(text, size: size, color: color,
                               font: font, tracking: tracking)
        l.alpha = alpha
        return l
    }

    static func titleLabel(_ text: String, size: CGFloat, color: SKColor) -> NeonLabel {
        label(text, size: size, color: color,
              font: Config.fontTitle, tracking: Config.titleTracking)
    }

    static func hudLabel(_ text: String, size: CGFloat, color: SKColor,
                         alpha: CGFloat = 1) -> NeonLabel {
        label(text, size: size, color: color, alpha: alpha,
              font: Config.fontHUD, tracking: Config.hudTracking)
    }
}
