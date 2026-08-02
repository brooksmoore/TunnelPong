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

    // MARK: - Run state

    private var level = 1
    private var score = 0
    private var playerLives = Config.playerLives
    private var opponentLives = Config.opponentLivesPerLevel
    private var rallyHits = 0
    private var highScore = UserDefaults.standard.integer(forKey: "highScore")

    // MARK: - Ball (world coordinates)

    private var bx: CGFloat = 0, by: CGFloat = 0, bz: CGFloat = 0
    private var vx: CGFloat = 0, vy: CGFloat = 0, vz: CGFloat = 0
    private var ballLive = false           // false while waiting to serve / frozen
    private var serveCountdown: CGFloat = 0
    /// You serve first each round; after a miss the opponent auto-serves.
    private enum Server { case player, opponent }
    private var nextServer: Server = .player
    private var awaitingPlayerServe = false
    /// Point just scored — ball held on the plane with a callout.
    private var pointFreezeCountdown: CGFloat = 0
    private var pendingPointWin = false   // true = you scored, false = you lost a life
    // Serve strike tracking (Mac: click/drag on ball; iOS: drag across ball).
    private var serveDragPrev: CGPoint?
    private var serveDragDelta: CGPoint = .zero

    // MARK: - Paddles (world coordinates)

    private var px: CGFloat = 0, py: CGFloat = 0        // player, at z = 0
    private var touchTarget: CGPoint?                   // where the finger wants the paddle
    private var ox: CGFloat = 0, oy: CGFloat = 0        // opponent, at z = zFar
    // AI is pure tracking — no aim error / reaction delay (see stepAI).

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
    private var gridLines: [SKShapeNode] = []
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
    private var serveReadyShown: Bool?
    private var playerPaddleNode: SKShapeNode!
    private var oppPaddleNode: SKShapeNode!

    private var hudNode: SKNode!
    private var hudLevelLabel: PixelLabel!
    private var hudScoreLabel: PixelLabel!
    private var hudPlayerLives: PixelLabel!
    private var hudOppLives: PixelLabel!
    private var pauseButton: PixelLabel!
    private var serveHintLabel: PixelLabel!
    private var pointCalloutLabel: PixelLabel!

    private var titleLayer: SKNode!
    private var titleHighLabel: PixelLabel!
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
        proj.center = CGPoint(x: size.width / 2, y: size.height / 2)
        halfW = size.width / 2 * Config.courtWidthFactor
        halfH = size.height / 2 * Config.courtHeightFactor

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

    /// Call after safeInsets or size change (Mac resize, notch, titlebar).
    /// Court geometry stays screen-centered; only chrome (HUD / title) moves into the safe band.
    func applyChromeLayout() {
        proj.center = CGPoint(x: size.width / 2, y: size.height / 2)
        halfW = size.width / 2 * Config.courtWidthFactor
        halfH = size.height / 2 * Config.courtHeightFactor
        // halfW/halfH ARE the ball's walls, so the drawn tunnel has to be
        // rebuilt from them — repositioning alone would leave the wireframe
        // describing the old court after a Mac window resize.
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
    /// Rebuilt only when the frame actually changes size.
    private func rebuildBackdrop() {
        guard size.width > 0, size.height > 0, size != backdropSize else { return }
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
    private func rebuildTunnelGeometry() {
        for (i, node) in rings.enumerated() {
            let t = CourtMath.ringT(index: i, ringCount: Config.ringCount)
            let s = proj.scale(z: Config.zFar * t)
            let w = halfW * s, h = halfH * s
            // Keep far ring rectangular (not a disc) so rails meet a clean frame.
            let r = min(Config.ringCornerRadius * s, min(w, h) * 0.22)
            let rect = CGRect(x: -w, y: -h, width: 2 * w, height: 2 * h)
            node.path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
            node.position = proj.center
            if i < depthPanels.count {
                depthPanels[i].path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
                depthPanels[i].position = proj.center
            }
        }
        // Four continuous corner rails from the near plane to the vanishing point.
        var i = 0
        for sx: CGFloat in [-1, 1] {
            for sy: CGFloat in [-1, 1] {
                guard i < railSegments.count else { break }
                let path = CGMutablePath()
                path.move(to: proj.project(x: sx * halfW, y: sy * halfH, z: 0))
                path.addLine(to: proj.project(x: sx * halfW, y: sy * halfH, z: Config.zFar))
                railSegments[i].path = path
                railSegments[i].strokeColor = Config.wallNeonPink
                railSegments[i].lineWidth = Config.railLineWidth
                railSegments[i].alpha = Config.cornerLineAlpha
                i += 1
            }
        }
        rebuildGridPaths()
    }

    /// Floor + ceiling depth rungs and longitudinal rails down all four faces.
    private func rebuildGridPaths() {
        guard !gridLines.isEmpty else { return }
        var idx = 0
        // Depth rungs on floor and ceiling.
        for faceY: CGFloat in [-1, 1] {
            for d in 0..<Config.gridDepthLines {
                guard idx < gridLines.count else { return }
                let t = CGFloat(d + 1) / CGFloat(Config.gridDepthLines + 1)
                let z = Config.zFar * t
                let path = CGMutablePath()
                path.move(to: proj.project(x: -halfW, y: faceY * halfH, z: z))
                path.addLine(to: proj.project(x: halfW, y: faceY * halfH, z: z))
                gridLines[idx].path = path
                gridLines[idx].strokeColor = Config.wallNeonPink
                gridLines[idx].alpha = NodeFactory.lerp(Config.gridAlphaNear, Config.gridAlphaFar, t)
                gridLines[idx].lineWidth = Config.gridLineWidthNear
                idx += 1
            }
        }
        // Depth rungs on left and right walls.
        for faceX: CGFloat in [-1, 1] {
            for d in 0..<Config.gridDepthLines {
                guard idx < gridLines.count else { return }
                let t = CGFloat(d + 1) / CGFloat(Config.gridDepthLines + 1)
                let z = Config.zFar * t
                let path = CGMutablePath()
                path.move(to: proj.project(x: faceX * halfW, y: -halfH, z: z))
                path.addLine(to: proj.project(x: faceX * halfW, y: halfH, z: z))
                gridLines[idx].path = path
                gridLines[idx].strokeColor = Config.wallNeonPink
                gridLines[idx].alpha = NodeFactory.lerp(Config.gridAlphaNear, Config.gridAlphaFar, t)
                gridLines[idx].lineWidth = Config.gridLineWidthNear
                idx += 1
            }
        }
        // Longitudinal face lines (off when gridLongLines == 0 — rings + rails only).
        for face in 0..<4 {
            for k in 0..<Config.gridLongLines {
                guard idx < gridLines.count else { return }
                let u = CGFloat(k + 1) / CGFloat(Config.gridLongLines + 1)
                let path = CGMutablePath()
                switch face {
                case 0:
                    let x = -halfW + 2 * halfW * u
                    path.move(to: proj.project(x: x, y: -halfH, z: 0))
                    path.addLine(to: proj.project(x: x, y: -halfH, z: Config.zFar))
                case 1:
                    let x = -halfW + 2 * halfW * u
                    path.move(to: proj.project(x: x, y: halfH, z: 0))
                    path.addLine(to: proj.project(x: x, y: halfH, z: Config.zFar))
                case 2:
                    let y = -halfH + 2 * halfH * u
                    path.move(to: proj.project(x: -halfW, y: y, z: 0))
                    path.addLine(to: proj.project(x: -halfW, y: y, z: Config.zFar))
                default:
                    let y = -halfH + 2 * halfH * u
                    path.move(to: proj.project(x: halfW, y: y, z: 0))
                    path.addLine(to: proj.project(x: halfW, y: y, z: Config.zFar))
                }
                gridLines[idx].path = path
                gridLines[idx].strokeColor = Config.wallNeonPink
                gridLines[idx].alpha = Config.gridAlphaNear * 0.7
                gridLines[idx].lineWidth = Config.gridLineWidthNear
                idx += 1
            }
        }
    }

    private func layoutHUD() {
        guard hudNode != nil, hudPlayerLives != nil else { return }
        let topSafe = max(safeInsets.top, 0)
        let bottomY = layoutBottomInset
        let sidePad = max(safeInsets.left, safeInsets.right, 10) + 8
        let cx = size.width / 2

        // Hearts in the status-bar / Dynamic Island *ear* band (left & right of
        // the island). Level + score sit fully under the safe top so they never
        // land on the notch.
        let heartsY: CGFloat = topSafe >= 44
            ? size.height - topSafe * 0.48
            : size.height - topSafe - 12
        let chromeY = size.height - topSafe - Config.hudTopPad

        hudPlayerLives.position = CGPoint(x: sidePad, y: heartsY)
        hudOppLives.position = CGPoint(x: size.width - sidePad, y: heartsY)
        hudLevelLabel.position = CGPoint(x: cx, y: chromeY)
        hudScoreLabel.position = CGPoint(x: cx, y: chromeY - Config.hudScoreGap)
        pauseButton.position = CGPoint(x: size.width - sidePad - 10, y: bottomY)
        serveHintLabel.position = CGPoint(x: cx, y: bottomY + 32)
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
        let kids = titleLayer.children
        if kids.count >= 4 {
            kids[0].position = CGPoint(x: cx, y: cyberY)
            kids[1].position = CGPoint(x: cx, y: pongY)
            kids[2].position = CGPoint(x: cx, y: cy - 50)
            kids[3].position = CGPoint(x: cx, y: cy - 110)
        }
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

        // Perspective grid on floor / ceiling / walls.
        let gridCount = Config.gridDepthLines * 4 + Config.gridLongLines * 4
        for _ in 0..<gridCount {
            let line = NodeFactory.gridLine(t: 0.4)
            line.zPosition = 2.5
            worldNode.addChild(line)
            gridLines.append(line)
        }

        for i in 0..<Config.ringCount {
            let t = CourtMath.ringT(index: i, ringCount: Config.ringCount)
            let z = Config.zFar * t
            let node = NodeFactory.ring(halfW: halfW, halfH: halfH,
                                        scale: proj.scale(z: z), t: t,
                                        center: proj.center)
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
        // Four continuous corner rails (near plane → far plane).
        for _ in 0..<4 {
            let rail = NodeFactory.railSegment(t: 0.5)
            rail.zPosition = 3
            worldNode.addChild(rail)
            railSegments.append(rail)
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
        hudPlayerLives = NodeFactory.hudLabel("", size: 15, color: Config.playerColor, alpha: 0.7)
        hudPlayerLives.hAlign = .left
        hudNode.addChild(hudPlayerLives)

        hudOppLives = NodeFactory.hudLabel("", size: 13, color: Config.opponentColor, alpha: 0.7)
        hudOppLives.hAlign = .right
        hudNode.addChild(hudOppLives)

        hudLevelLabel = NodeFactory.hudLabel("LV 1", size: 15, color: Config.hudColor, alpha: 0.65)
        hudNode.addChild(hudLevelLabel)

        hudScoreLabel = NodeFactory.hudLabel("0", size: 20, color: Config.hudColor, alpha: 0.85)
        hudNode.addChild(hudScoreLabel)

        // Pixel font has "|" not the geometric pause bars.
        pauseButton = NodeFactory.hudLabel("||", size: 17, color: Config.hudColor, alpha: 0.4)
        hudNode.addChild(pauseButton)

        serveHintLabel = NodeFactory.hudLabel("CLICK TO SERVE", size: 15, color: Config.titleAccent, alpha: 0.9)
        serveHintLabel.isHidden = true
        hudNode.addChild(serveHintLabel)

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
        titleLayer.addChild(place(NodeFactory.titleLabel("CYBER", size: 56, color: Config.playerColor), cx, cy + 148))
        titleLayer.addChild(place(NodeFactory.titleLabel("PONG", size: 56, color: Config.titleAccent), cx, cy + 86))
        let tap = NodeFactory.hudLabel("TAP TO START", size: 21, color: Config.moonColor, alpha: 0.9)
        tap.position = CGPoint(x: cx, y: cy - 50)
        tap.run(pulseForever())
        titleLayer.addChild(tap)
        titleHighLabel = NodeFactory.hudLabel("HIGH SCORE 0", size: 14, color: Config.hudColor, alpha: 0.55)
        titleHighLabel.position = CGPoint(x: cx, y: cy - 120)
        titleLayer.addChild(titleHighLabel)

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
        goHighLabel = NodeFactory.hudLabel("HIGH SCORE 0", size: 15, color: Config.hudColor, alpha: 0.65)
        goHighLabel.position = CGPoint(x: cx, y: cy)
        gameOverLayer.addChild(goHighLabel)
        let replay = NodeFactory.hudLabel("TAP TO REPLAY", size: 18, color: .white, alpha: 0.85)
        replay.position = CGPoint(x: cx, y: cy - 90)
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

    private func englishStrength() -> CGFloat {
        Config.lerp(Config.englishL1, Config.englishL10, difficultyT())
    }

    private func serveDragSpin() -> CGFloat {
        Config.lerp(Config.serveDragL1, Config.serveDragL10, difficultyT())
    }

    /// World-space: does the player paddle cover the (parked) serve ball?
    private func paddleOverlapsServeBall() -> Bool {
        let slop = Config.paddleHitSlop
        return abs(px - bx) <= Config.playerPaddleHalfW + Config.ballRadius + slop
            && abs(py - by) <= Config.playerPaddleHalfH + Config.ballRadius + slop
    }

    // MARK: - Flow

    private func showTitle() {
        phase = .title
        lastPhaseChange = CACurrentMediaTime()
        titleHighLabel.display("HIGH SCORE \(highScore)")
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
        playerLives = Config.playerLives
        opponentLives = Config.opponentLivesPerLevel
        px = 0; py = 0; ox = 0; oy = 0
        touchTarget = nil
        nextServer = .player     // every round (incl. level 1): you serve first
        awaitingPlayerServe = false
        pointFreezeCountdown = 0
        pointCalloutLabel.isHidden = true
        serveHintLabel.isHidden = true
        clearServeGesture()

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
        awaitingPlayerServe = false
        serveCountdown = 0
        // Every point: opponent starts centered (no crawl back from last rally).
        ox = 0; oy = 0
        ballNode.isHidden = false
        serveHintLabel.isHidden = true
        clearServeGesture()

        switch nextServer {
        case .opponent:
            // Mid/far tunnel, then auto-launch toward you.
            bx = 0; by = 0
            bz = Config.zFar * Config.serveZFraction
            serveCountdown = Config.serveDelay
        case .player:
            // Fixed center of court — does NOT follow the paddle until struck.
            bx = 0; by = 0
            bz = Config.playerServeZ
            awaitingPlayerServe = true
            // Short copy only — the old sentence ran off both edges of the
            // window. The "cover the ball first" half is taught by the
            // affordance in update(), not by more text.
            #if targetEnvironment(macCatalyst)
            serveHintLabel.display("CLICK TO SERVE")
            #else
            serveHintLabel.display("SWIPE TO SERVE")
            #endif
            serveReadyShown = nil
            serveHintLabel.isHidden = false
        }
        renderWorld()
    }

    private func clearServeGesture() {
        serveDragPrev = nil
        serveDragDelta = .zero
    }

    /// Opponent auto-serve (toward you).
    private func launchBall() {
        guard !ballLive, pointFreezeCountdown <= 0 else { return }
        awaitingPlayerServe = false
        serveHintLabel.isHidden = true
        clearServeGesture()
        ballLive = true
        let speed = levelBallSpeed()
        let a = CGFloat.random(in: -0.45...0.45)
        let b = CGFloat.random(in: -0.30...0.30)
        vx = speed * 0.28 * a
        vy = speed * 0.20 * b
        let vzMag = sqrt(max(speed * speed - vx * vx - vy * vy, 1))
        vz = -vzMag
    }

    /// Your serve: ball stays centered until struck by the *paddle* (any part).
    /// English from contact offset (corners veer off that corner); drag adds spin.
    private func launchPlayerServe(dragScreen: CGPoint) {
        guard awaitingPlayerServe, !ballLive, pointFreezeCountdown <= 0 else { return }
        guard paddleOverlapsServeBall() else { return }

        awaitingPlayerServe = false
        serveHintLabel.isHidden = true
        clearServeGesture()

        bx = 0; by = 0; bz = Config.playerServeZ
        let speed = levelBallSpeed()

        // Contact normal: ball at center relative to paddle — whole face works,
        // not just the visual midpoint. Corners → both axes high → extra veer.
        let nX = max(-1, min(1, (bx - px) / max(Config.playerPaddleHalfW, 1)))
        let nY = max(-1, min(1, (by - py) / max(Config.playerPaddleHalfH, 1)))
        let corner = abs(nX) * abs(nY)
        let eng = englishStrength() * (1 + Config.serveCornerBoost * corner)

        let dragMag = hypot(dragScreen.x, dragScreen.y)
        var spinX: CGFloat = 0, spinY: CGFloat = 0
        if dragMag > 3 {
            let t = min(dragMag, 90) / 90
            let spin = serveDragSpin()
            spinX = (dragScreen.x / dragMag) * spin * t
            spinY = (dragScreen.y / dragMag) * spin * t
        }

        vx = nX * eng * speed + spinX
        vy = nY * eng * speed + spinY
        vz = sqrt(max(speed * speed * 0.85, 1))
        ballLive = true
        applySpeed(speed)
        Haptics.shared.paddleHit()
        Audio.shared.paddleHit(player: true)
        Audio.shared.serve()
        flashPaddle(playerPaddleNode)
        pulseRing(atZ: bz)
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
            nextServer = .player
            if opponentLives <= 0 {
                levelUp()
            } else {
                scheduleServe()
            }
        } else {
            nextServer = .opponent
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
        updateLevelHUD()
        updateLivesHUD()
        Haptics.shared.levelUp()
        Audio.shared.levelUp()
        transitionLabel.display("LEVEL \(level)")
        transitionLabel.isHidden = false
        ballNode.isHidden = true
        transitionCountdown = Config.levelTransitionDuration
        phase = .levelTransition
    }

    private func endTransition() {
        transitionLabel.isHidden = true
        phase = .playing
        nextServer = .player     // new level/round: you serve first
        ballNode.isHidden = false
        scheduleServe()
    }

    private func endRun() {
        // Capture before saveHighScoreIfNeeded overwrites highScore.
        let isNewHigh = score > highScore && score > 0
        saveHighScoreIfNeeded()
        goTitleLabel.display("GAME OVER")
        goTitleLabel.tint = .white
        goScoreLabel.display("SCORE \(score)")
        goHighLabel.display(isNewHigh ? "NEW HIGH SCORE" : "HIGH SCORE \(highScore)")
        gameOverLayer.isHidden = false
        ballNode.isHidden = true
        playerPaddleNode.isHidden = true
        oppPaddleNode.isHidden = true
        serveHintLabel.isHidden = true
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

    private func updateScoreHUD() { hudScoreLabel.display("\(score)") }
    private func updateLevelHUD() { hudLevelLabel.display("LV \(level)") }
    private func updateLivesHUD() {
        // Hearts are spare lives. An empty row is the warning — you're on your
        // last life — so it needs no label.
        hudPlayerLives.display(String(repeating: "♥", count: max(playerLives, 0)))
        hudOppLives.display(String(repeating: "♥", count: max(opponentLives, 0)))
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
            if pointFreezeCountdown > 0 {
                pointFreezeCountdown -= dt
                if pointFreezeCountdown <= 0 { resolvePointFreeze() }
            } else {
                stepBall(dt)
                stepAI(dt)
            }
            // Serve ball stays fixed at court center until struck (not glued to paddle).
            if awaitingPlayerServe {
                bx = 0; by = 0; bz = Config.playerServeZ
                // Light the prompt only once the paddle actually covers the
                // ball, so the requirement is shown rather than spelled out.
                let ready = paddleOverlapsServeBall()
                if serveReadyShown != ready {
                    serveReadyShown = ready
                    serveHintLabel.tint = ready ? Config.playerColor : Config.hudColor
                    serveHintLabel.alpha = ready ? 1.0 : 0.45
                }
            }
            renderWorld()
        case .levelTransition:
            stepPlayer(dt)
            transitionCountdown -= dt
            if transitionCountdown <= 0 { endTransition() }
            renderWorld()
        case .title, .paused, .gameOver:
            break
        }
    }

    // MARK: - Player paddle

    private func stepPlayer(_ dt: CGFloat) {
        guard let target = touchTarget else { return }
        // Full capability from frame 1: paddle is the pointer (no lag).
        _ = dt
        px = target.x
        py = target.y
        clampPlayer()
    }

    private func clampPlayer() {
        let mx = halfW - Config.playerPaddleHalfW
        let my = halfH - Config.playerPaddleHalfH
        px = max(-mx, min(mx, px))
        py = max(-my, min(my, py))
    }

    private func setTouchTarget(_ loc: CGPoint, thumbOffset: Bool = true) {
        // Screen → world at z = 0 is a straight offset from center (scale = 1).
        // On phone, add occlusion offset so the paddle rides above the thumb.
        // On Mac pointer, skip that so the paddle sits under the cursor.
        let wx = loc.x - proj.center.x
        let offset: CGFloat = thumbOffset ? Config.touchOffsetY : 0
        let wy = loc.y - proj.center.y + offset
        touchTarget = CGPoint(x: wx, y: wy)
        // Apply immediately so click frames don't fight hover.
        px = wx
        py = wy
        clampPlayer()
    }

    /// Mac Catalyst: paddle follows the mouse with no click held.
    func pointerMoved(to loc: CGPoint) {
        guard phase == .playing || phase == .levelTransition else { return }
        setTouchTarget(loc, thumbOffset: false)
    }

    // MARK: - Ball

    private func stepBall(_ dt: CGFloat) {
        if !ballLive {
            // Opponent auto-serve only (player serve waits for click/tap).
            if !awaitingPlayerServe && serveCountdown > 0 {
                serveCountdown -= dt
                if serveCountdown <= 0 { launchBall() }
            }
            return
        }

        let prevX = bx, prevY = by, prevZ = bz
        bx += vx * dt
        by += vy * dt
        bz += vz * dt

        // Roll: a ball travelling sideways turns about the view axis. Driving
        // this off vx alone (rather than total speed) means a straight shot
        // down the tunnel barely spins, while a cut shot visibly tumbles.
        ballSpin -= (vx / max(Config.ballRadius, 1)) * dt * Config.ballSpinFactor

        // Wall bounces: positional reflection keeps the ball inside the court
        // even on a long frame.
        let effW = halfW - Config.ballRadius
        let effH = halfH - Config.ballRadius
        if bx > effW { bx = 2 * effW - bx; vx = -vx; wallBounce() }
        else if bx < -effW { bx = -2 * effW - bx; vx = -vx; wallBounce() }
        if by > effH { by = 2 * effH - by; vy = -vy; wallBounce() }
        else if by < -effH { by = -2 * effH - by; vy = -vy; wallBounce() }

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
                          newZ: 0.1, outbound: true)
                rallyHits += 1
                score += Config.scorePerHit * level
                updateScoreHUD()
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
                          newZ: Config.zFar - 0.1, outbound: false)
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
                           newZ: CGFloat, outbound: Bool) {
        let speed = sqrt(vx * vx + vy * vy + vz * vz)
        // English: off-center / corner hit; strength ramps mildly with level.
        let nX = max(-1, min(1, (xc - cx) / paddleHalfW))
        let nY = max(-1, min(1, (yc - cy) / paddleHalfH))
        let corner = abs(nX) * abs(nY)
        let eng = englishStrength() * (1 + Config.serveCornerBoost * corner * 0.5)
        vx += nX * eng * speed
        vy += nY * eng * speed
        vz = outbound ? abs(vz) : -abs(vz)
        bx = xc; by = yc; bz = newZ
        applySpeed(targetSpeed())
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
    // Pure tracking, Flappy Bird style: chase the ball intercept as hard as
    // aiSpeed allows. No aim error, no reaction delay, no corner hunting.
    // Difficulty is ONLY "it gets faster" (Config.aiSpeedL1 → L10).

    private func stepAI(_ dt: CGFloat) {
        // Between points / before serve: park center.
        if !ballLive {
            ox = 0; oy = 0
            return
        }

        let tx: CGFloat
        let ty: CGFloat
        let effW = halfW - Config.ballRadius
        let effH = halfH - Config.ballRadius

        if vz > 0.001 {
            // Ball coming at the AI: track where it will cross the far plane
            // (wall bounces folded in). Exact intercept — no offset.
            let tHit = max(0, (Config.zFar - bz) / vz)
            tx = CourtMath.reflect(bx + vx * tHit, limit: effW)
            ty = CourtMath.reflect(by + vy * tHit, limit: effH)
        } else {
            // Ball going back to the player: keep tracking its XY so the
            // paddle doesn't invent a fake recenter dodge.
            tx = max(-effW, min(effW, bx))
            ty = max(-effH, min(effH, by))
        }

        let step = aiSpeed() * dt
        ox = CourtMath.moveToward(ox, target: tx, maxStep: step)
        oy = CourtMath.moveToward(oy, target: ty, maxStep: step)

        let mx = halfW - Config.oppPaddleHalfW
        let my = halfH - Config.oppPaddleHalfH
        ox = max(-mx, min(mx, ox))
        oy = max(-my, min(my, oy))
    }

    // MARK: - Rendering (positions + one perspective scale; no allocations)

    private func renderWorld() {
        // Pixel-snap every actor: continuous physics, discrete picture.
        playerPaddleNode.position = Config.snapPoint(proj.project(x: px, y: py, z: 0))
        oppPaddleNode.position = Config.snapPoint(proj.project(x: ox, y: oy, z: Config.zFar))
        // Quantize far paddle scale to keep slab edges on-grid.
        let oppS = proj.scale(z: Config.zFar)
        oppPaddleNode.setScale(quantizeScale(oppS))

        let ballScale = proj.scale(z: bz) * Config.ballDrawScale
        ballNode.position = Config.snapPoint(proj.project(x: bx, y: by, z: bz))
        ballNode.setScale(quantizeScale(ballScale))
        // Spin ticks through discrete sprite frames.
        let step = (2 * CGFloat.pi) / Config.ballSpinSteps
        ballSpinLayer?.zRotation = (ballSpin / step).rounded() * step
        ballNode.isHidden = (phase == .title || phase == .gameOver)

        if ballShadowNode != nil {
            let showShadow = !ballNode.isHidden && (ballLive || awaitingPlayerServe || pointFreezeCountdown > 0)
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
                let s = proj.scale(z: h.z) * Config.ballDrawScale
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
            if awaitingPlayerServe {
                serveDragPrev = loc
                serveDragDelta = .zero
                #if targetEnvironment(macCatalyst)
                // Do not setTouchTarget — that was jumping the paddle to the click.
                #else
                setTouchTarget(loc)
                #endif
                return
            }
            #if targetEnvironment(macCatalyst)
            // Hover owns aim on Mac; clicks are for serve / UI only.
            #else
            setTouchTarget(loc)
            #endif
        case .levelTransition:
            #if !targetEnvironment(macCatalyst)
            setTouchTarget(loc)
            #endif
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing || phase == .levelTransition,
              let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if phase == .playing, awaitingPlayerServe {
            if let prev = serveDragPrev {
                serveDragDelta = CGPoint(x: loc.x - prev.x, y: loc.y - prev.y)
            }
            serveDragPrev = loc
            #if !targetEnvironment(macCatalyst)
            setTouchTarget(loc)
            // Phone: swipe while paddle covers ball → serve with spin.
            if paddleOverlapsServeBall(), hypot(serveDragDelta.x, serveDragDelta.y) > 8 {
                launchPlayerServe(dragScreen: serveDragDelta)
            }
            #endif
            return
        }

        #if !targetEnvironment(macCatalyst)
        setTouchTarget(loc)
        #endif
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if phase == .playing, awaitingPlayerServe {
            // Strike if paddle covers the ball (any face region), or click was on ball
            // while already overlapping from hover/finger.
            if paddleOverlapsServeBall() {
                launchPlayerServe(dragScreen: serveDragDelta)
            }
        }
        clearServeGesture()
        #if targetEnvironment(macCatalyst)
        // Keep last aim; hover continues tracking without a click.
        #else
        touchTarget = nil
        #endif
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearServeGesture()
        #if targetEnvironment(macCatalyst)
        #else
        touchTarget = nil
        #endif
    }
}
