import SpriteKit
import UIKit

/// Pseudo-3D farm field seen from above at an angle. Everything on the ground lives in
/// ground space (x = world units along the field, d = depth into the screen) and is
/// projected to the screen every frame.
final class GameScene: SKScene {
    enum Screen { case menu, store, settings, playing, paused, over }
    enum UFOStatus { case intro, play, boost, dead }
    enum StoreTab: Int { case ufo, worlds, powers, items, animals }

    let store = Store.shared
    let sound = Sound.shared

    // MARK: Layout / projection
    var W: CGFloat = 0
    var H: CGFloat = 0
    var ws: CGFloat = 1
    var P: CGFloat = 1.5          // projection factor (screen points per world unit at depth 1)
    var horizonV: CGFloat = 0     // vanishing line
    var A: CGFloat = 0            // y(d) = horizonV - A / d
    let dMin: CGFloat = 1.1
    let dMax: CGFloat = 3.1
    var fieldTop: CGFloat = 0
    var camX: CGFloat = 0

    func sy(_ d: CGFloat) -> CGFloat { return horizonV - A / d }
    func sc(_ d: CGFloat) -> CGFloat { return P / d }
    func sx(_ x: CGFloat, _ d: CGFloat) -> CGFloat { return W * 0.5 + (x - camX) * P / d }
    func depth(atY y: CGFloat) -> CGFloat { return A / max(1, horizonV - y) }
    func worldX(atX x: CGFloat, d: CGFloat) -> CGFloat { return camX + (x - W * 0.5) * d / P }
    func roadD(_ x: CGFloat) -> CGFloat {
        return 2.05 + 0.6 * sin(x / 1150) + 0.22 * sin(x / 430 + 2)
    }

    // MARK: Nodes
    let bg = SKNode()
    let world = SKNode()
    let road = SKShapeNode()
    let roadEdge = SKShapeNode()
    let beamGlow = SKShapeNode()
    let beamCore = SKShapeNode()
    let beamRing = SKShapeNode()
    let crosshair = SKNode()
    var sparkles: [(SKSpriteNode, CGFloat, CGFloat)] = []
    let liftLayer = SKNode()
    let ufo = SKNode()
    var ufoArt = SKNode()
    let fx = SKNode()
    var vignette = SKSpriteNode()
    var redFlash = SKSpriteNode()
    let ui = SKNode()
    let hud = SKNode()
    var overlay = SKNode()
    var buttons: [Button] = []
    var clouds: [SKNode] = []
    var trees: [SKNode] = []
    var hills: [SKNode] = []
    var cloudTiles: [SKSpriteNode] = []
    var farTiles: [SKSpriteNode] = []
    var nearTiles: [SKSpriteNode] = []
    var hedgeTiles: [SKSpriteNode] = []
    let beamSprite = SKSpriteNode()
    let beamInner = SKSpriteNode()
    let landing = SKSpriteNode()
    let landing2 = SKSpriteNode()
    var ufoScale: CGFloat = 1
    var sideInset: CGFloat = 0
    // big update state
    var grabTimes: [CGFloat] = []
    var lastMega: CGFloat = -10
    let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    let rainNode = SKEmitterNode()
    let snowNode = SKEmitterNode()
    var raining = false
    var rainLeft: CGFloat = 0
    var nextWeatherAt = 1500
    var lightningIn: CGFloat = 4
    let flashNode = SKSpriteNode()
    let dawnNode = SKSpriteNode()
    let slowTint = SKSpriteNode()
    var flyers: [Flyer] = []
    var dusterIn: CGFloat = 25
    var warnNode: SKNode?
    var searchLight: SKSpriteNode?
    var searchCone: SKSpriteNode?
    var searchLeft: CGFloat = 0
    var searchIn: CGFloat = 20
    var searchPhase: CGFloat = 0
    var spottedCooldown: CGFloat = 0
    var bossNode: SKNode?
    var bossTank: Obstacle?
    var bossLeft: CGFloat = 0
    var bossFireIn: CGFloat = 2
    var nextBossAt = 3000
    var bossCount = 0
    var bossLabel = SKLabelNode()
    var biome: Biome = .farm
    var fieldNode: SKSpriteNode?
    let beamSprite2 = SKSpriteNode()
    let landing3 = SKSpriteNode()
    let shieldNode = SKShapeNode()
    var lastHitDistance = 0
    var lastMissionTick: CGFloat = 0
    var bats: [SKSpriteNode] = []
    var hearts: [HeartPickup] = []
    var nextHeartAt = 1500
    /// Only one shooter at a time: after any shot, nobody fires until this runs out.
    var shotCooldown: CGFloat = 0
    // lights (beam pool, saucer underglow, police searchlight)
    let beamLight = SKLightNode()
    let ufoLight = SKLightNode()
    let spotLight = SKLightNode()
    var beamColorNow: UIColor = .white
    weak var aimingHunter: Creature?
    var fireflies: [(node: SKSpriteNode, phase: CGFloat, speed: CGFloat)] = []
    let beamDust = SKEmitterNode()
    var haze = SKSpriteNode()
    var nextFenceX: CGFloat = 0
    var nextFarX: CGFloat = 0
    // left depth slider
    let slider = SKNode()
    let sliderThumb = SKShapeNode()
    var sliderRect = CGRect.zero
    var sliding = false

    // HUD
    var scoreLabel = SKLabelNode()
    var multLabel = SKLabelNode()
    let ringTrack = SKShapeNode()
    let ringFill = SKShapeNode()
    var healthBars: [SKShapeNode] = []
    var coinLabel = SKLabelNode()
    var distLabel = SKLabelNode()
    var powerLabel = SKLabelNode()
    var pauseButton: Button?

    // MARK: Run state
    var screen: Screen = .menu
    var status: UFOStatus = .intro
    var storeTab: StoreTab = .powers
    var storePage = 0
    var runCfg = RunConfig()
    var lastTime: TimeInterval = 0
    var clock: CGFloat = 0
    var elapsed: CGFloat = 0
    var overTimer: CGFloat = 0

    var touching = false
    var lastTouch: CGPoint = .zero
    var target = CGPoint.zero        // where the finger wants the beam (screen)
    var beamPt = CGPoint.zero        // smoothed beam end (screen)
    var ufoPos = CGPoint.zero        // screen
    var ufoVel: CGFloat = 0
    var ufoDepth: CGFloat = 2
    var beamOn = false

    var moveSpeed: CGFloat = Tuning.startSpeed
    var streakSpeed: CGFloat = 0
    var curSpeed: CGFloat = 0
    var distance = 0
    var boostUntil: CGFloat = 0
    var nextSpeedBanner = 1000
    var score = 0
    var runCoins = 0
    var health = 3
    var maxHealth = 3
    var level = 0
    var collectedStreak = 0
    var sinceCollect: CGFloat = 0
    var invincible: CGFloat = 0
    var damageTimer: CGFloat = 0
    var power: PowerType?
    var powerTimer: CGFloat = 0
    var secondChance = false
    var tutorial = false
    var abducted = 0
    var deathV = CGVector.zero
    var bouncesLeft = 0

    var inVehicleState = false
    var stateTimer: CGFloat = 0
    var vehicleDuration = Tuning.vehicleDuration
    var vehicleDifficulty = 0
    var nextVehicleIn: CGFloat = 1
    var nextTankIn: CGFloat = 18

    // Entities
    var creatures: [Creature] = []
    var obstacles: [Obstacle] = []
    var coins: [Coin] = []
    var pickups: [Pickup] = []
    var decals: [Decal] = []
    var missiles: [Missile] = []
    var flocks: [Flock] = []

    var nextGroupX: CGFloat = 0
    var nextStaticX: CGFloat = 0
    var nextCoinX: CGFloat = 0
    var nextPickupX: CGFloat = 0
    var nextTuftX: CGFloat = 0
    var nextSign = Tuning.signEvery
    var pendingSigns: [(CGFloat, [String])] = []

    /// Launch argument used by the CI screenshot job: plays by itself.
    let autoplay = ProcessInfo.processInfo.arguments.contains("-autoplay")
    let hapticLight = UIImpactFeedbackGenerator(style: .light)
    let hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Setup

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        setup()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil, size.width > 0, size.height > 0, size != oldSize else { return }
        setup()
    }

    func setup() {
        removeAllChildren()
        removeAllActions()
        for n in [bg, world, liftLayer, ufo, fx, ui, hud] { n.removeAllChildren() }
        creatures = []; obstacles = []; coins = []; pickups = []; decals = []; missiles = []; flocks = []
        clouds = []; trees = []; hills = []; sparkles = []; healthBars = []
        cloudTiles = []; farTiles = []; nearTiles = []; hedgeTiles = []

        anchorPoint = .zero
        let ins = view?.safeAreaInsets ?? .zero
        sideInset = max(ins.left, ins.right)
        W = size.width
        H = size.height
        ws = max(0.85, min(1.6, H / 390))
        P = 1.5 * ws
        horizonV = H * 0.62
        A = H * 0.62
        fieldTop = H * 0.44
        backgroundColor = Art.rgb(0.12, 0.08, 0.25)
        let fxOn = FX.cinematic && !ProcessInfo.processInfo.arguments.contains("-nofx")
        filter = fxOn ? CinemaFilter() : nil
        shouldEnableEffects = fxOn
        shouldRasterize = false

        bg.zPosition = -1000
        addChild(bg)
        buildBackground()

        world.zPosition = 0
        addChild(world)
        road.zPosition = 2
        road.lineWidth = 0
        road.fillColor = Art.rgb(0.2, 0.17, 0.12, 0.92)
        road.strokeColor = .clear
        world.addChild(road)
        roadEdge.zPosition = 3
        roadEdge.lineWidth = 1.5
        roadEdge.strokeColor = Art.rgb(0.12, 0.1, 0.07, 0.7)
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
        crosshair.alpha = 0
        for (b, z, a) in [(beamSprite, CGFloat(598), CGFloat(0.85)), (beamInner, CGFloat(599), CGFloat(0.9))] {
            b.texture = Painter.beam()
            b.anchorPoint = CGPoint(x: 0.5, y: 1)
            b.blendMode = .add
            b.colorBlendFactor = 1
            b.zPosition = z
            b.alpha = a
            addChild(b)
        }
        for (l, z) in [(landing, CGFloat(597)), (landing2, CGFloat(603))] {
            l.texture = Painter.landing()
            l.blendMode = .add
            l.colorBlendFactor = 1
            l.zPosition = z
            addChild(l)
        }
        let dot = Art.softDot()
        for _ in 0..<28 {
            let s = SKSpriteNode(texture: dot)
            s.size = CGSize(width: 7 * ws, height: 7 * ws)
            s.blendMode = .add
            s.zPosition = 602
            addChild(s)
            sparkles.append((s, CGFloat.random(in: 0...1), CGFloat.random(in: -1...1)))
        }

        // glowing dust that streams up the beam
        beamDust.removeFromParent()
        beamDust.particleTexture = dot
        beamDust.particleBirthRate = 0
        beamDust.particleLifetime = 0.9
        beamDust.particleLifetimeRange = 0.3
        beamDust.particleSize = CGSize(width: 7 * ws, height: 7 * ws)
        beamDust.particleScaleRange = 0.6
        beamDust.particleScaleSpeed = -0.7
        beamDust.particleAlpha = 0.95
        beamDust.particleAlphaSpeed = -0.9
        beamDust.particleBlendMode = .add
        beamDust.particleColorBlendFactor = 1
        beamDust.emissionAngleRange = 0.18
        beamDust.zPosition = 604
        beamDust.targetNode = self
        addChild(beamDust)

        // haze over the far field: distant things fade into the night air
        haze = SKSpriteNode(texture: Art.gradient(size: CGSize(width: 8, height: 64),
                                                   colors: [Art.rgb(0.3, 0.35, 0.62, 0), Art.rgb(0.28, 0.33, 0.6, 0.3), Art.rgb(0.25, 0.3, 0.5, 0)],
                                                   locations: [0, 0.5, 1]))
        haze.anchorPoint = .zero
        haze.size = CGSize(width: W, height: H * 0.16)
        haze.position = CGPoint(x: 0, y: sy(2.5) - H * 0.03)
        haze.zPosition = 420
        addChild(haze)

        // fireflies drifting over the grass
        fireflies = []
        for _ in 0..<22 {
            let f = SKSpriteNode(texture: dot)
            f.size = CGSize(width: 6 * ws, height: 6 * ws)
            f.color = Art.rgb(1, 0.92, 0.45)
            f.colorBlendFactor = 1
            f.blendMode = .add
            f.position = CGPoint(x: CGFloat.random(in: 0...W), y: CGFloat.random(in: H * 0.04...H * 0.42))
            f.zPosition = 430
            addChild(f)
            fireflies.append((f, CGFloat.random(in: 0...6.28), CGFloat.random(in: 0.6...1.4)))
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
        redFlash = SKSpriteNode(texture: Art.vignette(size: CGSize(width: 256, height: 256 * H / W), color: .red, strength: 0.55))
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

        setupExtras()
        showMenu()
        if autoplay {
            run(.wait(forDuration: 1.0)) { [weak self] in self?.startGame() }
        }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-themes"), i + 1 < args.count, let pg = Int(args[i + 1]) {
            run(.wait(forDuration: 0.5)) { [weak self] in self?.showStore(.ufo, page: pg) }
        }
        if args.contains("-exportart") {
            run(.wait(forDuration: 1.0)) { [weak self] in self?.exportArt() }
        }
        if let i = args.firstIndex(of: "-screen"), i + 1 < args.count {
            let what = args[i + 1]
            run(.wait(forDuration: 0.6)) { [weak self] in
                guard let self = self else { return }
                switch what {
                case "missions": self.showMissions()
                case "awards": self.showAwards()
                case "collection": self.showAwards(tab: 1)
                case "friends": self.showFriends()
                case "worlds": self.showStore(.worlds)
                default: break
                }
            }
        }
        if let i = args.firstIndex(of: "-startat"), i + 1 < args.count, let m = Int(args[i + 1]) {
            // jump ahead (used by the screenshot job to check the city and desert)
            run(.wait(forDuration: 2.2)) { [weak self] in
                guard let self = self else { return }
                self.camX = CGFloat(m) * Tuning.unit
                self.nextGroupX = self.camX
                self.nextStaticX = self.camX + 300
                self.nextTuftX = self.camX - self.W * 0.5 * self.dMax / self.P
                self.nextFenceX = self.nextTuftX
                self.nextFarX = self.camX - 300
                self.nextCoinX = self.camX + 200
                self.nextSign = (m / Tuning.signEvery + 1) * Tuning.signEvery
                self.nextBossAt = m + 3000
                self.nextWeatherAt = m + 400
            }
        }
    }

    func setUFOArt() {
        ufoArt.removeFromParent()
        ufoArt = Art.ufo(theme: store.currentTheme)
        ufoScale = min(W * 0.23, H * 0.5) / 220
        ufoArt.setScale(ufoScale)
        ufo.addChild(ufoArt)
    }

    func buildCrosshair() {
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

    func buildBackground() {
        let sky = SKSpriteNode(texture: Painter.sky(size), size: size)
        sky.anchorPoint = .zero
        sky.zPosition = 0
        bg.addChild(sky)
        for i in 0..<10 {
            let st = Art.circ(CGFloat.random(in: 0.7...1.3), .white, CGFloat.random(in: 0...W), CGFloat.random(in: H * 0.6...H))
            st.zPosition = 1
            st.run(.repeatForever(.sequence([.wait(forDuration: Double(i) * 0.3), .fadeAlpha(to: 0.15, duration: 0.9), .fadeAlpha(to: 0.9, duration: 0.9)])))
            bg.addChild(st)
        }
        func tiles(_ tex: SKTexture, _ h: CGFloat, _ y: CGFloat, _ z: CGFloat) -> [SKSpriteNode] {
            var out: [SKSpriteNode] = []
            for i in 0..<2 {
                let t = SKSpriteNode(texture: tex, size: CGSize(width: W, height: h))
                t.anchorPoint = .zero
                t.position = CGPoint(x: CGFloat(i) * W, y: y)
                t.zPosition = z
                bg.addChild(t)
                out.append(t)
            }
            return out
        }
        let cloudH = H * 0.38
        cloudTiles = tiles(Painter.clouds(CGSize(width: W, height: cloudH)), cloudH, H * 0.6, 2)
        let farH = H * 0.25
        farTiles = tiles(Painter.mountains(CGSize(width: W, height: farH), seed: 21, top: Art.rgb(0.2, 0.24, 0.45), bottom: Art.rgb(0.12, 0.15, 0.3), rough: 0.6), farH, fieldTop - 4, 3)
        let nearH = H * 0.13
        nearTiles = tiles(Painter.mountains(CGSize(width: W, height: nearH), seed: 4, top: Art.rgb(0.1, 0.13, 0.27), bottom: Art.rgb(0.05, 0.07, 0.15), rough: 0.35), nearH, fieldTop - 4, 4)
        let hedgeH = H * 0.06
        hedgeTiles = tiles(Painter.hedge(CGSize(width: W, height: hedgeH)), hedgeH, fieldTop - hedgeH * 0.45, 6)

        let field = SKSpriteNode(texture: Painter.field(CGSize(width: W, height: fieldTop + 4)), size: CGSize(width: W, height: fieldTop + 4))
        field.anchorPoint = .zero
        field.zPosition = 5
        bg.addChild(field)
        fieldNode = field
        field.lightingBitMask = 1
        biome = .farm

        // haze where the field meets the hills
        let fog = SKSpriteNode(texture: Art.gradient(size: CGSize(width: 8, height: 64),
                                                      colors: [Art.rgb(0.45, 0.5, 0.8, 0), Art.rgb(0.4, 0.45, 0.75, 0.28), Art.rgb(0.3, 0.35, 0.6, 0)],
                                                      locations: [0, 0.45, 1]))
        fog.anchorPoint = .zero
        fog.size = CGSize(width: W, height: H * 0.14)
        fog.position = CGPoint(x: 0, y: fieldTop - H * 0.07)
        fog.zPosition = 7
        bg.addChild(fog)
    }

    func moveFireflies(_ dx: CGFloat) {
        for f in fireflies {
            let n = f.node
            n.position.x += -dx * P / 1.8 + sin(clock * f.speed + f.phase) * 0.4
            n.position.y += cos(clock * f.speed * 0.8 + f.phase) * 0.25
            if n.position.x < -10 { n.position.x = W + 10; n.position.y = CGFloat.random(in: H * 0.04...H * 0.42) }
            n.alpha = 0.25 + 0.75 * max(0, sin(clock * f.speed * 2 + f.phase))
        }
    }

    func scrollBackground(_ dx: CGFloat) {
        moveFireflies(dx)
        func scroll(_ arr: [SKSpriteNode], _ amount: CGFloat) {
            for t in arr {
                t.position.x -= amount
                if t.position.x <= -W { t.position.x += W * 2 }
            }
        }
        scroll(cloudTiles, dx * P / 40 + 0.06)
        scroll(farTiles, dx * P / 14)
        scroll(nearTiles, dx * P / 7)
        scroll(hedgeTiles, dx * P / 3.6)
    }

    // MARK: - HUD

    func pill(_ w: CGFloat, _ h: CGFloat, at p: CGPoint) -> SKShapeNode {
        let n = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: h / 2)
        n.fillColor = UIColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 0.55)
        n.strokeColor = UIColor(white: 1, alpha: 0.1)
        n.lineWidth = 1
        n.position = p
        return n
    }

    func buildHUD() {
        let top = H / 2
        let hs = min(1.25, max(0.85, H / 390))
        // coins + distance pills (top-left)
        let lx = -W / 2 + max(18, sideInset * 0.5) + 62 * hs
        hud.addChild(pill(124 * hs, 30 * hs, at: CGPoint(x: lx, y: top - 26 * hs)))
        let coin = SKSpriteNode(texture: Painter.coin(), size: CGSize(width: 30 * hs, height: 30 * hs))
        coin.position = CGPoint(x: lx - 44 * hs, y: top - 26 * hs)
        hud.addChild(coin)
        coinLabel = UIK.label("0", size: 19 * hs, color: Art.rgb(1, 0.82, 0.35), font: UIK.heavyItalic, x: lx - 26 * hs, y: top - 26 * hs, align: .left, shadow: nil)
        hud.addChild(coinLabel)
        hud.addChild(pill(124 * hs, 30 * hs, at: CGPoint(x: lx, y: top - 62 * hs)))
        let pin = CGMutablePath()
        pin.addArc(center: CGPoint(x: 0, y: 3), radius: 5, startAngle: -0.5, endAngle: .pi + 0.5, clockwise: false)
        pin.addLine(to: CGPoint(x: 0, y: -7))
        pin.closeSubpath()
        let pinN = SKShapeNode(path: pin)
        pinN.fillColor = Art.rgb(0.35, 0.65, 1)
        pinN.strokeColor = .clear
        pinN.addChild(Art.circ(2, Art.rgb(0.05, 0.08, 0.2), 0, 3))
        pinN.setScale(hs)
        pinN.position = CGPoint(x: lx - 44 * hs, y: top - 62 * hs)
        hud.addChild(pinN)
        distLabel = UIK.label("0 M", size: 16 * hs, color: .white, font: UIK.heavyItalic, x: lx - 30 * hs, y: top - 62 * hs, align: .left, shadow: nil)
        hud.addChild(distLabel)

        // multiplier ring + score (top-centre)
        let ringR: CGFloat = 25 * hs
        let rx: CGFloat = -64 * hs
        let ry = top - 40 * hs
        ringTrack.removeFromParent()
        ringFill.removeFromParent()
        ringTrack.path = CGPath(ellipseIn: CGRect(x: -ringR, y: -ringR, width: ringR * 2, height: ringR * 2), transform: nil)
        ringTrack.strokeColor = Art.rgb(0.15, 0.25, 0.45, 0.9)
        ringTrack.lineWidth = 5 * hs
        ringTrack.fillColor = Art.rgb(0.02, 0.04, 0.1, 0.7)
        ringTrack.position = CGPoint(x: rx, y: ry)
        hud.addChild(ringTrack)
        ringFill.strokeColor = Art.rgb(0.4, 0.8, 1)
        ringFill.lineWidth = 4 * hs
        ringFill.glowWidth = 3
        ringFill.lineCap = .round
        ringFill.position = ringTrack.position
        hud.addChild(ringFill)
        multLabel = UIK.label("1X", size: 20 * hs, color: .white, font: UIK.heavyItalic, x: rx, y: ry, shadow: Art.rgb(0.1, 0.3, 0.7, 0.8))
        hud.addChild(multLabel)

        scoreLabel = UIK.label("0", size: 40 * hs, color: .white, font: UIK.heavyItalic, x: rx + ringR + 10 * hs, y: ry - 8 * hs, align: .left,
                               shadow: Art.rgb(0.05, 0.08, 0.25, 0.9))
        hud.addChild(scoreLabel)

        let heart = UIK.label("♡", size: 22 * hs, color: .white, font: "AvenirNext-Bold", x: rx + ringR + 22 * hs, y: top - 14 * hs, shadow: nil)
        heart.name = "heart"
        hud.addChild(heart)

        powerLabel = UIK.label("", size: 17 * hs, color: .white, font: UIK.heavyItalic, x: 0, y: top - 96 * hs)
        hud.addChild(powerLabel)

        // pause (dark round button)
        let px = W / 2 - max(40 * hs, sideInset), py = top - 36 * hs
        let pc = SKShapeNode(circleOfRadius: 24 * hs)
        pc.fillColor = Art.rgb(0.02, 0.03, 0.08, 0.6)
        pc.strokeColor = UIColor(white: 1, alpha: 0.2)
        pc.lineWidth = 1.5
        pc.position = CGPoint(x: px, y: py)
        pc.addChild(Art.rect(5 * hs, 18 * hs, .white, -5 * hs, 0, r: 1.5))
        pc.addChild(Art.rect(5 * hs, 18 * hs, .white, 5 * hs, 0, r: 1.5))
        hud.addChild(pc)
        let pb = Button("", w: 52 * hs, h: 52 * hs, plain: true) { [weak self] in self?.pauseGame() }
        pb.position = CGPoint(x: px, y: py)
        hud.addChild(pb)
        pauseButton = pb

        // left slider: drag it to push the beam deeper into the field or closer
        slider.removeAllChildren()
        slider.removeFromParent()
        let sw = 40 * hs, sh = H * 0.36
        let sxp = -W / 2 + max(14, sideInset + 4) + sw / 2, syp = -H * 0.1
        let cap = SKShapeNode(rectOf: CGSize(width: sw, height: sh), cornerRadius: sw / 2)
        cap.fillColor = Art.rgb(0.02, 0.03, 0.08, 0.55)
        cap.strokeColor = UIColor(white: 1, alpha: 0.12)
        cap.lineWidth = 1.2
        slider.addChild(cap)
        for d in [1, -1] as [CGFloat] {
            let ch = CGMutablePath()
            ch.move(to: CGPoint(x: -6 * hs, y: d * (sh / 2 - 22 * hs) - d * 3 * hs))
            ch.addLine(to: CGPoint(x: 0, y: d * (sh / 2 - 22 * hs) + d * 3 * hs))
            ch.addLine(to: CGPoint(x: 6 * hs, y: d * (sh / 2 - 22 * hs) - d * 3 * hs))
            let cn = SKShapeNode(path: ch)
            cn.strokeColor = UIColor(white: 1, alpha: 0.55)
            cn.lineWidth = 2
            cn.lineCap = .round
            slider.addChild(cn)
        }
        sliderThumb.path = CGPath(roundedRect: CGRect(x: -sw * 0.32, y: -4 * hs, width: sw * 0.64, height: 8 * hs), cornerWidth: 4 * hs, cornerHeight: 4 * hs, transform: nil)
        sliderThumb.fillColor = Art.rgb(0.75, 0.6, 1)
        sliderThumb.strokeColor = .clear
        sliderThumb.glowWidth = 4
        slider.addChild(sliderThumb)
        slider.position = CGPoint(x: sxp, y: syp)
        hud.addChild(slider)
        sliderRect = CGRect(x: W / 2 + sxp - sw, y: H / 2 + syp - sh / 2 - 10, width: sw * 2, height: sh + 20)

        hud.isHidden = true
        rebuildHealthBars()
    }

    func rebuildHealthBars() {
        shownHealth = -1
        ringFrac = -1
        for b in healthBars { b.removeFromParent() }
        healthBars = []
        let top = H / 2
        let hs = min(1.25, max(0.85, H / 390))
        let segW: CGFloat = 30 * hs, segH: CGFloat = 8 * hs
        let x0 = -64 * hs + 25 * hs + 38 * hs
        for i in 0..<max(3, maxHealth) {
            let s = SKShapeNode(rectOf: CGSize(width: segW, height: segH), cornerRadius: segH / 2)
            s.position = CGPoint(x: x0 + CGFloat(i) * (segW + 5 * hs) + segW / 2, y: top - 14 * hs)
            s.lineWidth = 1.2
            hud.addChild(s)
            healthBars.append(s)
        }
    }

    func setText(_ l: SKLabelNode, _ s: String) {
        if l.text == s { return }
        l.text = s
        (l.children.first as? SKLabelNode)?.text = s
    }

    func updateHUD() {
        setText(scoreLabel, UIK.coins(score))
        setText(multLabel, "\(multiplier)X")
        setText(coinLabel, "\(runCoins)")
        setText(distLabel, "\(UIK.coins(distance)) M")

        if health != shownHealth || maxHealth != shownMax {
        shownHealth = health
        shownMax = maxHealth
        for (i, b) in healthBars.enumerated() {
            if i >= maxHealth { b.isHidden = true; continue }
            b.isHidden = false
            let full = i < health
            b.fillColor = full ? Art.rgb(0.45, 0.82, 1) : Art.rgb(0.05, 0.08, 0.16, 0.8)
            b.strokeColor = full ? Art.rgb(0.8, 0.95, 1, 0.9) : Art.rgb(0.25, 0.4, 0.6, 0.8)
            b.glowWidth = full ? 1.5 : 0
        }
        }
        if let heart = hud.childNode(withName: "heart") as? SKLabelNode {
            heart.fontColor = (health <= 1 && Int(clock * 4) % 2 == 0) ? Art.rgb(1, 0.3, 0.35) : .white
            let ht = secondChance ? "♥" : "♡"
            if heart.text != ht { heart.text = ht }
        }

        let hasNext = level + 1 < Tuning.streakCounts.count
        let lo = Tuning.streakCounts[level]
        let hi = hasNext ? Tuning.streakCounts[level + 1] : lo + 1
        let frac = hasNext ? CGFloat(collectedStreak - lo) / CGFloat(max(1, hi - lo)) : 1
        let hs = min(1.25, max(0.85, H / 390))
        let r: CGFloat = 25 * hs
        let q = (frac * 200).rounded() / 200
        if q != ringFrac {
            ringFrac = q
            let p = CGMutablePath()
            let start = CGFloat.pi / 2
            p.addArc(center: .zero, radius: r, startAngle: start, endAngle: start - max(0.01, min(1, q)) * .pi * 2, clockwise: true)
            ringFill.path = p
        }
        ringFill.strokeColor = (level > 0 && sinceCollect > Tuning.streakWindow - 2 && Int(clock * 6) % 2 == 0) ? UIK.red : Art.rgb(0.4, 0.8, 1)

        // slider thumb follows the beam depth
        let sh = H * 0.36
        let t = (depth(atY: beamPt.y) - dMin) / (dMax - dMin)
        sliderThumb.position = CGPoint(x: 0, y: -sh / 2 + 34 * hs + max(0, min(1, t)) * (sh - 68 * hs))

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

    func newOverlay(dim: CGFloat = 0) {
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
    func addButton(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 40, color: UIColor = UIK.orange,
                           fontSize: CGFloat = 18, enabled: Bool = true, plain: Bool = false, coin: Bool = false,
                           to parent: SKNode? = nil, action: @escaping () -> Void) -> Button {
        let b = Button(text, w: w, h: h, color: color, fontSize: fontSize, enabled: enabled, plain: plain, coin: coin, action: action)
        b.position = CGPoint(x: x, y: y)
        (parent ?? overlay).addChild(b)
        buttons.append(b)
        return b
    }

    func coinBadge() {
        let ci = UIK.coinIcon(9)
        ci.position = CGPoint(x: -W / 2 + 26, y: H / 2 - 22)
        overlay.addChild(ci)
        overlay.addChild(UIK.label(UIK.coins(store.d.coins), size: 18, color: .white, font: UIK.heavyItalic,
                                   x: -W / 2 + 40, y: H / 2 - 22, align: .left))
    }

    // MARK: - Menu

    func showMenu() {
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

        let lx = -W / 2 + max(110 * s, sideInset + 80 * s)
        store.refreshMissionsIfNeeded()
        let badge = store.unclaimedMissions > 0 ? " (\(store.unclaimedMissions))" : ""
        let items: [(String, () -> Void)] = [
            ("STORE", { [weak self] in self?.showStore(.powers) }),
            ("THEMES", { [weak self] in self?.showStore(.ufo) }),
            ("MISSIONS" + badge, { [weak self] in self?.showMissions() }),
            ("AWARDS", { [weak self] in self?.showAwards() }),
            ("FRIENDS", { [weak self] in self?.showFriends() }),
            ("OPTIONS", { [weak self] in self?.showSettings() })
        ]
        for (i, it) in items.enumerated() {
            let b = addButton(it.0, x: lx + CGFloat(i) * 5, y: H * 0.2 - CGFloat(i) * 32 * s, w: 170 * s, h: 28 * s, fontSize: 21 * s, plain: true, action: it.1)
            b.zRotation = 0.06
        }
        overlay.addChild(UIK.label(store.title.uppercased(), size: 13 * s, color: UIK.cyan, x: -W * 0.12, y: titleY - 50 * s, shadow: nil))
        if store.dailyRewardReady {
            let chest = addButton("DAILY CHEST!", x: W * 0.3, y: H * 0.3, w: 170, h: 38, color: UIK.green, fontSize: 17) { [weak self] in self?.claimDaily() }
            chest.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.45), .scale(to: 1, duration: 0.45)])))
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

    struct Card {
        var title: String
        var icon: SKNode
        var desc: String
        var price: Int?
        var buttonText: String?
        var enabled: Bool
        var status: String?
        var action: (() -> Void)?
    }

    func showStore(_ tab: StoreTab, page: Int = 0) {
        screen = .store
        storeTab = tab
        storePage = page
        newOverlay(dim: 0.3)
        let pw = min(W - 30, 720), ph = H - 40
        overlay.addChild(UIK.panel(pw, ph, y: -6))
        coinBadge()
        overlay.addChild(UIK.label("STORE", size: 22, color: UIK.cyan, y: H / 2 - 40))
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in self?.showMenu() }

        let tabs: [(String, StoreTab)] = [("THEMES", .ufo), ("WORLDS", .worlds), ("POWER-UPS", .powers), ("ITEMS", .items), ("ANIMALS", .animals)]
        let tw = (pw - 60) / 5
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

    func wrap(_ s: String, max: Int) -> [String] {
        var out: [String] = []
        var cur = ""
        for w in s.split(separator: " ") {
            if cur.count + w.count + 1 > max && !cur.isEmpty { out.append(cur); cur = "" }
            cur += (cur.isEmpty ? "" : " ") + w
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    func buy(_ cost: Int, _ then: () -> Void) {
        guard store.d.coins >= cost else { return }
        store.d.coins -= cost
        then()
        store.save()
        sound.play("coin")
        hapticLight.impactOccurred()
    }

    func storeCards(_ tab: StoreTab) -> [Card] {
        let coins = store.d.coins
        switch tab {
        case .worlds:
            return worldCards()
        case .ufo:
            return UFOTheme.all.map { (t: UFOTheme) -> Card in
                let icon = Art.ufo(theme: t)
                icon.setScale(0.55)
                if !store.ownsTheme(t.id) {
                    return Card(title: t.name.uppercased(), icon: icon, desc: "New saucer look and beam colour", price: t.price, buttonText: nil,
                                enabled: coins >= t.price, status: nil,
                                action: { [weak self] in
                                    guard let self = self else { return }
                                    self.buy(t.price) {
                                        var owned = self.store.d.themesOwned ?? []
                                        owned.append(t.id)
                                        self.store.d.themesOwned = owned
                                        self.store.d.theme = t.id
                                    }
                                    self.setUFOArt()
                                    self.showStore(.ufo, page: self.storePage)
                                })
                }
                if store.currentTheme.id == t.id {
                    return Card(title: t.name.uppercased(), icon: icon, desc: "Your saucer", price: nil, buttonText: nil,
                                enabled: true, status: "SELECTED", action: nil)
                }
                return Card(title: t.name.uppercased(), icon: icon, desc: "Owned", price: nil, buttonText: "USE",
                            enabled: true, status: nil,
                            action: { [weak self] in
                                guard let self = self else { return }
                                self.store.d.theme = t.id
                                self.store.save()
                                self.setUFOArt()
                                self.showStore(.ufo, page: self.storePage)
                            })
            }
        case .powers:
            var cards: [Card] = []
            let sel = store.d.selectedUFO
            let tier = store.d.ufoTier[sel]
            let upIcon = Art.ufo(theme: store.currentTheme)
            upIcon.setScale(0.5)
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
                icon.setScale(u.kind == .cow ? 1.0 : 1.4)
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

    func showSettings() {
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
        addButton("CINEMATIC FX: \(FX.cinematic ? "ON" : "OFF")", x: 0, y: -H * 0.13, w: 220, h: 34, color: FX.cinematic ? UIK.green : UIColor(white: 0.4, alpha: 1), fontSize: 15) { [weak self] in
            guard let self = self else { return }
            FX.cinematic.toggle()
            self.filter = FX.cinematic ? CinemaFilter() : nil
            self.shouldEnableEffects = FX.cinematic
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

    func clearEntities() {
        for n in creatures { n.removeFromParent() }
        for n in obstacles { n.removeFromParent() }
        for n in coins { n.removeFromParent() }
        for n in pickups { n.removeFromParent() }
        for n in decals { n.removeFromParent() }
        for n in hearts { n.removeFromParent() }
        hearts = []
        for n in missiles { n.removeFromParent() }
        liftLayer.removeAllChildren()
        creatures = []; obstacles = []; coins = []; pickups = []; decals = []; missiles = []; flocks = []
    }

    func resetWorld() {
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
        nextFenceX = camX - (W * 0.6) * 3.4 / P
        nextFarX = camX - 300
        nextSign = Tuning.signEvery
        pendingSigns = []
        spawnWorld(menu: true)
    }

    func startGame() {
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
        nextSpeedBanner = 1000
        moveSpeed = Tuning.startSpeed
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
        resetExtras()

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
        nextFenceX = camX - (W * 0.6) * 3.4 / P
        nextFarX = camX - 300
        spawnWorld(menu: false)

        // intro: saucer swoops in from the top-left
        status = .intro
        beamOn = false
        ufoPos = CGPoint(x: -80 * ws, y: H + 60)
        ufo.position = ufoPos
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
                self.sound.laserOpen()
                if self.tutorial { self.banner("Drag anywhere to move the beam") }
            }
        }
        updateHUD()
    }

    func pauseGame() {
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

    func finishRun(quit: Bool = false) {
        store.d.coins += runCoins
        store.d.coinsEarnedTotal = (store.d.coinsEarnedTotal ?? 0) + runCoins
        store.mission(.distance, best: distance)
        for c in creatures { c.aimLine?.removeFromParent() }
        endSearchlight()
        for f in flyers { f.removeFromParent() }
        flyers = []
        bossNode?.removeFromParent()
        bossNode = nil
        bossTank = nil
        setText(bossLabel, "")
        rainNode.particleBirthRate = 0
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
        addButton("MAIN MENU", x: 0, y: -ph * 0.06 - 88, w: 220, h: 40, fontSize: 30, plain: true) { [weak self] in self?.awardsThenMenu() }
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
            let p = t.location(in: self)
            if sliderRect.contains(p) {
                sliding = true
                slideTo(p.y)
                return
            }
            touching = true
            lastTouch = p
        }
    }

    func slideTo(_ y: CGFloat) {
        let hs = min(1.25, max(0.85, H / 390))
        let sh = H * 0.36
        let bottom = sliderRect.midY - sh / 2 + 34 * hs
        let t = max(0, min(1, (y - bottom) / (sh - 68 * hs)))
        target.y = sy(dMin + 0.02 + t * (dMax - dMin - 0.07))
        clampTarget()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard screen == .playing, let t = touches.first else { return }
        let p = t.location(in: self)
        if sliding { slideTo(p.y); return }
        guard touching else { return }
        let sense = CGFloat(store.d.touchSense) * 1.25
        target.x += (p.x - lastTouch.x) * sense
        target.y += (p.y - lastTouch.y) * sense
        lastTouch = p
        clampTarget()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false; sliding = false }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false; sliding = false }

    func clampTarget() {
        target.x = max(sideInset + W * 0.08, min(W * 0.96, target.x))
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
    func attractStep(_ dt: CGFloat) {
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

    var beamRadiusWorld: CGFloat {
        return power == .rampage ? Tuning.beamRadius * Tuning.rampageRadiusFactor : Tuning.beamRadius
    }

    var multiplier: Int {
        return Tuning.streakMult[level] + (store.upgradedMultiplier ? 1 : 0)
    }

    func step(_ dt: CGFloat) {
        elapsed += dt
        if autoplay && status == .play {
            let pool = creatures.filter { !$0.lifting && sx($0.gx, $0.gd) > W * 0.35 && sx($0.gx, $0.gd) < W * 0.95 }
            if let c = pool.min(by: { sx($0.gx, $0.gd) < sx($1.gx, $1.gd) }) {
                target.x += (sx(c.gx, c.gd) - target.x) * min(1, dt * 3)
                target.y += (sy(c.gd) - target.y) * min(1, dt * 3)
                clampTarget()
            }
        }
        switch status {
        case .intro:
            curSpeed = moveSpeed
        case .play:
            // the saucer speeds up with every point scored (smoothly, with a ceiling)
            let want = Tuning.startSpeed + Tuning.scoreSpeedMax * (1 - exp(-CGFloat(score) / Tuning.scoreSpeedScale))
            moveSpeed += (want - moveSpeed) * min(1, dt * 2)
            if score >= nextSpeedBanner {
                nextSpeedBanner += 1000
                banner("SPEED UP!")
            }
            curSpeed = moveSpeed + streakSpeed
        case .boost:
            curSpeed += (Tuning.boostSpeed - curSpeed) * min(1, dt * 3)
            if CGFloat(distance) >= boostUntil {
                status = .play
                beamOn = true
                invincible = Tuning.boostInvuln
                sound.laserOpen()
                banner("GO!")
            }
        case .dead:
            curSpeed *= max(0, 1 - dt * 2)
        }

        let wdt = dt * worldRate
        let dx = curSpeed * Tuning.unit * wdt
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

        manageStates(wdt)
        spawnWorld(menu: false)
        updateWorld(wdt, playing: true)
        drawBeam()
        checkBeamCollisions(dt)
        updateMissiles(wdt)
        extrasStep(dt)

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
    func moveUFO(_ dt: CGFloat, menu: Bool) {
        beamPt.x += (target.x - beamPt.x) * min(1, dt * 18)
        beamPt.y += (target.y - beamPt.y) * min(1, dt * 18)
        let tD = depth(atY: beamPt.y)
        ufoDepth += (tD - ufoDepth) * min(1, dt * 2.2)

        let far = (tD - dMin) / (dMax - dMin)
        let wantX = max(W * 0.2, min(W * 0.82, beamPt.x + W * 0.03))
        let wantY = H * (0.55 + 0.12 * far)
        let oldX = ufoPos.x
        let k = min(1, dt * (status == .intro && !menu ? 2.2 : 3.2))
        ufoPos.x += (wantX - ufoPos.x) * k
        ufoPos.y += (wantY - ufoPos.y) * k
        ufoVel = (ufoPos.x - oldX) / max(dt, 0.001)
        ufo.position = CGPoint(x: ufoPos.x, y: ufoPos.y + sin(clock * 2.6) * 4 * ws)
        let lean = max(-0.32, min(0.32, -ufoVel / (W * 2.2) - (beamPt.x - ufoPos.x) / W * 0.35))
        ufoArt.zRotation += (lean - ufoArt.zRotation) * min(1, dt * 6)
    }

    var ufoBottom: CGPoint {
        return CGPoint(x: ufo.position.x + sin(-ufoArt.zRotation) * 25 * ufoScale, y: ufo.position.y - 25 * ufoScale)
    }

    var beamVisible: Bool {
        if screen == .playing || screen == .paused { return beamOn && status == .play }
        return beamOn
    }

    func drawBeam() {
        if !beamVisible {
            for n in [beamSprite, beamInner, landing, landing2] { n.isHidden = true }
            beamDust.particleBirthRate = 0
            drawTwin(base: .white)
            beamGlow.path = nil
            beamCore.path = nil
            beamRing.path = nil
            crosshair.isHidden = true
            for s in sparkles { s.0.isHidden = true }
            return
        }
        let T = beamPt
        let U = ufoBottom
        let tD = depth(atY: T.y)
        let r = beamRadiusWorld * sc(tD)
        let base: UIColor
        if damageTimer > 0 {
            base = Art.rgb(1, 0.25, 0.3)
        } else if power == .rampage {
            base = Art.rgb(1, 0.55, 0.2)
        } else if power == .magnet {
            base = Art.rgb(0.4, 0.75, 1)
        } else {
            let th = store.currentTheme
            base = th.extra == .rainbow ? UIColor(hue: (clock * 0.15).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 1, alpha: 1) : th.neon.darker(1.05)
        }
        let dx = T.x - U.x, dy = T.y - U.y
        let len = max(4, hypot(dx, dy))
        let ang = atan2(dx, -dy)
        let pulse = 0.06 * sin(clock * 10)
        for (b, wf) in [(beamSprite, CGFloat(2.4)), (beamInner, CGFloat(1.2))] {
            b.isHidden = false
            b.position = U
            b.size = CGSize(width: r * wf, height: len)
            b.zRotation = ang
            b.color = base
        }
        beamSprite.alpha = 0.8 + pulse
        beamInner.alpha = 0.75 + pulse
        beamInner.color = base.darker(1.5)
        landing.isHidden = false
        landing.position = T
        landing.size = CGSize(width: r * 3.4, height: r * 1.35)
        landing.color = base
        landing.alpha = 0.9
        landing2.isHidden = false
        landing2.position = T
        let k = 1 + 0.08 * sin(clock * 6)
        landing2.size = CGSize(width: r * 2.1 * k, height: r * 0.85 * k)
        landing2.color = base.darker(1.6)
        landing2.alpha = 0.85
        beamGlow.path = nil
        beamCore.path = nil
        beamRing.path = nil
        crosshair.isHidden = true

        beamDust.particleBirthRate = 110
        beamDust.position = T
        beamDust.emissionAngle = atan2(U.y - T.y, U.x - T.x)
        beamDust.particleSpeed = len / 0.9
        beamDust.particleSpeedRange = len * 0.3
        beamDust.particlePositionRange = CGVector(dx: r * 1.4, dy: r * 0.4)
        beamDust.particleColor = base.darker(1.5)
        beamColorNow = base
        drawTwin(base: base)

        for i in 0..<sparkles.count {
            var sp = sparkles[i]
            sp.1 += 0.012 + CGFloat(i % 4) * 0.003
            if sp.1 > 1 { sp.1 = 0; sp.2 = CGFloat.random(in: -1...1) }
            let t = sp.1
            let w = r * 0.9 * (1 - t) + 8 * ws * t
            sp.0.isHidden = false
            sp.0.position = CGPoint(x: T.x + (U.x - T.x) * t + sp.2 * w, y: T.y + (U.y - T.y) * t)
            sp.0.alpha = sin(t * .pi) * 0.9
            sp.0.color = base.darker(1.6)
            sp.0.colorBlendFactor = 0.6
            sparkles[i] = sp
        }
    }

    // MARK: - Difficulty (GroundManager state cycle)

    func manageStates(_ dt: CGFloat) {
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

    var tutorialActive: Bool { return tutorial && elapsed < 14 }

    func spawnVehicle(forced: ObKind? = nil) {
        var pool: [ObKind] = [.car, .car, .car, .truck]
        if distance >= Tuning.fireTruckFrom { pool.append(.fireTruck) }
        if distance >= Tuning.policeFrom { pool += [.police, .police] }
        if distance >= Tuning.jeepFrom { pool += [.jeep, .jeep] }
        if biome == .city { pool += [.car, .car, .police, .fireTruck] }
        if biome == .desert { pool = [.jeep, .jeep, .truck, .truck, .car] }
        let k = forced ?? (pool.randomElement() ?? .car)
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

    var spawnEdge: CGFloat { return camX + (W * 0.5 + 60) * dMax / P }

    func spawnWorld(menu: Bool) {
        let limit = spawnEdge

        // grass, flowers, puddles and dirt patches for a sense of motion
        while nextTuftX < limit {
            let dec = Decal()
            dec.gx = nextTuftX + CGFloat.random(in: 0...30)
            dec.gd = CGFloat.random(in: dMin...(dMax + 0.15))
            let roll = Int.random(in: 0..<100)
            if roll < 7 && biome != .desert {
                dec.addChild(SKSpriteNode(texture: Painter.puddle(), size: CGSize(width: 100, height: 100)))
                let refl = SKSpriteNode(texture: Painter.puddle(), size: CGSize(width: 100, height: 100))
                refl.name = "refl"
                refl.blendMode = .add
                refl.colorBlendFactor = 1
                refl.alpha = 0.15
                dec.addChild(refl)
                let glint = SKSpriteNode(texture: Art.softDot(), size: CGSize(width: 60, height: 14))
                glint.name = "glint"
                glint.blendMode = .add
                glint.alpha = 0.3
                glint.position = CGPoint(x: -8, y: 6)
                dec.addChild(glint)
                dec.name = "puddle"
                dec.flat = true
                dec.worldW = CGFloat.random(in: 50...120)
                dec.worldD = CGFloat.random(in: 0.04...0.09)
            } else if roll < 20 {
                dec.addChild(SKSpriteNode(texture: Painter.dirt(), size: CGSize(width: 100, height: 100)))
                dec.flat = true
                dec.worldW = CGFloat.random(in: 50...140)
                dec.worldD = CGFloat.random(in: 0.04...0.12)
            } else if roll < 22 && dec.gd < 1.5 {
                let rk = SKSpriteNode(texture: Painter.rock(), size: CGSize(width: 80, height: 50))
                rk.anchorPoint = CGPoint(x: 0.5, y: 0.05)
                rk.setScale(CGFloat.random(in: 0.5...1.0))
                dec.addChild(rk)
            } else {
                dec.addChild(biomeDecor())
            }
            world.addChild(dec)
            decals.append(dec)
            nextTuftX += CGFloat.random(in: 14...32)
        }
        // continuous fences: one along the far edge of the field, one in the foreground
        while nextFenceX < limit {
            for d in [CGFloat(1.02), CGFloat(3.25)] where biome == .farm {
                let f = Decal()
                let sp = SKSpriteNode(texture: Painter.fence(), size: CGSize(width: 96, height: 36))
                sp.anchorPoint = CGPoint(x: 0.5, y: 0.1)
                f.addChild(sp)
                f.gx = nextFenceX
                f.gd = d
                world.addChild(f)
                decals.append(f)
            }
            nextFenceX += 92
        }
        // farm buildings on the horizon (scenery only)
        while nextFarX < limit {
            let kinds: [ObKind]
            switch biome {
            case .farm: kinds = [.house, .windmill, .silo, .barn, .windmill]
            case .city: kinds = [.building, .building, .lamp]
            case .desert: kinds = [.palm, .tent, .palm]
            }
            let k = kinds.randomElement() ?? .house
            let f = Decal()
            f.addChild(Art.obstacle(k))
            f.gx = nextFarX
            f.gd = 3.4
            world.addChild(f)
            decals.append(f)
            if biome == .farm && (k == .silo || k == .windmill) && Bool.random() {
                let g = Decal()
                g.addChild(Art.obstacle(k == .silo ? .windmill : .silo))
                g.gx = nextFarX + 70
                g.gd = 3.38
                world.addChild(g)
                decals.append(g)
            }
            nextFarX += biome == .city ? CGFloat.random(in: 200...420) : CGFloat.random(in: 900...1700)
        }

        while nextGroupX < limit {
            spawnGroup(at: nextGroupX)
            let busy = min(1, CGFloat(distance) / 3000)
            nextGroupX += CGFloat.random(in: 250...400) * (1 - busy * 0.2)
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

    func addSign(_ lines: [String], x: CGFloat, d: CGFloat, wide: Bool = false) {
        let dec = Decal()
        dec.addChild(Art.sign(lines, wide: wide || lines.count > 1))
        dec.gx = x
        dec.gd = d
        world.addChild(dec)
        decals.append(dec)
    }

    func pick(_ k: Kind) -> Int? {
        let v = store.unlockedVariants(k)
        guard !v.isEmpty else { return nil }
        // rarer variants appear less often
        if v.count > 1 && Int.random(in: 0..<100) < 30 {
            return v.filter { $0 != 0 }.randomElement() ?? v[0]
        }
        return v.contains(0) ? 0 : v[0]
    }

    func spawnGroup(at x: CGFloat) {
        if biome == .city { spawnCityGroup(at: x); return }
        if biome == .desert { spawnDesertGroup(at: x); return }
        let roll = Int.random(in: 0..<100)
        let d = CGFloat.random(in: (dMin + 0.1)...(dMax - 0.2))
        if screen == .playing && distance > 300 && Int.random(in: 0..<100) < 3 {
            spawnRareSheep(at: x, d: d)
            return
        }
        if screen == .playing && distance > 600 && Int.random(in: 0..<100) < 4 {
            spawnCreature(.hunter, variant: 0, x: x, d: d)
            return
        }
        if roll < 38 {
            // a flock of sheep (Boids) — sometimes with a herding dog
            let flock = Flock(x: x, d: d)
            flocks.append(flock)
            let n = Int.random(in: 2...5)
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
                if screen == .playing && distance > 800 && Int.random(in: 0..<100) < 5 {
                    spawnNukeCow(at: x + CGFloat(i) * 60, d: d + CGFloat(i) * 0.15)
                } else if let v = pick(.cow) { spawnCreature(.cow, variant: v, x: x + CGFloat(i) * 60, d: d + CGFloat(i) * 0.15) }
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

    func spawnStaticCluster(at x: CGFloat) {
        if tutorialActive { return }
        if biome == .farm && distance > 400 && Int.random(in: 0..<100) < 14 {
            var d = CGFloat.random(in: (dMin + 0.15)...(dMax - 0.1))
            if abs(d - roadD(x)) < 0.2 { d = max(dMin + 0.1, d - 0.3) }
            spawnPowerline(at: x, d: d)
            return
        }
        if let bk = biomeObstacle() {
            var d = CGFloat.random(in: (dMin + 0.1)...(dMax - 0.05))
            if abs(d - roadD(x)) < 0.22 { d = roadD(x) + (d < roadD(x) ? -0.3 : 0.3) }
            d = max(dMin + 0.08, min(dMax, d))
            spawnObstacle(bk, x: x, d: d)
            return
        }
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

    func spawnCoinPattern(at x: CGFloat) {
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
    func spawnCreature(_ kind: Kind, variant: Int, x: CGFloat, d: CGFloat) -> Creature {
        let c = Creature(kind: kind, variant: variant, body: Art.creature(kind, variant: variant))
        c.gx = x
        c.gd = max(dMin + 0.02, min(dMax - 0.05, d))
        c.vx = Bool.random() ? c.walkSpeed : -c.walkSpeed
        c.legsNode = c.body.childNode(withName: ".//legs")
        c.forkNode = c.body.childNode(withName: ".//fork")
        c.flashNode = c.body.childNode(withName: ".//flash")
        world.addChild(c)
        creatures.append(c)
        return c
    }

    @discardableResult
    func spawnObstacle(_ kind: ObKind, x: CGFloat, d: CGFloat) -> Obstacle {
        let o = Obstacle(kind: kind)
        o.addChild(Art.obstacle(kind))
        o.gx = x
        o.gd = d
        world.addChild(o)
        obstacles.append(o)
        return o
    }

    // MARK: - World update (AI + projection)

    func project(_ n: GroundThing) {
        n.position = CGPoint(x: sx(n.gx, n.gd), y: sy(n.gd))
        n.setScale(sc(n.gd))
        n.zPosition = 400 - n.gd * 100
    }

    func updateWorld(_ dt: CGFloat, playing: Bool) {
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
            x += 45
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

    func groundDist(_ x: CGFloat, _ d: CGFloat, toScreen T: CGPoint) -> CGFloat {
        // ellipse test in screen space around the beam point
        let r = beamRadiusWorld * sc(depth(atY: T.y))
        let dx = (sx(x, d) - T.x) / r
        let dy = (sy(d) - T.y) / (r * 0.5)
        return hypot(dx, dy)
    }

    var beamActive: Bool {
        if screen == .playing { return beamOn && status == .play }
        return beamOn
    }

    func updateCreatures(_ dt: CGFloat) {
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
            var scared = false
            // flee from the beam (calculateDirectionToBeam)
            if beamActive && c.kind.flees {
                let fx = c.gx - tX, fd = (c.gd - tD) * 250
                let dist = hypot(fx, fd)
                if dist < beamRadiusWorld * 3.2 && dist > 0.1 {
                    let sp = c.walkSpeed * 1.35
                    c.vx = fx / dist * sp
                    c.vd = fd / dist * sp / 250
                    moving = true
                    scared = true
                    if c.kind == .grumpa && !c.spoke && Int.random(in: 0..<90) == 0 {
                        c.spoke = true
                        if screen == .playing { sound.grumpa() }
                    }
                }
            }
            c.gx += c.vx * dt
            c.gd = max(dMin + 0.02, min(dMax - 0.04, c.gd + c.vd * dt))
            if abs(c.vx) > 1 { c.facing = c.vx > 0 ? 1 : -1 }

            // walk cycle with squash & stretch; scared ones hop, idle animals graze and breathe
            let phase = clock * (scared ? 22 : 14) + c.wob
            let bob = moving ? abs(sin(phase)) : 0
            c.legsNode?.position.y = bob * 1.6
            let squash = moving ? sin(phase * 2) * (scared ? 0.09 : 0.05) : sin(clock * 2.2 + c.wob) * 0.02
            c.body.xScale = c.facing * (1 - squash * 0.5)
            c.body.yScale = 1 + squash
            c.body.position.y = c.kind == .dog ? bob * 4 : bob * (scared ? 4 : 1.2)
            if !moving && (c.kind == .sheep || c.kind == .cow || c.kind == .pig || c.kind == .camel) {
                c.body.zRotation = -c.facing * 0.05 * (1 + sin(clock * 0.9 + c.wob))
            } else {
                c.body.zRotation = scared ? sin(phase) * 0.07 : 0
            }
            if scared && !c.noticed && screen == .playing {
                c.noticed = true
                let ex = SKLabelNode(fontNamed: UIK.heavyItalic)
                ex.text = "!"
                ex.fontSize = 22
                ex.fontColor = UIK.yellow
                ex.position = CGPoint(x: 0, y: c.kind == .cow || c.kind == .camel ? 70 : 52)
                ex.setScale(0.2)
                c.addChild(ex)
                ex.run(.sequence([.scale(to: 1.1, duration: 0.12), .scale(to: 1, duration: 0.08), .wait(forDuration: 0.5), .fadeOut(withDuration: 0.25), .removeFromParent()]))
            }
            if c.kind == .grumpa, let fork = c.forkNode {
                fork.zRotation = sin(clock * (moving ? 10 : 3) + c.wob) * 0.25
            }
            if c.kind == .reporter {
                c.flashTimer -= dt
                if c.flashTimer <= 0, let fl = c.flashNode {
                    c.flashTimer = CGFloat.random(in: 1.5...3.5)
                    let glow = Art.circ(7, UIColor(white: 1, alpha: 0.95))
                    glow.position = fl.position
                    fl.parent?.addChild(glow)
                    glow.run(.sequence([.group([.scale(to: 3, duration: 0.15), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
                }
            }
            if c.kind == .hunter { updateHunter(c, dt) }
            project(c)

            // the beam grabs anything inside its circle
            let hitBeam = beamActive ? beamHit(c.gx, c.gd, 1) : 0
            if hitBeam > 0 {
                c.onTwin = hitBeam == 2
                startLift(c)
                registerGrab(c)
                if screen == .playing {
                    sound.laserGrab()
                    switch c.kind {
                    case .sheep: sound.creature(.sheep)
                    case .cow: sound.creature(.cow)
                    case .pig: sound.creature(.pig)
                    case .dog: sound.creature(.dog)
                    default: sound.creature(.oldMan)
                    }
                }
            }
        }
    }

    func startLift(_ n: GroundThing) {
        n.lifting = true
        n.liftT = 0
        n.liftScale = sc(n.gd)
        let base = n.onTwin ? twinPt : beamPt
        n.liftOffset = CGPoint(x: n.position.x - base.x, y: n.position.y - base.y)
        n.removeFromParent()
        liftLayer.addChild(n)
        n.zPosition = 0
    }

    /// Lifted things ride up the beam to the saucer, spinning and shrinking.
    func updateLifting(_ dt: CGFloat) {
        let T0 = beamPt
        let T1 = twinPt
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
            let T = n.onTwin && power == .twin ? T1 : T0
            let e = pow(t, 1.5)
            let swirl = sin(clock * 9 + n.spin * 4) * 10 * ws * (1 - t)
            n.position = CGPoint(x: T.x + (U.x - T.x) * e + n.liftOffset.x * (1 - t) + swirl,
                                 y: T.y + (U.y - T.y) * e + n.liftOffset.y * (1 - t) + sin(t * .pi) * 6 * ws)
            n.setScale(n.liftScale * (1 - 0.55 * t))
            if n is Creature { n.zRotation += (2 + abs(n.spin) * 3) * dt * (n.spin >= 0 ? 1 : -1) }
            if let c = n as? Creature {
                let f = sin(clock * 26 + c.wob)
                c.body.yScale = 1 + f * 0.08
                c.body.xScale = c.facing * (1 - f * 0.05)
            }
            if let c = n as? Creature, let legs = c.legsNode {
                legs.position.y = abs(sin(clock * 24 + c.wob)) * 2.5   // kicking legs
            }
            if t >= 1 { done.append(n) }
        }
        for n in done { collect(n) }
    }

    func collect(_ n: GroundThing) {
        n.removeFromParent()
        let U = ufoBottom
        if let c = n as? Creature {
            creatures.removeAll { $0 === c }
            guard screen == .playing else { return }
            let pts = c.value * multiplier * (power == .multiply ? 2 : 1)
            score += pts
            abducted += 1
            bumpStreak()
            scorePopup(pts, at: CGPoint(x: U.x + 18 * ws, y: U.y - 6 * ws))
            onCollected(c)
            sound.play("collect", volume: 0.6, minGap: 0.08)
            if clock - lastHaptic > 0.08 { lastHaptic = clock; hapticLight.impactOccurred() }
        } else if let c = n as? Coin {
            coins.removeAll { $0 === c }
            guard screen == .playing else { return }
            runCoins += 1
            score += multiplier
            missionDone(store.mission(.coins, add: 1))
            bumpStreak()
            sound.play("coin", volume: 0.55, minGap: 0.05)
        } else if let h = n as? HeartPickup {
            hearts.removeAll { $0 === h }
            guard screen == .playing else { return }
            health = maxHealth
            invincible = max(invincible, 1)
            banner("FULL HEALTH!")
            sound.play("powerup")
            sound.play("chest", volume: 0.6)
            hapticMedium.impactOccurred()
        } else if let p = n as? Pickup {
            pickups.removeAll { $0 === p }
            guard screen == .playing else { return }
            let lvl = store.d.powerLevel[p.type.rawValue]
            if lvl > 0 {
                power = p.type
                powerTimer = p.type.durations[lvl - 1]
                store.d.powerupsCollected += 1
                missionDone(store.mission(.powerups, add: 1))
                banner(p.type.title.uppercased() + "!")
                sound.play("powerup")
            }
        }
    }

    func bumpStreak() {
        sinceCollect = 0
        collectedStreak += 1
        while level + 1 < Tuning.streakCounts.count && collectedStreak >= Tuning.streakCounts[level + 1] {
            level += 1
            streakSpeed = Tuning.streakSpeed[level]
            banner("\(multiplier)X!")
            sound.play("levelup")
        }
    }

    func dropLevel() {
        guard level > 0 else { return }
        level -= 1
        collectedStreak = Tuning.streakCounts[level]
        streakSpeed = Tuning.streakSpeed[level]
    }

    func updateCoins(_ dt: CGFloat) {
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
            let hb = beamActive && screen == .playing ? beamHit(c.gx, c.gd, 1.15) : 0
            if hb > 0 {
                c.onTwin = hb == 2
                startLift(c)
            }
        }
    }

    func updatePickups(_ dt: CGFloat) {
        let T = beamPt
        for p in pickups where !p.lifting {
            project(p)
            let hb = beamActive && screen == .playing ? beamHit(p.gx, p.gd, 1.2) : 0
            if hb > 0 {
                p.onTwin = hb == 2
                sound.laserGrab()
                startLift(p)
            }
        }
    }

    func updateObstacles(_ dt: CGFloat, playing: Bool) {
        let U = ufoBottom
        for o in obstacles where !o.dead {
            if o.hitCooldown > 0 { o.hitCooldown -= dt }
            if o.kind.isVehicle && o.vx != 0 {
                o.gx += o.vx * dt
                o.gd = roadD(o.gx) + o.lane
            }
            project(o)
            if o.giant { o.setScale(o.xScale * 2.2) }
            if o.kind == .powerline && o.span > 0 { updateWire(o) }
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
                if let barrel = o.childNode(withName: ".//barrel") {
                    let dx = U.x - o.position.x, dy = U.y - o.position.y
                    barrel.zRotation = max(0.2, min(2.9, atan2(dy, dx * flip)))
                }
                if o.position.x > 0 && o.position.x < W {
                    o.fireTimer -= dt
                    if o.fireTimer <= 0 && (o.giant || (shotCooldown <= 0 && aimingHunter == nil)) {
                        o.fireTimer = o.giant ? CGFloat.random(in: 2.2...3.0) : CGFloat.random(in: 3...4.5)
                        if !o.giant { shotCooldown = CGFloat.random(in: 5...7) }
                        fireMissile(from: o)
                    }
                }
            }
        }
    }

    /// The beam line hurts when it passes through an obstacle at the same depth.
    func checkBeamCollisions(_ dt: CGFloat) {
        guard beamActive, status == .play else { return }
        let T = beamPt
        let U = ufoBottom
        let tD = depth(atY: T.y)
        let r = beamRadiusWorld * sc(tD)
        for o in obstacles where !o.dead && o.hitCooldown <= 0 {
            if o.kind == .powerline && o.span > 0 && beamCrossesWire(o, U: U, T: T, tD: tD) {
                if invincible <= 0 && damageTimer <= 0 {
                    o.hitCooldown = 1.5
                    takeDamage(1, byVehicle: false)
                    if let e = wireEnds(o) { sparksAt(CGPoint(x: (e.0.x + e.1.x) / 2, y: (e.0.y + e.1.y) / 2)) }
                    sound.play("hit", volume: 0.6)
                }
                continue
            }
            let s = sc(o.gd) * (o.giant ? 2.2 : 1)
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

    func smash(_ o: Obstacle) {
        o.dead = true
        if screen == .playing { missionDone(store.mission(.smash, add: 1)) }
        o.wire?.removeFromParent()
        o.wire = nil
        o.span = 0
        explode(o)
        let pts = 50 * multiplier
        score += pts
        popup("SMASH +\(pts)", at: CGPoint(x: o.position.x, y: o.position.y + 40 * ws), color: Art.rgb(1, 0.6, 0.2))
        if o.kind.isVehicle { store.d.vehiclesDestroyed += 1 }
        if o.kind == .tank { store.d.tanksDestroyed += 1 }
        sound.play("explode", volume: 0.8)
        hapticHeavy.impactOccurred()
    }

    func explode(_ o: Obstacle) {
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

    func boom(at p: CGPoint, size: CGFloat) {
        let c = Art.circ(max(8, size), UIColor.orange.withAlphaComponent(0.9), p.x, p.y)
        c.zPosition = 20
        fx.addChild(c)
        c.run(.sequence([.group([.scale(to: 3, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        let c2 = Art.circ(max(6, size * 0.6), UIColor.yellow.withAlphaComponent(0.9), p.x, p.y)
        c2.zPosition = 21
        fx.addChild(c2)
        c2.run(.sequence([.group([.scale(to: 2.2, duration: 0.2), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
    }

    func sparksAt(_ p: CGPoint) {
        for _ in 0..<8 {
            let s = Art.circ(2 * ws, Art.rgb(1, 0.85, 0.4), p.x, p.y)
            s.zPosition = 22
            fx.addChild(s)
            let a = CGFloat.random(in: 0...(2 * .pi))
            s.run(.sequence([.group([.moveBy(x: cos(a) * 30 * ws, y: sin(a) * 30 * ws, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        }
    }

    // MARK: - Missiles (tanks)

    func fireMissile(from o: Obstacle) {
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

    func updateMissiles(_ dt: CGFloat) {
        var dead: [Missile] = []
        for m in missiles {
            m.position.x += m.v.dx * dt
            m.position.y += m.v.dy * dt
            m.life -= dt
            if m.life <= 0 || m.position.y > H + 40 { dead.append(m); continue }
            if status != .dead && hypot(m.position.x - ufo.position.x, m.position.y - ufo.position.y) < max(32 * ws, 60 * ufoScale) {
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

    func takeDamage(_ amount: Int, byVehicle: Bool) {
        guard status == .play || status == .boost else { return }
        if invincible > 0 || damageTimer > 0 { return }
        if power == .shield {
            power = nil
            powerTimer = 0
            invincible = 1.2
            sound.play("powerup", volume: 0.6)
            popup("SHIELD!", at: CGPoint(x: ufo.position.x, y: ufo.position.y + 40 * ws), color: Art.rgb(0.5, 0.85, 1))
            return
        }
        lastHitDistance = distance
        health -= 1   // any hit costs exactly one bar
        if tutorialActive { health = max(1, health) }
        damageTimer = Tuning.damageTime
        hapticHeavy.impactOccurred()
        sound.play("hit")
        redFlash.removeAllActions()
        redFlash.alpha = 0.85
        redFlash.run(.fadeOut(withDuration: 0.45))
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

    func shake() {
        let a: CGFloat = 6 * ws
        world.run(.sequence([.moveBy(x: a, y: a * 0.5, duration: 0.03), .moveBy(x: -2 * a, y: -a, duration: 0.05),
                             .moveBy(x: a, y: a * 0.5, duration: 0.03)]))
    }

    func die() {
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

    func stepDeath(_ dt: CGFloat) {
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

    func offLeft(_ n: GroundThing) -> Bool {
        return sx(n.gx, n.gd) < -150 * ws
    }

    func cleanup() {
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
            if x < -150 * ws && !(o.kind == .powerline && o.span > 0 && (o.pole2.map { sx(($0 as? Obstacle)?.gx ?? 0, o.gd) > -150 * ws } ?? false)) {
                o.wire?.removeFromParent()
                o.removeFromParent()
                return true
            }
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

    var lastHaptic: CGFloat = 0
    var ringFrac: CGFloat = -1
    var shownHealth = -1
    var shownMax = -1
    var comboLabel: SKLabelNode?
    var comboValue = 0
    var comboTime: CGFloat = -10

    /// Points from creatures arriving close together are added into one "+N" label
    /// instead of making a new label for each sheep (that caused stutters with big flocks).
    func scorePopup(_ pts: Int, at p: CGPoint) {
        if let l = comboLabel, l.parent != nil, clock - comboTime < 0.35 {
            comboValue += pts
            comboTime = clock
            setText(l, "+\(comboValue)")
            l.removeAllActions()
            l.alpha = 1
            l.setScale(1.15)
            l.run(.sequence([.scale(to: 1, duration: 0.1),
                             .group([.moveBy(x: 10, y: 34 * ws, duration: 0.7), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)])]),
                             .removeFromParent()]))
            return
        }
        comboValue = pts
        comboTime = clock
        let l = UIK.label("+\(pts)", size: 18 * ws, color: UIK.cyan, font: UIK.heavyItalic, x: p.x, y: p.y, shadow: Art.rgb(0.05, 0.1, 0.25, 0.8))
        l.zPosition = 800
        addChild(l)
        comboLabel = l
        l.run(.sequence([.group([.moveBy(x: 10, y: 34 * ws, duration: 0.7), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
    }

    func popup(_ text: String, at p: CGPoint, color: UIColor) {
        let l = UIK.label(text, size: 18 * ws, color: color, font: UIK.heavyItalic, x: p.x, y: p.y, shadow: Art.rgb(0.05, 0.1, 0.25, 0.8))
        l.zPosition = 800
        addChild(l)
        l.run(.sequence([.group([.moveBy(x: 10, y: 34 * ws, duration: 0.7), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
    }

    func banner(_ text: String) {
        let l = UIK.label(text, size: 30, color: UIK.orange, y: H * 0.1, shadow: UIK.orangeDark)
        l.zPosition = 50
        l.setScale(0.4)
        ui.addChild(l)
        l.run(.sequence([.scale(to: 1, duration: 0.15), .wait(forDuration: 0.9), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
}
