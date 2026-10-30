import SpriteKit
import UIKit

/// Simple rounded button for SpriteKit menus.
final class Button: SKNode {
    let size: CGSize
    let onTap: () -> Void
    let enabled: Bool
    private let bg: SKShapeNode

    init(_ text: String, w: CGFloat, h: CGFloat = 44, color: UIColor, textColor: UIColor = .white,
         fontSize: CGFloat = 18, enabled: Bool = true, action: @escaping () -> Void) {
        self.size = CGSize(width: w, height: h)
        self.onTap = action
        self.enabled = enabled
        self.bg = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: min(14, h / 2))
        super.init()
        let shadow = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: min(14, h / 2))
        shadow.fillColor = color.darker(0.55)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -3)
        addChild(shadow)
        bg.fillColor = enabled ? color : UIColor(white: 0.35, alpha: 1)
        bg.strokeColor = UIColor(white: 1, alpha: 0.25)
        bg.lineWidth = 1.5
        addChild(bg)
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = fontSize
        l.fontColor = enabled ? textColor : UIColor(white: 0.7, alpha: 1)
        l.verticalAlignmentMode = .center
        l.horizontalAlignmentMode = .center
        addChild(l)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func hit(_ t: UITouch) -> Bool {
        guard let p = parent, !isHidden, alpha > 0.05 else { return false }
        let lp = t.location(in: p)
        let r = CGRect(x: position.x - size.width / 2 * xScale - 6, y: position.y - size.height / 2 * yScale - 6,
                       width: size.width * xScale + 12, height: size.height * yScale + 12)
        return r.contains(lp)
    }

    func press() {
        run(.sequence([.scale(to: 0.92, duration: 0.05), .scale(to: 1, duration: 0.08)]))
    }
}

enum UIK {
    static func label(_ text: String, size: CGFloat, color: UIColor = .white, bold: Bool = true,
                      x: CGFloat = 0, y: CGFloat = 0, align: SKLabelHorizontalAlignmentMode = .center) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: bold ? "AvenirNext-Heavy" : "AvenirNext-DemiBold")
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = align
        l.verticalAlignmentMode = .center
        l.position = CGPoint(x: x, y: y)
        return l
    }

    static func panel(_ w: CGFloat, _ h: CGFloat, x: CGFloat = 0, y: CGFloat = 0, alpha: CGFloat = 0.82) -> SKShapeNode {
        let p = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 18)
        p.fillColor = UIColor(red: 0.08, green: 0.06, blue: 0.22, alpha: alpha)
        p.strokeColor = UIColor(red: 0.5, green: 1, blue: 0.7, alpha: 0.5)
        p.lineWidth = 2
        p.position = CGPoint(x: x, y: y)
        return p
    }

    static let green = UIColor(red: 0.2, green: 0.75, blue: 0.4, alpha: 1)
    static let yellow = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
    static let blue = UIColor(red: 0.25, green: 0.45, blue: 0.9, alpha: 1)
    static let purple = UIColor(red: 0.5, green: 0.3, blue: 0.85, alpha: 1)
    static let red = UIColor(red: 0.85, green: 0.25, blue: 0.3, alpha: 1)
    static let gray = UIColor(white: 0.4, alpha: 1)

    static func coins(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
