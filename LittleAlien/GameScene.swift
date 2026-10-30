import SpriteKit
import UIKit

final class GameScene: SKScene {
    enum Screen { case menu, shop, hangar, settings, playing, paused, over }
    /// Mirrors ufoStatus from the original design: 0 intro, 1 play, 2 boost, 3 dead.
    enum UFOStatus { case intro, play, boost, dead }

    private struct Layer {
        var nodes: [SKNode]
        var period: CGFloat
        var factor: CGFloat
    }

    private let store = Store.shared

    // Layout
    private var W: CGFloat = 0
    private var H: CGFloat = 0
    private var ws: CGFloat = 1           // world scale for small screens
    private var groundY: CGFloat = 0      // where creatures stand
    private var roadY: CGFloat = 0        // where vehicles drive
    private var ufoY: CGFloat = 0

    // Nodes
    private let cam = SKCameraNode()
    private let ufo = SKNode()
    private var ufoArt = SKNode()
    private let beam = SKShapeNode()
    private let beamRing = SKShapeNode()
    private var layers: [Layer] = []
    private var overlay = SKNode()
    private var buttons: [Button] = []
    private let hud = SKNode()

    // HUD
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let distLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let multLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let goalLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let heartsLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let coinLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let powerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let barBack = SKShapeNode()
    private let barFill = SKShapeNode()
    private var pauseButton: Button?

    // Run state
    private var screen: Screen = .menu
    private var status: UFOStatus = .intro
    private var runCfg = RunConfig()
    private var lastTime: TimeInterval = 0
    private var clock: CGFloat = 0
    private var elapsed: CGFloat = 0
    private var overTimer: CGFloat = 0

    private var touching = false
    private var lastTouch: CGPoint = .zero
    private var beamOffset: CGFloat = 90      // beam target relative to the UFO
    private var beamX: CGFloat = 0
    private var ufoOffset: CGFloat = 0        // translation align toward the beam
    private var beamWeight: CGFloat = 0

    private var moveSpeed: CGFloat = Tuning.startSpeed
    private var streakSpeed: CGFloat = 0
    private var startX: CGFloat = 0
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

    // Death
    private var deathV = CGVector.zero
    private var bouncesLeft = 0

    // World difficulty (GroundManager)
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
    private var missiles: [Missile] = []
    private var flocks: [Flock] = []
    private var decor: [SKNode] = []

    private var nextGroupX: CGFloat = 0
    private var nextStaticX: CGFloat = 0
    private var nextCoinX: CGFloat = 0
    private var nextPickupX: CGFloat = 0
    private var nextDecorX: CGFloat = 0
    private var nextCloudX: CGFloat = 0
    private var nextSign = Tuning.signEvery
    private var nextBirdX: CGFloat = 0

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
        cam.removeAllChildren()
        ufo.removeAllChildren()
        hud.removeAllChildren()
        creatures = []; obstacles = []; coins = []; pickups = []; missiles = []; flocks = []; decor = []
        layers = []

        W = size.width
        H = size.height
        ws = max(0.85, min(1.5, H / 390))
        groundY = H * 0.2
        roadY = H * 0.09
        ufoY = H * 0.72
        backgroundColor = UIColor(red: 0.07, green: 0.05, blue: 0.2, alpha: 1)

        addChild(cam)
        camera = cam
        buildBackground()

        ufo.zPosition = 50
        addChild(ufo)
        setUFOArt()

        beam.zPosition = 40
        beam.lineWidth = 0
        beam.strokeColor = .clear
        addChild(beam)
        beamRing.zPosition = 41
        beamRing.lineWidth = 2
        addChild(beamRing)

        hud.zPosition = 1000
        cam.addChild(hud)
        buildHUD()

        showMenu()
    }

    private func setUFOArt() {
        ufoArt.removeFromParent()
        ufoArt = Art.ufo(store.d.selectedUFO)
        ufoArt.setScale(ws)
        ufo.addChild(ufoArt)
    }

    private func buildBackground() {
        let sky = SKSpriteNode(texture: Art.gradient(size: CGSize(width: 8, height: 256),
                                                      top: Art.rgb(0.25, 0.55, 0.9),
                                                      bottom: Art.rgb(0.75, 0.9, 1)))
        sky.size = CGSize(width: W + 4, height: H + 4)
        sky.zPosition = -100
        cam.addChild(sky)

        let sun = Art.circ(26 * ws, Art.rgb(1, 0.95, 0.6), W * 0.32, H * 0.3)
        sun.zPosition = -98
        cam.addChild(sun)

        let horizon = groundY - H / 2
        layers.append(makeLayer(period: 300, factor: 0.1, color: Art.rgb(0.55, 0.7, 0.85), z: -90, baseY: horizon + 10, hMin: 90, hMax: 150))
        layers.append(makeLayer(period: 200, factor: 0.25, color: Art.rgb(0.4, 0.68, 0.4), z: -80, baseY: horizon, hMin: 50, hMax: 90))

        let field = Art.rect(W + 4, groundY + 4, Art.rgb(0.42, 0.72, 0.3), 0, -H / 2 + groundY / 2 - 2)
        field.zPosition = -20
        cam.addChild(field)
        let road = Art.rect(W + 4, H * 0.1, UIColor(white: 0.32, alpha: 1), 0, -H / 2 + roadY + H * 0.01)
        road.zPosition = -19
        cam.addChild(road)
        var dashes: [SKNode] = []
        let dashCount = Int(ceil(W / 90)) + 3
        for _ in 0..<dashCount {
            let d = Art.rect(34, 3, UIColor(white: 0.9, alpha: 1), 0, -H / 2 + roadY + H * 0.01)
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
            let h = CGFloat.random(in: hMin...hMax) * ws
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
        for l in [scoreLabel, distLabel, multLabel, goalLabel, heartsLabel, coinLabel, powerLabel] {
            hud.addChild(l)
            l.verticalAlignmentMode = .center
        }
        let left = -W / 2 + 56
        scoreLabel.fontSize = 26
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: left, y: top - 28)

        distLabel.fontSize = 15
        distLabel.fontColor = UIColor(white: 1, alpha: 0.9)
        distLabel.horizontalAlignmentMode = .left
        distLabel.position = CGPoint(x: left, y: top - 54)

        multLabel.fontSize = 26
        multLabel.fontColor = UIK.yellow
        multLabel.position = CGPoint(x: 0, y: top - 26)

        goalLabel.fontSize = 12
        goalLabel.fontColor = UIColor(white: 1, alpha: 0.85)
        goalLabel.position = CGPoint(x: 0, y: top - 62)

        heartsLabel.fontSize = 24
        heartsLabel.fontColor = UIColor(red: 1, green: 0.3, blue: 0.4, alpha: 1)
        heartsLabel.horizontalAlignmentMode = .right
        heartsLabel.position = CGPoint(x: W / 2 - 110, y: top - 28)

        coinLabel.fontSize = 16
        coinLabel.fontColor = UIK.yellow
        coinLabel.horizontalAlignmentMode = .right
        coinLabel.position = CGPoint(x: W / 2 - 110, y: top - 54)

        powerLabel.fontSize = 15
        powerLabel.position = CGPoint(x: 0, y: top - 82)

        barBack.position = CGPoint(x: -60, y: top - 48)
        barFill.position = barBack.position
        barBack.strokeColor = .clear
        barFill.strokeColor = .clear
        barBack.fillColor = UIColor(white: 0, alpha: 0.3)
        barFill.fillColor = UIK.yellow
        hud.addChild(barBack)
        hud.addChild(barFill)

        let pb = Button("II", w: 44, h: 40, color: UIColor(white: 0, alpha: 0.35), fontSize: 18) { [weak self] in
            self?.pauseGame()
        }
        pb.position = CGPoint(x: W / 2 - 60, y: top - 34)
        hud.addChild(pb)
        pauseButton = pb
        hud.isHidden = true
    }

    // MARK: - Overlay helpers

    private func newOverlay(dim: CGFloat = 0) {
        overlay.removeFromParent()
        overlay = SKNode()
        overlay.zPosition = 2000
        cam.addChild(overlay)
        buttons = []
        if dim > 0 {
            overlay.addChild(Art.rect(W + 4, H + 4, UIColor(white: 0, alpha: dim)))
        }
    }

    @discardableResult
    private func addButton(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 44, color: UIColor,
                           textColor: UIColor = .white, fontSize: CGFloat = 18, enabled: Bool = true,
                           to parent: SKNode? = nil, action: @escaping () -> Void) -> Button {
        let b = Button(text, w: w, h: h, color: color, textColor: textColor, fontSize: fontSize, enabled: enabled, action: action)
        b.position = CGPoint(x: x, y: y)
        (parent ?? overlay).addChild(b)
        buttons.append(b)
        return b
    }

    private func coinBadge(y: CGFloat) {
        let l = UIK.label("◉ \(UIK.coins(store.d.coins))", size: 18, color: UIK.yellow, x: W / 2 - 24, y: y, align: .right)
        overlay.addChild(l)
    }

    // MARK: - Menu

    private func showMenu() {
        screen = .menu
        hud.isHidden = true
        resetWorld()
        status = .intro
        newOverlay()

        let s = min(1.0, H / 390)
        let title = UIK.label("LITTLE ALIEN", size: 46 * s, color: Art.rgb(0.35, 1, 0.5), y: H * 0.3)
        let shadow = UIK.label("LITTLE ALIEN", size: 46 * s, color: Art.rgb(0.05, 0.2, 0.1), x: 3, y: H * 0.3 - 3)
        overlay.addChild(shadow)
        overlay.addChild(title)
        overlay.addChild(UIK.label("Probe the humans!", size: 16 * s, color: .white, y: H * 0.3 - 34 * s))

        coinBadge(y: H / 2 - 26)
        overlay.addChild(UIK.label("Best \(UIK.coins(store.d.bestScore))  •  \(UIK.coins(store.d.bestDistance))m",
                                   size: 14, color: UIColor(white: 1, alpha: 0.9), x: -W / 2 + 24, y: H / 2 - 26, align: .left))

        addButton("PLAY", x: 0, y: H * 0.02, w: 200, h: 54, color: UIK.green, fontSize: 26) { [weak self] in
            self?.startGame()
        }
        let row = -H * 0.17
        let bw = min(150, (W - 120) / 3)
        addButton("SHOP", x: -bw - 14, y: row, w: bw, color: UIK.blue) { [weak self] in self?.showShop() }
        addButton("UFOS", x: 0, y: row, w: bw, color: UIK.purple) { [weak self] in self?.showHangar() }
        addButton("OPTIONS", x: bw + 14, y: row, w: bw, color: UIK.gray) { [weak self] in self?.showSettings() }

        // consumables to take into the next run
        let cy = -H * 0.34
        let items: [(String, Int, Bool, () -> Void)] = [
            ("Health Pack ×\(store.d.healthPacks)", store.d.healthPacks, runCfg.healthPack, { [weak self] in self?.runCfg.healthPack.toggle(); self?.showMenu() }),
            ("Head Start ×\(store.d.headStarts)", store.d.headStarts, runCfg.headStart, { [weak self] in self?.runCfg.headStart.toggle(); self?.showMenu() }),
            ("Meter Up ×\(store.d.meterUps)", store.d.meterUps, runCfg.meterUp, { [weak self] in self?.runCfg.meterUp.toggle(); self?.showMenu() })
        ]
        let iw = min(190, (W - 80) / 3)
        for (i, it) in items.enumerated() {
            let x = CGFloat(i - 1) * (iw + 10)
            let on = it.2 && it.1 > 0
            addButton((on ? "✓ " : "") + it.0, x: x, y: cy, w: iw, h: 34, color: on ? UIK.yellow : UIColor(white: 0, alpha: 0.35),
                      textColor: on ? .black : .white, fontSize: 13, enabled: it.1 > 0, action: it.3)
        }
    }

    // MARK: - Shop

    private func showShop() {
        screen = .shop
        newOverlay(dim: 0.35)
        overlay.addChild(UIK.panel(W - 40, H - 30))
        overlay.addChild(UIK.label("SHOP", size: 28, color: UIK.yellow, x: -W / 2 + 44, y: H / 2 - 42, align: .left))
        coinBadge(y: H / 2 - 42)
        addButton("BACK", x: 0, y: -H / 2 + 38, w: 140, h: 38, color: UIK.gray) { [weak self] in self?.showMenu() }

        let colW = (W - 100) / 2
        let lx = -colW / 2 - 10
        let rx = colW / 2 + 10
        let top = H / 2 - 92
        let step = min(58, (H - 170) / 3)

        overlay.addChild(UIK.label("Powers", size: 16, color: .white, x: lx, y: top + 26))
        for (i, p) in PowerType.allCases.enumerated() {
            let lvl = store.d.powerLevel[p.rawValue]
            let y = top - CGFloat(i) * step
            let dur = lvl > 0 ? "\(Int(p.durations[lvl - 1]))s" : "locked"
            overlay.addChild(UIK.label("\(p.title)  Lv \(lvl)/3  (\(dur))", size: 14, color: p.color.withAlphaComponent(1),
                                       x: lx - colW / 2 + 8, y: y + 9, align: .left))
            overlay.addChild(UIK.label(p.blurb, size: 11, color: UIColor(white: 1, alpha: 0.75), bold: false,
                                       x: lx - colW / 2 + 8, y: y - 9, align: .left))
            if lvl < 3 {
                let cost = Tuning.powerCost[lvl]
                addButton("◉ \(UIK.coins(cost))", x: lx + colW / 2 - 52, y: y, w: 96, h: 34, color: UIK.green, fontSize: 14,
                          enabled: store.d.coins >= cost) { [weak self] in
                    guard let self = self, self.spend(cost) else { return }
                    self.store.d.powerLevel[p.rawValue] += 1
                    self.store.save()
                    self.showShop()
                }
            } else {
                overlay.addChild(UIK.label("MAX", size: 14, color: UIK.yellow, x: lx + colW / 2 - 52, y: y))
            }
        }

        overlay.addChild(UIK.label("Items (one use)", size: 16, color: .white, x: rx, y: top + 26))
        let items: [(String, String, Int, Int, () -> Void)] = [
            ("Health Pack", "Second chance when you crash", Tuning.healthPackCost, store.d.healthPacks, { [weak self] in self?.store.d.healthPacks += 1 }),
            ("Head Start", "Blast \(Int(Tuning.boostDistance))m ahead at the start", Tuning.headStartCost, store.d.headStarts, { [weak self] in self?.store.d.headStarts += 1 }),
            ("Meter Up", "Start at multiplier x3", Tuning.meterUpCost, store.d.meterUps, { [weak self] in self?.store.d.meterUps += 1 })
        ]
        for (i, it) in items.enumerated() {
            let y = top - CGFloat(i) * step
            overlay.addChild(UIK.label("\(it.0)  (own \(it.3))", size: 14, color: .white, x: rx - colW / 2 + 8, y: y + 9, align: .left))
            overlay.addChild(UIK.label(it.1, size: 11, color: UIColor(white: 1, alpha: 0.75), bold: false,
                                       x: rx - colW / 2 + 8, y: y - 9, align: .left))
            let cost = it.2
            let give = it.4
            addButton("◉ \(UIK.coins(cost))", x: rx + colW / 2 - 52, y: y, w: 96, h: 34, color: UIK.green, fontSize: 14,
                      enabled: store.d.coins >= cost) { [weak self] in
                guard let self = self, self.spend(cost) else { return }
                give()
                self.store.save()
                self.showShop()
            }
        }
    }

    private func spend(_ cost: Int) -> Bool {
        guard store.d.coins >= cost else { return false }
        store.d.coins -= cost
        store.save()
        hapticLight.impactOccurred()
        return true
    }

    // MARK: - Hangar (UFOs)

    private func showHangar() {
        screen = .hangar
        newOverlay(dim: 0.35)
        overlay.addChild(UIK.panel(W - 40, H - 30))
        overlay.addChild(UIK.label("UFOS", size: 28, color: UIK.yellow, x: -W / 2 + 44, y: H / 2 - 42, align: .left))
        coinBadge(y: H / 2 - 42)
        addButton("BACK", x: 0, y: -H / 2 + 38, w: 140, h: 38, color: UIK.gray) { [weak self] in self?.showMenu() }

        let cw = (W - 80) / 5
        for i in 0..<5 {
            let x = -W / 2 + 40 + cw * (CGFloat(i) + 0.5)
            let owned = store.d.ufoOwned[i]
            let selected = store.d.selectedUFO == i
            let card = SKShapeNode(rectOf: CGSize(width: cw - 10, height: H * 0.6), cornerRadius: 12)
            card.fillColor = selected ? UIColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 0.6) : UIColor(white: 1, alpha: 0.08)
            card.strokeColor = selected ? UIK.yellow : .clear
            card.lineWidth = 2
            card.position = CGPoint(x: x, y: H * 0.03)
            overlay.addChild(card)

            let art = Art.ufo(i)
            art.setScale(min(1, (cw - 20) / 95))
            art.position = CGPoint(x: x, y: H * 0.18)
            if !owned { art.alpha = 0.45 }
            overlay.addChild(art)
            overlay.addChild(UIK.label(Art.ufoNames[i], size: 15, color: .white, x: x, y: H * 0.07))

            if owned {
                let tier = store.d.ufoTier[i]
                overlay.addChild(UIK.label("Level \(tier)/3  ♥\(Tuning.ufoHealth[tier])", size: 11, color: UIColor(white: 1, alpha: 0.85), x: x, y: H * 0.0))
                let perk = tier >= 3 ? "keeps powers" : (tier >= 2 ? "multiplier +1" : "")
                if !perk.isEmpty {
                    overlay.addChild(UIK.label(perk, size: 10, color: UIK.yellow, x: x, y: -H * 0.05))
                }
                if tier < 3 {
                    let cost = Tuning.ufoTierCost[tier]
                    addButton("UP ◉\(UIK.coins(cost))", x: x, y: -H * 0.12, w: cw - 20, h: 30, color: UIK.green, fontSize: 11,
                              enabled: store.d.coins >= cost) { [weak self] in
                        guard let self = self, self.spend(cost) else { return }
                        self.store.d.ufoTier[i] += 1
                        self.store.save()
                        self.showHangar()
                    }
                }
                if !selected {
                    addButton("SELECT", x: x, y: -H * 0.21, w: cw - 20, h: 30, color: UIK.blue, fontSize: 12) { [weak self] in
                        guard let self = self else { return }
                        self.store.d.selectedUFO = i
                        self.store.save()
                        self.setUFOArt()
                        self.showHangar()
                    }
                } else {
                    overlay.addChild(UIK.label("SELECTED", size: 12, color: UIK.yellow, x: x, y: -H * 0.21))
                }
            } else {
                let cost = Tuning.ufoBuyCost[i]
                addButton("◉ \(UIK.coins(cost))", x: x, y: -H * 0.15, w: cw - 20, h: 34, color: UIK.green, fontSize: 12,
                          enabled: store.d.coins >= cost) { [weak self] in
                    guard let self = self, self.spend(cost) else { return }
                    self.store.d.ufoOwned[i] = true
                    self.store.d.selectedUFO = i
                    self.store.save()
                    self.setUFOArt()
                    self.showHangar()
                }
            }
        }
    }

    // MARK: - Settings

    private func showSettings() {
        screen = .settings
        newOverlay(dim: 0.35)
        overlay.addChild(UIK.panel(min(W - 40, 560), H - 30))
        overlay.addChild(UIK.label("OPTIONS", size: 28, color: UIK.yellow, y: H / 2 - 42))
        addButton("BACK", x: 0, y: -H / 2 + 38, w: 140, h: 38, color: UIK.gray) { [weak self] in self?.showMenu() }

        let sense = store.d.touchSense
        overlay.addChild(UIK.label("Touch sensitivity: \(String(format: "%.1f", sense))", size: 18, y: H * 0.17))
        addButton("−", x: -70, y: H * 0.05, w: 60, h: 40, color: UIK.blue, fontSize: 24, enabled: sense > 0.51) { [weak self] in
            guard let self = self else { return }
            self.store.d.touchSense = max(0.5, ((sense - 0.1) * 10).rounded() / 10)
            self.store.save()
            self.showSettings()
        }
        addButton("+", x: 70, y: H * 0.05, w: 60, h: 40, color: UIK.blue, fontSize: 24, enabled: sense < 1.49) { [weak self] in
            guard let self = self else { return }
            self.store.d.touchSense = min(1.5, ((sense + 0.1) * 10).rounded() / 10)
            self.store.save()
            self.showSettings()
        }

        let d = store.d
        let lines = [
            "Runs \(d.runs)   •   Humans & animals abducted \(UIK.coins(d.totalAbducted))",
            "Vehicles destroyed \(d.vehiclesDestroyed)   •   Tanks destroyed \(d.tanksDestroyed)",
            "Powers collected \(d.powerupsCollected)   •   Crashes by vehicle \(d.deathsByVehicle)"
        ]
        for (i, s) in lines.enumerated() {
            overlay.addChild(UIK.label(s, size: 13, color: UIColor(white: 1, alpha: 0.85), bold: false, y: -H * 0.08 - CGFloat(i) * 22))
        }
    }

    // MARK: - Game flow

    private func resetWorld() {
        for n in creatures { n.removeFromParent() }
        for n in obstacles { n.removeFromParent() }
        for n in coins { n.removeFromParent() }
        for n in pickups { n.removeFromParent() }
        for n in missiles { n.removeFromParent() }
        for n in decor { n.removeFromParent() }
        creatures = []; obstacles = []; coins = []; pickups = []; missiles = []; flocks = []; decor = []

        ufo.removeAllActions()
        ufo.alpha = 1
        ufo.zRotation = 0
        ufoArt.zRotation = 0
        ufoArt.position = .zero
        ufo.position = CGPoint(x: W * 0.25, y: ufoY)
        startX = ufo.position.x
        cam.position = CGPoint(x: ufo.position.x + W * 0.2, y: H / 2)
        beamOffset = 90 * ws
        beamX = ufo.position.x + beamOffset
        ufoOffset = 0
        touching = false
        beam.path = nil
        beamRing.path = nil

        nextGroupX = ufo.position.x + W * 0.6
        nextStaticX = ufo.position.x + W * 1.4
        nextCoinX = ufo.position.x + W * 0.9
        nextPickupX = ufo.position.x + W * 2.5
        nextDecorX = ufo.position.x - W
        nextCloudX = ufo.position.x - W
        nextBirdX = ufo.position.x + W * 2
        nextSign = Tuning.signEvery
        spawnScenery()
    }

    private func startGame() {
        newOverlay()
        resetWorld()
        screen = .playing
        hud.isHidden = false

        elapsed = 0
        score = 0
        runCoins = 0
        abducted = 0
        moveSpeed = Tuning.startSpeed
        streakSpeed = 0
        distance = 0
        level = 0
        collectedStreak = 0
        sinceCollect = 0
        invincible = 0
        damageTimer = 0
        power = nil
        powerTimer = 0
        beamWeight = 0
        inVehicleState = false
        stateTimer = Tuning.groundDuration
        vehicleDuration = Tuning.vehicleDuration
        vehicleDifficulty = 0
        nextVehicleIn = 1
        nextTankIn = CGFloat.random(in: 15...20)
        maxHealth = store.maxHealth
        health = maxHealth
        tutorial = store.d.runs == 0

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

        // Intro animation (status 0) then play/boost
        status = .intro
        ufo.position.y = H + 60
        ufo.run(.sequence([.moveTo(y: ufoY, duration: 0.6)])) { [weak self] in
            guard let self = self, self.screen == .playing || self.screen == .paused else { return }
            if boosting {
                self.status = .boost
                self.boostUntil = CGFloat(self.distance) + Tuning.boostDistance
                self.banner("HEAD START!")
            } else {
                self.status = .play
                self.banner(self.tutorial ? "Drag your finger to move the beam" : "Probe them!")
            }
        }
        if secondChance { popupHUD("Health Pack ready", color: UIK.green) }
        updateHUD()
    }

    private func pauseGame() {
        guard screen == .playing else { return }
        screen = .paused
        touching = false
        newOverlay(dim: 0.5)
        overlay.addChild(UIK.label("PAUSED", size: 40, color: .white, y: H * 0.18))
        addButton("RESUME", x: 0, y: 0, w: 200, h: 48, color: UIK.green, fontSize: 22) { [weak self] in
            guard let self = self else { return }
            self.newOverlay()
            self.screen = .playing
            self.lastTime = 0
        }
        addButton("QUIT", x: 0, y: -H * 0.17, w: 160, h: 40, color: UIK.red) { [weak self] in
            self?.finishRun()
        }
    }

    private func finishRun() {
        let bonus = score / Tuning.scoreToCoinsDivisor
        let earned = runCoins + bonus
        store.d.coins += earned
        store.d.runs += 1
        store.d.totalAbducted += abducted
        let newBest = score > store.d.bestScore
        if newBest { store.d.bestScore = score }
        if distance > store.d.bestDistance { store.d.bestDistance = distance }
        store.save()

        screen = .over
        overTimer = 0
        hud.isHidden = true
        newOverlay(dim: 0.5)
        overlay.addChild(UIK.panel(min(W - 60, 520), H * 0.8))
        overlay.addChild(UIK.label(newBest ? "NEW BEST!" : "GAME OVER", size: 36,
                                   color: newBest ? UIK.yellow : Art.rgb(1, 0.45, 0.5), y: H * 0.29))
        overlay.addChild(UIK.label("Score \(UIK.coins(score))", size: 24, y: H * 0.17))
        overlay.addChild(UIK.label("Distance \(UIK.coins(distance))m   •   Abducted \(abducted)", size: 15,
                                   color: UIColor(white: 1, alpha: 0.9), bold: false, y: H * 0.08))
        overlay.addChild(UIK.label("Coins +\(runCoins)  + score bonus \(bonus)  =  ◉ \(earned)", size: 15,
                                   color: UIK.yellow, y: -H * 0.01))
        addButton("PLAY AGAIN", x: -95, y: -H * 0.18, w: 170, h: 46, color: UIK.green, fontSize: 18) { [weak self] in
            self?.startGame()
        }
        addButton("MENU", x: 95, y: -H * 0.18, w: 170, h: 46, color: UIK.blue, fontSize: 18) { [weak self] in
            self?.showMenu()
        }
    }

    // MARK: - Input

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
            lastTouch = t.location(in: view)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard screen == .playing, touching, let t = touches.first else { return }
        let p = t.location(in: view)
        let dx = p.x - lastTouch.x
        lastTouch = p
        // touchScale: normalise to a 960-wide reference, scaled by user sensitivity
        let scale = CGFloat(store.d.touchSense) * 1.35
        beamOffset += dx * scale
        beamOffset = max(-W * 0.28, min(W * 0.55, beamOffset))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let dt = CGFloat(min(currentTime - lastTime, 1.0 / 20.0))
        lastTime = currentTime
        guard W > 0 else { return }
        clock += dt

        switch screen {
        case .menu, .shop, .hangar, .settings:
            idleDrift(dt)
        case .playing:
            step(dt)
        case .paused:
            break
        case .over:
            overTimer += dt
            idleDrift(dt * 0.5)
        }
        updateParallax()
    }

    private func idleDrift(_ dt: CGFloat) {
        ufo.position.x += 60 * dt
        ufo.position.y = ufoY + sin(clock * 2.5) * 6
        cam.position = CGPoint(x: ufo.position.x + W * 0.2, y: H / 2)
        beamX = ufo.position.x
        beam.path = nil
        beamRing.path = nil
        spawnScenery()
        for c in creatures { walk(c, dt) }
        cleanup()
    }

    private var beamActive: Bool {
        return touching && status == .play
    }

    private var beamRadius: CGFloat {
        let r = Tuning.beamRadius * ws
        return power == .rampage ? r * Tuning.rampageRadiusFactor : r
    }

    private var multiplier: Int {
        return Tuning.streakMult[level] + (store.upgradedMultiplier ? 1 : 0)
    }

    private func step(_ dt: CGFloat) {
        elapsed += dt

        // --- Speed (UFOSpeedController) ---
        var speed: CGFloat
        switch status {
        case .intro:
            speed = moveSpeed
        case .play:
            moveSpeed = min(Tuning.maxSpeed, max(0, moveSpeed + Tuning.speedGain * dt))
            speed = moveSpeed + streakSpeed
        case .boost:
            speed = Tuning.boostSpeed
            if CGFloat(distance) >= boostUntil {
                status = .play
                invincible = Tuning.boostInvuln
                banner("Go!")
            }
        case .dead:
            speed = 0
        }

        if status == .dead {
            stepDeath(dt)
        } else {
            ufo.position.x += speed * Tuning.unit * ws * dt
            // AlignToBeam: smooth translation + rotation toward beam target
            let targetOff = max(-W * 0.12, min(W * 0.18, beamOffset * 0.35))
            ufoOffset += (targetOff - ufoOffset) * min(1, dt * 2.5)
            let bob = sin(clock * 3) * 5
            if status != .intro { ufo.position.y = ufoY + bob }
            let lean = max(-0.35, min(0.35, -(beamOffset - ufoOffset) / W * 0.6))
            ufoArt.zRotation += (lean - ufoArt.zRotation) * min(1, dt * 6)
        }
        ufoArt.position.x = ufoOffset
        let ufoPos = CGPoint(x: ufo.position.x + ufoOffset, y: ufo.position.y)

        if status != .dead {
            cam.position = CGPoint(x: ufo.position.x + W * 0.2, y: H / 2)
        }

        let d = Int(floor((ufo.position.x - startX) / (Tuning.unit * ws)))
        if status != .dead { distance = max(distance, d) }

        // Beam target eases toward finger target
        let desired = ufoPos.x + beamOffset
        beamX += (desired - beamX) * min(1, dt * 12)
        drawBeam(from: ufoPos)

        manageStates(dt)
        spawnScenery()
        spawnWorld()
        updateCreatures(dt, ufoPos: ufoPos)
        updateObstacles(dt, ufoPos: ufoPos)
        updateCoins(dt, ufoPos: ufoPos)
        updatePickups(dt)
        updateMissiles(dt, ufoPos: ufoPos)
        cleanup()

        // Timers
        if invincible > 0 { invincible -= dt }
        if damageTimer > 0 {
            damageTimer -= dt
            ufoArt.alpha = (Int(clock * 14) % 2 == 0) ? 0.35 : 1
            if damageTimer <= 0 { ufoArt.alpha = 1 }
        } else if invincible > 0 {
            ufoArt.alpha = 0.6 + 0.4 * sin(clock * 20)
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

        if status == .dead {
            overTimer += dt
        }
        updateHUD()
    }

    private func drawBeam(from top: CGPoint) {
        guard beamActive else {
            beam.path = nil
            beamRing.path = nil
            return
        }
        let r = beamRadius
        let y0 = top.y - 12 * ws
        let bottom = roadY
        let p = CGMutablePath()
        p.move(to: CGPoint(x: top.x - 12 * ws, y: y0))
        p.addLine(to: CGPoint(x: beamX - r, y: bottom))
        p.addLine(to: CGPoint(x: beamX + r, y: bottom))
        p.addLine(to: CGPoint(x: top.x + 12 * ws, y: y0))
        p.closeSubpath()
        beam.path = p
        let pulse = 0.28 + 0.06 * sin(clock * 10)
        let col: UIColor
        if damageTimer > 0 {
            col = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: pulse + 0.1)   // _TintColor red on damage
        } else if power == .rampage {
            col = UIColor(red: 1, green: 0.45, blue: 0.2, alpha: pulse + 0.08)
        } else if power == .magnet {
            col = UIColor(red: 0.5, green: 0.7, blue: 1, alpha: pulse)
        } else {
            col = UIColor(red: 0.6, green: 1, blue: 0.8, alpha: pulse)
        }
        beam.fillColor = col
        beamRing.strokeColor = col.withAlphaComponent(0.9)
        beamRing.fillColor = col.withAlphaComponent(0.25)
        beamRing.path = CGPath(ellipseIn: CGRect(x: beamX - r, y: bottom - 7, width: r * 2, height: 14), transform: nil)
    }

    // MARK: - Difficulty (GroundManager state cycle)

    private func manageStates(_ dt: CGFloat) {
        guard status == .play, !tutorialActive else { return }
        stateTimer -= dt
        if stateTimer <= 0 {
            if inVehicleState {
                // EndVehicleSpawn
                inVehicleState = false
                vehicleDifficulty = min(Tuning.maxVehicleDifficulty, vehicleDifficulty + 1)
                vehicleDuration += Tuning.vehicleDurationGrowth
                stateTimer = Tuning.groundDuration
            } else {
                // BeginVehicleSpawn
                inVehicleState = true
                stateTimer = vehicleDuration
                nextVehicleIn = 0.5
                banner("Traffic incoming!")
            }
        }

        if inVehicleState {
            nextVehicleIn -= dt
            let vehicleCount = obstacles.filter { $0.kind.isVehicle }.count
            if nextVehicleIn <= 0 && vehicleCount < Tuning.maxVehicles {
                spawnVehicle()
                let lo = max(0.4, 1 - 0.3 * CGFloat(vehicleDifficulty) * 0.5)
                let hi = max(lo + 0.3, 3 - 0.3 * CGFloat(vehicleDifficulty))
                nextVehicleIn = CGFloat.random(in: lo...hi)
            }
        }

        if distance >= Tuning.tankFrom {
            nextTankIn -= dt
            if nextTankIn <= 0 {
                spawnObstacle(.tank, x: cam.position.x + W * 0.75, moving: true)
                nextTankIn = CGFloat.random(in: 15...20)
            }
        }
    }

    private var tutorialActive: Bool { return tutorial && elapsed < 20 }

    private func spawnVehicle() {
        var pool: [ObKind] = [.car, .car, .car, .truck]
        if distance >= Tuning.fireTruckFrom { pool.append(.fireTruck) }
        if distance >= Tuning.policeFrom { pool += [.police, .police] }
        if distance >= Tuning.jeepFrom { pool += [.jeep, .jeep] }
        let k = pool.randomElement() ?? .car
        let x = cam.position.x + W * 0.7 + CGFloat.random(in: 0...60)
        let o = spawnObstacle(k, x: x, moving: true)
        if k == .fireTruck {
            for i in 0..<2 { spawnCreature(.fireman, x: x + CGFloat(i) * 20 * ws + 50 * ws) }
        }
        if k == .jeep, Bool.random() {
            spawnCreature(.soldier, x: x + 40 * ws)
        }
        _ = o
    }

    // MARK: - Spawning

    private func spawnScenery() {
        let limit = cam.position.x + W * 1.2
        while nextDecorX < limit {
            let n = Art.tree()
            n.setScale(CGFloat.random(in: 0.9...1.4) * ws)
            n.position = CGPoint(x: nextDecorX, y: groundY + CGFloat.random(in: 6...16) * ws)
            n.zPosition = -12
            addChild(n)
            decor.append(n)
            nextDecorX += CGFloat.random(in: 120...300) * ws
        }
        while nextCloudX < limit {
            let n = Art.cloud()
            n.setScale(CGFloat.random(in: 0.8...1.8) * ws)
            n.position = CGPoint(x: nextCloudX, y: CGFloat.random(in: H * 0.55...H * 0.95))
            n.zPosition = -50
            addChild(n)
            decor.append(n)
            nextCloudX += CGFloat.random(in: 260...520)
        }
        while nextBirdX < limit {
            // AirBoid: decorative flock
            let count = Int.random(in: 3...6)
            let by = CGFloat.random(in: H * 0.6...H * 0.9)
            for i in 0..<count {
                let b = Art.bird()
                b.setScale(ws)
                b.position = CGPoint(x: nextBirdX + CGFloat(i) * 16, y: by + CGFloat(i % 3) * 10)
                b.zPosition = -40
                b.run(.repeatForever(.moveBy(x: -50, y: 0, duration: 1)))
                addChild(b)
                decor.append(b)
            }
            nextBirdX += CGFloat.random(in: 900...1600)
        }
    }

    private func spawnWorld() {
        let limit = cam.position.x + W * 0.9

        // Creatures in groups
        while nextGroupX < limit {
            spawnGroup(at: nextGroupX)
            let busy = min(1, CGFloat(distance) / 3000)
            nextGroupX += CGFloat.random(in: 150...300) * ws * (1 - busy * 0.3)
        }

        // Static obstacles (fences, sheds, buildings...)
        while nextStaticX < limit {
            if !tutorialActive {
                var pool: [ObKind] = [.fence, .fence, .barrel, .shed]
                if distance > 300 { pool += [.windmill, .house] }
                if distance > 800 { pool += [.silo, .barrel] }
                if distance > 1500 { pool += [.barn, .house] }
                let k = pool.randomElement() ?? .fence
                spawnObstacle(k, x: nextStaticX, moving: false)
            }
            let busy = min(1, CGFloat(distance) / 4000)
            nextStaticX += CGFloat.random(in: 380...720) * ws * (1 - busy * 0.4)
        }

        // Coins in arcs
        while nextCoinX < limit {
            let n = Int.random(in: 4...8)
            for i in 0..<n {
                let c = Coin()
                c.addChild(Art.coin())
                c.setScale(ws)
                c.baseY = groundY + (22 + sin(CGFloat(i) / CGFloat(n - 1) * .pi) * 30) * ws
                c.position = CGPoint(x: nextCoinX + CGFloat(i) * 22 * ws, y: c.baseY)
                c.zPosition = 30
                addChild(c)
                coins.append(c)
            }
            nextCoinX += CGFloat.random(in: 500...900) * ws
        }

        // Power capsules (only for unlocked powers)
        let unlocked = PowerType.allCases.filter { store.d.powerLevel[$0.rawValue] > 0 }
        while nextPickupX < limit {
            if let t = unlocked.randomElement() {
                let p = Pickup(type: t)
                p.addChild(Art.capsule(t))
                p.setScale(ws)
                p.baseY = groundY + 40 * ws
                p.position = CGPoint(x: nextPickupX, y: p.baseY)
                p.zPosition = 31
                addChild(p)
                pickups.append(p)
            }
            nextPickupX += CGFloat.random(in: 1400...2400) * ws
        }

        // Distance signs
        let signX = startX + CGFloat(nextSign) * Tuning.unit * ws
        if signX < limit {
            let s = Art.sign(nextSign)
            s.setScale(ws)
            s.position = CGPoint(x: signX, y: groundY + 2)
            s.zPosition = -8
            addChild(s)
            decor.append(s)
            nextSign += Tuning.signEvery
        }
    }

    private func spawnGroup(at x: CGFloat) {
        let roll = Int.random(in: 0..<100)
        if roll < 30 {
            // Flock of sheep (Boids) with a herding dog
            let flock = Flock(x: x)
            flocks.append(flock)
            let n = Int.random(in: 3...6)
            let goldChance = distance > 1000 ? 12 : 4
            for i in 0..<n {
                let r = Int.random(in: 0..<100)
                let variant = r < goldChance ? 2 : (r < 25 ? 1 : 0)
                let c = spawnCreature(.sheep, x: x + CGFloat(i) * 14 * ws, variant: variant)
                c.flock = flock
                c.flockOffset = CGFloat(i) * 14 * ws - CGFloat(n) * 7 * ws
            }
            if Int.random(in: 0..<100) < 60 {
                let dog = spawnCreature(.dog, x: x - 40 * ws)
                dog.flock = flock
                dog.flockOffset = -CGFloat(n) * 7 * ws - 30 * ws
            }
        } else if roll < 50 {
            let n = Int.random(in: 1...3)
            let r = Int.random(in: 0..<100)
            let variant = r < 15 ? 2 : (r < 55 ? 1 : 0)
            for i in 0..<n { spawnCreature(.cow, x: x + CGFloat(i) * 46 * ws, variant: variant) }
        } else if roll < 65 {
            let n = Int.random(in: 2...4)
            for i in 0..<n {
                let r = Int.random(in: 0..<100)
                spawnCreature(.pig, x: x + CGFloat(i) * 30 * ws, variant: r < 50 ? 0 : (r < 75 ? 1 : 2))
            }
        } else if roll < 82 {
            spawnCreature(.farmer, x: x)
            if Bool.random() { spawnCreature(.farmer, x: x + 30 * ws) }
            if distance > 500 && Int.random(in: 0..<100) < 40 { spawnCreature(.pitchforkMan, x: x + 60 * ws) }
        } else if roll < 92 {
            if distance > 1000 { spawnCreature(.reporter, x: x) } else { spawnCreature(.farmer, x: x) }
        } else {
            if distance > Tuning.jeepFrom {
                for i in 0..<Int.random(in: 2...3) { spawnCreature(.soldier, x: x + CGFloat(i) * 26 * ws) }
            } else {
                spawnCreature(.pitchforkMan, x: x)
            }
        }
    }

    /// Pickup.scoreValue from the original
    private func baseValue(_ k: Kind) -> Int {
        switch k {
        case .cow: return 25
        case .sheep: return 30
        case .soldier: return 30
        case .fireman: return 24
        case .pig: return 20
        case .pitchforkMan: return 15
        case .farmer: return 12
        case .reporter: return 12
        case .dog: return 6
        }
    }

    @discardableResult
    private func spawnCreature(_ kind: Kind, x: CGFloat, variant: Int = 0) -> Creature {
        var v = baseValue(kind)
        if kind == .pig && variant != 0 { v = 16 }
        let c = Creature(kind: kind, value: v)
        c.addChild(Art.creature(kind, variant: variant))
        c.setScale(ws)
        c.baseY = groundY - CGFloat.random(in: 0...10) * ws
        c.position = CGPoint(x: x, y: c.baseY)
        c.zPosition = 20 - c.baseY / 100
        c.xScale = c.dir * ws
        c.walkSpeed *= ws
        addChild(c)
        creatures.append(c)
        return c
    }

    @discardableResult
    private func spawnObstacle(_ kind: ObKind, x: CGFloat, moving: Bool) -> Obstacle {
        let o = Obstacle(kind: kind)
        o.addChild(Art.obstacle(kind))
        o.setScale(ws)
        if kind.isStatic {
            o.baseY = groundY + 2 * ws
            o.zPosition = 12
        } else if kind == .barrel {
            o.baseY = groundY - 4 * ws
            o.zPosition = 22
        } else {
            o.baseY = roadY - 6 * ws
            o.zPosition = 24
        }
        o.position = CGPoint(x: x, y: o.baseY)
        if moving {
            // AIVehicle drives toward the UFO (leftward)
            o.dir = -1
            o.xScale = ws
            o.driveSpeed = kind == .tank ? 25 * ws : CGFloat.random(in: 40...90) * ws * (1 + CGFloat(vehicleDifficulty) * 0.08)
        }
        addChild(o)
        obstacles.append(o)
        return o
    }

    // MARK: - Creatures (AIPeople / AICow / Boids)

    private func walk(_ c: Creature, _ dt: CGFloat) {
        if let f = c.flock {
            f.x += f.dir * f.speed * dt * 0.25
            let target = f.x + c.flockOffset + sin(clock * 2 + c.wob) * 4
            let dx = target - c.position.x
            c.position.x += max(-c.walkSpeed, min(c.walkSpeed, dx * 3)) * dt
            if abs(dx) > 1 { c.xScale = (dx > 0 ? 1 : -1) * ws }
            if c.kind == .dog {
                c.position.y = c.baseY + max(0, sin(clock * 9 + c.wob)) * 5 * ws  // JumpObject
            }
        } else {
            c.position.x += c.dir * c.walkSpeed * dt
            if Int.random(in: 0..<400) == 0 {
                c.dir = -c.dir
                c.xScale = c.dir * ws
            }
        }
        if c.kind == .reporter {
            c.flashTimer -= dt
            if c.flashTimer <= 0 {
                c.flashTimer = CGFloat.random(in: 1.5...3.5)
                if let fl = c.childNode(withName: "//flash") {
                    let glow = Art.circ(8, UIColor(white: 1, alpha: 0.9))
                    glow.position = fl.position
                    fl.parent?.addChild(glow)
                    glow.run(.sequence([.group([.scale(to: 2.5, duration: 0.15), .fadeOut(withDuration: 0.15)]), .removeFromParent()]))
                }
            }
        }
    }

    private func updateCreatures(_ dt: CGFloat, ufoPos: CGPoint) {
        let r = beamRadius
        var collected: [Creature] = []
        var weight: CGFloat = 0

        for c in creatures {
            if !c.lifted {
                if c.position.y > c.baseY + 0.5 && c.flock == nil || (c.fallV > 0) {
                    // falling back down after being dropped
                    c.fallV += 900 * dt
                    c.position.y = max(c.baseY, c.position.y - c.fallV * dt)
                    c.zRotation *= 0.9
                    if c.position.y <= c.baseY { c.fallV = 0; c.zRotation = 0 }
                    continue
                }
                // Flee the beam (calculateDirectionToBeam)
                if beamActive && c.kind.flees && abs(c.position.x - beamX) < r + 90 * ws {
                    let d: CGFloat = c.position.x >= beamX ? 1 : -1
                    c.position.x += d * c.walkSpeed * 1.4 * dt
                    c.xScale = d * ws
                    if let f = c.flock { f.x += d * c.walkSpeed * 0.3 * dt }
                } else {
                    walk(c, dt)
                }
                if beamActive && abs(c.position.x - beamX) < r {
                    c.lifted = true
                    c.flock = nil
                }
            } else {
                if !beamActive {
                    c.lifted = false
                    c.fallV = 1
                    continue
                }
                weight += c.kind.weight
                let span = max(1, ufoPos.y - groundY)
                let t = max(0, min(1, (ufoPos.y - c.position.y) / span))
                let lineX = ufoPos.x + (beamX - ufoPos.x) * t
                if abs(c.position.x - lineX) > r * 1.1 + 10 {
                    c.lifted = false
                    c.fallV = 1
                    continue
                }
                // Spinny pull: spiral that tightens as the object rises
                let pull = 40 * ws * 3.6 / (1 + beamWeight * 0.04)
                c.position.y += pull * dt
                let swirl = sin(clock * 6 + c.wob) * r * 0.5 * t
                c.position.x += (lineX + swirl - c.position.x) * min(1, dt * 8)
                c.zRotation += 10 * .pi / 180 * dt * 20
                if c.position.y >= ufoPos.y - 18 * ws {
                    collected.append(c)
                }
            }
        }
        beamWeight = weight + obstacles.filter { $0.lifted }.reduce(0) { $0 + $1.kind.weight }
        for c in collected { collect(c) }
    }

    private func collect(_ c: Creature) {
        let pts = c.value * multiplier * (power == .multiply ? 2 : 1)
        score += pts
        abducted += 1
        sinceCollect = 0
        collectedStreak += 1
        while level + 1 < Tuning.streakCounts.count && collectedStreak >= Tuning.streakCounts[level + 1] {
            level += 1
            streakSpeed = Tuning.streakSpeed[level]
            banner("x\(multiplier)  speed up!")
        }
        popup("+\(pts)", at: CGPoint(x: c.position.x, y: c.position.y + 20), color: UIK.yellow)
        hapticLight.impactOccurred()
        c.removeFromParent()
        creatures.removeAll { $0 === c }
    }

    private func dropLevel() {
        guard level > 0 else { return }
        level -= 1
        collectedStreak = Tuning.streakCounts[level]
        streakSpeed = Tuning.streakSpeed[level]
    }

    // MARK: - Obstacles

    private func updateObstacles(_ dt: CGFloat, ufoPos: CGPoint) {
        let r = beamRadius
        var gone: [Obstacle] = []

        for o in obstacles where !o.dead {
            if o.lifted {
                if !beamActive {
                    o.lifted = false
                    o.fallV = 1
                    continue
                }
                let pull = 40 * ws * 3.6 / (1 + o.kind.weight * 0.35 + beamWeight * 0.04)
                o.position.y += pull * dt
                let span = max(1, ufoPos.y - roadY)
                let t = max(0, min(1, (ufoPos.y - o.position.y) / span))
                let lineX = ufoPos.x + (beamX - ufoPos.x) * t
                o.position.x += (lineX - o.position.x) * min(1, dt * 5)
                o.zRotation = sin(clock * 4 + o.wob) * 0.25
                if o.position.y >= ufoPos.y - 20 * ws {
                    // An obstacle reaching the saucer hurts it
                    gone.append(o)
                    explode(o, at: CGPoint(x: ufoPos.x, y: ufoPos.y - 10 * ws))
                    takeDamage(o.kind.damage, byVehicle: o.kind.isVehicle)
                }
                continue
            }

            if o.fallV > 0 {
                o.fallV += 900 * dt
                o.position.y -= o.fallV * dt
                if o.position.y <= o.baseY {
                    o.position.y = o.baseY
                    gone.append(o)
                    explode(o, at: o.position)
                    score += 10 * multiplier
                    if o.kind.isVehicle { store.d.vehiclesDestroyed += 1 }
                    if o.kind == .tank { store.d.tanksDestroyed += 1 }
                }
                continue
            }

            if o.driveSpeed > 0 {
                o.position.x += o.dir * o.driveSpeed * dt
                // leanVehicle: small bounce on the road
                o.zRotation = sin(clock * 8 + o.wob) * 0.02
            }

            // Tank fires at the UFO
            if o.kind == .tank {
                if let barrel = o.childNode(withName: "barrel") {
                    let dx = ufoPos.x - o.position.x
                    let dy = ufoPos.y - (o.position.y + 26 * ws)
                    barrel.zRotation = max(0.2, min(2.9, atan2(dy, dx * o.xScale / ws)))
                }
                let dx = o.position.x - ufoPos.x
                if abs(dx) < W * 0.7 && status == .play {
                    o.fireTimer -= dt
                    if o.fireTimer <= 0 {
                        o.fireTimer = CGFloat.random(in: 2...3.2)
                        fireMissile(from: o, at: ufoPos)
                    }
                }
            }

            let hit = beamActive && abs(o.position.x - beamX) < r + o.kind.halfWidth * ws * 0.7
            guard hit else { continue }

            if power == .rampage {
                // Rampage smashes anything inside the beam
                gone.append(o)
                explode(o, at: o.position)
                score += 50 * multiplier
                popup("SMASH +\(50 * multiplier)", at: CGPoint(x: o.position.x, y: o.position.y + 40 * ws), color: Art.rgb(1, 0.5, 0.2))
                if o.kind.isVehicle { store.d.vehiclesDestroyed += 1 }
                if o.kind == .tank { store.d.tanksDestroyed += 1 }
                hapticHeavy.impactOccurred()
            } else if o.kind.isStatic {
                // destroyOnGround: buildings collapse and damage the beam
                if invincible <= 0 && damageTimer <= 0 {
                    gone.append(o)
                    explode(o, at: o.position)
                    takeDamage(o.kind.damage, byVehicle: false)
                }
            } else {
                o.lifted = true
            }
        }

        for o in gone {
            o.dead = true
            o.removeFromParent()
        }
        obstacles.removeAll { $0.dead }
    }

    private func explode(_ o: Obstacle, at p: CGPoint) {
        let base: UIColor
        switch o.kind {
        case .fence, .shed: base = Art.rgb(0.7, 0.55, 0.35)
        case .barn: base = Art.rgb(0.72, 0.15, 0.12)
        case .tank, .jeep: base = Art.rgb(0.35, 0.42, 0.28)
        case .fireTruck: base = Art.rgb(0.85, 0.12, 0.1)
        case .silo, .windmill: base = UIColor(white: 0.8, alpha: 1)
        default: base = UIColor(white: 0.6, alpha: 1)
        }
        boom(at: p, size: o.kind.halfWidth * ws * 0.6)
        for _ in 0..<10 {
            let d = Art.debris(Bool.random() ? base : UIColor(white: 0.2, alpha: 1))
            d.position = CGPoint(x: p.x + CGFloat.random(in: -20...20) * ws, y: p.y + 10 * ws)
            d.zPosition = 60
            addChild(d)
            let vx = CGFloat.random(in: -120...120) * ws
            let vy = CGFloat.random(in: 80...240) * ws
            d.run(.sequence([
                .group([
                    .customAction(withDuration: 0.9) { n, t in
                        let tt = CGFloat(t)
                        n.position = CGPoint(x: p.x + vx * tt, y: p.y + 10 * self.ws + vy * tt - 450 * tt * tt)
                        n.zRotation = tt * 8
                    },
                    .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.3)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func boom(at p: CGPoint, size: CGFloat) {
        let c = Art.circ(max(8, size), UIColor.orange.withAlphaComponent(0.9), p.x, p.y)
        c.zPosition = 61
        addChild(c)
        c.run(.sequence([.group([.scale(to: 3, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        let c2 = Art.circ(max(6, size * 0.6), UIColor.yellow.withAlphaComponent(0.9), p.x, p.y)
        c2.zPosition = 62
        addChild(c2)
        c2.run(.sequence([.group([.scale(to: 2.2, duration: 0.2), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
    }

    // MARK: - Missiles

    private func fireMissile(from o: Obstacle, at target: CGPoint) {
        let m = Missile()
        m.addChild(Art.missile())
        m.setScale(ws)
        let start = CGPoint(x: o.position.x, y: o.position.y + 30 * ws)
        m.position = start
        let speed: CGFloat = 230 * ws
        let dist = hypot(target.x - start.x, target.y - start.y)
        let lead = (moveSpeed + streakSpeed) * Tuning.unit * ws * dist / speed
        let aim = CGPoint(x: target.x + lead, y: target.y)
        let ang = atan2(aim.y - start.y, aim.x - start.x)
        m.v = CGVector(dx: cos(ang) * speed, dy: sin(ang) * speed)
        m.zRotation = ang
        m.zPosition = 46
        addChild(m)
        missiles.append(m)
        boom(at: start, size: 4)
    }

    private func updateMissiles(_ dt: CGFloat, ufoPos: CGPoint) {
        var dead: [Missile] = []
        for m in missiles {
            m.position.x += m.v.dx * dt
            m.position.y += m.v.dy * dt
            m.life -= dt
            if m.life <= 0 { dead.append(m); continue }
            if status != .dead && hypot(m.position.x - ufoPos.x, m.position.y - ufoPos.y) < 30 * ws {
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

    // MARK: - Coins & powers

    private func updateCoins(_ dt: CGFloat, ufoPos: CGPoint) {
        let r = beamRadius
        let magnetR = W * 0.45
        var taken: [Coin] = []
        for c in coins {
            if c.homing {
                let dx = ufoPos.x - c.position.x, dy = ufoPos.y - c.position.y
                let d = max(1, hypot(dx, dy))
                let sp: CGFloat = 700 * ws
                c.position.x += dx / d * sp * dt + (moveSpeed * Tuning.unit * ws) * dt
                c.position.y += dy / d * sp * dt
                if d < 24 * ws { taken.append(c) }
                continue
            }
            c.position.y = c.baseY + sin(clock * 3 + c.phase) * 3 * ws
            if power == .magnet && abs(c.position.x - ufoPos.x) < magnetR {
                c.homing = true
            } else if beamActive && abs(c.position.x - beamX) < r + 6 * ws {
                c.homing = true
            }
        }
        for c in taken {
            let v = Tuning.coinValue
            runCoins += v
            c.removeFromParent()
            coins.removeAll { $0 === c }
        }
    }

    private func updatePickups(_ dt: CGFloat) {
        let r = beamRadius + 8 * ws
        var taken: [Pickup] = []
        for p in pickups {
            p.position.y = p.baseY + sin(clock * 3 + p.position.x) * 4
            if beamActive && abs(p.position.x - beamX) < r {
                taken.append(p)
            }
        }
        for p in taken {
            let lvl = store.d.powerLevel[p.type.rawValue]
            if lvl > 0 {
                power = p.type
                powerTimer = p.type.durations[lvl - 1]
                store.d.powerupsCollected += 1
                switch p.type {
                case .rampage: banner("RAMPAGE!")
                case .magnet: banner("MAGNET!")
                case .multiply: banner("DOUBLE POINTS!")
                }
            }
            hapticLight.impactOccurred()
            p.removeFromParent()
            pickups.removeAll { $0 === p }
        }
    }

    // MARK: - Damage & death (TakeDamage / playDeath)

    private func takeDamage(_ amount: Int, byVehicle: Bool) {
        guard status == .play || status == .boost else { return }
        if invincible > 0 || damageTimer > 0 { return }
        health -= max(1, amount)
        if tutorialActive { health = max(1, health) }
        damageTimer = Tuning.damageTime
        hapticHeavy.impactOccurred()
        shake()
        if power != nil && !store.keepsPowerups {
            power = nil
            powerTimer = 0
        }
        dropLevel()

        if health <= 0 {
            if secondChance {
                secondChance = false
                health = maxHealth
                invincible = 3
                banner("Health Pack used!")
                return
            }
            health = 0
            if byVehicle { store.d.deathsByVehicle += 1 }
            die()
        } else {
            popupHUD("-\(amount) ♥", color: Art.rgb(1, 0.4, 0.45))
        }
    }

    private func shake() {
        let a: CGFloat = 7
        cam.run(.sequence([.moveBy(x: a, y: a, duration: 0.03), .moveBy(x: -2 * a, y: -a, duration: 0.05),
                           .moveBy(x: a, y: 0, duration: 0.03)]))
    }

    private func die() {
        status = .dead
        touching = false
        overTimer = 0
        let speed = moveSpeed + streakSpeed
        deathV = CGVector(dx: speed * 1.2 * Tuning.unit * ws * 0.6, dy: 0)
        bouncesLeft = max(0, Int(floor((speed - 12) / 3))) + 1
        banner("CRASH!")
        store.save()
    }

    private func stepDeath(_ dt: CGFloat) {
        let floorY = groundY + 10 * ws
        deathV.dy -= 900 * ws * dt
        ufo.position.x += deathV.dx * dt
        ufo.position.y += deathV.dy * dt
        ufoArt.zRotation -= 4 * dt
        if ufo.position.y <= floorY {
            ufo.position.y = floorY
            if bouncesLeft > 0 {
                bouncesLeft -= 1
                deathV.dy = 320 * ws * (0.5 + 0.15 * CGFloat(bouncesLeft))
                deathV.dx *= 0.75
                boom(at: ufo.position, size: 10)
                hapticHeavy.impactOccurred()
            } else {
                deathV = .zero
                if overTimer > 1.4 && screen == .playing {
                    boom(at: ufo.position, size: 24)
                    finishRun()
                    return
                }
            }
        }
        // Camera follows the falling saucer
        let target = ufo.position.x + W * 0.05
        cam.position.x += (target - cam.position.x) * min(1, dt * 3)
    }

    // MARK: - Cleanup

    private func cleanup() {
        let left = cam.position.x - W / 2 - 220
        let right = cam.position.x + W * 2.5
        creatures.removeAll { n in
            if n.position.x < left || n.position.x > right { n.removeFromParent(); return true }
            return false
        }
        flocks.removeAll { f in !creatures.contains { $0.flock === f } }
        obstacles.removeAll { n in if n.position.x < left - 100 { n.removeFromParent(); return true }; return false }
        pickups.removeAll { n in if n.position.x < left { n.removeFromParent(); return true }; return false }
        coins.removeAll { n in if n.position.x < left && !n.homing { n.removeFromParent(); return true }; return false }
        decor.removeAll { n in if n.position.x < left - 200 { n.removeFromParent(); return true }; return false }
        missiles.removeAll { n in if n.position.x < left || n.position.y > H + 100 { n.removeFromParent(); return true }; return false }
    }

    // MARK: - HUD

    private func updateHUD() {
        scoreLabel.text = UIK.coins(score)
        distLabel.text = "\(UIK.coins(distance)) m"
        multLabel.text = "x\(multiplier)"
        coinLabel.text = "◉ \(runCoins)"
        let full = max(0, health)
        heartsLabel.text = String(repeating: "♥", count: full) + String(repeating: "♡", count: max(0, maxHealth - full)) + (secondChance ? " +" : "")

        if let p = power {
            powerLabel.text = "\(p.title.uppercased())  \(Int(ceil(powerTimer)))s"
            powerLabel.fontColor = p.color
        } else if status == .boost {
            powerLabel.text = "HEAD START"
            powerLabel.fontColor = UIK.yellow
        } else {
            powerLabel.text = ""
        }

        let barW: CGFloat = 120
        let hasNext = level + 1 < Tuning.streakCounts.count
        let lo = Tuning.streakCounts[level]
        let hi = hasNext ? Tuning.streakCounts[level + 1] : lo + 1
        let frac = hasNext ? CGFloat(collectedStreak - lo) / CGFloat(max(1, hi - lo)) : 1
        goalLabel.text = hasNext ? "\(collectedStreak - lo)/\(hi - lo) to x\(Tuning.streakMult[level + 1] + (store.upgradedMultiplier ? 1 : 0))" : "MAX MULTIPLIER"
        // SetMultiplierGoal: show how long until the streak drops
        if level > 0 && hasNext {
            let left = max(0, Tuning.streakWindow - sinceCollect)
            if left < 2.5 { goalLabel.fontColor = Art.rgb(1, 0.5, 0.5) } else { goalLabel.fontColor = UIColor(white: 1, alpha: 0.85) }
        }
        barBack.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: barW, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil)
        barFill.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: max(2, barW * max(0, min(1, frac))), height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil)
    }

    private func popup(_ text: String, at p: CGPoint, color: UIColor) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 18 * ws
        l.fontColor = color
        l.position = p
        l.zPosition = 900
        addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 40, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }

    private func popupHUD(_ text: String, color: UIColor) {
        let l = UIK.label(text, size: 18, color: color, y: H * 0.18)
        l.zPosition = 1500
        cam.addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    }

    private func banner(_ text: String) {
        let l = UIK.label(text, size: 28, color: .white, y: H * 0.06)
        l.zPosition = 1500
        l.setScale(0.5)
        let sh = UIK.label(text, size: 28, color: UIColor(white: 0, alpha: 0.5), x: 2, y: -2)
        sh.zPosition = -1
        l.addChild(sh)
        cam.addChild(l)
        l.run(.sequence([.scale(to: 1, duration: 0.15), .wait(forDuration: 0.9), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
}
