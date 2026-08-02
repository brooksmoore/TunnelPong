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
    // Near ring fills the view horizontally so the shaft reads edge-to-edge.
    static let courtWidthFactor: CGFloat = 1.02
    /// Share of the *safe* vertical band the court occupies. The band is
    /// measured between the safe-area top and bottom (see applyChromeLayout),
    /// so the top wall always clears the notch / Dynamic Island.
    static let courtHeightFactor: CGFloat = 1.0
    /// Gap between the safe-area top and the court's top wall.
    static let courtTopPad: CGFloat = 12
    static let courtBottomPad: CGFloat = 8

    // MARK: - Pixel grid (modern GBC)
    //
    // Everything snaps to this grid. Depth and motion stay continuous in
    // physics; only the *picture* is discrete — that's the "beautiful 8-bit"
    // trick (Celeste / modern GBC homebrew), not a blurry CRT filter.
    /// Logical pixel size in points. 3 ≈ GBC-on-phone scale on modern screens.
    static let pixel: CGFloat = 3
    /// Snap a point-space value to the pixel grid.
    static func snap(_ v: CGFloat) -> CGFloat {
        (v / pixel).rounded() * pixel
    }
    static func snapPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: snap(p.x), y: snap(p.y))
    }
    /// Discrete spin steps so the ball "ticks" like sprite frames.
    static let ballSpinSteps: CGFloat = 16

    // MARK: - Tunnel look
    // Transparent walls: only evenly spaced single strokes + corner rails.
    // Evenly spaced depth rings (every-other of the denser lattice).
    static let ringCount: Int = 9
    /// Corner radius as a fraction of court width, matched to the iPhone's own
    /// screen corner (~0.125 of width ≈ 55pt on a 440pt display) so the tunnel
    /// mouth echoes the device it's running on.
    static let ringCornerFrac: CGFloat = 0.125
    /// Ceiling as a share of the ring's smaller half-dimension — keeps distant
    /// rings rounded rects instead of collapsing them into discs.
    static let ringCornerCap: CGFloat = 0.32
    /// 2pt hard stroke — thick enough to read as 8-bit, not a hairline.
    static let ringLineWidthNear: CGFloat = 2
    static let ringLineWidthFar: CGFloat = 2
    /// Depth (z-axis) corner rails — thinner than depth rings.
    static let railLineWidth: CGFloat = 1
    static let ringAlphaNear: CGFloat = 0.88
    /// Far rings stay open wireframe (low alpha), never a solid disc.
    static let ringAlphaFar: CGFloat = 0.42
    static let cornerLineAlpha: CGFloat = 0.90
    /// Always draw the far-plane ring so corner rails meet a real end frame.
    static let ringSkipFarPlane = false
    /// Hit flash: ring pops to this colour then settles back to neon pink.
    static let ringHitColor = SKColor(red: 1.00, green: 0.85, blue: 0.95, alpha: 1)
    static let ringHitUp: CGFloat = 0.04
    static let ringHitDown: CGFloat = 0.28

    // MARK: - Ball (constants that do not ramp)
    /// World-space radius (also base on-screen size at z = 0).
    static let ballRadius: CGFloat = 24
    /// Extra multiplier on rendered ball scale (physics radius unchanged).
    static let ballDrawScale: CGFloat = 1.0
    /// Extra english when the paddle *corner* is on the ball at serve (0–1 scale).
    static let serveCornerBoost: CGFloat = 0.55
    /// Minimum share of total speed kept along z, so the ball can't stall
    /// bouncing sideways after heavy english. Slightly lower = more lateral room
    /// for spin to read without killing depth travel.
    static let minVzFraction: CGFloat = 0.48
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
    /// Minimum thumb travel (screen points, per frame) that counts as a serve
    /// sweep rather than fine paddle positioning.
    static let serveSwipeMin: CGFloat = 6
    /// iOS relative-drag amplification. The paddle moves this many times
    /// further than your thumb, so the whole court is reachable one-handed
    /// without stretching. 1.0 would be literal 1:1 dragging.
    static let touchGain: CGFloat = 2.3

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
    // Off-center english / spin bite (stronger so contact placement reads).
    static let englishL1: CGFloat = 0.38
    static let englishL10: CGFloat = 0.62
    // Serve drag spin magnitude (drag-to-meet should clearly steer the ball).
    static let serveDragL1: CGFloat = 320
    static let serveDragL10: CGFloat = 560

    // AI: pure ball tracking. Difficulty = linear tracking speed only.
    //   L1  — slow enough that casual angles score freely
    //   L10 — hard but beatable with strong English / corners
    // 2026-08-02: raised ×2 after mid/late still too easy (base was 48→245).
    static let aiSpeedL1: CGFloat = 96
    static let aiSpeedL10: CGFloat = 490
    /// Safety ceiling only — not a skill dial.
    static let aiLateralFracL1: CGFloat = 0.35
    static let aiLateralFracL10: CGFloat = 0.72

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
    /// Pad under the Dynamic Island / safe top for level + score (hearts sit higher).
    static let hudTopPad: CGFloat = 6
    static let hudBottomPad: CGFloat = 10
    /// Mac Catalyst titlebar eats the top of the content view; treat as min top inset.
    static let macTitlebarInset: CGFloat = 40
    /// Vertical gap between LV and score under the island.
    static let hudScoreGap: CGFloat = 20
    /// Drop from the court's top wall down to the LV readout, so the HUD sits
    /// inside the tunnel rather than on the wall line.
    static let hudTopGap: CGFloat = 22

    // MARK: - Type (procedural 5×7 pixel font — r1 chrome/neon title style)
    /// Blank columns between glyphs, in blocks. Tight like OVERDRIVE lettering.
    static let titleTracking: CGFloat = 0.5
    static let hudTracking: CGFloat = 1
    /// Drop-shadow offset in blocks (classic 8-bit title depth).
    static let titleShadowBlocks: CGFloat = 1
    /// Title chrome: pink (top) → mid magenta-cyan → cyan (bottom).
    static let titleChromeTop = SKColor(red: 1.00, green: 0.42, blue: 0.68, alpha: 1)
    static let titleChromeMid = SKColor(red: 0.72, green: 0.55, blue: 0.95, alpha: 1)
    static let titleChromeBot = SKColor(red: 0.35, green: 0.92, blue: 1.00, alpha: 1)
    static let titleNeonGlow  = SKColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1)

    // MARK: - GBC palette (from Desktop/c3.png, quantized for modern Game Boy Color)
    //
    // c3: black zenith → indigo → violet → magenta → hot pink horizon,
    // black peak silhouettes with pink ridges, white crescent. Actors use
    // a tiny set so the eye never hunts — GBC-style discipline, modern taste.

    /// You — cyan blue (paddle + hearts).
    static let playerColor   = SKColor(red: 0.20, green: 0.92, blue: 1.00, alpha: 1)
    /// AI — hot magenta (c3 ridge / horizon).
    static let opponentColor = SKColor(red: 1.00, green: 0.22, blue: 0.52, alpha: 1)
    /// Ball — warm peach-orange (one warm note in a cool frame).
    static let ballColor     = SKColor(red: 1.00, green: 0.55, blue: 0.18, alpha: 1)
    static let ballStrokeColor = SKColor(red: 1.00, green: 0.82, blue: 0.40, alpha: 1)
    static let ballCoreColor = SKColor(red: 1.00, green: 0.94, blue: 0.72, alpha: 1)
    static let ballShadeColor = SKColor(red: 0.72, green: 0.22, blue: 0.12, alpha: 1)
    /// HUD text — pale lavender (readable on pink sky).
    static let hudColor      = SKColor(red: 0.90, green: 0.86, blue: 0.98, alpha: 1)
    /// Title accent — c3 horizon pink.
    static let titleAccent   = SKColor(red: 1.00, green: 0.32, blue: 0.55, alpha: 1)
    /// Shadow under pixel type.
    static let typeShadowColor = SKColor(red: 0.08, green: 0.02, blue: 0.14, alpha: 1)

    // MARK: - Sky bands (top → bottom). Mostly black + purple; pink only a
    // faint sliver at the very bottom (lowered vs earlier passes).
    static let sky0 = SKColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1)  // black
    static let sky1 = SKColor(red: 0.01, green: 0.00, blue: 0.03, alpha: 1)  // near-black
    static let sky2 = SKColor(red: 0.05, green: 0.02, blue: 0.12, alpha: 1)  // deep indigo
    static let sky3 = SKColor(red: 0.10, green: 0.03, blue: 0.20, alpha: 1)  // dark purple
    static let sky4 = SKColor(red: 0.16, green: 0.05, blue: 0.28, alpha: 1)  // purple
    static let sky5 = SKColor(red: 0.22, green: 0.06, blue: 0.34, alpha: 1)  // mid purple
    static let sky6 = SKColor(red: 0.30, green: 0.08, blue: 0.40, alpha: 1)  // violet
    static let sky7 = SKColor(red: 0.42, green: 0.10, blue: 0.42, alpha: 1)  // purple-magenta
    static let sky8 = SKColor(red: 0.72, green: 0.18, blue: 0.48, alpha: 1)  // muted rose (thin base)
    static let groundColor = SKColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1)
    static let moonColor = SKColor(red: 0.96, green: 0.96, blue: 1.00, alpha: 1)
    static let ridgeColor = SKColor(red: 1.00, green: 0.35, blue: 0.55, alpha: 1)
    static let streakColor = SKColor(red: 1.00, green: 0.40, blue: 0.62, alpha: 1)

    // MARK: - Tunnel wire — one neon pink for every spaced line
    static let wallNeonPink = SKColor(red: 1.00, green: 0.28, blue: 0.58, alpha: 1)
    static let wallNear = wallNeonPink
    static let wallMid1 = wallNeonPink
    static let wallMid2 = wallNeonPink
    static let wallMid3 = wallNeonPink
    static let wallFar  = wallNeonPink

    /// Every tunnel stroke is the same neon pink (depth is spacing, not colour).
    static func wallColor(_ t: CGFloat) -> SKColor {
        _ = t
        return wallNeonPink
    }

    /// Soft blend only for baked sky bands (still quantized by band height).
    static func blend(_ a: SKColor, _ b: SKColor, _ t: CGFloat) -> SKColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return SKColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t,
                       blue: ab + (bb - ab) * t, alpha: aa + (ba - aa) * t)
    }

    // MARK: - LCD / scan presentation (modern handheld, not CRT dirt)
    /// Darken every other logical-pixel row slightly (GBC LCD feel).
    static let lcdRowAlpha: CGFloat = 0.10
    /// Thin grid lines between logical pixels.
    static let lcdGridAlpha: CGFloat = 0.06

    // MARK: - Ball spin
    static let ballSpinFactor: CGFloat = 0.95

    // MARK: - Starfield (deterministic seed → same sky every launch)
    /// Sparse 1px stars across the whole gradient (not only the top).
    static let starCount = 72

    // MARK: - Depth atmosphere (simplified)
    /// Mild edge darken only — sky already carries most of the mood.
    static let vignetteAlpha: CGFloat = 0.22
    /// Walls stay transparent — no filled panels.
    static let panelAlphaNear: CGFloat = 0
    static let panelAlphaFar: CGFloat = 0
    /// Extra face grid off — rings + corner rails are the continuous lattice.
    static let gridDepthLines = 0
    static let gridLongLines = 0
    static let gridAlphaNear: CGFloat = 0.55
    static let gridAlphaFar: CGFloat = 0.35
    static let gridLineWidthNear: CGFloat = 2
    static let gridLineWidthFar: CGFloat = 2
    /// Dust / vanishing glow removed — they read as noise vs the clean r1 look.
    static let dustCount = 0

    // MARK: - Audio (procedural, zero assets)
    static let audioMaster: Float = 0.55
    static let audioSFX: Float = 0.85
    static let audioAmbient: Float = 0.12

    // MARK: - Ball trail + contact shadow (hard steps, not soft fade)
    static let trailLength = 5
    static let trailAlphaHead: CGFloat = 0.55
    static let trailAlphaTail: CGFloat = 0.12
    static let trailScaleHead: CGFloat = 1.0
    static let trailScaleTail: CGFloat = 0.55
    static let ballShadowAlpha: CGFloat = 0.45
    static let ballShadowYScale: CGFloat = 0.35
    static let ballShadowXScale: CGFloat = 1.2

    // MARK: - Paddle (solid slabs, lightly rounded)
    static let paddleCornerRadius: CGFloat = 10
    /// Impact flash is a second solid border + brief fill brighten.
    static let paddleGlowWidth: CGFloat = 0
    static let paddleGlowLineWidth: CGFloat = 4
    static let paddleGlowUp: CGFloat = 0.035
    static let paddleGlowDown: CGFloat = 0.16
    static let paddleGlowScale: CGFloat = 1.06
    static let paddleFillAlpha: CGFloat = 0.22
    /// Fill alpha at peak of a hit flash (rest is paddleFillAlpha).
    static let paddleHitFillAlpha: CGFloat = 0.55
    static let paddleInnerInset: CGFloat = 6
}
