import SpriteKit
import UIKit

/// Procedural 8-bit / modern Game Boy Color visuals.
/// Style reference: Desktop/c3.png — black→indigo→violet→magenta→pink sky,
/// black peaks, pink ridges, white moon. Depth via stepped colour + hard pixels,
/// never soft blur or continuous gradients on actors.
enum NodeFactory {

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    static func snap(_ v: CGFloat) -> CGFloat { Config.snap(v) }

    // MARK: - Backdrop (night-sky gradient only)

    /// Full-frame c3 night gradient + 8-bit stars + crescent moon.
    /// No mountains — clean sky so the tunnel owns the stage.
    static func worldBackdropTexture(size: CGSize) -> SKTexture {
        let px = Config.pixel
        let tw = max(1, Int((size.width / px).rounded()))
        let th = max(1, Int((size.height / px).rounded()))
        let texSize = CGSize(width: tw, height: th)

        var seed: UInt64 = 0xC35C_001
        func rnd() -> CGFloat {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return CGFloat(seed % 100_000) / 100_000
        }

        let bayer: [[Int]] = [
            [0,  8,  2, 10],
            [12, 4, 14,  6],
            [3, 11,  1,  9],
            [15, 7, 13,  5],
        ]

        let skyStops: [SKColor] = [
            Config.sky0, Config.sky1, Config.sky2, Config.sky3, Config.sky4,
            Config.sky5, Config.sky6, Config.sky7, Config.sky8,
        ]
        // Darker sky: black through most of the frame; soft purple only near the
        // bottom (gradient "moved up" — no pink horizon). t = 0 is top (UIKit y-down).
        let skyLocs: [CGFloat] = [
            0.00, 0.28, 0.48, 0.62, 0.74, 0.84, 0.90, 0.95, 1.00,
        ]

        func skyColor(at t: CGFloat, x: Int, y: Int) -> SKColor {
            let clamped = max(0, min(1, t))
            var i0 = 0
            for i in 0..<(skyLocs.count - 1) {
                if clamped >= skyLocs[i] { i0 = i }
            }
            let i1 = min(i0 + 1, skyStops.count - 1)
            let lo = skyLocs[i0]
            let hi = i0 + 1 < skyLocs.count ? skyLocs[i0 + 1] : 1
            let local = (clamped - lo) / max(hi - lo, 0.0001)
            // Full-band ordered dither: the whole band is a soft pixel blend,
            // which keeps the 8-bit look without abrupt solid jumps.
            let thr = CGFloat(bayer[y % 4][x % 4]) / 16.0
            return local > thr ? skyStops[i1] : skyStops[i0]
        }

        let renderer = UIGraphicsImageRenderer(size: texSize)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            for y in 0..<th {
                let t = CGFloat(y) / CGFloat(max(th - 1, 1))
                for x in 0..<tw {
                    cg.setFillColor(skyColor(at: t, x: x, y: y).cgColor)
                    cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }

            // Deterministic 1px stars across the *whole* gradient (same seed every
            // launch). Slightly dimmer near the bottom so they sit in the sky,
            // not on top of the pink band — but density is uniform.
            for _ in 0..<Config.starCount {
                let x = Int(rnd() * CGFloat(tw))
                let y = Int(rnd() * CGFloat(th))
                let depth = CGFloat(y) / CGFloat(max(th - 1, 1))  // 0 top → 1 bottom
                let a = (0.35 + rnd() * 0.50) * (1.0 - depth * 0.35)
                cg.setFillColor(Config.moonColor.withAlphaComponent(a).cgColor)
                cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }

            // Crescent moon (upper right), mirrored on Y so the open face flips.
            let moonCX = Int(CGFloat(tw) * 0.78)
            let moonCY = Int(CGFloat(th) * 0.16)
            let moonR = max(5, Int(CGFloat(tw) * Config.moonRadiusFrac))
            drawPixelCircle(cg, cx: moonCX, cy: moonCY, r: moonR, color: Config.moonColor)
            let punchT = CGFloat(moonCY) / CGFloat(max(th - 1, 1))
            // Punch on the left side (was +x) → crescent opens the other way.
            drawPixelCircle(cg, cx: moonCX - moonR / 2, cy: moonCY - moonR / 5,
                            r: moonR, color: skyColor(at: punchT, x: moonCX, y: moonCY))
        }

        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    private static func drawPixelCircle(_ cg: CGContext, cx: Int, cy: Int, r: Int, color: SKColor) {
        cg.setFillColor(color.cgColor)
        let r2 = r * r
        for y in (cy - r)...(cy + r) {
            for x in (cx - r)...(cx + r) {
                let dx = x - cx, dy = y - cy
                if dx * dx + dy * dy <= r2 {
                    cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }

    /// LCD grid: darkened every-other logical row + thin cell lines.
    static func lcdOverlayTexture(size: CGSize) -> SKTexture {
        let px = Config.pixel
        let tw = max(1, Int((size.width / px).rounded()))
        let th = max(1, Int((size.height / px).rounded()))
        let texSize = CGSize(width: tw, height: th)
        let renderer = UIGraphicsImageRenderer(size: texSize)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            for y in 0..<th {
                if y % 2 == 1 {
                    cg.setFillColor(SKColor.black.withAlphaComponent(Config.lcdRowAlpha).cgColor)
                    cg.fill(CGRect(x: 0, y: y, width: tw, height: 1))
                }
            }
            cg.setFillColor(SKColor.black.withAlphaComponent(Config.lcdGridAlpha).cgColor)
            // Very sparse vertical ticks every 4 cells
            for x in stride(from: 0, to: tw, by: 4) {
                cg.fill(CGRect(x: x, y: 0, width: 1, height: th))
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    /// Mild vignette — still soft is OK as a full-screen grade.
    static func vignetteTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                SKColor.clear.cgColor,
                SKColor.black.withAlphaComponent(Config.vignetteAlpha * 0.2).cgColor,
                SKColor.black.withAlphaComponent(Config.vignetteAlpha).cgColor,
            ] as CFArray
            let locs: [CGFloat] = [0.0, 0.6, 1.0]
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let grad = CGGradient(colorsSpace: space, colors: colors, locations: locs)
            else { return }
            let cx = size.width / 2
            let cy = size.height / 2
            let maxR = hypot(cx, cy) * 1.05
            cg.drawRadialGradient(grad,
                                  startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                                  endCenter: CGPoint(x: cx, y: cy), endRadius: maxR,
                                  options: [.drawsAfterEndLocation])
        }
        return SKTexture(image: image)
    }

    // MARK: - Tunnel

    /// Ring / panel corner radius in screen points (same formula as GameScene rebuild).
    static func ringCornerRadius(halfW: CGFloat, halfH: CGFloat, scale: CGFloat) -> CGFloat {
        let w = halfW * scale
        let h = halfH * scale
        let rRaw = Config.ringCornerFrac * (halfW * 2) * scale
        return min(max(Config.pixel, rRaw), min(w, h) * Config.ringCornerCap)
    }

    static func ring(halfW: CGFloat, halfH: CGFloat, scale: CGFloat,
                     t: CGFloat, center: CGPoint, index: Int = 0) -> SKShapeNode {
        let w = snap(halfW * scale)
        let h = snap(halfH * scale)
        let r = ringCornerRadius(halfW: halfW, halfH: halfH, scale: scale)
        let rect = CGRect(x: -w, y: -h, width: 2 * w, height: 2 * h)
        let node = SKShapeNode(path: PixelPath.roundedRect(rect: rect, cornerRadius: r,
                                                           pixel: Config.pixel))
        node.position = center
        node.lineWidth = Config.ringLineWidth(index: index)
        node.glowWidth = 0
        node.isAntialiased = false
        node.lineJoin = .miter
        node.lineCap = .square
        // Far plane = soft pink fill + hairline outline (thinner than far wire
        // rings so fill+stroke doesn't read heavier than the second-to-last wall).
        let isFarWall = index >= Config.ringCount - 1
        if isFarWall {
            node.fillColor = Config.wallNeonPink.withAlphaComponent(Config.farWallFillAlpha)
            node.strokeColor = Config.wallNeonPink.withAlphaComponent(Config.farWallStrokeAlpha)
            node.lineWidth = Config.farWallStrokeWidth
            node.alpha = 1
        } else {
            node.fillColor = .clear
            node.strokeColor = Config.wallNeonPink
            node.alpha = lerp(Config.ringAlphaNear, Config.ringAlphaFar, t)
        }
        return node
    }

    static func depthPanel(halfW: CGFloat, halfH: CGFloat, scale: CGFloat,
                           t: CGFloat, center: CGPoint) -> SKShapeNode {
        // Transparent walls — panel exists only so rebuild paths stay valid.
        let w = snap(halfW * scale)
        let h = snap(halfH * scale)
        let r = ringCornerRadius(halfW: halfW, halfH: halfH, scale: scale)
        let rect = CGRect(x: -w, y: -h, width: 2 * w, height: 2 * h)
        let node = SKShapeNode(path: PixelPath.roundedRect(rect: rect, cornerRadius: r,
                                                           pixel: Config.pixel))
        node.position = center
        node.fillColor = .clear
        node.strokeColor = .clear
        node.alpha = 0
        node.isHidden = true
        node.isAntialiased = false
        _ = t
        return node
    }

    static func railSegment(t: CGFloat) -> SKShapeNode {
        let node = SKShapeNode()
        node.strokeColor = Config.wallNeonPink
        node.alpha = Config.cornerLineAlpha * lerp(1.0, 0.75, t)
        node.lineWidth = Config.railLineWidthDefault
        node.glowWidth = 0
        node.isAntialiased = false
        // Butt caps so the far-end segment stops on the far ring (square caps
        // used to poke half a stroke past the pink wall).
        node.lineCap = .butt
        node.lineJoin = .miter
        return node
    }

    // MARK: - Actors

    static let impactGlowName = "impactGlow"
    static let paddleInnerName = "innerPlate"

    /// Chunked 8-bit slab paddle — stepped corners, hard pixels, no soft arcs.
    static func paddle(halfW: CGFloat, halfH: CGFloat, color: SKColor) -> SKShapeNode {
        let size = CGSize(width: snap(halfW * 2), height: snap(halfH * 2))
        let cr = Config.paddleCornerRadius
        let outerRect = CGRect(x: -size.width / 2, y: -size.height / 2,
                               width: size.width, height: size.height)
        let node = SKShapeNode(path: PixelPath.roundedRect(rect: outerRect, cornerRadius: cr,
                                                           pixel: Config.pixel))
        node.fillColor = color.withAlphaComponent(Config.paddleFillAlpha)
        node.strokeColor = color
        node.lineWidth = Config.pixel
        node.glowWidth = 0
        node.isAntialiased = false
        node.lineJoin = .miter
        node.lineCap = .square

        let inset = Config.paddleInnerInset
        let innerW = max(Config.pixel * 2, size.width - inset * 2)
        let innerH = max(Config.pixel * 2, size.height - inset * 2)
        let innerRect = CGRect(x: -innerW / 2, y: -innerH / 2, width: innerW, height: innerH)
        let inner = SKShapeNode(path: PixelPath.roundedRect(
            rect: innerRect,
            cornerRadius: max(Config.pixel, cr - Config.pixel * 2),
            pixel: Config.pixel))
        inner.fillColor = .clear
        inner.strokeColor = color.withAlphaComponent(0.45)
        inner.lineWidth = Config.pixel
        inner.isAntialiased = false
        inner.lineJoin = .miter
        inner.lineCap = .square
        inner.zPosition = 1
        inner.name = paddleInnerName
        node.addChild(inner)

        let tick = snap(min(halfW, halfH) * 0.28)
        let cross = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -tick, y: 0)); p.addLine(to: CGPoint(x: tick, y: 0))
        p.move(to: CGPoint(x: 0, y: -tick)); p.addLine(to: CGPoint(x: 0, y: tick))
        cross.path = p
        cross.strokeColor = color.withAlphaComponent(0.40)
        cross.lineWidth = Config.pixel
        cross.isAntialiased = false
        cross.lineCap = .square
        cross.zPosition = 2
        node.addChild(cross)

        let gw = size.width + Config.pixel * 2
        let gh = size.height + Config.pixel * 2
        let glowRect = CGRect(x: -gw / 2, y: -gh / 2, width: gw, height: gh)
        let glow = SKShapeNode(path: PixelPath.roundedRect(
            rect: glowRect,
            cornerRadius: cr + Config.pixel,
            pixel: Config.pixel))
        glow.fillColor = .clear
        glow.strokeColor = color
        glow.lineWidth = Config.paddleGlowLineWidth
        glow.glowWidth = 0
        glow.isAntialiased = false
        glow.lineJoin = .miter
        glow.lineCap = .square
        glow.alpha = 0
        glow.zPosition = -1
        glow.name = impactGlowName
        node.addChild(glow)

        return node
    }

    static let ballSpinLayerName = "spin"

    /// Pixel-art ball: baked nearest-neighbour disc + spinning shade band.
    static func ball() -> SKNode {
        let root = SKNode()
        let r = Config.ballRadius

        // Outer hard disc halo (slightly larger, dim).
        let haloR = r + Config.pixel
        let haloTex = pixelDiscTexture(radiusPts: haloR,
                                       fill: Config.ballColor.withAlphaComponent(0.35),
                                       rim: nil)
        let halo = SKSpriteNode(texture: haloTex)
        halo.size = CGSize(width: haloR * 2, height: haloR * 2)
        halo.zPosition = 0
        halo.alpha = 0.7
        root.addChild(halo)

        let bodyTex = pixelDiscTexture(radiusPts: r,
                                       fill: Config.ballColor,
                                       rim: Config.ballStrokeColor)
        let body = SKSpriteNode(texture: bodyTex)
        body.size = CGSize(width: r * 2, height: r * 2)
        body.zPosition = 1
        root.addChild(body)

        // Spin layer: dark band pixels inside a crop of the same disc mask.
        let crop = SKCropNode()
        crop.zPosition = 2
        let mask = SKSpriteNode(texture: pixelDiscTexture(radiusPts: r,
                                                          fill: .white, rim: nil))
        mask.size = CGSize(width: r * 2, height: r * 2)
        crop.maskNode = mask

        let spin = SKNode()
        spin.name = ballSpinLayerName
        // Two hard latitude bands + a couple of square pips.
        for (dy, h) in [(-0.4, 0.18), (0.25, 0.14)] as [(CGFloat, CGFloat)] {
            let band = SKShapeNode(rectOf: CGSize(width: r * 2, height: snap(r * h)))
            band.fillColor = Config.ballShadeColor.withAlphaComponent(0.55)
            band.strokeColor = .clear
            band.isAntialiased = false
            band.position = CGPoint(x: 0, y: snap(r * dy))
            spin.addChild(band)
        }
        for (dx, dy) in [(0.35, -0.15), (-0.3, 0.35)] as [(CGFloat, CGFloat)] {
            let pip = SKShapeNode(rectOf: CGSize(width: Config.pixel * 2, height: Config.pixel * 2))
            pip.fillColor = Config.ballShadeColor.withAlphaComponent(0.7)
            pip.strokeColor = .clear
            pip.isAntialiased = false
            pip.position = CGPoint(x: snap(r * dx), y: snap(r * dy))
            spin.addChild(pip)
        }
        crop.addChild(spin)
        root.addChild(crop)

        // Fixed highlight (doesn't spin) — single bright pixel cluster.
        let hi = SKShapeNode(rectOf: CGSize(width: Config.pixel * 3, height: Config.pixel * 3))
        hi.fillColor = Config.ballCoreColor
        hi.strokeColor = .clear
        hi.isAntialiased = false
        hi.position = CGPoint(x: -snap(r * 0.28), y: snap(r * 0.28))
        hi.zPosition = 3
        root.addChild(hi)

        return root
    }

    /// Bake a filled disc as integer pixels (true 8-bit circle).
    static func pixelDiscTexture(radiusPts: CGFloat, fill: SKColor, rim: SKColor?) -> SKTexture {
        let px = Config.pixel
        let rBlocks = max(1, Int((radiusPts / px).rounded()))
        let dim = rBlocks * 2 + 1
        let size = CGSize(width: dim, height: dim)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let cx = rBlocks, cy = rBlocks
            let r2 = rBlocks * rBlocks
            let rim2 = (rBlocks - 1) * (rBlocks - 1)
            for y in 0..<dim {
                for x in 0..<dim {
                    let dx = x - cx, dy = y - cy
                    let d2 = dx * dx + dy * dy
                    if d2 <= r2 {
                        if let rim = rim, d2 > rim2 {
                            cg.setFillColor(rim.cgColor)
                        } else {
                            cg.setFillColor(fill.cgColor)
                        }
                        cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                }
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        // Display size matches radiusPts*2
        return tex
    }

    static func ballShadow() -> SKNode {
        let r = Config.ballRadius
        let tex = pixelDiscTexture(radiusPts: r, fill: .black, rim: nil)
        let n = SKSpriteNode(texture: tex)
        n.size = CGSize(width: r * 2 * Config.ballShadowXScale,
                        height: r * 2 * Config.ballShadowYScale)
        n.alpha = Config.ballShadowAlpha
        n.zPosition = 15
        return n
    }

    static func trailGhost() -> SKNode {
        let r = Config.ballRadius
        let tex = pixelDiscTexture(radiusPts: r,
                                   fill: Config.ballColor, rim: nil)
        let n = SKSpriteNode(texture: tex)
        n.size = CGSize(width: r * 2, height: r * 2)
        n.alpha = 0
        n.zPosition = 18
        return n
    }

    // MARK: - Type

    static func label(_ text: String, size: CGFloat, color: SKColor,
                      alpha: CGFloat = 1,
                      tracking: CGFloat = Config.hudTracking,
                      shadow: Bool = false) -> PixelLabel {
        let l = PixelLabel.make(text, height: size, color: color, tracking: tracking,
                                shadow: shadow)
        l.alpha = alpha
        return l
    }

    static func titleLabel(_ text: String, size: CGFloat, color: SKColor) -> PixelLabel {
        // r1.jpg chrome: cyan→pink fill + magenta neon rim.
        _ = color
        return PixelLabel.make(text, height: size, color: Config.titleChromeTop,
                               tracking: Config.titleTracking, shadow: false,
                               style: .chrome)
    }

    static func hudLabel(_ text: String, size: CGFloat, color: SKColor,
                         alpha: CGFloat = 1) -> PixelLabel {
        label(text, size: size, color: color, alpha: alpha,
              tracking: Config.hudTracking, shadow: false)
    }
}
