import SpriteKit
import UIKit

/// All art is drawn in code from simple shapes (original artwork, night-farm style).
enum Art {
    private static func fill(_ n: SKShapeNode, _ c: UIColor, stroke: UIColor? = nil, lw: CGFloat = 1) -> SKShapeNode {
        n.fillColor = c
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : lw
        n.isAntialiased = true
        return n
    }

    static func ell(_ w: CGFloat, _ h: CGFloat, _ c: UIColor, _ x: CGFloat = 0, _ y: CGFloat = 0, stroke: UIColor? = nil) -> SKShapeNode {
        let n = fill(SKShapeNode(ellipseOf: CGSize(width: w, height: h)), c, stroke: stroke)
        n.position = CGPoint(x: x, y: y)
        return n
    }

    static func rect(_ w: CGFloat, _ h: CGFloat, _ c: UIColor, _ x: CGFloat = 0, _ y: CGFloat = 0, r: CGFloat = 0, stroke: UIColor? = nil) -> SKShapeNode {
        let n = fill(SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: r), c, stroke: stroke)
        n.position = CGPoint(x: x, y: y)
        return n
    }

    static func circ(_ r: CGFloat, _ c: UIColor, _ x: CGFloat = 0, _ y: CGFloat = 0, stroke: UIColor? = nil) -> SKShapeNode {
        let n = fill(SKShapeNode(circleOfRadius: r), c, stroke: stroke)
        n.position = CGPoint(x: x, y: y)
        return n
    }

    static func poly(_ pts: [CGPoint], _ c: UIColor, stroke: UIColor? = nil) -> SKShapeNode {
        let p = CGMutablePath()
        p.addLines(between: pts)
        p.closeSubpath()
        return fill(SKShapeNode(path: p), c, stroke: stroke)
    }

    static func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ col: UIColor) -> SKShapeNode {
        return poly([a, b, c], col)
    }

    static func line(_ a: CGPoint, _ b: CGPoint, _ c: UIColor, _ w: CGFloat) -> SKShapeNode {
        let p = CGMutablePath()
        p.move(to: a)
        p.addLine(to: b)
        let n = SKShapeNode(path: p)
        n.strokeColor = c
        n.lineWidth = w
        n.lineCap = .round
        return n
    }

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    static let skin = rgb(0.98, 0.78, 0.62)
    static let dark = rgb(0.12, 0.12, 0.16)
    static let outline = rgb(0.1, 0.08, 0.15, 0.9)

    static func shadow(_ w: CGFloat) -> SKSpriteNode {
        let s = SKSpriteNode(texture: Painter.shadowTex(), size: CGSize(width: w * 1.15, height: w * 0.4))
        s.zPosition = -1
        return s
    }

    /// Plain coloured block as a sprite (batches far better than shape nodes).
    static func block(_ w: CGFloat, _ h: CGFloat, _ c: UIColor, _ x: CGFloat = 0, _ y: CGFloat = 0) -> SKSpriteNode {
        let s = SKSpriteNode(color: c, size: CGSize(width: w, height: h))
        s.position = CGPoint(x: x, y: y)
        s.lightingBitMask = 1
        return s
    }

    // MARK: UFOs (painted)

    static let ufoNames = ["Casey", "Nick", "Marc", "Andres", "Tania"]

    static func ufo(_ index: Int) -> SKNode {
        return ufo(theme: UFOTheme.all[max(0, min(UFOTheme.all.count - 1, index))])
    }

    static func ufo(theme: UFOTheme) -> SKNode {
        let n = SKNode()
        let s = Painter.sprite(Painter.ufo(theme: theme), canvas: Painter.ufoCanvas, foot: Painter.ufoFoot, lit: false)
        n.addChild(s)
        // pulsing emitter light
        let glow = SKSpriteNode(texture: Painter.landing())
        glow.size = CGSize(width: 90, height: 24)
        glow.position = CGPoint(x: 0, y: -25)
        glow.color = theme.neon
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.7
        glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.5), .fadeAlpha(to: 0.8, duration: 0.5)])))
        n.addChild(glow)
        return n
    }

    // MARK: Creatures (feet at y = 0, facing right)

    static let creatureScale: CGFloat = 1.3

    private static func legs(_ xs: [CGFloat], w: CGFloat, h: CGFloat, color: UIColor, hoof: UIColor? = nil) -> SKNode {
        let l = SKNode()
        l.name = "legs"
        for x in xs {
            l.addChild(block(w, h, color, x, h / 2))
            if let hf = hoof { l.addChild(block(w + 0.6, 2.4, hf, x, 1.2)) }
        }
        return l
    }

    static func creature(_ kind: Kind, variant: Int) -> SKNode {
        let root = SKNode()
        let n = SKNode()
        n.setScale(creatureScale)
        root.addChild(n)
        let cv = Painter.creatureCanvas, ft = Painter.creatureFoot
        switch kind {
        case .sheep:
            n.addChild(shadow(30))
            n.addChild(legs([-8, -3, 5, 10], w: 2.8, h: 9, color: rgb(0.12, 0.11, 0.14)))
            n.addChild(Painter.sprite(Painter.sheep(variant), canvas: cv, foot: ft))
        case .cow:
            n.addChild(shadow(50))
            let b = [UIColor(white: 0.9, alpha: 1), rgb(0.5, 0.3, 0.18), rgb(0.68, 0.5, 0.9), rgb(0.5, 0.95, 0.4)][variant % 4]
            n.addChild(legs([-15, -8, 9, 16], w: 4.4, h: 13, color: b.darker(0.85), hoof: rgb(0.1, 0.1, 0.12)))
            n.addChild(Painter.sprite(Painter.cow(variant), canvas: CGSize(width: 84, height: 64), foot: CGPoint(x: 40, y: 6)))
        case .pig:
            n.addChild(shadow(32))
            let b = [rgb(1, 0.66, 0.74), rgb(0.56, 0.72, 0.42), rgb(0.62, 0.62, 0.64)][variant % 3]
            n.addChild(legs([-9, -4, 4, 9], w: 3.4, h: 7, color: b.darker(0.75)))
            n.addChild(Painter.sprite(Painter.pig(variant), canvas: cv, foot: CGPoint(x: 30, y: 4)))
        case .camel:
            n.addChild(shadow(64))
            n.addChild(legs([-17, -10, 11, 18], w: 5, h: 50, color: rgb(0.66, 0.5, 0.3), hoof: rgb(0.3, 0.22, 0.14)))
            n.addChild(Painter.sprite(Painter.camel(), canvas: CGSize(width: 96, height: 84), foot: CGPoint(x: 44, y: 0)).moved(0, 22))
        case .dog:
            n.addChild(shadow(26))
            n.addChild(legs([-9, -4, 6, 10], w: 2.8, h: 9, color: rgb(0.12, 0.12, 0.14), hoof: .white))
            n.addChild(Painter.sprite(Painter.dog(), canvas: cv, foot: CGPoint(x: 28, y: 6)))
        default:
            let o: Painter.Outfit
            switch kind {
            case .grumpa: o = Painter.Outfit(shirt: rgb(0.32, 0.36, 0.42), pants: rgb(0.22, 0.32, 0.55), hat: rgb(0.45, 0.32, 0.2), beard: true, hair: UIColor(white: 0.9, alpha: 1))
            case .farmer: o = Painter.Outfit(shirt: rgb(0.75, 0.25, 0.2), pants: rgb(0.2, 0.32, 0.6), hat: rgb(0.25, 0.4, 0.75), cap: true, hair: rgb(0.4, 0.25, 0.12))
            case .fireman: o = Painter.Outfit(shirt: rgb(0.95, 0.72, 0.15), pants: rgb(0.95, 0.72, 0.15), hat: rgb(0.85, 0.15, 0.1))
            case .soldier: o = Painter.Outfit(shirt: rgb(0.33, 0.42, 0.24), pants: rgb(0.28, 0.36, 0.2), hat: rgb(0.26, 0.34, 0.2), cap: true)
            case .hunter: o = Painter.Outfit(shirt: rgb(0.45, 0.32, 0.2), pants: rgb(0.3, 0.3, 0.22), hat: rgb(1, 0.45, 0.05), cap: true, beard: true, hair: rgb(0.35, 0.22, 0.1))
            case .bedouin: o = Painter.Outfit(shirt: rgb(0.95, 0.94, 0.9), pants: rgb(0.95, 0.94, 0.9), hat: rgb(0.85, 0.15, 0.15), cap: true)
            case .citizen: o = Painter.Outfit(shirt: rgb(0.2, 0.22, 0.3), pants: rgb(0.15, 0.16, 0.2), hair: rgb(0.15, 0.1, 0.08))
            default: o = Painter.Outfit(shirt: rgb(0.3, 0.3, 0.42), pants: rgb(0.15, 0.15, 0.2), hair: rgb(0.85, 0.65, 0.2))
            }
            n.addChild(shadow(20))
            let lg = SKNode()
            lg.name = "legs"
            for x in [-3, 3] as [CGFloat] {
                lg.addChild(block(4.6, 14, o.pants.darker(0.85), x, 7))
                lg.addChild(block(6, 3, rgb(0.15, 0.1, 0.08), x + 1, 1.5))
            }
            n.addChild(lg)
            n.addChild(Painter.sprite(Painter.person("\(kind)", o), canvas: CGSize(width: 48, height: 64), foot: CGPoint(x: 24, y: 2)))
            if kind == .grumpa || kind == .farmer && variant == 1 {
                let fork = SKNode()
                fork.name = "fork"
                fork.position = CGPoint(x: 9, y: 16)
                fork.addChild(block(1.8, 40, rgb(0.5, 0.35, 0.2), 0, 14))
                fork.addChild(block(10, 1.8, UIColor(white: 0.7, alpha: 1), 0, 34))
                for dx in [-4.5, 0, 4.5] as [CGFloat] { fork.addChild(block(1.4, 8, UIColor(white: 0.75, alpha: 1), dx, 38)) }
                n.addChild(fork)
            }
            if kind == .hunter {
                let gun = SKNode()
                gun.name = "gun"
                gun.position = CGPoint(x: 6, y: 22)
                gun.addChild(block(26, 2.4, rgb(0.15, 0.15, 0.17), 13, 0))
                gun.addChild(block(10, 4, rgb(0.45, 0.28, 0.15), 2, -1))
                n.addChild(gun)
            }
            if kind == .citizen {
                n.addChild(block(2.2, 9, rgb(0.8, 0.15, 0.15), 1, 20))
                n.addChild(block(8, 6, rgb(0.25, 0.2, 0.15), 10, 14))
            }
            if kind == .reporter {
                let cam = SKNode()
                cam.position = CGPoint(x: 10, y: 26)
                cam.addChild(rect(9, 7, dark, stroke: outline))
                cam.addChild(circ(2.2, rgb(0.6, 0.8, 1), 4.5, 0))
                let flash = rect(4, 3, .white, -1, 5)
                flash.name = "flash"
                cam.addChild(flash)
                n.addChild(cam)
            }
        }
        return root
    }

    // MARK: Obstacles (painted, base at y = 0)

    static let carColors: [UIColor] = [rgb(0.75, 0.12, 0.15), rgb(0.18, 0.32, 0.7), rgb(0.88, 0.72, 0.25), rgb(0.18, 0.5, 0.42), rgb(0.1, 0.1, 0.12)]

    static func obstacle(_ kind: ObKind) -> SKNode {
        let n = SKNode()
        func add(_ t: SKTexture, _ w: CGFloat, _ h: CGFloat, footY: CGFloat = 4, shadowW: CGFloat) {
            n.addChild(shadow(shadowW))
            n.addChild(Painter.sprite(t, canvas: CGSize(width: w, height: h), foot: CGPoint(x: w / 2, y: footY)))
        }
        switch kind {
        case .fence: add(Painter.fence(), 96, 36, shadowW: 92)
        case .shed: add(Painter.shed(), 60, 56, footY: 6, shadowW: 54)
        case .barrels: add(Painter.barrels(), 56, 36, shadowW: 50)
        case .silo: add(Painter.silo(), 50, 104, shadowW: 46)
        case .house: add(Painter.house(), 100, 92, shadowW: 86)
        case .barn: add(Painter.barn(), 112, 90, shadowW: 100)
        case .windmill:
            add(Painter.windmillTower(), 48, 128, footY: 2, shadowW: 40)
            let wheel = SKSpriteNode(texture: Painter.windmillWheel(), size: CGSize(width: 60, height: 60))
            wheel.position = CGPoint(x: 0, y: 112)
            wheel.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 3)))
            n.addChild(wheel)
            n.addChild(poly([CGPoint(x: 2, y: 112), CGPoint(x: -22, y: 117), CGPoint(x: -22, y: 106)], rgb(0.45, 0.42, 0.4)))
        case .car:
            let i = Int.random(in: 0..<carColors.count)
            let b = carColors[i]
            add(Painter.car("c\(i)", body: b, roof: i == 4 ? UIColor(white: 0.85, alpha: 1) : b.darker(0.85)), 96, 44, footY: 2, shadowW: 84)
        case .police:
            add(Painter.car("police", body: rgb(0.1, 0.1, 0.12), roof: .white, police: true), 96, 44, footY: 2, shadowW: 84)
            let red = rect(6, 4, .red, -4, 38, r: 1)
            let blue = rect(6, 4, rgb(0.2, 0.4, 1), 4, 38, r: 1)
            red.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.18), .fadeAlpha(to: 1, duration: 0.18)])))
            blue.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.18), .fadeAlpha(to: 0.15, duration: 0.18)])))
            n.addChild(red); n.addChild(blue)
        case .jeep, .truck, .fireTruck:
            add(Painter.vehicle(kind), 110, 52, footY: 2, shadowW: 96)
            if kind == .fireTruck {
                let siren = rect(8, 4, rgb(0.3, 0.6, 1), 35, 34, r: 1)
                siren.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)])))
                n.addChild(siren)
            }
        case .powerline:
            n.addChild(shadow(16))
            n.addChild(Painter.sprite(Painter.powerPole(), canvas: CGSize(width: 40, height: 132), foot: CGPoint(x: 20, y: 0)))
        case .building:
            add(Painter.building(Int.random(in: 0..<3)), 110, 156, footY: 2, shadowW: 100)
        case .lamp:
            add(Painter.lamp(), 50, 104, footY: 0, shadowW: 18)
        case .hydrant:
            add(Painter.hydrant(), 24, 28, footY: 2, shadowW: 18)
        case .tent:
            add(Painter.tent(), 96, 56, footY: 3, shadowW: 92)
        case .palm:
            add(Painter.palm(), 90, 130, footY: 0, shadowW: 30)
        case .tank:
            let b = SKNode()
            b.name = "barrel"
            b.position = CGPoint(x: 0, y: 30)
            b.zRotation = 0.9
            b.addChild(rect(34, 6, UIColor(white: 0.22, alpha: 1), 17, 0, stroke: outline))
            n.addChild(b)
            add(Painter.vehicle(.tank), 110, 52, footY: 2, shadowW: 84)
        }
        return n
    }

    // MARK: Collectables, signs, decor

    static func coin() -> SKNode {
        let n = SKNode()
        n.addChild(shadow(12))
        let face = SKSpriteNode(texture: Painter.coin(), size: CGSize(width: 26, height: 26))
        face.position = CGPoint(x: 0, y: 11)
        face.run(.repeatForever(.sequence([.scaleX(to: 0.2, duration: 0.4), .scaleX(to: 1, duration: 0.4)])))
        n.addChild(face)
        return n
    }

    static func capsule(_ t: PowerType) -> SKNode {
        let n = SKNode()
        n.addChild(shadow(20))
        let orb = SKNode()
        orb.position = CGPoint(x: 0, y: 16)
        let glow = SKSpriteNode(texture: Painter.coin(), size: CGSize(width: 40, height: 40))
        glow.color = t.color
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        orb.addChild(glow)
        orb.addChild(circ(10, t.color, stroke: .white))
        let txt: String
        switch t {
        case .rampage: txt = "⚡︎"
        case .magnet: txt = "U"
        case .multiply: txt = "2X"
        case .shield: txt = "◯"
        case .twin: txt = "II"
        case .slowmo: txt = "⏱︎"
        }
        let l = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
        l.text = txt
        l.fontSize = 11
        l.fontColor = .white
        l.verticalAlignmentMode = .center
        orb.addChild(l)
        orb.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.5), .moveBy(x: 0, y: -4, duration: 0.5)])))
        n.addChild(orb)
        return n
    }

    /// Wooden sign with light text (tutorial / high score / distance signs).
    static func sign(_ lines: [String], wide: Bool = false) -> SKNode {
        let n = SKNode()
        let w: CGFloat = wide ? 150 : 96
        let h: CGFloat = CGFloat(lines.count) * 17 + 14
        let total = h / 0.47 + 6
        let board = SKSpriteNode(texture: Painter.signBoard(), size: CGSize(width: w, height: total))
        board.anchorPoint = CGPoint(x: 0.5, y: 0)
        n.addChild(board)
        let top = total * 0.93 - 4
        for (i, s) in lines.enumerated() {
            let l = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
            l.text = s
            l.fontSize = 14
            l.fontColor = rgb(0.95, 0.92, 0.85)
            l.verticalAlignmentMode = .center
            l.position = CGPoint(x: 0, y: top - 14 - CGFloat(i) * 17)
            n.addChild(l)
        }
        return n
    }

    /// The Kuwaiti blue street signs (3 from the owner's pictures + Jordan St. and Beirut St.).
    static let roadSignCount = 5
    static func roadSign(_ i: Int) -> SKNode {
        let n = SKNode()
        let tex: SKTexture
        // order along the road: Kuwait City → West Abdullah Mubarak → Ardiya → Jordan St. → Beirut St. → again
        switch i % roadSignCount {
        case 0: tex = Painter.roadSignImage("road_kuwait") ?? Painter.streetSign("kuwait", arabic: "مدينة الكويت", english: "Kuwait City", arrowLeft: false)
        case 1: tex = Painter.streetSign("westabdullah", arabic: "غرب عبدالله المبارك", english: "West Abdullah Mubarak", arrowLeft: true)
        case 2: tex = Painter.roadSignImage("road_ardiya") ?? Painter.streetSign("ardiya", arabic: "العارضية", english: "Ardiya", arrowLeft: false)
        case 3: tex = Painter.streetSign("jordan", arabic: "شارع الأردن", english: "Jordan Street", arrowLeft: false)
        default: tex = Painter.streetSign("beirut", arabic: "شارع بيروت", english: "Beirut Street", arrowLeft: true)
        }
        let pw: CGFloat = 236
        let ph = pw * tex.size().height / max(1, tex.size().width)
        let postH: CGFloat = 66
        let grey = rgb(0.55, 0.58, 0.62)
        for px in [-pw * 0.3, pw * 0.3] {
            let post = rect(6, postH + ph * 0.6, grey, px, (postH + ph * 0.6) / 2, r: 2, stroke: rgb(0.2, 0.22, 0.26))
            post.lineWidth = 1
            n.addChild(post)
        }
        let plate = SKSpriteNode(texture: tex, size: CGSize(width: pw, height: ph))
        plate.anchorPoint = CGPoint(x: 0.5, y: 0)
        plate.position = CGPoint(x: 0, y: postH)
        // night: slightly dimmed, still readable (signs are reflective)
        plate.color = rgb(0.78, 0.8, 0.92)
        plate.colorBlendFactor = 0.25
        n.addChild(plate)
        return n
    }

    /// The owner's shop strip (restaurant · supermarket · laundry), tinted to match the
    /// world look, the map and the weather, with neon glow and light spilling on the ground.
    static func shop(look: WorldTheme.Look, biome: Biome, rain: Bool) -> SKNode {
        let n = SKNode()
        guard let tex = Painter.roadSignImage("shop_strip") else { return n }
        let w: CGFloat = 420
        let h = w * tex.size().height / max(1, tex.size().width)
        let glow = Painter.softGlow()
        let spots: [(CGFloat, UIColor)] = [(-0.33, rgb(1, 0.72, 0.4)), (0, rgb(1, 0.22, 0.2)), (0.33, rgb(0.3, 0.5, 1))]

        // light from the windows on the pavement (longer and brighter on a wet road)
        for (fx, col) in spots {
            let g = SKSpriteNode(texture: glow, size: CGSize(width: w * 0.42, height: rain ? 70 : 38))
            g.position = CGPoint(x: fx * w, y: rain ? -14 : -4)
            g.color = col
            g.colorBlendFactor = 1
            g.alpha = rain ? 0.5 : 0.32
            g.blendMode = .add
            n.addChild(g)
        }

        let shopS = SKSpriteNode(texture: tex, size: CGSize(width: w, height: h))
        shopS.anchorPoint = CGPoint(x: 0.5, y: 0)
        var tint = rgb(0.82, 0.84, 1)
        var amount: CGFloat = 0.16
        switch look {
        case .winter: tint = rgb(0.84, 0.93, 1); amount = 0.3
        case .halloween: tint = rgb(1, 0.74, 0.52); amount = 0.24
        case .normal: break
        }
        if biome == .desert && look == .normal { tint = rgb(1, 0.86, 0.68); amount = 0.18 }
        if rain { tint = rgb(0.72, 0.78, 0.95); amount = max(amount, 0.3) }
        shopS.color = tint
        shopS.colorBlendFactor = amount
        n.addChild(shopS)

        // neon glow over the three signs
        for (i, (fx, col)) in spots.enumerated() {
            let g = SKSpriteNode(texture: glow, size: CGSize(width: w * 0.4, height: h * 0.5))
            g.position = CGPoint(x: fx * w, y: h * 0.74)
            g.color = col
            g.colorBlendFactor = 1
            g.alpha = 0.22
            g.blendMode = .add
            n.addChild(g)
            if look == .halloween && i == 0 {
                // spooky flickering restaurant sign
                g.run(.repeatForever(.sequence([.wait(forDuration: Double.random(in: 1.5...3.5)),
                                                .fadeAlpha(to: 0.02, duration: 0.05), .fadeAlpha(to: 0.3, duration: 0.05),
                                                .fadeAlpha(to: 0.05, duration: 0.07), .fadeAlpha(to: 0.22, duration: 0.1)])))
            }
        }

        switch look {
        case .winter:
            // snow on the roof and the restaurant awning
            let roof = rect(w * 0.99, 7, rgb(0.95, 0.97, 1), 0, h - 3, r: 3.5)
            n.addChild(roof)
            let mid = rect(w * 0.37, 6, rgb(0.95, 0.97, 1), 0, h + 1, r: 3)
            n.addChild(mid)
            let awn = rect(w * 0.29, 4, rgb(0.95, 0.97, 1), -w * 0.335, h * 0.535, r: 2)
            n.addChild(awn)
        case .halloween:
            for px in [-w * 0.44, w * 0.44] {
                let p = SKSpriteNode(texture: Painter.pumpkin(), size: CGSize(width: 22, height: 19))
                p.anchorPoint = CGPoint(x: 0.5, y: 0)
                p.position = CGPoint(x: px, y: h * 0.06)
                n.addChild(p)
            }
        case .normal:
            break
        }
        return n
    }

    static func tuft() -> SKNode {
        let s = SKSpriteNode(texture: Painter.tuft(Int.random(in: 0..<3)), size: CGSize(width: 22, height: 16))
        s.anchorPoint = CGPoint(x: 0.5, y: 0)
        s.lightingBitMask = 1
        return s
    }

    static func missile() -> SKNode {
        let n = SKNode()
        n.addChild(ell(14, 7, UIColor.orange.withAlphaComponent(0.9), -12, 0))
        n.addChild(rect(18, 7, rgb(0.85, 0.15, 0.15), 0, 0, r: 3))
        n.addChild(tri(CGPoint(x: 9, y: 4), CGPoint(x: 9, y: -4), CGPoint(x: 17, y: 0), UIColor(white: 0.9, alpha: 1)))
        return n
    }

    static func debris(_ color: UIColor) -> SKShapeNode {
        return rect(CGFloat.random(in: 4...10), CGFloat.random(in: 3...7), color)
    }

    // MARK: Textures

    static func gradient(size: CGSize, colors: [UIColor], locations: [CGFloat]) -> SKTexture {
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { ctx in
            let cs = CGColorSpaceCreateDeviceRGB()
            if let g = CGGradient(colorsSpace: cs, colors: colors.map { $0.cgColor } as CFArray, locations: locations) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        return SKTexture(image: img)
    }

    /// Dark (or red) edges, clear centre.
    static func vignette(size: CGSize, color: UIColor, strength: CGFloat) -> SKTexture {
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { ctx in
            let cs = CGColorSpaceCreateDeviceRGB()
            let c0 = color.withAlphaComponent(0).cgColor
            let c1 = color.withAlphaComponent(strength).cgColor
            if let g = CGGradient(colorsSpace: cs, colors: [c0, c0, c1] as CFArray, locations: [0, 0.55, 1]) {
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: center.x, y: center.y)
                ctx.cgContext.scaleBy(x: 1, y: size.height / size.width)
                ctx.cgContext.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero,
                                                 endRadius: size.width * 0.62, options: [.drawsAfterEndLocation])
                ctx.cgContext.restoreGState()
            }
        }
        return SKTexture(image: img)
    }

    static func softDot() -> SKTexture {
        let s = CGSize(width: 32, height: 32)
        let r = UIGraphicsImageRenderer(size: s)
        let img = r.image { ctx in
            let cs = CGColorSpaceCreateDeviceRGB()
            if let g = CGGradient(colorsSpace: cs, colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                                 endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
            }
        }
        return SKTexture(image: img)
    }
}

extension UIColor {
    func darker(_ f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: min(1, r * f), green: min(1, g * f), blue: min(1, b * f), alpha: a)
        }
        var w: CGFloat = 0
        getWhite(&w, alpha: &a)
        return UIColor(white: min(1, w * f), alpha: a)
    }
}

extension SKNode {
    func rotated(_ a: CGFloat) -> Self {
        zRotation = a
        return self
    }
}

extension SKNode {
    func moved(_ x: CGFloat, _ y: CGFloat) -> Self {
        position = CGPoint(x: position.x + x, y: position.y + y)
        return self
    }
}
