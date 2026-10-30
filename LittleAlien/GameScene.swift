import SpriteKit
import UIKit

final class GameScene: SKScene {
    enum State { case menu, playing, over }

    private struct Layer {
        var nodes: [SKNode]
        var period: CGFloat
        var factor: CGFloat
    }

    // Layout
    private var W: CGFloat = 0
    private var H: CGFloat = 0
    private var groundTop: CGFloat = 0
    private var ufoY: CGFloat = 0

    // Nodes
    private let cam = SKCameraNode()
    private let ufo = SKNode()
    private let ufoArt = Art.ufo()
    private let beam = SKShapeNode()
    private let beamRing = SKShapeNode()
    private var layers: [Layer] = []
    private var overlay = SKNode()

    // HUD
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let multLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let heartsLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let powerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let barBack = SKShapeNode()
    private let barFill = SKShapeNode()

    // State
    private var state: State = .menu
    private var lastTime: TimeInterval = 0
    private var clock: CGFloat = 0
    private var elapsed: CGFloat = 0
    private var overTimer: CGFloat = 0
    private var touchX: CGFloat?
    private var beamX: CGFloat = 0
    private var boost: CGFloat = 0
    private var score = 0
    private var best = 0
    private var health = Tuning.maxHealth
    private var streak = 0
    private var tier = 0
    private var idle: CGFloat = 0
    private var invul: CGFloat = 0
    private var rampage: CGFloat = 0
    private var magnet: CGFloat = 0
    private var multiply: CGFloat = 0

    private var creatures: [Creature] = []
    private var missiles: [Missile] = []
    private var turrets: [Turret] = []
    private var birds: [Bird] = []
    private var pickups: [Pickup] = []
    private var decor: [SKNode] = []

    private var nextCreatureX: CGFloat = 0
    private var nextTurretX: CGFloat = 0
    private var nextBirdX: CGFloat = 0
    private var nextDecorX: CGFloat = 0
    private var nextCloudX: CGFloat = 0
    private var nextPickupX: CGFloat = 0

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: Setup

    override func didMove(to view: SKView) {
        setup()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil, size.width > 0, size.height > 0, size != oldSize else { return }
        setup()
    }

    private func setup() {
        removeAllChildren()
        removeAllActions()
        cam.removeAllChildren()
        ufo.removeAllChildren()
        creatures = []; missiles = []; turrets = []; birds = []; pickups = []; decor = []
        layers = []

        W = size.width
        H = size.height
        groundTop = H * 0.2
        ufoY = H * 0.7
        best = UserDefaults.standard.integer(forKey: "littleAlienBest")
        backgroundColor = UIColor(red: 0.07, green: 0.05, blue: 0.2, alpha: 1)

        addChild(cam)
        camera = cam

        buildBackground()
        buildHUD()

        ufo.addChild(ufoArt)
        ufo.zPosition = 50
        addChild(ufo)

        beam.zPosition = 40
        beam.lineWidth = 0
        beam.strokeColor = .clear
        beam.fillColor = UIColor(red: 0.6, green: 1, blue: 0.8, alpha: 0.35)
        addChild(beam)

        beamRing.zPosition = 41
        beamRing.lineWidth = 2
        beamRing.strokeColor = UIColor(red: 0.7, green: 1, blue: 0.85, alpha: 0.8)
        beamRing.fillColor = UIColor(red: 0.6, green: 1, blue: 0.8, alpha: 0.25)
        addChild(beamRing)

        showMenu()
    }

    private func buildBackground() {
        let sky = SKSpriteNode(texture: Art.gradient(size: CGSize(width: 8, height: 256),
                                                      top: UIColor(red: 0.08, green: 0.04, blue: 0.28, alpha: 1),
                                                      bottom: UIColor(red: 0.55, green: 0.25, blue: 0.5, alpha: 1)))
        sky.size = CGSize(width: W + 4, height: H + 4)
        sky.zPosition = -100
        cam.addChild(sky)

        for _ in 0..<45 {
            let s = Art.circ(CGFloat.random(in: 0.6...1.6), UIColor(white: 1, alpha: CGFloat.random(in: 0.4...0.9)),
                             CGFloat.random(in: -W/2...W/2), CGFloat.random(in: 0...H/2))
            s.zPosition = -99
            s.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: Double.random(in: 0.6...1.6)),
                                            .fadeAlpha(to: 1, duration: Double.random(in: 0.6...1.6))])))
            cam.addChild(s)
        }
        let moon = Art.circ(20, UIColor(red: 1, green: 0.96, blue: 0.8, alpha: 1), W * 0.3, H * 0.25)
        moon.zPosition = -98
        cam.addChild(moon)

        let horizon = groundTop - H / 2
        layers.append(makeLayer(period: 260, factor: 0.12, color: UIColor(red: 0.22, green: 0.12, blue: 0.4, alpha: 1), z: -90, baseY: horizon, hMin: 70, hMax: 120))
        layers.append(makeLayer(period: 190, factor: 0.3, color: UIColor(red: 0.16, green: 0.2, blue: 0.38, alpha: 1), z: -80, baseY: horizon, hMin: 40, hMax: 80))

        let ground = Art.rect(W + 4, groundTop + 4, UIColor(red: 0.16, green: 0.36, blue: 0.2, alpha: 1), 0, -H / 2 + groundTop / 2 - 2)
        ground.zPosition = -20
        cam.addChild(ground)
        let road = Art.rect(W + 4, groundTop * 0.5, UIColor(white: 0.25, alpha: 1), 0, -H / 2 + groundTop * 0.25)
        road.zPosition = -19
        cam.addChild(road)
        var dashes: [SKNode] = []
        let dashCount = Int(ceil(W / 90)) + 3
        for _ in 0..<dashCount {
            let d = Art.rect(34, 3, UIColor(white: 0.85, alpha: 1), 0, -H / 2 + groundTop * 0.25)
            d.zPosition = -18
            cam.addChild(d)
            dashes.append(d)
        }
        layers.append(Layer(nodes: dashes, period: 90, factor: 1.0))
    }

    private func makeLayer(period: CGFloat, factor: CGFloat, color: UIColor, z: CGFloat, baseY: CGFloat, hMin: CGFloat, hMax: CGFloat) -> Layer {
        var nodes: [SKNode] = []
        let count = Int(ceil(W / period)) + 3
        for _ in 0..<count {
            let h = CGFloat.random(in: hMin...hMax)
            let hill = Art.ell(period * 1.5, h * 2, color, 0, baseY)
            hill.zPosition = z
            cam.addChild(hill)
            nodes.append(hill)
        }
        return Layer(nodes: nodes, period: period, factor: factor)
    }

    private func updateParallax() {
        for l in layers {
            let off = cam.position.x * l.factor
            let m = off.truncatingRemainder(dividingBy: l.period)
            for (i, n) in l.nodes.enumerated() {
                n.position.x = -W / 2 - l.period + CGFloat(i) * l.period - m
            }
        }
    }

    private func buildHUD() {
        let top = H / 2
        for l in [scoreLabel, multLabel, heartsLabel, powerLabel] {
            l.zPosition = 1000
            cam.addChild(l)
        }
        scoreLabel.fontSize = 26
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -W / 2 + 60, y: top - 42)

        multLabel.fontSize = 22
        multLabel.fontColor = UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)
        multLabel.horizontalAlignmentMode = .center
        multLabel.position = CGPoint(x: 0, y: top - 40)

        heartsLabel.fontSize = 26
        heartsLabel.fontColor = UIColor(red: 1, green: 0.3, blue: 0.4, alpha: 1)
        heartsLabel.horizontalAlignmentMode = .right
        heartsLabel.position = CGPoint(x: W / 2 - 60, y: top - 42)

        powerLabel.fontSize = 15
        powerLabel.horizontalAlignmentMode = .center
        powerLabel.position = CGPoint(x: 0, y: top - 66)

        barBack.zPosition = 1000
        barFill.zPosition = 1001
        barBack.position = CGPoint(x: -W / 2 + 60, y: top - 56)
        barFill.position = barBack.position
        barBack.strokeColor = .clear
        barFill.strokeColor = .clear
        barBack.fillColor = UIColor(white: 1, alpha: 0.2)
        barFill.fillColor = UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)
        cam.addChild(barBack)
        cam.addChild(barFill)
        updateHUD()
    }

    // MARK: Menu / game flow

    private func clearWorld() {
        for n in creatures { n.removeFromParent() }
        for n in missiles { n.removeFromParent() }
        for n in turrets { n.removeFromParent() }
        for n in birds { n.removeFromParent() }
        for n in pickups { n.removeFromParent() }
        for n in decor { n.removeFromParent() }
        creatures = []; missiles = []; turrets = []; birds = []; pickups = []; decor = []
    }

    private func resetRun() {
        clearWorld()
        score = 0
        health = Tuning.maxHealth
        streak = 0
        tier = 0
        idle = 0
        invul = 0
        rampage = 0; magnet = 0; multiply = 0
        elapsed = 0
        boost = 0
        touchX = nil
        ufo.position = CGPoint(x: W * 0.2, y: ufoY)
        ufo.alpha = 1
        beamX = ufo.position.x + 90
        cam.position = CGPoint(x: ufo.position.x + W * 0.22, y: H / 2)
        nextCreatureX = ufo.position.x + 140
        nextTurretX = ufo.position.x + W * 2.2
        nextBirdX = ufo.position.x + W * 3
        nextDecorX = ufo.position.x - W * 0.5
        nextCloudX = ufo.position.x - W * 0.5
        nextPickupX = ufo.position.x + W * 1.6
        spawnAhead()
        updateHUD()
    }

    private func showMenu() {
        state = .menu
        overlay.removeFromParent()
        overlay = SKNode()
        overlay.zPosition = 2000
        cam.addChild(overlay)

        resetRun()

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "LITTLE ALIEN"
        title.fontSize = 46
        title.fontColor = UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
        title.position = CGPoint(x: 0, y: H * 0.1)
        overlay.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Bold")
        sub.text = "Drag your finger to beam up everything!"
        sub.fontSize = 17
        sub.fontColor = .white
        sub.position = CGPoint(x: 0, y: H * 0.1 - 32)
        overlay.addChild(sub)

        let tap = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        tap.text = "TAP TO START"
        tap.fontSize = 22
        tap.fontColor = UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)
        tap.position = CGPoint(x: 0, y: H * 0.1 - 72)
        tap.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        overlay.addChild(tap)

        if best > 0 {
            let b = SKLabelNode(fontNamed: "AvenirNext-Bold")
            b.text = "Best: \(best)"
            b.fontSize = 16
            b.fontColor = UIColor(white: 1, alpha: 0.8)
            b.position = CGPoint(x: 0, y: H * 0.1 - 100)
            overlay.addChild(b)
        }
    }

    private func startGame() {
        overlay.removeFromParent()
        overlay = SKNode()
        cam.addChild(overlay)
        resetRun()
        state = .playing
        banner("Beam them up!")
    }

    private func gameOver() {
        state = .over
        overTimer = 0
        touchX = nil
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: "littleAlienBest")
        }
        hapticHeavy.impactOccurred()
        ufo.run(.fadeAlpha(to: 0.0, duration: 0.5))

        overlay.removeFromParent()
        overlay = SKNode()
        overlay.zPosition = 2000
        cam.addChild(overlay)

        let dim = Art.rect(W + 4, H + 4, UIColor(white: 0, alpha: 0.5))
        overlay.addChild(dim)

        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = "GAME OVER"
        t.fontSize = 44
        t.fontColor = UIColor(red: 1, green: 0.4, blue: 0.45, alpha: 1)
        t.position = CGPoint(x: 0, y: H * 0.12)
        overlay.addChild(t)

        let s = SKLabelNode(fontNamed: "AvenirNext-Bold")
        s.text = "Score \(score)   Best \(best)"
        s.fontSize = 22
        s.fontColor = .white
        s.position = CGPoint(x: 0, y: H * 0.12 - 40)
        overlay.addChild(s)

        let r = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        r.text = "TAP TO PLAY AGAIN"
        r.fontSize = 20
        r.fontColor = UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)
        r.position = CGPoint(x: 0, y: H * 0.12 - 80)
        r.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        overlay.addChild(r)
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        switch state {
        case .menu:
            startGame()
            touchX = t.location(in: self).x
        case .over:
            if overTimer > 0.8 {
                ufo.removeAllActions()
                startGame()
            }
        case .playing:
            touchX = t.location(in: self).x
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .playing, let t = touches.first else { return }
        touchX = t.location(in: self).x
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchX = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchX = nil
    }

    // MARK: Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let dt = CGFloat(min(currentTime - lastTime, 1.0 / 20.0))
        lastTime = currentTime
        guard W > 0 else { return }
        clock += dt

        switch state {
        case .menu:
            ufo.position.y = ufoY + sin(clock * 3) * 6
            drawBeam()
        case .playing:
            step(dt)
        case .over:
            overTimer += dt
        }
        updateParallax()
    }

    private func pullRadius() -> CGFloat {
        var r: CGFloat = rampage > 0 ? 70 : 38
        if magnet > 0 { r += 55 }
        return r
    }

    private func step(_ dt: CGFloat) {
        elapsed += dt
        let difficulty = min(1, elapsed / 120)

        let targetBoost = Tuning.tierSpeedBoost[tier]
        boost += (targetBoost - boost) * min(1, dt * 2)
        let speed = Tuning.baseSpeed + difficulty * Tuning.maxExtraSpeed + boost
        ufo.position.x += speed * dt
        ufo.position.y = ufoY + sin(clock * 3) * 6
        cam.position = CGPoint(x: ufo.position.x + W * 0.22, y: H / 2)

        // Beam target follows finger
        let desired: CGFloat
        if let tx = touchX {
            desired = min(max(tx, ufo.position.x - W * 0.3), ufo.position.x + W * 0.55)
        } else {
            desired = ufo.position.x + 90
        }
        beamX += (desired - beamX) * min(1, dt * 10)
        ufoArt.zRotation = max(-0.3, min(0.3, (ufo.position.x - beamX) / W * 0.5))

        drawBeam()
        spawnAhead()
        updateCreatures(dt)
        updatePickups(dt)
        updateTurrets(dt)
        updateMissiles(dt)
        updateBirds(dt)
        cleanup()

        // Timers
        if invul > 0 {
            invul -= dt
            ufo.alpha = (Int(clock * 14) % 2 == 0) ? 0.35 : 1
            if invul <= 0 { ufo.alpha = 1 }
        }
        rampage = max(0, rampage - dt)
        magnet = max(0, magnet - dt)
        multiply = max(0, multiply - dt)

        if tier > 0 {
            idle += dt
            if idle > 6 {
                idle = 0
                tier -= 1
                streak = Tuning.tierThresholds[tier]
            }
        }
        updateHUD()
    }

    private func drawBeam() {
        let r = pullRadius()
        let top = CGPoint(x: ufo.position.x, y: ufo.position.y - 12)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: top.x - 12, y: top.y))
        p.addLine(to: CGPoint(x: beamX - r, y: groundTop))
        p.addLine(to: CGPoint(x: beamX + r, y: groundTop))
        p.addLine(to: CGPoint(x: top.x + 12, y: top.y))
        p.closeSubpath()
        beam.path = p
        let col: UIColor = rampage > 0 ? UIColor(red: 1, green: 0.5, blue: 0.5, alpha: 0.4)
            : (magnet > 0 ? UIColor(red: 0.5, green: 0.7, blue: 1, alpha: 0.4) : UIColor(red: 0.6, green: 1, blue: 0.8, alpha: 0.35))
        beam.fillColor = col
        beamRing.path = CGPath(ellipseIn: CGRect(x: beamX - r, y: groundTop - 8, width: r * 2, height: 16), transform: nil)
    }

    // MARK: Spawning

    private func spawnAhead() {
        let limit = ufo.position.x + W * 1.3

        while nextCreatureX < limit {
            let vehicles = elapsed.truncatingRemainder(dividingBy: 45) >= 30
            let kind: Kind
            let roll = Int.random(in: 0..<100)
            if vehicles && roll < 55 {
                kind = .car
            } else if roll < 45 {
                kind = .human
            } else if roll < 62 {
                kind = .kid
            } else if roll < 80 {
                kind = .dog
            } else {
                kind = .cow
            }
            let c = Creature(kind: kind)
            c.addChild(Art.creature(kind))
            c.baseY = groundTop - 4 + CGFloat.random(in: -6...10)
            if kind == .car { c.baseY = groundTop * 0.3 }
            c.position = CGPoint(x: nextCreatureX, y: c.baseY)
            c.zPosition = 10 - c.baseY / 100
            if c.dir < 0 { c.xScale = -1 }
            addChild(c)
            creatures.append(c)
            let diff = min(1, elapsed / 120)
            nextCreatureX += CGFloat.random(in: 45...130) / (1 + diff * 0.4)
        }

        while nextDecorX < limit {
            let n = Bool.random() ? Art.tree() : Art.house()
            let s = CGFloat.random(in: 0.9...1.3)
            n.setScale(s)
            n.position = CGPoint(x: nextDecorX, y: groundTop + CGFloat.random(in: -2...6))
            n.zPosition = -10
            addChild(n)
            decor.append(n)
            nextDecorX += CGFloat.random(in: 110...260)
        }

        while nextCloudX < limit {
            let n = Art.cloud()
            n.setScale(CGFloat.random(in: 0.8...1.8))
            n.position = CGPoint(x: nextCloudX, y: CGFloat.random(in: H * 0.5...H * 0.92))
            n.zPosition = -50
            addChild(n)
            decor.append(n)
            nextCloudX += CGFloat.random(in: 260...520)
        }

        if state != .playing { return }
        let diff = min(1, elapsed / 120)

        while nextTurretX < limit {
            let t = Turret()
            t.addChild(Art.tank())
            t.position = CGPoint(x: nextTurretX, y: groundTop - 6)
            t.zPosition = 9
            addChild(t)
            turrets.append(t)
            nextTurretX += CGFloat.random(in: 420...800) * (1 - diff * 0.45)
        }

        while nextBirdX < limit {
            let n = Int.random(in: 2...4)
            let baseY = ufoY + CGFloat.random(in: -50...50)
            for i in 0..<n {
                let b = Bird()
                b.addChild(Art.bird())
                b.vx = -CGFloat.random(in: 40...80)
                b.position = CGPoint(x: nextBirdX + CGFloat(i) * 34, y: baseY + CGFloat(i % 2) * 22)
                b.zPosition = 45
                addChild(b)
                birds.append(b)
            }
            nextBirdX += CGFloat.random(in: 700...1300) * (1 - diff * 0.4)
        }

        while nextPickupX < limit {
            let types: [PowerType] = [.rampage, .magnet, .multiply]
            let p = Pickup(type: types[Int.random(in: 0..<3)])
            p.addChild(Art.capsule(p.type))
            p.baseY = groundTop + 34
            p.position = CGPoint(x: nextPickupX, y: p.baseY)
            p.zPosition = 20
            addChild(p)
            pickups.append(p)
            nextPickupX += CGFloat.random(in: 900...1500)
        }
    }

    // MARK: Entities

    private func updateCreatures(_ dt: CGFloat) {
        let pr = pullRadius()
        let ufoPos = ufo.position
        var collected: [Creature] = []

        for c in creatures {
            if !c.lifted {
                if c.position.y > c.baseY + 0.5 {
                    // falling back down
                    c.fallV += 900 * dt
                    c.position.y = max(c.baseY, c.position.y - c.fallV * dt)
                    c.zRotation *= 0.9
                    if c.position.y <= c.baseY { c.fallV = 0; c.zRotation = 0 }
                } else {
                    var sp = c.walkSpeed
                    if c.kind != .car && abs(c.position.x - beamX) < pr + 70 {
                        // panic: run away from the beam
                        let d: CGFloat = (c.position.x >= beamX) ? 1 : -1
                        if d != c.dir { c.dir = d; c.xScale = d }
                        sp *= 1.6
                    }
                    c.position.x += c.dir * sp * dt
                }
                if abs(c.position.x - beamX) < pr && c.position.y <= c.baseY + 6 && c.position.x > ufoPos.x - W * 0.4 {
                    c.lifted = true
                }
            } else {
                let span = max(1, ufoPos.y - groundTop)
                let t = max(0, min(1, (ufoPos.y - c.position.y) / span))
                let lineX = ufoPos.x + (beamX - ufoPos.x) * t
                if abs(c.position.x - lineX) > pr * 0.9 + 14 {
                    c.lifted = false
                    c.fallV = 0
                } else {
                    let rise = Tuning.pullSpeed * c.kind.weight * (rampage > 0 ? 1.6 : 1) * (magnet > 0 ? 1.2 : 1)
                    c.position.y += rise * dt
                    c.position.x += (lineX - c.position.x) * min(1, dt * 6)
                    c.zRotation = sin(c.wob + clock * 8) * 0.35
                    if c.position.y >= ufoPos.y - 24 {
                        collected.append(c)
                    }
                }
            }
        }

        for c in collected { collect(c) }
    }

    private func collect(_ c: Creature) {
        let mult = Tuning.tierMultiplier[tier]
        let pts = c.kind.points * mult * (multiply > 0 ? 2 : 1)
        score += pts
        streak += c.kind.streakValue
        idle = 0
        let oldTier = tier
        while tier + 1 < Tuning.tierThresholds.count && streak >= Tuning.tierThresholds[tier + 1] {
            tier += 1
        }
        if tier > oldTier {
            banner("x\(Tuning.tierMultiplier[tier]) speed up!")
        }
        popup("+\(pts)", at: ufo.position)
        hapticLight.impactOccurred()
        c.removeFromParent()
        creatures.removeAll { $0 === c }
    }

    private func updatePickups(_ dt: CGFloat) {
        let pr = pullRadius() + 8
        var taken: [Pickup] = []
        for p in pickups {
            p.position.y = p.baseY + sin(clock * 3 + p.position.x) * 4
            if abs(p.position.x - beamX) < pr {
                taken.append(p)
            }
        }
        for p in taken {
            switch p.type {
            case .rampage: rampage = Tuning.powerDuration; banner("RAMPAGE! Wide beam")
            case .magnet: magnet = Tuning.powerDuration; banner("MAGNET! Pulls from far")
            case .multiply: multiply = Tuning.powerDuration; banner("DOUBLE SCORE!")
            }
            hapticLight.impactOccurred()
            p.removeFromParent()
            pickups.removeAll { $0 === p }
        }
    }

    private func updateTurrets(_ dt: CGFloat) {
        for t in turrets where !t.fired {
            let dx = t.position.x - ufo.position.x
            if dx > 0 && dx < W * 0.6 {
                t.fired = true
                fire(from: t)
            }
        }
    }

    private func fire(from t: Turret) {
        let m = Missile()
        m.addChild(Art.missile())
        let start = CGPoint(x: t.position.x + 10, y: t.position.y + 30)
        m.position = start
        let speed: CGFloat = 250
        let dist = hypot(ufo.position.x - start.x, ufo.position.y - start.y)
        let travel = dist / speed
        let ahead = CGPoint(x: ufo.position.x + (Tuning.baseSpeed + boost) * travel, y: ufo.position.y)
        let ang = atan2(ahead.y - start.y, ahead.x - start.x)
        m.v = CGVector(dx: cos(ang) * speed, dy: sin(ang) * speed)
        m.zRotation = ang
        m.zPosition = 46
        addChild(m)
        missiles.append(m)
    }

    private func updateMissiles(_ dt: CGFloat) {
        var dead: [Missile] = []
        for m in missiles {
            m.position.x += m.v.dx * dt
            m.position.y += m.v.dy * dt
            m.life -= dt
            if m.life <= 0 { dead.append(m); continue }
            if invul <= 0 && hypot(m.position.x - ufo.position.x, m.position.y - ufo.position.y) < 30 {
                dead.append(m)
                hurt()
            }
        }
        for m in dead {
            boom(at: m.position)
            m.removeFromParent()
            missiles.removeAll { $0 === m }
        }
    }

    private func updateBirds(_ dt: CGFloat) {
        for b in birds {
            b.position.x += b.vx * dt
            if invul <= 0 && state == .playing && hypot(b.position.x - ufo.position.x, b.position.y - ufo.position.y) < 26 {
                hurt()
                b.removeFromParent()
                birds.removeAll { $0 === b }
                break
            }
        }
    }

    private func hurt() {
        health -= 1
        invul = 1.6
        tier = max(0, tier - 1)
        streak = Tuning.tierThresholds[tier]
        rampage = 0; magnet = 0; multiply = 0
        hapticHeavy.impactOccurred()
        cam.run(.sequence([.moveBy(x: 0, y: 8, duration: 0.04), .moveBy(x: 0, y: -16, duration: 0.06), .moveBy(x: 0, y: 8, duration: 0.04)]))
        if health <= 0 {
            health = 0
            updateHUD()
            gameOver()
        } else {
            banner("Ouch!")
        }
    }

    private func boom(at p: CGPoint) {
        let c = Art.circ(10, UIColor.orange.withAlphaComponent(0.9), p.x, p.y)
        c.zPosition = 60
        addChild(c)
        c.run(.sequence([.group([.scale(to: 3.5, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    private func cleanup() {
        let left = cam.position.x - W / 2 - 200
        creatures.removeAll { n in
            if n.position.x < left || n.position.x > ufo.position.x + W * 3 { n.removeFromParent(); return true }
            return false
        }
        turrets.removeAll { n in if n.position.x < left { n.removeFromParent(); return true }; return false }
        birds.removeAll { n in if n.position.x < left { n.removeFromParent(); return true }; return false }
        pickups.removeAll { n in if n.position.x < left { n.removeFromParent(); return true }; return false }
        decor.removeAll { n in if n.position.x < left { n.removeFromParent(); return true }; return false }
        missiles.removeAll { n in if n.position.x < left || n.position.y < -50 { n.removeFromParent(); return true }; return false }
    }

    // MARK: HUD & popups

    private func updateHUD() {
        scoreLabel.text = "\(score)"
        multLabel.text = "x\(Tuning.tierMultiplier[tier])"
        heartsLabel.text = String(repeating: "♥", count: max(0, health)) + String(repeating: "♡", count: max(0, Tuning.maxHealth - health))

        var parts: [String] = []
        if rampage > 0 { parts.append("RAMPAGE \(Int(ceil(rampage)))s") }
        if magnet > 0 { parts.append("MAGNET \(Int(ceil(magnet)))s") }
        if multiply > 0 { parts.append("x2 SCORE \(Int(ceil(multiply)))s") }
        powerLabel.text = parts.joined(separator: "   ")
        powerLabel.fontColor = UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 1)

        // streak progress bar toward the next multiplier
        let barW: CGFloat = 110
        let lo = Tuning.tierThresholds[tier]
        let hi = tier + 1 < Tuning.tierThresholds.count ? Tuning.tierThresholds[tier + 1] : lo + 1
        let frac = tier + 1 < Tuning.tierThresholds.count ? CGFloat(streak - lo) / CGFloat(max(1, hi - lo)) : 1
        barBack.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: barW, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil)
        barFill.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: max(2, barW * max(0, min(1, frac))), height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil)
    }

    private func popup(_ text: String, at p: CGPoint) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 20
        l.fontColor = UIColor(red: 1, green: 0.95, blue: 0.4, alpha: 1)
        l.position = CGPoint(x: p.x, y: p.y + 10)
        l.zPosition = 900
        addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 40, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }

    private func banner(_ text: String) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 28
        l.fontColor = .white
        l.position = CGPoint(x: 0, y: H * 0.05)
        l.zPosition = 1500
        l.setScale(0.5)
        cam.addChild(l)
        l.run(.sequence([.scale(to: 1, duration: 0.15), .wait(forDuration: 0.8), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
}
