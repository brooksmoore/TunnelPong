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
