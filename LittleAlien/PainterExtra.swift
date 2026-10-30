import UIKit
import SpriteKit

/// Extra painted art: new creatures, city/desert props, enemies and biome backdrops.
extension Painter {

    // MARK: Creatures

    static func camel() -> SKTexture {
        return texture("camel", CGSize(width: 96, height: 84)) { ctx, _ in
            let b = c(0.78, 0.6, 0.38)
            ball(ctx, rr(44, 34, 52, 22, 10), b, light: 1.15, dark: 0.6, rect: CGRect(x: 18, y: 23, width: 52, height: 22))
            ball(ctx, ell(38, 48, 22, 18), b, light: 1.2, dark: 0.65, rect: CGRect(x: 27, y: 39, width: 22, height: 18))
            ball(ctx, ell(54, 46, 18, 14), b, light: 1.2, dark: 0.65, rect: CGRect(x: 45, y: 39, width: 18, height: 14))
            // saddle blanket
            linear(ctx, rr(46, 40, 18, 8, 2), [c(0.85, 0.15, 0.15), c(0.55, 0.05, 0.08)], CGPoint(x: 0, y: 44), CGPoint(x: 0, y: 36))
            fill(ctx, rr(46, 37, 18, 1.6, 0.8), c(1, 0.85, 0.3))
            // neck + head
            let neck = poly([CGPoint(x: 64, y: 36), CGPoint(x: 72, y: 38), CGPoint(x: 80, y: 62), CGPoint(x: 73, y: 64)])
            linear(ctx, neck, [b.darker(1.1), b.darker(0.7)], CGPoint(x: 64, y: 0), CGPoint(x: 80, y: 0))
            ball(ctx, rr(82, 64, 18, 10, 5), b, rect: CGRect(x: 73, y: 59, width: 18, height: 10))
            fill(ctx, ell(80, 67, 4, 4.5), .white)
            fill(ctx, ell(80.6, 66.6, 2, 2.4), .black)
            fill(ctx, ell(90, 62, 2, 1.4), c(0.3, 0.2, 0.1))
            fill(ctx, ell(76, 71, 4, 3), b.darker(0.8))
            stroke(ctx, line(CGPoint(x: 19, y: 38), CGPoint(x: 15, y: 26)), b.darker(0.6), 2)
        }
    }

    static func heart() -> SKTexture {
        return texture("heart", CGSize(width: 48, height: 46)) { ctx, _ in
            radial(ctx, ell(24, 24, 48, 46), [c(1, 0.3, 0.4, 0.55), c(1, 0.2, 0.3, 0)], CGPoint(x: 24, y: 24), 24)
            let h = CGMutablePath()
            h.move(to: CGPoint(x: 24, y: 8))
            h.addCurve(to: CGPoint(x: 8, y: 30), control1: CGPoint(x: 14, y: 16), control2: CGPoint(x: 6, y: 22))
            h.addCurve(to: CGPoint(x: 24, y: 32), control1: CGPoint(x: 10, y: 40), control2: CGPoint(x: 22, y: 40))
            h.addCurve(to: CGPoint(x: 40, y: 30), control1: CGPoint(x: 26, y: 40), control2: CGPoint(x: 38, y: 40))
            h.addCurve(to: CGPoint(x: 24, y: 8), control1: CGPoint(x: 42, y: 22), control2: CGPoint(x: 34, y: 16))
            h.closeSubpath()
            glow(ctx, c(1, 0.25, 0.35), 6) { fill(ctx, h, c(0.9, 0.12, 0.2)) }
            radial(ctx, h, [c(1, 0.55, 0.6), c(0.92, 0.15, 0.25), c(0.55, 0.03, 0.1)], CGPoint(x: 17, y: 30), 22, [0, 0.45, 1])
            stroke(ctx, h, c(1, 0.85, 0.88, 0.8), 1.2)
            fill(ctx, ell(15, 31, 6, 4), c(1, 1, 1, 0.75))
        }
    }

    // MARK: Props

    static func powerPole() -> SKTexture {
        return texture("pole", CGSize(width: 40, height: 132)) { ctx, _ in
            let w = c(0.32, 0.23, 0.16)
            let r = CGRect(x: 17, y: 0, width: 6, height: 124)
            wood(ctx, CGPath(rect: r, transform: nil), w, horizontal: false, rect: r)
            let bar = CGRect(x: 2, y: 112, width: 36, height: 4)
            wood(ctx, CGPath(rect: bar, transform: nil), w.darker(0.9), horizontal: true, rect: bar)
            for x in [5, 20, 35] as [CGFloat] {
                fill(ctx, rr(x, 119, 3.6, 6, 1.5), c(0.55, 0.75, 0.6))
            }
        }
    }

    static func building(_ v: Int) -> SKTexture {
        return texture("bld\(v)", CGSize(width: 110, height: 156)) { ctx, _ in
            let walls = [c(0.22, 0.24, 0.34), c(0.3, 0.22, 0.24), c(0.18, 0.26, 0.3)]
            let wcol = walls[v % 3]
            let r = CGRect(x: 6, y: 2, width: 98, height: 146)
            linear(ctx, CGPath(rect: r, transform: nil), [wcol.darker(0.7), wcol.darker(1.2), wcol.darker(0.6)], CGPoint(x: 6, y: 0), CGPoint(x: 104, y: 0))
            fill(ctx, CGPath(rect: CGRect(x: 4, y: 146, width: 102, height: 5), transform: nil), wcol.darker(0.5))
            var rng = SeededRNG(seed: UInt64(17 + v))
            for row in 0..<9 {
                for col in 0..<5 {
                    let x = 18 + CGFloat(col) * 18.5, y = 20 + CGFloat(row) * 14
                    let on = Int.random(in: 0..<10, using: &rng) < 6
                    if on {
                        glow(ctx, c(1, 0.8, 0.35), 5) { fill(ctx, CGPath(rect: CGRect(x: x - 5, y: y - 4, width: 10, height: 8), transform: nil), c(1, 0.85, 0.45)) }
                    } else {
                        fill(ctx, CGPath(rect: CGRect(x: x - 5, y: y - 4, width: 10, height: 8), transform: nil), c(0.08, 0.1, 0.16))
                    }
                }
            }
            fill(ctx, rr(55, 9, 18, 14, 1), c(0.12, 0.1, 0.1))
            glow(ctx, c(1, 0.85, 0.5), 6) { fill(ctx, rr(55, 18, 22, 2, 1), c(1, 0.9, 0.6)) }
        }
    }

    static func lamp() -> SKTexture {
        return texture("lamp", CGSize(width: 50, height: 104)) { ctx, _ in
            let m = c(0.25, 0.27, 0.32)
            linear(ctx, CGPath(rect: CGRect(x: 22, y: 0, width: 5, height: 92), transform: nil), [m.darker(0.6), m.darker(1.5), m.darker(0.6)], CGPoint(x: 22, y: 0), CGPoint(x: 27, y: 0))
            stroke(ctx, line(CGPoint(x: 25, y: 92), CGPoint(x: 38, y: 96)), m, 3)
            radial(ctx, ell(38, 86, 30, 30), [c(1, 0.9, 0.55, 0.65), c(1, 0.8, 0.4, 0)], CGPoint(x: 38, y: 88), 15)
            fill(ctx, rr(38, 94, 14, 5, 2), m.darker(0.8))
            glow(ctx, c(1, 0.85, 0.5), 8) { fill(ctx, ell(38, 91, 9, 3.5), c(1, 0.95, 0.75)) }
        }
    }

    static func hydrant() -> SKTexture {
        return texture("hydrant", CGSize(width: 24, height: 28)) { ctx, _ in
            let r = c(0.85, 0.15, 0.12)
            ball(ctx, rr(12, 11, 12, 18, 4), r, rect: CGRect(x: 6, y: 2, width: 12, height: 18))
            ball(ctx, ell(12, 21, 12, 8), r, rect: CGRect(x: 6, y: 17, width: 12, height: 8))
            fill(ctx, rr(12, 13, 20, 4, 2), r.darker(0.75))
        }
    }

    static func tent() -> SKTexture {
        return texture("tent", CGSize(width: 96, height: 56)) { ctx, _ in
            let cloth = c(0.2, 0.14, 0.1)
            linear(ctx, poly([CGPoint(x: 4, y: 4), CGPoint(x: 92, y: 4), CGPoint(x: 80, y: 34), CGPoint(x: 48, y: 46), CGPoint(x: 16, y: 34)]),
                   [cloth.darker(1.6), cloth], CGPoint(x: 0, y: 46), CGPoint(x: 0, y: 4))
            for x in stride(from: 10, through: 86, by: 8) as StrideThrough<CGFloat> {
                stroke(ctx, line(CGPoint(x: x, y: 5), CGPoint(x: 48 + (x - 48) * 0.7, y: 40)), c(0.75, 0.55, 0.3, 0.5), 1)
            }
            glow(ctx, c(1, 0.6, 0.2), 10) { fill(ctx, poly([CGPoint(x: 40, y: 4), CGPoint(x: 56, y: 4), CGPoint(x: 48, y: 26)]), c(1, 0.7, 0.3)) }
            for x in [10, 86] as [CGFloat] { stroke(ctx, line(CGPoint(x: x, y: 36), CGPoint(x: x, y: 0)), c(0.4, 0.28, 0.15), 2) }
        }
    }

    static func palm() -> SKTexture {
        return texture("palm", CGSize(width: 90, height: 130)) { ctx, _ in
            let trunk = CGMutablePath()
            trunk.move(to: CGPoint(x: 40, y: 0))
            trunk.addQuadCurve(to: CGPoint(x: 48, y: 104), control: CGPoint(x: 34, y: 60))
            trunk.addLine(to: CGPoint(x: 54, y: 104))
            trunk.addQuadCurve(to: CGPoint(x: 48, y: 0), control: CGPoint(x: 42, y: 60))
            trunk.closeSubpath()
            linear(ctx, trunk, [c(0.5, 0.36, 0.2), c(0.3, 0.2, 0.1)], CGPoint(x: 36, y: 0), CGPoint(x: 52, y: 0))
            for k in 0..<12 { stroke(ctx, line(CGPoint(x: 38 + CGFloat(k) * 0.8, y: CGFloat(k) * 8 + 4), CGPoint(x: 46 + CGFloat(k) * 0.6, y: CGFloat(k) * 8 + 6)), c(0.22, 0.14, 0.07), 1) }
            for k in 0..<7 {
                let a = CGFloat(k) / 6 * .pi
                let tip = CGPoint(x: 51 + cos(a) * 42, y: 104 + sin(a) * 18 - 14)
                let f = CGMutablePath()
                f.move(to: CGPoint(x: 51, y: 106))
                f.addQuadCurve(to: tip, control: CGPoint(x: 51 + cos(a) * 24, y: 124))
                f.addQuadCurve(to: CGPoint(x: 51, y: 102), control: CGPoint(x: 51 + cos(a) * 20, y: 108))
                f.closeSubpath()
                linear(ctx, f, [c(0.25, 0.55, 0.25), c(0.1, 0.3, 0.12)], CGPoint(x: 0, y: 124), CGPoint(x: 0, y: 90))
            }
            for x in [47, 55] as [CGFloat] { ball(ctx, ell(x, 101, 6, 6), c(0.45, 0.3, 0.12), rect: CGRect(x: x - 3, y: 98, width: 6, height: 6)) }
        }
    }

    static func pumpkin() -> SKTexture {
        return texture("pumpkin", CGSize(width: 40, height: 34)) { ctx, _ in
            for (x, w) in [(12, 14), (28, 14), (20, 18)] as [(CGFloat, CGFloat)] {
                ball(ctx, ell(x, 14, w, 22), c(1, 0.5, 0.08), light: 1.2, dark: 0.55, rect: CGRect(x: x - w / 2, y: 3, width: w, height: 22))
            }
            fill(ctx, rr(20, 27, 4, 7, 1.5), c(0.3, 0.45, 0.12))
            let lit = c(1, 0.92, 0.4)
            glow(ctx, c(1, 0.8, 0.2), 6) {
                fill(ctx, poly([CGPoint(x: 12, y: 15), CGPoint(x: 17, y: 15), CGPoint(x: 14.5, y: 20)]), lit)
                fill(ctx, poly([CGPoint(x: 23, y: 15), CGPoint(x: 28, y: 15), CGPoint(x: 25.5, y: 20)]), lit)
                fill(ctx, poly([CGPoint(x: 11, y: 10), CGPoint(x: 15, y: 7), CGPoint(x: 20, y: 9), CGPoint(x: 25, y: 7), CGPoint(x: 29, y: 10), CGPoint(x: 20, y: 6)]), lit)
            }
        }
    }

    static func bat() -> SKTexture {
        return texture("bat", CGSize(width: 40, height: 20)) { ctx, _ in
            let b = c(0.06, 0.05, 0.08)
            fill(ctx, poly([CGPoint(x: 20, y: 12), CGPoint(x: 2, y: 16), CGPoint(x: 6, y: 10), CGPoint(x: 10, y: 12), CGPoint(x: 13, y: 8), CGPoint(x: 20, y: 7),
                            CGPoint(x: 27, y: 8), CGPoint(x: 30, y: 12), CGPoint(x: 34, y: 10), CGPoint(x: 38, y: 16)]), b)
            fill(ctx, ell(20, 10, 6, 7), b)
            fill(ctx, ell(18.5, 11, 1.4, 1.4), c(1, 0.3, 0.2))
            fill(ctx, ell(21.5, 11, 1.4, 1.4), c(1, 0.3, 0.2))
        }
    }

    // MARK: Enemies in the sky

    static func duster() -> SKTexture {
        return texture("duster", CGSize(width: 120, height: 56)) { ctx, _ in
            let y = c(0.95, 0.75, 0.15)
            linear(ctx, rr(52, 26, 76, 16, 8), [y.darker(1.2), y.darker(0.6)], CGPoint(x: 0, y: 34), CGPoint(x: 0, y: 18))
            linear(ctx, rr(48, 40, 70, 5, 2), [y.darker(1.1), y.darker(0.7)], CGPoint(x: 0, y: 43), CGPoint(x: 0, y: 37))
            linear(ctx, rr(48, 14, 70, 5, 2), [y.darker(1.1), y.darker(0.7)], CGPoint(x: 0, y: 17), CGPoint(x: 0, y: 11))
            for x in [30, 66] as [CGFloat] { stroke(ctx, line(CGPoint(x: x, y: 16), CGPoint(x: x, y: 38)), c(0.3, 0.25, 0.2), 1.5) }
            fill(ctx, poly([CGPoint(x: 88, y: 26), CGPoint(x: 108, y: 30), CGPoint(x: 108, y: 44), CGPoint(x: 96, y: 34)]), y.darker(0.85))
            fill(ctx, ell(58, 34, 12, 8), c(0.4, 0.6, 0.8))
            fill(ctx, ell(14, 26, 6, 10), c(0.3, 0.3, 0.32))
            fill(ctx, ell(10, 26, 2, 30), c(0.8, 0.8, 0.85, 0.45))
            fill(ctx, ell(40, 8, 6, 6), c(0.1, 0.1, 0.1))
            fill(ctx, ell(64, 8, 6, 6), c(0.1, 0.1, 0.1))
        }
    }

    static func helicopter() -> SKTexture {
        return texture("heli", CGSize(width: 150, height: 70)) { ctx, _ in
            let g = c(0.22, 0.28, 0.2)
            ball(ctx, ell(58, 30, 70, 34), g, light: 1.3, dark: 0.5, rect: CGRect(x: 23, y: 13, width: 70, height: 34))
            linear(ctx, poly([CGPoint(x: 88, y: 30), CGPoint(x: 140, y: 34), CGPoint(x: 140, y: 40), CGPoint(x: 88, y: 40)]), [g.darker(1.2), g.darker(0.6)], CGPoint(x: 0, y: 40), CGPoint(x: 0, y: 30))
            fill(ctx, poly([CGPoint(x: 132, y: 34), CGPoint(x: 146, y: 52), CGPoint(x: 140, y: 34)]), g.darker(0.8))
            linear(ctx, ell(40, 34, 30, 18), [c(0.5, 0.75, 0.9), c(0.15, 0.25, 0.4)], CGPoint(x: 30, y: 42), CGPoint(x: 50, y: 26))
            stroke(ctx, line(CGPoint(x: 30, y: 8), CGPoint(x: 86, y: 8)), c(0.15, 0.15, 0.15), 2.5)
            stroke(ctx, line(CGPoint(x: 42, y: 8), CGPoint(x: 46, y: 16)), c(0.15, 0.15, 0.15), 2)
            stroke(ctx, line(CGPoint(x: 74, y: 8), CGPoint(x: 70, y: 16)), c(0.15, 0.15, 0.15), 2)
            fill(ctx, rr(58, 50, 6, 6, 1), c(0.2, 0.2, 0.2))
            glow(ctx, c(1, 0.2, 0.2), 6) { fill(ctx, ell(26, 24, 4, 4), c(1, 0.3, 0.3)) }
            fill(ctx, rr(62, 18, 12, 6, 2), c(0.15, 0.15, 0.15))
        }
    }

    static func rotor() -> SKTexture {
        return texture("rotor", CGSize(width: 150, height: 10)) { ctx, _ in
            fill(ctx, rr(75, 5, 148, 4, 2), c(0.12, 0.12, 0.12, 0.85))
            fill(ctx, rr(75, 5, 8, 8, 3), c(0.2, 0.2, 0.2))
        }
    }

    static func rainDrop() -> SKTexture {
        return texture("rain", CGSize(width: 3, height: 26), scale: Painter.screen) { ctx, _ in
            linear(ctx, rr(1.5, 13, 1.6, 24, 0.8), [c(0.75, 0.85, 1, 0), c(0.8, 0.9, 1, 0.75)], CGPoint(x: 0, y: 26), CGPoint(x: 0, y: 0))
        }
    }

    // MARK: Biome backdrops (tileable)

    static func skyline(_ size: CGSize) -> SKTexture {
        return texture("skyline\(Int(size.width))x\(Int(size.height))", size, scale: Painter.screen) { ctx, s in
            var rng = SeededRNG(seed: 31)
            for layer in 0..<2 {
                var x: CGFloat = 0
                let col = layer == 0 ? c(0.13, 0.15, 0.3) : c(0.07, 0.08, 0.17)
                while x < s.width {
                    let w = CGFloat.random(in: 18...46, using: &rng)
                    let h = s.height * CGFloat.random(in: layer == 0 ? 0.45...0.95 : 0.25...0.7, using: &rng)
                    for dx in [0, s.width] {
                        let r = CGRect(x: x - dx, y: 0, width: w, height: h)
                        fill(ctx, CGPath(rect: r, transform: nil), col)
                        if layer == 1 {
                            var yy: CGFloat = 6
                            while yy < h - 6 {
                                var xx = x - dx + 4
                                while xx < x - dx + w - 4 {
                                    if Int.random(in: 0..<10, using: &rng) < 3 {
                                        fill(ctx, CGPath(rect: CGRect(x: xx, y: yy, width: 2.5, height: 3), transform: nil), c(1, 0.85, 0.45, 0.85))
                                    }
                                    xx += 6
                                }
                                yy += 7
                            }
                        }
                    }
                    if layer == 0 && Int.random(in: 0..<5, using: &rng) == 0 {
                        glow(ctx, c(1, 0.2, 0.2), 4) { fill(ctx, ell(x + w / 2, h + 3, 3, 3), c(1, 0.3, 0.3)) }
                    }
                    x += w + CGFloat.random(in: 0...6, using: &rng)
                }
            }
        }
    }

    static func dunes(_ size: CGSize, seed: Int, top: UIColor, bottom: UIColor) -> SKTexture {
        return texture("dunes\(seed)_\(Int(size.width))x\(Int(size.height))", size, scale: Painter.screen) { ctx, s in
            var rng = SeededRNG(seed: UInt64(seed))
            let p = CGMutablePath()
            p.move(to: .zero)
            let k1 = CGFloat(Int.random(in: 2...3, using: &rng)), k2 = CGFloat(Int.random(in: 4...6, using: &rng))
            let ph = CGFloat.random(in: 0...6, using: &rng)
            var x: CGFloat = 0
            while x <= s.width {
                let h = 0.5 + 0.22 * sin(2 * .pi * k1 * x / s.width + ph) + 0.1 * sin(2 * .pi * k2 * x / s.width)
                p.addLine(to: CGPoint(x: x, y: s.height * h))
                x += 3
            }
            p.addLine(to: CGPoint(x: s.width, y: 0))
            p.closeSubpath()
            linear(ctx, p, [top, bottom], CGPoint(x: 0, y: s.height), CGPoint(x: 0, y: 0))
        }
    }

    static func ground(_ size: CGSize, biome: Biome) -> SKTexture {
        return texture("ground\(biome.rawValue)_\(Int(size.width))x\(Int(size.height))", size, scale: Painter.screen) { ctx, s in
            let all = CGPath(rect: CGRect(origin: .zero, size: s), transform: nil)
            var rng = SeededRNG(seed: 7)
            switch biome {
            case .city:
                linear(ctx, all, [c(0.22, 0.24, 0.32), c(0.14, 0.16, 0.22), c(0.06, 0.07, 0.1)], CGPoint(x: 0, y: s.height), CGPoint(x: 0, y: 0), [0, 0.4, 1])
                for _ in 0..<Int(s.width * s.height / 80) {
                    let x = CGFloat.random(in: 0...s.width, using: &rng), y = CGFloat.random(in: 0...s.height, using: &rng)
                    fill(ctx, CGPath(rect: CGRect(x: x, y: y, width: 1, height: 1), transform: nil), c(1, 1, 1, 0.05))
                }
            case .desert:
                linear(ctx, all, [c(0.42, 0.36, 0.42), c(0.36, 0.28, 0.24), c(0.22, 0.16, 0.12), c(0.08, 0.06, 0.05)],
                       CGPoint(x: 0, y: s.height), CGPoint(x: 0, y: 0), [0, 0.15, 0.55, 1])
                for _ in 0..<Int(s.width * s.height / 300) {
                    let x = CGFloat.random(in: 0...s.width, using: &rng), y = CGFloat.random(in: 0...s.height, using: &rng)
                    let w = CGFloat.random(in: 8...30, using: &rng) * (1.2 - y / s.height)
                    stroke(ctx, line(CGPoint(x: x, y: y), CGPoint(x: x + w, y: y + 1)), c(0.55, 0.45, 0.35, 0.18), 1)
                }
            case .farm:
                break
            }
        }
    }
}
