import SpriteKit
import UIKit

// MARK: - Powers

enum PowerType: Int, CaseIterable {
    case rampage = 0, magnet, multiply

    var title: String {
        switch self {
        case .rampage: return "Rampage"
        case .magnet: return "Magnet"
        case .multiply: return "Multiplier"
        }
    }

    var blurb: String {
        switch self {
        case .rampage: return "Huge beam that smashes obstacles"
        case .magnet: return "Pulls in coins from all around"
        case .multiply: return "Double points"
        }
    }

    /// Seconds of effect for upgrade level 1, 2, 3.
    var durations: [CGFloat] {
        switch self {
        case .rampage: return [5, 10, 15]
        case .magnet: return [15, 20, 25]
        case .multiply: return [10, 15, 20]
        }
    }

    var color: UIColor {
        switch self {
        case .rampage: return UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1)
        case .magnet: return UIColor(red: 0.95, green: 0.2, blue: 0.3, alpha: 1)
        case .multiply: return UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1)
        }
    }
}

// MARK: - Tuning (all gameplay numbers live here)

enum Tuning {
    /// World units per meter (and per speed unit).
    static let unit: CGFloat = 10

    // Speed (meters per second)
    static let startSpeed: CGFloat = 12
    static let speedGain: CGFloat = 0.083
    static let maxSpeed: CGFloat = 20
    /// Extra speed earned from score: start + max * (1 - e^(-score/scale)).
    static let scoreSpeedMax: CGFloat = 18
    static let scoreSpeedScale: CGFloat = 3000
    static let boostSpeed: CGFloat = 34
    static let boostDistance: CGFloat = 300
    static let boostInvuln: CGFloat = 3

    // Streak / multiplier levels 0...5
    static let streakCounts: [Int] = [0, 25, 75, 150, 300, 500]
    static let streakMult: [Int] = [1, 2, 3, 4, 5, 6]
    static let streakSpeed: [CGFloat] = [0, 2, 3, 4, 6, 8]
    static let streakWindow: CGFloat = 6

    // UFO tiers 0...3
    static let ufoHealth: [Int] = [3, 4, 4, 5]
    static let ufoTierCost: [Int] = [1000, 5000, 7500]
    static let ufoBuyCost: [Int] = [0, 10000, 15000, 20000, 25000]

    // Shop
    static let powerCost: [Int] = [200, 2000, 6000]
    static let healthPackCost = 5000
    static let headStartCost = 2000
    static let meterUpCost = 1000

    // Beam (world units on the ground)
    static let beamRadius: CGFloat = 30
    static let rampageRadiusFactor: CGFloat = 2.0
    static let damageTime: CGFloat = 1.2

    // World
    static let groundDuration: CGFloat = 30
    static let vehicleDuration: CGFloat = 15
    static let vehicleDurationGrowth: CGFloat = 2.5
    static let maxVehicleDifficulty = 6
    static let maxVehicles = 50
    static let policeFrom = 1500
    static let jeepFrom = 3000
    static let tankFrom = 3000
    static let fireTruckFrom = 1000
    static let signEvery = 500
}

// MARK: - Creatures

enum Kind: Int {
    case sheep, cow, pig, grumpa, farmer, dog, fireman, soldier, reporter

    var weight: CGFloat {
        switch self {
        case .cow: return 4
        case .pig: return 2.5
        case .sheep: return 1.5
        case .dog: return 1
        default: return 2
        }
    }

    /// world units per second
    var walk: ClosedRange<CGFloat> {
        switch self {
        case .cow: return 8...16
        case .sheep: return 14...26
        case .dog: return 60...90
        case .pig: return 10...20
        case .grumpa: return 22...34
        default: return 26...40
        }
    }

    var flees: Bool { return self != .cow && self != .pig }
    var isHuman: Bool { return [.grumpa, .farmer, .fireman, .soldier, .reporter].contains(self) }
}

/// Animals and people you can unlock in the store (the "HUMANS" tab of the original).
struct Unlockable {
    let id: String
    let name: String
    let kind: Kind
    let variant: Int
    let points: Int
    let cost: Int   // 0 = available at start

    static let all: [Unlockable] = [
        Unlockable(id: "sheep", name: "Sheep", kind: .sheep, variant: 0, points: 5, cost: 0),
        Unlockable(id: "grumpa", name: "Grumpa", kind: .grumpa, variant: 0, points: 10, cost: 0),
        Unlockable(id: "cow", name: "Milky Cow", kind: .cow, variant: 0, points: 20, cost: 0),
        Unlockable(id: "pig", name: "Piggy", kind: .pig, variant: 0, points: 8, cost: 0),
        Unlockable(id: "farmer", name: "Farm Boy", kind: .farmer, variant: 0, points: 8, cost: 0),
        Unlockable(id: "blacksheep", name: "Black Sheep", kind: .sheep, variant: 1, points: 12, cost: 1500),
        Unlockable(id: "browncow", name: "Choco Cow", kind: .cow, variant: 1, points: 25, cost: 2500),
        Unlockable(id: "greenpig", name: "Muddy Pig", kind: .pig, variant: 1, points: 15, cost: 2000),
        Unlockable(id: "fireman", name: "Fireman", kind: .fireman, variant: 0, points: 15, cost: 3000),
        Unlockable(id: "reporter", name: "Reporter", kind: .reporter, variant: 0, points: 12, cost: 3500),
        Unlockable(id: "soldier", name: "Soldier", kind: .soldier, variant: 0, points: 30, cost: 4000),
        Unlockable(id: "purplecow", name: "Space Cow", kind: .cow, variant: 2, points: 40, cost: 6000),
        Unlockable(id: "goldsheep", name: "Golden Sheep", kind: .sheep, variant: 2, points: 50, cost: 8000),
    ]

    static func points(_ k: Kind, _ v: Int) -> Int {
        return all.first { $0.kind == k && $0.variant == v }?.points ?? (k == .dog ? 3 : 5)
    }
}

// MARK: - Obstacles

enum ObKind {
    case fence, shed, barrels, car, police, jeep, truck, windmill, silo, house, fireTruck, barn, tank

    var damage: Int {
        switch self {
        case .fence, .shed: return 1
        case .barrels, .car, .police, .jeep, .truck, .windmill, .silo: return 2
        case .house, .fireTruck: return 3
        case .barn, .tank: return 4
        }
    }

    var isStatic: Bool {
        switch self {
        case .fence, .shed, .windmill, .silo, .house, .barn, .barrels: return true
        default: return false
        }
    }

    var isVehicle: Bool {
        switch self {
        case .car, .police, .jeep, .truck, .fireTruck, .tank: return true
        default: return false
        }
    }

    /// Half width and full height of the hit box in art points (at scale 1).
    var hitBox: (CGFloat, CGFloat) {
        switch self {
        case .fence: return (40, 20)
        case .shed: return (24, 40)
        case .barrels: return (16, 20)
        case .car, .police: return (32, 26)
        case .jeep: return (30, 30)
        case .truck: return (42, 36)
        case .fireTruck: return (46, 32)
        case .tank: return (30, 30)
        case .windmill: return (14, 110)
        case .silo: return (18, 80)
        case .house: return (34, 70)
        case .barn: return (42, 66)
        }
    }

    /// Footprint half-depth used to decide whether the beam is at the same depth.
    var depthTolerance: CGFloat {
        switch self {
        case .fence: return 0.06
        case .barrels: return 0.07
        default: return 0.11
        }
    }
}

// MARK: - Entities (positions are in ground space: x = world units, d = depth)

class GroundThing: SKNode {
    var gx: CGFloat = 0
    var gd: CGFloat = 2
    var lifting = false
    var liftT: CGFloat = 0
    var liftOffset = CGPoint.zero
    var liftScale: CGFloat = 1
    var spin: CGFloat = CGFloat.random(in: -1...1)
}

final class Flock {
    var x: CGFloat
    var d: CGFloat
    var vx: CGFloat
    var vd: CGFloat

    init(x: CGFloat, d: CGFloat) {
        self.x = x
        self.d = d
        self.vx = CGFloat.random(in: -10...10)
        self.vd = CGFloat.random(in: -0.04...0.04)
    }
}

final class Creature: GroundThing {
    let kind: Kind
    let variant: Int
    let value: Int
    let body: SKNode
    var vx: CGFloat = 0
    var vd: CGFloat = 0
    var walkSpeed: CGFloat
    var wanderTimer: CGFloat = 0
    var flock: Flock?
    var offX: CGFloat = 0
    var offD: CGFloat = 0
    var wob: CGFloat = CGFloat.random(in: 0..<6.28)
    var flashTimer: CGFloat = CGFloat.random(in: 1...4)
    var spoke = false

    init(kind: Kind, variant: Int, body: SKNode) {
        self.kind = kind
        self.variant = variant
        self.value = Unlockable.points(kind, variant)
        self.body = body
        self.walkSpeed = CGFloat.random(in: kind.walk)
        super.init()
        addChild(body)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class Obstacle: GroundThing {
    let kind: ObKind
    var vx: CGFloat = 0
    var lane: CGFloat = 0
    var dead = false
    var fireTimer: CGFloat = CGFloat.random(in: 1...2)
    var hitCooldown: CGFloat = 0

    init(kind: ObKind) {
        self.kind = kind
        super.init()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class Coin: GroundThing {
    var drift = false
}

final class Pickup: GroundThing {
    let type: PowerType

    init(type: PowerType) {
        self.type = type
        super.init()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Ground decorations (grass tufts, mud, signs, scenery) that only need projecting.
final class Decal: GroundThing {
    var flat = false      // drawn flat on the ground (scaled in y by perspective)
    var worldW: CGFloat = 0
    var worldD: CGFloat = 0
}

final class Missile: SKNode {
    var v = CGVector.zero
    var life: CGFloat = 4
}

// MARK: - Run options chosen in the menu

struct RunConfig {
    var healthPack = false
    var headStart = false
    var meterUp = false
}

// MARK: - Saved progress (stored on the device only)

struct SaveData: Codable {
    var coins = 0
    var bestScore = 0
    var bestDistance = 0
    var powerLevel: [Int] = [0, 0, 0]
    var ufoOwned: [Bool] = [true, false, false, false, false]
    var ufoTier: [Int] = [0, 0, 0, 0, 0]
    var selectedUFO = 0
    var healthPacks = 0
    var headStarts = 0
    var meterUps = 0
    var touchSense: Double = 1.0
    var vehiclesDestroyed = 0
    var tanksDestroyed = 0
    var powerupsCollected = 0
    var deathsByVehicle = 0
    var totalAbducted = 0
    var runs = 0
    var unlocked: [String]? = nil
}

final class Store {
    static let shared = Store()
    private let key = "littleAlienSave3"
    var d: SaveData

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(SaveData.self, from: data) {
            d = s
        } else if let data = UserDefaults.standard.data(forKey: "littleAlienSave2"),
                  let s = try? JSONDecoder().decode(SaveData.self, from: data) {
            d = s
        } else {
            d = SaveData()
        }
        if d.unlocked == nil {
            d.unlocked = Unlockable.all.filter { $0.cost == 0 }.map { $0.id }
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func isUnlocked(_ id: String) -> Bool { return d.unlocked?.contains(id) ?? false }

    func unlockedVariants(_ k: Kind) -> [Int] {
        return Unlockable.all.filter { $0.kind == k && isUnlocked($0.id) }.map { $0.variant }
    }

    var currentTier: Int { return d.ufoTier[d.selectedUFO] }
    var maxHealth: Int { return Tuning.ufoHealth[currentTier] }
    var upgradedMultiplier: Bool { return currentTier >= 2 }
    var keepsPowerups: Bool { return currentTier >= 3 }
}
