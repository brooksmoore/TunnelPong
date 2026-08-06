import SpriteKit
import UIKit
import QuartzCore

/// The whole game lives in one scene, driven by an explicit state machine.
/// World space: x/y are court coordinates centered on 0; z is depth, with
/// z = 0 at the player's paddle plane and z = zFar at the opponent's.
final class GameScene: SKScene {

    // MARK: - State machine

    enum Phase {
        case title
        case playing
        case paused
        case levelTransition
        case gameOver
    }

    private(set) var phase: Phase = .title

    // MARK: - Geometry

    /// Set by GameViewController after layout (notch / home indicator).
    var safeInsets: UIEdgeInsets = .zero

    private var proj = Projector(focal: Config.focal, center: .zero)
    private var halfW: CGFloat = 0   // court half-width at z = 0, in points
    private var halfH: CGFloat = 0
    /// Screen y of the court's top wall — HUD hangs below this.
    private var courtTopY: CGFloat = 0

    // MARK: - Run state

    private var level = 1
    private var score = 0
    private var playerLives = Config.playerLives
    private var opponentLives = Config.opponentLivesPerLevel
    private var rallyHits = 0
    private var highScore = UserDefaults.standard.integer(forKey: "highScore")
    /// Self-degrading hit / curve / accuracy / level-clear bonuses.
    private var bonuses = ScoreBonuses.fresh(
        hit: Config.hitScoreStart,
        curve: Config.curveBonusStart,
        superCurve: Config.superCurveBonusStart,
        accuracy: Config.accuracyBonusStart,
        levelClear: Config.levelClearBonusStart
    )

    // MARK: - Ball (world coordinates)

    private var bx: CGFloat = 0, by: CGFloat = 0, bz: CGFloat = 0
    private var vx: CGFloat = 0, vy: CGFloat = 0, vz: CGFloat = 0
    /// Continuous curve acceleration (Curveball-style banana arc).
    private var curveX: CGFloat = 0, curveY: CGFloat = 0
    private var ballLive = false           // false while waiting to serve / frozen
    private var serveCountdown: CGFloat = 0
    /// Who the ball flies toward first when a point begins.
    ///
    /// Every point starts with the ball parked dead centre of the tunnel and
    /// then launching — there is no serve-from-your-own-plane state. The ball
    /// goes to whoever *won* the previous point: win and you get the free first
    /// touch, lose and the opponent takes it and you receive whatever curve
    /// they put on it. A new level is a gift, so it comes to you.
    private enum FirstTouch { case player, opponent }
    private var firstTouch: FirstTouch = .player
    /// Point just scored — ball held on the plane with a callout.
    private var pointFreezeCountdown: CGFloat = 0
    private var pendingPointWin = false   // true = you scored, false = you lost a life
    // Serve strike tracking (Mac: click/drag on ball; iOS: drag across ball).
    /// Serve gesture: accumulate travel so swipe threshold is FPS-independent.
    /// Last-frame delta (instant spin intensity).
    /// Path length since touch-down (swipe threshold).
    /// Net displacement from start (spin direction on serve).



    // MARK: - Paddles (world coordinates)

    private var px: CGFloat = 0, py: CGFloat = 0        // player, at z = 0
    private var touchTarget: CGPoint?                   // where the finger wants the paddle
    private var ox: CGFloat = 0, oy: CGFloat = 0        // opponent, at z = zFar
    // AI is pure live-XY tracking — no intercept predict / aim error / delay.
    /// Smoothed paddle world-velocity (units/sec) — source of curve on contact.
    private var playerVelX: CGFloat = 0, playerVelY: CGFloat = 0
    private var oppVelX: CGFloat = 0, oppVelY: CGFloat = 0
    private var prevPx: CGFloat = 0, prevPy: CGFloat = 0
    private var prevOx: CGFloat = 0, prevOy: CGFloat = 0

    // MARK: - Timers

    private var lastUpdate: TimeInterval = 0
    private var transitionCountdown: CGFloat = 0
    private var lastPhaseChange: TimeInterval = 0

    // MARK: - Nodes

    private let backdropNode = SKNode()
    private var backdropSize: CGSize = .zero
    private let worldNode = SKNode()
    private var rings: [SKShapeNode] = []
    private var depthPanels: [SKShapeNode] = []
    private var railSegments: [SKShapeNode] = []
    /// Depth tracker: small dots riding the four corner rails at the ball's z.
    /// Index order matches the (sx, sy) corner loop in `rebuildTunnelGeometry`.
    private var depthDots: [SKShapeNode] = []
    private var ringPulses: [SKAction] = []
    private var pauseDim: SKSpriteNode!
    private var scanlineNode: SKSpriteNode!
    private var vignetteNode: SKSpriteNode!
    private var ballNode: SKNode!
    private var ballShadowNode: SKNode!
    /// Discrete trail opacities, head → tail. Static so the update loop never
    /// allocates to read them.
    private static let trailAlphaSteps: [CGFloat] =
        [Config.trailAlphaHead, 0.35, 0.22, 0.15, Config.trailAlphaTail]

    private var trailGhosts: [SKNode] = []
    private var trailHistory: [(x: CGFloat, y: CGFloat, z: CGFloat)] = []
    /// Inner layer of the ball that turns; see NodeFactory.ball().
    private weak var ballSpinLayer: SKNode?
    private var ballSpin: CGFloat = 0
    /// Cached so the serve affordance isn't re-applied every frame.
    private var playerPaddleNode: SKShapeNode!
    private var oppPaddleNode: SKShapeNode!

    private var hudNode: SKNode!
    private var hudLevelLabel: PixelLabel!
    private var hudScoreLabel: PixelLabel!
    private var hudHighScoreLabel: PixelLabel!
    private var hudPlayerLives: PixelLabel!
    private var hudOppLives: PixelLabel!
    private var pauseButton: PixelLabel!
    private var pointCalloutLabel: PixelLabel!
    private var bonusPopupLabel: PixelLabel!
    private var bonusPopupCountdown: CGFloat = 0

    private var titleLayer: SKNode!
    private var titleHighLabel: PixelLabel!
    private var titleWordTop: PixelLabel!
    private var titleWordBottom: PixelLabel!
    private var titleTapLabel: PixelLabel!
    private var titleStoreLabel: PixelLabel!
    private var titleRestoreLabel: PixelLabel!
    private var pauseLayer: SKNode!
    private var quitLabel: PixelLabel!
    private var gameOverLayer: SKNode!
    private var goTitleLabel: PixelLabel!
    private var goScoreLabel: PixelLabel!
    private var goHighLabel: PixelLabel!
    private var transitionLabel: PixelLabel!
    private var flashNode: SKSpriteNode!

    private var shakeAction: SKAction!
    private var flashAction: SKAction!

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black
        applyCourtMetrics()

        backdropNode.zPosition = -100
        addChild(backdropNode)
        addChild(worldNode)
        buildTunnel()
        buildActors()
        buildEffects()
        buildHUD()
        buildOverlays()
        applyChromeLayout()

        Haptics.shared.prepare()
        Audio.shared.prepare()
        Store.shared.onChange = { [weak self] in self?.refreshStoreRow() }
        Store.shared.start()
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResign),
            name: UIApplication.willResignActiveNotification, object: nil)

        showTitle()
    }

    /// Top inset under notch / Dynamic Island / Mac titlebar.
    private var layoutTopInset: CGFloat {
        max(safeInsets.top, 0) + Config.hudTopPad
    }

    private var layoutBottomInset: CGFloat {
        max(safeInsets.bottom, 0) + Config.hudBottomPad
    }

    /// Heart row in the safe-top / Island-ear band — always *above* the tunnel.
    /// In landscape (shallow top safe area) keep a compact top margin.
    private func heartsBandY() -> CGFloat {
        let topSafe = max(safeInsets.top, 0)
        if topSafe >= 44 {
            return size.height - topSafe * 0.48
        }
        // Landscape phone / Mac titlebar / small inset.
        let compact = size.height < size.width ? 12.0 : 16.0
        return size.height - max(topSafe, 8) - compact
    }

    /// Immersive court: safe band under hearts, above bottom score, inside
    /// left/right safe insets. Rebuilds on any orientation or Mac resize —
    /// world halfW/halfH track the view aspect; speeds & paddle sizes stay
    /// fixed in world units (same rules, different field shape).
    private func applyCourtMetrics() {
        let topSafe = max(safeInsets.top, 0)
        let botSafe = max(safeInsets.bottom, 0)
        let leftSafe = max(safeInsets.left, 0)
        let rightSafe = max(safeInsets.right, 0)

        let heartsY = heartsBandY()
        // Landscape: less vertical room — tighter gap under hearts so the tunnel
        // keeps height; portrait keeps the roomier clearance.
        let landscape = size.width > size.height
        let heartsGap = landscape
            ? min(Config.heartsToCourtGap, 18)
            : Config.heartsToCourtGap
        let underHearts = heartsY - heartsGap
        let underSafe = size.height - topSafe - Config.courtTopPad
        courtTopY = min(underHearts, underSafe)

        let scoreBand = landscape
            ? min(Config.bottomScoreBand, 36)
            : Config.bottomScoreBand
        let courtBottomY = botSafe + Config.courtBottomPad + scoreBand

        // Preferred min height, but never steal more than ~55% of short screens.
        let preferredMin = Config.courtMinHeightPreferred
        let adaptiveMin = max(Config.courtMinHeightFloor,
                              min(preferredMin, size.height * 0.55))
        if courtTopY - courtBottomY < adaptiveMin {
            courtTopY = min(size.height - topSafe - 4, courtBottomY + adaptiveMin)
        }

        let usableW = max(1, size.width - leftSafe - rightSafe - Config.courtSidePad * 2)
        let centerX = leftSafe + Config.courtSidePad + usableW / 2
        let centerY = (courtTopY + courtBottomY) / 2
        proj.center = CGPoint(x: centerX, y: centerY)

        halfW = usableW / 2 * Config.courtWidthFactor
        halfH = max(1, (courtTopY - courtBottomY) / 2 * Config.courtHeightFactor)
    }

    /// Call after safeInsets or size change (rotation, Mac resize, notch, titlebar).
    func applyChromeLayout() {
        applyCourtMetrics()
        // Keep actors inside the new bounds (landscape ↔ portrait mid-rally).
        clampPlayer()
        clampOpponent()
        clampBallXY()
        let mx = max(0, halfW - Config.playerPaddleHalfW)
        let my = max(0, halfH - Config.playerPaddleHalfH)
        if var t = touchTarget {
            t.x = max(-mx, min(mx, t.x))
            t.y = max(-my, min(my, t.y))
            touchTarget = t
        }
        // The relative-drag origin stores a paddle position too. Rotating with
        // a finger down leaves it describing the *old* court, so the next drag
        // update would solve to a point outside the new one and snap the paddle
        // to a wall before the elastic re-anchor caught up.
        dragAnchorPaddle.x = max(-mx, min(mx, dragAnchorPaddle.x))
        dragAnchorPaddle.y = max(-my, min(my, dragAnchorPaddle.y))
        rebuildBackdrop()
        rebuildTunnelGeometry()
        layoutHUD()
        layoutOverlays()
        if flashNode != nil {
            flashNode.position = proj.center
            flashNode.size = CGSize(width: size.width * 1.2, height: size.height * 1.2)
        }
        if pauseDim != nil {
            pauseDim.position = proj.center
            pauseDim.size = CGSize(width: size.width * 1.2, height: size.height * 1.2)
        }
        renderWorld()
    }

    /// Night-sky gradient + stars + moon. LCD overlay + light vignette on top.
    /// Rebuilt when frame size changes (or backdropSize is cleared to force regen).
    private func rebuildBackdrop() {
        guard size.width > 0, size.height > 0 else { return }
        if size == backdropSize { return }
        backdropSize = size
        backdropNode.removeAllChildren()

        let sky = SKSpriteNode(texture: NodeFactory.worldBackdropTexture(size: size))
        sky.size = size
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.texture?.filteringMode = .nearest
        backdropNode.addChild(sky)

        if vignetteNode == nil {
            vignetteNode = SKSpriteNode()
            vignetteNode.zPosition = 65
            addChild(vignetteNode)
        }
        vignetteNode.texture = NodeFactory.vignetteTexture(size: size)
        vignetteNode.size = size
        vignetteNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // LCD row darkening (GBC screen feel), nearest-neighbour upscale.
        if scanlineNode == nil {
            scanlineNode = SKSpriteNode()
            scanlineNode.zPosition = 70
            addChild(scanlineNode)
        }
        scanlineNode.texture = NodeFactory.lcdOverlayTexture(size: size)
        scanlineNode.texture?.filteringMode = .nearest
        scanlineNode.size = size
        scanlineNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// Re-derive rings, panels, rails, and perspective grid from live court size.
    /// Safe to call before the tunnel exists (arrays are empty).
    /// Where a corner rail should meet a ring, in screen space.
    ///
    /// Matches ring drawing: snapped half-extents + stepped-corner inset so
    /// rails land on the ring outline and never poke past the far wall.
    private func railAnchor(sx: CGFloat, sy: CGFloat, z: CGFloat) -> CGPoint {
        // Never place anchors past the opponent plane (zFar).
        let zClamped = min(max(z, Config.railNearExtendZ), Config.zFar)
        let s = proj.scale(z: zClamped)
        // Same snap as NodeFactory.ring so rails meet the drawn path.
        let w = Config.snap(halfW * s)
        let h = Config.snap(halfH * s)
        let r = NodeFactory.ringCornerRadius(halfW: halfW, halfH: halfH, scale: s)
        let inset = PixelPath.railCornerInset(radius: r)
        return CGPoint(x: proj.center.x + sx * (w - inset),
                       y: proj.center.y + sy * (h - inset))
    }

    private func rebuildTunnelGeometry() {
        for (i, node) in rings.enumerated() {
            let t = CourtMath.ringT(index: i, ringCount: Config.ringCount)
            let s = proj.scale(z: Config.zFar * t)
            let w = Config.snap(halfW * s)
            let h = Config.snap(halfH * s)
            let r = NodeFactory.ringCornerRadius(halfW: halfW, halfH: halfH, scale: s)
            let rect = CGRect(x: -w, y: -h, width: 2 * w, height: 2 * h)
            let path = PixelPath.roundedRect(rect: rect, cornerRadius: r, pixel: Config.pixel)
            node.path = path
            node.position = proj.center
            node.isAntialiased = false
            node.lineJoin = .miter
            node.lineCap = .square
            node.lineWidth = Config.ringLineWidth(index: i)
            // Far plane: soft pink fill + hairline outline (visually matches
            // second-to-last wire; fill+stroke needs a thinner lineWidth).
            if i >= Config.ringCount - 1 {
                node.fillColor = Config.wallNeonPink.withAlphaComponent(Config.farWallFillAlpha)
                node.strokeColor = Config.wallNeonPink.withAlphaComponent(Config.farWallStrokeAlpha)
                node.lineWidth = Config.farWallStrokeWidth
                node.alpha = 1
            } else {
                node.fillColor = .clear
                node.strokeColor = Config.wallNeonPink
                node.lineWidth = Config.ringLineWidth(index: i)
                node.alpha = NodeFactory.lerp(Config.ringAlphaNear, Config.ringAlphaFar, t)
            }
            if i < depthPanels.count {
                depthPanels[i].path = path
                depthPanels[i].position = proj.center
            }
        }
        // Z-axis corner rails: (1) stubs past the near plane toward the camera,
        // then (2) one segment per ring gap ending *on* the far wall — never past.
        let gaps = max(Config.ringCount - 1, 1)
        var i = 0
        for sx: CGFloat in [-1, 1] {
            for sy: CGFloat in [-1, 1] {
                // Past player POV: z < 0 (toward camera). Thick neon, high alpha.
                if i < railSegments.count {
                    let path = CGMutablePath()
                    path.move(to: railAnchor(sx: sx, sy: sy, z: Config.railNearExtendZ))
                    path.addLine(to: railAnchor(sx: sx, sy: sy, z: 0))
                    railSegments[i].path = path
                    railSegments[i].strokeColor = Config.wallNeonPink
                    railSegments[i].lineWidth = Config.railNearExtendWidth
                    railSegments[i].lineCap = .butt
                    railSegments[i].alpha = min(1, Config.cornerLineAlpha * 1.05)
                    railSegments[i].isHidden = false
                    i += 1
                }
                for seg in 0..<gaps {
                    guard i < railSegments.count else { break }
                    let z0 = Config.zFar * CourtMath.ringT(index: seg, ringCount: Config.ringCount)
                    // Clamp so the last segment terminates exactly at zFar.
                    let z1 = min(
                        Config.zFar * CourtMath.ringT(index: seg + 1, ringCount: Config.ringCount),
                        Config.zFar
                    )
                    let path = CGMutablePath()
                    path.move(to: railAnchor(sx: sx, sy: sy, z: z0))
                    path.addLine(to: railAnchor(sx: sx, sy: sy, z: z1))
                    railSegments[i].path = path
                    railSegments[i].strokeColor = Config.wallNeonPink
                    railSegments[i].lineWidth = Config.railLineWidth(index: seg)
                    railSegments[i].lineCap = .butt
                    let t = CourtMath.ringT(index: seg, ringCount: Config.ringCount)
                    railSegments[i].alpha = Config.cornerLineAlpha * NodeFactory.lerp(1.0, 0.75, t)
                    railSegments[i].isHidden = false
                    i += 1
                }
            }
        }
        // Any leftover rails (count mismatch after rebuild) must not keep old paths.
        while i < railSegments.count {
            railSegments[i].path = nil
            railSegments[i].isHidden = true
            i += 1
        }
    }

    private func layoutHUD() {
        guard hudNode != nil, hudPlayerLives != nil else { return }
        let botSafe = max(safeInsets.bottom, 0)
        let sidePad = max(safeInsets.left, safeInsets.right, 10) + 10
        let cx = size.width / 2

        // Top: hearts + LVL chrome (page header).
        let heartsY = heartsBandY()
        hudPlayerLives.position = CGPoint(x: sidePad, y: heartsY)
        hudOppLives.position = CGPoint(x: size.width - sidePad, y: heartsY)
        // LVL is painted on the ceiling, the score on the floor. Each anchors to
        // its own wall, so both sit the same distance from their wall by
        // construction rather than by tuning.
        hudLevelLabel.surface = PixelLabel.SurfaceProjection(
            focal: Config.focal,
            zNear: Config.hudSurfaceZNear,
            zFar: Config.hudSurfaceZFar,
            surfaceY: halfH,
            widthScale: Config.hudSurfaceWidthScale,
            nearAtTop: true)
        hudLevelLabel.position = proj.center

        let courtFloor = proj.center.y - halfH

        hudScoreLabel.surface = PixelLabel.SurfaceProjection(
            focal: Config.focal,
            zNear: Config.hudSurfaceZNear,
            zFar: Config.hudSurfaceZFar,
            surfaceY: -halfH,
            widthScale: Config.hudSurfaceWidthScale,
            nearAtTop: false)
        hudScoreLabel.position = proj.center
        // Pause lives in the bottom-right corner, clear of the tunnel mouth and
        // under the thumb. Sits on the safe-area floor, not the court floor.
        pauseButton.position = CGPoint(x: size.width - sidePad - 8,
                                       y: botSafe + Config.hudBottomPad + 12)
        // Bonus popups sit above mid-court, snapped to the pixel grid.
        if bonusPopupLabel != nil {
            let popY = Config.snap((courtTopY + courtFloor) * 0.5 + halfH * 0.15)
            bonusPopupLabel.position = Config.snapPoint(CGPoint(x: cx, y: popY))
        }
        hudHighScoreLabel?.isHidden = true
    }

    private func layoutOverlays() {
        guard titleLayer != nil else { return }
        let cx = size.width / 2
        let cy = size.height / 2
        // Wordmark sits below safe top so Mac titlebar / iOS notch never clip it.
        let maxTop = size.height - layoutTopInset - 36
        let cyberY = min(cy + 130, maxTop)
        let pongY = cyberY - 62
        // Order matches buildOverlays: CYBER, PONG, tap prompt, high score.
        // Named refs, not child indices — adding a node used to silently shift
        // everything that came after it.
        titleWordTop?.position = CGPoint(x: cx, y: cyberY)
        titleWordBottom?.position = CGPoint(x: cx, y: pongY)
        titleTapLabel?.position = CGPoint(x: cx, y: cy - 50)
        titleHighLabel?.position = CGPoint(x: cx, y: cy - 110)
        titleStoreLabel?.position = CGPoint(x: cx, y: cy - 152)
        titleRestoreLabel?.position = CGPoint(x: cx, y: cy - 182)
        if transitionLabel != nil {
            transitionLabel.position = CGPoint(x: cx, y: cy + 30)
        }
        goTitleLabel?.position = CGPoint(x: cx, y: cy + 100)
        goScoreLabel?.position = CGPoint(x: cx, y: cy + 30)
        goHighLabel?.position = CGPoint(x: cx, y: cy - 10)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillResign() {
        if phase == .playing { pauseGame() }
    }

    private func buildTunnel() {
        // Soft panels first (behind rings) — shaft volume.
        for i in 0..<Config.ringCount {
            let t = CourtMath.ringT(index: i, ringCount: Config.ringCount)
            let z = Config.zFar * t
            let panel = NodeFactory.depthPanel(halfW: halfW, halfH: halfH,
                                               scale: proj.scale(z: z), t: t,
                                               center: proj.center)
            panel.zPosition = 1
            worldNode.addChild(panel)
            depthPanels.append(panel)
        }

        for i in 0..<Config.ringCount {
            let t = CourtMath.ringT(index: i, ringCount: Config.ringCount)
            let z = Config.zFar * t
            let node = NodeFactory.ring(halfW: halfW, halfH: halfH,
                                        scale: proj.scale(z: z), t: t,
                                        center: proj.center, index: i)
            node.zPosition = 4
            worldNode.addChild(node)
            rings.append(node)
            // Colour + alpha pop on wall contact — sells which depth ring was hit.
            let baseA = node.alpha
            let flashA = min(1.0, baseA * 1.45 + 0.2)
            let toHit = SKAction.run {
                node.strokeColor = Config.ringHitColor
            }
            let up = SKAction.group([
                toHit,
                SKAction.fadeAlpha(to: flashA, duration: TimeInterval(Config.ringHitUp)),
            ])
            let settleColor = SKAction.customAction(
                withDuration: TimeInterval(Config.ringHitDown)
            ) { n, elapsed in
                let t = CGFloat(min(1, elapsed / Config.ringHitDown))
                (n as? SKShapeNode)?.strokeColor = Config.blend(
                    Config.ringHitColor, Config.wallNeonPink, t)
            }
            let down = SKAction.group([
                settleColor,
                SKAction.fadeAlpha(to: baseA, duration: TimeInterval(Config.ringHitDown)),
            ])
            down.timingMode = .easeOut
            let restore = SKAction.run {
                node.strokeColor = Config.wallNeonPink
                node.alpha = baseA
            }
            ringPulses.append(SKAction.sequence([up, down, restore]))
        }
        // Four corners × (1 near-extend + ringCount−1 depth segs) for POV stubs + 3→2→1 taper.
        let segsPerCorner = 1 + max(Config.ringCount - 1, 1)
        let railCount = 4 * segsPerCorner
        for s in 0..<railCount {
            let local = s % segsPerCorner
            let t = local == 0 ? 0 : CourtMath.ringT(index: local - 1, ringCount: Config.ringCount)
            let rail = NodeFactory.railSegment(t: t)
            rail.zPosition = 3
            worldNode.addChild(rail)
            railSegments.append(rail)
        }

        // Depth tracker: one dot per corner rail. Above the rails but below the
        // ball, so the ball always wins where they overlap.
        for _ in 0..<4 {
            let r = Config.depthDotRadius
            let dot = SKShapeNode(rect: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r))
            dot.isAntialiased = false
            dot.fillColor = Config.depthDotColor
            dot.strokeColor = .clear
            dot.alpha = Config.depthDotAlpha
            dot.zPosition = 4
            dot.isHidden = true
            worldNode.addChild(dot)
            depthDots.append(dot)
        }

        rebuildTunnelGeometry()
    }

    private func buildActors() {
        oppPaddleNode = NodeFactory.paddle(halfW: Config.oppPaddleHalfW,
                                           halfH: Config.oppPaddleHalfH,
                                           color: Config.opponentColor)
        oppPaddleNode.setScale(proj.scale(z: Config.zFar))
        oppPaddleNode.zPosition = 10
        worldNode.addChild(oppPaddleNode)

        for _ in 0..<Config.trailLength {
            let g = NodeFactory.trailGhost()
            worldNode.addChild(g)
            trailGhosts.append(g)
        }

        ballShadowNode = NodeFactory.ballShadow()
        worldNode.addChild(ballShadowNode)

        ballNode = NodeFactory.ball()
        ballNode.zPosition = 20
        worldNode.addChild(ballNode)
        ballSpinLayer = ballNode.childNode(withName: "//" + NodeFactory.ballSpinLayerName)

        playerPaddleNode = NodeFactory.paddle(halfW: Config.playerPaddleHalfW,
                                              halfH: Config.playerPaddleHalfH,
                                              color: Config.playerColor)
        playerPaddleNode.zPosition = 30
        worldNode.addChild(playerPaddleNode)
    }

    private func buildEffects() {
        flashNode = SKSpriteNode(color: .white,
                                 size: CGSize(width: size.width * 1.2,
                                              height: size.height * 1.2))
        flashNode.position = proj.center
        flashNode.alpha = 0
        flashNode.zPosition = 80
        addChild(flashNode)

        let fadeIn = SKAction.fadeAlpha(to: 0.30, duration: 0.04)
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.28)
        fadeOut.timingMode = .easeOut
        flashAction = SKAction.sequence([fadeIn, fadeOut])

        let d = 0.035
        shakeAction = SKAction.sequence([
            SKAction.moveBy(x: 9, y: -6, duration: d),
            SKAction.moveBy(x: -14, y: 10, duration: d),
            SKAction.moveBy(x: 8, y: -7, duration: d),
            SKAction.moveBy(x: -3, y: 3, duration: d),
        ])
    }

    private func buildHUD() {
        hudNode = SKNode()
        hudNode.zPosition = 90
        addChild(hudNode)

        // Positions set by layoutHUD() via applyChromeLayout() (safe-area aware).
        // Hearts slightly larger + full opacity so they stay readable on the sky.
        hudPlayerLives = NodeFactory.hudLabel("♥♥♥", size: 18, color: Config.playerColor, alpha: 1.0)
        hudPlayerLives.hAlign = .left
        hudNode.addChild(hudPlayerLives)

        hudOppLives = NodeFactory.hudLabel("♥♥♥", size: 16, color: Config.opponentColor, alpha: 0.95)
        hudOppLives.hAlign = .right
        hudNode.addChild(hudOppLives)

        // Same chrome type as CYBER/PONG title wordmark.
        hudLevelLabel = NodeFactory.titleLabel("LVL 1", size: Config.hudLevelSize, color: Config.titleChromeTop)
        hudLevelLabel.alpha = 0.95
        hudNode.addChild(hudLevelLabel)

        hudScoreLabel = NodeFactory.hudLabel("0", size: Config.hudScoreSize, color: Config.hudColor, alpha: 0.95)
        hudNode.addChild(hudScoreLabel)

        bonusPopupLabel = NodeFactory.hudLabel("", size: Config.bonusPopupSize,
                                               color: Config.titleAccent, alpha: 1)
        bonusPopupLabel.isHidden = true
        hudNode.addChild(bonusPopupLabel)

        // High score is title + game-over only (not live HUD).
        hudHighScoreLabel = NodeFactory.hudLabel("", size: 14, color: Config.hudColor, alpha: 0)
        hudHighScoreLabel.isHidden = true
        hudNode.addChild(hudHighScoreLabel)

        // Pixel font has "|" not the geometric pause bars.
        pauseButton = NodeFactory.hudLabel("||", size: 17, color: Config.hudColor, alpha: Config.pauseButtonAlpha)
        hudNode.addChild(pauseButton)

        // Kept for layout compatibility; never shown (hearts carry the feedback).
        pointCalloutLabel = NodeFactory.titleLabel("", size: 32, color: .white)
        pointCalloutLabel.isHidden = true
    }

    private func buildOverlays() {
        let cx = proj.center.x
        let cy = proj.center.y

        // Title — CyberPong (retrowave; majority black)
        titleLayer = SKNode()
        titleLayer.zPosition = 100
        addChild(titleLayer)
        titleWordTop = NodeFactory.titleLabel("CYBER", size: 56, color: Config.playerColor)
        titleLayer.addChild(place(titleWordTop, cx, cy + 148))
        titleWordBottom = NodeFactory.titleLabel("PONG", size: 56, color: Config.titleAccent)
        titleLayer.addChild(place(titleWordBottom, cx, cy + 86))
        titleTapLabel = NodeFactory.hudLabel("TAP TO START", size: 21, color: Config.moonColor, alpha: 0.9)
        titleTapLabel.position = CGPoint(x: cx, y: cy - 50)
        titleTapLabel.run(pulseForever())
        titleLayer.addChild(titleTapLabel)
        titleHighLabel = NodeFactory.hudLabel("HIGH SCORE 0", size: 14, color: Config.hudColor, alpha: 0.55)
        titleHighLabel.position = CGPoint(x: cx, y: cy - 120)
        titleLayer.addChild(titleHighLabel)

        // Store row. Hidden until StoreKit answers, so an offline launch or a
        // not-yet-configured product simply shows nothing rather than a dead button.
        titleStoreLabel = NodeFactory.hudLabel("", size: 13, color: Config.titleAccent, alpha: 0.9)
        titleStoreLabel.isHidden = true
        titleLayer.addChild(titleStoreLabel)
        titleRestoreLabel = NodeFactory.hudLabel("RESTORE", size: 11, color: Config.hudColor, alpha: 0.45)
        titleRestoreLabel.isHidden = true
        titleLayer.addChild(titleRestoreLabel)

        // Pause
        pauseLayer = SKNode()
        pauseLayer.zPosition = 100
        pauseDim = SKSpriteNode(color: .black,
                                size: CGSize(width: size.width * 1.2, height: size.height * 1.2))
        pauseDim.position = proj.center
        pauseDim.alpha = 0.7
        pauseLayer.addChild(pauseDim)
        pauseLayer.addChild(place(NodeFactory.titleLabel("PAUSED", size: 36, color: Config.playerColor), cx, cy + 70))
        pauseLayer.addChild(place(NodeFactory.hudLabel("TAP TO RESUME", size: 16, color: .white, alpha: 0.75), cx, cy))
        quitLabel = NodeFactory.hudLabel("QUIT", size: 20, color: Config.opponentColor, alpha: 0.95)
        quitLabel.position = CGPoint(x: cx, y: cy - 110)
        pauseLayer.addChild(quitLabel)
        pauseLayer.isHidden = true
        addChild(pauseLayer)

        // Game over / win
        gameOverLayer = SKNode()
        gameOverLayer.zPosition = 100
        goTitleLabel = NodeFactory.titleLabel("GAME OVER", size: 40, color: .white)
        goTitleLabel.position = CGPoint(x: cx, y: cy + 120)
        gameOverLayer.addChild(goTitleLabel)
        goScoreLabel = NodeFactory.hudLabel("SCORE 0", size: 22, color: Config.hudColor)
        goScoreLabel.position = CGPoint(x: cx, y: cy + 40)
        gameOverLayer.addChild(goScoreLabel)
        // Becomes chrome "NEW HIGH SCORE" when you beat the record.
        goHighLabel = NodeFactory.titleLabel("HIGH SCORE 0", size: 18, color: Config.titleChromeTop)
        goHighLabel.position = CGPoint(x: cx, y: cy - 8)
        goHighLabel.alpha = 0.85
        gameOverLayer.addChild(goHighLabel)
        let replay = NodeFactory.hudLabel("TAP TO REPLAY", size: 18, color: .white, alpha: 0.85)
        replay.position = CGPoint(x: cx, y: cy - 100)
        replay.run(pulseForever())
        gameOverLayer.addChild(replay)
        gameOverLayer.isHidden = true
        addChild(gameOverLayer)

        // Level transition
        transitionLabel = NodeFactory.titleLabel("LEVEL 2", size: 40, color: Config.playerColor)
        transitionLabel.position = CGPoint(x: cx, y: cy + 30)
        transitionLabel.zPosition = 100
        transitionLabel.isHidden = true
        addChild(transitionLabel)
    }

    private func place(_ node: PixelLabel, _ x: CGFloat, _ y: CGFloat) -> PixelLabel {
        node.position = CGPoint(x: x, y: y)
        return node
    }

    private func pulseForever() -> SKAction {
        let out = SKAction.fadeAlpha(to: 0.25, duration: 0.9)
        out.timingMode = .easeInEaseOut
        let back = SKAction.fadeAlpha(to: 0.85, duration: 0.9)
        back.timingMode = .easeInEaseOut
        return SKAction.repeatForever(SKAction.sequence([out, back]))
    }

    // MARK: - Difficulty (linear L1→L10; player paddle never ramps)

    /// 0 at L1, 1 at L10.
    private func difficultyT() -> CGFloat { Config.difficultyT(level) }

    private func levelBallSpeed() -> CGFloat {
        min(Config.lerp(Config.ballSpeedL1, Config.ballSpeedL10, difficultyT()),
            Config.ballMaxSpeed)
    }

    private func rallyIncrement() -> CGFloat {
        Config.lerp(Config.rallyIncL1, Config.rallyIncL10, difficultyT())
    }

    private func targetSpeed() -> CGFloat {
        min(levelBallSpeed() + CGFloat(rallyHits) * rallyIncrement(),
            Config.ballMaxSpeed)
    }

    /// Max |vx/vy| the ball can carry at current speed given minVzFraction.
    private func ballMaxLateralSpeed() -> CGFloat {
        let s = targetSpeed()
        let f = Config.minVzFraction
        return s * sqrt(max(0, 1 - f * f))
    }

    /// AI XY: linear raw speed, hard-leashed to a rising fraction of ball lateral.
    /// Only dial for AI difficulty: how fast the paddle can chase the ball.
    /// Linear L1→L10 — no ease curve.
    private func aiSpeed() -> CGFloat {
        let t = difficultyT()
        let raw = Config.lerp(Config.aiSpeedL1, Config.aiSpeedL10, t)
        let frac = Config.lerp(Config.aiLateralFracL1, Config.aiLateralFracL10, t)
        return min(raw, ballMaxLateralSpeed() * frac)
    }

    /// Full english from L1 — intensity scales with ball speed, not level t.
    private func englishStrength() -> CGFloat {
        Config.englishStrength
    }

    /// World-space: does the player paddle cover the (parked) serve ball?
    // MARK: - Flow

    /// Reflect purchase state on the title screen. Called on show and whenever
    /// StoreKit reports a change.
    private func refreshStoreRow() {
        guard titleStoreLabel != nil else { return }
        if Store.shared.isSupporter {
            titleStoreLabel.display("SUPPORTER")
            titleStoreLabel.tint = Config.playerColor
            titleStoreLabel.isHidden = false
            titleRestoreLabel.isHidden = true
        } else if let price = Store.shared.displayPrice {
            titleStoreLabel.display("SUPPORT \(price)")
            titleStoreLabel.tint = Config.titleAccent
            titleStoreLabel.isHidden = false
            titleRestoreLabel.isHidden = false
        } else {
            // No product (offline / not yet live) — show nothing rather than a
            // button that cannot work.
            titleStoreLabel.isHidden = true
            titleRestoreLabel.isHidden = true
        }
    }

    /// Generous tap target for the small store text.
    private func storeHit(_ node: PixelLabel?, _ loc: CGPoint) -> Bool {
        guard let node, !node.isHidden else { return false }
        return node.calculateAccumulatedFrame().insetBy(dx: -34, dy: -18).contains(loc)
    }

    private func showTitle() {
        phase = .title
        lastPhaseChange = CACurrentMediaTime()
        titleHighLabel.display("HIGH SCORE \(highScore)")
        refreshStoreRow()
        titleLayer.isHidden = false
        gameOverLayer.isHidden = true
        pauseLayer.isHidden = true
        transitionLabel.isHidden = true
        hudNode.isHidden = true
        ballNode.isHidden = true
        playerPaddleNode.isHidden = true
        oppPaddleNode.isHidden = true
        Audio.shared.setAmbient(true)
    }

    private func startRun() {
        Audio.shared.setAmbient(true)
        Audio.shared.uiTap()
        level = 1
        score = 0
        // Fresh run: plain score until (if) it surpasses highScore.
        hudScoreLabel.setStyle(.plain)
        hudScoreLabel.tint = Config.hudColor
        hudScoreLabel.alpha = 0.95
        playerLives = Config.playerLives
        opponentLives = Config.opponentLivesPerLevel
        bonuses = ScoreBonuses.fresh(
            hit: Config.hitScoreStart,
            curve: Config.curveBonusStart,
            superCurve: Config.superCurveBonusStart,
            accuracy: Config.accuracyBonusStart,
            levelClear: Config.levelClearBonusStart
        )
        px = 0; py = 0; ox = 0; oy = 0
        prevPx = 0; prevPy = 0; prevOx = 0; prevOy = 0
        playerVelX = 0; playerVelY = 0; oppVelX = 0; oppVelY = 0
        curveX = 0; curveY = 0
        touchTarget = nil
        firstTouch = .player     // fresh run: the first ball comes to you
        pointFreezeCountdown = 0
        pointCalloutLabel.isHidden = true
        hideBonusPopup()

        titleLayer.isHidden = true
        gameOverLayer.isHidden = true
        hudNode.isHidden = false
        playerPaddleNode.isHidden = false
        oppPaddleNode.isHidden = false

        updateScoreHUD()
        updateLevelHUD()
        updateLivesHUD()

        phase = .playing
        scheduleServe()
    }

    /// Park the ball for the next serve. Opponent auto-launches; you strike the ball.
    private func scheduleServe() {
        rallyHits = 0
        ballLive = false
        serveCountdown = 0
        // Every point: opponent starts centered (no crawl back from last rally).
        ox = 0; oy = 0
        ballNode.isHidden = false

        // Every point begins the same way: ball parked dead centre of the
        // tunnel, then launched toward whoever gets the first touch. Direction
        // is decided in launchBall(); the hang time here is what lets you read
        // which way it's about to go.
        bx = 0; by = 0
        bz = CourtMath.rallyStartZ(zFar: Config.zFar, fraction: Config.rallyStartZFraction)
        serveCountdown = Config.serveDelay
        renderWorld()
    }

    private func resetBonusesOnLifeLoss() {
        bonuses.reset(
            hit: Config.hitScoreStart,
            curve: Config.curveBonusStart,
            superCurve: Config.superCurveBonusStart,
            accuracy: Config.accuracyBonusStart,
            levelClear: Config.levelClearBonusStart
        )
    }

    private func showBonusPopup(_ kind: BonusPopupKind) {
        guard bonusPopupLabel != nil else { return }
        bonusPopupLabel.display(kind.rawValue)
        bonusPopupLabel.isHidden = false
        bonusPopupLabel.alpha = 1
        bonusPopupCountdown = Config.bonusPopupDuration
    }

    private func hideBonusPopup() {
        bonusPopupLabel?.isHidden = true
        bonusPopupCountdown = 0
    }

    private func tickBonusPopup(_ dt: CGFloat) {
        guard bonusPopupCountdown > 0 else { return }
        bonusPopupCountdown -= dt
        if bonusPopupCountdown <= 0 {
            hideBonusPopup()
        } else if bonusPopupCountdown < 0.2 {
            bonusPopupLabel?.alpha = max(0, bonusPopupCountdown / 0.2)
        }
    }

    /// Launch the point from tunnel centre toward whoever gets the first touch.
    private func launchBall() {
        guard !ballLive, pointFreezeCountdown <= 0 else { return }
        ballLive = true
        curveX = 0; curveY = 0
        let speed = levelBallSpeed()
        let a = CGFloat.random(in: -0.45...0.45)
        let b = CGFloat.random(in: -0.30...0.30)
        vx = speed * 0.28 * a
        vy = speed * 0.20 * b
        let vzMag = sqrt(max(speed * speed - vx * vx - vy * vy, 1))
        vz = CourtMath.rallyLaunchVz(magnitude: vzMag, towardPlayer: firstTouch == .player)
        Audio.shared.serve()
    }

    /// Brief contact cue: outer shell pops + paddle face brightens + tiny scale.
    /// Reads as a hit without dimming the paddle out.
    private func flashPaddle(_ node: SKNode) {
        guard let paddle = node as? SKShapeNode else { return }
        let up = TimeInterval(Config.paddleGlowUp)
        let down = TimeInterval(Config.paddleGlowDown)

        // Outer impact shell.
        if let glow = paddle.childNode(withName: NodeFactory.impactGlowName) {
            glow.removeAllActions()
            glow.alpha = 0
            glow.setScale(1)
            let bloom = SKAction.group([
                SKAction.fadeAlpha(to: 1, duration: up),
                SKAction.scale(to: Config.paddleGlowScale, duration: up),
            ])
            let settle = SKAction.group([
                SKAction.fadeAlpha(to: 0, duration: down),
                SKAction.scale(to: 1, duration: down),
            ])
            settle.timingMode = .easeOut
            glow.run(SKAction.sequence([bloom, settle]), withKey: "impactGlow")
        }

        // Face fill: lift alpha so the slab "pops" on contact.
        // (No root scale punch — opponent scale is owned by perspective each frame.)
        paddle.removeAction(forKey: "hitFill")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        paddle.strokeColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let baseFill = paddle.strokeColor.withAlphaComponent(Config.paddleFillAlpha)
        paddle.fillColor = paddle.strokeColor.withAlphaComponent(Config.paddleHitFillAlpha)
        let fillDown = SKAction.customAction(withDuration: down) { n, elapsed in
            let t = CGFloat(min(1, elapsed / Config.paddleGlowDown))
            let alpha = Config.paddleHitFillAlpha
                + (Config.paddleFillAlpha - Config.paddleHitFillAlpha) * t
            (n as? SKShapeNode)?.fillColor = SKColor(red: r, green: g, blue: b, alpha: alpha)
        }
        let fillRestore = SKAction.run { paddle.fillColor = baseFill }
        paddle.run(SKAction.sequence([fillDown, fillRestore]), withKey: "hitFill")
    }

    /// Ball crossed a plane without a paddle — freeze briefly; hearts update
    /// immediately (no POINT/MISS text — the missing heart is the message).
    private func beginPointFreeze(playerScored: Bool, atX x: CGFloat, y: CGFloat, z: CGFloat) {
        guard pointFreezeCountdown <= 0, phase == .playing else { return }
        ballLive = false
        bx = x; by = y; bz = z
        vx = 0; vy = 0; vz = 0
        curveX = 0; curveY = 0
        pendingPointWin = playerScored
        pointFreezeCountdown = Config.pointFreezeDuration
        pointCalloutLabel?.isHidden = true

        if playerScored {
            score += Config.scorePerOpponentLife * level
            opponentLives -= 1
            updateScoreHUD()
            updateLivesHUD()
            Haptics.shared.pointScored()
            Audio.shared.pointScored()
        } else {
            // Hearts are SPARE lives. 0 → -1 ends the run after freeze.
            playerLives -= 1
            resetBonusesOnLifeLoss()
            updateLivesHUD()
            Haptics.shared.lifeLost()
            Audio.shared.lifeLost()
            playShake()
        }
        pulseRing(atZ: z)
        renderWorld()
    }

    private func resolvePointFreeze() {
        if pendingPointWin {
            firstTouch = CourtMath.firstTouchGoesToPlayer(playerWonLastPoint: true) ? .player : .opponent
            if opponentLives <= 0 {
                levelUp()
            } else {
                scheduleServe()
            }
        } else {
            firstTouch = CourtMath.firstTouchGoesToPlayer(playerWonLastPoint: false) ? .player : .opponent
            if playerLives < 0 {
                endRun()
            } else {
                scheduleServe()
            }
        }
    }

    /// Reset position first so a replaced mid-shake action can't leave the court offset.
    private func playShake() {
        worldNode.removeAction(forKey: "shake")
        worldNode.position = .zero
        worldNode.run(shakeAction, withKey: "shake")
    }

    private func levelUp() {
        // Endless: levels keep counting past Config.maxLevel; only the
        // difficulty curve clamps there (see Config.difficultyT).
        level += 1
        opponentLives = Config.opponentLivesPerLevel
        // Earn a spare back for clearing a level — but only up to the cap, so
        // a clean level grants nothing and the pressure never fully lifts.
        playerLives = min(playerLives + Config.lifeGainPerLevel, Config.playerLivesMax)
        // Bank remaining level-clear bonus (rewards fast aggressive clears).
        score += bonuses.bankLevelClear(resetTo: Config.levelClearBonusStart)
        updateScoreHUD()
        updateLevelHUD()
        updateLivesHUD()
        Haptics.shared.levelUp()
        Audio.shared.levelUp()
        transitionLabel.display("LEVEL \(level)")
        transitionLabel.isHidden = false
        ballNode.isHidden = true
        curveX = 0; curveY = 0
        transitionCountdown = Config.levelTransitionDuration
        phase = .levelTransition
    }

    private func endTransition() {
        transitionLabel.isHidden = true
        phase = .playing
        firstTouch = .player     // new level is a gift: ball comes to you
        ballNode.isHidden = false
        scheduleServe()
    }

    private func endRun() {
        // Capture before saveHighScoreIfNeeded overwrites highScore.
        let isNewHigh = score > highScore && score > 0
        saveHighScoreIfNeeded()
        goTitleLabel.removeAllActions()
        goHighLabel.removeAllActions()
        goTitleLabel.setScale(1)
        goHighLabel.setScale(1)

        if isNewHigh {
            // Celebrate: chrome title, pulse, stronger feedback.
            goTitleLabel.display("NEW HIGH")
            goScoreLabel.display("SCORE \(score)")
            goHighLabel.display("HIGH SCORE \(highScore)")
            goHighLabel.alpha = 1
            goTitleLabel.run(pulseForever())
            goHighLabel.run(pulseForever())
            Haptics.shared.levelUp()
            Audio.shared.levelUp()
        } else {
            goTitleLabel.display("GAME OVER")
            goScoreLabel.display("SCORE \(score)")
            goHighLabel.display("HIGH SCORE \(highScore)")
            goHighLabel.alpha = 0.85
        }
        gameOverLayer.isHidden = false
        ballNode.isHidden = true
        playerPaddleNode.isHidden = true
        oppPaddleNode.isHidden = true
        pointCalloutLabel.isHidden = true
        phase = .gameOver
        lastPhaseChange = CACurrentMediaTime()
    }

    private func saveHighScoreIfNeeded() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "highScore")
        }
    }

    private func pauseGame() {
        guard phase == .playing else { return }
        phase = .paused
        pauseLayer.isHidden = false
    }

    private func resumeGame() {
        pauseLayer.isHidden = true
        phase = .playing
    }

    private func quitToTitle() {
        saveHighScoreIfNeeded()
        showTitle()
    }

    // MARK: - HUD updates (event-driven; nothing here runs per frame)

    private func updateScoreHUD() {
        hudScoreLabel.display("\(score)")
        // Once this run beats the saved high score, score stays chrome (title/LVL)
        // for the rest of the run as a live high-score achievement cue.
        if score > highScore && score > 0 {
            hudScoreLabel.setStyle(.chrome)
            hudScoreLabel.alpha = 1
        } else {
            hudScoreLabel.setStyle(.plain)
            hudScoreLabel.tint = Config.hudColor
            hudScoreLabel.alpha = 0.95
        }
    }
    private func updateLevelHUD() { hudLevelLabel.display("LVL \(level)") }
    private func updateLivesHUD() {
        // Hearts are spare lives. An empty row is the warning — you're on your
        // last life — so it needs no label.
        hudPlayerLives.display(String(repeating: "♥", count: max(playerLives, 0)))
        hudOppLives.display(String(repeating: "♥", count: max(opponentLives, 0)))
        hudPlayerLives.isHidden = false
        hudOppLives.isHidden = false
        hudPlayerLives.alpha = 1
        hudOppLives.alpha = 0.95
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat
        if lastUpdate == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = CGFloat(min(currentTime - lastUpdate, 1.0 / 20.0))
        }
        lastUpdate = currentTime

        switch phase {
        case .playing:
            stepPlayer(dt)
            tickBonusPopup(dt)
            if pointFreezeCountdown > 0 {
                pointFreezeCountdown -= dt
                if pointFreezeCountdown <= 0 { resolvePointFreeze() }
            } else {
                stepBall(dt)
                stepAI(dt)
            }
            renderWorld()
        case .levelTransition:
            stepPlayer(dt)
            tickBonusPopup(dt)
            transitionCountdown -= dt
            if transitionCountdown <= 0 { endTransition() }
            renderWorld()
        case .title, .paused, .gameOver:
            break
        }
    }

    // MARK: - Player paddle

    private func stepPlayer(_ dt: CGFloat) {
        guard let target = touchTarget else {
            playerVelX = CourtMath.smoothToward(playerVelX, sample: 0, alpha: Config.paddleVelSmooth)
            playerVelY = CourtMath.smoothToward(playerVelY, sample: 0, alpha: Config.paddleVelSmooth)
            prevPx = px; prevPy = py
            return
        }
        // Lag toward target so paddle velocity is real (curve needs a signal).
        let alpha = CourtMath.followAlpha(lerpPerFrame: Config.paddleFollowLerp, dt: max(dt, 1.0 / 240))
        px += (target.x - px) * alpha
        py += (target.y - py) * alpha
        clampPlayer()

        if dt > 0.0001 {
            let rawVx = (px - prevPx) / dt
            let rawVy = (py - prevPy) / dt
            let a = Config.paddleVelSmooth
            playerVelX = CourtMath.smoothToward(playerVelX, sample: rawVx, alpha: a)
            playerVelY = CourtMath.smoothToward(playerVelY, sample: rawVy, alpha: a)
        }
        prevPx = px
        prevPy = py
    }

    private func clampPlayer() {
        let mx = max(0, halfW - Config.playerPaddleHalfW)
        let my = max(0, halfH - Config.playerPaddleHalfH)
        px = max(-mx, min(mx, px))
        py = max(-my, min(my, py))
    }

    private func clampOpponent() {
        // Match stepAI wall inset (half paddle-width gap beyond flush).
        let mx = max(0, halfW - Config.oppPaddleHalfW * Config.aiWallInsetPaddles)
        let my = max(0, halfH - Config.oppPaddleHalfH * Config.aiWallInsetPaddles)
        ox = max(-mx, min(mx, ox))
        oy = max(-my, min(my, oy))
    }

    private func clampBallXY() {
        let effW = max(0, halfW - Config.ballRadius)
        let effH = max(0, halfH - Config.ballRadius)
        bx = max(-effW, min(effW, bx))
        by = max(-effH, min(effH, by))
    }

    /// Absolute mapping — Mac pointer only. Screen → world at z = 0 is a
    /// straight offset from centre (scale = 1), so the paddle sits under the
    /// cursor.
    private func setTouchTarget(_ loc: CGPoint) {
        let wx = loc.x - proj.center.x
        let wy = loc.y - proj.center.y
        // Target only — stepPlayer lerps so velocity/curve stay meaningful.
        let mx = max(0, halfW - Config.playerPaddleHalfW)
        let my = max(0, halfH - Config.playerPaddleHalfH)
        touchTarget = CGPoint(x: max(-mx, min(mx, wx)),
                              y: max(-my, min(my, wy)))
    }

    // MARK: - Touch: elastic trackpad (iOS)
    //
    // The phone does NOT map the paddle to the absolute touch point. Reaching
    // the far corners of a 6.9" screen one-handed means stretching your thumb
    // off the grip. Instead the finger works like a trackpad: wherever you
    // press becomes the origin, and the paddle moves `touchGain`× further than
    // your thumb does, so the whole court is covered by a short, comfortable
    // swipe anywhere on the glass.

    /// Where the current drag started, and where the paddle was at that moment.
    private var dragAnchorScreen: CGPoint?
    private var dragAnchorPaddle: CGPoint = .zero

    private func beginRelativeDrag(at loc: CGPoint) {
        dragAnchorScreen = loc
        dragAnchorPaddle = CGPoint(x: px, y: py)
        touchTarget = dragAnchorPaddle          // hold still until the thumb moves
    }

    private func updateRelativeDrag(to loc: CGPoint) {
        guard let anchor = dragAnchorScreen else { return }
        let g = Config.touchGain
        let wantX = dragAnchorPaddle.x + (loc.x - anchor.x) * g
        let wantY = dragAnchorPaddle.y + (loc.y - anchor.y) * g

        let mx = max(0, halfW - Config.playerPaddleHalfW)
        let my = max(0, halfH - Config.playerPaddleHalfH)
        let clampedX = max(-mx, min(mx, wantX))
        let clampedY = max(-my, min(my, wantY))

        // Elastic re-anchor: if the paddle is pinned against a wall, move the
        // origin to the thumb's current spot. Without this the thumb builds up
        // "debt" past the edge and the paddle sits dead until you drag all the
        // way back — the classic relative-control trap.
        if clampedX != wantX || clampedY != wantY {
            dragAnchorScreen = loc
            dragAnchorPaddle = CGPoint(x: clampedX, y: clampedY)
        }

        // Target only — stepPlayer owns position + velocity smoothing.
        touchTarget = CGPoint(x: clampedX, y: clampedY)
    }

    /// Mac Catalyst: paddle follows the mouse with no click held.
    /// Hover never serves — that needs a click or click-drag (see touches*).
    func pointerMoved(to loc: CGPoint) {
        guard phase == .playing || phase == .levelTransition else { return }
        setTouchTarget(loc)
    }

    // MARK: - Ball

    private func stepBall(_ dt: CGFloat) {
        if !ballLive {
            // Opponent auto-serve only (player serve waits for click/tap).
            if serveCountdown > 0 {
                serveCountdown -= dt
                if serveCountdown <= 0 { launchBall() }
            }
            return
        }

        // Level-clear bank decays while the ball is live (rewards fast clears).
        bonuses.tickLevelClear(dt: dt, decayPerSecond: Config.levelClearDecayPerSecond)

        // Curve integration BEFORE position — banana arc (dt-based decay).
        CourtMath.applyCurveStep(
            vx: &vx, vy: &vy, vz: &vz,
            curveX: &curveX, curveY: &curveY,
            dt: dt,
            curveDecayPerSecond: Config.curveDecayPerSecond,
            minVzFraction: Config.minVzFraction
        )

        let prevX = bx, prevY = by, prevZ = bz
        bx += vx * dt
        by += vy * dt
        bz += vz * dt

        // Roll: a ball travelling sideways turns about the view axis. Driving
        // this off vx alone (rather than total speed) means a straight shot
        // down the tunnel barely spins, while a cut shot visibly tumbles.
        ballSpin -= (vx / max(Config.ballRadius, 1)) * dt * Config.ballSpinFactor

        // Wall bounces: positional reflection keeps the ball inside the court
        // even on a long frame. Flip + damp curve on the reflected axis.
        let effW = halfW - Config.ballRadius
        let effH = halfH - Config.ballRadius
        if bx > effW {
            bx = 2 * effW - bx; vx = -vx
            CourtMath.wallBounceCurve(curveX: &curveX, curveY: &curveY,
                                      flipX: true, flipY: false,
                                      damp: Config.curveWallDamp)
            wallBounce()
        } else if bx < -effW {
            bx = -2 * effW - bx; vx = -vx
            CourtMath.wallBounceCurve(curveX: &curveX, curveY: &curveY,
                                      flipX: true, flipY: false,
                                      damp: Config.curveWallDamp)
            wallBounce()
        }
        if by > effH {
            by = 2 * effH - by; vy = -vy
            CourtMath.wallBounceCurve(curveX: &curveX, curveY: &curveY,
                                      flipX: false, flipY: true,
                                      damp: Config.curveWallDamp)
            wallBounce()
        } else if by < -effH {
            by = -2 * effH - by; vy = -vy
            CourtMath.wallBounceCurve(curveX: &curveX, curveY: &curveY,
                                      flipX: false, flipY: true,
                                      damp: Config.curveWallDamp)
            wallBounce()
        }

        // --- Paddle collisions, sampled by z-crossing ---------------------
        // World-space rect + ball radius + slop (glow made the paddle look
        // bigger than the old hitbox; slop + larger paddle close that gap).

        let pSlop = Config.paddleHitSlop
        let pHitW = Config.playerPaddleHalfW + Config.ballRadius + pSlop
        let pHitH = Config.playerPaddleHalfH + Config.ballRadius + pSlop
        let oHitW = Config.oppPaddleHalfW + Config.ballRadius + pSlop
        let oHitH = Config.oppPaddleHalfH + Config.ballRadius + pSlop

        if prevZ > 0 && bz <= 0 && vz < 0 {
            let t = prevZ / (prevZ - bz)
            let xc = prevX + (bx - prevX) * t
            let yc = prevY + (by - prevY) * t
            if abs(xc - px) <= pHitW, abs(yc - py) <= pHitH {
                hitPaddle(xc: xc, yc: yc, cx: px, cy: py,
                          paddleHalfW: Config.playerPaddleHalfW,
                          paddleHalfH: Config.playerPaddleHalfH,
                          paddleVelX: playerVelX, paddleVelY: playerVelY,
                          newZ: 0.1, outbound: true, awardScore: true)
                rallyHits += 1
                Haptics.shared.paddleHit()
                Audio.shared.paddleHit(player: true)
            } else {
                // Miss: stop on the plane — no fly-through past the camera.
                beginPointFreeze(playerScored: false, atX: xc, y: yc, z: 0)
                return
            }
        }

        if prevZ < Config.zFar && bz >= Config.zFar && vz > 0 {
            let t = (Config.zFar - prevZ) / (bz - prevZ)
            let xc = prevX + (bx - prevX) * t
            let yc = prevY + (by - prevY) * t
            if abs(xc - ox) <= oHitW, abs(yc - oy) <= oHitH {
                hitPaddle(xc: xc, yc: yc, cx: ox, cy: oy,
                          paddleHalfW: Config.oppPaddleHalfW,
                          paddleHalfH: Config.oppPaddleHalfH,
                          paddleVelX: oppVelX, paddleVelY: oppVelY,
                          newZ: Config.zFar - 0.1, outbound: false, awardScore: false)
                Haptics.shared.paddleHit()
                Audio.shared.paddleHit(player: false)
            } else {
                beginPointFreeze(playerScored: true, atX: xc, y: yc, z: Config.zFar)
                return
            }
        }

        // Safety net if a frame skips the plane entirely.
        if bz < -40 {
            beginPointFreeze(playerScored: false, atX: bx, y: by, z: 0)
        } else if bz > Config.zFar + 40 {
            beginPointFreeze(playerScored: true, atX: bx, y: by, z: Config.zFar)
        }
    }

    private func hitPaddle(xc: CGFloat, yc: CGFloat, cx: CGFloat, cy: CGFloat,
                           paddleHalfW: CGFloat, paddleHalfH: CGFloat,
                           paddleVelX: CGFloat, paddleVelY: CGFloat,
                           newZ: CGFloat, outbound: Bool, awardScore: Bool) {
        let speed = sqrt(vx * vx + vy * vy + vz * vz)
        // Contact-offset english (demoted) + paddle-velocity curve (dominant).
        let nX = max(-1, min(1, (xc - cx) / max(paddleHalfW, 1)))
        let nY = max(-1, min(1, (yc - cy) / max(paddleHalfH, 1)))
        let corner = abs(nX) * abs(nY)
        let eng = englishStrength() * (1 + Config.serveCornerBoost * corner * 0.55)
        vx += nX * eng * speed
        vy += nY * eng * speed
        vz = outbound ? abs(vz) : -abs(vz)

        // Player (outbound): invert brush English — matches Curveball `(-pSpeedX, …)`.
        // AI (inbound): same-direction — matches Curveball enemy `(+eSpeedX, …)`.
        let c = CourtMath.curveFromPaddleVelocity(
            paddleVelX: paddleVelX, paddleVelY: paddleVelY,
            scale: Config.curveFromPaddleVel, maxMag: Config.curveMax,
            invert: outbound)
        curveX = c.0
        curveY = c.1

        bx = xc; by = yc; bz = newZ
        applySpeed(targetSpeed())

        if awardScore {
            let result = HitScoring.scorePlayerHit(
                bonuses: &bonuses,
                curveX: curveX, curveY: curveY,
                curveBonusThreshold: Config.curveBonusThreshold,
                curveSuperThreshold: Config.curveSuperThreshold,
                offsetFracX: nX, offsetFracY: nY,
                accuracyWindowFrac: Config.accuracyWindowFrac,
                hitDegrade: Config.hitScoreDegrade,
                curveDegrade: Config.curveBonusDegrade,
                superDegrade: Config.superCurveBonusDegrade,
                accuracyDegrade: Config.accuracyBonusDegrade
            )
            score += result.points
            updateScoreHUD()
            // Show the flashiest popup that applied (super > curve > perfect).
            if let top = result.popups.first {
                showBonusPopup(top)
            }
        }

        // Outbound = you struck (near plane); inbound return = opponent struck.
        flashPaddle(outbound ? playerPaddleNode : oppPaddleNode)
        pulseRing(atZ: newZ)
    }

    private func applySpeed(_ speed: CGFloat) {
        CourtMath.renormVelocity(vx: &vx, vy: &vy, vz: &vz,
                                 speed: speed, minVzFraction: Config.minVzFraction)
    }

    private func wallBounce() {
        Haptics.shared.wallBounce()
        Audio.shared.wallBounce()
        pulseRing(atZ: bz)
    }

    private func pulseRing(atZ z: CGFloat) {
        let idx = CourtMath.ringIndex(z: z, zFar: Config.zFar, ringCount: Config.ringCount)
        guard idx >= 0, idx < rings.count else { return }
        let ring = rings[idx]
        ring.removeAction(forKey: "pulse")
        ring.strokeColor = Config.wallNeonPink
        ring.run(ringPulses[idx], withKey: "pulse")
    }

    // MARK: - Opponent AI
    //
    // Pure ball XY tracking. Chase the ball's *current* world XY as hard as
    // aiSpeed allows — never the future intercept, never wall-bounce folds.
    // (Predicting "where it will land" is how it used to feel psychic.)
    // No aim error, no reaction delay, no corner hunting.
    // Difficulty is ONLY "it gets faster" (Config.aiSpeedL1 → L10).

    private func stepAI(_ dt: CGFloat) {
        // Between points / before serve: park center.
        if !ballLive {
            ox = 0; oy = 0
            oppVelX = 0; oppVelY = 0
            prevOx = ox; prevOy = oy
            return
        }

        // Live ball position only. Clamp to the ball's wall bounds so the AI
        // never aims outside the court when the ball is in a corner.
        let effW = halfW - Config.ballRadius
        let effH = halfH - Config.ballRadius
        let tx = max(-effW, min(effW, bx))
        let ty = max(-effH, min(effH, by))

        let step = aiSpeed() * dt
        ox = CourtMath.moveToward(ox, target: tx, maxStep: step)
        oy = CourtMath.moveToward(oy, target: ty, maxStep: step)

        // D1: center stays half a paddle-width off the wall beyond flush so
        // wall-hug shots remain a scoring lane at high levels.
        let mx = max(0, halfW - Config.oppPaddleHalfW * Config.aiWallInsetPaddles)
        let my = max(0, halfH - Config.oppPaddleHalfH * Config.aiWallInsetPaddles)
        ox = max(-mx, min(mx, ox))
        oy = max(-my, min(my, oy))

        // Paddle velocity from this frame's motion (feeds curve on contact).
        if dt > 0.0001 {
            let rawVx = (ox - prevOx) / dt
            let rawVy = (oy - prevOy) / dt
            let a = Config.paddleVelSmooth
            oppVelX = CourtMath.smoothToward(oppVelX, sample: rawVx, alpha: a)
            oppVelY = CourtMath.smoothToward(oppVelY, sample: rawVy, alpha: a)
        }
        prevOx = ox
        prevOy = oy
    }

    // MARK: - Rendering (positions + one perspective scale; no allocations)

    /// Ride a small dot along each of the four corner rails at the ball's depth.
    ///
    /// This is the z-axis readout. The x/y walls deliberately stay dark until
    /// individually struck — that is what makes a wall hit read as a hit — so
    /// depth gets its own channel on the only geometry that runs along z. The
    /// dot borrows the wall-impact colour so the two cues read as one family.
    ///
    /// The dot rides the same perspective as everything else, so it creeps
    /// while the ball is far and accelerates as it arrives. That acceleration
    /// is the timing cue; it needs no extra length or animation.
    private func updateDepthTracker() {
        guard !depthDots.isEmpty else { return }
        guard !ballNode.isHidden else {
            for d in depthDots { d.isHidden = true }
            return
        }

        let z = min(max(bz, Config.railNearExtendZ), Config.zFar)
        // Floor the scale so the dot stays visible against the far wall, where
        // raw perspective would shrink it below a pixel.
        let sc = max(proj.scale(z: z), Config.depthDotMinScale)

        var i = 0
        for sx: CGFloat in [-1, 1] {
            for sy: CGFloat in [-1, 1] {
                guard i < depthDots.count else { break }
                depthDots[i].position = Config.snapPoint(railAnchor(sx: sx, sy: sy, z: z))
                depthDots[i].setScale(sc)
                depthDots[i].isHidden = false
                i += 1
            }
        }
    }

    private func renderWorld() {
        // Pixel-snap every actor: continuous physics, discrete picture.
        playerPaddleNode.position = Config.snapPoint(proj.project(x: px, y: py, z: 0))
        oppPaddleNode.position = Config.snapPoint(proj.project(x: ox, y: oy, z: Config.zFar))
        // Quantize far paddle scale to keep slab edges on-grid.
        let oppS = proj.scale(z: Config.zFar)
        oppPaddleNode.setScale(quantizeScale(oppS))

        let ballScale = proj.scale(z: bz)
        ballNode.position = Config.snapPoint(proj.project(x: bx, y: by, z: bz))
        ballNode.setScale(quantizeScale(ballScale))
        // Spin ticks through discrete sprite frames.
        let step = (2 * CGFloat.pi) / Config.ballSpinSteps
        ballSpinLayer?.zRotation = (ballSpin / step).rounded() * step
        ballNode.isHidden = (phase == .title || phase == .gameOver)
        updateDepthTracker()

        if ballShadowNode != nil {
            let showShadow = !ballNode.isHidden && (ballLive || serveCountdown > 0 || pointFreezeCountdown > 0)
            ballShadowNode.isHidden = !showShadow
            if showShadow {
                let heightFrac = max(0, min(1, (by + halfH) / max(2 * halfH, 1)))
                // Two-step alpha only (near floor / high in court).
                ballShadowNode.alpha = heightFrac > 0.55 ? Config.ballShadowAlpha * 0.4 : Config.ballShadowAlpha
                ballShadowNode.position = Config.snapPoint(
                    proj.project(x: bx, y: -halfH * 0.98, z: bz))
                ballShadowNode.setScale(quantizeScale(ballScale))
            }
        }

        if ballLive {
            trailHistory.insert((bx, by, bz), at: 0)
            if trailHistory.count > Config.trailLength {
                trailHistory.removeLast(trailHistory.count - Config.trailLength)
            }
        } else {
            trailHistory.removeAll(keepingCapacity: true)
        }
        for (i, ghost) in trailGhosts.enumerated() {
            if i < trailHistory.count, ballLive {
                let h = trailHistory[i]
                let t = CGFloat(i) / CGFloat(max(Config.trailLength - 1, 1))
                ghost.isHidden = false
                ghost.position = Config.snapPoint(proj.project(x: h.x, y: h.y, z: h.z))
                let s = proj.scale(z: h.z)
                    * NodeFactory.lerp(Config.trailScaleHead, Config.trailScaleTail, t)
                ghost.setScale(quantizeScale(s))
                // Stepped trail alpha rather than a continuous fade. Hoisted to
                // a stored constant — building this array inline allocated once
                // per ghost per frame (~300 heap allocations/second).
                ghost.alpha = GameScene.trailAlphaSteps[min(i, GameScene.trailAlphaSteps.count - 1)]
            } else {
                ghost.isHidden = true
            }
        }

    }

    /// Keep perspective scale continuous enough to read depth, but bias toward
    /// values that don't smear a 1-pixel stroke into half-pixels.
    private func quantizeScale(_ s: CGFloat) -> CGFloat {
        // 32 steps between 0 and 1 is plenty for GBC depth layers.
        let steps: CGFloat = 32
        return max(1 / steps, (s * steps).rounded() / steps)
    }

    // MARK: - Touch handling
    //
    // Serve: ball is fixed center. Position paddle over it (any part of the
    // face counts). Mac: click to strike (hover aims — click does NOT jump
    // the paddle). iOS: finger aims; swipe while overlapping = spin serve.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        switch phase {
        case .title, .gameOver:
            // Brief lockout so a stray tap right at game over doesn't restart.
            guard CACurrentMediaTime() - lastPhaseChange > 0.45 else { return }
            // Store controls sit on the title screen where *any* tap starts a
            // run, so they have to be claimed first or they'd be unreachable.
            if phase == .title, !Store.shared.isSupporter {
                if storeHit(titleStoreLabel, loc) {
                    Audio.shared.uiTap()
                    Task { _ = await Store.shared.purchase() }
                    return
                }
                if storeHit(titleRestoreLabel, loc) {
                    Audio.shared.uiTap()
                    Task { _ = await Store.shared.restore() }
                    return
                }
            }
            startRun()
        case .paused:
            if quitLabel.calculateAccumulatedFrame().insetBy(dx: -40, dy: -30).contains(loc) {
                quitToTitle()
            } else {
                resumeGame()
            }
        case .playing:
            if pauseButton.calculateAccumulatedFrame().insetBy(dx: -18, dy: -18).contains(loc) {
                pauseGame()
                return
            }
            #if targetEnvironment(macCatalyst)
            // Hover owns aim on Mac; clicks are UI / serve only.
            #else
            beginRelativeDrag(at: loc)
            #endif
        case .levelTransition:
            #if !targetEnvironment(macCatalyst)
            beginRelativeDrag(at: loc)
            #endif
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing || phase == .levelTransition,
              let touch = touches.first else { return }
        let loc = touch.location(in: self)

        #if !targetEnvironment(macCatalyst)
        updateRelativeDrag(to: loc)
        #endif
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        #if targetEnvironment(macCatalyst)
        // Keep last aim; hover continues tracking without a click.
        #else
        dragAnchorScreen = nil
        touchTarget = nil
        #endif
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        #if targetEnvironment(macCatalyst)
        #else
        dragAnchorScreen = nil
        touchTarget = nil
        #endif
    }
}
