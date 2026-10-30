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

    static func shadow(_ w: CGFloat) -> SKShapeNode {
        let s = ell(w, w * 0.32, UIColor(white: 0, alpha: 0.35))
        s.zPosition = -1
        return s
    }

    // MARK: UFOs (painted)

    static let ufoNames = ["Casey", "Nick", "Marc", "Andres", "Tania"]

    static func ufo(_ index: Int) -> SKNode {
        let n = SKNode()
        let s = Painter.sprite(Painter.ufo(index), canvas: Painter.ufoCanvas, foot: Painter.ufoFoot)
        n.addChild(s)
        // pulsing emitter light
        let glow = SKSpriteNode(texture: Painter.landing())
        glow.size = CGSize(width: 90, height: 24)
        glow.position = CGPoint(x: 0, y: -25)
        glow.color = Painter.neon[max(0, min(4, index))]
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
            l.addChild(rect(w, h, color, x, h / 2, r: w / 2))
            if let hf = hoof { l.addChild(rect(w + 0.6, 2.4, hf, x, 1.2, r: 1)) }
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
            let b = [UIColor(white: 0.9, alpha: 1), rgb(0.5, 0.3, 0.18), rgb(0.68, 0.5, 0.9)][variant % 3]
            n.addChild(legs([-15, -8, 9, 16], w: 4.4, h: 13, color: b.darker(0.85), hoof: rgb(0.1, 0.1, 0.12)))
            n.addChild(Painter.sprite(Painter.cow(variant), canvas: CGSize(width: 84, height: 64), foot: CGPoint(x: 40, y: 6)))
        case .pig:
            n.addChild(shadow(32))
            let b = [rgb(1, 0.66, 0.74), rgb(0.56, 0.72, 0.42), rgb(0.62, 0.62, 0.64)][variant % 3]
            n.addChild(legs([-9, -4, 4, 9], w: 3.4, h: 7, color: b.darker(0.75)))
            n.addChild(Painter.sprite(Painter.pig(variant), canvas: cv, foot: CGPoint(x: 30, y: 4)))
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
            default: o = Painter.Outfit(shirt: rgb(0.3, 0.3, 0.42), pants: rgb(0.15, 0.15, 0.2), hair: rgb(0.85, 0.65, 0.2))
            }
            n.addChild(shadow(20))
            let lg = SKNode()
            lg.name = "legs"
            for x in [-3, 3] as [CGFloat] {
                lg.addChild(rect(4.6, 14, o.pants.darker(0.85), x, 7, r: 2))
                lg.addChild(rect(6, 3, rgb(0.15, 0.1, 0.08), x + 1, 1.5, r: 1.2))
            }
            n.addChild(lg)
            n.addChild(Painter.sprite(Painter.person("\(kind)", o), canvas: CGSize(width: 48, height: 64), foot: CGPoint(x: 24, y: 2)))
            if kind == .grumpa || kind == .farmer && variant == 1 {
                let fork = SKNode()
                fork.name = "fork"
                fork.position = CGPoint(x: 9, y: 16)
                fork.addChild(rect(1.8, 40, rgb(0.5, 0.35, 0.2), 0, 14))
                fork.addChild(rect(10, 1.8, UIColor(white: 0.7, alpha: 1), 0, 34))
                for dx in [-4.5, 0, 4.5] as [CGFloat] { fork.addChild(rect(1.4, 8, UIColor(white: 0.75, alpha: 1), dx, 38)) }
                n.addChild(fork)
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
        let board = SKSpriteNode(texture: Painter.signBoard(), size: CGSize(width: w, height: h + 34))
        board.anchorPoint = CGPoint(x: 0.5, y: 0)
        n.addChild(board)
        let top = h + 34 - (h + 34) * 0.06
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

    static func tuft() -> SKNode {
        let s = SKSpriteNode(texture: Painter.tuft(Int.random(in: 0..<3)), size: CGSize(width: 22, height: 16))
        s.anchorPoint = CGPoint(x: 0.5, y: 0)
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
