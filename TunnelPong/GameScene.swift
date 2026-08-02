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
    private var ballLive = false           // false while waiting to serve
    private var serveCountdown: CGFloat = 0

    // MARK: - Paddles (world coordinates)

    private var px: CGFloat = 0, py: CGFloat = 0        // player, at z = 0
    private var touchTarget: CGPoint?                   // where the finger wants the paddle
    private var ox: CGFloat = 0, oy: CGFloat = 0        // opponent, at z = zFar
    private var aiErrX: CGFloat = 0, aiErrY: CGFloat = 0
    private var aiReactionClock: CGFloat = 0
    private var ballWasOutbound = false

    // MARK: - Timers

    private var lastUpdate: TimeInterval = 0
    private var transitionCountdown: CGFloat = 0
    private var lastPhaseChange: TimeInterval = 0

    // MARK: - Nodes

    private let worldNode = SKNode()
    private var rings: [SKShapeNode] = []
    private var ringPulses: [SKAction] = []
    private var ballNode: SKShapeNode!
    private var playerPaddleNode: SKShapeNode!
    private var oppPaddleNode: SKShapeNode!

    private var hudNode: SKNode!
    private var hudLevelLabel: SKLabelNode!
    private var hudScoreLabel: SKLabelNode!
    private var hudPlayerLives: SKLabelNode!
    private var hudOppLives: SKLabelNode!
    private var pauseButton: SKLabelNode!

    private var titleLayer: SKNode!
    private var titleHighLabel: SKLabelNode!
    private var pauseLayer: SKNode!
    private var quitLabel: SKLabelNode!
    private var gameOverLayer: SKNode!
    private var goScoreLabel: SKLabelNode!
    private var goHighLabel: SKLabelNode!
    private var transitionLabel: SKLabelNode!
    private var flashNode: SKSpriteNode!

    private var shakeAction: SKAction!
    private var flashAction: SKAction!

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black
        proj.center = CGPoint(x: size.width / 2, y: size.height / 2)
        halfW = size.width / 2 * Config.courtWidthFactor
        halfH = size.height / 2 * Config.courtHeightFactor

        addChild(worldNode)
        buildTunnel()
        buildActors()
        buildEffects()
        buildHUD()
        buildOverlays()

        Haptics.shared.prepare()
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResign),
            name: UIApplication.willResignActiveNotification, object: nil)

        showTitle()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillResign() {
        if phase == .playing { pauseGame() }
    }

    private func buildTunnel() {
        for i in 0..<Config.ringCount {
            let t = CourtMath.ringT(index: i, ringCount: Config.ringCount)
            let z = Config.zFar * t
            let node = NodeFactory.ring(halfW: halfW, halfH: halfH,
                                        scale: proj.scale(z: z), t: t,
                                        center: proj.center)
            node.zPosition = 4
            worldNode.addChild(node)
            rings.append(node)
            // Pre-built pulse action per ring (rings have different base alphas),
            // so wall bounces never allocate.
            let up = SKAction.fadeAlpha(to: min(node.alpha * 3.0, 0.95), duration: 0.045)
            let down = SKAction.fadeAlpha(to: node.alpha, duration: 0.30)
            down.timingMode = .easeOut
            ringPulses.append(SKAction.sequence([up, down]))
        }
        // Corner rails from near plane to far plane.
        for sx: CGFloat in [-1, 1] {
            for sy: CGFloat in [-1, 1] {
                let p0 = proj.project(x: sx * halfW, y: sy * halfH, z: 0)
                let p1 = proj.project(x: sx * halfW, y: sy * halfH, z: Config.zFar)
                let line = NodeFactory.cornerLine(from: p0, to: p1)
                line.zPosition = 2
                worldNode.addChild(line)
            }
        }
    }

    private func buildActors() {
        oppPaddleNode = NodeFactory.paddle(halfW: Config.oppPaddleHalfW,
                                           halfH: Config.oppPaddleHalfH,
                                           color: Config.opponentColor)
        oppPaddleNode.setScale(proj.scale(z: Config.zFar))
        oppPaddleNode.zPosition = 10
        worldNode.addChild(oppPaddleNode)

        ballNode = NodeFactory.ball()
        ballNode.zPosition = 20
        worldNode.addChild(ballNode)

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

        // Keep labels clear of notch / Dynamic Island / home indicator.
        let topPad = max(safeInsets.top, 20) + 18
        let bottomPad = max(safeInsets.bottom, 12) + 18
        let sidePad = max(safeInsets.left, safeInsets.right, 12) + 10
        let topY = size.height - topPad

        hudPlayerLives = NodeFactory.label("", size: 15, color: Config.playerColor, alpha: 0.55)
        hudPlayerLives.horizontalAlignmentMode = .left
        hudPlayerLives.position = CGPoint(x: sidePad, y: topY)
        hudNode.addChild(hudPlayerLives)

        hudOppLives = NodeFactory.label("", size: 13, color: Config.opponentColor, alpha: 0.55)
        hudOppLives.horizontalAlignmentMode = .right
        hudOppLives.position = CGPoint(x: size.width - sidePad, y: topY)
        hudNode.addChild(hudOppLives)

        hudLevelLabel = NodeFactory.label("LV 1", size: 15, color: Config.hudColor, alpha: 0.6)
        hudLevelLabel.position = CGPoint(x: proj.center.x, y: topY)
        hudNode.addChild(hudLevelLabel)

        hudScoreLabel = NodeFactory.label("0", size: 20, color: Config.hudColor, alpha: 0.8)
        hudScoreLabel.position = CGPoint(x: proj.center.x, y: topY - 26)
        hudNode.addChild(hudScoreLabel)

        pauseButton = NodeFactory.label("❚❚", size: 17, color: Config.hudColor, alpha: 0.35)
        pauseButton.position = CGPoint(x: size.width - sidePad - 10, y: bottomPad)
        hudNode.addChild(pauseButton)
    }

    private func buildOverlays() {
        let cx = proj.center.x
        let cy = proj.center.y

        // Title
        titleLayer = SKNode()
        titleLayer.zPosition = 100
        addChild(titleLayer)
        titleLayer.addChild(place(NodeFactory.label("TUNNEL", size: 56, color: Config.playerColor), cx, cy + 150))
        titleLayer.addChild(place(NodeFactory.label("PONG", size: 56, color: .white), cx, cy + 88))
        let tap = NodeFactory.label("TAP TO START", size: 19, color: .white, alpha: 0.8)
        tap.position = CGPoint(x: cx, y: cy - 50)
        tap.run(pulseForever())
        titleLayer.addChild(tap)
        titleHighLabel = NodeFactory.label("HIGH SCORE 0", size: 15, color: Config.hudColor, alpha: 0.5)
        titleHighLabel.position = CGPoint(x: cx, y: cy - 120)
        titleLayer.addChild(titleHighLabel)

        // Pause
        pauseLayer = SKNode()
        pauseLayer.zPosition = 100
        let dim = SKSpriteNode(color: .black,
                               size: CGSize(width: size.width * 1.2, height: size.height * 1.2))
        dim.position = proj.center
        dim.alpha = 0.6
        pauseLayer.addChild(dim)
        pauseLayer.addChild(place(NodeFactory.label("PAUSED", size: 34, color: .white), cx, cy + 70))
        pauseLayer.addChild(place(NodeFactory.label("TAP TO RESUME", size: 17, color: .white, alpha: 0.7), cx, cy))
        quitLabel = NodeFactory.label("QUIT", size: 20, color: Config.opponentColor, alpha: 0.9)
        quitLabel.position = CGPoint(x: cx, y: cy - 110)
        pauseLayer.addChild(quitLabel)
        pauseLayer.isHidden = true
        addChild(pauseLayer)

        // Game over
        gameOverLayer = SKNode()
        gameOverLayer.zPosition = 100
        gameOverLayer.addChild(place(NodeFactory.label("GAME OVER", size: 40, color: .white), cx, cy + 120))
        goScoreLabel = NodeFactory.label("SCORE 0", size: 22, color: Config.hudColor)
        goScoreLabel.position = CGPoint(x: cx, y: cy + 40)
        gameOverLayer.addChild(goScoreLabel)
        goHighLabel = NodeFactory.label("HIGH SCORE 0", size: 16, color: Config.hudColor, alpha: 0.6)
        goHighLabel.position = CGPoint(x: cx, y: cy)
        gameOverLayer.addChild(goHighLabel)
        let replay = NodeFactory.label("TAP TO REPLAY", size: 19, color: .white, alpha: 0.8)
        replay.position = CGPoint(x: cx, y: cy - 90)
        replay.run(pulseForever())
        gameOverLayer.addChild(replay)
        gameOverLayer.isHidden = true
        addChild(gameOverLayer)

        // Level transition
        transitionLabel = NodeFactory.label("LEVEL 2", size: 40, color: Config.playerColor)
        transitionLabel.position = CGPoint(x: cx, y: cy + 30)
        transitionLabel.zPosition = 100
        transitionLabel.isHidden = true
        addChild(transitionLabel)
    }

    private func place(_ node: SKLabelNode, _ x: CGFloat, _ y: CGFloat) -> SKLabelNode {
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

    // MARK: - Difficulty formulas (all driven by level number)

    private func levelBallSpeed() -> CGFloat {
        min(Config.ballBaseSpeed * (1 + Config.ballSpeedPerLevel * CGFloat(level - 1)),
            Config.ballMaxSpeed)
    }

    private func targetSpeed() -> CGFloat {
        min(levelBallSpeed() + CGFloat(rallyHits) * Config.ballRallyIncrement,
            Config.ballMaxSpeed)
    }

    private func aiSpeed() -> CGFloat {
        min(Config.aiBaseSpeed * (1 + Config.aiSpeedPerLevel * CGFloat(level - 1)),
            Config.aiMaxSpeed)
    }

    private func aiErrorAmp() -> CGFloat {
        Config.aiErrorBase * pow(Config.aiErrorDecayPerLevel, CGFloat(level - 1))
    }

    // MARK: - Flow

    private func showTitle() {
        phase = .title
        lastPhaseChange = CACurrentMediaTime()
        titleHighLabel.text = "HIGH SCORE \(highScore)"
        titleLayer.isHidden = false
        gameOverLayer.isHidden = true
        pauseLayer.isHidden = true
        transitionLabel.isHidden = true
        hudNode.isHidden = true
        ballNode.isHidden = true
        playerPaddleNode.isHidden = true
        oppPaddleNode.isHidden = true
    }

    private func startRun() {
        level = 1
        score = 0
        playerLives = Config.playerLives
        opponentLives = Config.opponentLivesPerLevel
        px = 0; py = 0; ox = 0; oy = 0
        touchTarget = nil

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

    /// Every point starts here: ball parked mid-tunnel, short beat, then launch.
    private func scheduleServe() {
        rallyHits = 0
        ballLive = false
        serveCountdown = Config.serveDelay
        bx = 0; by = 0
        bz = Config.zFar * Config.serveZFraction
        ballWasOutbound = false
        aiReactionClock = 0
        ballNode.isHidden = false
        renderWorld()
    }

    private func launchBall() {
        ballLive = true
        let speed = levelBallSpeed()
        let a = CGFloat.random(in: -0.5...0.5)
        let b = CGFloat.random(in: -0.35...0.35)
        vx = speed * 0.30 * a
        vy = speed * 0.22 * b
        // Serve always toward the player, so they get first touch.
        vz = -sqrt(max(speed * speed - vx * vx - vy * vy, 1))
    }

    private func playerMiss() {
        Haptics.shared.lifeLost()
        flashNode.run(flashAction, withKey: "flash")
        playShake()
        playerLives -= 1
        updateLivesHUD()
        if playerLives <= 0 {
            endRun()
        } else {
            scheduleServe()
        }
    }

    private func opponentMiss() {
        Haptics.shared.pointScored()
        score += Config.scorePerOpponentLife * level
        updateScoreHUD()
        opponentLives -= 1
        updateLivesHUD()
        pulseRing(atZ: Config.zFar)
        if opponentLives <= 0 {
            levelUp()
        } else {
            scheduleServe()
        }
    }

    /// Reset position first so a replaced mid-shake action can't leave the court offset.
    private func playShake() {
        worldNode.removeAction(forKey: "shake")
        worldNode.position = .zero
        worldNode.run(shakeAction, withKey: "shake")
    }

    private func levelUp() {
        level += 1
        opponentLives = Config.opponentLivesPerLevel
        if Config.extraLifeEveryNLevels > 0, level % Config.extraLifeEveryNLevels == 0 {
            playerLives += 1
        }
        updateLevelHUD()
        updateLivesHUD()
        Haptics.shared.levelUp()
        flashNode.run(flashAction, withKey: "flash")
        transitionLabel.text = "LEVEL \(level)"
        transitionLabel.isHidden = false
        ballNode.isHidden = true
        transitionCountdown = Config.levelTransitionDuration
        phase = .levelTransition
    }

    private func endTransition() {
        transitionLabel.isHidden = true
        phase = .playing
        scheduleServe()
    }

    private func endRun() {
        // Capture before saveHighScoreIfNeeded overwrites highScore.
        let isNewHigh = score > highScore && score > 0
        saveHighScoreIfNeeded()
        goScoreLabel.text = "SCORE \(score)"
        goHighLabel.text = isNewHigh
            ? "NEW HIGH SCORE" : "HIGH SCORE \(highScore)"
        gameOverLayer.isHidden = false
        ballNode.isHidden = true
        playerPaddleNode.isHidden = true
        oppPaddleNode.isHidden = true
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

    private func updateScoreHUD() { hudScoreLabel.text = "\(score)" }
    private func updateLevelHUD() { hudLevelLabel.text = "LV \(level)" }
    private func updateLivesHUD() {
        hudPlayerLives.text = String(repeating: "◆", count: max(playerLives, 0))
        hudOppLives.text = String(repeating: "◆", count: max(opponentLives, 0))
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
            stepBall(dt)
            stepAI(dt)
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
        // Exponential smoothing, frame-rate independent: responsive but not twitchy.
        let k = 1 - exp(-Config.paddleSmoothing * dt)
        px += (target.x - px) * k
        py += (target.y - py) * k
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
    }

    /// Mac Catalyst: paddle follows the mouse with no click held.
    func pointerMoved(to loc: CGPoint) {
        guard phase == .playing || phase == .levelTransition else { return }
        setTouchTarget(loc, thumbOffset: false)
    }

    // MARK: - Ball

    private func stepBall(_ dt: CGFloat) {
        if !ballLive {
            serveCountdown -= dt
            if serveCountdown <= 0 { launchBall() }
            return
        }

        let prevX = bx, prevY = by, prevZ = bz
        bx += vx * dt
        by += vy * dt
        bz += vz * dt

        // Wall bounces: positional reflection keeps the ball inside the court
        // even on a long frame.
        let effW = halfW - Config.ballRadius
        let effH = halfH - Config.ballRadius
        if bx > effW { bx = 2 * effW - bx; vx = -vx; wallBounce() }
        else if bx < -effW { bx = -2 * effW - bx; vx = -vx; wallBounce() }
        if by > effH { by = 2 * effH - by; vy = -vy; wallBounce() }
        else if by < -effH { by = -2 * effH - by; vy = -vy; wallBounce() }

        // --- Paddle collisions, sampled by z-crossing ---------------------
        // We never test rendered screen overlap. Instead: did the ball's z
        // pass a paddle plane between the previous frame and this one? If so,
        // solve for the exact fraction t of the frame where it crossed,
        // reconstruct (x, y) at that instant, and test against the paddle
        // rect (inflated by the ball radius). Because the check is on the
        // crossing itself, the ball cannot tunnel through a paddle no matter
        // how fast it moves.

        if prevZ > 0 && bz <= 0 && vz < 0 {
            let t = prevZ / (prevZ - bz)
            let xc = prevX + (bx - prevX) * t
            let yc = prevY + (by - prevY) * t
            if abs(xc - px) <= Config.playerPaddleHalfW + Config.ballRadius,
               abs(yc - py) <= Config.playerPaddleHalfH + Config.ballRadius {
                hitPaddle(xc: xc, yc: yc, cx: px, cy: py,
                          paddleHalfW: Config.playerPaddleHalfW,
                          paddleHalfH: Config.playerPaddleHalfH,
                          newZ: 0.1, outbound: true)
                rallyHits += 1
                score += Config.scorePerHit * level
                updateScoreHUD()
                Haptics.shared.paddleHit()
            }
            // On a miss the ball keeps flying toward the camera; the life is
            // lost only once it's clearly past the plane (below), which reads
            // as the ball whooshing by.
        }

        if prevZ < Config.zFar && bz >= Config.zFar && vz > 0 {
            let t = (Config.zFar - prevZ) / (bz - prevZ)
            let xc = prevX + (bx - prevX) * t
            let yc = prevY + (by - prevY) * t
            if abs(xc - ox) <= Config.oppPaddleHalfW + Config.ballRadius,
               abs(yc - oy) <= Config.oppPaddleHalfH + Config.ballRadius {
                hitPaddle(xc: xc, yc: yc, cx: ox, cy: oy,
                          paddleHalfW: Config.oppPaddleHalfW,
                          paddleHalfH: Config.oppPaddleHalfH,
                          newZ: Config.zFar - 0.1, outbound: false)
                Haptics.shared.paddleHit()
            }
        }

        // Misses register once the ball is clearly past a plane.
        if bz < -Config.missDepthNear {
            ballLive = false
            playerMiss()
        } else if bz > Config.zFar + Config.missDepthFar {
            ballLive = false
            opponentMiss()
        }
    }

    private func hitPaddle(xc: CGFloat, yc: CGFloat, cx: CGFloat, cy: CGFloat,
                           paddleHalfW: CGFloat, paddleHalfH: CGFloat,
                           newZ: CGFloat, outbound: Bool) {
        let speed = sqrt(vx * vx + vy * vy + vz * vz)
        // English: an off-center hit tilts the return proportionally.
        let nX = max(-1, min(1, (xc - cx) / paddleHalfW))
        let nY = max(-1, min(1, (yc - cy) / paddleHalfH))
        vx += nX * Config.englishMultiplier * speed
        vy += nY * Config.englishMultiplier * speed
        vz = outbound ? abs(vz) : -abs(vz)
        bx = xc; by = yc; bz = newZ
        applySpeed(targetSpeed())
        pulseRing(atZ: newZ)
    }

    private func applySpeed(_ speed: CGFloat) {
        CourtMath.renormVelocity(vx: &vx, vy: &vy, vz: &vz,
                                 speed: speed, minVzFraction: Config.minVzFraction)
    }

    private func wallBounce() {
        Haptics.shared.wallBounce()
        pulseRing(atZ: bz)
    }

    private func pulseRing(atZ z: CGFloat) {
        let idx = CourtMath.ringIndex(z: z, zFar: Config.zFar, ringCount: Config.ringCount)
        rings[idx].run(ringPulses[idx], withKey: "pulse")
    }

    // MARK: - Opponent AI

    private func stepAI(_ dt: CGFloat) {
        let outbound = ballLive && vz > 0

        // The moment the ball turns outbound, roll a fresh aim error and
        // restart the reaction clock. The error shrinks with level; the
        // imperfection is what makes the opponent beatable.
        if outbound && !ballWasOutbound {
            aiReactionClock = 0
            let amp = aiErrorAmp()
            aiErrX = CGFloat.random(in: -amp...amp)
            aiErrY = CGFloat.random(in: -amp...amp)
        }
        ballWasOutbound = outbound

        var tx: CGFloat = 0
        var ty: CGFloat = 0
        var speedFactor: CGFloat = Config.aiIdleSpeedFactor  // slow recentre when idle

        if outbound {
            aiReactionClock += dt
            if aiReactionClock >= Config.aiReactionDelay {
                // Project the ball to the far plane, folding wall bounces in,
                // then aim at that intercept plus this approach's error.
                let tHit = (Config.zFar - bz) / vz
                let effW = halfW - Config.ballRadius
                let effH = halfH - Config.ballRadius
                tx = CourtMath.reflect(bx + vx * tHit, limit: effW) + aiErrX
                ty = CourtMath.reflect(by + vy * tHit, limit: effH) + aiErrY
                speedFactor = 1
            } else {
                // Still "reacting": hold position.
                tx = ox; ty = oy
                speedFactor = 0
            }
        }

        let step = aiSpeed() * speedFactor * dt
        ox = CourtMath.moveToward(ox, target: tx, maxStep: step)
        oy = CourtMath.moveToward(oy, target: ty, maxStep: step)

        let mx = halfW - Config.oppPaddleHalfW
        let my = halfH - Config.oppPaddleHalfH
        ox = max(-mx, min(mx, ox))
        oy = max(-my, min(my, oy))
    }

    // MARK: - Rendering (positions + one perspective scale; no allocations)

    private func renderWorld() {
        playerPaddleNode.position = proj.project(x: px, y: py, z: 0)
        oppPaddleNode.position = proj.project(x: ox, y: oy, z: Config.zFar)
        ballNode.position = proj.project(x: bx, y: by, z: bz)
        ballNode.setScale(proj.scale(z: bz))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        switch phase {
        case .title, .gameOver:
            // Brief lockout so a stray tap right at game over doesn't restart.
            guard CACurrentMediaTime() - lastPhaseChange > 0.45 else { return }
            startRun()
        case .paused:
            if quitLabel.frame.insetBy(dx: -40, dy: -30).contains(loc) {
                quitToTitle()
            } else {
                resumeGame()
            }
        case .playing:
            if pauseButton.frame.insetBy(dx: -18, dy: -18).contains(loc) {
                pauseGame()
                return
            }
            setTouchTarget(loc)
        case .levelTransition:
            setTouchTarget(loc)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing || phase == .levelTransition,
              let touch = touches.first else { return }
        setTouchTarget(touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        #if targetEnvironment(macCatalyst)
        // Keep last aim; hover continues tracking without a click.
        #else
        touchTarget = nil
        #endif
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        #if targetEnvironment(macCatalyst)
        #else
        touchTarget = nil
        #endif
    }
}
