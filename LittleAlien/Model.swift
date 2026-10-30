import SpriteKit
import UIKit

// MARK: - Powers

enum PowerType: Int, CaseIterable {
    case rampage = 0, magnet, multiply

    var title: String {
        switch self {
        case .rampage: return "Rampage"
        case .magnet: return "Magnet"
        case .multiply: return "Multiply"
        }
    }

    var blurb: String {
        switch self {
        case .rampage: return "Wide beam that smashes vehicles"
        case .magnet: return "Pulls coins in from far away"
        case .multiply: return "Doubles every score you earn"
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
        case .rampage: return UIColor.systemRed
        case .magnet: return UIColor.systemBlue
        case .multiply: return UIColor.systemYellow
        }
    }
}

// MARK: - Tuning (all gameplay numbers live here)

enum Tuning {
    /// Points per world unit.
    static let unit: CGFloat = 11

    // Speed (world units per second)
    static let startSpeed: CGFloat = 12
    static let speedGain: CGFloat = 0.083
    static let maxSpeed: CGFloat = 20
    static let boostSpeed: CGFloat = 30
    static let boostDistance: CGFloat = 300     // meters of head start
    static let boostInvuln: CGFloat = 3

    // Streak / multiplier levels 0...5
    static let streakCounts: [Int] = [0, 25, 75, 150, 300, 500]
    static let streakMult: [Int] = [1, 2, 3, 4, 5, 6]
    static let streakSpeed: [CGFloat] = [0, 2, 3, 4, 6, 8]
    static let streakWindow: CGFloat = 5

    // UFO tiers 0...3
    static let ufoHealth: [Int] = [3, 4, 4, 5]
    static let ufoTierCost: [Int] = [1000, 5000, 7500]       // to reach tier 1, 2, 3
    static let ufoBuyCost: [Int] = [0, 10000, 15000, 20000, 25000]

    // Shop
    static let powerCost: [Int] = [200, 2000, 6000]          // to reach level 1, 2, 3
    static let healthPackCost = 5000
    static let headStartCost = 2000
    static let meterUpCost = 1000

    // Beam
    static let beamRadius: CGFloat = 34
    static let rampageRadiusFactor: CGFloat = 2.2
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

    // Coins
    static let coinValue = 5
    static let scoreToCoinsDivisor = 20
}

// MARK: - Creatures

enum Kind {
    case cow, sheep, soldier, fireman, pig, pitchforkMan, farmer, reporter, dog

    var weight: CGFloat {
        switch self {
        case .cow: return 4
        case .pitchforkMan: return 2.5
        case .pig: return 2.5
        case .sheep: return 2
        case .dog: return 1
        default: return 1.5
        }
    }

    var walk: ClosedRange<CGFloat> {
        switch self {
        case .cow: return 6...14
        case .sheep: return 10...22
        case .dog: return 30...60
        case .pig: return 10...20
        default: return 16...34
        }
    }

    var flees: Bool { return self != .cow }
}

// MARK: - Obstacles

enum ObKind {
    case fence, shed, barrel, car, police, jeep, truck, windmill, silo, house, fireTruck, barn, tank

    var damage: Int {
        switch self {
        case .fence, .shed: return 1
        case .barrel, .car, .police, .jeep, .truck, .windmill, .silo: return 2
        case .house, .fireTruck: return 3
        case .barn, .tank: return 4
        }
    }

    var weight: CGFloat {
        switch self {
        case .barrel: return 1
        case .fence: return 3
        case .shed, .windmill: return 4
        case .fireTruck: return 5
        case .car, .police, .jeep, .truck: return 6
        case .silo: return 7
        case .house: return 8
        case .barn, .tank: return 10
        }
    }

    var isStatic: Bool {
        switch self {
        case .fence, .shed, .windmill, .silo, .house, .barn: return true
        default: return false
        }
    }

    var isVehicle: Bool {
        switch self {
        case .car, .police, .jeep, .truck, .fireTruck, .tank: return true
        default: return false
        }
    }

    var halfWidth: CGFloat {
        switch self {
        case .fence: return 28
        case .shed: return 24
        case .barrel: return 8
        case .car, .police: return 34
        case .jeep: return 32
        case .truck: return 42
        case .fireTruck: return 46
        case .tank: return 30
        case .windmill: return 22
        case .silo: return 16
        case .house: return 32
        case .barn: return 44
        }
    }
}

// MARK: - Entities

final class Flock {
    var x: CGFloat
    var dir: CGFloat
    var speed: CGFloat

    init(x: CGFloat) {
        self.x = x
        self.dir = Bool.random() ? 1 : -1
        self.speed = CGFloat.random(in: 8...16)
    }
}

final class Creature: SKNode {
    let kind: Kind
    let value: Int
    var dir: CGFloat = Bool.random() ? 1 : -1
    var walkSpeed: CGFloat
    var lifted = false
    var fallV: CGFloat = 0
    var baseY: CGFloat = 0
    var wob: CGFloat = CGFloat.random(in: 0..<6.28)
    var flock: Flock?
    var flockOffset: CGFloat = 0
    var flashTimer: CGFloat = CGFloat.random(in: 1...4)

    init(kind: Kind, value: Int) {
        self.kind = kind
        self.value = value
        self.walkSpeed = CGFloat.random(in: kind.walk)
        super.init()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class Obstacle: SKNode {
    let kind: ObKind
    var dir: CGFloat = -1
    var driveSpeed: CGFloat = 0
    var lifted = false
    var fallV: CGFloat = 0
    var baseY: CGFloat = 0
    var dead = false
    var fireTimer: CGFloat = CGFloat.random(in: 0.8...2)
    var wob: CGFloat = CGFloat.random(in: 0..<6.28)

    init(kind: ObKind) {
        self.kind = kind
        super.init()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class Coin: SKNode {
    var lifted = false
    var homing = false
    var baseY: CGFloat = 0
    var phase: CGFloat = CGFloat.random(in: 0..<6.28)
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
}

final class Store {
    static let shared = Store()
    private let key = "littleAlienSave2"
    var d: SaveData

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(SaveData.self, from: data) {
            d = s
        } else {
            d = SaveData()
            d.bestScore = UserDefaults.standard.integer(forKey: "littleAlienBest")
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    var currentTier: Int { return d.ufoTier[d.selectedUFO] }
    var maxHealth: Int { return Tuning.ufoHealth[currentTier] }
    var upgradedMultiplier: Bool { return currentTier >= 2 }
    var keepsPowerups: Bool { return currentTier >= 3 }
}
