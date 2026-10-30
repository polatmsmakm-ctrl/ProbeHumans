import SpriteKit
import UIKit

/// All art is drawn in code from simple shapes (original artwork).
enum Art {
    private static func fill(_ n: SKShapeNode, _ c: UIColor) -> SKShapeNode {
        n.fillColor = c
        n.strokeColor = .clear
        n.lineWidth = 0
        return n
    }

    static func ell(_ w: CGFloat, _ h: CGFloat, _ c: UIColor, _ x: CGFloat = 0, _ y: CGFloat = 0) -> SKShapeNode {
        let n = fill(SKShapeNode(ellipseOf: CGSize(width: w, height: h)), c)
        n.position = CGPoint(x: x, y: y)
        return n
    }

    static func rect(_ w: CGFloat, _ h: CGFloat, _ c: UIColor, _ x: CGFloat = 0, _ y: CGFloat = 0, r: CGFloat = 0) -> SKShapeNode {
        let n = fill(SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: r), c)
        n.position = CGPoint(x: x, y: y)
        return n
    }

    static func circ(_ r: CGFloat, _ c: UIColor, _ x: CGFloat = 0, _ y: CGFloat = 0) -> SKShapeNode {
        let n = fill(SKShapeNode(circleOfRadius: r), c)
        n.position = CGPoint(x: x, y: y)
        return n
    }

    static func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ col: UIColor) -> SKShapeNode {
        let p = CGMutablePath()
        p.move(to: a)
        p.addLine(to: b)
        p.addLine(to: c)
        p.closeSubpath()
        return fill(SKShapeNode(path: p), col)
    }

    // MARK: Colors

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    static let skin = rgb(0.96, 0.8, 0.65)
    static let dark = UIColor(white: 0.15, alpha: 1)

    // MARK: UFOs (5 designs)

    static let ufoNames = ["Casey", "Nick", "Marc", "Andres", "Tania"]

    static func ufo(_ index: Int) -> SKNode {
        let n = SKNode()
        let hull: [UIColor] = [UIColor(white: 0.8, alpha: 1), rgb(0.95, 0.45, 0.2), rgb(0.35, 0.55, 0.95), rgb(0.3, 0.75, 0.4), rgb(0.85, 0.4, 0.8)]
        let alien: [UIColor] = [rgb(0.35, 0.85, 0.4), rgb(0.6, 0.4, 0.9), rgb(1, 0.75, 0.25), rgb(0.95, 0.35, 0.4), rgb(0.3, 0.8, 0.9)]
        let i = max(0, min(4, index))
        let h = hull[i]
        // alien inside the dome
        n.addChild(ell(15, 18, alien[i], 0, 12))
        n.addChild(circ(3, .white, -3.5, 15))
        n.addChild(circ(3, .white, 3.5, 15))
        n.addChild(circ(1.6, .black, -3.5, 15))
        n.addChild(circ(1.6, .black, 3.5, 15))
        if i == 1 || i == 3 {
            n.addChild(rect(1.5, 8, alien[i], -4, 24))
            n.addChild(rect(1.5, 8, alien[i], 4, 24))
            n.addChild(circ(2, alien[i], -4, 28))
            n.addChild(circ(2, alien[i], 4, 28))
        }
        // glass dome (transparent)
        n.addChild(circ(19, rgb(0.6, 0.9, 1, 0.38), 0, 12))
        n.addChild(ell(7, 4, UIColor(white: 1, alpha: 0.6), -7, 22))
        // hull
        let w: CGFloat = i == 4 ? 92 : (i == 2 ? 78 : 86)
        n.addChild(ell(w, 26, h.darker(0.6), 0, -2))
        n.addChild(ell(w, 20, h, 0, 1))
        n.addChild(ell(w * 0.8, 5, UIColor(white: 1, alpha: 0.25), 0, 5))
        let lights = i == 3 ? 7 : 5
        for k in 0..<lights {
            let x = (CGFloat(k) - CGFloat(lights - 1) / 2) * (w * 0.7 / CGFloat(lights - 1))
            let l = circ(2.8, rgb(1, 0.9, 0.3), x, -3)
            l.run(.repeatForever(.sequence([.wait(forDuration: Double(k) * 0.08), .fadeAlpha(to: 0.3, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)])))
            n.addChild(l)
        }
        if i == 2 {
            n.addChild(tri(CGPoint(x: -w/2 + 4, y: 0), CGPoint(x: -w/2 - 8, y: -10), CGPoint(x: -w/2 + 14, y: -6), h.darker(0.7)))
            n.addChild(tri(CGPoint(x: w/2 - 4, y: 0), CGPoint(x: w/2 + 8, y: -10), CGPoint(x: w/2 - 14, y: -6), h.darker(0.7)))
        }
        n.addChild(ell(26, 8, rgb(0.5, 1, 0.9, 0.9), 0, -13))
        return n
    }

    // MARK: People (feet at y = 0)

    private static func person(shirt: UIColor, pants: UIColor, hat: UIColor? = nil, scale: CGFloat = 1) -> SKNode {
        let n = SKNode()
        n.addChild(rect(3, 10, pants, -2.5, 5))
        n.addChild(rect(3, 10, pants, 2.5, 5))
        n.addChild(rect(10, 14, shirt, 0, 17, r: 2))
        n.addChild(rect(3, 10, shirt, -7, 17))
        n.addChild(rect(3, 10, shirt, 7, 17))
        n.addChild(circ(5.5, skin, 0, 29))
        n.addChild(circ(0.9, .black, 2.5, 30))
        if let hat = hat {
            n.addChild(rect(14, 2.5, hat, 0, 33))
            n.addChild(rect(9, 5, hat, 0, 36, r: 1.5))
        }
        n.setScale(scale)
        return n
    }

    static func creature(_ kind: Kind, variant: Int) -> SKNode {
        switch kind {
        case .farmer:
            return person(shirt: rgb(0.85, 0.25, 0.2), pants: rgb(0.2, 0.35, 0.7), hat: rgb(0.9, 0.8, 0.45))
        case .pitchforkMan:
            let n = person(shirt: rgb(0.45, 0.6, 0.3), pants: rgb(0.35, 0.25, 0.15), hat: rgb(0.6, 0.45, 0.25), scale: 1.25)
            n.addChild(rect(1.6, 30, rgb(0.5, 0.35, 0.2), 9, 22))
            for dx in [-2.5, 0, 2.5] as [CGFloat] { n.addChild(rect(1, 6, UIColor(white: 0.7, alpha: 1), 9 + dx, 39)) }
            return n
        case .fireman:
            let n = person(shirt: rgb(0.95, 0.75, 0.1), pants: rgb(0.2, 0.2, 0.2), hat: rgb(0.9, 0.15, 0.1))
            return n
        case .soldier:
            let n = person(shirt: rgb(0.33, 0.42, 0.25), pants: rgb(0.28, 0.35, 0.22), hat: rgb(0.25, 0.32, 0.2))
            n.addChild(rect(12, 2.5, dark, 3, 19))
            return n
        case .reporter:
            let n = person(shirt: rgb(0.25, 0.25, 0.35), pants: dark)
            let cam = SKNode()
            cam.position = CGPoint(x: 9, y: 22)
            cam.addChild(rect(8, 6, dark))
            cam.addChild(circ(2, rgb(0.6, 0.8, 1), 4, 0))
            let flash = rect(4, 3, .white, 0, 4)
            flash.name = "flash"
            cam.addChild(flash)
            n.addChild(cam)
            return n
        case .cow:
            let n = SKNode()
            let body: [UIColor] = [rgb(0.55, 0.33, 0.18), .white, rgb(0.7, 0.45, 0.9)]
            let spot: [UIColor] = [rgb(0.35, 0.2, 0.1), .black, rgb(0.45, 0.25, 0.65)]
            let b = body[variant % 3], s = spot[variant % 3]
            for x in [-12, -6, 7, 13] as [CGFloat] { n.addChild(rect(3.5, 10, UIColor(white: 0.3, alpha: 1), x, 5)) }
            n.addChild(rect(36, 16, b, 0, 18, r: 6))
            n.addChild(ell(9, 6, s, -7, 21))
            n.addChild(ell(8, 6, s, 7, 17))
            n.addChild(rect(12, 11, b, 21, 25, r: 3))
            n.addChild(rect(8, 5, rgb(1, 0.7, 0.7), 25, 22))
            n.addChild(circ(1.4, .black, 22, 28))
            n.addChild(rect(2, 5, UIColor(white: 0.9, alpha: 1), 19, 33))
            n.addChild(rect(2, 8, b, -19, 18))
            return n
        case .sheep:
            let n = SKNode()
            let wool: [UIColor] = [UIColor(white: 0.95, alpha: 1), UIColor(white: 0.18, alpha: 1), rgb(1, 0.8, 0.2)]
            let w = wool[variant % 3]
            for x in [-6, -2, 4, 7] as [CGFloat] { n.addChild(rect(2.2, 7, dark, x, 3.5)) }
            for (x, y) in [(-6, 13), (0, 15), (6, 13), (-3, 10), (4, 10)] as [(CGFloat, CGFloat)] { n.addChild(circ(6, w, x, y)) }
            n.addChild(ell(8, 9, dark, 11, 15))
            n.addChild(circ(1, .white, 12.5, 16))
            if variant % 3 == 2 { n.addChild(circ(2, .white, -2, 18)) }
            return n
        case .pig:
            let n = SKNode()
            let col: [UIColor] = [rgb(1, 0.65, 0.72), rgb(0.55, 0.75, 0.45), UIColor(white: 0.6, alpha: 1)]
            let c = col[variant % 3]
            for x in [-7, -3, 4, 8] as [CGFloat] { n.addChild(rect(3, 5, c.darker(0.8), x, 2.5)) }
            n.addChild(ell(26, 15, c, 0, 11))
            n.addChild(ell(6, 5, c.darker(0.85), 13, 11))
            n.addChild(circ(0.8, .black, 12, 11))
            n.addChild(circ(0.8, .black, 14, 11))
            n.addChild(circ(1, .black, 9, 14))
            n.addChild(tri(CGPoint(x: 6, y: 16), CGPoint(x: 10, y: 17), CGPoint(x: 8, y: 21), c.darker(0.85)))
            return n
        case .dog:
            let n = SKNode()
            let c = rgb(0.25, 0.22, 0.2)
            for x in [-7, -3, 5, 8] as [CGFloat] { n.addChild(rect(2.5, 6, c, x, 3)) }
            n.addChild(rect(20, 9, c, 0, 10, r: 3))
            n.addChild(rect(10, 5, .white, 2, 8, r: 2))
            n.addChild(circ(5, c, 12, 15))
            n.addChild(rect(4, 3, .white, 16, 13))
            n.addChild(rect(3, 6, c.darker(0.7), 10, 18))
            n.addChild(rect(3, 8, c, -11, 15))
            n.addChild(circ(1, .white, 14, 16))
            return n
        }
    }

    // MARK: Obstacles (base at y = 0)

    static let carColors: [UIColor] = [rgb(0.9, 0.2, 0.2), rgb(0.2, 0.45, 0.9), rgb(0.95, 0.8, 0.2), rgb(0.25, 0.7, 0.35), rgb(0.6, 0.3, 0.75), UIColor(white: 0.92, alpha: 1)]

    private static func wheels(_ n: SKNode, _ xs: [CGFloat], r: CGFloat = 7) {
        for x in xs {
            n.addChild(circ(r, UIColor(white: 0.12, alpha: 1), x, r))
            n.addChild(circ(r * 0.42, UIColor(white: 0.7, alpha: 1), x, r))
        }
    }

    static func obstacle(_ kind: ObKind) -> SKNode {
        let n = SKNode()
        switch kind {
        case .fence:
            let wood = rgb(0.75, 0.6, 0.4)
            for x in stride(from: -24, through: 24, by: 12) as StrideThrough<CGFloat> { n.addChild(rect(3.5, 20, wood, x, 10)) }
            n.addChild(rect(56, 3, wood, 0, 15))
            n.addChild(rect(56, 3, wood, 0, 7))
        case .shed:
            n.addChild(rect(42, 26, rgb(0.6, 0.4, 0.25), 0, 13))
            n.addChild(tri(CGPoint(x: -26, y: 26), CGPoint(x: 26, y: 26), CGPoint(x: 0, y: 40), rgb(0.35, 0.3, 0.28)))
            n.addChild(rect(12, 18, rgb(0.4, 0.25, 0.15), 0, 9))
        case .barrel:
            n.addChild(rect(15, 20, rgb(0.85, 0.3, 0.15), 0, 10, r: 3))
            n.addChild(rect(16, 2, dark, 0, 5))
            n.addChild(rect(16, 2, dark, 0, 15))
            n.addChild(tri(CGPoint(x: -3, y: 8), CGPoint(x: 3, y: 8), CGPoint(x: 0, y: 13), .yellow))
        case .car, .police:
            let col = kind == .police ? UIColor(white: 0.95, alpha: 1) : (carColors.randomElement() ?? .red)
            n.addChild(rect(64, 16, col, 0, 13, r: 5))
            n.addChild(rect(34, 13, col, -2, 26, r: 5))
            n.addChild(rect(26, 8, rgb(0.7, 0.9, 1), -2, 26, r: 2))
            if kind == .police {
                n.addChild(rect(64, 5, rgb(0.1, 0.15, 0.4), 0, 12))
                let red = rect(6, 4, .red, -5, 34, r: 1)
                let blue = rect(6, 4, .blue, 5, 34, r: 1)
                red.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)])))
                blue.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.2), .fadeAlpha(to: 0.2, duration: 0.2)])))
                n.addChild(red); n.addChild(blue)
            }
            n.addChild(rect(4, 4, .yellow, -31, 15))
            wheels(n, [-20, 20])
        case .jeep:
            let g = rgb(0.38, 0.45, 0.28)
            n.addChild(rect(60, 18, g, 0, 15, r: 3))
            n.addChild(rect(28, 14, g, 8, 30, r: 2))
            n.addChild(rect(20, 8, rgb(0.6, 0.75, 0.8), 4, 30, r: 1))
            n.addChild(rect(3, 18, dark, 22, 36))
            n.addChild(circ(5, UIColor(white: 0.9, alpha: 1), 4, 15))
            wheels(n, [-20, 20], r: 8)
        case .truck:
            let c = carColors.randomElement() ?? .blue
            n.addChild(rect(54, 26, UIColor(white: 0.85, alpha: 1), 10, 20, r: 2))
            n.addChild(rect(26, 22, c, -30, 18, r: 4))
            n.addChild(rect(12, 9, rgb(0.7, 0.9, 1), -36, 22, r: 2))
            wheels(n, [-30, 6, 24])
        case .fireTruck:
            let r = rgb(0.85, 0.12, 0.1)
            n.addChild(rect(88, 22, r, 0, 18, r: 3))
            n.addChild(rect(22, 12, rgb(0.7, 0.9, 1), -30, 26, r: 2))
            n.addChild(rect(56, 3, UIColor(white: 0.85, alpha: 1), 10, 33))
            for x in stride(from: -14, through: 34, by: 8) as StrideThrough<CGFloat> { n.addChild(rect(1.5, 6, UIColor(white: 0.85, alpha: 1), x, 33)) }
            let siren = rect(8, 4, rgb(0.3, 0.6, 1), -30, 31, r: 1)
            siren.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)])))
            n.addChild(siren)
            wheels(n, [-30, 20, 34])
        case .tank:
            let green = rgb(0.3, 0.4, 0.25)
            let b = SKNode()
            b.name = "barrel"
            b.position = CGPoint(x: 0, y: 26)
            b.zRotation = 0.9
            b.addChild(rect(28, 5, UIColor(white: 0.25, alpha: 1), 14, 0))
            n.addChild(b)
            n.addChild(rect(56, 14, green, 0, 13, r: 4))
            n.addChild(rect(26, 11, green, 0, 25, r: 4))
            n.addChild(rect(60, 9, dark, 0, 5, r: 4))
            for x in stride(from: -22, through: 22, by: 11) as StrideThrough<CGFloat> { n.addChild(circ(3, UIColor(white: 0.35, alpha: 1), x, 5)) }
            n.addChild(circ(3.5, .white, -12, 14))
            n.addChild(circ(2, .red, -12, 14))
        case .windmill:
            n.addChild(tri(CGPoint(x: -14, y: 0), CGPoint(x: 14, y: 0), CGPoint(x: 0, y: 70), UIColor(white: 0.85, alpha: 1)))
            let blades = SKNode()
            blades.position = CGPoint(x: 0, y: 64)
            for k in 0..<4 {
                let bl = rect(4, 30, UIColor(white: 0.95, alpha: 1), 0, 15)
                let holder = SKNode()
                holder.zRotation = CGFloat(k) * .pi / 2
                holder.addChild(bl)
                blades.addChild(holder)
            }
            blades.addChild(circ(4, dark))
            blades.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 4)))
            n.addChild(blades)
        case .silo:
            n.addChild(rect(30, 62, rgb(0.75, 0.75, 0.78), 0, 31))
            n.addChild(ell(30, 18, rgb(0.6, 0.6, 0.65), 0, 62))
            for y in stride(from: 10, through: 52, by: 14) as StrideThrough<CGFloat> { n.addChild(rect(30, 1.5, UIColor(white: 0.55, alpha: 1), 0, y)) }
        case .house:
            n.addChild(rect(58, 36, rgb(0.95, 0.88, 0.7), 0, 18))
            n.addChild(tri(CGPoint(x: -36, y: 36), CGPoint(x: 36, y: 36), CGPoint(x: 0, y: 62), rgb(0.55, 0.2, 0.2)))
            n.addChild(rect(10, 16, rgb(0.4, 0.25, 0.12), -14, 8))
            n.addChild(rect(11, 11, rgb(1, 0.95, 0.55), 12, 22))
            n.addChild(rect(6, 12, rgb(0.5, 0.25, 0.2), 18, 58))
        case .barn:
            let red = rgb(0.72, 0.15, 0.12)
            n.addChild(rect(84, 44, red, 0, 22))
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: -48, y: 44))
            roof.addLine(to: CGPoint(x: -30, y: 64))
            roof.addLine(to: CGPoint(x: 30, y: 64))
            roof.addLine(to: CGPoint(x: 48, y: 44))
            roof.closeSubpath()
            let r = SKShapeNode(path: roof)
            r.fillColor = rgb(0.35, 0.3, 0.3); r.strokeColor = .clear
            n.addChild(r)
            n.addChild(rect(26, 30, .white, 0, 15))
            n.addChild(rect(22, 26, red.darker(0.8), 0, 15))
            n.addChild(rect(30, 2, .white, 0, 15).rotated(0.85))
            n.addChild(rect(30, 2, .white, 0, 15).rotated(-0.85))
            n.addChild(rect(12, 9, .white, 0, 48))
        }
        return n
    }

    // MARK: Collectables & signs

    static func coin() -> SKNode {
        let n = SKNode()
        n.addChild(circ(7, rgb(0.85, 0.6, 0.1)))
        n.addChild(circ(5.5, rgb(1, 0.85, 0.25)))
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = "$"
        l.fontSize = 9
        l.fontColor = rgb(0.75, 0.5, 0.05)
        l.verticalAlignmentMode = .center
        n.addChild(l)
        n.run(.repeatForever(.sequence([.scaleX(to: 0.2, duration: 0.3), .scaleX(to: 1, duration: 0.3)])))
        return n
    }

    static func sign(_ meters: Int) -> SKNode {
        let n = SKNode()
        n.addChild(rect(4, 34, rgb(0.5, 0.35, 0.2), 0, 17))
        n.addChild(rect(56, 22, rgb(0.15, 0.5, 0.25), 0, 38, r: 3))
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = "\(meters)m"
        l.fontSize = 13
        l.fontColor = .white
        l.verticalAlignmentMode = .center
        l.position = CGPoint(x: 0, y: 38)
        n.addChild(l)
        return n
    }

    static func capsule(_ t: PowerType) -> SKNode {
        let n = SKNode()
        let txt: String
        switch t {
        case .rampage: txt = "R"
        case .magnet: txt = "M"
        case .multiply: txt = "x2"
        }
        n.addChild(circ(17, t.color.withAlphaComponent(0.35)))
        n.addChild(circ(12, t.color))
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = txt
        l.fontSize = 13
        l.fontColor = (t == .multiply) ? .black : .white
        l.verticalAlignmentMode = .center
        n.addChild(l)
        n.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.5), .scale(to: 0.95, duration: 0.5)])))
        return n
    }

    static func missile() -> SKNode {
        let n = SKNode()
        n.addChild(ell(14, 7, UIColor.orange.withAlphaComponent(0.9), -12, 0))
        n.addChild(rect(18, 7, rgb(0.85, 0.15, 0.15), 0, 0, r: 3))
        n.addChild(tri(CGPoint(x: 9, y: 4), CGPoint(x: 9, y: -4), CGPoint(x: 17, y: 0), UIColor(white: 0.9, alpha: 1)))
        return n
    }

    static func bird() -> SKNode {
        let n = SKNode()
        let c = UIColor(white: 0.12, alpha: 1)
        n.addChild(ell(12, 5, c))
        n.addChild(tri(CGPoint(x: -3, y: 1), CGPoint(x: 3, y: 1), CGPoint(x: 0, y: 9), c))
        n.run(.repeatForever(.sequence([.scaleY(to: 0.4, duration: 0.18), .scaleY(to: 1, duration: 0.18)])))
        return n
    }

    static func debris(_ color: UIColor) -> SKShapeNode {
        return rect(CGFloat.random(in: 4...10), CGFloat.random(in: 3...7), color)
    }

    // MARK: Scenery

    static func tree() -> SKNode {
        let n = SKNode()
        n.addChild(rect(6, 18, UIColor(red: 0.35, green: 0.22, blue: 0.1, alpha: 1), 0, 9))
        n.addChild(circ(15, UIColor(red: 0.13, green: 0.5, blue: 0.22, alpha: 1), 0, 28))
        n.addChild(circ(11, UIColor(red: 0.18, green: 0.58, blue: 0.27, alpha: 1), -8, 22))
        return n
    }

    static func house() -> SKNode {
        let n = SKNode()
        let wall = [UIColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 1), UIColor(red: 0.75, green: 0.85, blue: 0.95, alpha: 1), UIColor(red: 0.95, green: 0.75, blue: 0.75, alpha: 1)].randomElement() ?? .white
        n.addChild(rect(50, 32, wall, 0, 16))
        n.addChild(tri(CGPoint(x: -32, y: 32), CGPoint(x: 32, y: 32), CGPoint(x: 0, y: 56), UIColor(red: 0.6, green: 0.2, blue: 0.2, alpha: 1)))
        n.addChild(rect(9, 14, UIColor(red: 0.4, green: 0.25, blue: 0.12, alpha: 1), -10, 7))
        n.addChild(rect(10, 10, UIColor(red: 1, green: 0.95, blue: 0.55, alpha: 1), 12, 20))
        return n
    }

    static func cloud() -> SKNode {
        let n = SKNode()
        let c = UIColor(white: 1, alpha: 0.85)
        n.addChild(ell(70, 22, c))
        n.addChild(ell(44, 24, c, -12, 8))
        n.addChild(ell(40, 20, c, 18, 6))
        return n
    }

    static func gradient(size: CGSize, top: UIColor, bottom: UIColor) -> SKTexture {
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { ctx in
            let cs = CGColorSpaceCreateDeviceRGB()
            if let g = CGGradient(colorsSpace: cs, colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        return SKTexture(image: img)
    }
}

extension UIColor {
    func darker(_ f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: r * f, green: g * f, blue: b * f, alpha: a)
        }
        var w: CGFloat = 0
        getWhite(&w, alpha: &a)
        return UIColor(white: w * f, alpha: a)
    }
}

extension SKNode {
    func rotated(_ a: CGFloat) -> Self {
        zRotation = a
        return self
    }
}
