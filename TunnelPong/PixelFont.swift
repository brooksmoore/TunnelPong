import SpriteKit

/// A 5×7 bitmap typeface defined entirely in code — no font file, no asset
/// catalog. Every glyph is seven rows of five bits; a set bit is one square
/// block. This is what carries the 8-bit read: real pixel construction rather
/// than a smooth vector face pretending to be retro.
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

        // Pixel heart — the life indicator.
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
    ]
}

/// Draws `PixelFont` text as one filled path — a whole line of copy costs a
/// single node and one draw call, so HUD updates stay cheap.
final class PixelLabel: SKNode {

    enum HAlign { case left, center, right }

    private let shape = SKShapeNode()
    private var raw = ""

    /// Edge length of one block, in points. Rounded to whole points so the
    /// grid never lands on a half pixel and blurs.
    private(set) var pixelSize: CGFloat = 2
    /// Blank columns between glyphs, in blocks.
    var tracking: CGFloat = 1 { didSet { rebuild() } }
    var hAlign: HAlign = .center { didSet { rebuild() } }

    var tint: SKColor = .white {
        didSet { shape.fillColor = tint; shape.strokeColor = .clear }
    }

    /// `height` is the cap height the text should occupy, so call sites can go
    /// on thinking in points rather than blocks.
    static func make(_ text: String, height: CGFloat, color: SKColor,
                     tracking: CGFloat = 1, align: HAlign = .center) -> PixelLabel {
        let l = PixelLabel()
        l.pixelSize = max(1, (height / CGFloat(PixelFont.rows)).rounded())
        l.tracking = tracking
        l.hAlign = align
        l.raw = text
        l.shape.strokeColor = .clear
        l.shape.isAntialiased = false      // keep block edges hard
        l.addChild(l.shape)
        l.tint = color
        l.rebuild()
        return l
    }

    func display(_ text: String) {
        guard text != raw else { return }
        raw = text
        rebuild()
    }

    /// Width of the current line in points — used for fitting copy to the frame.
    var contentWidth: CGFloat {
        let n = CGFloat(raw.count)
        guard n > 0 else { return 0 }
        return n * CGFloat(PixelFont.cols) * pixelSize
            + (n - 1) * tracking * pixelSize
    }

    private func rebuild() {
        let path = CGMutablePath()
        let px = pixelSize
        let glyphW = CGFloat(PixelFont.cols) * px
        let advance = glyphW + tracking * px
        let total = contentWidth

        var originX: CGFloat
        switch hAlign {
        case .left:   originX = 0
        case .center: originX = -total / 2
        case .right:  originX = -total
        }
        // Vertically centred on the node's origin.
        let top = CGFloat(PixelFont.rows) * px / 2

        for ch in raw.uppercased() {
            let bitmap = PixelFont.glyph(ch)
            for (r, bits) in bitmap.enumerated() {
                for c in 0..<PixelFont.cols {
                    guard bits & (1 << (PixelFont.cols - 1 - c)) != 0 else { continue }
                    path.addRect(CGRect(x: originX + CGFloat(c) * px,
                                        y: top - CGFloat(r + 1) * px,
                                        width: px, height: px))
                }
            }
            originX += advance
        }
        shape.path = path
        shape.fillColor = tint
        shape.strokeColor = .clear
    }
}
