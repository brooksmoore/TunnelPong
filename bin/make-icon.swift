#!/usr/bin/env swift
//
// Draws the CyberPong app icon and writes it into the asset catalog.
// Generated, not hand-drawn, so the icon stays reproducible code like the rest
// of the project.
//
//   xcrun swift bin/make-icon.swift
//
// Style rules, matched to the game:
//   * Everything lands on a coarse pixel grid — the icon is built from blocks,
//     not smooth vectors, so it reads 8-bit at any size.
//   * Tunnel rings are rounded rects using the same corner proportion as the
//     game (and as iOS itself), stepped through the grid.
//   * Neon pink wire on black, one orange ball. Same palette as play.
//
import AppKit
import CoreGraphics
import Foundation

let side = 1024
let out = FileManager.default.currentDirectoryPath
    + "/TunnelPong/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

/// Icon "pixel" — every shape snaps to this so nothing renders sub-block.
let px: CGFloat = 16
func snap(_ v: CGFloat) -> CGFloat { (v / px).rounded() * px }

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

// Game palette.
let neonPink = rgb(1.00, 0.28, 0.58)
let deepPink = rgb(0.85, 0.18, 0.48)
let ballOrange = rgb(1.00, 0.48, 0.09)
let ballHot = rgb(1.00, 0.80, 0.42)

guard let ctx = CGContext(data: nil, width: side, height: side,
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("no context") }

// Hard edges everywhere: no antialiasing is what makes blocks look like blocks.
ctx.setShouldAntialias(false)
ctx.interpolationQuality = .none

let S = CGFloat(side)
ctx.setFillColor(rgb(0, 0, 0))
ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))

// Starfield, deterministic, snapped to the grid.
var seed: UInt64 = 0xC0FFEE
func rnd() -> CGFloat {
    seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
    return CGFloat(seed % 100_000) / 100_000
}
for _ in 0..<46 {
    let x = snap(rnd() * S), y = snap(rnd() * S)
    ctx.setFillColor(rgb(1, 1, 1, 0.25 + rnd() * 0.55))
    ctx.fill(CGRect(x: x, y: y, width: px, height: px))
}

/// Stroke a rounded rect as a ring of grid blocks — a blocky outline rather
/// than a smooth path. Corner radius uses the game's fraction of width, which
/// is also iOS's own screen-corner proportion.
func blockRing(halfW: CGFloat, halfH: CGFloat, weight: CGFloat, color: CGColor) {
    let cx = S / 2, cy = S / 2
    let w = snap(halfW), h = snap(halfH)
    // 0.125 of full width, matching Config.ringCornerFrac; capped so small
    // rings stay rects instead of collapsing to blobs.
    let r = snap(min(0.125 * (w * 2), min(w, h) * 0.32))
    ctx.setFillColor(color)

    var y = -h
    while y <= h {
        var x = -w
        while x <= w {
            let ax = abs(x), ay = abs(y)
            // Distance outside the straight edges, measured into the corner box.
            let dx = ax - (w - r), dy = ay - (h - r)
            let onEdge: Bool
            if dx > 0 && dy > 0 {
                // Corner quadrant: keep blocks within `weight` of the arc.
                let d = sqrt(dx * dx + dy * dy)
                onEdge = d <= r && d > r - weight
            } else {
                onEdge = (ax > w - weight && ay <= h) || (ay > h - weight && ax <= w)
            }
            // Never draw outside the rounded silhouette.
            let inside = (dx <= 0 || dy <= 0) ? (ax <= w && ay <= h)
                                              : sqrt(dx * dx + dy * dy) <= r
            if onEdge && inside {
                ctx.fill(CGRect(x: cx + x, y: cy + y, width: px, height: px))
            }
            x += px
        }
        y += px
    }
}

// Four rings receding toward the centre. Fewer, chunkier rings than the game
// uses — nine would turn to mush at home-screen size.
let rings: [(CGFloat, CGFloat, CGColor)] = [
    (0.400, px * 2, neonPink),
    (0.285, px * 2, neonPink),
    (0.190, px,     deepPink),
    (0.115, px,     deepPink),
]
for (frac, weight, color) in rings {
    blockRing(halfW: S * frac, halfH: S * frac * 1.06, weight: weight, color: color)
}

/// Where a rail meets a rounded ring: the 45° point on the corner arc, inset
/// from the sharp corner by r·(1 − 1/√2). Aiming at the sharp corner instead
/// leaves the rail floating outside the ring — same bug the game had.
func railAnchor(frac: CGFloat) -> CGPoint {
    let w = snap(S * frac)
    let h = snap(S * frac * 1.06)
    let r = snap(min(0.125 * (w * 2), min(w, h) * 0.32))
    let inset = r * (1 - 1 / sqrt(2.0))
    return CGPoint(x: w - inset, y: h - inset)
}

// Corner rails as stepped blocks, outer ring corner → innermost ring corner.
ctx.setFillColor(deepPink)
let a0 = railAnchor(frac: 0.400)
let a1 = railAnchor(frac: 0.115)
for (sx, sy) in [(-1.0, -1.0), (-1.0, 1.0), (1.0, -1.0), (1.0, 1.0)] {
    var t: CGFloat = 0
    while t <= 1.0 {
        let x = snap(CGFloat(sx) * (a0.x + (a1.x - a0.x) * t))
        let y = snap(CGFloat(sy) * (a0.y + (a1.y - a0.y) * t))
        ctx.fill(CGRect(x: S / 2 + x, y: S / 2 + y, width: px, height: px))
        t += 0.015
    }
}

/// Filled disc drawn as blocks.
func blockDisc(cx: CGFloat, cy: CGFloat, radius: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    var y = -radius
    while y <= radius {
        var x = -radius
        while x <= radius {
            if sqrt(x * x + y * y) <= radius {
                ctx.fill(CGRect(x: snap(cx + x), y: snap(cy + y), width: px, height: px))
            }
            x += px
        }
        y += px
    }
}

// The ball: one warm element, offset so the icon isn't dead symmetrical.
let ballC = CGPoint(x: snap(S / 2 + S * 0.055), y: snap(S / 2 - S * 0.040))
blockDisc(cx: ballC.x, cy: ballC.y, radius: S * 0.105, color: ballOrange)
blockDisc(cx: ballC.x - px * 2, cy: ballC.y + px * 2, radius: S * 0.038, color: ballHot)

guard let image = ctx.makeImage() else { fatalError("no image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("no png")
}
try! FileManager.default.createDirectory(
    atPath: (out as NSString).deletingLastPathComponent,
    withIntermediateDirectories: true)
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
