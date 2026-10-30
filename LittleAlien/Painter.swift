import UIKit
import SpriteKit

/// Paints every texture in code with Core Graphics (gradients, glows, soft shading)
/// so the game has a painted night-farm look without any image files.
/// All drawing uses y-up coordinates (origin bottom-left) like SpriteKit.
enum Painter {
    private static var cache: [String: SKTexture] = [:]
    /// Native screen scale (3 on modern iPhones).
    static let screen: CGFloat = UIScreen.main.scale
    /// Characters, buildings and the saucer get drawn up to ~2x bigger than their canvas
    /// on screen, so they are painted at twice the screen scale to stay razor sharp.
    static let hi: CGFloat = min(6, UIScreen.main.scale * 2)
    private static let cs = CGColorSpaceCreateDeviceRGB()

    static func texture(_ key: String, _ size: CGSize, scale: CGFloat = Painter.hi, _ draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = scale
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { rc in
            let c = rc.cgContext
            c.translateBy(x: 0, y: size.height)
            c.scaleBy(x: 1, y: -1)
            draw(c, size)
        }
        let t = SKTexture(image: img)
        t.filteringMode = .linear
        cache[key] = t
        return t
    }

    /// Sprite whose anchor sits at `foot` (in canvas points).
    static func sprite(_ tex: SKTexture, canvas: CGSize, foot: CGPoint) -> SKSpriteNode {
        let s = SKSpriteNode(texture: tex, size: canvas)
        s.anchorPoint = CGPoint(x: foot.x / canvas.width, y: foot.y / canvas.height)
        return s
    }

    // MARK: Helpers

    static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    static func gradient(_ colors: [UIColor], _ locs: [CGFloat]? = nil) -> CGGradient {
        return CGGradient(colorsSpace: cs, colors: colors.map { $0.cgColor } as CFArray, locations: locs)!
    }

    static func linear(_ ctx: CGContext, _ path: CGPath, _ colors: [UIColor], _ p0: CGPoint, _ p1: CGPoint, _ locs: [CGFloat]? = nil) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient(colors, locs), start: p0, end: p1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    static func radial(_ ctx: CGContext, _ path: CGPath, _ colors: [UIColor], _ center: CGPoint, _ radius: CGFloat, _ locs: [CGFloat]? = nil) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawRadialGradient(gradient(colors, locs), startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }

    static func fill(_ ctx: CGContext, _ path: CGPath, _ color: UIColor) {
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    }

    static func stroke(_ ctx: CGContext, _ path: CGPath, _ color: UIColor, _ w: CGFloat) {
        ctx.addPath(path)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(w)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }

    static func glow(_ ctx: CGContext, _ color: UIColor, _ blur: CGFloat, _ body: () -> Void) {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: blur, color: color.cgColor)
        body()
        ctx.restoreGState()
    }

    static func ell(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        return CGPath(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), transform: nil)
    }

    static func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        return CGPath(roundedRect: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), cornerWidth: min(r, w / 2), cornerHeight: min(r, h / 2), transform: nil)
    }

    static func poly(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts)
        p.closeSubpath()
        return p
    }

    static func line(_ a: CGPoint, _ b: CGPoint) -> CGPath {
        let p = CGMutablePath()
        p.move(to: a)
        p.addLine(to: b)
        return p
    }

    /// Ball shaded from a top-left highlight to a darker rim.
    static func ball(_ ctx: CGContext, _ path: CGPath, _ base: UIColor, light: CGFloat = 1.25, dark: CGFloat = 0.6, rect: CGRect) {
        let hl = CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.7)
        radial(ctx, path, [base.darker(light), base, base.darker(dark)], hl, max(rect.width, rect.height) * 0.85, [0, 0.45, 1])
    }

    static func shaded(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ base: UIColor, light: CGFloat = 1.25, dark: CGFloat = 0.6) {
        ball(ctx, ell(x, y, w, h), base, light: light, dark: dark, rect: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
    }

    // MARK: - UFO

    static let neon: [UIColor] = [c(0.72, 0.42, 1), c(0.3, 0.85, 1), c(0.45, 1, 0.55), c(1, 0.62, 0.2), c(1, 0.4, 0.78)]
    static let ufoCanvas = CGSize(width: 220, height: 132)
    static let ufoFoot = CGPoint(x: 110, y: 52)

    static func ufo(_ i: Int) -> SKTexture {
        let n = neon[max(0, min(4, i))]
        return texture("ufo\(i)", ufoCanvas) { ctx, _ in
            // emitter glow underneath
            radial(ctx, ell(110, 28, 120, 40), [n.withAlphaComponent(0.85), n.withAlphaComponent(0)], CGPoint(x: 110, y: 28), 60)
            // lower hull
            linear(ctx, ell(110, 40, 128, 38), [c(0.26, 0.28, 0.4), c(0.07, 0.08, 0.13)], CGPoint(x: 0, y: 59), CGPoint(x: 0, y: 21))
            // emitter ring
            glow(ctx, n, 10) { fill(ctx, ell(110, 27, 64, 13), n) }
            fill(ctx, ell(110, 27.5, 40, 7), c(1, 0.95, 1, 0.95))
            // main disc
            let disc = ell(110, 56, 212, 42)
            linear(ctx, disc, [c(0.5, 0.53, 0.68), c(0.22, 0.24, 0.35), c(0.06, 0.07, 0.12)], CGPoint(x: 0, y: 77), CGPoint(x: 0, y: 35), [0, 0.45, 1])
            stroke(ctx, disc, c(1, 1, 1, 0.18), 1)
            // neon band on the front rim
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: 220, height: 56))
            glow(ctx, n, 8) { stroke(ctx, ell(110, 56, 188, 26), n, 3) }
            stroke(ctx, ell(110, 56, 188, 26), c(1, 1, 1, 0.7), 1)
            ctx.restoreGState()
            // upper deck
            linear(ctx, ell(110, 64, 160, 22), [c(0.62, 0.65, 0.8), c(0.28, 0.3, 0.42)], CGPoint(x: 0, y: 75), CGPoint(x: 0, y: 53))
            // neon dashes
            for (x, y, w) in [(36, 50, 18), (70, 45, 22), (150, 45, 22), (184, 50, 18)] as [(CGFloat, CGFloat, CGFloat)] {
                glow(ctx, n, 6) { fill(ctx, rr(x, y, w, 3.2, 1.6), n) }
                fill(ctx, rr(x, y, w * 0.7, 1.2, 0.6), c(1, 1, 1, 0.8))
            }
            // dome collar
            linear(ctx, ell(110, 70, 100, 14), [c(0.7, 0.72, 0.85), c(0.3, 0.32, 0.45)], CGPoint(x: 0, y: 77), CGPoint(x: 0, y: 63))
            // alien
            linear(ctx, ell(110, 78, 50, 20), [n.darker(0.55), c(0.2, 0.18, 0.3)], CGPoint(x: 0, y: 88), CGPoint(x: 0, y: 68))
            fill(ctx, rr(110, 88, 8, 12, 3), c(0.42, 0.38, 0.55))
            let head = ell(110, 104, 28, 34)
            ball(ctx, head, c(0.55, 0.5, 0.72), light: 1.4, dark: 0.55, rect: CGRect(x: 96, y: 87, width: 28, height: 34))
            for s in [-1, 1] as [CGFloat] {
                ctx.saveGState()
                ctx.translateBy(x: 110 + s * 6.5, y: 101)
                ctx.rotate(by: s * 0.45)
                fill(ctx, ell(0, 0, 9, 13), c(0.05, 0.03, 0.1))
                fill(ctx, ell(-1.5 * s, 2.5, 2.5, 3), c(1, 1, 1, 0.6))
                ctx.restoreGState()
            }
            // glass dome
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 70, width: 220, height: 62))
            let dome = ell(110, 70, 96, 112)
            linear(ctx, dome, [n.withAlphaComponent(0.12), c(0.75, 0.85, 1, 0.3)], CGPoint(x: 0, y: 70), CGPoint(x: 0, y: 126))
            stroke(ctx, dome, c(0.85, 0.9, 1, 0.55), 1.4)
            ctx.restoreGState()
            fill(ctx, ell(82, 104, 10, 26), c(1, 1, 1, 0.28))
            fill(ctx, ell(90, 118, 14, 6), c(1, 1, 1, 0.22))
        }
    }

    static func ufo(theme t: UFOTheme) -> SKTexture {
        let n = t.neon
        return texture("ufoT_" + t.id, ufoCanvas) { ctx, _ in
            radial(ctx, ell(110, 28, 120, 40), [n.withAlphaComponent(0.85), n.withAlphaComponent(0)], CGPoint(x: 110, y: 28), 60)
            linear(ctx, ell(110, 40, 128, 38), [t.hullMid.darker(1.1), t.hullBottom], CGPoint(x: 0, y: 59), CGPoint(x: 0, y: 21))
            if t.extra == .icicles {
                for k in 0..<9 {
                    let x = 62 + CGFloat(k) * 12
                    let h = CGFloat(8 + (k * 5) % 9)
                    linear(ctx, poly([CGPoint(x: x - 3, y: 40), CGPoint(x: x + 3, y: 40), CGPoint(x: x, y: 40 - h)]),
                           [c(0.85, 0.95, 1, 0.95), c(0.6, 0.85, 1, 0.6)], CGPoint(x: 0, y: 40), CGPoint(x: 0, y: 40 - h))
                }
            }
            glow(ctx, n, 10) { fill(ctx, ell(110, 27, 64, 13), n) }
            fill(ctx, ell(110, 27.5, 40, 7), c(1, 0.97, 1, 0.95))
            if t.extra == .flames {
                for k in 0..<7 {
                    let x = 30 + CGFloat(k) * 26
                    let h = CGFloat(16 + (k * 7) % 12)
                    let fl = CGMutablePath()
                    fl.move(to: CGPoint(x: x - 9, y: 50))
                    fl.addQuadCurve(to: CGPoint(x: x - 2, y: 50 - h), control: CGPoint(x: x - 12, y: 50 - h * 0.6))
                    fl.addQuadCurve(to: CGPoint(x: x + 9, y: 50), control: CGPoint(x: x + 8, y: 50 - h * 0.5))
                    fl.closeSubpath()
                    glow(ctx, c(1, 0.5, 0.1), 8) {
                        linear(ctx, fl, [c(1, 0.95, 0.4), c(1, 0.45, 0.05), c(0.8, 0.1, 0.02, 0.6)], CGPoint(x: 0, y: 50), CGPoint(x: 0, y: 50 - h))
                    }
                }
            }
            let disc = ell(110, 56, 212, 42)
            linear(ctx, disc, [t.hullTop, t.hullMid, t.hullBottom], CGPoint(x: 0, y: 77), CGPoint(x: 0, y: 35), [0, 0.45, 1])
            stroke(ctx, disc, c(1, 1, 1, 0.2), 1)
            ctx.saveGState()
            ctx.addPath(disc)
            ctx.clip()
            switch t.extra {
            case .candy:
                for k in 0..<12 {
                    let x = CGFloat(k) * 22 - 10
                    fill(ctx, poly([CGPoint(x: x, y: 35), CGPoint(x: x + 9, y: 35), CGPoint(x: x + 25, y: 77), CGPoint(x: x + 16, y: 77)]), c(1, 1, 1, 0.45))
                }
            case .hazard:
                for k in 0..<8 {
                    let x = 22 + CGFloat(k) * 25
                    fill(ctx, ell(x, 45, 7, 4), c(0.05, 0.05, 0.05, 0.8))
                    fill(ctx, ell(x, 45, 4, 2.2), c(0.6, 1, 0.2))
                }
            case .gold:
                for k in 0..<10 {
                    let x = 18 + CGFloat(k) * 20, y: CGFloat = 46 + CGFloat(k % 3) * 4
                    glow(ctx, c(1, 1, 0.8), 4) {
                        fill(ctx, poly([CGPoint(x: x, y: y + 4), CGPoint(x: x + 1, y: y + 1), CGPoint(x: x + 4, y: y), CGPoint(x: x + 1, y: y - 1),
                                        CGPoint(x: x, y: y - 4), CGPoint(x: x - 1, y: y - 1), CGPoint(x: x - 4, y: y), CGPoint(x: x - 1, y: y + 1)]), c(1, 1, 0.9))
                    }
                }
            case .pumpkin:
                // carved jack-o'-lantern face glowing on the front of the disc
                for k in 0..<9 {
                    let x = 14 + CGFloat(k) * 24
                    stroke(ctx, line(CGPoint(x: x, y: 36), CGPoint(x: x + 6, y: 76)), t.hullBottom.withAlphaComponent(0.45), 2)
                }
                let lit = c(1, 0.92, 0.35)
                glow(ctx, c(1, 0.8, 0.2), 8) {
                    fill(ctx, poly([CGPoint(x: 76, y: 48), CGPoint(x: 92, y: 48), CGPoint(x: 84, y: 60)]), lit)
                    fill(ctx, poly([CGPoint(x: 128, y: 48), CGPoint(x: 144, y: 48), CGPoint(x: 136, y: 60)]), lit)
                    fill(ctx, poly([CGPoint(x: 86, y: 44), CGPoint(x: 94, y: 40), CGPoint(x: 100, y: 44), CGPoint(x: 106, y: 39), CGPoint(x: 112, y: 44),
                                    CGPoint(x: 118, y: 39), CGPoint(x: 124, y: 44), CGPoint(x: 132, y: 40), CGPoint(x: 136, y: 44),
                                    CGPoint(x: 126, y: 38), CGPoint(x: 110, y: 36), CGPoint(x: 94, y: 38)]), lit)
                }
            default: break
            }
            ctx.restoreGState()
            // neon band on the front rim
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: 220, height: 56))
            if t.extra == .rainbow {
                let cols = [c(1, 0.25, 0.3), c(1, 0.6, 0.15), c(1, 0.95, 0.2), c(0.3, 1, 0.4), c(0.25, 0.7, 1), c(0.7, 0.4, 1)]
                for (k, col) in cols.enumerated() {
                    ctx.saveGState()
                    ctx.clip(to: CGRect(x: 16 + CGFloat(k) * 31.5, y: 0, width: 31.5, height: 56))
                    glow(ctx, col, 8) { stroke(ctx, ell(110, 56, 188, 26), col, 3.5) }
                    ctx.restoreGState()
                }
            } else {
                glow(ctx, n, 8) { stroke(ctx, ell(110, 56, 188, 26), n, 3) }
            }
            stroke(ctx, ell(110, 56, 188, 26), c(1, 1, 1, 0.7), 1)
            ctx.restoreGState()
            if t.extra == .spikes {
                for k in 0..<7 {
                    let x = 28 + CGFloat(k) * 27
                    let y: CGFloat = 40 + abs(CGFloat(k) - 3) * 2.2
                    linear(ctx, poly([CGPoint(x: x - 5, y: y + 4), CGPoint(x: x + 5, y: y + 4), CGPoint(x: x, y: y - 9)]),
                           [c(0.75, 0.75, 0.8), c(0.2, 0.2, 0.25)], CGPoint(x: x - 5, y: 0), CGPoint(x: x + 5, y: 0))
                }
            }
            let deck = ell(110, 64, 160, 22)
            linear(ctx, deck, [t.deck, t.deck.darker(0.45)], CGPoint(x: 0, y: 75), CGPoint(x: 0, y: 53))
            if t.extra == .cyberGrid {
                ctx.saveGState()
                ctx.addPath(deck)
                ctx.clip()
                for k in 0..<12 { stroke(ctx, line(CGPoint(x: 30 + CGFloat(k) * 14, y: 53), CGPoint(x: 40 + CGFloat(k) * 12, y: 75)), n.withAlphaComponent(0.5), 0.8) }
                stroke(ctx, line(CGPoint(x: 30, y: 64), CGPoint(x: 190, y: 64)), n.withAlphaComponent(0.5), 0.8)
                ctx.restoreGState()
            }
            for (x, y, w) in [(36, 50, 18), (70, 45, 22), (150, 45, 22), (184, 50, 18)] as [(CGFloat, CGFloat, CGFloat)] {
                glow(ctx, n, 6) { fill(ctx, rr(x, y, w, 3.2, 1.6), n) }
                fill(ctx, rr(x, y, w * 0.7, 1.2, 0.6), c(1, 1, 1, 0.8))
            }
            linear(ctx, ell(110, 70, 100, 14), [t.deck.darker(1.1), t.deck.darker(0.5)], CGPoint(x: 0, y: 77), CGPoint(x: 0, y: 63))
            // alien
            linear(ctx, ell(110, 78, 50, 20), [n.darker(0.55), c(0.2, 0.18, 0.3)], CGPoint(x: 0, y: 88), CGPoint(x: 0, y: 68))
            fill(ctx, rr(110, 88, 8, 12, 3), t.alien.darker(0.75))
            ball(ctx, ell(110, 104, 28, 34), t.alien, light: 1.4, dark: 0.55, rect: CGRect(x: 96, y: 87, width: 28, height: 34))
            for sgn in [-1, 1] as [CGFloat] {
                ctx.saveGState()
                ctx.translateBy(x: 110 + sgn * 6.5, y: 101)
                ctx.rotate(by: sgn * 0.45)
                fill(ctx, ell(0, 0, 9, 13), c(0.05, 0.03, 0.1))
                fill(ctx, ell(-1.5 * sgn, 2.5, 2.5, 3), c(1, 1, 1, 0.6))
                ctx.restoreGState()
            }
            if t.extra == .gold {
                // a little crown for the king
                let cr = poly([CGPoint(x: 100, y: 118), CGPoint(x: 120, y: 118), CGPoint(x: 122, y: 128), CGPoint(x: 116, y: 123),
                               CGPoint(x: 110, y: 130), CGPoint(x: 104, y: 123), CGPoint(x: 98, y: 128)])
                linear(ctx, cr, [c(1, 0.95, 0.5), c(0.85, 0.55, 0.05)], CGPoint(x: 0, y: 130), CGPoint(x: 0, y: 118))
            }
            if t.extra == .pumpkin {
                fill(ctx, rr(110, 124, 4, 8, 1.5), c(0.3, 0.5, 0.15))
            }
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 70, width: 220, height: 62))
            let dome = ell(110, 70, 96, 112)
            linear(ctx, dome, [n.withAlphaComponent(0.12), t.glass.withAlphaComponent(0.3)], CGPoint(x: 0, y: 70), CGPoint(x: 0, y: 126))
            stroke(ctx, dome, t.glass.withAlphaComponent(0.6), 1.4)
            ctx.restoreGState()
            fill(ctx, ell(82, 104, 10, 26), c(1, 1, 1, 0.28))
            fill(ctx, ell(90, 118, 14, 6), c(1, 1, 1, 0.22))
        }
    }

    /// Soft round shadow (one shared texture so many shadows draw in one batch).
    static func shadowTex() -> SKTexture {
        return texture("shadow", CGSize(width: 64, height: 24), scale: Painter.screen) { ctx, _ in
            radial(ctx, ell(32, 12, 64, 24), [c(0, 0, 0, 0.55), c(0, 0, 0, 0.3), c(0, 0, 0, 0)], CGPoint(x: 32, y: 12), 32, [0, 0.55, 1])
        }
    }

    // MARK: - Beam

    /// White cone; tinted and drawn additively. Top (narrow) is at the top of the image.
    static func beam() -> SKTexture {
        return texture("beam", CGSize(width: 128, height: 256), scale: Painter.hi) { ctx, s in
            for k in 0..<7 {
                let f = 1 - CGFloat(k) * 0.13
                let top = 16 * f, bot = 64 * f
                let p = poly([CGPoint(x: 64 - bot, y: 0), CGPoint(x: 64 + bot, y: 0), CGPoint(x: 64 + top, y: 256), CGPoint(x: 64 - top, y: 256)])
                linear(ctx, p, [c(1, 1, 1, 0.06 + CGFloat(k) * 0.02), c(1, 1, 1, 0.16 + CGFloat(k) * 0.03)], CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 256))
            }
            for i in 0..<9 {
                let x0 = 64 + (CGFloat(i) - 4) * 11
                let x1 = 64 + (CGFloat(i) - 4) * 3
                stroke(ctx, line(CGPoint(x: x0, y: 0), CGPoint(x: x1, y: 256)), c(1, 1, 1, 0.07), 2)
            }
        }
    }

    static func landing() -> SKTexture {
        return texture("landing", CGSize(width: 160, height: 64), scale: Painter.hi) { ctx, _ in
            radial(ctx, ell(80, 32, 160, 64), [c(1, 1, 1, 0.75), c(1, 1, 1, 0.25), c(1, 1, 1, 0)], CGPoint(x: 80, y: 32), 80, [0, 0.5, 1])
            ctx.saveGState()
            ctx.translateBy(x: 0, y: 32)
            ctx.scaleBy(x: 1, y: 0.4)
            ctx.translateBy(x: 0, y: -32)
            glow(ctx, .white, 6) { stroke(ctx, ell(80, 32, 128, 128 * 0.95), c(1, 1, 1, 0.95), 3) }
            ctx.restoreGState()
        }
    }

    // MARK: - Animals

    static let creatureCanvas = CGSize(width: 64, height: 56)
    static let creatureFoot = CGPoint(x: 32, y: 6)

    /// Body only (legs are separate nodes so they can animate).
    static func sheep(_ v: Int) -> SKTexture {
        let wools: [(UIColor, UIColor)] = [(c(0.98, 0.95, 0.88), c(0.72, 0.65, 0.55)), (c(0.32, 0.3, 0.36), c(0.12, 0.11, 0.15)), (c(1, 0.86, 0.38), c(0.75, 0.52, 0.12))]
        let (hi, lo) = wools[v % 3]
        return texture("sheep\(v)", creatureCanvas) { ctx, _ in
            let blobs: [(CGFloat, CGFloat, CGFloat)] = [(-12, 20, 8), (-6, 25, 9), (2, 26, 9), (9, 23, 8), (-14, 14, 7), (-6, 14, 8), (3, 14, 8), (10, 15, 7),
                                                       (-9, 19, 8), (0, 20, 9), (7, 19, 8)]
            for (x, y, r) in blobs {
                let p = ell(32 + x, 6 + y, r * 2, r * 2)
                radial(ctx, p, [hi, hi.darker(0.9), lo], CGPoint(x: 32 + x - r * 0.35, y: 6 + y + r * 0.4), r * 1.25, [0, 0.55, 1])
            }
            // head
            ctx.saveGState()
            ctx.translateBy(x: 32 + 17, y: 6 + 19)
            ctx.rotate(by: -0.25)
            fill(ctx, ell(-6, 4, 8, 5), c(0.1, 0.09, 0.12))
            ball(ctx, ell(0, 0, 14, 17), c(0.16, 0.15, 0.2), light: 1.8, dark: 0.6, rect: CGRect(x: -7, y: -8.5, width: 14, height: 17))
            for s in [-1, 1] as [CGFloat] {
                fill(ctx, ell(s * 3.2, 2, 5.6, 6.4), .white)
                fill(ctx, ell(s * 3.2 + 0.8, 1.6, 2.8, 3.4), .black)
                fill(ctx, ell(s * 3.2 + 1.5, 2.6, 1.1, 1.1), .white)
            }
            fill(ctx, ell(0, -5, 4, 2), c(0.35, 0.2, 0.25))
            ctx.restoreGState()
            radial(ctx, ell(32 + 13, 6 + 30, 10, 8), [hi, lo], CGPoint(x: 32 + 12, y: 6 + 32), 7)
            if v % 3 == 2 {
                glow(ctx, c(1, 0.9, 0.4), 6) { fill(ctx, ell(32 - 4, 6 + 28, 3, 3), .white) }
            }
        }
    }

    static func cow(_ v: Int) -> SKTexture {
        let bodies: [UIColor] = [c(0.96, 0.95, 0.92), c(0.55, 0.34, 0.2), c(0.74, 0.55, 0.96), c(0.55, 1, 0.4)]
        let spots: [UIColor] = [c(0.1, 0.1, 0.12), c(0.3, 0.18, 0.1), c(0.4, 0.24, 0.65), c(0.1, 0.45, 0.08)]
        let b = bodies[v % 4], sp = spots[v % 4]
        return texture("cow\(v)", CGSize(width: 84, height: 64)) { ctx, _ in
            if v == 3 { radial(ctx, ell(42, 32, 84, 64), [c(0.5, 1, 0.3, 0.55), c(0.4, 1, 0.2, 0)], CGPoint(x: 42, y: 32), 42) }
            let body = rr(40, 30, 50, 24, 11)
            ball(ctx, body, b, light: 1.1, dark: 0.62, rect: CGRect(x: 15, y: 18, width: 50, height: 24))
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            for (x, y, w, h) in [(28, 34, 16, 12), (50, 24, 14, 10), (42, 40, 8, 7)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                fill(ctx, ell(x, y, w, h), sp)
            }
            ctx.restoreGState()
            fill(ctx, ell(42, 18, 10, 6), c(1, 0.7, 0.75))
            stroke(ctx, line(CGPoint(x: 15, y: 36), CGPoint(x: 11, y: 24)), b.darker(0.7), 2)
            // head
            ctx.saveGState()
            ctx.translateBy(x: 68, y: 38)
            ball(ctx, rr(0, 0, 17, 18, 6), b, light: 1.1, dark: 0.65, rect: CGRect(x: -8.5, y: -9, width: 17, height: 18))
            ball(ctx, ell(3, -6, 15, 9), c(1, 0.72, 0.76), rect: CGRect(x: -4.5, y: -10.5, width: 15, height: 9))
            fill(ctx, ell(0, -6, 2, 2), c(0.4, 0.2, 0.25))
            fill(ctx, ell(6, -6, 2, 2), c(0.4, 0.2, 0.25))
            for s in [-1, 1] as [CGFloat] {
                fill(ctx, ell(s * 4, 3, 5, 5.5), .white)
                fill(ctx, ell(s * 4 + 0.8, 2.6, 2.6, 3), .black)
                stroke(ctx, line(CGPoint(x: s * 5, y: 8), CGPoint(x: s * 8, y: 13)), c(0.95, 0.92, 0.8), 2.5)
                fill(ctx, ell(s * 10, 6, 7, 3.5), b.darker(0.85))
            }
            ctx.restoreGState()
        }
    }

    static func pig(_ v: Int) -> SKTexture {
        let cols: [UIColor] = [c(1, 0.66, 0.74), c(0.56, 0.72, 0.42), c(0.62, 0.62, 0.64)]
        let b = cols[v % 3]
        return texture("pig\(v)", creatureCanvas) { ctx, _ in
            ball(ctx, ell(30, 20, 34, 22), b, light: 1.15, dark: 0.62, rect: CGRect(x: 13, y: 9, width: 34, height: 22))
            ball(ctx, ell(48, 20, 10, 9), b.darker(0.92), rect: CGRect(x: 43, y: 15.5, width: 10, height: 9))
            fill(ctx, ell(47, 20, 1.6, 2.4), c(0.4, 0.15, 0.2))
            fill(ctx, ell(50, 20, 1.6, 2.4), c(0.4, 0.15, 0.2))
            fill(ctx, ell(41, 25, 4.5, 5), .white)
            fill(ctx, ell(41.7, 24.6, 2.3, 2.8), .black)
            fill(ctx, poly([CGPoint(x: 35, y: 28), CGPoint(x: 41, y: 29), CGPoint(x: 37, y: 35)]), b.darker(0.8))
            stroke(ctx, line(CGPoint(x: 13, y: 24), CGPoint(x: 9, y: 28)), b.darker(0.7), 1.6)
            if v % 3 == 1 { fill(ctx, ell(26, 14, 12, 6), c(0.35, 0.25, 0.15, 0.8)) }
        }
    }

    static func dog() -> SKTexture {
        return texture("dog", creatureCanvas) { ctx, _ in
            let blk = c(0.12, 0.12, 0.14)
            ball(ctx, rr(28, 20, 28, 12, 6), blk, light: 2.2, dark: 0.7, rect: CGRect(x: 14, y: 14, width: 28, height: 12))
            fill(ctx, rr(33, 17, 14, 7, 3), c(0.95, 0.95, 0.95))
            stroke(ctx, line(CGPoint(x: 15, y: 22), CGPoint(x: 8, y: 30)), blk, 3)
            fill(ctx, ell(8, 31, 4, 4), .white)
            // head
            ball(ctx, ell(45, 28, 14, 13), blk, light: 2.2, dark: 0.7, rect: CGRect(x: 38, y: 21.5, width: 14, height: 13))
            fill(ctx, poly([CGPoint(x: 45, y: 34), CGPoint(x: 47, y: 22), CGPoint(x: 52, y: 24)]), .white)
            fill(ctx, rr(53, 25, 8, 6, 3), c(0.92, 0.92, 0.92))
            fill(ctx, ell(57, 26.5, 2.4, 2), .black)
            fill(ctx, ell(55, 21, 3, 4), c(0.95, 0.4, 0.5))
            fill(ctx, ell(48, 30, 3.6, 4), .white)
            fill(ctx, ell(48.6, 29.8, 1.8, 2.2), .black)
            fill(ctx, poly([CGPoint(x: 40, y: 33), CGPoint(x: 43, y: 40), CGPoint(x: 45, y: 33)]), blk)
        }
    }

    // MARK: - People

    struct Outfit {
        var shirt: UIColor
        var pants: UIColor
        var hat: UIColor?
        var cap = false
        var beard = false
        var hair: UIColor?
    }

    static func person(_ key: String, _ o: Outfit) -> SKTexture {
        return texture("p_" + key, CGSize(width: 48, height: 64)) { ctx, _ in
            let skin = c(0.96, 0.76, 0.6)
            // torso + overalls
            ball(ctx, rr(24, 26, 15, 17, 5), o.shirt, light: 1.25, dark: 0.6, rect: CGRect(x: 16.5, y: 17.5, width: 15, height: 17))
            if o.pants != o.shirt {
                linear(ctx, rr(24, 22, 12, 10, 2), [o.pants.darker(1.15), o.pants.darker(0.75)], CGPoint(x: 0, y: 27), CGPoint(x: 0, y: 17))
                fill(ctx, rr(20, 29, 2, 9, 1), o.pants)
                fill(ctx, rr(28, 29, 2, 9, 1), o.pants)
                fill(ctx, ell(20, 32, 2, 2), c(0.9, 0.8, 0.3))
                fill(ctx, ell(28, 32, 2, 2), c(0.9, 0.8, 0.3))
            }
            // back arm
            fill(ctx, rr(17, 25, 4.5, 12, 2.2), o.shirt.darker(0.7))
            // head
            ball(ctx, ell(24, 41, 15, 15), skin, light: 1.1, dark: 0.75, rect: CGRect(x: 16.5, y: 33.5, width: 15, height: 15))
            fill(ctx, ell(31, 40, 4, 3.4), skin.darker(0.88))
            fill(ctx, ell(27.5, 43, 2, 2.4), .black)
            if let h = o.hair { fill(ctx, ell(21, 46, 13, 7), h) }
            if o.beard {
                radial(ctx, ell(26, 36, 13, 11), [.white, c(0.82, 0.82, 0.86)], CGPoint(x: 25, y: 38), 8)
                fill(ctx, ell(29, 39.5, 7, 2.8), .white)
                fill(ctx, ell(24.5, 46, 6, 2.2), c(0.9, 0.9, 0.92))
            }
            if let h = o.hat {
                if o.cap {
                    ball(ctx, ell(24, 47, 15, 9), h, rect: CGRect(x: 16.5, y: 42.5, width: 15, height: 9))
                    fill(ctx, rr(31, 45, 9, 2.5, 1.2), h.darker(0.8))
                } else {
                    fill(ctx, ell(24, 47, 26, 5.5), h.darker(0.8))
                    ball(ctx, rr(24, 51, 14, 9, 3.5), h, rect: CGRect(x: 17, y: 46.5, width: 14, height: 9))
                    fill(ctx, rr(24, 48.5, 14, 2, 1), h.darker(0.55))
                }
            }
            // front arm
            ball(ctx, rr(30, 25, 4.8, 12, 2.4), o.shirt, rect: CGRect(x: 27.6, y: 19, width: 4.8, height: 12))
            fill(ctx, ell(30, 18.5, 4.4, 4.4), skin)
        }
    }

    // MARK: - Obstacles

    static func wood(_ ctx: CGContext, _ path: CGPath, _ base: UIColor, horizontal: Bool, rect: CGRect) {
        if horizontal {
            linear(ctx, path, [base.darker(1.2), base, base.darker(0.65)], CGPoint(x: 0, y: rect.maxY), CGPoint(x: 0, y: rect.minY))
        } else {
            linear(ctx, path, [base.darker(0.7), base.darker(1.15), base.darker(0.65)], CGPoint(x: rect.minX, y: 0), CGPoint(x: rect.maxX, y: 0))
        }
        stroke(ctx, path, base.darker(0.4), 0.8)
    }

    static func fence() -> SKTexture {
        return texture("fence", CGSize(width: 96, height: 36)) { ctx, _ in
            let w = c(0.42, 0.29, 0.18)
            for y in [10.0, 21.0] as [CGFloat] {
                let r = CGRect(x: 2, y: y, width: 92, height: 5)
                wood(ctx, CGPath(rect: r, transform: nil), w, horizontal: true, rect: r)
            }
            for x in stride(from: 6, through: 90, by: 28) as StrideThrough<CGFloat> {
                let r = CGRect(x: x - 2.5, y: 4, width: 5, height: 26)
                wood(ctx, CGPath(roundedRect: r, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil), w.darker(0.95), horizontal: false, rect: r)
            }
        }
    }

    static func shed() -> SKTexture {
        return texture("shed", CGSize(width: 60, height: 56)) { ctx, _ in
            let r = CGRect(x: 8, y: 6, width: 44, height: 28)
            wood(ctx, CGPath(rect: r, transform: nil), c(0.45, 0.31, 0.2), horizontal: false, rect: r)
            for x in stride(from: 12, through: 48, by: 6) as StrideThrough<CGFloat> {
                stroke(ctx, line(CGPoint(x: x, y: 6), CGPoint(x: x, y: 34)), c(0.25, 0.16, 0.1, 0.6), 0.8)
            }
            linear(ctx, poly([CGPoint(x: 3, y: 32), CGPoint(x: 30, y: 52), CGPoint(x: 57, y: 32)]), [c(0.3, 0.3, 0.36), c(0.14, 0.14, 0.18)], CGPoint(x: 0, y: 52), CGPoint(x: 0, y: 32))
            fill(ctx, rr(30, 14, 12, 16, 2), c(0.1, 0.07, 0.06))
        }
    }

    static func barrels() -> SKTexture {
        return texture("barrels", CGSize(width: 56, height: 36)) { ctx, _ in
            for (x, y) in [(15, 4), (41, 4), (28, 7)] as [(CGFloat, CGFloat)] {
                let r = CGRect(x: x - 9, y: y, width: 18, height: 24)
                linear(ctx, CGPath(roundedRect: r, cornerWidth: 4, cornerHeight: 4, transform: nil),
                       [c(0.45, 0.08, 0.08), c(0.85, 0.2, 0.15), c(0.4, 0.07, 0.07)], CGPoint(x: r.minX, y: 0), CGPoint(x: r.maxX, y: 0))
                fill(ctx, ell(x, y + 24, 18, 5), c(0.3, 0.06, 0.06))
                for yy in [y + 6, y + 17] { fill(ctx, CGPath(rect: CGRect(x: r.minX, y: yy, width: 18, height: 1.6), transform: nil), c(0.15, 0.12, 0.12)) }
            }
        }
    }

    static func silo() -> SKTexture {
        return texture("silo", CGSize(width: 50, height: 104)) { ctx, _ in
            let r = CGRect(x: 7, y: 4, width: 36, height: 74)
            let metal = [c(0.32, 0.33, 0.38), c(0.72, 0.74, 0.8), c(0.5, 0.52, 0.58), c(0.22, 0.23, 0.28)]
            linear(ctx, CGPath(rect: r, transform: nil), metal, CGPoint(x: r.minX, y: 0), CGPoint(x: r.maxX, y: 0), [0, 0.35, 0.65, 1])
            for y in stride(from: 12, through: 72, by: 9) as StrideThrough<CGFloat> {
                stroke(ctx, line(CGPoint(x: 7, y: y), CGPoint(x: 43, y: y)), c(0.15, 0.15, 0.18, 0.5), 1)
            }
            let cap = CGMutablePath()
            cap.move(to: CGPoint(x: 5, y: 78))
            cap.addQuadCurve(to: CGPoint(x: 45, y: 78), control: CGPoint(x: 25, y: 104))
            cap.closeSubpath()
            linear(ctx, cap, metal, CGPoint(x: 5, y: 0), CGPoint(x: 45, y: 0), [0, 0.35, 0.65, 1])
            fill(ctx, rr(25, 92, 5, 5, 2), c(0.3, 0.3, 0.34))
            stroke(ctx, line(CGPoint(x: 40, y: 6), CGPoint(x: 40, y: 76)), c(0.2, 0.2, 0.24), 1.4)
        }
    }

    static func house() -> SKTexture {
        return texture("house", CGSize(width: 100, height: 92)) { ctx, _ in
            let wall = CGRect(x: 14, y: 4, width: 72, height: 44)
            wood(ctx, CGPath(rect: wall, transform: nil), c(0.4, 0.27, 0.17), horizontal: true, rect: wall)
            for y in stride(from: 8, through: 46, by: 5) as StrideThrough<CGFloat> {
                stroke(ctx, line(CGPoint(x: 14, y: y), CGPoint(x: 86, y: y)), c(0.2, 0.13, 0.08, 0.6), 0.7)
            }
            linear(ctx, poly([CGPoint(x: 6, y: 46), CGPoint(x: 50, y: 82), CGPoint(x: 94, y: 46)]), [c(0.25, 0.22, 0.24), c(0.11, 0.1, 0.12)], CGPoint(x: 0, y: 82), CGPoint(x: 0, y: 46))
            stroke(ctx, poly([CGPoint(x: 6, y: 46), CGPoint(x: 50, y: 82), CGPoint(x: 94, y: 46)]), c(0.3, 0.2, 0.12), 2.5)
            fill(ctx, CGPath(rect: CGRect(x: 66, y: 64, width: 8, height: 18), transform: nil), c(0.25, 0.18, 0.15))
            let lit = c(1, 0.78, 0.35)
            for (x, y) in [(30, 28), (70, 28), (50, 60)] as [(CGFloat, CGFloat)] {
                glow(ctx, c(1, 0.7, 0.25), 12) { fill(ctx, rr(x, y, 11, 12, 1), lit) }
                stroke(ctx, line(CGPoint(x: x, y: y - 6), CGPoint(x: x, y: y + 6)), c(0.3, 0.18, 0.1), 1.2)
                stroke(ctx, line(CGPoint(x: x - 5.5, y: y), CGPoint(x: x + 5.5, y: y)), c(0.3, 0.18, 0.1), 1.2)
            }
            fill(ctx, rr(50, 13, 12, 18, 1.5), c(0.18, 0.1, 0.06))
            glow(ctx, c(1, 0.8, 0.4), 10) { fill(ctx, ell(60, 24, 3, 3), c(1, 0.9, 0.6)) }
        }
    }

    static func barn() -> SKTexture {
        return texture("barn", CGSize(width: 112, height: 90)) { ctx, _ in
            let red = c(0.6, 0.13, 0.11)
            let wall = CGRect(x: 12, y: 4, width: 88, height: 50)
            linear(ctx, CGPath(rect: wall, transform: nil), [red.darker(1.25), red, red.darker(0.6)], CGPoint(x: 0, y: 54), CGPoint(x: 0, y: 4))
            for x in stride(from: 16, through: 98, by: 6) as StrideThrough<CGFloat> {
                stroke(ctx, line(CGPoint(x: x, y: 4), CGPoint(x: x, y: 54)), red.darker(0.6), 0.8)
            }
            let roof = poly([CGPoint(x: 4, y: 52), CGPoint(x: 26, y: 80), CGPoint(x: 86, y: 80), CGPoint(x: 108, y: 52)])
            linear(ctx, roof, [c(0.3, 0.28, 0.32), c(0.12, 0.11, 0.14)], CGPoint(x: 0, y: 80), CGPoint(x: 0, y: 52))
            let door = CGRect(x: 40, y: 4, width: 32, height: 34)
            fill(ctx, CGPath(rect: door, transform: nil), c(0.92, 0.9, 0.85))
            fill(ctx, CGPath(rect: door.insetBy(dx: 3, dy: 3), transform: nil), red.darker(0.8))
            stroke(ctx, line(CGPoint(x: 43, y: 7), CGPoint(x: 69, y: 35)), c(0.92, 0.9, 0.85), 2.5)
            stroke(ctx, line(CGPoint(x: 69, y: 7), CGPoint(x: 43, y: 35)), c(0.92, 0.9, 0.85), 2.5)
            glow(ctx, c(1, 0.75, 0.3), 10) { fill(ctx, rr(56, 64, 12, 9, 1), c(1, 0.8, 0.4)) }
        }
    }

    static func windmillTower() -> SKTexture {
        return texture("windmill", CGSize(width: 48, height: 128)) { ctx, _ in
            let w = c(0.38, 0.27, 0.18)
            stroke(ctx, line(CGPoint(x: 6, y: 2), CGPoint(x: 20, y: 110)), w, 3)
            stroke(ctx, line(CGPoint(x: 42, y: 2), CGPoint(x: 28, y: 110)), w, 3)
            for k in 0..<6 {
                let y0 = CGFloat(k) * 18 + 2, y1 = y0 + 18
                let x0 = 6 + y0 / 108 * 14, x1 = 6 + y1 / 108 * 14
                stroke(ctx, line(CGPoint(x: x0, y: y0), CGPoint(x: 48 - x1, y: y1)), w.darker(0.85), 1.4)
                stroke(ctx, line(CGPoint(x: 48 - x0, y: y0), CGPoint(x: x1, y: y1)), w.darker(0.85), 1.4)
            }
            fill(ctx, rr(24, 112, 14, 6, 2), w.darker(0.7))
        }
    }

    static func windmillWheel() -> SKTexture {
        return texture("wheel", CGSize(width: 60, height: 60)) { ctx, _ in
            for k in 0..<14 {
                ctx.saveGState()
                ctx.translateBy(x: 30, y: 30)
                ctx.rotate(by: CGFloat(k) / 14 * .pi * 2)
                linear(ctx, poly([CGPoint(x: -2, y: 6), CGPoint(x: 2, y: 6), CGPoint(x: 4, y: 28), CGPoint(x: -4, y: 28)]),
                       [c(0.78, 0.72, 0.62), c(0.45, 0.4, 0.35)], CGPoint(x: -4, y: 0), CGPoint(x: 4, y: 0))
                ctx.restoreGState()
            }
            stroke(ctx, ell(30, 30, 50, 50), c(0.35, 0.3, 0.25), 1.5)
            fill(ctx, ell(30, 30, 9, 9), c(0.25, 0.22, 0.2))
        }
    }

    static func car(_ key: String, body: UIColor, roof: UIColor, police: Bool = false) -> SKTexture {
        return texture("car_" + key, CGSize(width: 96, height: 44)) { ctx, _ in
            let shape = poly([CGPoint(x: 8, y: 9), CGPoint(x: 86, y: 9), CGPoint(x: 90, y: 19), CGPoint(x: 82, y: 23), CGPoint(x: 16, y: 24),
                              CGPoint(x: 6, y: 28), CGPoint(x: 5, y: 15)])
            linear(ctx, shape, [body.darker(1.35), body, body.darker(0.45)], CGPoint(x: 0, y: 28), CGPoint(x: 0, y: 9))
            let cab = poly([CGPoint(x: 28, y: 23), CGPoint(x: 66, y: 23), CGPoint(x: 58, y: 36), CGPoint(x: 34, y: 36)])
            linear(ctx, cab, [roof.darker(1.25), roof.darker(0.8)], CGPoint(x: 0, y: 36), CGPoint(x: 0, y: 23))
            let glass = c(0.45, 0.6, 0.8)
            linear(ctx, poly([CGPoint(x: 32, y: 24), CGPoint(x: 45, y: 24), CGPoint(x: 45, y: 34), CGPoint(x: 36, y: 34)]), [glass.darker(1.4), glass.darker(0.6)], CGPoint(x: 32, y: 34), CGPoint(x: 45, y: 24))
            linear(ctx, poly([CGPoint(x: 48, y: 24), CGPoint(x: 62, y: 24), CGPoint(x: 56, y: 34), CGPoint(x: 48, y: 34)]), [glass.darker(1.4), glass.darker(0.6)], CGPoint(x: 48, y: 34), CGPoint(x: 62, y: 24))
            fill(ctx, CGPath(rect: CGRect(x: 6, y: 15, width: 84, height: 2), transform: nil), c(0.9, 0.9, 0.92, 0.8))
            if police {
                fill(ctx, CGPath(rect: CGRect(x: 30, y: 12, width: 36, height: 9), transform: nil), c(0.95, 0.95, 0.95))
                fill(ctx, ell(48, 16.5, 7, 7), c(0.9, 0.75, 0.2))
            }
            glow(ctx, c(1, 0.95, 0.6), 8) { fill(ctx, rr(88, 18, 4, 4, 1), c(1, 0.97, 0.75)) }
            glow(ctx, c(1, 0.2, 0.2), 6) { fill(ctx, rr(6, 22, 3, 4, 1), c(1, 0.25, 0.2)) }
            for x in [24, 72] as [CGFloat] {
                fill(ctx, ell(x, 9, 15, 15), c(0.06, 0.06, 0.07))
                radial(ctx, ell(x, 9, 7, 7), [c(0.9, 0.9, 0.95), c(0.5, 0.5, 0.55)], CGPoint(x: x - 1, y: 10), 4)
            }
        }
    }

    static func vehicle(_ kind: ObKind) -> SKTexture {
        return texture("veh_\(kind)", CGSize(width: 110, height: 52)) { ctx, _ in
            func wheels(_ xs: [CGFloat], _ r: CGFloat) {
                for x in xs {
                    fill(ctx, ell(x, r + 1, r * 2, r * 2), c(0.06, 0.06, 0.07))
                    radial(ctx, ell(x, r + 1, r, r), [c(0.85, 0.85, 0.9), c(0.45, 0.45, 0.5)], CGPoint(x: x - 1, y: r + 2), r * 0.6)
                }
            }
            switch kind {
            case .jeep:
                let g = c(0.3, 0.37, 0.22)
                linear(ctx, rr(55, 18, 74, 18, 4), [g.darker(1.3), g.darker(0.6)], CGPoint(x: 0, y: 27), CGPoint(x: 0, y: 9))
                linear(ctx, rr(48, 33, 32, 14, 3), [g.darker(1.2), g.darker(0.7)], CGPoint(x: 0, y: 40), CGPoint(x: 0, y: 26))
                fill(ctx, rr(48, 34, 24, 8, 2), c(0.5, 0.65, 0.75))
                fill(ctx, ell(66, 18, 10, 10), c(0.95, 0.95, 0.95))
                wheels([32, 80], 9)
            case .truck:
                let b = c(0.5, 0.36, 0.22)
                linear(ctx, poly([CGPoint(x: 8, y: 8), CGPoint(x: 102, y: 8), CGPoint(x: 102, y: 22), CGPoint(x: 86, y: 24), CGPoint(x: 80, y: 38),
                                  CGPoint(x: 62, y: 38), CGPoint(x: 60, y: 24), CGPoint(x: 8, y: 24)]), [b.darker(1.3), b.darker(0.55)], CGPoint(x: 0, y: 38), CGPoint(x: 0, y: 8))
                fill(ctx, rr(73, 30, 14, 9, 1.5), c(0.5, 0.65, 0.8))
                glow(ctx, c(1, 0.95, 0.6), 8) { fill(ctx, rr(100, 17, 4, 4, 1), c(1, 0.97, 0.75)) }
                wheels([28, 84], 8)
            case .fireTruck:
                let r = c(0.8, 0.12, 0.1)
                linear(ctx, rr(55, 20, 100, 24, 3), [r.darker(1.3), r.darker(0.55)], CGPoint(x: 0, y: 32), CGPoint(x: 0, y: 8))
                fill(ctx, rr(90, 26, 18, 10, 2), c(0.55, 0.7, 0.85))
                fill(ctx, CGPath(rect: CGRect(x: 10, y: 33, width: 66, height: 3), transform: nil), c(0.85, 0.85, 0.88))
                for x in stride(from: 12, through: 74, by: 8) as StrideThrough<CGFloat> {
                    fill(ctx, CGPath(rect: CGRect(x: x, y: 32, width: 1.6, height: 7), transform: nil), c(0.85, 0.85, 0.88))
                }
                wheels([22, 80, 96], 7.5)
            default: // tank body (barrel is a separate node)
                let g = c(0.28, 0.34, 0.22)
                linear(ctx, rr(55, 16, 70, 16, 5), [g.darker(1.3), g.darker(0.6)], CGPoint(x: 0, y: 24), CGPoint(x: 0, y: 8))
                ball(ctx, ell(55, 30, 34, 16), g, rect: CGRect(x: 38, y: 22, width: 34, height: 16))
                fill(ctx, rr(55, 8, 76, 12, 6), c(0.1, 0.1, 0.1))
                for x in stride(from: 25, through: 85, by: 12) as StrideThrough<CGFloat> {
                    fill(ctx, ell(x, 8, 8, 8), c(0.3, 0.3, 0.32))
                }
                fill(ctx, ell(44, 18, 6, 6), .white)
                fill(ctx, ell(44, 18, 3, 3), c(0.9, 0.1, 0.1))
            }
        }
    }

    // MARK: - Collectables / props

    static func coin() -> SKTexture {
        return texture("coin", CGSize(width: 30, height: 30)) { ctx, _ in
            radial(ctx, ell(15, 15, 30, 30), [c(1, 0.65, 0.15, 0.55), c(1, 0.6, 0.1, 0)], CGPoint(x: 15, y: 15), 15)
            radial(ctx, ell(15, 15, 16, 16), [c(1, 0.95, 0.6), c(1, 0.78, 0.2), c(0.75, 0.45, 0.05)], CGPoint(x: 12, y: 18), 10, [0, 0.5, 1])
            stroke(ctx, ell(15, 15, 11, 11), c(0.7, 0.42, 0.05, 0.8), 1)
            fill(ctx, ell(12, 18, 4, 3), c(1, 1, 0.9, 0.7))
        }
    }

    static func tuft(_ v: Int) -> SKTexture {
        return texture("tuft\(v)", CGSize(width: 22, height: 16), scale: Painter.hi) { ctx, _ in
            let g = [c(0.18, 0.32, 0.18), c(0.24, 0.38, 0.2), c(0.14, 0.26, 0.16)][v % 3]
            for k in 0..<6 {
                let x = 3 + CGFloat(k) * 3.2
                let h = CGFloat(8 + (k * 7 + v * 3) % 7)
                let lean = CGFloat((k * 5 + v) % 5) - 2
                linear(ctx, poly([CGPoint(x: x - 1.5, y: 0), CGPoint(x: x + 1.5, y: 0), CGPoint(x: x + lean, y: h)]), [g.darker(0.6), g.darker(1.4)], CGPoint(x: 0, y: 0), CGPoint(x: 0, y: h))
            }
            if v % 3 == 1 {
                fill(ctx, ell(8, 11, 3, 3), c(1, 0.85, 0.3))
                fill(ctx, ell(15, 9, 2.6, 2.6), c(1, 0.95, 0.85))
            }
        }
    }

    static func rock() -> SKTexture {
        return texture("rock", CGSize(width: 80, height: 50)) { ctx, _ in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 4, y: 4))
            p.addCurve(to: CGPoint(x: 40, y: 44), control1: CGPoint(x: 4, y: 30), control2: CGPoint(x: 20, y: 44))
            p.addCurve(to: CGPoint(x: 76, y: 4), control1: CGPoint(x: 62, y: 44), control2: CGPoint(x: 76, y: 24))
            p.closeSubpath()
            radial(ctx, p, [c(0.42, 0.42, 0.45), c(0.22, 0.22, 0.25), c(0.1, 0.1, 0.12)], CGPoint(x: 30, y: 34), 50, [0, 0.5, 1])
            fill(ctx, ell(28, 30, 10, 4), c(0.2, 0.35, 0.18, 0.6))
        }
    }

    static func puddle() -> SKTexture {
        return texture("puddle", CGSize(width: 100, height: 40), scale: Painter.screen) { ctx, _ in
            radial(ctx, ell(50, 20, 100, 40), [c(0.45, 0.35, 0.75, 0.55), c(0.15, 0.15, 0.3, 0.6), c(0.1, 0.12, 0.15, 0)], CGPoint(x: 46, y: 22), 50, [0, 0.7, 1])
            fill(ctx, ell(40, 24, 30, 4), c(0.8, 0.7, 1, 0.25))
        }
    }

    static func dirt() -> SKTexture {
        return texture("dirt", CGSize(width: 100, height: 40), scale: Painter.screen) { ctx, _ in
            radial(ctx, ell(50, 20, 100, 40), [c(0.2, 0.17, 0.12, 0.6), c(0.18, 0.15, 0.1, 0)], CGPoint(x: 50, y: 20), 50)
        }
    }

    static func signBoard() -> SKTexture {
        return texture("signboard", CGSize(width: 90, height: 64)) { ctx, _ in
            let w = c(0.38, 0.27, 0.17)
            for x in [26, 64] as [CGFloat] {
                let r = CGRect(x: x - 3, y: 0, width: 6, height: 40)
                wood(ctx, CGPath(rect: r, transform: nil), w.darker(0.8), horizontal: false, rect: r)
            }
            let b = CGRect(x: 3, y: 30, width: 84, height: 30)
            wood(ctx, CGPath(roundedRect: b, cornerWidth: 3, cornerHeight: 3, transform: nil), w, horizontal: true, rect: b)
            for y in [40, 50] as [CGFloat] { stroke(ctx, line(CGPoint(x: 4, y: y), CGPoint(x: 86, y: y)), w.darker(0.55), 0.8) }
        }
    }

    // MARK: - Backdrop (painted once per screen size)

    static func sky(_ size: CGSize) -> SKTexture {
        return texture("sky\(Int(size.width))x\(Int(size.height))", size, scale: Painter.screen) { ctx, s in
            let all = CGPath(rect: CGRect(origin: .zero, size: s), transform: nil)
            linear(ctx, all, [c(0.16, 0.16, 0.36), c(0.08, 0.1, 0.24), c(0.03, 0.05, 0.14)], CGPoint(x: 0, y: s.height * 0.35), CGPoint(x: 0, y: s.height), [0, 0.4, 1])
            var rng = SeededRNG(seed: 11)
            for _ in 0..<Int(s.width * s.height / 450) {
                let x = CGFloat.random(in: 0...s.width, using: &rng)
                let y = CGFloat.random(in: s.height * 0.3...s.height, using: &rng)
                let r = CGFloat.random(in: 0.3...1.1, using: &rng)
                let a = CGFloat.random(in: 0.25...0.95, using: &rng)
                if r > 0.95 {
                    glow(ctx, .white, 4) { fill(ctx, ell(x, y, r * 2, r * 2), c(1, 1, 1, a)) }
                } else {
                    fill(ctx, ell(x, y, r * 2, r * 2), c(0.9, 0.92, 1, a))
                }
            }
            // crescent moon with glow
            let mx = s.width * 0.2, my = s.height * 0.78, mr = s.height * 0.06
            radial(ctx, ell(mx, my, mr * 7, mr * 7), [c(0.85, 0.8, 1, 0.3), c(0.6, 0.6, 0.9, 0.08), c(0.5, 0.5, 0.8, 0)], CGPoint(x: mx, y: my), mr * 3.5, [0, 0.4, 1])
            ctx.saveGState()
            let moon = CGMutablePath()
            moon.addPath(ell(mx, my, mr * 2, mr * 2))
            moon.addPath(ell(mx + mr * 0.55, my + mr * 0.3, mr * 1.8, mr * 1.8))
            ctx.addPath(moon)
            ctx.clip(using: .evenOdd)
            glow(ctx, c(1, 0.95, 0.8), 14) {
                radial(ctx, ell(mx, my, mr * 2, mr * 2), [c(1, 0.98, 0.9), c(0.95, 0.88, 0.72)], CGPoint(x: mx - mr * 0.4, y: my), mr * 1.3)
            }
            ctx.restoreGState()
        }
    }

    /// Horizontally tileable cloud bank (width = tile).
    static func clouds(_ size: CGSize) -> SKTexture {
        return texture("clouds\(Int(size.width))x\(Int(size.height))", size, scale: Painter.screen) { ctx, s in
            var rng = SeededRNG(seed: 5)
            let banks = 4
            for b in 0..<banks {
                let cx = s.width * (CGFloat(b) + 0.3 + CGFloat.random(in: 0...0.4, using: &rng)) / CGFloat(banks)
                let cy = s.height * CGFloat.random(in: 0.3...0.62, using: &rng)
                let bw = s.width * CGFloat.random(in: 0.18...0.3, using: &rng)
                for k in 0..<18 {
                    let t = CGFloat(k) / 17
                    let x = cx - bw / 2 + bw * t + CGFloat.random(in: -10...10, using: &rng)
                    let hump = sin(t * .pi)
                    let r = s.height * (0.08 + 0.16 * hump) * CGFloat.random(in: 0.7...1.1, using: &rng)
                    let y = cy + r * 0.3 * hump
                    for dx in [-s.width, 0, s.width] {
                        let p = ell(x + dx, y, r * 2, r * 1.7)
                        radial(ctx, p, [c(0.48, 0.42, 0.72, 0.95), c(0.24, 0.24, 0.46, 0.92), c(0.12, 0.13, 0.3, 0.0)],
                               CGPoint(x: x + dx + r * 0.25, y: y + r * 0.45), r * 1.1, [0, 0.55, 1])
                    }
                }
            }
        }
    }

    /// Tileable mountain range. `seed` changes the ridge, `col` its colour.
    static func mountains(_ size: CGSize, seed: Int, top: UIColor, bottom: UIColor, rough: CGFloat) -> SKTexture {
        return texture("mtn\(seed)_\(Int(size.width))x\(Int(size.height))", size, scale: Painter.screen) { ctx, s in
            var rng = SeededRNG(seed: UInt64(seed))
            var waves: [(CGFloat, CGFloat, CGFloat)] = []
            for k in [2, 3, 5, 7, 11, 17] {
                waves.append((CGFloat(k), CGFloat.random(in: 0.3...1, using: &rng) / sqrt(CGFloat(k)), CGFloat.random(in: 0...6.28, using: &rng)))
            }
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 0))
            var x: CGFloat = 0
            while x <= s.width {
                var h: CGFloat = 0
                for (k, a, ph) in waves { h += a * sin(2 * .pi * k * x / s.width + ph) }
                let peak = abs(sin(2 * .pi * 4 * x / s.width + 1.3)) * rough
                p.addLine(to: CGPoint(x: x, y: s.height * (0.55 + 0.18 * h + 0.2 * peak)))
                x += 3
            }
            p.addLine(to: CGPoint(x: s.width, y: 0))
            p.closeSubpath()
            linear(ctx, p, [top, bottom], CGPoint(x: 0, y: s.height), CGPoint(x: 0, y: 0))
        }
    }

    static func hedge(_ size: CGSize) -> SKTexture {
        return texture("hedge\(Int(size.width))x\(Int(size.height))", size, scale: Painter.screen) { ctx, s in
            var rng = SeededRNG(seed: 9)
            fill(ctx, CGPath(rect: CGRect(x: 0, y: 0, width: s.width, height: s.height * 0.35), transform: nil), c(0.06, 0.1, 0.12))
            var x: CGFloat = 0
            while x < s.width {
                let r = s.height * CGFloat.random(in: 0.2...0.55, using: &rng)
                for dx in [-s.width, 0, s.width] {
                    radial(ctx, ell(x + dx, s.height * 0.35, r * 2.2, r * 2.2), [c(0.14, 0.2, 0.22), c(0.05, 0.09, 0.11)], CGPoint(x: x + dx - r * 0.3, y: s.height * 0.35 + r * 0.5), r * 1.2)
                }
                x += r * CGFloat.random(in: 0.9...1.6, using: &rng)
            }
        }
    }

    static func field(_ size: CGSize) -> SKTexture {
        return texture("field\(Int(size.width))x\(Int(size.height))", size, scale: Painter.screen) { ctx, s in
            let all = CGPath(rect: CGRect(origin: .zero, size: s), transform: nil)
            linear(ctx, all, [c(0.2, 0.25, 0.32), c(0.15, 0.24, 0.18), c(0.1, 0.18, 0.11), c(0.04, 0.07, 0.05)],
                   CGPoint(x: 0, y: s.height), CGPoint(x: 0, y: 0), [0, 0.12, 0.55, 1])
            var rng = SeededRNG(seed: 3)
            for _ in 0..<Int(s.width * s.height / 22) {
                let x = CGFloat.random(in: 0...s.width, using: &rng)
                let y = CGFloat.random(in: 0...s.height, using: &rng)
                let l = CGFloat.random(in: 0.7...1.3, using: &rng)
                let h = 1 + (1 - y / s.height) * 3
                stroke(ctx, line(CGPoint(x: x, y: y), CGPoint(x: x + CGFloat.random(in: -1...1, using: &rng), y: y + h)), c(0.2 * l, 0.32 * l, 0.18 * l, 0.25), 1)
            }
        }
    }
}

/// Tiny deterministic RNG so painted backdrops look the same every launch.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
