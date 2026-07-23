import SpriteKit

/// Every tunable number in the game lives here. Tweak these, nowhere else.
struct Config {

    // MARK: - Perspective
    /// Perspective strength. Lower = more dramatic depth distortion.
    static let focal: CGFloat = 320
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
    static let ringAlphaNear: CGFloat = 0.42
    static let ringAlphaFar: CGFloat = 0.10
    static let cornerLineAlpha: CGFloat = 0.14

    // MARK: - Ball
    static let ballRadius: CGFloat = 11
    /// Level-1 ball speed, in world units per second.
    static let ballBaseSpeed: CGFloat = 620
    /// Fractional speed gain per level (+12% per level).
    static let ballSpeedPerLevel: CGFloat = 0.12
    /// Flat speed added on every successful player hit within a rally.
    static let ballRallyIncrement: CGFloat = 9
    /// Hard cap. Keep this at a speed the paddle can actually reach.
    static let ballMaxSpeed: CGFloat = 1500
    /// Minimum share of total speed kept along z, so the ball can't stall
    /// bouncing sideways after heavy english.
    static let minVzFraction: CGFloat = 0.55
    /// How much an off-center paddle hit tilts the return. Keep subtle.
    static let englishMultiplier: CGFloat = 0.16
    /// Where serves spawn, as a fraction of zFar.
    static let serveZFraction: CGFloat = 0.45
    /// Pause before each serve launches, seconds.
    static let serveDelay: CGFloat = 0.9
    /// How far past a paddle plane the ball flies before the miss registers.
    static let missDepthNear: CGFloat = 130
    static let missDepthFar: CGFloat = 160

    // MARK: - Player paddle
    static let playerPaddleHalfW: CGFloat = 62
    static let playerPaddleHalfH: CGFloat = 44
    /// Follow rate toward the finger. Higher = snappier, lower = floatier.
    static let paddleSmoothing: CGFloat = 14
    /// The paddle rides this many points above the finger so the thumb
    /// doesn't cover the play area.
    static let touchOffsetY: CGFloat = 95

    // MARK: - Opponent
    static let oppPaddleHalfW: CGFloat = 50
    static let oppPaddleHalfH: CGFloat = 38
    /// Opponent max travel speed at level 1, world units/second.
    static let aiBaseSpeed: CGFloat = 240
    /// Fractional speed gain per level.
    static let aiSpeedPerLevel: CGFloat = 0.16
    static let aiMaxSpeed: CGFloat = 760
    /// Seconds after the ball turns outbound before the AI starts tracking.
    static let aiReactionDelay: CGFloat = 0.28
    /// Aim error amplitude at level 1 (world units). Bigger = more misses.
    static let aiErrorBase: CGFloat = 46
    /// Error multiplier applied per level (0.80 = 20% more accurate each level).
    static let aiErrorDecayPerLevel: CGFloat = 0.80
    /// Recentring speed factor while the ball is inbound (not "reacting").
    static let aiIdleSpeedFactor: CGFloat = 0.35

    // MARK: - Rules
    static let playerLives = 3
    static let opponentLivesPerLevel = 3
    /// Grant the player an extra life every N levels. 0 = off (default).
    static let extraLifeEveryNLevels = 0
    static let scorePerHit = 10
    static let scorePerOpponentLife = 100

    // MARK: - Flow
    static let levelTransitionDuration: CGFloat = 1.4

    // MARK: - Colors
    static let playerColor   = SKColor(red: 0.55, green: 0.95, blue: 1.00, alpha: 1)
    static let opponentColor = SKColor(red: 0.80, green: 0.62, blue: 1.00, alpha: 1)
    static let ballColor     = SKColor.white
    static let ringColor     = SKColor(red: 0.60, green: 0.85, blue: 1.00, alpha: 1)
    static let hudColor      = SKColor(red: 0.75, green: 0.90, blue: 1.00, alpha: 1)
}
