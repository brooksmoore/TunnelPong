import CoreGraphics

/// Maps 3D court coordinates to 2D screen points with a single perspective
/// divide. This one divide is the entire "3D" illusion:
///
///     scale   = focal / (focal + z)
///     screenX = centerX + x * scale
///     screenY = centerY + y * scale
///
/// Any object's rendered size is multiplied by the same scale.
struct Projector {
    var focal: CGFloat
    var center: CGPoint

    func scale(z: CGFloat) -> CGFloat {
        // Keep (focal + z) strictly positive so a ball that flies past the
        // camera never divides by zero or flips the tunnel inside-out.
        let safeZ = max(z, -focal + 1)
        return focal / (focal + safeZ)
    }

    func project(x: CGFloat, y: CGFloat, z: CGFloat) -> CGPoint {
        let s = scale(z: z)
        return CGPoint(x: center.x + x * s, y: center.y + y * s)
    }
}

/// Pure court/ball math shared by gameplay and unit tests.
enum CourtMath {

    /// Fold an unbounded coordinate into [-limit, limit] as if it had been
    /// bouncing off the walls the whole way (triangle wave).
    static func reflect(_ p: CGFloat, limit: CGFloat) -> CGFloat {
        guard limit > 0 else { return 0 }
        let period = 4 * limit
        var m = (p + limit).truncatingRemainder(dividingBy: period)
        if m < 0 { m += period }
        return m <= 2 * limit ? m - limit : 3 * limit - m
    }

    /// Renormalize velocity to `speed`, then guarantee a minimum |vz| share so
    /// heavy english can't leave the ball ping-ponging sideways forever.
    static func renormVelocity(vx: inout CGFloat, vy: inout CGFloat, vz: inout CGFloat,
                               speed: CGFloat, minVzFraction: CGFloat) {
        var mag = sqrt(vx * vx + vy * vy + vz * vz)
        if mag < 0.001 { mag = 0.001 }
        let f = speed / mag
        vx *= f; vy *= f; vz *= f

        let minVz = minVzFraction * speed
        if abs(vz) < minVz {
            let sign: CGFloat = vz >= 0 ? 1 : -1
            vz = sign * minVz
            let lateralBudget = sqrt(max(speed * speed - vz * vz, 0))
            let lat = sqrt(vx * vx + vy * vy)
            if lat > 0.001 {
                let lf = lateralBudget / lat
                vx *= lf; vy *= lf
            }
        }
    }

    static func moveToward(_ value: CGFloat, target: CGFloat, maxStep: CGFloat) -> CGFloat {
        let d = target - value
        return value + max(-maxStep, min(maxStep, d))
    }

    /// Ring depth parameter t in [0, 1]. Safe when ringCount is 1.
    static func ringT(index: Int, ringCount: Int) -> CGFloat {
        let denom = max(ringCount - 1, 1)
        return CGFloat(index) / CGFloat(denom)
    }

    /// Nearest ring index for a depth z. Clamped to [0, ringCount - 1].
    static func ringIndex(z: CGFloat, zFar: CGFloat, ringCount: Int) -> Int {
        guard ringCount > 0 else { return 0 }
        let denom = max(ringCount - 1, 1)
        let raw = Int((z / zFar * CGFloat(denom)).rounded())
        return max(0, min(ringCount - 1, raw))
    }

    // MARK: - Curve (frame-rate independent)

    /// Integrate curve into lateral velocity, decay curve exponentially in real
    /// time, then renorm total speed so curve bends without accelerating.
    static func applyCurveStep(
        vx: inout CGFloat, vy: inout CGFloat, vz: inout CGFloat,
        curveX: inout CGFloat, curveY: inout CGFloat,
        dt: CGFloat,
        curveDecayPerSecond: CGFloat,
        minVzFraction: CGFloat
    ) {
        guard dt > 0 else { return }
        let speedBefore = sqrt(vx * vx + vy * vy + vz * vz)
        vx += curveX * dt
        vy += curveY * dt
        let decay = pow(curveDecayPerSecond, dt)
        curveX *= decay
        curveY *= decay
        if speedBefore > 0.001 {
            renormVelocity(vx: &vx, vy: &vy, vz: &vz,
                           speed: speedBefore, minVzFraction: minVzFraction)
        }
    }

    /// Clamp curve vector magnitude to `maxMag`.
    static func clampCurve(curveX: inout CGFloat, curveY: inout CGFloat, maxMag: CGFloat) {
        let mag = hypot(curveX, curveY)
        guard mag > maxMag, mag > 0.0001 else { return }
        let s = maxMag / mag
        curveX *= s
        curveY *= s
    }

    /// Wall bounce: damp curve and flip the component on the reflected axis.
    static func wallBounceCurve(
        curveX: inout CGFloat, curveY: inout CGFloat,
        flipX: Bool, flipY: Bool,
        damp: CGFloat
    ) {
        if flipX { curveX = -curveX }
        if flipY { curveY = -curveY }
        curveX *= damp
        curveY *= damp
    }

    /// Curve set from paddle world-velocity (units/sec).
    ///
    /// Curveball player hit uses **inverted** brush English:
    ///   `myCurve.x = (-pSpeedX) / curveAmount`
    ///   `myCurve.y = pSpeedY / curveAmount` with Flash `pos.y -= speed.y`
    /// which visually means: swipe right → ball curves left; swipe down → ball lifts.
    /// Enemy hit keeps **same-direction** curve (`+eSpeedX`, `-eSpeedY` in Flash).
    /// Pass `invert: true` for the near (player) paddle; `false` for the AI.
    static func curveFromPaddleVelocity(
        paddleVelX: CGFloat, paddleVelY: CGFloat,
        scale: CGFloat, maxMag: CGFloat,
        invert: Bool = true
    ) -> (CGFloat, CGFloat) {
        let sx: CGFloat = invert ? -1 : 1
        let sy: CGFloat = invert ? -1 : 1
        var cx = sx * paddleVelX * scale
        var cy = sy * paddleVelY * scale
        clampCurve(curveX: &cx, curveY: &cy, maxMag: maxMag)
        return (cx, cy)
    }

    /// Exponential smooth toward a sample (alpha in 0…1 per call).
    static func smoothToward(_ current: CGFloat, sample: CGFloat, alpha: CGFloat) -> CGFloat {
        current + (sample - current) * max(0, min(1, alpha))
    }

    /// Fraction of gap closed in `dt` when `lerpPerFrame` is the 60 Hz close rate.
    static func followAlpha(lerpPerFrame: CGFloat, dt: CGFloat) -> CGFloat {
        1 - pow(1 - max(0, min(1, lerpPerFrame)), dt * 60)
    }

    // MARK: - Rally start

    /// Where a point begins: dead centre of the tunnel on x and y, and
    /// `fraction` of the way down z. There is no serve-from-your-own-plane.
    static func rallyStartZ(zFar: CGFloat, fraction: CGFloat) -> CGFloat {
        zFar * fraction
    }

    /// Launch direction out of the centre.
    ///
    /// The player plane is z = 0 and the opponent plane is z = zFar, so heading
    /// toward the player is **negative** vz. Getting this sign backwards sends
    /// every point the wrong way, which is why it is a function and not a
    /// ternary buried in the scene.
    static func rallyLaunchVz(magnitude: CGFloat, towardPlayer: Bool) -> CGFloat {
        towardPlayer ? -abs(magnitude) : abs(magnitude)
    }

    /// Depth at which a court of half-width `courtHalfWidth` projects to
    /// `targetHalfWidth` on screen.
    ///
    /// Used to place the player's paddle plane exactly at the glass, so the ball
    /// travels all the way to the viewer instead of stopping on the first wall.
    /// Clamped to `minZ` so the plane can never approach `-focal`, where the
    /// perspective divide blows up and the tunnel turns inside out.
    static func planeZFilling(
        targetHalfWidth: CGFloat, courtHalfWidth: CGFloat, focal: CGFloat, minZ: CGFloat
    ) -> CGFloat {
        guard courtHalfWidth > 0.001, targetHalfWidth > 0.001 else { return 0 }
        let s = targetHalfWidth / courtHalfWidth        // needed scale (>1 pulls closer)
        let z = focal * (1 - s) / max(s, 0.0001)
        // Never push the plane *away* from the viewer past the first wall.
        return max(min(z, 0), minZ)
    }

    /// Depth span for type painted on a tunnel surface, centred **on screen**
    /// inside one wall segment.
    ///
    /// Surface type sits at a constant world height, so its screen position is
    /// proportional to the perspective scale at that depth. Because that scale
    /// is non-linear in z, insetting equally in z leaves a visible gap at the
    /// near wall and none at the far one. Insetting in *scale* space instead
    /// makes both gaps equal, which is what the eye reads as centred.
    static func surfaceTypeSpan(
        segStartZ: CGFloat, segEndZ: CGFloat, focal: CGFloat, inset: CGFloat
    ) -> (near: CGFloat, far: CGFloat) {
        func scale(_ z: CGFloat) -> CGFloat { focal / max(focal + z, 0.001) }
        func depth(_ s: CGFloat) -> CGFloat { focal * (1 - s) / max(s, 0.0001) }

        let sStart = scale(segStartZ)          // nearer wall: larger scale
        let sEnd = scale(segEndZ)              // farther wall: smaller scale
        let spread = sStart - sEnd
        guard spread > 0 else { return (segStartZ, segEndZ) }

        let pad = spread * max(0, min(0.45, inset))
        return (depth(sStart - pad), depth(sEnd + pad))
    }

    /// Who receives the first touch of the next point.
    ///
    /// The ball always goes first toward whoever **won** the previous point:
    /// win it and you get the free opening touch, lose it and the opponent
    /// takes the ball first and you receive whatever curve they put on it.
    /// A new level counts as a win for the player (see `GameScene.endTransition`).
    static func firstTouchGoesToPlayer(playerWonLastPoint: Bool) -> Bool {
        playerWonLastPoint
    }
}

// MARK: - Self-degrading score bonuses (pure; no SpriteKit)

/// Curveball-style bonuses: award then degrade; floor at 0; reset on life loss.
struct ScoreBonuses: Equatable {
    var hitScore: Int
    var curveBonus: Int
    var superCurveBonus: Int
    var accuracyBonus: Int
    /// Remaining level-clear bank (decays while ball is live).
    var levelClearBonus: Int
    /// Sub-point carry for level-clear decay (not part of score display).
    var levelClearFrac: CGFloat = 0

    static func fresh(
        hit: Int = 100,
        curve: Int = 50,
        superCurve: Int = 150,
        accuracy: Int = 100,
        levelClear: Int = 3000
    ) -> ScoreBonuses {
        ScoreBonuses(hitScore: hit, curveBonus: curve, superCurveBonus: superCurve,
                     accuracyBonus: accuracy, levelClearBonus: levelClear,
                     levelClearFrac: 0)
    }

    mutating func reset(
        hit: Int, curve: Int, superCurve: Int, accuracy: Int, levelClear: Int
    ) {
        hitScore = hit
        curveBonus = curve
        superCurveBonus = superCurve
        accuracyBonus = accuracy
        levelClearBonus = levelClear
        levelClearFrac = 0
    }

    /// Award current hit value, then degrade. Returns points added (≥ 0).
    mutating func awardHit(degrade: Int) -> Int {
        let got = max(0, hitScore)
        hitScore = max(0, hitScore - max(0, degrade))
        return got
    }

    /// Single-axis curve bonus.
    mutating func awardCurve(degrade: Int) -> Int {
        let got = max(0, curveBonus)
        curveBonus = max(0, curveBonus - max(0, degrade))
        return got
    }

    /// Both-axes super curve bonus.
    mutating func awardSuperCurve(degrade: Int) -> Int {
        let got = max(0, superCurveBonus)
        superCurveBonus = max(0, superCurveBonus - max(0, degrade))
        return got
    }

    mutating func awardAccuracy(degrade: Int) -> Int {
        let got = max(0, accuracyBonus)
        accuracyBonus = max(0, accuracyBonus - max(0, degrade))
        return got
    }

    /// Tick level-clear bank down while the ball is live. Never negative.
    mutating func tickLevelClear(dt: CGFloat, decayPerSecond: CGFloat) {
        guard dt > 0, decayPerSecond > 0, levelClearBonus > 0 else { return }
        levelClearFrac += decayPerSecond * dt
        let whole = Int(levelClearFrac)
        if whole > 0 {
            levelClearBonus = max(0, levelClearBonus - whole)
            levelClearFrac -= CGFloat(whole)
        }
        if levelClearBonus == 0 { levelClearFrac = 0 }
    }

    /// Bank remaining level-clear bonus and re-arm for next level.
    mutating func bankLevelClear(resetTo: Int) -> Int {
        let got = max(0, levelClearBonus)
        levelClearBonus = max(0, resetTo)
        levelClearFrac = 0
        return got
    }
}

/// Which style bonus popups to show (player education, not decoration).
enum BonusPopupKind: String {
    case curve = "CURVE BONUS"
    case superCurve = "SUPER CURVE"
    case perfect = "PERFECT HIT"
}

/// Classify a hit for scoring / popups from curve + paddle offset.
struct HitBonusResult: Equatable {
    var points: Int
    var popups: [BonusPopupKind]
}

enum HitScoring {
    /// Apply hit / curve / super / accuracy awards for one paddle contact.
    static func scorePlayerHit(
        bonuses: inout ScoreBonuses,
        curveX: CGFloat, curveY: CGFloat,
        curveBonusThreshold: CGFloat,
        curveSuperThreshold: CGFloat,
        offsetFracX: CGFloat, offsetFracY: CGFloat,
        accuracyWindowFrac: CGFloat,
        hitDegrade: Int, curveDegrade: Int,
        superDegrade: Int, accuracyDegrade: Int
    ) -> HitBonusResult {
        var points = bonuses.awardHit(degrade: hitDegrade)
        var popups: [BonusPopupKind] = []

        let ax = abs(curveX), ay = abs(curveY)
        let superCurve = ax >= curveSuperThreshold && ay >= curveSuperThreshold
        let anyCurve = ax >= curveBonusThreshold || ay >= curveBonusThreshold

        if superCurve {
            points += bonuses.awardSuperCurve(degrade: superDegrade)
            popups.append(.superCurve)
        } else if anyCurve {
            points += bonuses.awardCurve(degrade: curveDegrade)
            popups.append(.curve)
        }

        if abs(offsetFracX) <= accuracyWindowFrac,
           abs(offsetFracY) <= accuracyWindowFrac {
            points += bonuses.awardAccuracy(degrade: accuracyDegrade)
            popups.append(.perfect)
        }

        return HitBonusResult(points: points, popups: popups)
    }
}

// MARK: - 8-bit stepped rounded rects

/// Pixel-art style rounded rectangles: corners are quantized stair-steps on
/// the logical pixel grid, never smooth Bézier arcs.
enum PixelPath {

    /// Inset from the sharp corner (±halfW, ±halfH) to the 45° meeting point
    /// on a stepped (or circular) corner of radius `r` — used for rail anchors.
    static func railCornerInset(radius r: CGFloat) -> CGFloat {
        max(0, r * (1 - 1 / sqrt(2)))
    }

    /// Quantize a nominal corner radius down to whole logical pixels.
    static func quantizeRadius(_ r: CGFloat, pixel: CGFloat = 3) -> CGFloat {
        let px = max(pixel, 1)
        guard r > 0 else { return 0 }
        return max(px, floor(r / px) * px)
    }

    /// Closed path for a rect with 8-bit stepped corners.
    ///
    /// Corners follow a quarter-circle, then snap to a fine pixel grid so the
    /// silhouette reads *round* (many small stairs) rather than a flat chamfer.
    /// `pixel` is the style block size; sampling uses a finer grid (`pixel/2`,
    /// min 1) so large rings don't collapse into octagons.
    static func roundedRect(rect: CGRect, cornerRadius: CGFloat,
                            pixel: CGFloat = 3) -> CGPath {
        let stylePx = max(pixel, 1)
        // Finer snap than style block → rounder stairs, still hard-edged.
        let snapPx = max(1, floor(stylePx / 2))
        var r = quantizeRadius(cornerRadius, pixel: snapPx)
        let maxR = min(rect.width, rect.height) / 2
        r = min(r, floor(maxR / snapPx) * snapPx)
        if r < snapPx * 0.5 {
            let path = CGMutablePath()
            path.addRect(rect)
            return path
        }

        let minX = rect.minX, maxX = rect.maxX
        let minY = rect.minY, maxY = rect.maxY
        // Sample by arc length so we keep ~1 snap-cell per step around the curve.
        func cornerOffsets() -> [CGPoint] {
            let arcLen = r * CGFloat.pi / 2
            let steps = max(4, Int(ceil(arcLen / snapPx)))
            var pts: [CGPoint] = []
            var lastIX = Int.min, lastIY = Int.min
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let ang = t * CGFloat.pi / 2
                let lx = (r * sin(ang) / snapPx).rounded() * snapPx
                let ly = (r * cos(ang) / snapPx).rounded() * snapPx
                let ix = Int((lx / snapPx).rounded())
                let iy = Int((ly / snapPx).rounded())
                if ix != lastIX || iy != lastIY {
                    pts.append(CGPoint(x: lx, y: ly))
                    lastIX = ix
                    lastIY = iy
                }
            }
            // Always pin exact start/end on the axes so sides meet cleanly.
            if let first = pts.first, first.x != 0 || first.y != r {
                pts.insert(CGPoint(x: 0, y: r), at: 0)
            }
            if let last = pts.last, last.x != r || last.y != 0 {
                pts.append(CGPoint(x: r, y: 0))
            }
            if pts.isEmpty { pts = [CGPoint(x: 0, y: r), CGPoint(x: r, y: 0)] }
            return pts
        }
        let c = cornerOffsets()
        let path = CGMutablePath()

        // Start mid-top, go clockwise: top → TR → right → BR → bottom → BL → left → TL → close.
        path.move(to: CGPoint(x: 0, y: maxY))

        // Top edge into top-right corner
        path.addLine(to: CGPoint(x: maxX - r, y: maxY))
        for p in c {
            path.addLine(to: CGPoint(x: maxX - r + p.x, y: maxY - r + p.y))
        }

        // Right edge into bottom-right
        path.addLine(to: CGPoint(x: maxX, y: minY + r))
        for p in c {
            path.addLine(to: CGPoint(x: maxX - r + p.y, y: minY + r - p.x))
        }

        // Bottom edge into bottom-left
        path.addLine(to: CGPoint(x: minX + r, y: minY))
        for p in c {
            path.addLine(to: CGPoint(x: minX + r - p.x, y: minY + r - p.y))
        }

        // Left edge into top-left
        path.addLine(to: CGPoint(x: minX, y: maxY - r))
        for p in c {
            path.addLine(to: CGPoint(x: minX + r - p.y, y: maxY - r + p.x))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Peer mirror (v2 prep; not used by solo gameplay)

/// Maps local-frame world state into the peer's local frame for network send.
///
/// **Convention (locked in docs/V2_DESIGN.md):**
/// - Each device always *stores* state in local frame: self at z = 0, opponent at zFar.
/// - Apply this transform **on send only**. Never also on receive (double-flip).
/// - x sign: `-x` as specified; verify on first two-device playtest and update tests if flipped.
///
///     z'  = zFar - z
///     x'  = -x
///     vz' = -vz
///     vx' = -vx
///     y, vy unchanged
enum PeerMirror {

    struct Pose: Equatable {
        var x: CGFloat
        var y: CGFloat
        var z: CGFloat
    }

    struct Velocity: Equatable {
        var vx: CGFloat
        var vy: CGFloat
        var vz: CGFloat
    }

    static func position(_ p: Pose, zFar: CGFloat) -> Pose {
        Pose(x: -p.x, y: p.y, z: zFar - p.z)
    }

    static func velocity(_ v: Velocity) -> Velocity {
        Velocity(vx: -v.vx, vy: v.vy, vz: -v.vz)
    }

    /// Full ball snapshot helper for handoff packets.
    static func ball(x: CGFloat, y: CGFloat, z: CGFloat,
                     vx: CGFloat, vy: CGFloat, vz: CGFloat,
                     zFar: CGFloat) -> (Pose, Velocity) {
        let p = position(Pose(x: x, y: y, z: z), zFar: zFar)
        let v = velocity(Velocity(vx: vx, vy: vy, vz: vz))
        return (p, v)
    }
}
