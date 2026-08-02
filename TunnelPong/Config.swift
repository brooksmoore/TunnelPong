import SpriteKit

/// Every tunable number in the game lives here. Tweak these, nowhere else.
struct Config {

    // MARK: - Perspective
    /// Perspective strength. Lower = more dramatic depth distortion.
    /// 280 makes near/far ball size read more clearly than 320.
    static let focal: CGFloat = 280
    /// Depth of the opponent's paddle plane. The player's plane is z = 0.
    static let zFar: CGFloat = 900

    // MARK: - Court (fractions of the screen at the near plane, z = 0)
    static let courtWidthFactor: CGFloat = 0.92
    static let courtHeightFactor: CGFloat = 0.72

    // MARK: - Tunnel look
    static let ringCount: Int = 13
    /// 0 = hard square corners. The tunnel should read as cut, not extruded.
    static let ringCornerRadius: CGFloat = 0
    static let ringLineWidthNear: CGFloat = 2.0
    static let ringLineWidthFar: CGFloat = 0.7
    static let ringAlphaNear: CGFloat = 0.50
    static let ringAlphaFar: CGFloat = 0.14
    static let cornerLineAlpha: CGFloat = 0.22

    // MARK: - Ball (constants that do not ramp)
    /// World-space radius (also base on-screen size at z = 0).
    static let ballRadius: CGFloat = 26
    /// Extra multiplier on rendered ball scale (physics radius unchanged).
    static let ballDrawScale: CGFloat = 1.08
    /// Extra english when the paddle *corner* is on the ball at serve (0–1 scale).
    static let serveCornerBoost: CGFloat = 0.40
    /// Minimum share of total speed kept along z, so the ball can't stall
    /// bouncing sideways after heavy english.
    static let minVzFraction: CGFloat = 0.55
    /// Absolute ceiling (safety). L10 endpoints stay under this.
    static let ballMaxSpeed: CGFloat = 1200
    /// Where opponent auto-serves spawn, as a fraction of zFar.
    static let serveZFraction: CGFloat = 0.55
    /// Player serve parks slightly in front of the near plane.
    static let playerServeZ: CGFloat = 40
    /// Pause before opponent auto-serve launches, seconds.
    static let serveDelay: CGFloat = 0.75
    /// Hold the ball on the plane after a point, then resolve lives/score.
    static let pointFreezeDuration: CGFloat = 0.65

    // MARK: - Player paddle (full capability always — does not ramp)
    static let playerPaddleHalfW: CGFloat = 72
    static let playerPaddleHalfH: CGFloat = 52
    static let paddleHitSlop: CGFloat = 14
    static let touchOffsetY: CGFloat = 95

    // MARK: - Opponent size (fixed; skill ramps below)
    static let oppPaddleHalfW: CGFloat = 48
    static let oppPaddleHalfH: CGFloat = 36

    // MARK: - 10-level linear difficulty
    //
    // Your model, cleaned up: each ramping variable has an L1 (calibrated) and
    // L10 (brutal) endpoint. Progress is linear in level:
    //
    //     t = (level - 1) / 9     // 0 at L1, 1 at L10
    //     value = lerp(L1, L10, t)
    //
    // Player paddle never appears here. AI XY is also hard-capped as a
    // fraction of the ball's max lateral component so L10 is hard, not
    // mathematically unwinnable.

    /// Difficulty ceiling, NOT an ending. Play is endless: levels keep counting
    /// up (LV 11, 12, …) but every ramping value clamps at its L10 endpoint.
    /// This is the "as hard as it gets without being impossible" line.
    static let maxLevel = 10

    /// 0 at level 1 → 1 at level 10 (clamped).
    static func difficultyT(_ level: Int) -> CGFloat {
        let L = max(1, min(level, maxLevel))
        return CGFloat(L - 1) / CGFloat(maxLevel - 1)
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    // Ball total speed (mostly Z travel; lateral share constrained by minVzFraction)
    static let ballSpeedL1: CGFloat = 460
    static let ballSpeedL10: CGFloat = 980
    // Per-hit rally add within a point
    static let rallyIncL1: CGFloat = 5
    static let rallyIncL10: CGFloat = 16
    // Off-center english / spin bite
    static let englishL1: CGFloat = 0.22
    static let englishL10: CGFloat = 0.42
    // Serve drag spin magnitude
    static let serveDragL1: CGFloat = 180
    static let serveDragL10: CGFloat = 340

    // AI paddle move speed. THIS is the dial that actually governs AI reach —
    // at current numbers it is always the binding constraint (95→500 sits well
    // under the lateral ceiling below at every level). Tune these.
    static let aiSpeedL1: CGFloat = 95
    static let aiSpeedL10: CGFloat = 500
    /// Safety ceiling only: caps AI XY at a fraction of the ball's max lateral
    /// speed so the opponent can never be mathematically un-passable. Inert at
    /// the aiSpeed values above (never binds) — it exists so that raising
    /// aiSpeedL10 later can't accidentally create an unbeatable wall.
    /// Kept below 1.0 on purpose: the ball must always be able to out-run it.
    static let aiLateralFracL1: CGFloat = 0.42
    static let aiLateralFracL10: CGFloat = 0.94
    // Aim error (world units). High early → sparse late.
    static let aiErrorL1: CGFloat = 110
    static let aiErrorL10: CGFloat = 12
    // Reaction delay after ball turns outbound (seconds)
    static let aiReactionL1: CGFloat = 0.58
    static let aiReactionL10: CGFloat = 0.10
    // Idle recentre rate while ball is inbound
    static let aiIdleL1: CGFloat = 0.22
    static let aiIdleL10: CGFloat = 0.55

    // MARK: - Rules
    //
    // Lives are *spare* lives — the hearts in the HUD are what you have left
    // over. At 0 hearts you are playing your last life; the next miss ends the
    // run. So 3 hearts = 4 total misses.
    //
    /// Spare lives at the start of a run.
    static let playerLives = 3
    /// Hard cap on spares. Clearing a level grants one back, but only up to
    /// this — you can't bank lives you never lost.
    static let playerLivesMax = 3
    /// Spare lives granted for clearing a level (capped by playerLivesMax).
    static let lifeGainPerLevel = 1
    static let opponentLivesPerLevel = 3
    static let scorePerHit = 10
    static let scorePerOpponentLife = 100

    // MARK: - Flow
    static let levelTransitionDuration: CGFloat = 1.4

    // MARK: - Layout / safe area
    /// Extra pad below the safe-area top (notch / Dynamic Island / Mac titlebar).
    static let hudTopPad: CGFloat = 14
    static let hudBottomPad: CGFloat = 14
    /// Mac Catalyst titlebar eats the top of the content view; treat as min top inset.
    static let macTitlebarInset: CGFloat = 40

    // MARK: - Type (procedural 5×7 pixel font — see PixelFont.swift)
    /// Blank columns between glyphs, in blocks. Wider reads more deliberate.
    static let titleTracking: CGFloat = 2
    static let hudTracking: CGFloat = 1.6

    // MARK: - Retrowave palette
    //
    // Reference: black sky falling through indigo → violet → magenta to a hot
    // pink horizon, near-black silhouettes, one white moon. Screen stays
    // majority black. Only THREE things carry color, so the eye never hunts:
    //   you = white · opponent = magenta · ball = neon orange.

    /// You — moon white, faintly lavender. Always the brightest thing near you.
    static let playerColor   = SKColor(red: 0.94, green: 0.92, blue: 1.00, alpha: 1)
    /// AI — hot magenta, sitting far down the tunnel against deep violet.
    static let opponentColor = SKColor(red: 1.00, green: 0.18, blue: 0.49, alpha: 1)
    /// Ball — neon orange. The one warm object in a cool frame.
    static let ballColor     = SKColor(red: 1.00, green: 0.48, blue: 0.09, alpha: 1)
    static let ballStrokeColor = SKColor(red: 1.00, green: 0.72, blue: 0.24, alpha: 1)
    static let ballCoreColor = SKColor(red: 1.00, green: 0.88, blue: 0.62, alpha: 1)
    /// Tunnel wire — violet, dim, never competing with the three actors.
    static let ringColor     = SKColor(red: 0.62, green: 0.36, blue: 0.98, alpha: 1)
    /// HUD text — soft lavender white.
    static let hudColor      = SKColor(red: 0.86, green: 0.80, blue: 0.96, alpha: 1)
    /// Title accent / hot pink horizon line.
    static let titleAccent   = SKColor(red: 1.00, green: 0.36, blue: 0.55, alpha: 1)

    // MARK: - Tunnel gradient
    //
    // The wireframe runs a colour ramp down its length, echoing the reference
    // sunset: hot pink where the wall is closest, falling through magenta and
    // violet to deep indigo at the vanishing point. Depth reads as colour, not
    // just as fade.
    static let wallNear = SKColor(red: 1.00, green: 0.40, blue: 0.52, alpha: 1)
    static let wallMid1 = SKColor(red: 0.91, green: 0.26, blue: 0.55, alpha: 1)
    static let wallMid2 = SKColor(red: 0.58, green: 0.22, blue: 0.72, alpha: 1)
    static let wallMid3 = SKColor(red: 0.34, green: 0.16, blue: 0.62, alpha: 1)
    static let wallFar  = SKColor(red: 0.16, green: 0.09, blue: 0.38, alpha: 1)

    /// Colour of the tunnel wall at depth `t` (0 = near plane, 1 = far).
    static func wallColor(_ t: CGFloat) -> SKColor {
        let stops = [wallNear, wallMid1, wallMid2, wallMid3, wallFar]
        let clamped = max(0, min(1, t))
        let scaled = clamped * CGFloat(stops.count - 1)
        let i = min(Int(scaled), stops.count - 2)
        return blend(stops[i], stops[i + 1], scaled - CGFloat(i))
    }

    static func blend(_ a: SKColor, _ b: SKColor, _ t: CGFloat) -> SKColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return SKColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t,
                       blue: ab + (bb - ab) * t, alpha: aa + (ba - aa) * t)
    }

    // MARK: - CRT scanlines
    /// Horizontal line overlay. Subtle texture, not a gimmick — keep it low.
    static let scanlineAlpha: CGFloat = 0.16
    /// Points between lines (line is 1pt of that span).
    static let scanlineSpacing: CGFloat = 3

    // MARK: - Ball spin
    /// Radians of roll per point of lateral travel, scaled. Higher = spinnier.
    static let ballSpinFactor: CGFloat = 0.85

    // MARK: - Starfield
    //
    // The background is pure black. The only thing in it is a scatter of
    // distant white stars — texture, never colour.
    static let starCount = 110
    static let starMinRadius: CGFloat = 0.5
    static let starMaxRadius: CGFloat = 1.5
    static let starMinAlpha: CGFloat = 0.18
    static let starMaxAlpha: CGFloat = 0.85
    static let starColor = SKColor.white

    // MARK: - Impact glow
    /// Paddles are hairline rects that bloom when the ball strikes them.
    static let paddleCornerRadius: CGFloat = 14
    /// Halo thickness on the glow layer that sits under each paddle.
    static let paddleGlowWidth: CGFloat = 18
    static let paddleGlowLineWidth: CGFloat = 4
    /// Rise and fall of the strike bloom, seconds.
    static let paddleGlowUp: CGFloat = 0.05
    static let paddleGlowDown: CGFloat = 0.28
    /// How far the halo swells past the paddle at peak.
    static let paddleGlowScale: CGFloat = 1.10
}
