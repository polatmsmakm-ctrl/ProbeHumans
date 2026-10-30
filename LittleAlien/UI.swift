import SpriteKit
import UIKit

enum UIK {
    static let comic = "MarkerFelt-Wide"
    static let heavyItalic = "AvenirNext-HeavyItalic"

    static let orange = UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)
    static let orangeDark = UIColor(red: 0.55, green: 0.12, blue: 0.05, alpha: 1)
    static let panelFill = UIColor(red: 0.32, green: 0.22, blue: 0.58, alpha: 0.96)
    static let panelEdge = UIColor(red: 0.5, green: 0.4, blue: 0.82, alpha: 1)
    static let cardFill = UIColor(red: 0.24, green: 0.16, blue: 0.46, alpha: 1)
    static let cyan = UIColor(red: 0.62, green: 0.95, blue: 1, alpha: 1)
    static let yellow = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
    static let green = UIColor(red: 0.2, green: 0.75, blue: 0.4, alpha: 1)
    static let red = UIColor(red: 0.9, green: 0.25, blue: 0.3, alpha: 1)

    /// Label with a dark drop shadow (comic look).
    static func label(_ text: String, size: CGFloat, color: UIColor = .white, font: String = comic,
                      x: CGFloat = 0, y: CGFloat = 0, align: SKLabelHorizontalAlignmentMode = .center,
                      shadow: UIColor? = UIColor(white: 0, alpha: 0.55)) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: font)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = align
        l.verticalAlignmentMode = .center
        l.position = CGPoint(x: x, y: y)
        if let s = shadow {
            let sh = SKLabelNode(fontNamed: font)
            sh.text = text
            sh.fontSize = size
            sh.fontColor = s
            sh.horizontalAlignmentMode = align
            sh.verticalAlignmentMode = .center
            sh.position = CGPoint(x: size * 0.06, y: -size * 0.08)
            sh.zPosition = -1
            l.addChild(sh)
        }
        return l
    }

    static func panel(_ w: CGFloat, _ h: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> SKNode {
        let n = SKNode()
        n.position = CGPoint(x: x, y: y)
        let sh = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: min(40, h * 0.18))
        sh.fillColor = UIColor(white: 0, alpha: 0.35)
        sh.strokeColor = .clear
        sh.position = CGPoint(x: 4, y: -6)
        n.addChild(sh)
        let p = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: min(40, h * 0.18))
        p.fillColor = panelFill
        p.strokeColor = panelEdge
        p.lineWidth = 5
        n.addChild(p)
        let inner = SKShapeNode(rectOf: CGSize(width: w - 22, height: h - 22), cornerRadius: min(32, h * 0.15))
        inner.fillColor = .clear
        inner.strokeColor = UIColor(white: 1, alpha: 0.07)
        inner.lineWidth = 3
        n.addChild(inner)
        return n
    }

    static func coins(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    static func coinIcon(_ r: CGFloat = 8) -> SKNode {
        let n = SKNode()
        n.addChild(Art.circ(r, Art.rgb(0.85, 0.55, 0.05), stroke: Art.rgb(0.5, 0.3, 0)))
        n.addChild(Art.circ(r * 0.72, Art.rgb(1, 0.82, 0.2)))
        return n
    }
}

/// Tappable button. `plain` = orange comic text only (like the original menus).
final class Button: SKNode {
    let size: CGSize
    let onTap: () -> Void
    let enabled: Bool

    init(_ text: String, w: CGFloat, h: CGFloat = 44, color: UIColor = UIK.orange, textColor: UIColor = .white,
         fontSize: CGFloat = 18, enabled: Bool = true, plain: Bool = false, coin: Bool = false,
         action: @escaping () -> Void) {
        self.size = CGSize(width: w, height: h)
        self.onTap = action
        self.enabled = enabled
        super.init()
        if plain {
            let l = UIK.label(text, size: fontSize, color: enabled ? UIK.orange : UIColor(white: 0.6, alpha: 1),
                              shadow: UIK.orangeDark)
            addChild(l)
            return
        }
        let r = min(12, h / 2)
        let shadow = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: r)
        shadow.fillColor = (enabled ? color : UIColor(white: 0.3, alpha: 1)).darker(0.5)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        addChild(shadow)
        let bg = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: r)
        bg.fillColor = enabled ? color : UIColor(white: 0.38, alpha: 1)
        bg.strokeColor = UIColor(white: 1, alpha: 0.35)
        bg.lineWidth = 1.5
        addChild(bg)
        let hi = SKShapeNode(rectOf: CGSize(width: w - 8, height: h * 0.35), cornerRadius: r * 0.6)
        hi.fillColor = UIColor(white: 1, alpha: 0.18)
        hi.strokeColor = .clear
        hi.position = CGPoint(x: 0, y: h * 0.2)
        addChild(hi)
        let l = UIK.label(text, size: fontSize, color: enabled ? textColor : UIColor(white: 0.75, alpha: 1),
                          shadow: UIColor(white: 0, alpha: 0.35))
        if coin {
            let icon = UIK.coinIcon(fontSize * 0.42)
            let tw = CGFloat(text.count) * fontSize * 0.5
            icon.position = CGPoint(x: -tw / 2 - fontSize * 0.25, y: 0)
            l.position.x = fontSize * 0.35
            addChild(icon)
        }
        addChild(l)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func hit(_ t: UITouch) -> Bool {
        guard let p = parent, !isHidden, alpha > 0.05 else { return false }
        let lp = t.location(in: p)
        let r = CGRect(x: position.x - size.width / 2 * xScale - 8, y: position.y - size.height / 2 * yScale - 8,
                       width: size.width * xScale + 16, height: size.height * yScale + 16)
        return r.contains(lp)
    }

    func press() {
        run(.sequence([.scale(to: 0.9, duration: 0.05), .scale(to: 1, duration: 0.08)]))
        Sound.shared.play("click", volume: 0.6)
    }
}
