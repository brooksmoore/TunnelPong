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

    /// Vertical sunset: black overhead falling through indigo and violet to a
    /// hot pink band at the horizon, then snapping back to black underneath.
    static func skyTexture(size: CGSize) -> SKTexture {
        let h = Config.horizonFrac                      // from the bottom
        // Locations are top→bottom, so invert the horizon fraction.
        let stops: [(CGFloat, SKColor)] = [
            (0.00,            Config.skyTop),
            (0.34,            Config.skyHigh),
            (0.60,            Config.skyMid),
            (1 - h - 0.16,    Config.skyLow),
            (1 - h - 0.045,   Config.skyGlow),
            (1 - h,           Config.skyHot),
            (min(1 - h + 0.05, 0.995), Config.skyLow),
            (1.00,            Config.skyTop),
        ]
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = stops.map { $0.1.cgColor } as CFArray
            let locations = stops.map { $0.0 }
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: locations) else { return }
            cg.drawLinearGradient(grad,
                                  start: CGPoint(x: 0, y: 0),
                                  end: CGPoint(x: 0, y: size.height),
                                  options: [])
        }
        return SKTexture(image: image)
    }

    /// Crescent: a filled disc with a second disc punched out of it.
    static func moonTexture(radius r: CGFloat) -> SKTexture {
        let pad: CGFloat = 2
        let side = (r + pad) * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(Config.moonColor.cgColor)
            cg.fillEllipse(in: CGRect(x: pad, y: pad, width: r * 2, height: r * 2))
            cg.setBlendMode(.clear)
            cg.fillEllipse(in: CGRect(x: pad + r * 0.52, y: pad - r * 0.14,
                                      width: r * 2, height: r * 2))
        }
        return SKTexture(image: image)
    }

    /// Near-black peaks rising off the bottom edge. Overlapping triangles at
    /// different heights, with one apex catching the horizon light.
    static func mountains(size: CGSize) -> SKNode {
        let root = SKNode()
        let horizonY = size.height * Config.horizonFrac
        let maxH = size.height * Config.mountainHeightFrac
        // (centre x, half-base, height) as fractions — echoes the reference's
        // two dominant peaks plus a shoulder.
        let peaks: [(CGFloat, CGFloat, CGFloat)] = [
            (0.28, 0.34, 0.74),
            (0.63, 0.40, 1.00),
            (0.90, 0.28, 0.60),
        ]
        for (i, p) in peaks.enumerated() {
            let cx = size.width * p.0
            let hb = size.width * p.1
            let apexY = horizonY + maxH * p.2
            let path = CGMutablePath()
            path.move(to: CGPoint(x: cx - hb, y: 0))
            path.addLine(to: CGPoint(x: cx, y: apexY))
            path.addLine(to: CGPoint(x: cx + hb, y: 0))
            path.closeSubpath()
            let node = SKShapeNode(path: path)
            node.fillColor = Config.mountainColor
            node.strokeColor = .clear
            node.zPosition = CGFloat(i)
            root.addChild(node)

            // Lit face on the tallest peak only — a sliver of horizon pink.
            if p.2 == 1.00 {
                let lit = CGMutablePath()
                lit.move(to: CGPoint(x: cx, y: apexY))
                lit.addLine(to: CGPoint(x: cx + hb * 0.30, y: apexY - maxH * 0.62))
                lit.addLine(to: CGPoint(x: cx + hb * 0.06, y: apexY - maxH * 0.62))
                lit.closeSubpath()
                let litNode = SKShapeNode(path: lit)
                litNode.fillColor = Config.titleAccent.withAlphaComponent(0.55)
                litNode.strokeColor = .clear
                litNode.zPosition = CGFloat(i) + 0.5
                root.addChild(litNode)
            }
        }
        return root
    }

    /// The reference's thin parallel diagonals — each shorter and fainter than
    /// the last, like light trails leaving a peak.
    static func streaks(size: CGSize) -> SKNode {
        let root = SKNode()
        // (origin x, origin y, count) as fractions of the frame.
        let clusters: [(CGFloat, CGFloat, Int)] = [
            (0.17, 0.72, 6),
            (0.50, 0.55, 5),
        ]
        let angle: CGFloat = -0.62          // radians, down-left
        for c in clusters {
            let ox = size.width * c.0
            let oy = size.height * c.1
            for i in 0..<c.2 {
                let step = CGFloat(i)
                let len = size.height * (0.20 - step * 0.026)
                guard len > 8 else { continue }
                let sx = ox + step * 15
                let sy = oy - step * 22
                let path = CGMutablePath()
                path.move(to: CGPoint(x: sx, y: sy))
                path.addLine(to: CGPoint(x: sx + cos(angle) * len,
                                         y: sy + sin(angle) * len))
                let node = SKShapeNode(path: path)
                node.strokeColor = Config.streakColor
                node.lineWidth = 1
                node.alpha = Config.streakAlpha * (1 - step * 0.13)
                node.isAntialiased = true
                root.addChild(node)
            }
        }
        return root
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

    /// Hairline rectangle — no fill weight, so the paddle reads as drawn light
    /// rather than a solid slab sitting on the art.
    static func paddle(halfW: CGFloat, halfH: CGFloat, color: SKColor) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: halfW * 2, height: halfH * 2),
                               cornerRadius: 3)
        node.fillColor = color.withAlphaComponent(0.07)
        node.strokeColor = color
        node.lineWidth = 1.6
        node.glowWidth = 4
        node.isAntialiased = true
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
