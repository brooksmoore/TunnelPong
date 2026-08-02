import SpriteKit

/// Builders for every procedural visual. No image assets anywhere.
enum NodeFactory {

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

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

    static func paddle(halfW: CGFloat, halfH: CGFloat, color: SKColor) -> SKShapeNode {
        // Slightly tighter corners so the filled rect matches the AABB hitbox better.
        let node = SKShapeNode(rectOf: CGSize(width: halfW * 2, height: halfH * 2),
                               cornerRadius: 6)
        node.fillColor = color.withAlphaComponent(0.18)
        node.strokeColor = color
        node.lineWidth = 3.5
        node.glowWidth = 5
        return node
    }

    /// Layered sphere: sunset core + hot specular (retrowave sun energy).
    static func ball() -> SKNode {
        let root = SKNode()
        let r = Config.ballRadius

        let limb = SKShapeNode(circleOfRadius: r * 1.05)
        limb.fillColor = SKColor(red: 0.55, green: 0.05, blue: 0.20, alpha: 0.5)
        limb.strokeColor = .clear
        limb.zPosition = 0
        root.addChild(limb)

        let body = SKShapeNode(circleOfRadius: r)
        body.fillColor = Config.ballColor
        body.strokeColor = Config.ballStrokeColor
        body.lineWidth = 2.5
        body.zPosition = 1
        body.isAntialiased = true
        root.addChild(body)

        // Sunset bands feel (horizontal “scan” shade).
        let shade = SKShapeNode(circleOfRadius: r * 0.78)
        shade.fillColor = SKColor(red: 0.85, green: 0.15, blue: 0.35, alpha: 0.40)
        shade.strokeColor = .clear
        shade.position = CGPoint(x: r * 0.12, y: -r * 0.28)
        shade.zPosition = 2
        root.addChild(shade)

        let hi = SKShapeNode(circleOfRadius: r * 0.28)
        hi.fillColor = SKColor(red: 1.0, green: 0.92, blue: 0.55, alpha: 0.9)
        hi.strokeColor = .clear
        hi.position = CGPoint(x: -r * 0.30, y: r * 0.32)
        hi.zPosition = 3
        root.addChild(hi)

        let hot = SKShapeNode(circleOfRadius: r * 0.10)
        hot.fillColor = SKColor.white.withAlphaComponent(0.95)
        hot.strokeColor = .clear
        hot.position = CGPoint(x: -r * 0.36, y: r * 0.38)
        hot.zPosition = 4
        root.addChild(hot)

        return root
    }

    static func label(_ text: String, size: CGFloat, color: SKColor,
                      alpha: CGFloat = 1,
                      font: String = Config.fontBody) -> SKLabelNode {
        // Fall back if a condensed face is missing on some OS builds.
        let l = SKLabelNode(fontNamed: font)
        if l.fontName == nil || (l.fontName?.isEmpty ?? true) {
            l.fontName = "HelveticaNeue-Bold"
        }
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.alpha = alpha
        l.verticalAlignmentMode = .center
        return l
    }

    static func titleLabel(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        label(text, size: size, color: color, font: Config.fontTitle)
    }

    static func hudLabel(_ text: String, size: CGFloat, color: SKColor,
                         alpha: CGFloat = 1) -> SKLabelNode {
        label(text, size: size, color: color, alpha: alpha, font: Config.fontHUD)
    }
}
