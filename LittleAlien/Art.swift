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

    // MARK: UFOs

    static let ufoNames = ["Casey", "Nick", "Marc", "Andres", "Tania"]

    static func ufo(_ index: Int) -> SKNode {
        let n = SKNode()
        let i = max(0, min(4, index))
        let rim: [UIColor] = [rgb(0.9, 0.2, 0.25), rgb(0.95, 0.55, 0.1), rgb(0.25, 0.5, 0.95), rgb(0.2, 0.7, 0.35), rgb(0.75, 0.3, 0.85)]
        let alien: [UIColor] = [rgb(0.95, 0.45, 0.75), rgb(0.55, 0.4, 0.95), rgb(0.6, 0.9, 0.3), rgb(0.95, 0.75, 0.2), rgb(0.35, 0.85, 0.85)]
        let r = rim[i], a = alien[i]

        // under-glow
        n.addChild(ell(40, 12, rgb(0.5, 1, 1, 0.8), 0, -14))
        // bottom hull
        n.addChild(ell(70, 22, rgb(0.55, 0.58, 0.65), 0, -6, stroke: outline))
        n.addChild(ell(46, 12, rgb(0.7, 0.72, 0.78), 0, -9))
        // rim (big red disc) with white stripe
        n.addChild(ell(104, 30, r.darker(0.7), 0, -1))
        n.addChild(ell(104, 27, r, 0, 1, stroke: outline))
        n.addChild(ell(88, 18, .white, 0, 3))
        n.addChild(ell(84, 14, r.darker(1.05), 0, 4))
        // metal ring with rivets around the dome
        n.addChild(ell(60, 16, rgb(0.7, 0.72, 0.8), 0, 8, stroke: outline))
        for k in 0..<7 {
            let ang = CGFloat(k) / 6 * .pi
            let x = cos(ang) * 26, y = 8 - sin(ang) * 5
            let rv = circ(2.3, rgb(0.45, 0.47, 0.55), x, y)
            n.addChild(rv)
        }
        // alien (blob with goggly eyes)
        let body = SKNode()
        body.position = CGPoint(x: 0, y: 14)
        body.addChild(ell(30, 26, a, 0, 6, stroke: a.darker(0.6)))
        body.addChild(ell(12, 6, a.darker(0.8), 0, -1))
        for ex in [-6.5, 6.5] as [CGFloat] {
            body.addChild(circ(6, .white, ex, 13, stroke: outline))
            body.addChild(circ(2.6, .black, ex + 1, 12))
            body.addChild(circ(0.9, .white, ex + 1.8, 13))
        }
        body.addChild(ell(8, 3, a.darker(0.5), 0, 4))
        if i == 1 || i == 3 {
            body.addChild(line(CGPoint(x: -5, y: 18), CGPoint(x: -9, y: 28), a.darker(0.7), 2))
            body.addChild(line(CGPoint(x: 5, y: 18), CGPoint(x: 9, y: 28), a.darker(0.7), 2))
            body.addChild(circ(2.5, a, -9, 28))
            body.addChild(circ(2.5, a, 9, 28))
        }
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1.5, duration: 0.5), .moveBy(x: 0, y: -1.5, duration: 0.5)])))
        n.addChild(body)
        // glass dome
        let dome = SKShapeNode(path: domePath(w: 46, h: 40))
        dome.fillColor = rgb(0.55, 0.9, 1, 0.33)
        dome.strokeColor = rgb(0.8, 1, 1, 0.8)
        dome.lineWidth = 1.5
        dome.position = CGPoint(x: 0, y: 9)
        n.addChild(dome)
        n.addChild(ell(10, 6, UIColor(white: 1, alpha: 0.6), -11, 35))
        // blinking lights on the rim
        for k in 0..<6 {
            let x = (CGFloat(k) - 2.5) * 15
            let y: CGFloat = -2 - abs(CGFloat(k) - 2.5) * -1.2
            let l = circ(2.6, rgb(1, 0.95, 0.5), x, y)
            l.run(.repeatForever(.sequence([.wait(forDuration: Double(k) * 0.1), .fadeAlpha(to: 0.25, duration: 0.3), .fadeAlpha(to: 1, duration: 0.3)])))
            n.addChild(l)
        }
        return n
    }

    private static func domePath(w: CGFloat, h: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -w / 2, y: 0))
        p.addCurve(to: CGPoint(x: 0, y: h), control1: CGPoint(x: -w / 2, y: h * 0.75), control2: CGPoint(x: -w * 0.28, y: h))
        p.addCurve(to: CGPoint(x: w / 2, y: 0), control1: CGPoint(x: w * 0.28, y: h), control2: CGPoint(x: w / 2, y: h * 0.75))
        p.addQuadCurve(to: CGPoint(x: -w / 2, y: 0), control: CGPoint(x: 0, y: -6))
        return p
    }

    // MARK: Creatures (feet at y = 0, facing right)

    private static func person(shirt: UIColor, pants: UIColor, hair: UIColor? = nil, hat: UIColor? = nil, beard: Bool = false) -> SKNode {
        let n = SKNode()
        n.addChild(shadow(18))
        let legs = SKNode()
        legs.name = "legs"
        legs.addChild(rect(4, 11, pants, -2.6, 5.5, r: 1.5))
        legs.addChild(rect(4, 11, pants, 2.6, 5.5, r: 1.5))
        legs.addChild(rect(5, 2.5, dark, -2.6, 0.5, r: 1))
        legs.addChild(rect(5, 2.5, dark, 3.4, 0.5, r: 1))
        n.addChild(legs)
        n.addChild(rect(12, 13, shirt, 0, 17, r: 3, stroke: outline))
        if pants != shirt {
            n.addChild(rect(9, 7, pants, 0, 14, r: 1))
            n.addChild(rect(1.6, 8, pants, -3.5, 19))
            n.addChild(rect(1.6, 8, pants, 3.5, 19))
        }
        let arm = SKNode()
        arm.name = "arm"
        arm.position = CGPoint(x: 5, y: 22)
        arm.addChild(rect(3.5, 10, shirt, 0, -5, r: 1.5))
        arm.addChild(circ(2.2, skin, 0, -10))
        n.addChild(arm)
        n.addChild(circ(6.5, skin, 0, 29, stroke: outline))
        n.addChild(circ(1.1, .black, 3, 30))
        n.addChild(ell(3, 2.4, skin.darker(0.85), 6, 28))
        if let h = hair { n.addChild(ell(12, 6, h, -1.5, 33)) }
        if beard {
            n.addChild(ell(10, 8, UIColor(white: 0.95, alpha: 1), 2, 25))
            n.addChild(ell(6, 2.5, UIColor(white: 0.95, alpha: 1), 3.5, 27.5))
        }
        if let hat = hat {
            n.addChild(ell(18, 3.5, hat, 0, 34))
            n.addChild(rect(10, 6, hat, 0, 37, r: 2.5))
        }
        return n
    }

    static func creature(_ kind: Kind, variant: Int) -> SKNode {
        switch kind {
        case .grumpa:
            // the grumpy old farmer with a pitchfork
            let n = person(shirt: rgb(0.35, 0.65, 0.3), pants: rgb(0.25, 0.4, 0.8), hair: UIColor(white: 0.92, alpha: 1), beard: true)
            let fork = SKNode()
            fork.name = "fork"
            fork.position = CGPoint(x: 8, y: 14)
            fork.addChild(rect(1.8, 34, rgb(0.55, 0.38, 0.2), 0, 12))
            fork.addChild(rect(9, 1.6, UIColor(white: 0.75, alpha: 1), 0, 29))
            for dx in [-4, 0, 4] as [CGFloat] { fork.addChild(rect(1.3, 7, UIColor(white: 0.75, alpha: 1), dx, 33)) }
            n.addChild(fork)
            return n
        case .farmer:
            return person(shirt: rgb(0.85, 0.3, 0.25), pants: rgb(0.2, 0.35, 0.7), hair: rgb(0.45, 0.28, 0.12), hat: rgb(0.2, 0.45, 0.85))
        case .fireman:
            return person(shirt: rgb(0.95, 0.75, 0.15), pants: rgb(0.95, 0.75, 0.15), hat: rgb(0.9, 0.15, 0.1))
        case .soldier:
            let n = person(shirt: rgb(0.35, 0.45, 0.25), pants: rgb(0.3, 0.38, 0.22), hat: rgb(0.28, 0.36, 0.2))
            n.addChild(rect(14, 2.8, dark, 4, 19))
            return n
        case .reporter:
            let n = person(shirt: rgb(0.3, 0.3, 0.42), pants: dark, hair: rgb(0.85, 0.65, 0.2))
            let cam = SKNode()
            cam.position = CGPoint(x: 10, y: 24)
            cam.addChild(rect(9, 7, dark, stroke: outline))
            cam.addChild(circ(2.2, rgb(0.6, 0.8, 1), 4.5, 0))
            let flash = rect(4, 3, .white, -1, 5)
            flash.name = "flash"
            cam.addChild(flash)
            n.addChild(cam)
            return n
        case .sheep:
            let n = SKNode()
            n.addChild(shadow(26))
            let wool: [UIColor] = [UIColor(white: 0.97, alpha: 1), UIColor(white: 0.22, alpha: 1), rgb(1, 0.82, 0.25)]
            let w = wool[variant % 3]
            let legs = SKNode()
            legs.name = "legs"
            for x in [-7, -3, 4, 8] as [CGFloat] { legs.addChild(rect(2.6, 8, dark, x, 4, r: 1)) }
            n.addChild(legs)
            for (x, y, r) in [(-8, 13, 6.5), (-2, 16, 7.5), (5, 15, 7), (-4, 10, 6.5), (4, 10, 6.5), (9, 12, 5.5)] as [(CGFloat, CGFloat, CGFloat)] {
                n.addChild(circ(r, w, x, y, stroke: w.darker(0.75)))
            }
            for (x, y, r) in [(-2, 16, 6.5), (5, 15, 6), (-4, 11, 5.5), (3, 11, 5.5)] as [(CGFloat, CGFloat, CGFloat)] {
                n.addChild(circ(r, w, x, y))
            }
            let head = SKNode()
            head.position = CGPoint(x: 13, y: 16)
            head.addChild(ell(9, 11, dark))
            head.addChild(ell(5, 3, dark, -5, 2))
            head.addChild(circ(1.3, .white, 2, 2))
            head.addChild(circ(4, w, -1, 6))
            n.addChild(head)
            if variant % 3 == 2 {
                let sp = circ(2, .white, -4, 20)
                sp.run(.repeatForever(.sequence([.fadeAlpha(to: 0.1, duration: 0.4), .fadeAlpha(to: 1, duration: 0.4)])))
                n.addChild(sp)
            }
            return n
        case .cow:
            let n = SKNode()
            n.addChild(shadow(44))
            let body: [UIColor] = [.white, rgb(0.55, 0.33, 0.18), rgb(0.72, 0.5, 0.95)]
            let spot: [UIColor] = [.black, rgb(0.32, 0.18, 0.08), rgb(0.42, 0.25, 0.65)]
            let b = body[variant % 3], s = spot[variant % 3]
            let legs = SKNode()
            legs.name = "legs"
            for x in [-13, -7, 8, 14] as [CGFloat] { legs.addChild(rect(4, 11, b.darker(0.9), x, 5.5, r: 1)) }
            for x in [-13, -7, 8, 14] as [CGFloat] { legs.addChild(rect(4.5, 3, dark, x, 1, r: 1)) }
            n.addChild(legs)
            n.addChild(rect(38, 18, b, 0, 19, r: 8, stroke: outline))
            n.addChild(ell(11, 8, s, -8, 22))
            n.addChild(ell(9, 7, s, 8, 16))
            n.addChild(ell(6, 5, s, 2, 25))
            n.addChild(ell(8, 6, rgb(1, 0.7, 0.75), 2, 10))
            let head = SKNode()
            head.position = CGPoint(x: 22, y: 25)
            head.addChild(rect(13, 13, b, 0, 0, r: 4, stroke: outline))
            head.addChild(ell(11, 7, rgb(1, 0.72, 0.75), 3, -4))
            head.addChild(circ(1.4, .black, 1, 3))
            head.addChild(rect(2.2, 5, UIColor(white: 0.95, alpha: 1), -3, 8))
            head.addChild(rect(2.2, 5, UIColor(white: 0.95, alpha: 1), 3, 8))
            head.addChild(ell(6, 3, s, -6, 4))
            n.addChild(head)
            n.addChild(line(CGPoint(x: -19, y: 22), CGPoint(x: -23, y: 12), b.darker(0.8), 2))
            return n
        case .pig:
            let n = SKNode()
            n.addChild(shadow(28))
            let col: [UIColor] = [rgb(1, 0.66, 0.74), rgb(0.55, 0.72, 0.42), UIColor(white: 0.6, alpha: 1)]
            let c = col[variant % 3]
            let legs = SKNode()
            legs.name = "legs"
            for x in [-8, -3, 4, 9] as [CGFloat] { legs.addChild(rect(3.2, 5, c.darker(0.8), x, 2.5)) }
            n.addChild(legs)
            n.addChild(ell(28, 17, c, 0, 11, stroke: outline))
            n.addChild(ell(7, 6, c.darker(0.85), 14, 11, stroke: outline))
            n.addChild(circ(0.9, .black, 13, 11))
            n.addChild(circ(0.9, .black, 15, 11))
            n.addChild(circ(1.1, .black, 9, 15))
            n.addChild(tri(CGPoint(x: 6, y: 17), CGPoint(x: 11, y: 18), CGPoint(x: 8, y: 23), c.darker(0.85)))
            n.addChild(line(CGPoint(x: -14, y: 13), CGPoint(x: -17, y: 16), c.darker(0.8), 1.5))
            if variant % 3 == 1 { n.addChild(ell(9, 5, rgb(0.35, 0.25, 0.15), -4, 7)) }
            return n
        case .dog:
            let n = SKNode()
            n.addChild(shadow(22))
            let c = rgb(0.22, 0.2, 0.2)
            let legs = SKNode()
            legs.name = "legs"
            for x in [-7, -3, 5, 8] as [CGFloat] { legs.addChild(rect(2.6, 7, c, x, 3.5)) }
            n.addChild(legs)
            n.addChild(rect(21, 9, c, 0, 11, r: 4, stroke: outline))
            n.addChild(rect(11, 5, .white, 2, 9, r: 2))
            n.addChild(circ(5.5, c, 12, 16, stroke: outline))
            n.addChild(rect(5, 3.5, .white, 16, 14, r: 1))
            n.addChild(rect(3, 6, c.darker(0.7), 10, 19))
            n.addChild(line(CGPoint(x: -10, y: 13), CGPoint(x: -14, y: 19), c, 2.5))
            n.addChild(circ(1, .white, 14, 17))
            return n
        }
    }

    // MARK: Obstacles (base at y = 0)

    static let carColors: [UIColor] = [rgb(0.8, 0.15, 0.2), rgb(0.2, 0.35, 0.75), rgb(0.9, 0.75, 0.25), rgb(0.2, 0.55, 0.45), rgb(0.12, 0.12, 0.15)]

    private static func wheels(_ n: SKNode, _ xs: [CGFloat], r: CGFloat = 6.5) {
        for x in xs {
            n.addChild(circ(r, UIColor(white: 0.08, alpha: 1), x, r))
            n.addChild(circ(r * 0.45, UIColor(white: 0.75, alpha: 1), x, r))
        }
    }

    private static func fiftiesCar(_ body: UIColor, roof: UIColor) -> SKNode {
        let n = SKNode()
        n.addChild(shadow(74))
        n.addChild(poly([CGPoint(x: -34, y: 6), CGPoint(x: 34, y: 6), CGPoint(x: 36, y: 15), CGPoint(x: 30, y: 19),
                         CGPoint(x: -26, y: 20), CGPoint(x: -36, y: 24), CGPoint(x: -37, y: 12)], body, stroke: outline))
        n.addChild(poly([CGPoint(x: -18, y: 19), CGPoint(x: 14, y: 19), CGPoint(x: 8, y: 30), CGPoint(x: -13, y: 30)], roof, stroke: outline))
        n.addChild(poly([CGPoint(x: -14, y: 20), CGPoint(x: -3, y: 20), CGPoint(x: -3, y: 28), CGPoint(x: -11, y: 28)], rgb(0.55, 0.75, 0.9)))
        n.addChild(poly([CGPoint(x: 0, y: 20), CGPoint(x: 11, y: 20), CGPoint(x: 6, y: 28), CGPoint(x: 0, y: 28)], rgb(0.55, 0.75, 0.9)))
        n.addChild(rect(70, 2, UIColor(white: 0.85, alpha: 1), 0, 12))
        n.addChild(rect(5, 4, rgb(1, 0.95, 0.6), 34, 14, r: 1))
        n.addChild(rect(3, 4, rgb(1, 0.2, 0.2), -36, 18, r: 1))
        wheels(n, [-22, 22])
        return n
    }

    static func obstacle(_ kind: ObKind) -> SKNode {
        let n = SKNode()
        switch kind {
        case .fence:
            let wood = rgb(0.32, 0.33, 0.36)
            n.addChild(shadow(84))
            for x in stride(from: -38, through: 38, by: 19) as StrideThrough<CGFloat> {
                n.addChild(rect(4, 22, wood, x, 11, r: 1, stroke: outline))
            }
            n.addChild(rect(84, 4, wood.darker(1.15), 0, 16, stroke: outline))
            n.addChild(rect(84, 4, wood.darker(1.15), 0, 7, stroke: outline))
        case .shed:
            n.addChild(shadow(54))
            let wall = rgb(0.2, 0.32, 0.6)
            n.addChild(rect(40, 26, wall, 0, 13, stroke: outline))
            n.addChild(poly([CGPoint(x: -26, y: 24), CGPoint(x: 0, y: 44), CGPoint(x: 26, y: 24)], rgb(0.12, 0.13, 0.2), stroke: outline))
            n.addChild(rect(12, 14, rgb(0.06, 0.06, 0.12), 0, 7, r: 5))
            for y in stride(from: 4, through: 22, by: 6) as StrideThrough<CGFloat> { n.addChild(rect(40, 1, wall.darker(0.8), 0, y)) }
        case .barrels:
            n.addChild(shadow(40))
            for (x, y) in [(-9, 0), (8, 0), (0, 3)] as [(CGFloat, CGFloat)] {
                let b = SKNode()
                b.position = CGPoint(x: x, y: y)
                b.addChild(rect(14, 19, rgb(0.82, 0.12, 0.15), 0, 9.5, r: 3, stroke: outline))
                b.addChild(ell(14, 5, rgb(0.6, 0.08, 0.1), 0, 19))
                b.addChild(rect(14, 1.6, dark, 0, 5))
                b.addChild(rect(14, 1.6, dark, 0, 14))
                n.addChild(b)
            }
        case .car:
            let c = carColors.randomElement() ?? .red
            return fiftiesCar(c, roof: c == carColors[4] ? UIColor(white: 0.85, alpha: 1) : c.darker(0.85))
        case .police:
            let car = fiftiesCar(UIColor(white: 0.12, alpha: 1), roof: .white)
            car.addChild(rect(30, 8, .white, 0, 13))
            car.addChild(circ(3.5, rgb(0.95, 0.8, 0.2), 0, 13))
            let red = rect(5, 4, .red, -4, 32, r: 1)
            let blue = rect(5, 4, rgb(0.2, 0.4, 1), 4, 32, r: 1)
            red.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.18), .fadeAlpha(to: 1, duration: 0.18)])))
            blue.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.18), .fadeAlpha(to: 0.15, duration: 0.18)])))
            car.addChild(red); car.addChild(blue)
            return car
        case .jeep:
            n.addChild(shadow(68))
            let g = rgb(0.33, 0.4, 0.24)
            n.addChild(rect(60, 16, g, 0, 14, r: 3, stroke: outline))
            n.addChild(rect(24, 12, g, -8, 27, r: 2, stroke: outline))
            n.addChild(rect(18, 7, rgb(0.55, 0.7, 0.75), -8, 28, r: 1))
            n.addChild(circ(5, UIColor(white: 0.95, alpha: 1), 6, 14))
            n.addChild(rect(3, 16, dark, 18, 30))
            wheels(n, [-19, 19], r: 7.5)
        case .truck:
            n.addChild(shadow(80))
            let c = [rgb(0.35, 0.45, 0.25), rgb(0.55, 0.35, 0.2), rgb(0.25, 0.4, 0.6)].randomElement() ?? .gray
            n.addChild(poly([CGPoint(x: -40, y: 6), CGPoint(x: 40, y: 6), CGPoint(x: 40, y: 18), CGPoint(x: 26, y: 20),
                             CGPoint(x: 22, y: 32), CGPoint(x: 6, y: 32), CGPoint(x: 4, y: 20), CGPoint(x: -40, y: 20)], c, stroke: outline))
            n.addChild(rect(12, 9, rgb(0.55, 0.75, 0.9), 15, 25, r: 1))
            n.addChild(rect(40, 3, c.darker(0.7), -18, 20))
            n.addChild(rect(5, 4, rgb(1, 0.95, 0.6), 38, 13))
            wheels(n, [-24, 26], r: 7)
        case .fireTruck:
            n.addChild(shadow(96))
            let r = rgb(0.85, 0.12, 0.1)
            n.addChild(rect(90, 22, r, 0, 17, r: 3, stroke: outline))
            n.addChild(rect(20, 10, rgb(0.6, 0.8, 0.95), 30, 23, r: 2))
            n.addChild(rect(56, 3, UIColor(white: 0.85, alpha: 1), -12, 32))
            for x in stride(from: -36, through: 12, by: 8) as StrideThrough<CGFloat> { n.addChild(rect(1.5, 6, UIColor(white: 0.85, alpha: 1), x, 31)) }
            let siren = rect(8, 4, rgb(0.3, 0.6, 1), 30, 30, r: 1)
            siren.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)])))
            n.addChild(siren)
            wheels(n, [-30, 20, 34])
        case .tank:
            n.addChild(shadow(70))
            let green = rgb(0.3, 0.38, 0.24)
            let b = SKNode()
            b.name = "barrel"
            b.position = CGPoint(x: 0, y: 26)
            b.zRotation = 0.9
            b.addChild(rect(30, 5, UIColor(white: 0.25, alpha: 1), 15, 0, stroke: outline))
            n.addChild(b)
            n.addChild(rect(58, 14, green, 0, 13, r: 4, stroke: outline))
            n.addChild(rect(28, 12, green, 0, 25, r: 5, stroke: outline))
            n.addChild(rect(62, 10, dark, 0, 5, r: 5))
            for x in stride(from: -24, through: 24, by: 12) as StrideThrough<CGFloat> { n.addChild(circ(3.2, UIColor(white: 0.35, alpha: 1), x, 5)) }
            n.addChild(circ(3.5, .white, -12, 14))
            n.addChild(circ(2, .red, -12, 14))
        case .windmill:
            n.addChild(shadow(36))
            let wood = rgb(0.45, 0.33, 0.25)
            n.addChild(line(CGPoint(x: -14, y: 0), CGPoint(x: -3, y: 86), wood, 2.5))
            n.addChild(line(CGPoint(x: 14, y: 0), CGPoint(x: 3, y: 86), wood, 2.5))
            for k in 0..<5 {
                let y0 = CGFloat(k) * 17, y1 = y0 + 17
                let x0 = 14 - y0 / 86 * 11, x1 = 14 - y1 / 86 * 11
                n.addChild(line(CGPoint(x: -x0, y: y0), CGPoint(x: x1, y: y1), wood, 1.2))
                n.addChild(line(CGPoint(x: x0, y: y0), CGPoint(x: -x1, y: y1), wood, 1.2))
            }
            let blades = SKNode()
            blades.position = CGPoint(x: 0, y: 90)
            for k in 0..<12 {
                let h = SKNode()
                h.zRotation = CGFloat(k) * .pi / 6
                h.addChild(rect(3.5, 16, rgb(0.85, 0.82, 0.75), 0, 12, stroke: outline))
                blades.addChild(h)
            }
            blades.addChild(circ(3.5, dark))
            blades.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 3)))
            n.addChild(blades)
            n.addChild(poly([CGPoint(x: -2, y: 88), CGPoint(x: -18, y: 92), CGPoint(x: -18, y: 84)], rgb(0.6, 0.6, 0.65)))
        case .silo:
            n.addChild(shadow(42))
            let m = rgb(0.68, 0.7, 0.74)
            n.addChild(rect(34, 70, m, 0, 35, stroke: outline))
            for x in stride(from: -14, through: 14, by: 4) as StrideThrough<CGFloat> {
                n.addChild(rect(1, 70, m.darker(abs(x) > 9 ? 0.75 : 0.88), x, 35))
            }
            n.addChild(rect(30, 6, m.darker(0.7), 0, 6))
            n.addChild(ell(34, 10, m.darker(0.9), 0, 70, stroke: outline))
            n.addChild(poly([CGPoint(x: -17, y: 70), CGPoint(x: 0, y: 84), CGPoint(x: 17, y: 70)], m.darker(0.8), stroke: outline))
            n.addChild(rect(6, 6, m.darker(0.6), 0, 86, r: 2))
        case .house:
            n.addChild(shadow(78))
            let wall = rgb(0.3, 0.45, 0.85)
            n.addChild(rect(60, 36, wall, 0, 18, stroke: outline))
            n.addChild(rect(8, 30, wall.darker(0.8), -26, 15))
            n.addChild(poly([CGPoint(x: -36, y: 34), CGPoint(x: -18, y: 62), CGPoint(x: 18, y: 62), CGPoint(x: 36, y: 34)], rgb(0.14, 0.15, 0.22), stroke: outline))
            n.addChild(rect(7, 14, rgb(0.25, 0.2, 0.2), 14, 64))
            let lit = rgb(1, 0.88, 0.35)
            for x in [-14, 0, 14] as [CGFloat] {
                n.addChild(rect(8, 9, lit, x, 24, stroke: outline))
                n.addChild(rect(8, 1, dark, x, 24))
            }
            n.addChild(rect(9, 14, rgb(0.15, 0.12, 0.12), -14, 7))
            n.addChild(rect(8, 8, lit, 0, 46, stroke: outline))
        case .barn:
            n.addChild(shadow(92))
            let red = rgb(0.68, 0.14, 0.12)
            n.addChild(rect(80, 44, red, 0, 22, stroke: outline))
            n.addChild(poly([CGPoint(x: -46, y: 42), CGPoint(x: -30, y: 64), CGPoint(x: 30, y: 64), CGPoint(x: 46, y: 42)], rgb(0.2, 0.2, 0.25), stroke: outline))
            for x in stride(from: -36, through: 36, by: 6) as StrideThrough<CGFloat> { n.addChild(rect(1, 44, red.darker(0.8), x, 22)) }
            n.addChild(rect(28, 30, .white, 0, 15))
            n.addChild(rect(24, 26, red.darker(0.85), 0, 15))
            n.addChild(rect(34, 2.2, .white, 0, 15).rotated(0.82))
            n.addChild(rect(34, 2.2, .white, 0, 15).rotated(-0.82))
            n.addChild(rect(12, 9, .white, 0, 50, stroke: outline))
            n.addChild(rect(9, 6, rgb(0.15, 0.1, 0.1), 0, 50))
        }
        return n
    }

    // MARK: Collectables, signs, decor

    static func coin() -> SKNode {
        let n = SKNode()
        n.addChild(shadow(12))
        let face = SKNode()
        face.position = CGPoint(x: 0, y: 8)
        face.addChild(circ(6.5, rgb(0.85, 0.55, 0.05), stroke: rgb(0.5, 0.3, 0)))
        face.addChild(circ(5, rgb(1, 0.82, 0.2)))
        face.addChild(circ(3, rgb(1, 0.9, 0.45)))
        face.run(.repeatForever(.sequence([.scaleX(to: 0.15, duration: 0.35), .scaleX(to: 1, duration: 0.35)])))
        n.addChild(face)
        return n
    }

    static func capsule(_ t: PowerType) -> SKNode {
        let n = SKNode()
        n.addChild(shadow(20))
        let orb = SKNode()
        orb.position = CGPoint(x: 0, y: 14)
        orb.addChild(circ(13, t.color.withAlphaComponent(0.3)))
        orb.addChild(circ(10, t.color, stroke: .white))
        let txt: String
        switch t {
        case .rampage: txt = "⚡︎"
        case .magnet: txt = "U"
        case .multiply: txt = "2X"
        }
        let l = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        l.text = txt
        l.fontSize = 12
        l.fontColor = .white
        l.verticalAlignmentMode = .center
        orb.addChild(l)
        orb.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.5), .moveBy(x: 0, y: -4, duration: 0.5)])))
        n.addChild(orb)
        return n
    }

    /// Wooden billboard with chalky text (tutorial / high score / distance signs).
    static func sign(_ lines: [String], wide: Bool = false) -> SKNode {
        let n = SKNode()
        let w: CGFloat = wide ? 150 : 110
        let h: CGFloat = CGFloat(lines.count) * 18 + 16
        let wood = rgb(0.12, 0.2, 0.24)
        n.addChild(rect(5, 40, wood.darker(0.8), -w * 0.3, 20))
        n.addChild(rect(5, 40, wood.darker(0.8), w * 0.3, 20))
        let board = SKNode()
        board.position = CGPoint(x: 0, y: 40 + h / 2)
        board.zRotation = -0.05
        board.addChild(rect(w, h, wood, 0, 0, r: 3, stroke: rgb(0.05, 0.1, 0.12)))
        for k in 0..<3 { board.addChild(rect(w, 1, wood.darker(0.75), 0, -h / 2 + CGFloat(k + 1) * h / 4)) }
        for (i, s) in lines.enumerated() {
            let l = SKLabelNode(fontNamed: "MarkerFelt-Wide")
            l.text = s
            l.fontSize = 15
            l.fontColor = rgb(0.75, 0.95, 1)
            l.verticalAlignmentMode = .center
            l.position = CGPoint(x: 0, y: h / 2 - 16 - CGFloat(i) * 18)
            board.addChild(l)
        }
        n.addChild(board)
        return n
    }

    static func tuft() -> SKNode {
        let n = SKNode()
        let c = rgb(0.05, 0.3, 0.32, 0.9)
        for k in 0..<4 {
            let x = CGFloat(k) * 2.4 - 3.6
            n.addChild(tri(CGPoint(x: x - 1.4, y: 0), CGPoint(x: x + 1.4, y: 0), CGPoint(x: x + CGFloat.random(in: -2...2), y: CGFloat.random(in: 4...8)), c))
        }
        return n
    }

    static func bush() -> SKNode {
        let n = SKNode()
        let c = rgb(0.06, 0.28, 0.3)
        n.addChild(circ(10, c, -8, 8))
        n.addChild(circ(13, c.darker(1.1), 4, 12))
        n.addChild(circ(9, c, 14, 7))
        return n
    }

    static func cloud() -> SKNode {
        let n = SKNode()
        let c = rgb(0.5, 0.42, 0.68)
        let hi = rgb(0.62, 0.55, 0.8)
        n.addChild(ell(110, 28, c, 0, 0))
        n.addChild(circ(20, c, -26, 10))
        n.addChild(circ(26, c, 2, 16))
        n.addChild(circ(18, c, 30, 8))
        n.addChild(circ(16, hi, -2, 24))
        n.addChild(circ(11, hi, -24, 18))
        return n
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
