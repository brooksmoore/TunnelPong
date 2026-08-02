import SpriteKit

/// A 5×7 bitmap typeface defined entirely in code — no font file, no asset
/// catalog. Every glyph is seven rows of five bits; a set bit is one square
/// block. Title style borrows r1.jpg (OVERDRIVE AVENUE): chrome cyan→pink
/// fill with a magenta neon halo.
enum PixelFont {

    static let cols = 5
    static let rows = 7

    /// Row bitmaps, MSB = leftmost column.
    static func glyph(_ c: Character) -> [UInt8] {
        table[c] ?? table[" "]!
    }

    static let table: [Character: [UInt8]] = {
        var out: [Character: [UInt8]] = [:]
        for (ch, art) in art {
            out[ch] = art.map { UInt8($0, radix: 2) ?? 0 }
        }
        return out
    }()

    private static let art: [Character: [String]] = [
        " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],

        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
        "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
        "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
        "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
        "N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
        "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
        "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
        "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
        "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
        "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
        "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],

        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],

        "♥": ["00000", "01010", "11111", "11111", "01110", "00100", "00000"],
        "·": ["00000", "00000", "00000", "00100", "00000", "00000", "00000"],
        ".": ["00000", "00000", "00000", "00000", "00000", "00100", "00100"],
        ",": ["00000", "00000", "00000", "00000", "00100", "00100", "01000"],
        "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
        "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
        ":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
        "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
        "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
        "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
        "'": ["00100", "00100", "00000", "00000", "00000", "00000", "00000"],
        "|": ["00100", "00100", "00100", "00100", "00100", "00100", "00100"],
    ]
}

/// Pixel text. HUD is flat; titles use r1-style chrome (top cyan / bottom pink)
/// plus a magenta neon outline.
final class PixelLabel: SKNode {

    enum HAlign { case left, center, right }
    enum Style { case plain, chrome }

    private let glowShape = SKShapeNode()
    private let outlineShape = SKShapeNode()
    private let shadowShape = SKShapeNode()
    private let fillTop = SKShapeNode()
    private let fillMid = SKShapeNode()
    private let fillBot = SKShapeNode()
    private let shape = SKShapeNode()
    private var raw = ""
    private var wantsShadow = false
    private var style: Style = .plain

    private(set) var pixelSize: CGFloat = 3
    var tracking: CGFloat = 1 { didSet { rebuild() } }
    var hAlign: HAlign = .center { didSet { rebuild() } }

    var tint: SKColor = .white {
        didSet {
            if style == .plain {
                shape.fillColor = tint
                shape.strokeColor = .clear
            }
        }
    }

    /// Switch plain ↔ chrome (e.g. score beats high score mid-run).
    func setStyle(_ newStyle: Style) {
        guard newStyle != style else { return }
        style = newStyle
        removeAllChildren()
        if style == .chrome {
            addChild(glowShape)
            addChild(outlineShape)
            addChild(fillTop)
            addChild(fillMid)
            addChild(fillBot)
        } else {
            if wantsShadow { addChild(shadowShape) }
            addChild(shape)
        }
        rebuild()
    }

    static func make(_ text: String, height: CGFloat, color: SKColor,
                     tracking: CGFloat = 1, align: HAlign = .center,
                     shadow: Bool = false, style: Style = .plain) -> PixelLabel {
        let l = PixelLabel()
        let rawPx = max(Config.pixel, (height / CGFloat(PixelFont.rows)))
        l.pixelSize = Config.snap(rawPx)
        if l.pixelSize < Config.pixel { l.pixelSize = Config.pixel }
        l.tracking = tracking
        l.hAlign = align
        l.raw = text
        l.wantsShadow = shadow
        l.style = style

        for n in [l.glowShape, l.outlineShape, l.shadowShape,
                  l.fillTop, l.fillMid, l.fillBot, l.shape] {
            n.strokeColor = .clear
            n.isAntialiased = false
        }
        l.glowShape.zPosition = -3
        l.outlineShape.zPosition = -2
        l.shadowShape.zPosition = -1
        l.fillTop.zPosition = 0
        l.fillMid.zPosition = 0
        l.fillBot.zPosition = 0
        l.shape.zPosition = 1

        if style == .chrome {
            l.addChild(l.glowShape)
            l.addChild(l.outlineShape)
            l.addChild(l.fillTop)
            l.addChild(l.fillMid)
            l.addChild(l.fillBot)
        } else {
            if shadow { l.addChild(l.shadowShape) }
            l.addChild(l.shape)
        }
        l.tint = color
        l.rebuild()
        return l
    }

    func display(_ text: String) {
        guard text != raw else { return }
        raw = text
        rebuild()
    }

    var contentWidth: CGFloat {
        let n = CGFloat(raw.count)
        guard n > 0 else { return 0 }
        return n * CGFloat(PixelFont.cols) * pixelSize
            + (n - 1) * tracking * pixelSize
    }

    private func rebuild() {
        let px = pixelSize
        let total = contentWidth
        var originX: CGFloat
        switch hAlign {
        case .left:   originX = 0
        case .center: originX = -total / 2
        case .right:  originX = -total
        }
        let top = CGFloat(PixelFont.rows) * px / 2
        let midY = 0 as CGFloat  // vertical centre of label

        let full = CGMutablePath()
        let topPath = CGMutablePath()
        let midPath = CGMutablePath()
        let botPath = CGMutablePath()

        var ox = originX
        for ch in raw.uppercased() {
            let bitmap = PixelFont.glyph(ch)
            for (r, bits) in bitmap.enumerated() {
                for c in 0..<PixelFont.cols {
                    guard bits & (1 << (PixelFont.cols - 1 - c)) != 0 else { continue }
                    let rect = CGRect(x: ox + CGFloat(c) * px,
                                      y: top - CGFloat(r + 1) * px,
                                      width: px, height: px)
                    full.addRect(rect)
                    // 3-band chrome: bright pink → magenta → dark purple (top→bot).
                    let band = CGFloat(r) / CGFloat(max(PixelFont.rows - 1, 1))
                    if band < 0.34 {
                        topPath.addRect(rect)
                    } else if band < 0.67 {
                        midPath.addRect(rect)
                    } else {
                        botPath.addRect(rect)
                    }
                }
            }
            ox += CGFloat(PixelFont.cols) * px + tracking * px
        }
        _ = midY

        if style == .chrome {
            let glow = CGMutablePath()
            let o = px * 0.50
            for dx in [-o, 0, o] {
                for dy in [-o, 0, o] {
                    if dx == 0 && dy == 0 { continue }
                    var t = CGAffineTransform(translationX: dx, y: dy)
                    if let p = full.copy(using: &t) { glow.addPath(p) }
                }
            }
            glowShape.path = glow
            glowShape.fillColor = Config.titleNeonGlow.withAlphaComponent(0.30)

            let rim = CGMutablePath()
            let rOff = px * 0.28
            for dx in [-rOff, 0, rOff] {
                for dy in [-rOff, 0, rOff] {
                    if dx == 0 && dy == 0 { continue }
                    var t = CGAffineTransform(translationX: dx, y: dy)
                    if let p = full.copy(using: &t) { rim.addPath(p) }
                }
            }
            outlineShape.path = rim
            outlineShape.fillColor = Config.titleNeonGlow.withAlphaComponent(0.50)

            fillTop.path = topPath
            fillTop.fillColor = Config.titleChromeTop
            fillMid.path = midPath
            fillMid.fillColor = Config.titleChromeMid
            fillBot.path = botPath
            fillBot.fillColor = Config.titleChromeBot
            shape.path = nil
        } else {
            shape.path = full
            shape.fillColor = tint
            shape.strokeColor = .clear
            if wantsShadow {
                shadowShape.path = full
                shadowShape.fillColor = Config.typeShadowColor
                let off = Config.titleShadowBlocks * px
                shadowShape.position = CGPoint(x: off, y: -off)
            }
        }
    }
}
