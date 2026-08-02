#!/usr/bin/env swift
//
// Draws the CyberPong app icon and writes it into the asset catalog.
// The icon is generated, not hand-drawn, so it stays reproducible code like
// everything else in this project.
//
//   xcrun swift bin/make-icon.swift
//
import AppKit
import CoreGraphics
import Foundation

let side = 1024
let out = FileManager.default.currentDirectoryPath
    + "/TunnelPong/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

// Same wall ramp as Config.wallColor: near hot pink → far deep indigo.
let ramp: [(CGFloat, CGFloat, CGFloat)] = [
    (1.00, 0.40, 0.52),
    (0.98, 0.24, 0.60),
    (0.72, 0.22, 0.78),
    (0.42, 0.18, 0.70),
    (0.20, 0.10, 0.44),
]
func rampColor(_ t: CGFloat) -> CGColor {
    let c = max(0, min(1, t)) * CGFloat(ramp.count - 1)
    let i = min(Int(c), ramp.count - 2)
    let f = c - CGFloat(i)
    let a = ramp[i], b = ramp[i + 1]
    return rgb(a.0 + (b.0 - a.0) * f, a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f)
}

guard let ctx = CGContext(data: nil, width: side, height: side,
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("no context") }

let S = CGFloat(side)
ctx.setFillColor(rgb(0, 0, 0))
ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))

// A few stars, deterministic.
var seed: UInt64 = 0xC0FFEE
func rnd() -> CGFloat {
    seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
    return CGFloat(seed % 100_000) / 100_000
}
for _ in 0..<70 {
    let x = rnd() * S, y = rnd() * S, r = 1.5 + rnd() * 3
    ctx.setFillColor(rgb(1, 1, 1, 0.20 + rnd() * 0.6))
    ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
}

// Tunnel: concentric squares receding to the centre. Square corners and a
// small ring count keep it legible at home-screen size, where the real
// tunnel's 9 rings would turn to mush.
let center = CGPoint(x: S / 2, y: S / 2)
// Outer ring stays inside 0.40 so iOS's rounded-corner mask never clips it.
let rings = 5
for i in 0..<rings {
    let t = CGFloat(i) / CGFloat(rings - 1)
    let half = S * (0.40 - t * 0.325)
    ctx.setStrokeColor(rampColor(t))
    ctx.setLineWidth(S * (0.024 - t * 0.011))
    ctx.stroke(CGRect(x: center.x - half, y: center.y - half,
                      width: half * 2, height: half * 2))
}

// Corner rails, drawn from the outer ring toward the vanishing point.
ctx.setLineWidth(S * 0.008)
ctx.setStrokeColor(rgb(0.72, 0.22, 0.78, 0.55))
let outer = S * 0.40, inner = S * 0.075
for (sx, sy) in [(-1.0, -1.0), (-1.0, 1.0), (1.0, -1.0), (1.0, 1.0)] {
    ctx.move(to: CGPoint(x: center.x + CGFloat(sx) * outer,
                         y: center.y + CGFloat(sy) * outer))
    ctx.addLine(to: CGPoint(x: center.x + CGFloat(sx) * inner,
                            y: center.y + CGFloat(sy) * inner))
}
ctx.strokePath()

// The ball: the one warm element, offset so the icon isn't dead symmetrical.
let ballR = S * 0.095
let ballC = CGPoint(x: center.x + S * 0.062, y: center.y - S * 0.045)
// Radial falloff, not a flat disc — a constant-alpha circle over black just
// reads as an opaque brown blob.
if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [rgb(1.0, 0.48, 0.09, 0.55),
                                  rgb(1.0, 0.35, 0.06, 0.18),
                                  rgb(1.0, 0.30, 0.05, 0.0)] as CFArray,
                         locations: [0.0, 0.45, 1.0]) {
    ctx.saveGState()
    ctx.drawRadialGradient(glow, startCenter: ballC, startRadius: ballR * 0.6,
                           endCenter: ballC, endRadius: ballR * 2.6,
                           options: [])
    ctx.restoreGState()
}
ctx.setFillColor(rgb(1.0, 0.48, 0.09))
ctx.fillEllipse(in: CGRect(x: ballC.x - ballR, y: ballC.y - ballR,
                           width: ballR * 2, height: ballR * 2))
ctx.setFillColor(rgb(1.0, 0.80, 0.42))
let coreR = ballR * 0.38
ctx.fillEllipse(in: CGRect(x: ballC.x - coreR - ballR * 0.22,
                           y: ballC.y - coreR + ballR * 0.24,
                           width: coreR * 2, height: coreR * 2))

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
