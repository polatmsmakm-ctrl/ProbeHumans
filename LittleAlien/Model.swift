import SpriteKit

enum Kind {
    case human, kid, dog, cow, car

    var points: Int {
        switch self {
        case .kid: return 8
        case .human: return 10
        case .dog: return 15
        case .cow: return 25
        case .car: return 40
        }
    }

    var streakValue: Int {
        switch self {
        case .kid, .human, .dog: return 1
        case .cow: return 2
        case .car: return 3
        }
    }

    /// Pull speed multiplier: heavier things rise slower.
    var weight: CGFloat {
        switch self {
        case .kid: return 1.2
        case .human: return 1.0
        case .dog: return 1.1
        case .cow: return 0.7
        case .car: return 0.45
        }
    }
}

enum PowerType {
    case rampage, magnet, multiply
}

enum Tuning {
    static let tierThresholds: [Int] = [0, 25, 75, 150, 300, 500]
    static let tierMultiplier: [Int] = [1, 2, 3, 4, 5, 6]
    static let tierSpeedBoost: [CGFloat] = [0, 16, 24, 32, 48, 64]
    static let baseSpeed: CGFloat = 140
    static let maxExtraSpeed: CGFloat = 110
    static let pullSpeed: CGFloat = 200
    static let powerDuration: CGFloat = 8
    static let maxHealth = 3
}

final class Creature: SKNode {
    let kind: Kind
    var dir: CGFloat = Bool.random() ? 1 : -1
    var walkSpeed: CGFloat
    var lifted = false
    var fallV: CGFloat = 0
    var baseY: CGFloat = 0
    var wob: CGFloat = CGFloat.random(in: 0..<6.28)

    init(kind: Kind) {
        self.kind = kind
        self.walkSpeed = (kind == .car) ? CGFloat.random(in: 70...120) : CGFloat.random(in: 14...34)
        super.init()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class Pickup: SKNode {
    let type: PowerType
    var baseY: CGFloat = 0

    init(type: PowerType) {
        self.type = type
        super.init()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class Missile: SKNode {
    var v = CGVector.zero
    var life: CGFloat = 5
}

final class Turret: SKNode {
    var fired = false
}

final class Bird: SKNode {
    var vx: CGFloat = -60
}
