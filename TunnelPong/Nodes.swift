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
        let node = SKShapeNode(rectOf: CGSize(width: halfW * 2, height: halfH * 2),
                               cornerRadius: 12)
        node.fillColor = color.withAlphaComponent(0.06)
        node.strokeColor = color
        node.lineWidth = 3
        node.glowWidth = 6
        return node
    }

    static func ball() -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: Config.ballRadius)
        node.fillColor = Config.ballColor
        node.strokeColor = Config.ballColor
        node.glowWidth = 9
        node.blendMode = .add
        return node
    }

    static func label(_ text: String, size: CGFloat, color: SKColor,
                      alpha: CGFloat = 1) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: "Menlo-Bold")
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.alpha = alpha
        l.verticalAlignmentMode = .center
        return l
    }
}
