// CyberPong v1.5 pure-logic tests.
//
// This harness is COMPILED AGAINST THE REAL SHIPPING SOURCE — it links
// TunnelPong/Projection.swift and TunnelPong/Config.swift directly. There is no
// mirrored copy of the logic here, and no hard-coded tuning literals: every
// threshold below reads from Config, so retuning Config cannot silently
// invalidate a test, and drift between test and app is impossible by
// construction.
//
// Run with: ./bin/test_v1_5.sh

import Foundation
import CoreGraphics

var failures = 0
var passes = 0

func check(_ name: String, _ ok: Bool, detail: String = "") {
    if ok {
        passes += 1
        print("  PASS  \(name)")
    } else {
        failures += 1
        print("  FAIL  \(name)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

func nearlyEqual(_ a: CGFloat, _ b: CGFloat, tol: CGFloat) -> Bool { abs(a - b) <= tol }

// Real Config values — not copies.
let decay = Config.curveDecayPerSecond
let minVz = Config.minVzFraction
let curveMax = Config.curveMax
let wallDamp = Config.curveWallDamp

print("=== CyberPong v1.5 pure-logic tests (real source) ===")
print("Config: decay=\(decay) minVz=\(minVz) curveMax=\(curveMax) wallDamp=\(wallDamp)\n")

// 1. Curve decay is frame-rate independent.
print("1) Frame-rate independent curve decay")
func integrateDeflection(hz: CGFloat, seconds: CGFloat) -> (x: CGFloat, y: CGFloat) {
    var vx: CGFloat = 0, vy: CGFloat = 0, vz: CGFloat = 500
    var cx: CGFloat = 200, cy: CGFloat = 0
    let dt = 1 / hz
    var t: CGFloat = 0, x: CGFloat = 0, y: CGFloat = 0
    while t < seconds - 1e-9 {
        CourtMath.applyCurveStep(vx: &vx, vy: &vy, vz: &vz,
                                 curveX: &cx, curveY: &cy,
                                 dt: dt, curveDecayPerSecond: decay, minVzFraction: minVz)
        x += vx * dt
        y += vy * dt
        t += dt
    }
    return (x, y)
}
let d60 = integrateDeflection(hz: 60, seconds: 1.0)
let d120 = integrateDeflection(hz: 120, seconds: 1.0)
check("60Hz vs 120Hz lateral X within 2%",
      nearlyEqual(d60.x, d120.x, tol: max(2, abs(d60.x) * 0.02)),
      detail: "60=\(d60.x) 120=\(d120.x)")
// ProMotion matters on Brooks's 16 Pro Max: also check 120 vs 30.
let d30 = integrateDeflection(hz: 30, seconds: 1.0)
check("30Hz vs 120Hz lateral X within 4%",
      nearlyEqual(d30.x, d120.x, tol: max(2, abs(d120.x) * 0.04)),
      detail: "30=\(d30.x) 120=\(d120.x)")

// 2. Total speed preserved across a curve step (curve bends, never accelerates).
print("\n2) Speed preserved across curve step")
do {
    var vx: CGFloat = 100, vy: CGFloat = 50, vz: CGFloat = 400
    var cx: CGFloat = 300, cy: CGFloat = -100
    let before = sqrt(vx * vx + vy * vy + vz * vz)
    CourtMath.applyCurveStep(vx: &vx, vy: &vy, vz: &vz, curveX: &cx, curveY: &cy,
                             dt: 1.0 / 60, curveDecayPerSecond: decay, minVzFraction: minVz)
    let after = sqrt(vx * vx + vy * vy + vz * vz)
    check("speed before == after", nearlyEqual(before, after, tol: 0.05),
          detail: "before=\(before) after=\(after)")
}

// 3. minVzFraction never violated after curve.
print("\n3) minVzFraction after curve")
do {
    var vx: CGFloat = 300, vy: CGFloat = 300, vz: CGFloat = 100
    var cx: CGFloat = 500, cy: CGFloat = 500
    let speed = sqrt(vx * vx + vy * vy + vz * vz)
    CourtMath.renormVelocity(vx: &vx, vy: &vy, vz: &vz, speed: speed, minVzFraction: minVz)
    CourtMath.applyCurveStep(vx: &vx, vy: &vy, vz: &vz, curveX: &cx, curveY: &cy,
                             dt: 1.0 / 30, curveDecayPerSecond: decay, minVzFraction: minVz)
    let s = sqrt(vx * vx + vy * vy + vz * vz)
    check("|vz| >= minVzFraction * speed", abs(vz) + 0.01 >= minVz * s,
          detail: "|vz|=\(abs(vz)) need>=\(minVz * s)")
}

// 4. Curve magnitude never exceeds curveMax — including via the paddle-velocity
//    entry point, which is how curve is actually created in the game.
print("\n4) curveMax clamp")
do {
    var cx: CGFloat = 2000, cy: CGFloat = 1500
    CourtMath.clampCurve(curveX: &cx, curveY: &cy, maxMag: curveMax)
    check("hypot(curve) <= curveMax", hypot(cx, cy) <= curveMax + 0.01,
          detail: "mag=\(hypot(cx, cy))")

    let (px, py) = CourtMath.curveFromPaddleVelocity(
        paddleVelX: 99999, paddleVelY: 99999,
        scale: Config.curveFromPaddleVel, maxMag: curveMax)
    check("absurd paddle velocity still clamped", hypot(px, py) <= curveMax + 0.01,
          detail: "mag=\(hypot(px, py))")
}

// 5. Wall bounce inverts curve on the reflected axis and damps.
print("\n5) Wall bounce curve flip + damp")
do {
    var cx: CGFloat = 100, cy: CGFloat = 80
    CourtMath.wallBounceCurve(curveX: &cx, curveY: &cy, flipX: true, flipY: false, damp: wallDamp)
    check("X flipped and damped", nearlyEqual(cx, -100 * wallDamp, tol: 0.01), detail: "cx=\(cx)")
    check("Y only damped", nearlyEqual(cy, 80 * wallDamp, tol: 0.01), detail: "cy=\(cy)")
}

// 6. Each score bonus degrades to exactly 0 and never goes negative.
print("\n6) Bonus degrade floors at 0")
do {
    var b = ScoreBonuses.fresh(hit: Config.hitScoreStart, curve: Config.curveBonusStart,
                               superCurve: Config.superCurveBonusStart,
                               accuracy: Config.accuracyBonusStart,
                               levelClear: Config.levelClearBonusStart)
    var hits = 0
    while b.hitScore > 0 && hits < 500 {
        _ = b.awardHit(degrade: Config.hitScoreDegrade)
        hits += 1
    }
    check("hitScore reaches 0", b.hitScore == 0)
    _ = b.awardHit(degrade: Config.hitScoreDegrade)
    check("hitScore stays non-negative", b.hitScore >= 0)

    for _ in 0..<500 { _ = b.awardCurve(degrade: Config.curveBonusDegrade) }
    check("curveBonus == 0", b.curveBonus == 0)
    for _ in 0..<500 { _ = b.awardSuperCurve(degrade: Config.superCurveBonusDegrade) }
    check("superCurveBonus == 0", b.superCurveBonus == 0)
    for _ in 0..<500 { _ = b.awardAccuracy(degrade: Config.accuracyBonusDegrade) }
    check("accuracyBonus == 0", b.accuracyBonus == 0)

    // Level-clear bank must also floor rather than run negative.
    for _ in 0..<10_000 { b.tickLevelClear(dt: 1.0 / 60, decayPerSecond: Config.levelClearDecayPerSecond) }
    check("levelClearBonus floors at 0", b.levelClearBonus == 0, detail: "\(b.levelClearBonus)")
}

// 7. Bonuses reset to start values on life loss.
print("\n7) Reset on life loss")
do {
    var b = ScoreBonuses.fresh(hit: Config.hitScoreStart, curve: Config.curveBonusStart,
                               superCurve: Config.superCurveBonusStart,
                               accuracy: Config.accuracyBonusStart,
                               levelClear: Config.levelClearBonusStart)
    for _ in 0..<5 {
        _ = b.awardHit(degrade: Config.hitScoreDegrade)
        _ = b.awardCurve(degrade: Config.curveBonusDegrade)
        _ = b.awardSuperCurve(degrade: Config.superCurveBonusDegrade)
        _ = b.awardAccuracy(degrade: Config.accuracyBonusDegrade)
    }
    check("pre-reset hit degraded", b.hitScore < Config.hitScoreStart)
    b.reset(hit: Config.hitScoreStart, curve: Config.curveBonusStart,
            superCurve: Config.superCurveBonusStart, accuracy: Config.accuracyBonusStart,
            levelClear: Config.levelClearBonusStart)
    check("hitScore reset", b.hitScore == Config.hitScoreStart)
    check("curveBonus reset", b.curveBonus == Config.curveBonusStart)
    check("superCurveBonus reset", b.superCurveBonus == Config.superCurveBonusStart)
    check("accuracyBonus reset", b.accuracyBonus == Config.accuracyBonusStart)
    check("levelClearBonus reset", b.levelClearBonus == Config.levelClearBonusStart)
}

// 8. Rally start: centre spawn, direction follows the previous point's winner.
print("\n8) Rally start (v1.6)")
do {
    let z = CourtMath.rallyStartZ(zFar: Config.zFar, fraction: Config.rallyStartZFraction)
    check("starts at tunnel centre", nearlyEqual(z, Config.zFar / 2, tol: 0.001),
          detail: "z=\(z) zFar=\(Config.zFar)")
    check("centre is strictly between both planes", z > 0 && z < Config.zFar)

    // Sign convention: player plane is z = 0, so toward the player is negative.
    check("toward player is negative vz",
          CourtMath.rallyLaunchVz(magnitude: 500, towardPlayer: true) < 0)
    check("toward opponent is positive vz",
          CourtMath.rallyLaunchVz(magnitude: 500, towardPlayer: false) > 0)
    check("magnitude preserved either way",
          abs(CourtMath.rallyLaunchVz(magnitude: 500, towardPlayer: true)) == 500 &&
          abs(CourtMath.rallyLaunchVz(magnitude: 500, towardPlayer: false)) == 500)
    // A negative magnitude must not silently flip the direction.
    check("negative magnitude still goes toward player",
          CourtMath.rallyLaunchVz(magnitude: -500, towardPlayer: true) < 0)

    check("winner of last point gets first touch — player won",
          CourtMath.firstTouchGoesToPlayer(playerWonLastPoint: true))
    check("winner of last point gets first touch — player lost",
          !CourtMath.firstTouchGoesToPlayer(playerWonLastPoint: false))
}

// D2 — AI lateral safety ceiling, computed from real Config endpoints.
print("\n--- D2 aiLateralFrac ceiling (real Config) ---")
print("LVL  rawAI  latFrac  ceiling  binds?")
var anyBinds = false
for level in 1...Config.maxLevel {
    let t = Config.difficultyT(level)
    let raw = Config.lerp(Config.aiSpeedL1, Config.aiSpeedL10, t)
    let frac = Config.lerp(Config.aiLateralFracL1, Config.aiLateralFracL10, t)
    let ballSp = Config.lerp(Config.ballSpeedL1, Config.ballSpeedL10, t)
    let latMax = ballSp * sqrt(max(0, 1 - Config.minVzFraction * Config.minVzFraction))
    let ceiling = latMax * frac
    let binds = raw > ceiling + 0.01
    if binds { anyBinds = true }
    print(String(format: " %2d  %6.1f  %7.2f  %7.1f  %@",
                 level, raw, frac, ceiling, binds ? "YES" : "no"))
}
check("aiLateralFrac ceiling never binds (safety cap, not a skill dial)", !anyBinds)

print("\n=== \(passes) passed, \(failures) failed ===")
exit(failures == 0 ? 0 : 1)
