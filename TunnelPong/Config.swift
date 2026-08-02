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
    /// Hit-test padding around the ball in screen points (serve strike).
    static let serveBallHitPad: CGFloat = 22
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
    static let paddleSmoothing: CGFloat = 999
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

    /// Final campaign level. Clearing it wins the run.
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

    // AI absolute move speed (secondary; lateral fraction is the real leash)
    static let aiSpeedL1: CGFloat = 95
    static let aiSpeedL10: CGFloat = 500
    /// AI XY as fraction of ball max lateral speed. L10 ≈ ball XY but not 1.0.
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
    static let playerLives = 3
    static let opponentLivesPerLevel = 3
    static let extraLifeEveryNLevels = 0
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

    // MARK: - Type (cyberpunk / condensed geometric)
    /// System fonts that read synthwave without bundling assets.
    static let fontTitle = "AvenirNextCondensed-Bold"
    static let fontBody  = "AvenirNext-DemiBold"
    static let fontHUD   = "AvenirNextCondensed-Medium"

    // MARK: - Retrowave palette (c1/c2/c3: magenta grid, cyan neon, sunset ball)
    // Screen stays majority black; neon only on entities + tunnel wireframe.
    /// You — electric cyan (c2 neon buildings).
    static let playerColor   = SKColor(red: 0.00, green: 0.95, blue: 1.00, alpha: 1)
    /// AI — hot magenta / purple (c1 grid / c3 peaks).
    static let opponentColor = SKColor(red: 1.00, green: 0.20, blue: 0.75, alpha: 1)
    /// Ball — sunset orange→gold (c1/c2 sun).
    static let ballColor     = SKColor(red: 1.00, green: 0.55, blue: 0.12, alpha: 1)
    static let ballStrokeColor = SKColor(red: 1.00, green: 0.28, blue: 0.35, alpha: 1)
    /// Tunnel walls — dim violet wire (mountains/grid, not paddle cyan).
    static let ringColor     = SKColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 1)
    /// HUD text — soft pink-white.
    static let hudColor      = SKColor(red: 0.95, green: 0.80, blue: 0.95, alpha: 1)
    /// Title accent (second word / glow).
    static let titleAccent   = SKColor(red: 1.00, green: 0.35, blue: 0.70, alpha: 1)

    // MARK: - Impact flash
    /// Paddle alpha dips to this on strike, then recovers.
    static let paddleHitAlpha: CGFloat = 0.12
    static let paddleHitFlashDown: CGFloat = 0.04
    static let paddleHitFlashUp: CGFloat = 0.16
}
