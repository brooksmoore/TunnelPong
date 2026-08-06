import SpriteKit

/// Every tunable number in the game lives here. Tweak these, nowhere else.
struct Config {

    // MARK: - Perspective
    /// Perspective strength. Lower = more dramatic depth distortion.
    /// 280 makes near/far ball size read more clearly than 320.
    static let focal: CGFloat = 280
    /// Depth of the opponent's paddle plane. The player's plane is z = 0.
    static let zFar: CGFloat = 900

    // MARK: - Court (immersive tunnel, not full-frame bezel)
    //
    // Court sits in the safe vertical band under the heart row and above the
    // bottom score bar — sky/margins around the tunnel keep the depth read.
    // Portrait, landscape, and free Mac resize all rebuild halfW/halfH from the
    // current view; physics stays in world units so rules feel the same while
    // the playing field aspect tracks the device.
    /// Horizontal fill of the *usable* width (inside left/right safe insets).
    static let courtWidthFactor: CGFloat = 0.96
    /// Vertical fill of the play band (between hearts and bottom score).
    static let courtHeightFactor: CGFloat = 1.0
    /// Extra inset from left/right safe edges before the near wall.
    static let courtSidePad: CGFloat = 6
    /// Gap under safe-top / hearts before the near wall.
    static let courtTopPad: CGFloat = 10
    static let courtBottomPad: CGFloat = 8
    /// Clearance from heart label centre down to the near-ring top edge.
    static let heartsToCourtGap: CGFloat = 30
    /// Reserved height at the bottom for score + serve hint (inside play band).
    static let bottomScoreBand: CGFloat = 48
    /// Prefer at least this much court height when the screen allows it.
    static let courtMinHeightPreferred: CGFloat = 220
    /// Floor for very short landscape (e.g. SE landscape) so the tunnel still fits.
    static let courtMinHeightFloor: CGFloat = 140

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
    /// Nominal corner radius as a fraction of court width. Drawn as *stepped*
    /// 8-bit corners (not smooth arcs) — see `PixelPath.roundedRect`.
    static let ringCornerFrac: CGFloat = 0.125
    /// Ceiling as a share of the ring's smaller half-dimension — keeps distant
    /// rings stepped rects instead of collapsing them into discs.
    static let ringCornerCap: CGFloat = 0.32
    /// Depth-ring stroke by near→far band (9 rings): near 3×3pt, mid 3×2pt, far 3×1pt.
    static let ringLineWidthNear: CGFloat = 3
    static let ringLineWidthMid: CGFloat = 2
    static let ringLineWidthFar: CGFloat = 1
    /// Fallback stroke when a rail has no band index (e.g. factory default).
    /// Prefer `railLineWidth(index:)` for live tunnel geometry.
    static let railLineWidthDefault: CGFloat = 1
    /// How far past the player plane (z=0) toward the camera the corner rails
    /// continue — negative Z. Must stay greater than -focal so scale stays finite.
    /// Makes the tunnel feel like it surrounds the viewer, not stop at the near wall.
    static let railNearExtendZ: CGFloat = -160
    /// Stroke weight of the past-camera rail stubs (match near rings).
    static let railNearExtendWidth: CGFloat = 3

    // MARK: - Depth tracker (z-axis readout on the corner rails)
    //
    // A 2D screen shows x and y directly but not z, and the hardest read in the
    // game is *when* the ball reaches your plane. The four corner rails are the
    // only geometry running along z, so a small dot rides each one at the ball's
    // current depth.
    //
    // Deliberately NOT a wall glow: the x/y walls stay dark until individually
    // struck, which is what makes an impact read as an impact. The dot borrows
    // the *impact* colour so the two cues feel like one family, while staying a
    // separate channel.
    //
    // Kept small and simple on purpose — a long dash read as clunky. The dot
    // scales with perspective, so its own acceleration is the timing cue.

    /// Dot radius in points at the near plane (z = 0).
    static let depthDotRadius: CGFloat = 5
    /// Floor on the perspective scale so the dot never vanishes at the far wall.
    static let depthDotMinScale: CGFloat = 0.42
    static let depthDotAlpha: CGFloat = 0.95
    /// Same colour as a struck wall — one visual family, two channels.
    static let depthDotColor = ringHitColor

    /// Line width for ring index 0…ringCount-1 (0 = nearest / player plane).
    static func ringLineWidth(index: Int) -> CGFloat {
        switch index {
        case 0, 1, 2: return ringLineWidthNear
        case 3, 4, 5: return ringLineWidthMid
        default:      return ringLineWidthFar
        }
    }

    /// Z-axis rail segment between ring `index` and `index+1` (same bands as rings).
    static func railLineWidth(index: Int) -> CGFloat {
        ringLineWidth(index: index)
    }
    static let ringAlphaNear: CGFloat = 0.88
    /// Far *wire* rings stay open; the opponent-plane ring is a soft pink wall.
    static let ringAlphaFar: CGFloat = 0.42
    static let cornerLineAlpha: CGFloat = 0.90
    /// Soft pink fill on the far (opponent) plane — marks the end of the tunnel.
    static let farWallFillAlpha: CGFloat = 0.14
    /// Outline must *look* as thin as the second-to-last wire ring. Fill + stroke
    /// on an SKShapeNode reads heavier at the same lineWidth, so we use a
    /// sub-1pt stroke and the same alpha band as far wire rings.
    static let farWallStrokeWidth: CGFloat = 0.5
    static let farWallStrokeAlpha: CGFloat = 0.42
    /// Hit flash: ring pops to this colour then settles back to neon pink.
    static let ringHitColor = SKColor(red: 1.00, green: 0.85, blue: 0.95, alpha: 1)
    static let ringHitUp: CGFloat = 0.04
    static let ringHitDown: CGFloat = 0.28

    // MARK: - Ball (constants that do not ramp)
    /// World-space radius (also base on-screen size at z = 0).
    static let ballRadius: CGFloat = 24
    /// Extra english when the paddle *corner* is on the ball at contact (0–1 scale).
    static let serveCornerBoost: CGFloat = 0.90
    /// Minimum share of total speed kept along z, so the ball can't stall
    /// bouncing sideways after heavy english. Slightly lower = more lateral room
    /// for spin to read without killing depth travel.
    static let minVzFraction: CGFloat = 0.36
    /// Absolute ceiling (safety). L10 endpoints stay under this.
    static let ballMaxSpeed: CGFloat = 1200
    /// Every point starts here: dead centre of the tunnel, both axes zero.
    /// 0.5 = exactly halfway between the player plane (z = 0) and the
    /// opponent plane (z = zFar). There is no serve-from-your-own-plane state;
    /// the ball launches from the middle toward whoever gets the first touch.
    static let rallyStartZFraction: CGFloat = 0.5
    /// Beat the ball hangs at centre before launching, seconds. Long enough to
    /// read which way it's about to go, short enough not to feel like a wait.
    static let serveDelay: CGFloat = 0.75
    /// Hold the ball on the plane after a point, then resolve lives/score.
    static let pointFreezeDuration: CGFloat = 0.65

    // MARK: - Curve
    //
    // Curveball-style continuous bend: curve is integrated into lateral
    // velocity every frame and decays exponentially in real time (not per
    // frame — so 60 Hz and 120 Hz feel the same). After each curve step we
    // renorm total speed so curve *bends* the path without inflating difficulty.

    /// Fraction of curve remaining after one full second (exponential base).
    static let curveDecayPerSecond: CGFloat = 0.80
    /// Scales paddle world-velocity (units/sec) into curve acceleration.
    /// Sign is applied in `CourtMath.curveFromPaddleVelocity` (player inverted).
    static let curveFromPaddleVel: CGFloat = 0.55
    /// Fraction of curve kept after a wall bounce (also axis-flips on that wall).
    static let curveWallDamp: CGFloat = 0.85
    /// Hard ceiling on curve vector magnitude.
    static let curveMax: CGFloat = 900
    /// |curve| on one axis that awards curveBonus.
    static let curveBonusThreshold: CGFloat = 120
    /// |curve| on *both* axes that awards superCurveBonus.
    static let curveSuperThreshold: CGFloat = 260
    /// Exponential smooth on paddle velocity samples (~3 frames at 60 Hz).
    static let paddleVelSmooth: CGFloat = 0.45
    /// Closes this fraction of the paddle→target gap per 1/60 s (dt-corrected).
    /// Needed so Mac/iOS produce a real velocity signal for curve.
    static let paddleFollowLerp: CGFloat = 0.55

    // MARK: - Player paddle (full capability always — does not ramp)
    static let playerPaddleHalfW: CGFloat = 72
    static let playerPaddleHalfH: CGFloat = 52
    static let paddleHitSlop: CGFloat = 14
    /// iOS relative-drag amplification. The paddle moves this many times
    /// further than your thumb, so the whole court is reachable one-handed
    /// without stretching. 1.0 would be literal 1:1 dragging.
    static let touchGain: CGFloat = 2.3

    // MARK: - Opponent size (fixed; skill ramps below)
    static let oppPaddleHalfW: CGFloat = 48
    static let oppPaddleHalfH: CGFloat = 36
    /// D1 wall inset: the AI paddle's *centre* stays this many half-paddle-widths
    /// off each wall, so wall-hugging shots stay a scoring lane even when the
    /// AI's tracking speed would otherwise reach everything. 1.0 = flush.
    /// Raising this widens the lane and makes high levels easier.
    static let aiWallInsetPaddles: CGFloat = 1.5

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
    // Contact-offset english — demoted in v1.5 so paddle-velocity curve dominates.
    // Absolute veer still grows with ball speed via eng * speed.
    static let englishStrength: CGFloat = 0.45

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
    /// Score when the opponent misses (still level-scaled).
    static let scorePerOpponentLife = 100

    // MARK: - Scoring (Curveball-style self-degrading bonuses)
    //
    // Each bonus awards its current value then subtracts its degrade; floors at 0.
    // All reset to start values when the player loses a life.

    static let hitScoreStart = 100
    static let hitScoreDegrade = 10
    static let curveBonusStart = 50
    static let curveBonusDegrade = 5
    static let superCurveBonusStart = 150
    static let superCurveBonusDegrade = 15
    static let accuracyBonusStart = 100
    static let accuracyBonusDegrade = 10
    /// Banked on level clear; decays while the ball is live during the level.
    static let levelClearBonusStart = 3000
    /// Points lost per second of live-ball time during a level.
    static let levelClearDecayPerSecond: CGFloat = 200
    /// Hit counts as "perfect" when |offset| / paddleHalf ≤ this on both axes.
    static let accuracyWindowFrac: CGFloat = 0.15
    /// How long bonus popups stay on screen.
    static let bonusPopupDuration: CGFloat = 0.85
    /// Pixel size of bonus popup type.
    static let bonusPopupSize: CGFloat = 14

    // MARK: - Flow
    static let levelTransitionDuration: CGFloat = 1.4

    // MARK: - Layout / safe area
    /// Pad under the Dynamic Island / safe top for level + score (hearts sit higher).
    static let hudTopPad: CGFloat = 6
    static let hudBottomPad: CGFloat = 10
    // MARK: - HUD type on the tunnel surfaces
    //
    // LVL and the score are painted onto the ceiling and floor rather than
    // floating flat over them, so they read as part of the tunnel. Both use the
    // same zNear/zFar span, and both anchor to their own wall (+halfH / -halfH),
    // which is what makes them equidistant from those walls at any screen size
    // or orientation — the symmetry falls out of the geometry instead of being
    // hand-tuned per device.

    /// Depth of the type's near edge (0 = right at the near wall).
    static let hudSurfaceZNear: CGFloat = 10
    /// Far edge of the surface type, expressed as a **ring index** rather than a
    /// raw depth so it tracks the tunnel's own spacing: 1 means the type ends
    /// exactly on the second ring. Tying it to the rings is what keeps the type
    /// visually "part of" the floor and ceiling — it fills one wall segment, and
    /// it keeps doing so if `ringCount` or `zFar` ever change.
    static let hudSurfaceEndRing: Int = 1
    /// Depth of the far edge, derived from `hudSurfaceEndRing`.
    static var hudSurfaceZFar: CGFloat {
        zFar * CourtMath.ringT(index: hudSurfaceEndRing, ringCount: ringCount)
    }
    /// World units per label point, horizontally. Above 1 widens the type.
    static let hudSurfaceWidthScale: CGFloat = 1.35
    /// Glyph heights. Bigger than flat HUD text because perspective shrinks the
    /// far rows — these are the *near*-edge sizes.
    static let hudLevelSize: CGFloat = 30
    static let hudScoreSize: CGFloat = 38

    /// Pause glyph opacity. It sits in the bottom-right corner away from the
    /// tunnel, so it can be legible without competing with the ball.
    static let pauseButtonAlpha: CGFloat = 0.85
    /// Mac Catalyst titlebar eats the top of the content view; treat as min top inset.
    static let macTitlebarInset: CGFloat = 40
    /// Extra gap below hearts / court top when placing the LVL chrome label.

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
    /// AI — neon purple (distinct from pink tunnel / far wall).
    static let opponentColor = SKColor(red: 0.72, green: 0.28, blue: 1.00, alpha: 1)
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

    // MARK: - Sky bands (top → bottom). Darker: black dominates; gradient
    // "starts" at deep purple (no pink horizon). Pink lives only on tunnel wire.
    static let sky0 = SKColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1)  // black
    static let sky1 = SKColor(red: 0.00, green: 0.00, blue: 0.02, alpha: 1)  // near-black
    static let sky2 = SKColor(red: 0.02, green: 0.00, blue: 0.06, alpha: 1)  // void indigo
    static let sky3 = SKColor(red: 0.04, green: 0.01, blue: 0.10, alpha: 1)  // deep indigo
    static let sky4 = SKColor(red: 0.06, green: 0.02, blue: 0.14, alpha: 1)  // dark purple
    static let sky5 = SKColor(red: 0.09, green: 0.02, blue: 0.18, alpha: 1)  // purple
    static let sky6 = SKColor(red: 0.12, green: 0.03, blue: 0.22, alpha: 1)  // mid purple
    static let sky7 = SKColor(red: 0.15, green: 0.04, blue: 0.26, alpha: 1)  // violet (no pink)
    static let sky8 = SKColor(red: 0.18, green: 0.05, blue: 0.28, alpha: 1)  // soft purple base
    static let moonColor = SKColor(red: 0.96, green: 0.96, blue: 1.00, alpha: 1)

    // MARK: - Tunnel wire — one neon pink for every spaced line
    static let wallNeonPink = SKColor(red: 1.00, green: 0.28, blue: 0.58, alpha: 1)

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
    static let ballSpinFactor: CGFloat = 1.25

    // MARK: - Starfield / moon (deterministic seed → same sky every launch)
    /// Sparse 1px stars across the whole gradient (not only the top).
    static let starCount = 72
    /// Crescent moon radius as a fraction of backdrop texture width (~was 1/28).
    static let moonRadiusFrac: CGFloat = 1.0 / 15.0

    // MARK: - Depth atmosphere (simplified)
    /// Mild edge darken only — sky already carries most of the mood.
    static let vignetteAlpha: CGFloat = 0.22

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

    // MARK: - Paddle (solid slabs, 8-bit stepped corners)
    /// Corner cut size in points; quantized to `pixel` steps (chunky, not smooth).
    static let paddleCornerRadius: CGFloat = 9
    static let paddleGlowLineWidth: CGFloat = 4
    static let paddleGlowUp: CGFloat = 0.035
    static let paddleGlowDown: CGFloat = 0.16
    static let paddleGlowScale: CGFloat = 1.06
    static let paddleFillAlpha: CGFloat = 0.22
    /// Fill alpha at peak of a hit flash (rest is paddleFillAlpha).
    static let paddleHitFillAlpha: CGFloat = 0.55
    static let paddleInnerInset: CGFloat = 6
}
