import SpriteKit
import UIKit

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

    /// One tunnel ring: a stroked rect at a given projected scale. `t` is 0 at
    /// the near plane, 1 at the far plane, and drives both the fade and the
    /// position along the wall's colour ramp.
    static func ring(halfW: CGFloat, halfH: CGFloat, scale: CGFloat,
                     t: CGFloat, center: CGPoint) -> SKShapeNode {
        let w = halfW * scale
        let h = halfH * scale
        let rect = CGRect(x: -w, y: -h, width: 2 * w, height: 2 * h)
        let node = SKShapeNode(rect: rect, cornerRadius: Config.ringCornerRadius * scale)
        node.position = center
        node.fillColor = .clear
        node.strokeColor = Config.wallColor(t)
        node.lineWidth = lerp(Config.ringLineWidthNear, Config.ringLineWidthFar, t)
        node.alpha = lerp(Config.ringAlphaNear, Config.ringAlphaFar, t)
        node.isAntialiased = true
        return node
    }

    /// One span of a corner rail. Rails are cut into per-ring segments so each
    /// can take its own colour — that's what makes the rail read as a gradient
    /// rather than a flat line (SKShapeNode strokes are a single colour).
    static func railSegment(t: CGFloat) -> SKShapeNode {
        let node = SKShapeNode()
        node.strokeColor = Config.wallColor(t)
        node.alpha = Config.cornerLineAlpha * (1 - t * 0.45)
        node.lineWidth = lerp(1.4, 0.6, t)
        node.isAntialiased = true
        return node
    }

    /// Horizontal CRT lines, baked once into a texture.
    static func scanlineTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(SKColor.black.withAlphaComponent(Config.scanlineAlpha).cgColor)
            var y: CGFloat = 0
            while y < size.height {
                cg.fill(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += Config.scanlineSpacing
            }
        }
        return SKTexture(image: image)
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

    static let ballSpinLayerName = "spin"

    /// Neon orange sphere. The halo and specular stay fixed to the screen while
    /// a marked inner layer rotates inside them — a still highlight over turning
    /// surface detail is what sells roll, and it costs one node rotation.
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

        // Rotating surface, clipped to the ball so marks disappear round the
        // limb instead of sliding off the edge.
        let crop = SKCropNode()
        crop.zPosition = 2
        let mask = SKShapeNode(circleOfRadius: r)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask

        let spin = SKNode()
        spin.name = ballSpinLayerName
        // Two dark bands and a couple of speckles: enough asymmetry to see the
        // rotation without turning the ball into a beach ball.
        for (dx, dy, rad, alpha) in [(-0.34, 0.10, 0.30, 0.30),
                                     (0.28, -0.30, 0.38, 0.26),
                                     (0.10, 0.42, 0.16, 0.22),
                                     (-0.12, -0.48, 0.13, 0.18)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            let mark = SKShapeNode(circleOfRadius: r * rad)
            mark.fillColor = SKColor.black.withAlphaComponent(alpha)
            mark.strokeColor = .clear
            mark.position = CGPoint(x: r * dx, y: r * dy)
            spin.addChild(mark)
        }
        crop.addChild(spin)
        root.addChild(crop)

        // Specular sits above the rotating surface and never moves — light
        // source stays put while the ball turns under it.
        let core = SKShapeNode(circleOfRadius: r * 0.34)
        core.fillColor = Config.ballCoreColor.withAlphaComponent(0.92)
        core.strokeColor = .clear
        core.position = CGPoint(x: -r * 0.24, y: r * 0.26)
        core.zPosition = 3
        root.addChild(core)

        return root
    }

    // MARK: - Type

    /// `size` is cap height in points, so call sites keep thinking in points
    /// even though the glyphs are built from blocks.
    static func label(_ text: String, size: CGFloat, color: SKColor,
                      alpha: CGFloat = 1,
                      tracking: CGFloat = Config.hudTracking) -> PixelLabel {
        let l = PixelLabel.make(text, height: size, color: color, tracking: tracking)
        l.alpha = alpha
        return l
    }

    static func titleLabel(_ text: String, size: CGFloat, color: SKColor) -> PixelLabel {
        label(text, size: size, color: color, tracking: Config.titleTracking)
    }

    static func hudLabel(_ text: String, size: CGFloat, color: SKColor,
                         alpha: CGFloat = 1) -> PixelLabel {
        label(text, size: size, color: color, alpha: alpha,
              tracking: Config.hudTracking)
    }
}
