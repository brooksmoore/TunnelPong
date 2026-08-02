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
    static let ringCornerRadius: CGFloat = 30
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

    // MARK: - Type (thin, geometric, wide-tracked)
    // Sleek and symmetrical — the letterforms should feel drawn with a single
    // hairline. Tracking (see *Tracking below) does most of the work.
    static let fontTitle = "AvenirNext-UltraLight"
    static let fontBody  = "Avenir-Light"
    static let fontHUD   = "Avenir-Light"
    /// Extra letter-spacing, in points, applied via attributed text.
    static let titleTracking: CGFloat = 14
    static let hudTracking: CGFloat = 3.2

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

    // MARK: - Sky (vertical gradient, black at top → hot pink at the horizon)
    static let skyTop     = SKColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1)
    static let skyHigh    = SKColor(red: 0.07, green: 0.03, blue: 0.17, alpha: 1)
    static let skyMid     = SKColor(red: 0.23, green: 0.11, blue: 0.42, alpha: 1)
    static let skyLow     = SKColor(red: 0.56, green: 0.18, blue: 0.62, alpha: 1)
    static let skyGlow    = SKColor(red: 0.91, green: 0.26, blue: 0.50, alpha: 1)
    static let skyHot     = SKColor(red: 1.00, green: 0.40, blue: 0.49, alpha: 1)
    /// Where the horizon sits, as a fraction of screen height from the bottom.
    static let horizonFrac: CGFloat = 0.085
    /// Silhouette peaks — effectively black, like the reference.
    static let mountainColor = SKColor(red: 0.02, green: 0.01, blue: 0.04, alpha: 1)
    /// Tallest peak height as a fraction of screen height.
    static let mountainHeightFrac: CGFloat = 0.20
    static let moonColor = SKColor.white
    static let moonRadius: CGFloat = 13
    /// Thin tapering diagonals (the reference's speed streaks).
    static let streakColor = SKColor(red: 1.00, green: 0.24, blue: 0.43, alpha: 1)
    static let streakAlpha: CGFloat = 0.30

    // MARK: - Impact flash
    /// Paddle alpha dips to this on strike, then recovers.
    static let paddleHitAlpha: CGFloat = 0.12
    static let paddleHitFlashDown: CGFloat = 0.04
    static let paddleHitFlashUp: CGFloat = 0.16
}
