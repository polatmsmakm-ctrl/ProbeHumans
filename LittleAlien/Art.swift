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

    // MARK: Hero

    static func ufo() -> SKNode {
        let n = SKNode()
        n.addChild(circ(19, UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 0.55), 0, 12))
        n.addChild(ell(15, 18, UIColor(red: 0.35, green: 0.85, blue: 0.4, alpha: 1), 0, 12))
        n.addChild(circ(2.2, .black, -3.5, 14))
        n.addChild(circ(2.2, .black, 3.5, 14))
        n.addChild(ell(84, 26, UIColor(white: 0.55, alpha: 1), 0, -2))
        n.addChild(ell(84, 20, UIColor(white: 0.82, alpha: 1), 0, 1))
        for i in -2...2 {
            n.addChild(circ(3, UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1), CGFloat(i) * 15, -3))
        }
        n.addChild(ell(26, 8, UIColor(red: 0.5, green: 1, blue: 0.9, alpha: 0.9), 0, -13))
        return n
    }

    // MARK: Creatures (feet at y = 0)

    static func human() -> SKNode {
        let n = SKNode()
        let cols: [UIColor] = [.systemRed, .systemBlue, .systemOrange, .systemTeal, .systemPink, .systemIndigo]
        let shirt = cols.randomElement() ?? .systemRed
        n.addChild(rect(3, 10, UIColor(white: 0.2, alpha: 1), -2.5, 5))
        n.addChild(rect(3, 10, UIColor(white: 0.2, alpha: 1), 2.5, 5))
        n.addChild(rect(10, 14, shirt, 0, 17, r: 2))
        n.addChild(rect(3, 10, shirt, -7, 17))
        n.addChild(rect(3, 10, shirt, 7, 17))
        n.addChild(circ(5.5, UIColor(red: 0.96, green: 0.8, blue: 0.65, alpha: 1), 0, 29))
        return n
    }

    static func kid() -> SKNode {
        let n = human()
        n.setScale(0.7)
        return n
    }

    static func cow() -> SKNode {
        let n = SKNode()
        let leg = UIColor(white: 0.3, alpha: 1)
        for x in [-12, -6, 7, 13] as [CGFloat] { n.addChild(rect(3.5, 10, leg, x, 5)) }
        n.addChild(rect(36, 16, .white, 0, 18, r: 6))
        n.addChild(ell(9, 6, .black, -7, 21))
        n.addChild(ell(8, 6, .black, 7, 17))
        n.addChild(rect(12, 11, .white, 21, 25, r: 3))
        n.addChild(rect(8, 5, UIColor(red: 1, green: 0.7, blue: 0.7, alpha: 1), 25, 22))
        n.addChild(circ(1.4, .black, 22, 28))
        n.addChild(rect(2, 5, UIColor(white: 0.9, alpha: 1), 19, 33))
        return n
    }

    static func dog() -> SKNode {
        let n = SKNode()
        let c = UIColor(red: 0.7, green: 0.45, blue: 0.2, alpha: 1)
        for x in [-7, -3, 5, 8] as [CGFloat] { n.addChild(rect(2.5, 6, c, x, 3)) }
        n.addChild(rect(20, 9, c, 0, 10, r: 3))
        n.addChild(circ(5, c, 12, 15))
        n.addChild(rect(3, 6, UIColor(red: 0.45, green: 0.28, blue: 0.1, alpha: 1), 10, 15))
        n.addChild(rect(3, 8, c, -11, 15))
        n.addChild(circ(1, .black, 14, 16))
        return n
    }

    static func car(_ color: UIColor) -> SKNode {
        let n = SKNode()
        n.addChild(rect(64, 16, color, 0, 13, r: 5))
        n.addChild(rect(34, 13, color, -2, 26, r: 5))
        n.addChild(rect(26, 8, UIColor(red: 0.7, green: 0.9, blue: 1, alpha: 1), -2, 26, r: 2))
        n.addChild(circ(7, UIColor(white: 0.12, alpha: 1), -20, 7))
        n.addChild(circ(7, UIColor(white: 0.12, alpha: 1), 20, 7))
        n.addChild(circ(3, UIColor(white: 0.7, alpha: 1), -20, 7))
        n.addChild(circ(3, UIColor(white: 0.7, alpha: 1), 20, 7))
        n.addChild(rect(4, 4, .yellow, 31, 15))
        return n
    }

    static func creature(_ kind: Kind) -> SKNode {
        switch kind {
        case .human: return human()
        case .kid: return kid()
        case .cow: return cow()
        case .dog: return dog()
        case .car:
            let cols: [UIColor] = [.systemRed, .systemBlue, .systemYellow, .systemGreen, .systemPurple, .white]
            return car(cols.randomElement() ?? .systemRed)
        }
    }

    // MARK: Obstacles

    static func tank() -> SKNode {
        let n = SKNode()
        let green = UIColor(red: 0.3, green: 0.4, blue: 0.25, alpha: 1)
        let barrel = rect(24, 5, UIColor(white: 0.25, alpha: 1), 14, 0)
        let b = SKNode()
        b.position = CGPoint(x: 0, y: 24)
        b.zRotation = 0.9
        b.addChild(barrel)
        n.addChild(b)
        n.addChild(rect(46, 12, green, 0, 12, r: 4))
        n.addChild(rect(22, 9, green, 0, 22, r: 3))
        n.addChild(rect(50, 7, UIColor(white: 0.15, alpha: 1), 0, 4, r: 3))
        return n
    }

    static func missile() -> SKNode {
        let n = SKNode()
        n.addChild(ell(14, 7, UIColor.orange.withAlphaComponent(0.9), -12, 0))
        n.addChild(rect(18, 7, UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1), 0, 0, r: 3))
        n.addChild(tri(CGPoint(x: 9, y: 4), CGPoint(x: 9, y: -4), CGPoint(x: 17, y: 0), UIColor(white: 0.9, alpha: 1)))
        return n
    }

    static func bird() -> SKNode {
        let n = SKNode()
        let c = UIColor(white: 0.12, alpha: 1)
        n.addChild(ell(16, 7, c))
        n.addChild(tri(CGPoint(x: -3, y: 2), CGPoint(x: 3, y: 2), CGPoint(x: 0, y: 12), c))
        n.addChild(tri(CGPoint(x: -8, y: 1), CGPoint(x: -14, y: 1), CGPoint(x: -11, y: -1), UIColor.orange))
        n.run(.repeatForever(.sequence([.scaleY(to: 0.4, duration: 0.18), .scaleY(to: 1, duration: 0.18)])))
        return n
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
        let c = UIColor(white: 1, alpha: 0.14)
        n.addChild(ell(70, 22, c))
        n.addChild(ell(44, 24, c, -12, 8))
        n.addChild(ell(40, 20, c, 18, 6))
        return n
    }

    static func capsule(_ t: PowerType) -> SKNode {
        let n = SKNode()
        let col: UIColor
        let txt: String
        switch t {
        case .rampage: col = .systemRed; txt = "R"
        case .magnet: col = .systemBlue; txt = "M"
        case .multiply: col = .systemYellow; txt = "x2"
        }
        n.addChild(circ(17, col.withAlphaComponent(0.35)))
        n.addChild(circ(12, col))
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = txt
        l.fontSize = 13
        l.fontColor = (t == .multiply) ? .black : .white
        l.verticalAlignmentMode = .center
        n.addChild(l)
        n.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.5), .scale(to: 0.95, duration: 0.5)])))
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
