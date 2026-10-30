import SpriteKit
import UIKit

// MARK: - Powers

enum PowerType: Int, CaseIterable {
    case rampage = 0, magnet, multiply, shield, twin, slowmo

    var title: String {
        switch self {
        case .rampage: return "Rampage"
        case .magnet: return "Magnet"
        case .multiply: return "Multiplier"
        case .shield: return "Shield"
        case .twin: return "Twin Beam"
        case .slowmo: return "Slow-Mo"
        }
    }

    var blurb: String {
        switch self {
        case .rampage: return "Huge beam that smashes obstacles"
        case .magnet: return "Pulls in coins from all around"
        case .multiply: return "Double points"
        case .shield: return "Blocks the next hit"
        case .twin: return "Two beams at once"
        case .slowmo: return "Slows the whole world"
        }
    }

    /// Seconds of effect for upgrade level 1, 2, 3.
    var durations: [CGFloat] {
        switch self {
        case .rampage: return [5, 10, 15]
        case .magnet: return [15, 20, 25]
        case .multiply: return [10, 15, 20]
        case .shield: return [20, 30, 40]
        case .twin: return [10, 13, 16]
        case .slowmo: return [5, 7, 9]
        }
    }

    var color: UIColor {
        switch self {
        case .rampage: return UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1)
        case .magnet: return UIColor(red: 0.95, green: 0.2, blue: 0.3, alpha: 1)
        case .multiply: return UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1)
        case .shield: return UIColor(red: 0.3, green: 0.7, blue: 1, alpha: 1)
        case .twin: return UIColor(red: 0.75, green: 0.4, blue: 1, alpha: 1)
        case .slowmo: return UIColor(red: 0.3, green: 1, blue: 0.75, alpha: 1)
        }
    }
}

// MARK: - Tuning (all gameplay numbers live here)

enum Tuning {
    /// World units per meter (and per speed unit).
    static let unit: CGFloat = 10

    // Speed (meters per second)
    static let startSpeed: CGFloat = 14
    static let speedGain: CGFloat = 0.083
    static let maxSpeed: CGFloat = 20
    /// Extra speed earned from score: start + max * (1 - e^(-score/scale)).
    static let scoreSpeedMax: CGFloat = 19
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
    case sheep, cow, pig, grumpa, farmer, dog, fireman, soldier, reporter, hunter, camel, bedouin, citizen

    var weight: CGFloat {
        switch self {
        case .cow: return 4
        case .camel: return 5
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
        case .camel: return 10...18
        case .hunter: return 0...0
        default: return 26...40
        }
    }

    var flees: Bool { return self != .cow && self != .pig && self != .camel && self != .hunter }
    var isHuman: Bool { return [.grumpa, .farmer, .fireman, .soldier, .reporter, .hunter, .bedouin, .citizen].contains(self) }
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
        if let u = all.first(where: { $0.kind == k && $0.variant == v }) { return u.points }
        switch k {
        case .dog: return 3
        case .hunter: return 25
        case .camel: return 30
        case .bedouin: return 15
        case .citizen: return 10
        case .cow where v == 3: return 60      // nuclear cow
        case .sheep where v == 2: return 100   // rare golden sheep in the wild
        default: return 5
        }
    }
}

// MARK: - Obstacles

enum ObKind {
    case fence, shed, barrels, car, police, jeep, truck, windmill, silo, house, fireTruck, barn, tank
    case powerline, building, lamp, hydrant, tent, palm

    var damage: Int {
        switch self {
        case .fence, .shed: return 1
        case .barrels, .car, .police, .jeep, .truck, .windmill, .silo: return 2
        case .house, .fireTruck: return 3
        case .barn, .tank: return 4
        default: return 1
        }
    }

    var isStatic: Bool {
        switch self {
        case .fence, .shed, .windmill, .silo, .house, .barn, .barrels, .powerline, .building, .lamp, .hydrant, .tent, .palm: return true
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
        case .powerline: return (5, 120)
        case .building: return (52, 140)
        case .lamp: return (5, 92)
        case .hydrant: return (8, 18)
        case .tent: return (40, 40)
        case .palm: return (8, 110)
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
    var onTwin = false
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
    var value: Int
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
    // cached child nodes (looking them up every frame was slow with big flocks)
    var legsNode: SKNode?
    var forkNode: SKNode?
    var flashNode: SKNode?
    var rare = false
    var aimTimer: CGFloat = 2.5
    var aimLine: SKShapeNode?
    var glow: SKNode?

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
    /// power lines: distance to the second pole and the wire drawn between them
    var span: CGFloat = 0
    var wire: SKShapeNode?
    var pole2: SKNode?
    /// boss tank
    var giant = false

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
    var themesOwned: [String]? = nil
    var theme: String? = nil
    // retention
    var missionsDay: String? = nil
    var missions: [Mission]? = nil
    var rewardDay: String? = nil
    var rewardStreak: Int? = nil
    var achievements: [String]? = nil
    var kindCounts: [String: Int]? = nil
    var playerName: String? = nil
    var friends: [FriendScore]? = nil
    var worldsOwned: [String]? = nil
    var world: String? = nil
    var coinsEarnedTotal: Int? = nil
    var bossesBeaten: Int? = nil
    var nukes: Int? = nil
    var raresCaught: Int? = nil
    var furthestBiome: Int? = nil
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
        // older saves only had 3 power slots
        while d.powerLevel.count < PowerType.allCases.count { d.powerLevel.append(0) }
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
    var currentTheme: UFOTheme { return UFOTheme.find(d.theme ?? "classic") }
    func ownsTheme(_ id: String) -> Bool { return id == "classic" || (d.themesOwned ?? []).contains(id) }
    var maxHealth: Int { return Tuning.ufoHealth[currentTier] }
    var upgradedMultiplier: Bool { return currentTier >= 2 }
    var keepsPowerups: Bool { return currentTier >= 3 }
}


// MARK: - Saucer themes (bought in the store with coins)

struct UFOTheme {
    enum Extra { case none, cyberGrid, hazard, candy, icicles, flames, spikes, gold, pumpkin, rainbow }

    let id: String
    let name: String
    let price: Int
    let hullTop: UIColor
    let hullMid: UIColor
    let hullBottom: UIColor
    let deck: UIColor
    let neon: UIColor
    let alien: UIColor
    let glass: UIColor
    let extra: Extra

    static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { return UIColor(red: r, green: g, blue: b, alpha: 1) }

    /// Prices are set around what a run earns (roughly 50–150 coins), so the first themes
    /// come after a few runs and the best ones are long-term goals.
    static let all: [UFOTheme] = [
        UFOTheme(id: "classic", name: "Night Purple", price: 0,
                 hullTop: c(0.5, 0.53, 0.68), hullMid: c(0.22, 0.24, 0.35), hullBottom: c(0.06, 0.07, 0.12),
                 deck: c(0.62, 0.65, 0.8), neon: c(0.72, 0.42, 1), alien: c(0.55, 0.5, 0.72), glass: c(0.75, 0.85, 1), extra: .none),
        UFOTheme(id: "cyber", name: "Cyber Cyan", price: 250,
                 hullTop: c(0.35, 0.45, 0.55), hullMid: c(0.1, 0.16, 0.24), hullBottom: c(0.03, 0.05, 0.09),
                 deck: c(0.4, 0.55, 0.65), neon: c(0.2, 0.95, 1), alien: c(0.6, 0.75, 0.8), glass: c(0.6, 1, 1), extra: .cyberGrid),
        UFOTheme(id: "toxic", name: "Toxic", price: 400,
                 hullTop: c(0.45, 0.5, 0.35), hullMid: c(0.2, 0.24, 0.14), hullBottom: c(0.06, 0.08, 0.04),
                 deck: c(0.55, 0.6, 0.42), neon: c(0.5, 1, 0.2), alien: c(0.45, 0.8, 0.35), glass: c(0.7, 1, 0.6), extra: .hazard),
        UFOTheme(id: "candy", name: "Candy Pop", price: 650,
                 hullTop: c(1, 0.75, 0.88), hullMid: c(0.92, 0.45, 0.68), hullBottom: c(0.5, 0.15, 0.35),
                 deck: c(1, 0.85, 0.93), neon: c(1, 0.45, 0.8), alien: c(0.6, 0.85, 1), glass: c(1, 0.85, 0.95), extra: .candy),
        UFOTheme(id: "ice", name: "Frost", price: 900,
                 hullTop: c(0.92, 0.97, 1), hullMid: c(0.6, 0.75, 0.88), hullBottom: c(0.25, 0.35, 0.5),
                 deck: c(0.95, 0.98, 1), neon: c(0.55, 0.85, 1), alien: c(0.7, 0.8, 0.95), glass: c(0.85, 0.95, 1), extra: .icicles),
        UFOTheme(id: "inferno", name: "Inferno", price: 1300,
                 hullTop: c(0.6, 0.25, 0.15), hullMid: c(0.3, 0.08, 0.05), hullBottom: c(0.1, 0.02, 0.02),
                 deck: c(0.7, 0.35, 0.2), neon: c(1, 0.5, 0.1), alien: c(0.95, 0.6, 0.4), glass: c(1, 0.75, 0.5), extra: .flames),
        UFOTheme(id: "midnight", name: "Midnight Fang", price: 1800,
                 hullTop: c(0.25, 0.25, 0.3), hullMid: c(0.08, 0.08, 0.1), hullBottom: c(0.01, 0.01, 0.02),
                 deck: c(0.3, 0.3, 0.36), neon: c(1, 0.15, 0.25), alien: c(0.5, 0.5, 0.55), glass: c(1, 0.6, 0.65), extra: .spikes),
        UFOTheme(id: "gold", name: "Golden King", price: 2600,
                 hullTop: c(1, 0.9, 0.55), hullMid: c(0.85, 0.62, 0.15), hullBottom: c(0.4, 0.25, 0.03),
                 deck: c(1, 0.92, 0.65), neon: c(1, 0.85, 0.3), alien: c(0.55, 0.85, 0.5), glass: c(1, 0.95, 0.75), extra: .gold),
        UFOTheme(id: "pumpkin", name: "Pumpkin King", price: 3500,
                 hullTop: c(1, 0.6, 0.15), hullMid: c(0.88, 0.38, 0.05), hullBottom: c(0.4, 0.14, 0.02),
                 deck: c(1, 0.7, 0.3), neon: c(1, 0.75, 0.1), alien: c(0.4, 0.75, 0.3), glass: c(1, 0.85, 0.5), extra: .pumpkin),
        UFOTheme(id: "rainbow", name: "Rainbow Rider", price: 5000,
                 hullTop: c(0.85, 0.85, 0.95), hullMid: c(0.45, 0.45, 0.6), hullBottom: c(0.12, 0.12, 0.2),
                 deck: c(0.9, 0.9, 1), neon: c(1, 0.3, 0.6), alien: c(0.95, 0.8, 0.4), glass: c(0.95, 0.9, 1), extra: .rainbow),
    ]

    static func find(_ id: String) -> UFOTheme { return all.first { $0.id == id } ?? all[0] }
}
