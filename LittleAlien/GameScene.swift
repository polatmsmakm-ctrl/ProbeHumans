import SpriteKit
import UIKit

/// Pseudo-3D farm field seen from above at an angle. Everything on the ground lives in
/// ground space (x = world units along the field, d = depth into the screen) and is
/// projected to the screen every frame.
final class GameScene: SKScene {
    enum Screen { case menu, store, settings, playing, paused, over }
    enum UFOStatus { case intro, play, boost, dead }
    enum StoreTab: Int { case ufo, powers, items, animals }

    private let store = Store.shared
    private let sound = Sound.shared

    // MARK: Layout / projection
    private var W: CGFloat = 0
    private var H: CGFloat = 0
    private var ws: CGFloat = 1
    private var P: CGFloat = 1.5          // projection factor (screen points per world unit at depth 1)
    private var horizonV: CGFloat = 0     // vanishing line
    private var A: CGFloat = 0            // y(d) = horizonV - A / d
    private let dMin: CGFloat = 1.1
    private let dMax: CGFloat = 3.1
    private var fieldTop: CGFloat = 0
    private var camX: CGFloat = 0

    private func sy(_ d: CGFloat) -> CGFloat { return horizonV - A / d }
    private func sc(_ d: CGFloat) -> CGFloat { return P / d }
    private func sx(_ x: CGFloat, _ d: CGFloat) -> CGFloat { return W * 0.5 + (x - camX) * P / d }
    private func depth(atY y: CGFloat) -> CGFloat { return A / max(1, horizonV - y) }
    private func worldX(atX x: CGFloat, d: CGFloat) -> CGFloat { return camX + (x - W * 0.5) * d / P }
    private func roadD(_ x: CGFloat) -> CGFloat {
        return 2.05 + 0.6 * sin(x / 1150) + 0.22 * sin(x / 430 + 2)
    }

    // MARK: Nodes
    private let bg = SKNode()
    private let world = SKNode()
    private let road = SKShapeNode()
    private let roadEdge = SKShapeNode()
    private let beamGlow = SKShapeNode()
    private let beamCore = SKShapeNode()
    private let beamRing = SKShapeNode()
    private let crosshair = SKNode()
    private var sparkles: [(SKSpriteNode, CGFloat, CGFloat)] = []
    private let liftLayer = SKNode()
    private let ufo = SKNode()
    private var ufoArt = SKNode()
    private let fx = SKNode()
    private var vignette = SKSpriteNode()
    private var redFlash = SKSpriteNode()
    private let ui = SKNode()
    private let hud = SKNode()
    private var overlay = SKNode()
    private var buttons: [Button] = []
    private var clouds: [SKNode] = []
    private var trees: [SKNode] = []
    private var hills: [SKNode] = []

    // HUD
    private var scoreLabel = SKLabelNode()
    private var multLabel = SKLabelNode()
    private let ringTrack = SKShapeNode()
    private let ringFill = SKShapeNode()
    private var healthBars: [SKShapeNode] = []
    private var coinLabel = SKLabelNode()
    private var distLabel = SKLabelNode()
    private var powerLabel = SKLabelNode()
    private var pauseButton: Button?

    // MARK: Run state
    private var screen: Screen = .menu
    private var status: UFOStatus = .intro
    private var storeTab: StoreTab = .powers
    private var storePage = 0
    private var runCfg = RunConfig()
    private var lastTime: TimeInterval = 0
    private var clock: CGFloat = 0
    private var elapsed: CGFloat = 0
    private var overTimer: CGFloat = 0

    private var touching = false
    private var lastTouch: CGPoint = .zero
    private var target = CGPoint.zero        // where the finger wants the beam (screen)
    private var beamPt = CGPoint.zero        // smoothed beam end (screen)
    private var ufoPos = CGPoint.zero        // screen
    private var ufoVel: CGFloat = 0
    private var ufoDepth: CGFloat = 2
    private var beamOn = false

    private var moveSpeed: CGFloat = Tuning.startSpeed
    private var streakSpeed: CGFloat = 0
    private var curSpeed: CGFloat = 0
    private var distance = 0
    private var boostUntil: CGFloat = 0
    private var score = 0
    private var runCoins = 0
    private var health = 3
    private var maxHealth = 3
    private var level = 0
    private var collectedStreak = 0
    private var sinceCollect: CGFloat = 0
    private var invincible: CGFloat = 0
    private var damageTimer: CGFloat = 0
    private var power: PowerType?
    private var powerTimer: CGFloat = 0
    private var secondChance = false
    private var tutorial = false
    private var abducted = 0
    private var deathV = CGVector.zero
    private var bouncesLeft = 0

    private var inVehicleState = false
    private var stateTimer: CGFloat = 0
    private var vehicleDuration = Tuning.vehicleDuration
    private var vehicleDifficulty = 0
    private var nextVehicleIn: CGFloat = 1
    private var nextTankIn: CGFloat = 18

    // Entities
    private var creatures: [Creature] = []
    private var obstacles: [Obstacle] = []
    private var coins: [Coin] = []
    private var pickups: [Pickup] = []
    private var decals: [Decal] = []
    private var missiles: [Missile] = []
    private var flocks: [Flock] = []

    private var nextGroupX: CGFloat = 0
    private var nextStaticX: CGFloat = 0
    private var nextCoinX: CGFloat = 0
    private var nextPickupX: CGFloat = 0
    private var nextTuftX: CGFloat = 0
    private var nextSign = Tuning.signEvery
    private var pendingSigns: [(CGFloat, [String])] = []

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Setup

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        setup()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil, size.width > 0, size.height > 0, size != oldSize else { return }
        setup()
    }

    private func setup() {
        removeAllChildren()
        removeAllActions()
        for n in [bg, world, liftLayer, ufo, fx, ui, hud] { n.removeAllChildren() }
        creatures = []; obstacles = []; coins = []; pickups = []; decals = []; missiles = []; flocks = []
        clouds = []; trees = []; hills = []; sparkles = []; healthBars = []

        anchorPoint = .zero
        W = size.width
        H = size.height
        ws = max(0.85, min(1.6, H / 390))
        P = 1.5 * ws
        horizonV = H * 0.8
        A = H * 0.8
        fieldTop = H * 0.6
        backgroundColor = Art.rgb(0.12, 0.08, 0.25)

        bg.zPosition = -1000
        addChild(bg)
        buildBackground()

        world.zPosition = 0
        addChild(world)
        road.zPosition = 2
        road.lineWidth = 0
        road.fillColor = Art.rgb(0.28, 0.38, 0.36, 0.9)
        road.strokeColor = .clear
        world.addChild(road)
        roadEdge.zPosition = 3
        roadEdge.lineWidth = 1.5
        roadEdge.strokeColor = Art.rgb(0.2, 0.28, 0.27, 0.8)
        roadEdge.fillColor = .clear
        world.addChild(roadEdge)

        for n in [beamGlow, beamCore] {
            n.lineWidth = 0
            n.strokeColor = .clear
            n.blendMode = .add
            n.zPosition = 600
            addChild(n)
        }
        beamRing.zPosition = 601
        beamRing.blendMode = .add
        beamRing.lineWidth = 2
        addChild(beamRing)
        buildCrosshair()
        let dot = Art.softDot()
        for _ in 0..<16 {
            let s = SKSpriteNode(texture: dot)
            s.size = CGSize(width: 7 * ws, height: 7 * ws)
            s.blendMode = .add
            s.zPosition = 602
            addChild(s)
            sparkles.append((s, CGFloat.random(in: 0...1), CGFloat.random(in: -1...1)))
        }

        liftLayer.zPosition = 650
        addChild(liftLayer)
        ufo.zPosition = 700
        addChild(ufo)
        setUFOArt()
        fx.zPosition = 720
        addChild(fx)

        vignette = SKSpriteNode(texture: Art.vignette(size: CGSize(width: 256, height: 256 * H / W), color: .black, strength: 0.75))
        vignette.size = size
        vignette.position = CGPoint(x: W / 2, y: H / 2)
        vignette.zPosition = 900
        addChild(vignette)
        redFlash = SKSpriteNode(texture: Art.vignette(size: CGSize(width: 256, height: 256 * H / W), color: .red, strength: 0.95))
        redFlash.size = size
        redFlash.position = vignette.position
        redFlash.zPosition = 901
        redFlash.alpha = 0
        addChild(redFlash)

        ui.position = CGPoint(x: W / 2, y: H / 2)
        ui.zPosition = 1000
        addChild(ui)
        hud.zPosition = 0
        ui.addChild(hud)
        buildHUD()

        showMenu()
    }

    private func setUFOArt() {
        ufoArt.removeFromParent()
        ufoArt = Art.ufo(store.d.selectedUFO)
        ufoArt.setScale(1.35 * ws)
        ufo.addChild(ufoArt)
    }

    private func buildCrosshair() {
        crosshair.removeAllChildren()
        crosshair.removeFromParent()
        let c = SKShapeNode(circleOfRadius: 10)
        c.strokeColor = UIColor(white: 1, alpha: 0.9)
        c.lineWidth = 1.5
        c.fillColor = .clear
        crosshair.addChild(c)
        for a in [0, CGFloat.pi / 2, .pi, .pi * 1.5] {
            let l = Art.line(CGPoint(x: cos(a) * 6, y: sin(a) * 6), CGPoint(x: cos(a) * 13, y: sin(a) * 13), UIColor(white: 1, alpha: 0.9), 1.5)
            crosshair.addChild(l)
        }
        crosshair.zPosition = 603
        addChild(crosshair)
    }

    private func buildBackground() {
        let sky = SKSpriteNode(texture: Art.gradient(size: CGSize(width: 8, height: 256),
                                                      colors: [Art.rgb(0.1, 0.07, 0.24), Art.rgb(0.3, 0.2, 0.52), Art.rgb(0.6, 0.42, 0.72)],
                                                      locations: [0, 0.5, 1]))
        sky.anchorPoint = CGPoint(x: 0, y: 0)
        sky.size = CGSize(width: W, height: H - fieldTop + 30)
        sky.position = CGPoint(x: 0, y: fieldTop - 30)
        sky.zPosition = 0
        bg.addChild(sky)

        for i in 0..<14 {
            let s = Art.circ(CGFloat.random(in: 0.6...1.4), UIColor(white: 1, alpha: 0.7), CGFloat.random(in: 0...W), CGFloat.random(in: H * 0.8...H))
            s.zPosition = 1
            s.run(.repeatForever(.sequence([.wait(forDuration: Double(i) * 0.2), .fadeAlpha(to: 0.2, duration: 0.8), .fadeAlpha(to: 0.8, duration: 0.8)])))
            bg.addChild(s)
        }

        // far hills (lavender silhouettes)
        let hillW: CGFloat = 260 * ws
        for i in 0..<Int(ceil(W / hillW)) + 2 {
            let h = SKNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 0))
            p.addQuadCurve(to: CGPoint(x: hillW * 0.5, y: CGFloat.random(in: 26...46) * ws), control: CGPoint(x: hillW * 0.2, y: 30 * ws))
            p.addQuadCurve(to: CGPoint(x: hillW, y: 0), control: CGPoint(x: hillW * 0.8, y: 34 * ws))
            p.closeSubpath()
            let shape = SKShapeNode(path: p)
            shape.fillColor = Art.rgb(0.42, 0.33, 0.6)
            shape.strokeColor = .clear
            h.addChild(shape)
            h.position = CGPoint(x: CGFloat(i) * hillW, y: fieldTop + 4 * ws)
            h.zPosition = 2
            bg.addChild(h)
            hills.append(h)
        }
        for i in 0..<5 {
            let c = Art.cloud()
            c.setScale(CGFloat.random(in: 0.8...1.4) * ws)
            c.position = CGPoint(x: CGFloat(i) * W / 4 + CGFloat.random(in: -40...40), y: CGFloat.random(in: H * 0.8...H * 0.95))
            c.zPosition = 3
            bg.addChild(c)
            clouds.append(c)
        }

        // field: bright teal by the horizon fading to dark at the bottom
        let field = SKSpriteNode(texture: Art.gradient(size: CGSize(width: 8, height: 256),
                                                        colors: [Art.rgb(0.32, 0.72, 0.72), Art.rgb(0.16, 0.55, 0.57), Art.rgb(0.08, 0.36, 0.39), Art.rgb(0.03, 0.17, 0.2)],
                                                        locations: [0, 0.18, 0.55, 1]))
        field.anchorPoint = .zero
        field.size = CGSize(width: W, height: fieldTop + 2)
        field.position = .zero
        field.zPosition = 4
        bg.addChild(field)

        // tree line along the horizon
        let tw: CGFloat = 46 * ws
        for i in 0..<Int(ceil(W / tw)) + 3 {
            let b = Art.bush()
            b.setScale(CGFloat.random(in: 0.9...1.5) * ws)
            b.position = CGPoint(x: CGFloat(i) * tw, y: fieldTop - 6 * ws)
            b.zPosition = 6
            bg.addChild(b)
            trees.append(b)
        }
        let band = Art.rect(W, 8 * ws, Art.rgb(0.05, 0.25, 0.28), W / 2, fieldTop - 6 * ws)
        band.zPosition = 6
        bg.addChild(band)

        // mist over the far field
        let fog = SKSpriteNode(texture: Art.gradient(size: CGSize(width: 8, height: 64),
                                                      colors: [Art.rgb(0.6, 0.9, 0.9, 0.0), Art.rgb(0.55, 0.85, 0.85, 0.35), Art.rgb(0.5, 0.8, 0.8, 0)],
                                                      locations: [0, 0.4, 1]))
        fog.anchorPoint = .zero
        fog.size = CGSize(width: W, height: H * 0.16)
        fog.position = CGPoint(x: 0, y: fieldTop - H * 0.12)
        fog.zPosition = 7
        bg.addChild(fog)
    }

    private func scrollBackground(_ dx: CGFloat) {
        let tw: CGFloat = 46 * ws
        for t in trees {
            t.position.x -= dx * P / 3.4
            if t.position.x < -tw * 1.5 { t.position.x += tw * CGFloat(trees.count) }
        }
        let hw: CGFloat = 260 * ws
        for h in hills {
            h.position.x -= dx * P / 9
            if h.position.x < -hw { h.position.x += hw * CGFloat(hills.count) }
        }
        for c in clouds {
            c.position.x -= dx * P / 20 + 0.08
            if c.position.x < -120 * ws { c.position.x = W + 120 * ws; c.position.y = CGFloat.random(in: H * 0.8...H * 0.95) }
        }
    }

    // MARK: - HUD

    private func buildHUD() {
        let top = H / 2
        let ringR: CGFloat = 19
        let rx: CGFloat = -10
        let ry = top - 34
        ringTrack.removeFromParent()
        ringFill.removeFromParent()
        ringTrack.path = CGPath(ellipseIn: CGRect(x: -ringR, y: -ringR, width: ringR * 2, height: ringR * 2), transform: nil)
        ringTrack.strokeColor = UIColor(white: 0, alpha: 0.4)
        ringTrack.lineWidth = 5
        ringTrack.fillColor = Art.rgb(0.08, 0.15, 0.3, 0.6)
        ringTrack.position = CGPoint(x: rx, y: ry)
        hud.addChild(ringTrack)
        ringFill.strokeColor = UIK.cyan
        ringFill.lineWidth = 4
        ringFill.lineCap = .round
        ringFill.position = ringTrack.position
        hud.addChild(ringFill)
        multLabel = UIK.label("1X", size: 15, color: UIK.cyan, font: UIK.heavyItalic, x: rx, y: ry)
        hud.addChild(multLabel)

        scoreLabel = UIK.label("0", size: 30, color: UIK.cyan, font: UIK.heavyItalic, x: rx + 28, y: ry - 6, align: .left,
                               shadow: Art.rgb(0.05, 0.1, 0.25, 0.8))
        hud.addChild(scoreLabel)

        let heart = UIK.label("♡", size: 18, color: UIK.cyan, font: "AvenirNext-Bold", x: rx + 34, y: top - 14, shadow: nil)
        heart.name = "heart"
        hud.addChild(heart)

        coinLabel = UIK.label("0", size: 16, color: UIK.yellow, font: UIK.heavyItalic, x: -W / 2 + 44, y: top - 22, align: .left)
        let ci = UIK.coinIcon(8)
        ci.position = CGPoint(x: -W / 2 + 32, y: top - 22)
        hud.addChild(ci)
        hud.addChild(coinLabel)
        distLabel = UIK.label("0 M", size: 14, color: UIColor(white: 1, alpha: 0.85), font: UIK.heavyItalic, x: -W / 2 + 26, y: top - 44, align: .left)
        hud.addChild(distLabel)
        powerLabel = UIK.label("", size: 16, color: .white, font: UIK.heavyItalic, x: 0, y: top - 74)
        hud.addChild(powerLabel)

        let pb = Button("II", w: 46, h: 40, fontSize: 26, plain: true) { [weak self] in self?.pauseGame() }
        pb.position = CGPoint(x: W / 2 - 34, y: top - 26)
        hud.addChild(pb)
        pauseButton = pb
        hud.isHidden = true
        rebuildHealthBars()
    }

    private func rebuildHealthBars() {
        for b in healthBars { b.removeFromParent() }
        healthBars = []
        let top = H / 2
        let segW: CGFloat = 22, segH: CGFloat = 6
        for i in 0..<max(3, maxHealth) {
            let s = SKShapeNode(rectOf: CGSize(width: segW, height: segH), cornerRadius: 3)
            s.position = CGPoint(x: 42 + CGFloat(i) * (segW + 4) + segW / 2, y: top - 14)
            s.lineWidth = 1.2
            hud.addChild(s)
            healthBars.append(s)
        }
    }

    private func setText(_ l: SKLabelNode, _ s: String) {
        l.text = s
        (l.children.first as? SKLabelNode)?.text = s
    }

    private func updateHUD() {
        setText(scoreLabel, UIK.coins(score))
        setText(multLabel, "\(multiplier)X")
        setText(coinLabel, "\(runCoins)")
        setText(distLabel, "\(UIK.coins(distance)) M")

        for (i, b) in healthBars.enumerated() {
            if i >= maxHealth { b.isHidden = true; continue }
            b.isHidden = false
            let full = i < health
            b.fillColor = full ? Art.rgb(0.35, 0.8, 1) : UIColor(white: 0, alpha: 0.3)
            b.strokeColor = full ? Art.rgb(0.75, 0.95, 1) : Art.rgb(0.95, 0.25, 0.3)
        }
        if let heart = hud.childNode(withName: "heart") as? SKLabelNode {
            heart.fontColor = (health <= 1 && Int(clock * 4) % 2 == 0) ? Art.rgb(1, 0.3, 0.35) : UIK.cyan
            heart.text = secondChance ? "♥" : "♡"
        }

        let hasNext = level + 1 < Tuning.streakCounts.count
        let lo = Tuning.streakCounts[level]
        let hi = hasNext ? Tuning.streakCounts[level + 1] : lo + 1
        let frac = hasNext ? CGFloat(collectedStreak - lo) / CGFloat(max(1, hi - lo)) : 1
        let r: CGFloat = 19
        let p = CGMutablePath()
        let start = CGFloat.pi / 2
        p.addArc(center: .zero, radius: r, startAngle: start, endAngle: start - max(0.01, min(1, frac)) * .pi * 2, clockwise: true)
        ringFill.path = p
        ringFill.strokeColor = (level > 0 && sinceCollect > Tuning.streakWindow - 2 && Int(clock * 6) % 2 == 0) ? UIK.red : UIK.cyan

        if let pw = power {
            setText(powerLabel, "\(pw.title.uppercased())  \(Int(ceil(powerTimer)))")
            powerLabel.fontColor = pw.color
        } else if status == .boost {
            setText(powerLabel, "HEAD START!")
            powerLabel.fontColor = UIK.yellow
        } else {
            setText(powerLabel, "")
        }
    }

    // MARK: - Overlay helpers

    private func newOverlay(dim: CGFloat = 0) {
        overlay.removeFromParent()
        overlay = SKNode()
        overlay.zPosition = 100
        ui.addChild(overlay)
        buttons = []
        if dim > 0 {
            overlay.addChild(Art.rect(W + 4, H + 4, UIColor(white: 0, alpha: dim)))
        }
    }

    @discardableResult
    private func addButton(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 40, color: UIColor = UIK.orange,
                           fontSize: CGFloat = 18, enabled: Bool = true, plain: Bool = false, coin: Bool = false,
                           to parent: SKNode? = nil, action: @escaping () -> Void) -> Button {
        let b = Button(text, w: w, h: h, color: color, fontSize: fontSize, enabled: enabled, plain: plain, coin: coin, action: action)
        b.position = CGPoint(x: x, y: y)
        (parent ?? overlay).addChild(b)
        buttons.append(b)
        return b
    }

    private func coinBadge() {
        let ci = UIK.coinIcon(9)
        ci.position = CGPoint(x: -W / 2 + 26, y: H / 2 - 22)
        overlay.addChild(ci)
        overlay.addChild(UIK.label(UIK.coins(store.d.coins), size: 18, color: .white, font: UIK.heavyItalic,
                                   x: -W / 2 + 40, y: H / 2 - 22, align: .left))
    }

    // MARK: - Menu

    private func showMenu() {
        screen = .menu
        hud.isHidden = true
        resetWorld()
        status = .intro
        beamOn = true
        newOverlay()
        sound.playMusic("menu_music")

        let s = min(1.15, H / 360)
        let titleY = H * 0.3
        let t1 = UIK.label("LITTLE", size: 34 * s, color: Art.rgb(0.65, 0.95, 1), x: -W * 0.12, y: titleY + 26 * s, shadow: Art.rgb(0.1, 0.1, 0.3))
        let t2 = UIK.label("ALIEN", size: 60 * s, color: UIK.orange, x: -W * 0.12, y: titleY - 18 * s, shadow: UIK.orangeDark)
        t2.zRotation = 0.04
        overlay.addChild(t1)
        overlay.addChild(t2)
        t2.run(.repeatForever(.sequence([.scale(to: 1.04, duration: 0.6), .scale(to: 1, duration: 0.6)])))

        // big wooden PLAY! arrow sign
        let sign = SKNode()
        sign.position = CGPoint(x: -W * 0.12, y: -H * 0.2)
        sign.addChild(Art.rect(8, 70 * s, Art.rgb(0.25, 0.2, 0.3), -10, -30 * s))
        let arrow = Art.poly([CGPoint(x: -90 * s, y: -24 * s), CGPoint(x: 70 * s, y: -24 * s), CGPoint(x: 100 * s, y: 0),
                              CGPoint(x: 70 * s, y: 24 * s), CGPoint(x: -90 * s, y: 24 * s)],
                             Art.rgb(0.22, 0.3, 0.42), stroke: Art.rgb(0.08, 0.1, 0.18))
        arrow.lineWidth = 3
        sign.addChild(arrow)
        overlay.addChild(sign)
        addButton("PLAY!", x: sign.position.x + 2, y: sign.position.y, w: 190 * s, h: 50 * s, fontSize: 34 * s, plain: true) { [weak self] in
            self?.startGame()
        }

        let lx = -W / 2 + 110 * s
        let items: [(String, () -> Void)] = [
            ("STORE", { [weak self] in self?.showStore(.powers) }),
            ("UFOS", { [weak self] in self?.showStore(.ufo) }),
            ("OPTIONS", { [weak self] in self?.showSettings() })
        ]
        for (i, it) in items.enumerated() {
            let b = addButton(it.0, x: lx + CGFloat(i) * 8, y: H * 0.12 - CGFloat(i) * 44 * s, w: 160 * s, h: 38 * s, fontSize: 28 * s, plain: true, action: it.1)
            b.zRotation = 0.08
        }

        coinBadge()
        if store.d.bestScore > 0 {
            overlay.addChild(UIK.label("BEST \(UIK.coins(store.d.bestScore)) PTS  •  \(UIK.coins(store.d.bestDistance)) M",
                                       size: 14, color: UIK.cyan, x: W / 2 - 16, y: H / 2 - 22, align: .right))
        }

        // consumables to bring into the next run
        let owned: [(String, Int, Bool, () -> Void)] = [
            ("HEALTH PACK", store.d.healthPacks, runCfg.healthPack, { [weak self] in self?.runCfg.healthPack.toggle(); self?.showMenu() }),
            ("HEAD START", store.d.headStarts, runCfg.headStart, { [weak self] in self?.runCfg.headStart.toggle(); self?.showMenu() }),
            ("METER UP", store.d.meterUps, runCfg.meterUp, { [weak self] in self?.runCfg.meterUp.toggle(); self?.showMenu() })
        ].filter { $0.1 > 0 }
        for (i, it) in owned.enumerated() {
            let on = it.2
            addButton((on ? "✓ " : "") + "\(it.0) ×\(it.1)", x: W * 0.28, y: -H * 0.05 - CGFloat(i) * 40, w: 180, h: 32,
                      color: on ? UIK.green : Art.rgb(0.3, 0.22, 0.55), fontSize: 14, action: it.3)
        }
        if !owned.isEmpty {
            overlay.addChild(UIK.label("Take with you:", size: 14, color: .white, x: W * 0.28, y: -H * 0.05 + 30))
        }
    }

    // MARK: - Store (tabs like the original: UFO / POWER-UPS / ITEMS / ANIMALS)

    private struct Card {
        var title: String
        var icon: SKNode
        var desc: String
        var price: Int?
        var buttonText: String?
        var enabled: Bool
        var status: String?
        var action: (() -> Void)?
    }

    private func showStore(_ tab: StoreTab, page: Int = 0) {
        screen = .store
        storeTab = tab
        storePage = page
        newOverlay(dim: 0.3)
        let pw = min(W - 30, 720), ph = H - 40
        overlay.addChild(UIK.panel(pw, ph, y: -6))
        coinBadge()
        overlay.addChild(UIK.label("STORE", size: 22, color: UIK.cyan, y: H / 2 - 40))
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in self?.showMenu() }

        let tabs: [(String, StoreTab)] = [("UFO", .ufo), ("POWER-UPS", .powers), ("ITEMS", .items), ("ANIMALS", .animals)]
        let tw = (pw - 60) / 4
        for (i, t) in tabs.enumerated() {
            let x = -pw / 2 + 30 + tw * (CGFloat(i) + 0.5)
            let y = H / 2 - 72
            if t.1 == tab {
                let sel = SKShapeNode(rectOf: CGSize(width: tw - 8, height: 28), cornerRadius: 6)
                sel.fillColor = UIK.cardFill
                sel.strokeColor = UIK.panelEdge
                sel.lineWidth = 2
                sel.position = CGPoint(x: x, y: y)
                overlay.addChild(sel)
            }
            addButton(t.0, x: x, y: y, w: tw - 8, h: 28, fontSize: 18, plain: true) { [weak self] in self?.showStore(t.1) }
        }

        let cards = storeCards(tab)
        let perPage = 4
        let pages = max(1, Int(ceil(Double(cards.count) / Double(perPage))))
        let pg = min(page, pages - 1)
        let shown = Array(cards.dropFirst(pg * perPage).prefix(perPage))
        let cw = min(150, (pw - 80) / 4)
        let ch = min(ph - 140, 200)
        let cy: CGFloat = -16
        for (i, c) in shown.enumerated() {
            let x = (CGFloat(i) - CGFloat(shown.count - 1) / 2) * (cw + 10)
            let card = SKShapeNode(rectOf: CGSize(width: cw, height: ch), cornerRadius: 10)
            card.fillColor = UIK.cardFill
            card.strokeColor = UIColor(white: 1, alpha: 0.12)
            card.lineWidth = 2
            card.position = CGPoint(x: x, y: cy)
            overlay.addChild(card)
            overlay.addChild(UIK.label(c.title, size: 15, color: .white, x: x, y: cy + ch / 2 - 16))
            c.icon.position = CGPoint(x: x, y: cy + ch * 0.08)
            overlay.addChild(c.icon)
            let lines = wrap(c.desc, max: 20)
            for (k, s) in lines.prefix(3).enumerated() {
                overlay.addChild(UIK.label(s, size: 11, color: UIK.yellow, x: x, y: cy - ch * 0.16 - CGFloat(k) * 13, shadow: nil))
            }
            if let st = c.status {
                overlay.addChild(UIK.label(st, size: 14, color: UIK.cyan, x: x, y: cy - ch / 2 + 22))
            } else if let act = c.action {
                let txt = c.buttonText ?? UIK.coins(c.price ?? 0)
                addButton(txt, x: x, y: cy - ch / 2 + 22, w: cw - 24, h: 30, fontSize: 15,
                          enabled: c.enabled, coin: c.price != nil, action: act)
            }
        }
        if pages > 1 {
            overlay.addChild(UIK.label("\(pg + 1)/\(pages)", size: 13, color: .white, y: -H / 2 + 34))
            if pg > 0 {
                addButton("◀", x: -pw / 2 + 24, y: cy, w: 40, h: 50, fontSize: 28, plain: true) { [weak self] in self?.showStore(tab, page: pg - 1) }
            }
            if pg < pages - 1 {
                addButton("▶", x: pw / 2 - 24, y: cy, w: 40, h: 50, fontSize: 28, plain: true) { [weak self] in self?.showStore(tab, page: pg + 1) }
            }
        }
    }

    private func wrap(_ s: String, max: Int) -> [String] {
        var out: [String] = []
        var cur = ""
        for w in s.split(separator: " ") {
            if cur.count + w.count + 1 > max && !cur.isEmpty { out.append(cur); cur = "" }
            cur += (cur.isEmpty ? "" : " ") + w
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    private func buy(_ cost: Int, _ then: () -> Void) {
        guard store.d.coins >= cost else { return }
        store.d.coins -= cost
        then()
        store.save()
        sound.play("coin")
        hapticLight.impactOccurred()
    }

    private func storeCards(_ tab: StoreTab) -> [Card] {
        let coins = store.d.coins
        switch tab {
        case .ufo:
            return (0..<5).map { (i: Int) -> Card in
                let icon = Art.ufo(i)
                icon.setScale(0.9)
                let owned = store.d.ufoOwned[i]
                let tier = store.d.ufoTier[i]
                if !owned {
                    let cost = Tuning.ufoBuyCost[i]
                    return Card(title: Art.ufoNames[i].uppercased(), icon: icon, desc: "A new saucer and alien", price: cost, buttonText: nil,
                                enabled: coins >= cost, status: nil,
                                action: { [weak self] in
                                    guard let self = self else { return }
                                    self.buy(cost) { self.store.d.ufoOwned[i] = true; self.store.d.selectedUFO = i }
                                    self.setUFOArt()
                                    self.showStore(.ufo, page: self.storePage)
                                })
                }
                if store.d.selectedUFO == i {
                    return Card(title: Art.ufoNames[i].uppercased(), icon: icon, desc: "Health bars: \(Tuning.ufoHealth[tier])", price: nil, buttonText: nil,
                                enabled: true, status: "SELECTED", action: nil)
                }
                return Card(title: Art.ufoNames[i].uppercased(), icon: icon, desc: "Health bars: \(Tuning.ufoHealth[tier])", price: nil, buttonText: "SELECT",
                            enabled: true, status: nil,
                            action: { [weak self] in
                                guard let self = self else { return }
                                self.store.d.selectedUFO = i
                                self.store.save()
                                self.setUFOArt()
                                self.showStore(.ufo, page: self.storePage)
                            })
            }
        case .powers:
            var cards: [Card] = []
            let sel = store.d.selectedUFO
            let tier = store.d.ufoTier[sel]
            let upIcon = Art.ufo(sel)
            upIcon.setScale(0.75)
            let upDesc = ["Add an extra health bar", "Score multiplier +1", "Keep power-ups when hit", "Fully upgraded"][tier]
            if tier < 3 {
                let cost = Tuning.ufoTierCost[tier]
                cards.append(Card(title: "UPGRADE UFO", icon: upIcon, desc: upDesc, price: cost, buttonText: nil, enabled: coins >= cost, status: nil,
                                  action: { [weak self] in
                                      guard let self = self else { return }
                                      self.buy(cost) { self.store.d.ufoTier[sel] += 1 }
                                      self.showStore(.powers)
                                  }))
            } else {
                cards.append(Card(title: "UPGRADE UFO", icon: upIcon, desc: upDesc, price: nil, buttonText: nil, enabled: true, status: "MAX", action: nil))
            }
            for p in PowerType.allCases {
                let lvl = store.d.powerLevel[p.rawValue]
                let icon = Art.capsule(p)
                icon.setScale(1.8)
                let desc = lvl == 0 ? "Unlock this power-up" : "\(p.blurb). Lasts \(Int(p.durations[lvl - 1]))s (Lv \(lvl))"
                if lvl < 3 {
                    let cost = Tuning.powerCost[lvl]
                    cards.append(Card(title: p.title.uppercased(), icon: icon, desc: desc, price: cost, buttonText: nil, enabled: coins >= cost, status: nil,
                                      action: { [weak self] in
                                          guard let self = self else { return }
                                          self.buy(cost) { self.store.d.powerLevel[p.rawValue] += 1 }
                                          self.showStore(.powers)
                                      }))
                } else {
                    cards.append(Card(title: p.title.uppercased(), icon: icon, desc: desc, price: nil, buttonText: nil, enabled: true, status: "MAX", action: nil))
                }
            }
            return cards
        case .items:
            let defs: [(String, String, Int, Int, Int, String)] = [
                ("HEALTH PACK", "A second chance when you crash", Tuning.healthPackCost, store.d.healthPacks, 0, "+"),
                ("HEAD START", "Blast \(Int(Tuning.boostDistance)) M ahead at the start", Tuning.headStartCost, store.d.headStarts, 1, "»"),
                ("METER UP", "Start the run at 3X", Tuning.meterUpCost, store.d.meterUps, 2, "3X")
            ]
            return defs.map { (d) -> Card in
                let icon = SKNode()
                icon.addChild(Art.circ(24, UIK.orange, stroke: .white))
                icon.addChild(UIK.label(d.5, size: 22, color: .white))
                let which = d.4
                return Card(title: d.0, icon: icon, desc: "\(d.1). You own \(d.3)", price: d.2, buttonText: nil, enabled: coins >= d.2, status: nil,
                            action: { [weak self] in
                                guard let self = self else { return }
                                self.buy(d.2) {
                                    switch which {
                                    case 0: self.store.d.healthPacks += 1
                                    case 1: self.store.d.headStarts += 1
                                    default: self.store.d.meterUps += 1
                                    }
                                }
                                self.showStore(.items)
                            })
            }
        case .animals:
            return Unlockable.all.map { (u: Unlockable) -> Card in
                let icon = Art.creature(u.kind, variant: u.variant)
                icon.setScale(u.kind == .cow ? 1.4 : 1.9)
                let unlocked = store.isUnlocked(u.id)
                if !unlocked { icon.alpha = 0.35 }
                let desc = "\(u.points) points. " + (u.cost == 0 ? "Available at start" : (unlocked ? "Unlocked" : "Shows up once unlocked"))
                if unlocked {
                    return Card(title: u.name.uppercased(), icon: icon, desc: desc, price: nil, buttonText: nil, enabled: true, status: "✓", action: nil)
                }
                return Card(title: "?", icon: icon, desc: desc, price: u.cost, buttonText: nil, enabled: coins >= u.cost, status: nil,
                            action: { [weak self] in
                                guard let self = self else { return }
                                self.buy(u.cost) { self.store.d.unlocked?.append(u.id) }
                                self.showStore(.animals, page: self.storePage)
                            })
            }
        }
    }

    // MARK: - Settings / stats

    private func showSettings() {
        screen = .settings
        newOverlay(dim: 0.3)
        overlay.addChild(UIK.panel(min(W - 40, 560), H - 40, y: -6))
        overlay.addChild(UIK.label("OPTIONS", size: 26, color: UIK.cyan, y: H / 2 - 44))
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in self?.showMenu() }

        let sense = store.d.touchSense
        overlay.addChild(UIK.label("Beam sensitivity  \(String(format: "%.1f", sense))", size: 18, y: H * 0.22))
        addButton("−", x: -60, y: H * 0.11, w: 54, h: 38, fontSize: 24, enabled: sense > 0.51) { [weak self] in
            guard let self = self else { return }
            self.store.d.touchSense = max(0.5, ((sense - 0.1) * 10).rounded() / 10)
            self.store.save()
            self.showSettings()
        }
        addButton("+", x: 60, y: H * 0.11, w: 54, h: 38, fontSize: 24, enabled: sense < 1.99) { [weak self] in
            guard let self = self else { return }
            self.store.d.touchSense = min(2.0, ((sense + 0.1) * 10).rounded() / 10)
            self.store.save()
            self.showSettings()
        }
        addButton("MUSIC: \(sound.musicOn ? "ON" : "OFF")", x: -90, y: -H * 0.02, w: 160, h: 36, color: sound.musicOn ? UIK.green : UIColor(white: 0.4, alpha: 1), fontSize: 16) { [weak self] in
            guard let self = self else { return }
            self.sound.musicOn.toggle()
            self.showSettings()
        }
        addButton("SOUNDS: \(sound.sfxOn ? "ON" : "OFF")", x: 90, y: -H * 0.02, w: 160, h: 36, color: sound.sfxOn ? UIK.green : UIColor(white: 0.4, alpha: 1), fontSize: 16) { [weak self] in
            guard let self = self else { return }
            self.sound.sfxOn.toggle()
            self.showSettings()
        }

        let d = store.d
        let lines = [
            "Runs \(d.runs)   •   Abducted \(UIK.coins(d.totalAbducted))",
            "Vehicles smashed \(d.vehiclesDestroyed)   •   Tanks \(d.tanksDestroyed)",
            "Power-ups \(d.powerupsCollected)   •   Crashes by vehicle \(d.deathsByVehicle)"
        ]
        for (i, s) in lines.enumerated() {
            overlay.addChild(UIK.label(s, size: 14, color: UIColor(white: 1, alpha: 0.9), y: -H * 0.15 - CGFloat(i) * 20, shadow: nil))
        }
    }

    // MARK: - Game flow

    private func clearEntities() {
        for n in creatures { n.removeFromParent() }
        for n in obstacles { n.removeFromParent() }
        for n in coins { n.removeFromParent() }
        for n in pickups { n.removeFromParent() }
        for n in decals { n.removeFromParent() }
        for n in missiles { n.removeFromParent() }
        liftLayer.removeAllChildren()
        creatures = []; obstacles = []; coins = []; pickups = []; decals = []; missiles = []; flocks = []
    }

    private func resetWorld() {
        clearEntities()
        camX = 0
        ufo.removeAllActions()
        ufoArt.zRotation = 0
        ufoArt.alpha = 1
        ufoPos = CGPoint(x: W * 0.3, y: H * 0.84)
        ufo.position = ufoPos
        target = CGPoint(x: W * 0.45, y: sy(1.9))
        beamPt = target
        ufoDepth = 1.9
        touching = false
        moveSpeed = Tuning.startSpeed
        curSpeed = 8
        status = .intro

        let ahead = spawnEdge
        nextGroupX = camX - 200
        nextStaticX = ahead + 300
        nextCoinX = camX + 200
        nextPickupX = ahead + 1500
        nextTuftX = camX - (W * 0.5) * dMax / P
        nextSign = Tuning.signEvery
        pendingSigns = []
        spawnWorld(menu: true)
    }

    private func startGame() {
        newOverlay()
        resetWorld()
        clearEntities()
        screen = .playing
        hud.isHidden = false
        sound.playMusic("music")

        elapsed = 0
        score = 0
        runCoins = 0
        abducted = 0
        streakSpeed = 0
        distance = 0
        level = 0
        collectedStreak = 0
        sinceCollect = 0
        invincible = 0
        damageTimer = 0
        power = nil
        powerTimer = 0
        inVehicleState = false
        stateTimer = Tuning.groundDuration
        vehicleDuration = Tuning.vehicleDuration
        vehicleDifficulty = 0
        nextVehicleIn = 1
        nextTankIn = CGFloat.random(in: 15...20)
        maxHealth = store.maxHealth
        health = maxHealth
        rebuildHealthBars()
        tutorial = store.d.runs < 2

        secondChance = false
        if runCfg.healthPack && store.d.healthPacks > 0 { store.d.healthPacks -= 1; secondChance = true }
        if runCfg.meterUp && store.d.meterUps > 0 {
            store.d.meterUps -= 1
            level = 2
            collectedStreak = Tuning.streakCounts[2]
            streakSpeed = Tuning.streakSpeed[2]
        }
        var boosting = false
        if runCfg.headStart && store.d.headStarts > 0 { store.d.headStarts -= 1; boosting = true }
        runCfg = RunConfig()
        store.save()

        // tutorial / high-score billboards like the original
        let ahead = spawnEdge
        if store.d.bestScore > 0 {
            addSign(["HIGH SCORE", "\(UIK.coins(store.d.bestScore)) PTS", "\(UIK.coins(store.d.bestDistance)) M"], x: camX + 260, d: 2.9)
        }
        if tutorial {
            pendingSigns = [(ahead + 200, ["COLLECT HUMANS", "AND ANIMALS"]), (ahead + 1200, ["AVOID", "OBSTACLES"])]
        }
        nextGroupX = camX + 120
        nextCoinX = camX + 320
        nextStaticX = ahead + (tutorial ? 1400 : 300)
        nextTuftX = camX - (W * 0.5) * dMax / P
        spawnWorld(menu: false)

        // intro: saucer swoops in from the top-left
        status = .intro
        beamOn = false
        ufoPos = CGPoint(x: -80 * ws, y: H + 60)
        ufo.position = ufoPos
        sound.play("ufo_in")
        ufo.run(.wait(forDuration: 0.9)) { [weak self] in
            guard let self = self, self.screen == .playing || self.screen == .paused else { return }
            self.beamOn = true
            if boosting {
                self.status = .boost
                self.beamOn = false
                self.boostUntil = CGFloat(self.distance) + Tuning.boostDistance
                self.banner("HEAD START!")
            } else {
                self.status = .play
                if self.tutorial { self.banner("Drag anywhere to move the beam") }
            }
        }
        updateHUD()
    }

    private func pauseGame() {
        guard screen == .playing else { return }
        screen = .paused
        touching = false
        newOverlay(dim: 0.4)
        overlay.addChild(UIK.panel(min(W - 80, 420), H * 0.7))
        overlay.addChild(UIK.label("PAUSED", size: 30, color: UIK.cyan, y: H * 0.22))
        addButton("RESUME", x: 0, y: H * 0.07, w: 200, h: 44, fontSize: 30, plain: true) { [weak self] in
            guard let self = self else { return }
            self.newOverlay()
            self.screen = .playing
            self.lastTime = 0
        }
        addButton("MAIN MENU", x: 0, y: -H * 0.07, w: 220, h: 44, fontSize: 30, plain: true) { [weak self] in
            self?.finishRun(quit: true)
        }
        addButton("MUSIC \(sound.musicOn ? "ON" : "OFF")", x: -80, y: -H * 0.22, w: 140, h: 32, color: UIK.green, fontSize: 14) { [weak self] in
            guard let self = self else { return }
            self.sound.musicOn.toggle()
            self.screen = .playing
            self.pauseGame()
        }
        addButton("SOUNDS \(sound.sfxOn ? "ON" : "OFF")", x: 80, y: -H * 0.22, w: 140, h: 32, color: UIK.green, fontSize: 14) { [weak self] in
            guard let self = self else { return }
            self.sound.sfxOn.toggle()
            self.screen = .playing
            self.pauseGame()
        }
    }

    private func finishRun(quit: Bool = false) {
        store.d.coins += runCoins
        store.d.runs += 1
        store.d.totalAbducted += abducted
        let newBest = score > store.d.bestScore
        if newBest { store.d.bestScore = score }
        if distance > store.d.bestDistance { store.d.bestDistance = distance }
        store.save()
        if quit { showMenu(); return }

        screen = .over
        overTimer = 0
        hud.isHidden = true
        newOverlay(dim: 0.25)
        coinBadge()
        let pw = min(W - 80, 460), ph = H * 0.82
        overlay.addChild(UIK.panel(pw, ph))
        if newBest {
            overlay.addChild(UIK.label("New High Score! You're climbing the ranks.", size: 15, color: Art.rgb(0.7, 0.75, 1), y: ph / 2 - 30, shadow: nil))
        }
        overlay.addChild(UIK.label("Coins: \(runCoins)", size: 18, y: ph / 2 - 62, shadow: nil))
        overlay.addChild(UIK.label("Distance: \(UIK.coins(distance))", size: 18, y: ph / 2 - 84, shadow: nil))
        overlay.addChild(UIK.label("Score: \(UIK.coins(score))", size: 18, y: ph / 2 - 106, shadow: nil))
        addButton("PLAY AGAIN", x: 0, y: -ph * 0.06, w: 220, h: 40, fontSize: 30, plain: true) { [weak self] in self?.startGame() }
        addButton("STORE", x: 0, y: -ph * 0.06 - 44, w: 160, h: 40, fontSize: 30, plain: true) { [weak self] in self?.showStore(.powers) }
        addButton("MAIN MENU", x: 0, y: -ph * 0.06 - 88, w: 220, h: 40, fontSize: 30, plain: true) { [weak self] in self?.showMenu() }
    }

    // MARK: - Input (relative drag moves the beam in 2D, like the original)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        if screen == .playing, let pb = pauseButton, pb.hit(t) {
            pb.press(); pb.onTap(); return
        }
        for b in buttons.reversed() where b.hit(t) {
            if b.enabled { b.press(); b.onTap() }
            return
        }
        if screen == .playing {
            touching = true
            lastTouch = t.location(in: self)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard screen == .playing, touching, let t = touches.first else { return }
        let p = t.location(in: self)
        let sense = CGFloat(store.d.touchSense) * 1.25
        target.x += (p.x - lastTouch.x) * sense
        target.y += (p.y - lastTouch.y) * sense
        lastTouch = p
        clampTarget()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false }

    private func clampTarget() {
        target.x = max(W * 0.04, min(W * 0.96, target.x))
        target.y = max(sy(dMin + 0.02), min(sy(dMax - 0.05), target.y))
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let dt = CGFloat(min(currentTime - lastTime, 1.0 / 20.0))
        lastTime = currentTime
        guard W > 0 else { return }
        clock += dt

        switch screen {
        case .menu, .store, .settings:
            attractStep(dt)
        case .playing:
            step(dt)
        case .paused:
            break
        case .over:
            overTimer += dt
            attractStep(dt * 0.4)
        }
    }

    /// Menu background: the saucer cruises and beams things up on its own.
    private func attractStep(_ dt: CGFloat) {
        curSpeed += (8 - curSpeed) * min(1, dt)
        let dx = curSpeed * Tuning.unit * dt
        camX += dx
        scrollBackground(dx)
        let candidates = creatures.filter { !$0.lifting && sx($0.gx, $0.gd) > W * 0.3 && sx($0.gx, $0.gd) < W * 0.9 }
        if let c = candidates.min(by: { sx($0.gx, $0.gd) < sx($1.gx, $1.gd) }) {
            target.x += (sx(c.gx, c.gd) - target.x) * min(1, dt * 2)
            target.y += (sy(c.gd) - target.y) * min(1, dt * 2)
        } else {
            target.x += (W * 0.6 - target.x) * min(1, dt)
        }
        clampTarget()
        beamOn = true
        status = .intro
        moveUFO(dt, menu: true)
        spawnWorld(menu: true)
        updateWorld(dt, playing: false)
        drawBeam()
    }

    private var beamRadiusWorld: CGFloat {
        return power == .rampage ? Tuning.beamRadius * Tuning.rampageRadiusFactor : Tuning.beamRadius
    }

    private var multiplier: Int {
        return Tuning.streakMult[level] + (store.upgradedMultiplier ? 1 : 0)
    }

    private func step(_ dt: CGFloat) {
        elapsed += dt
        switch status {
        case .intro:
            curSpeed = moveSpeed
        case .play:
            moveSpeed = min(Tuning.maxSpeed, moveSpeed + Tuning.speedGain * dt)
            curSpeed = moveSpeed + streakSpeed
        case .boost:
            curSpeed += (Tuning.boostSpeed - curSpeed) * min(1, dt * 3)
            if CGFloat(distance) >= boostUntil {
                status = .play
                beamOn = true
                invincible = Tuning.boostInvuln
                banner("GO!")
            }
        case .dead:
            curSpeed *= max(0, 1 - dt * 2)
        }

        let dx = curSpeed * Tuning.unit * dt
        camX += dx
        scrollBackground(dx)
        if status != .dead {
            distance = max(distance, Int(camX / Tuning.unit))
        }

        if status == .dead {
            stepDeath(dt)
        } else {
            moveUFO(dt, menu: false)
        }

        manageStates(dt)
        spawnWorld(menu: false)
        updateWorld(dt, playing: true)
        drawBeam()
        checkBeamCollisions(dt)
        updateMissiles(dt)

        if invincible > 0 { invincible -= dt }
        if damageTimer > 0 {
            damageTimer -= dt
            ufoArt.alpha = (Int(clock * 16) % 2 == 0) ? 0.45 : 1
            if damageTimer <= 0 { ufoArt.alpha = 1 }
        } else if invincible > 0 {
            ufoArt.alpha = 0.65 + 0.35 * sin(clock * 20)
        } else {
            ufoArt.alpha = 1
        }
        if powerTimer > 0 {
            powerTimer -= dt
            if powerTimer <= 0 { power = nil; powerTimer = 0 }
        }
        if level > 0 && status == .play {
            sinceCollect += dt
            if sinceCollect > Tuning.streakWindow {
                sinceCollect = 0
                dropLevel()
            }
        }
        if status == .dead { overTimer += dt }
        updateHUD()
    }

    /// AlignToBeam: the saucer trails the beam point with a soft delay and tilts toward it.
    private func moveUFO(_ dt: CGFloat, menu: Bool) {
        beamPt.x += (target.x - beamPt.x) * min(1, dt * 18)
        beamPt.y += (target.y - beamPt.y) * min(1, dt * 18)
        let tD = depth(atY: beamPt.y)
        ufoDepth += (tD - ufoDepth) * min(1, dt * 2.2)

        let far = (tD - dMin) / (dMax - dMin)
        let wantX = max(W * 0.12, min(W * 0.8, beamPt.x - W * 0.07))
        let wantY = H * (0.8 + 0.06 * (1 - far))
        let oldX = ufoPos.x
        let k = min(1, dt * (status == .intro && !menu ? 2.2 : 3.2))
        ufoPos.x += (wantX - ufoPos.x) * k
        ufoPos.y += (wantY - ufoPos.y) * k
        ufoVel = (ufoPos.x - oldX) / max(dt, 0.001)
        ufo.position = CGPoint(x: ufoPos.x, y: ufoPos.y + sin(clock * 2.6) * 4 * ws)
        let lean = max(-0.32, min(0.32, -ufoVel / (W * 2.2) - (beamPt.x - ufoPos.x) / W * 0.35))
        ufoArt.zRotation += (lean - ufoArt.zRotation) * min(1, dt * 6)
    }

    private var ufoBottom: CGPoint {
        return CGPoint(x: ufo.position.x + sin(-ufoArt.zRotation) * 12 * ws, y: ufo.position.y - 16 * ws)
    }

    private var beamVisible: Bool {
        if screen == .playing || screen == .paused { return beamOn && status == .play }
        return beamOn
    }

    private func drawBeam() {
        if !beamVisible {
            beamGlow.path = nil
            beamCore.path = nil
            beamRing.path = nil
            crosshair.isHidden = true
            for s in sparkles { s.0.isHidden = true }
            return
        }
        crosshair.isHidden = false
        let T = beamPt
        let U = ufoBottom
        let tD = depth(atY: T.y)
        let r = beamRadiusWorld * sc(tD)
        func quad(_ topW: CGFloat, _ botW: CGFloat) -> CGPath {
            let dx = T.x - U.x, dy = T.y - U.y
            let len = max(1, hypot(dx, dy))
            let nx = -dy / len, ny = dx / len
            let p = CGMutablePath()
            p.move(to: CGPoint(x: U.x + nx * topW, y: U.y + ny * topW))
            p.addLine(to: CGPoint(x: T.x + nx * botW, y: T.y + ny * botW))
            p.addLine(to: CGPoint(x: T.x - nx * botW, y: T.y - ny * botW))
            p.addLine(to: CGPoint(x: U.x - nx * topW, y: U.y - ny * topW))
            p.closeSubpath()
            return p
        }
        let base: UIColor
        if damageTimer > 0 {
            base = Art.rgb(1, 0.25, 0.25)
        } else if power == .rampage {
            base = Art.rgb(1, 0.55, 0.15)
        } else if power == .magnet {
            base = Art.rgb(0.75, 0.45, 1)
        } else {
            base = Art.rgb(0.3, 0.85, 1)
        }
        let pulse = 0.04 * sin(clock * 12)
        beamGlow.path = quad(13 * ws, r * 1.05)
        beamGlow.fillColor = base.withAlphaComponent(0.22 + pulse)
        beamCore.path = quad(6 * ws, r * 0.5)
        beamCore.fillColor = base.withAlphaComponent(0.5 + pulse)
        beamRing.path = CGPath(ellipseIn: CGRect(x: T.x - r, y: T.y - r * 0.45, width: r * 2, height: r * 0.9), transform: nil)
        beamRing.fillColor = base.withAlphaComponent(0.35)
        beamRing.strokeColor = UIColor.white.withAlphaComponent(0.7)
        crosshair.position = T
        crosshair.xScale = max(0.6, r / 13)
        crosshair.yScale = crosshair.xScale * 0.5
        crosshair.zRotation = 0

        for i in 0..<sparkles.count {
            var s = sparkles[i]
            s.1 += 0.012 + CGFloat(i % 4) * 0.003
            if s.1 > 1 { s.1 = 0; s.2 = CGFloat.random(in: -1...1) }
            let t = s.1
            let w = r * 0.8 * (1 - t) + 6 * ws * t
            s.0.isHidden = false
            s.0.position = CGPoint(x: T.x + (U.x - T.x) * t + s.2 * w, y: T.y + (U.y - T.y) * t)
            s.0.alpha = sin(t * .pi) * 0.9
            s.0.color = base
            s.0.colorBlendFactor = 0.4
            sparkles[i] = s
        }
    }

    // MARK: - Difficulty (GroundManager state cycle)

    private func manageStates(_ dt: CGFloat) {
        guard status == .play, !tutorialActive else { return }
        stateTimer -= dt
        if stateTimer <= 0 {
            if inVehicleState {
                inVehicleState = false
                vehicleDifficulty = min(Tuning.maxVehicleDifficulty, vehicleDifficulty + 1)
                vehicleDuration += Tuning.vehicleDurationGrowth
                stateTimer = Tuning.groundDuration
            } else {
                inVehicleState = true
                stateTimer = vehicleDuration
                nextVehicleIn = 0.3
            }
        }
        if inVehicleState {
            nextVehicleIn -= dt
            let count = obstacles.filter { $0.kind.isVehicle }.count
            if nextVehicleIn <= 0 && count < Tuning.maxVehicles {
                spawnVehicle()
                let lo = max(0.5, 1 - 0.1 * CGFloat(vehicleDifficulty))
                let hi = max(lo + 0.4, 3 - 0.3 * CGFloat(vehicleDifficulty))
                nextVehicleIn = CGFloat.random(in: lo...hi)
            }
        }
        if distance >= Tuning.tankFrom {
            nextTankIn -= dt
            if nextTankIn <= 0 {
                let x = camX + (W * 0.5 + 60) * 2.6 / P
                let o = spawnObstacle(.tank, x: x, d: roadD(x))
                o.vx = -25
                o.lane = 0
                nextTankIn = CGFloat.random(in: 15...20)
            }
        }
    }

    private var tutorialActive: Bool { return tutorial && elapsed < 14 }

    private func spawnVehicle() {
        var pool: [ObKind] = [.car, .car, .car, .truck]
        if distance >= Tuning.fireTruckFrom { pool.append(.fireTruck) }
        if distance >= Tuning.policeFrom { pool += [.police, .police] }
        if distance >= Tuning.jeepFrom { pool += [.jeep, .jeep] }
        let k = pool.randomElement() ?? .car
        let lane: CGFloat = Bool.random() ? 0.05 : -0.05
        let fromRight = Bool.random() || k == .police
        let rd0 = roadD(camX)
        let x = fromRight ? camX + (W * 0.5 + 80) * (rd0 + 0.5) / P : camX - (W * 0.5 + 80) * (rd0 + 0.5) / P
        let o = spawnObstacle(k, x: x, d: roadD(x) + lane)
        o.lane = lane
        let sp = CGFloat.random(in: 50...90) * (1 + CGFloat(vehicleDifficulty) * 0.08)
        // cars from the left must outrun the scrolling field to be seen
        o.vx = fromRight ? -sp : curSpeed * Tuning.unit + sp
        if k == .fireTruck && store.isUnlocked("fireman") {
            for i in 0..<2 {
                spawnCreature(.fireman, variant: 0, x: x + CGFloat(i + 1) * 30, d: max(dMin + 0.05, roadD(x) - 0.25))
            }
        }
        if k == .jeep && store.isUnlocked("soldier") {
            spawnCreature(.soldier, variant: 0, x: x + 40, d: max(dMin + 0.05, roadD(x) - 0.25))
        }
    }

    // MARK: - Spawning (ground space)

    private var spawnEdge: CGFloat { return camX + (W * 0.5 + 60) * dMax / P }

    private func spawnWorld(menu: Bool) {
        let limit = spawnEdge

        // grass tufts and darker ground blotches for a sense of motion
        while nextTuftX < limit {
            let dec = Decal()
            dec.gx = nextTuftX + CGFloat.random(in: 0...30)
            dec.gd = CGFloat.random(in: dMin...(dMax + 0.15))
            if Int.random(in: 0..<5) == 0 {
                let e = Art.ell(100, 100, Art.rgb(0.02, 0.18, 0.2, 0.35))
                dec.addChild(e)
                dec.flat = true
                dec.worldW = CGFloat.random(in: 40...110)
                dec.worldD = CGFloat.random(in: 0.04...0.1)
            } else {
                dec.addChild(Art.tuft())
            }
            world.addChild(dec)
            decals.append(dec)
            nextTuftX += CGFloat.random(in: 18...40)
        }

        while nextGroupX < limit {
            spawnGroup(at: nextGroupX)
            let busy = min(1, CGFloat(distance) / 3000)
            nextGroupX += CGFloat.random(in: 160...300) * (1 - busy * 0.25)
        }

        if !menu {
            while nextStaticX < limit {
                spawnStaticCluster(at: nextStaticX)
                let busy = min(1, CGFloat(distance) / 4000)
                nextStaticX += CGFloat.random(in: 380...700) * (1 - busy * 0.4)
            }
            while nextCoinX < limit {
                spawnCoinPattern(at: nextCoinX)
                nextCoinX += CGFloat.random(in: 420...800)
            }
            let unlocked = PowerType.allCases.filter { store.d.powerLevel[$0.rawValue] > 0 }
            while nextPickupX < limit {
                if let t = unlocked.randomElement() {
                    let p = Pickup(type: t)
                    p.addChild(Art.capsule(t))
                    p.gx = nextPickupX
                    p.gd = CGFloat.random(in: (dMin + 0.2)...(dMax - 0.3))
                    world.addChild(p)
                    pickups.append(p)
                }
                nextPickupX += CGFloat.random(in: 1600...2600)
            }
            // distance billboards
            let signX = CGFloat(nextSign) * Tuning.unit
            if signX < limit {
                addSign(["\(nextSign)M"], x: signX, d: 3.05)
                nextSign += Tuning.signEvery
            }
            var keep: [(CGFloat, [String])] = []
            for s in pendingSigns {
                if s.0 < limit { addSign(s.1, x: s.0, d: 2.95, wide: true) } else { keep.append(s) }
            }
            pendingSigns = keep
        }
    }

    private func addSign(_ lines: [String], x: CGFloat, d: CGFloat, wide: Bool = false) {
        let dec = Decal()
        dec.addChild(Art.sign(lines, wide: wide || lines.count > 1))
        dec.gx = x
        dec.gd = d
        world.addChild(dec)
        decals.append(dec)
    }

    private func pick(_ k: Kind) -> Int? {
        let v = store.unlockedVariants(k)
        guard !v.isEmpty else { return nil }
        // rarer variants appear less often
        if v.count > 1 && Int.random(in: 0..<100) < 30 {
            return v.filter { $0 != 0 }.randomElement() ?? v[0]
        }
        return v.contains(0) ? 0 : v[0]
    }

    private func spawnGroup(at x: CGFloat) {
        let roll = Int.random(in: 0..<100)
        let d = CGFloat.random(in: (dMin + 0.1)...(dMax - 0.2))
        if roll < 38 {
            // a flock of sheep (Boids) — sometimes with a herding dog
            let flock = Flock(x: x, d: d)
            flocks.append(flock)
            let n = Int.random(in: 3...7)
            for _ in 0..<n {
                guard let v = pick(.sheep) else { break }
                let c = spawnCreature(.sheep, variant: v, x: x, d: d)
                c.flock = flock
                c.offX = CGFloat.random(in: -45...45)
                c.offD = CGFloat.random(in: -0.12...0.12)
                c.gx = x + c.offX
                c.gd = max(dMin + 0.02, min(dMax - 0.05, d + c.offD))
            }
            if Int.random(in: 0..<100) < 35 {
                let dog = spawnCreature(.dog, variant: 0, x: x - 70, d: d)
                dog.flock = flock
                dog.offX = -70
            }
        } else if roll < 55 {
            for i in 0..<Int.random(in: 1...2) {
                if let v = pick(.cow) { spawnCreature(.cow, variant: v, x: x + CGFloat(i) * 60, d: d + CGFloat(i) * 0.15) }
            }
        } else if roll < 68 {
            // pigs wallowing in a mud patch
            let mud = Decal()
            mud.addChild(Art.ell(100, 100, Art.rgb(0.22, 0.2, 0.15, 0.85)))
            mud.flat = true
            mud.worldW = 70
            mud.worldD = 0.12
            mud.gx = x
            mud.gd = d
            world.addChild(mud)
            decals.append(mud)
            for _ in 0..<Int.random(in: 2...4) {
                if let v = pick(.pig) {
                    let c = spawnCreature(.pig, variant: v, x: x + CGFloat.random(in: -40...40), d: d + CGFloat.random(in: -0.08...0.08))
                    c.walkSpeed *= 0.4
                }
            }
        } else if roll < 86 {
            spawnCreature(.grumpa, variant: 0, x: x, d: d)
            if Bool.random() { spawnCreature(.farmer, variant: 0, x: x + 50, d: d + 0.2) }
        } else if roll < 93 {
            if store.isUnlocked("reporter") { spawnCreature(.reporter, variant: 0, x: x, d: d) } else { spawnCreature(.farmer, variant: 0, x: x, d: d) }
        } else {
            if distance > Tuning.jeepFrom && store.isUnlocked("soldier") {
                for i in 0..<Int.random(in: 2...3) { spawnCreature(.soldier, variant: 0, x: x + CGFloat(i) * 30, d: d) }
            } else {
                spawnCreature(.grumpa, variant: 0, x: x, d: d)
            }
        }
    }

    private func spawnStaticCluster(at x: CGFloat) {
        if tutorialActive { return }
        var pool: [ObKind] = [.fence, .fence, .fence, .barrels, .shed]
        if distance > 200 { pool += [.silo, .house, .windmill] }
        if distance > 700 { pool += [.barn, .silo, .shed] }
        if distance > 1500 { pool += [.barn, .house] }
        let k = pool.randomElement() ?? .fence
        var d = CGFloat.random(in: (dMin + 0.1)...(dMax - 0.05))
        // keep buildings off the road
        if abs(d - roadD(x)) < 0.22 { d = roadD(x) + (d < roadD(x) ? -0.3 : 0.3) }
        d = max(dMin + 0.08, min(dMax, d))
        if k == .shed && Bool.random() {
            for i in 0..<3 { spawnObstacle(.shed, x: x + CGFloat(i) * 46, d: d) }
        } else if k == .fence {
            for i in 0..<Int.random(in: 1...3) { spawnObstacle(.fence, x: x + CGFloat(i) * 86, d: d) }
        } else {
            spawnObstacle(k, x: x, d: d)
        }
    }

    private func spawnCoinPattern(at x: CGFloat) {
        let d0 = CGFloat.random(in: (dMin + 0.1)...(dMax - 0.35))
        let pattern = Int.random(in: 0..<4)
        var pts: [(CGFloat, CGFloat)] = []
        switch pattern {
        case 0: // straight line
            for i in 0..<Int.random(in: 6...10) { pts.append((x + CGFloat(i) * 26, d0)) }
        case 1: // rectangle outline
            let w = 5, h = 3
            for i in 0..<w { pts.append((x + CGFloat(i) * 28, d0)); pts.append((x + CGFloat(i) * 28, d0 + 0.3)) }
            for j in 1..<h { pts.append((x, d0 + CGFloat(j) * 0.1)); pts.append((x + CGFloat(w - 1) * 28, d0 + CGFloat(j) * 0.1)) }
        case 2: // diagonal line into the field
            for i in 0..<8 { pts.append((x + CGFloat(i) * 24, d0 + CGFloat(i) * 0.05)) }
        default: // wave
            for i in 0..<10 { pts.append((x + CGFloat(i) * 24, d0 + 0.12 + sin(CGFloat(i) * 0.7) * 0.12)) }
        }
        for (cx, cd) in pts {
            let c = Coin()
            c.addChild(Art.coin())
            c.gx = cx
            c.gd = max(dMin + 0.02, min(dMax, cd))
            world.addChild(c)
            coins.append(c)
        }
    }

    @discardableResult
    private func spawnCreature(_ kind: Kind, variant: Int, x: CGFloat, d: CGFloat) -> Creature {
        let c = Creature(kind: kind, variant: variant, body: Art.creature(kind, variant: variant))
        c.gx = x
        c.gd = max(dMin + 0.02, min(dMax - 0.05, d))
        c.vx = Bool.random() ? c.walkSpeed : -c.walkSpeed
        world.addChild(c)
        creatures.append(c)
        return c
    }

    @discardableResult
    private func spawnObstacle(_ kind: ObKind, x: CGFloat, d: CGFloat) -> Obstacle {
        let o = Obstacle(kind: kind)
        o.addChild(Art.obstacle(kind))
        o.gx = x
        o.gd = d
        world.addChild(o)
        obstacles.append(o)
        return o
    }

    // MARK: - World update (AI + projection)

    private func project(_ n: GroundThing) {
        n.position = CGPoint(x: sx(n.gx, n.gd), y: sy(n.gd))
        n.setScale(sc(n.gd))
        n.zPosition = 400 - n.gd * 100
    }

    private func updateWorld(_ dt: CGFloat, playing: Bool) {
        // winding dirt road
        let left = camX - (W * 0.5 + 40) * dMax / P
        let right = spawnEdge
        var upper: [CGPoint] = [], lower: [CGPoint] = []
        var x = left
        while x <= right {
            let rd = roadD(x)
            let hw: CGFloat = 0.11
            upper.append(CGPoint(x: sx(x, rd + hw), y: sy(rd + hw)))
            lower.append(CGPoint(x: sx(x, rd - hw), y: sy(rd - hw)))
            x += 30
        }
        let p = CGMutablePath()
        if let f = upper.first {
            p.move(to: f)
            for q in upper.dropFirst() { p.addLine(to: q) }
            for q in lower.reversed() { p.addLine(to: q) }
            p.closeSubpath()
        }
        road.path = p
        let e = CGMutablePath()
        if let f = upper.first { e.move(to: f); for q in upper.dropFirst() { e.addLine(to: q) } }
        if let f = lower.first { e.move(to: f); for q in lower.dropFirst() { e.addLine(to: q) } }
        roadEdge.path = e

        for dcl in decals {
            if dcl.flat {
                let w = dcl.worldW * sc(dcl.gd)
                let h = max(1, sy(dcl.gd + dcl.worldD) - sy(dcl.gd - dcl.worldD))
                dcl.position = CGPoint(x: sx(dcl.gx, dcl.gd), y: sy(dcl.gd))
                dcl.xScale = w / 100
                dcl.yScale = h / 100
                dcl.zPosition = 1
            } else {
                project(dcl)
            }
        }

        updateCreatures(dt)
        updateObstacles(dt, playing: playing)
        updateCoins(dt)
        updatePickups(dt)
        updateLifting(dt)
        cleanup()
    }

    private func groundDist(_ x: CGFloat, _ d: CGFloat, toScreen T: CGPoint) -> CGFloat {
        // ellipse test in screen space around the beam point
        let r = beamRadiusWorld * sc(depth(atY: T.y))
        let dx = (sx(x, d) - T.x) / r
        let dy = (sy(d) - T.y) / (r * 0.5)
        return hypot(dx, dy)
    }

    private var beamActive: Bool {
        if screen == .playing { return beamOn && status == .play }
        return beamOn
    }

    private func updateCreatures(_ dt: CGFloat) {
        let T = beamPt
        let tD = depth(atY: T.y)
        let tX = worldX(atX: T.x, d: tD)
        var flockMoved = Set<ObjectIdentifier>()

        for c in creatures where !c.lifting {
            var moving = true
            if let f = c.flock {
                if !flockMoved.contains(ObjectIdentifier(f)) {
                    flockMoved.insert(ObjectIdentifier(f))
                    f.x += f.vx * dt
                    f.d += f.vd * dt
                    if f.d < dMin + 0.15 || f.d > dMax - 0.2 { f.vd = -f.vd }
                    if Int.random(in: 0..<200) == 0 { f.vx = CGFloat.random(in: -14...14) }
                }
                let wantX = f.x + c.offX + sin(clock * 1.3 + c.wob) * 6
                let wantD = f.d + c.offD
                let ddx = wantX - c.gx, ddd = (wantD - c.gd) * 250
                let dist = hypot(ddx, ddd)
                if dist > 2 {
                    let sp = min(c.walkSpeed * (c.kind == .dog ? 1.2 : 1), dist * 2)
                    c.vx = ddx / dist * sp
                    c.vd = ddd / dist * sp / 250
                } else {
                    c.vx = 0; c.vd = 0; moving = false
                }
            } else {
                c.wanderTimer -= dt
                if c.wanderTimer <= 0 {
                    c.wanderTimer = CGFloat.random(in: 1.5...4)
                    let a = CGFloat.random(in: 0...(2 * .pi))
                    let stop = (c.kind == .cow || c.kind == .pig) ? Int.random(in: 0..<3) == 0 : Int.random(in: 0..<6) == 0
                    c.vx = stop ? 0 : cos(a) * c.walkSpeed
                    c.vd = stop ? 0 : sin(a) * c.walkSpeed / 400
                }
                moving = c.vx != 0
            }
            // flee from the beam (calculateDirectionToBeam)
            if beamActive && c.kind.flees {
                let fx = c.gx - tX, fd = (c.gd - tD) * 250
                let dist = hypot(fx, fd)
                if dist < beamRadiusWorld * 3.2 && dist > 0.1 {
                    let sp = c.walkSpeed * 1.35
                    c.vx = fx / dist * sp
                    c.vd = fd / dist * sp / 250
                    moving = true
                    if c.kind == .grumpa && !c.spoke && Int.random(in: 0..<90) == 0 {
                        c.spoke = true
                        if screen == .playing { sound.grumpa() }
                    }
                }
            }
            c.gx += c.vx * dt
            c.gd = max(dMin + 0.02, min(dMax - 0.04, c.gd + c.vd * dt))
            if abs(c.vx) > 1 { c.body.xScale = c.vx > 0 ? 1 : -1 }

            // walk cycle
            let bob = moving ? abs(sin(clock * 14 + c.wob)) : 0
            if let legs = c.body.childNode(withName: "legs") { legs.position.y = bob * 1.6 }
            c.body.position.y = c.kind == .dog ? bob * 4 : bob * 1.2
            if c.kind == .grumpa, let fork = c.body.childNode(withName: "fork") {
                fork.zRotation = sin(clock * (moving ? 10 : 3) + c.wob) * 0.25
            }
            if c.kind == .reporter {
                c.flashTimer -= dt
                if c.flashTimer <= 0, let fl = c.body.childNode(withName: "//flash") {
                    c.flashTimer = CGFloat.random(in: 1.5...3.5)
                    let glow = Art.circ(7, UIColor(white: 1, alpha: 0.95))
                    glow.position = fl.position
                    fl.parent?.addChild(glow)
                    glow.run(.sequence([.group([.scale(to: 3, duration: 0.15), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
                }
            }
            project(c)

            // the beam grabs anything inside its circle
            if beamActive && groundDist(c.gx, c.gd, toScreen: T) < 1 {
                startLift(c)
                if screen == .playing {
                    switch c.kind {
                    case .sheep: sound.sheep()
                    case .cow: sound.play("cow", volume: 0.9, minGap: 0.4)
                    case .pig: sound.play("pig", volume: 0.9, minGap: 0.3)
                    case .dog: sound.play("dog", volume: 0.8, minGap: 0.3)
                    case .grumpa: sound.grumpa()
                    default: if Bool.random() { sound.grumpa() } else { sound.play("grab", volume: 0.5) }
                    }
                }
            }
        }
    }

    private func startLift(_ n: GroundThing) {
        n.lifting = true
        n.liftT = 0
        n.liftScale = sc(n.gd)
        n.liftOffset = CGPoint(x: n.position.x - beamPt.x, y: n.position.y - beamPt.y)
        n.removeFromParent()
        liftLayer.addChild(n)
        n.zPosition = 0
    }

    /// Lifted things ride up the beam to the saucer, spinning and shrinking.
    private func updateLifting(_ dt: CGFloat) {
        let T = beamPt
        let U = ufoBottom
        var done: [GroundThing] = []
        for case let n as GroundThing in liftLayer.children {
            let dur: CGFloat
            if let c = n as? Creature {
                dur = 0.55 + c.kind.weight * 0.12
            } else if n is Coin {
                dur = 0.35
            } else {
                dur = 0.5
            }
            n.liftT = min(1, n.liftT + dt / dur)
            let t = n.liftT
            let e = pow(t, 1.5)
            let swirl = sin(clock * 9 + n.spin * 4) * 10 * ws * (1 - t)
            n.position = CGPoint(x: T.x + (U.x - T.x) * e + n.liftOffset.x * (1 - t) + swirl,
                                 y: T.y + (U.y - T.y) * e + n.liftOffset.y * (1 - t) + sin(t * .pi) * 6 * ws)
            n.setScale(n.liftScale * (1 - 0.55 * t))
            if n is Creature { n.zRotation += (2 + abs(n.spin) * 3) * dt * (n.spin >= 0 ? 1 : -1) }
            if let c = n as? Creature, let legs = c.body.childNode(withName: "legs") {
                legs.position.y = abs(sin(clock * 24 + c.wob)) * 2.5   // kicking legs
            }
            if t >= 1 { done.append(n) }
        }
        for n in done { collect(n) }
    }

    private func collect(_ n: GroundThing) {
        n.removeFromParent()
        let U = ufoBottom
        if let c = n as? Creature {
            creatures.removeAll { $0 === c }
            guard screen == .playing else { return }
            let pts = c.value * multiplier * (power == .multiply ? 2 : 1)
            score += pts
            abducted += 1
            bumpStreak()
            popup("+\(pts)", at: CGPoint(x: U.x + 18 * ws, y: U.y - 6 * ws), color: UIK.cyan)
            sound.play("collect", volume: 0.6)
            hapticLight.impactOccurred()
        } else if let c = n as? Coin {
            coins.removeAll { $0 === c }
            guard screen == .playing else { return }
            runCoins += 1
            score += multiplier
            bumpStreak()
            sound.play("coin", volume: 0.55, minGap: 0.05)
        } else if let p = n as? Pickup {
            pickups.removeAll { $0 === p }
            guard screen == .playing else { return }
            let lvl = store.d.powerLevel[p.type.rawValue]
            if lvl > 0 {
                power = p.type
                powerTimer = p.type.durations[lvl - 1]
                store.d.powerupsCollected += 1
                banner(p.type.title.uppercased() + "!")
                sound.play("powerup")
            }
        }
    }

    private func bumpStreak() {
        sinceCollect = 0
        collectedStreak += 1
        while level + 1 < Tuning.streakCounts.count && collectedStreak >= Tuning.streakCounts[level + 1] {
            level += 1
            streakSpeed = Tuning.streakSpeed[level]
            banner("\(multiplier)X!")
            sound.play("levelup")
        }
    }

    private func dropLevel() {
        guard level > 0 else { return }
        level -= 1
        collectedStreak = Tuning.streakCounts[level]
        streakSpeed = Tuning.streakSpeed[level]
    }

    private func updateCoins(_ dt: CGFloat) {
        let T = beamPt
        let tD = depth(atY: T.y)
        let tX = worldX(atX: T.x, d: tD)
        for c in coins where !c.lifting {
            if power == .magnet && screen == .playing {
                let fx = tX - c.gx, fd = (tD - c.gd) * 250
                let dist = hypot(fx, fd)
                if dist < 420 && dist > 1 {
                    let sp: CGFloat = 520
                    c.gx += fx / dist * sp * dt
                    c.gd += fd / dist * sp * dt / 250
                }
            }
            project(c)
            if beamActive && screen == .playing && groundDist(c.gx, c.gd, toScreen: T) < 1.15 {
                startLift(c)
            }
        }
    }

    private func updatePickups(_ dt: CGFloat) {
        let T = beamPt
        for p in pickups where !p.lifting {
            project(p)
            if beamActive && screen == .playing && groundDist(p.gx, p.gd, toScreen: T) < 1.2 {
                startLift(p)
            }
        }
    }

    private func updateObstacles(_ dt: CGFloat, playing: Bool) {
        let U = ufoBottom
        for o in obstacles where !o.dead {
            if o.hitCooldown > 0 { o.hitCooldown -= dt }
            if o.kind.isVehicle && o.vx != 0 {
                o.gx += o.vx * dt
                o.gd = roadD(o.gx) + o.lane
            }
            project(o)
            if o.kind.isVehicle && o.vx != 0 {
                // tilt along the winding road
                let x0 = o.gx - 30, x1 = o.gx + 30
                let a = CGPoint(x: sx(x0, roadD(x0) + o.lane), y: sy(roadD(x0) + o.lane))
                let b = CGPoint(x: sx(x1, roadD(x1) + o.lane), y: sy(roadD(x1) + o.lane))
                let ang = atan2(b.y - a.y, b.x - a.x)
                o.zRotation = max(-0.45, min(0.45, ang)) + sin(clock * 9 + o.spin * 5) * 0.015
                if let art = o.children.first { art.xScale = o.vx < 0 ? -1 : 1 }
            }

            if o.kind == .tank && playing && status == .play {
                let flip: CGFloat = (o.children.first?.xScale ?? 1) < 0 ? -1 : 1
                if let barrel = o.childNode(withName: "//barrel") {
                    let dx = U.x - o.position.x, dy = U.y - o.position.y
                    barrel.zRotation = max(0.2, min(2.9, atan2(dy, dx * flip)))
                }
                if o.position.x > 0 && o.position.x < W {
                    o.fireTimer -= dt
                    if o.fireTimer <= 0 {
                        o.fireTimer = CGFloat.random(in: 2...3.2)
                        fireMissile(from: o)
                    }
                }
            }
        }
    }

    /// The beam line hurts when it passes through an obstacle at the same depth.
    private func checkBeamCollisions(_ dt: CGFloat) {
        guard beamActive, status == .play else { return }
        let T = beamPt
        let U = ufoBottom
        let tD = depth(atY: T.y)
        let r = beamRadiusWorld * sc(tD)
        for o in obstacles where !o.dead && o.hitCooldown <= 0 {
            let s = sc(o.gd)
            let box = o.kind.hitBox
            let hw = box.0, hh = box.1
            let rect = CGRect(x: o.position.x - hw * s * 0.85, y: o.position.y, width: hw * s * 1.7, height: hh * s * 0.9)
            if rect.maxX < min(T.x, U.x) - r || rect.minX > max(T.x, U.x) + r { continue }
            var hit = false
            for i in 0...14 {
                let t = CGFloat(i) / 14
                let dep = ufoDepth + (tD - ufoDepth) * t
                if abs(dep - o.gd) > o.kind.depthTolerance + 0.04 { continue }
                let p = CGPoint(x: U.x + (T.x - U.x) * t, y: U.y + (T.y - U.y) * t)
                let w = 5 * ws * (1 - t) + r * 0.45 * t
                if rect.insetBy(dx: -w, dy: -w * 0.4).contains(p) { hit = true; break }
            }
            guard hit else { continue }
            if power == .rampage {
                smash(o)
            } else if invincible <= 0 && damageTimer <= 0 {
                o.hitCooldown = 1.5
                takeDamage(o.kind.damage, byVehicle: o.kind.isVehicle)
                sparksAt(CGPoint(x: o.position.x, y: o.position.y + hh * s * 0.5))
            }
        }
        obstacles.removeAll { o in
            if o.dead { o.removeFromParent(); return true }
            return false
        }
    }

    private func smash(_ o: Obstacle) {
        o.dead = true
        explode(o)
        let pts = 50 * multiplier
        score += pts
        popup("SMASH +\(pts)", at: CGPoint(x: o.position.x, y: o.position.y + 40 * ws), color: Art.rgb(1, 0.6, 0.2))
        if o.kind.isVehicle { store.d.vehiclesDestroyed += 1 }
        if o.kind == .tank { store.d.tanksDestroyed += 1 }
        sound.play("explode", volume: 0.8)
        hapticHeavy.impactOccurred()
    }

    private func explode(_ o: Obstacle) {
        let p = CGPoint(x: o.position.x, y: o.position.y + 10 * sc(o.gd))
        let base: UIColor
        switch o.kind {
        case .fence: base = Art.rgb(0.32, 0.33, 0.36)
        case .shed: base = Art.rgb(0.2, 0.32, 0.6)
        case .barn, .barrels, .fireTruck: base = Art.rgb(0.75, 0.15, 0.12)
        case .house: base = Art.rgb(0.3, 0.45, 0.85)
        case .tank, .jeep: base = Art.rgb(0.33, 0.4, 0.24)
        default: base = UIColor(white: 0.65, alpha: 1)
        }
        boom(at: p, size: o.kind.hitBox.0 * sc(o.gd) * 0.6)
        for _ in 0..<12 {
            let d = Art.debris(Bool.random() ? base : UIColor(white: 0.2, alpha: 1))
            d.position = p
            d.zPosition = 10
            fx.addChild(d)
            let vx = CGFloat.random(in: -140...140) * ws
            let vy = CGFloat.random(in: 100...260) * ws
            d.run(.sequence([
                .group([
                    .customAction(withDuration: 0.9) { n, el in
                        let t = CGFloat(el)
                        n.position = CGPoint(x: p.x + vx * t, y: p.y + vy * t - 480 * t * t)
                        n.zRotation = t * 9
                    },
                    .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.3)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func boom(at p: CGPoint, size: CGFloat) {
        let c = Art.circ(max(8, size), UIColor.orange.withAlphaComponent(0.9), p.x, p.y)
        c.zPosition = 20
        fx.addChild(c)
        c.run(.sequence([.group([.scale(to: 3, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        let c2 = Art.circ(max(6, size * 0.6), UIColor.yellow.withAlphaComponent(0.9), p.x, p.y)
        c2.zPosition = 21
        fx.addChild(c2)
        c2.run(.sequence([.group([.scale(to: 2.2, duration: 0.2), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
    }

    private func sparksAt(_ p: CGPoint) {
        for _ in 0..<8 {
            let s = Art.circ(2 * ws, Art.rgb(1, 0.85, 0.4), p.x, p.y)
            s.zPosition = 22
            fx.addChild(s)
            let a = CGFloat.random(in: 0...(2 * .pi))
            s.run(.sequence([.group([.moveBy(x: cos(a) * 30 * ws, y: sin(a) * 30 * ws, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        }
    }

    // MARK: - Missiles (tanks)

    private func fireMissile(from o: Obstacle) {
        let m = Missile()
        m.addChild(Art.missile())
        m.setScale(ws)
        let start = CGPoint(x: o.position.x, y: o.position.y + 28 * sc(o.gd))
        m.position = start
        let speed: CGFloat = 260 * ws
        let aim = ufo.position
        let ang = atan2(aim.y - start.y, aim.x - start.x)
        m.v = CGVector(dx: cos(ang) * speed, dy: sin(ang) * speed)
        m.zRotation = ang
        m.zPosition = 30
        fx.addChild(m)
        missiles.append(m)
        boom(at: start, size: 4)
        sound.play("missile", volume: 0.7)
    }

    private func updateMissiles(_ dt: CGFloat) {
        var dead: [Missile] = []
        for m in missiles {
            m.position.x += m.v.dx * dt
            m.position.y += m.v.dy * dt
            m.life -= dt
            if m.life <= 0 || m.position.y > H + 40 { dead.append(m); continue }
            if status != .dead && hypot(m.position.x - ufo.position.x, m.position.y - ufo.position.y) < 32 * ws {
                dead.append(m)
                takeDamage(2, byVehicle: true)
            }
        }
        for m in dead {
            boom(at: m.position, size: 8)
            m.removeFromParent()
            missiles.removeAll { $0 === m }
        }
    }

    // MARK: - Damage & death

    private func takeDamage(_ amount: Int, byVehicle: Bool) {
        guard status == .play || status == .boost else { return }
        if invincible > 0 || damageTimer > 0 { return }
        health -= max(1, amount)
        if tutorialActive { health = max(1, health) }
        damageTimer = Tuning.damageTime
        hapticHeavy.impactOccurred()
        sound.play("hit")
        redFlash.removeAllActions()
        redFlash.alpha = 1
        redFlash.run(.fadeOut(withDuration: 0.6))
        shake()
        if power != nil && !store.keepsPowerups { power = nil; powerTimer = 0 }
        dropLevel()

        if health <= 0 {
            if secondChance {
                secondChance = false
                health = maxHealth
                invincible = 3
                banner("HEALTH PACK!")
                sound.play("powerup")
                return
            }
            health = 0
            if byVehicle { store.d.deathsByVehicle += 1 }
            die()
        }
    }

    private func shake() {
        let a: CGFloat = 6 * ws
        world.run(.sequence([.moveBy(x: a, y: a * 0.5, duration: 0.03), .moveBy(x: -2 * a, y: -a, duration: 0.05),
                             .moveBy(x: a, y: a * 0.5, duration: 0.03)]))
    }

    private func die() {
        status = .dead
        beamOn = false
        touching = false
        overTimer = 0
        let speed = moveSpeed + streakSpeed
        deathV = CGVector(dx: speed * 1.2 * 6 * ws, dy: 60 * ws)
        bouncesLeft = max(0, Int(floor((speed - 12) / 3))) + 1
        sound.play("crash")
        // drop anything still in the beam
        for case let n as GroundThing in liftLayer.children {
            n.removeFromParent()
            if let c = n as? Creature { creatures.removeAll { $0 === c } }
            if let c = n as? Coin { coins.removeAll { $0 === c } }
            if let p = n as? Pickup { pickups.removeAll { $0 === p } }
        }
        banner("CRASH!")
        store.save()
    }

    private func stepDeath(_ dt: CGFloat) {
        let floorY = sy(1.55)
        deathV.dy -= 900 * ws * dt
        ufoPos.x += deathV.dx * dt
        ufoPos.y += deathV.dy * dt
        ufoPos.x = min(W * 0.85, ufoPos.x)
        ufoArt.zRotation -= 3 * dt
        if ufoPos.y <= floorY {
            ufoPos.y = floorY
            if bouncesLeft > 0 {
                bouncesLeft -= 1
                deathV.dy = 300 * ws * (0.45 + 0.12 * CGFloat(bouncesLeft))
                deathV.dx *= 0.7
                boom(at: ufoPos, size: 10)
                hapticHeavy.impactOccurred()
                sound.play("hit", volume: 0.5)
            } else {
                deathV = .zero
                ufoArt.zRotation += (0.25 - ufoArt.zRotation) * min(1, dt * 5)
                if overTimer > 1.6 && screen == .playing {
                    boom(at: ufoPos, size: 26)
                    sound.play("explode")
                    finishRun()
                    return
                }
            }
        }
        ufo.position = ufoPos
        if Int(clock * 20) % 3 == 0 {
            let puff = Art.circ(6 * ws, UIColor(white: 0.3, alpha: 0.6), ufoPos.x, ufoPos.y + 8 * ws)
            puff.zPosition = -1
            fx.addChild(puff)
            puff.run(.sequence([.group([.moveBy(x: -20, y: 30, duration: 0.8), .scale(to: 2.5, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        }
    }

    // MARK: - Cleanup

    private func offLeft(_ n: GroundThing) -> Bool {
        return sx(n.gx, n.gd) < -150 * ws
    }

    private func cleanup() {
        creatures.removeAll { c in
            if !c.lifting && (offLeft(c) || sx(c.gx, c.gd) > W * 4) { c.removeFromParent(); return true }
            return false
        }
        flocks.removeAll { f in !creatures.contains { $0.flock === f } }
        obstacles.removeAll { o in
            let x = sx(o.gx, o.gd)
            if o.vx > 0 {
                // cars entering from the left start off-screen; drop them once they leave on the right
                if x > W * 3 { o.removeFromParent(); return true }
                return false
            }
            if x < -150 * ws { o.removeFromParent(); return true }
            return false
        }
        coins.removeAll { c in
            if !c.lifting && offLeft(c) { c.removeFromParent(); return true }
            return false
        }
        pickups.removeAll { p in
            if !p.lifting && offLeft(p) { p.removeFromParent(); return true }
            return false
        }
        decals.removeAll { d in
            if offLeft(d) { d.removeFromParent(); return true }
            return false
        }
    }

    // MARK: - Popups

    private func popup(_ text: String, at p: CGPoint, color: UIColor) {
        let l = UIK.label(text, size: 18 * ws, color: color, font: UIK.heavyItalic, x: p.x, y: p.y, shadow: Art.rgb(0.05, 0.1, 0.25, 0.8))
        l.zPosition = 800
        addChild(l)
        l.run(.sequence([.group([.moveBy(x: 10, y: 34 * ws, duration: 0.7), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
    }

    private func banner(_ text: String) {
        let l = UIK.label(text, size: 30, color: UIK.orange, y: H * 0.1, shadow: UIK.orangeDark)
        l.zPosition = 50
        l.setScale(0.4)
        ui.addChild(l)
        l.run(.sequence([.scale(to: 1, duration: 0.15), .wait(forDuration: 0.9), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
}
