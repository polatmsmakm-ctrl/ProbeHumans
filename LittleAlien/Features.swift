import UIKit

// MARK: - Days

enum Day {
    static func key(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static var today: String { return key() }
    static var yesterday: String { return key(Date().addingTimeInterval(-86400)) }
}

// MARK: - Daily missions

enum MissionKind: String, Codable, CaseIterable {
    case sheep, cows, humans, coins, distance, noHit, powerups, smash, pigs
}

struct Mission: Codable {
    var kind: MissionKind
    var target: Int
    var progress: Int
    var reward: Int
    var claimed: Bool

    var done: Bool { return progress >= target }

    var title: String {
        switch kind {
        case .sheep: return "Abduct \(target) sheep"
        case .cows: return "Abduct \(target) cows"
        case .humans: return "Abduct \(target) humans"
        case .coins: return "Collect \(target) coins"
        case .distance: return "Fly \(target) M in one run"
        case .noHit: return "Fly \(target) M without a hit"
        case .powerups: return "Grab \(target) power-ups"
        case .smash: return "Smash \(target) things with Rampage"
        case .pigs: return "Abduct \(target) pigs"
        }
    }

    /// Single-run missions keep the best value, the rest add up over the day.
    var isBestOf: Bool { return kind == .distance || kind == .noHit }

    static func random(excluding: [MissionKind]) -> Mission {
        let pool = MissionKind.allCases.filter { !excluding.contains($0) }
        let k = pool.randomElement() ?? .sheep
        let opts: [(Int, Int)]
        switch k {
        case .sheep: opts = [(30, 60), (60, 110), (100, 180)]
        case .cows: opts = [(6, 70), (12, 130)]
        case .humans: opts = [(15, 70), (30, 140)]
        case .coins: opts = [(100, 60), (200, 120), (350, 200)]
        case .distance: opts = [(1000, 60), (2000, 120), (3500, 220)]
        case .noHit: opts = [(500, 80), (1000, 160)]
        case .powerups: opts = [(3, 70), (6, 140)]
        case .smash: opts = [(5, 90), (12, 180)]
        case .pigs: opts = [(10, 60), (20, 120)]
        }
        let o = opts.randomElement() ?? (10, 50)
        return Mission(kind: k, target: o.0, progress: 0, reward: o.1, claimed: false)
    }
}

extension Store {
    /// Three fresh missions every day.
    func refreshMissionsIfNeeded() {
        if d.missionsDay != Day.today || (d.missions ?? []).isEmpty {
            var m: [Mission] = []
            for _ in 0..<3 { m.append(Mission.random(excluding: m.map { $0.kind })) }
            d.missions = m
            d.missionsDay = Day.today
            save()
        }
    }

    /// Returns titles of missions that just got completed.
    @discardableResult
    func mission(_ kind: MissionKind, add: Int = 0, best: Int? = nil) -> [String] {
        refreshMissionsIfNeeded()
        guard var m = d.missions else { return [] }
        var finished: [String] = []
        for i in m.indices where m[i].kind == kind && !m[i].done {
            if let b = best { m[i].progress = max(m[i].progress, b) } else { m[i].progress += add }
            if m[i].done { finished.append(m[i].title) }
        }
        d.missions = m
        return finished
    }

    var unclaimedMissions: Int { return (d.missions ?? []).filter { $0.done && !$0.claimed }.count }

    // MARK: Daily reward

    static let dailyRewards = [50, 75, 100, 150, 200, 300, 500]

    var dailyRewardReady: Bool { return d.rewardDay != Day.today }

    /// Claims today's chest and returns (coins, streak day).
    func claimDailyReward() -> (Int, Int) {
        let streak = d.rewardDay == Day.yesterday ? (d.rewardStreak ?? 0) + 1 : 1
        d.rewardStreak = streak
        d.rewardDay = Day.today
        let coins = Store.dailyRewards[min(streak, 7) - 1]
        d.coins += coins
        d.coinsEarnedTotal = (d.coinsEarnedTotal ?? 0) + coins
        save()
        return (coins, streak)
    }

    // MARK: Collection

    func countKey(_ k: Kind, _ v: Int, rare: Bool = false) -> String { return rare ? "rare" : "\(k.rawValue)_\(v)" }

    func addCaught(_ k: Kind, _ v: Int, rare: Bool) {
        var c = d.kindCounts ?? [:]
        c[countKey(k, v, rare: rare), default: 0] += 1
        d.kindCounts = c
    }

    func caught(_ k: Kind, _ v: Int, rare: Bool = false) -> Int { return d.kindCounts?[countKey(k, v, rare: rare)] ?? 0 }

    func caught(kind k: Kind) -> Int {
        return (d.kindCounts ?? [:]).filter { $0.key.hasPrefix("\(k.rawValue)_") }.reduce(0) { $0 + $1.value }
    }

    var humansCaught: Int {
        return [Kind.grumpa, .farmer, .fireman, .soldier, .reporter, .hunter, .bedouin, .citizen].reduce(0) { $0 + caught(kind: $1) }
    }
}

// MARK: - Collection book entries

struct CollectionEntry {
    let name: String
    let kind: Kind
    let variant: Int
    let rare: Bool
    let special: Bool   // gold frame

    static let all: [CollectionEntry] = [
        CollectionEntry(name: "Sheep", kind: .sheep, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Black Sheep", kind: .sheep, variant: 1, rare: false, special: false),
        CollectionEntry(name: "Golden Sheep", kind: .sheep, variant: 2, rare: false, special: false),
        CollectionEntry(name: "Wild Gold Sheep", kind: .sheep, variant: 2, rare: true, special: true),
        CollectionEntry(name: "Milky Cow", kind: .cow, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Choco Cow", kind: .cow, variant: 1, rare: false, special: false),
        CollectionEntry(name: "Space Cow", kind: .cow, variant: 2, rare: false, special: false),
        CollectionEntry(name: "Nuclear Cow", kind: .cow, variant: 3, rare: false, special: true),
        CollectionEntry(name: "Piggy", kind: .pig, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Muddy Pig", kind: .pig, variant: 1, rare: false, special: false),
        CollectionEntry(name: "Sheep Dog", kind: .dog, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Grumpa", kind: .grumpa, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Farm Boy", kind: .farmer, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Hunter", kind: .hunter, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Fireman", kind: .fireman, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Reporter", kind: .reporter, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Soldier", kind: .soldier, variant: 0, rare: false, special: false),
        CollectionEntry(name: "City Guy", kind: .citizen, variant: 0, rare: false, special: false),
        CollectionEntry(name: "Camel", kind: .camel, variant: 0, rare: false, special: true),
        CollectionEntry(name: "Bedouin", kind: .bedouin, variant: 0, rare: false, special: false),
    ]
}

// MARK: - Achievements and titles

struct Achievement {
    let id: String
    let title: String
    let detail: String
    let reward: Int
    let check: (Store) -> Bool

    static let all: [Achievement] = [
        Achievement(id: "sheep100", title: "Sheep Snatcher", detail: "Abduct 100 sheep", reward: 150) { $0.caught(kind: .sheep) >= 100 },
        Achievement(id: "sheep1000", title: "Shepherd", detail: "Abduct 1,000 sheep", reward: 600) { $0.caught(kind: .sheep) >= 1000 },
        Achievement(id: "cow100", title: "Cow Collector", detail: "Abduct 100 cows", reward: 300) { $0.caught(kind: .cow) >= 100 },
        Achievement(id: "humans100", title: "Farmer's Nightmare", detail: "Abduct 100 humans", reward: 300) { $0.humansCaught >= 100 },
        Achievement(id: "tanks10", title: "Tank Buster", detail: "Smash 10 tanks", reward: 400) { $0.d.tanksDestroyed >= 10 },
        Achievement(id: "run2000", title: "Long Hauler", detail: "Fly 2,000 M in one run", reward: 200) { $0.d.bestDistance >= 2000 },
        Achievement(id: "run5000", title: "City Visitor", detail: "Reach the city (5,000 M)", reward: 500) { $0.d.bestDistance >= 5000 },
        Achievement(id: "run10000", title: "Desert Wanderer", detail: "Reach the desert (10,000 M)", reward: 1000) { $0.d.bestDistance >= 10000 },
        Achievement(id: "rich", title: "Rich Alien", detail: "Earn 10,000 coins in total", reward: 500) { ($0.d.coinsEarnedTotal ?? 0) >= 10000 },
        Achievement(id: "rare", title: "Golden Touch", detail: "Catch a wild golden sheep", reward: 250) { ($0.d.raresCaught ?? 0) >= 1 },
        Achievement(id: "nuke5", title: "Nuke Master", detail: "Set off 5 nuclear cows", reward: 400) { ($0.d.nukes ?? 0) >= 5 },
        Achievement(id: "boss3", title: "Survivor", detail: "Beat 3 bosses", reward: 600) { ($0.d.bossesBeaten ?? 0) >= 3 },
        Achievement(id: "streak7", title: "Daily Devotee", detail: "Claim the chest 7 days in a row", reward: 500) { ($0.d.rewardStreak ?? 0) >= 7 },
        Achievement(id: "collector", title: "Collector", detail: "Catch every creature in the book", reward: 1500) { s in
            CollectionEntry.all.allSatisfy { s.caught($0.kind, $0.variant, rare: $0.rare) > 0 }
        },
    ]
}

extension Store {
    /// Unlocks any newly reached achievements, pays their reward and returns them.
    func checkAchievements() -> [Achievement] {
        var done = Set(d.achievements ?? [])
        var new: [Achievement] = []
        for a in Achievement.all where !done.contains(a.id) && a.check(self) {
            done.insert(a.id)
            d.coins += a.reward
            new.append(a)
        }
        if !new.isEmpty {
            d.achievements = Array(done)
            save()
        }
        return new
    }

    /// The player's title: the last achievement in the list they have earned.
    var title: String {
        let done = Set(d.achievements ?? [])
        return Achievement.all.last { done.contains($0.id) }?.title ?? "Rookie Alien"
    }
}

// MARK: - Friends leaderboard (share codes, no server needed)

struct FriendScore: Codable {
    var name: String
    var score: Int
    var distance: Int
}

enum ScoreCode {
    private static func sum(_ s: String) -> Int {
        var h = 5381
        for u in s.unicodeScalars { h = ((h << 5) &+ h &+ Int(u.value)) & 0x7fffffff }
        return h % 9973
    }

    static func make(name: String, score: Int, distance: Int) -> String {
        let body = "\(name)|\(score)|\(distance)"
        let raw = "\(body)|\(sum(body))"
        let b64 = Data(raw.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "ALIEN-" + b64
    }

    static func read(_ code: String) -> FriendScore? {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = t.range(of: "ALIEN-") else { return nil }
        var b = String(t[r.upperBound...]).components(separatedBy: .whitespacesAndNewlines).first ?? ""
        b = b.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let data = Data(base64Encoded: b), let raw = String(data: data, encoding: .utf8) else { return nil }
        let p = raw.components(separatedBy: "|")
        guard p.count == 4, let sc = Int(p[1]), let di = Int(p[2]), let ck = Int(p[3]) else { return nil }
        guard ck == sum("\(p[0])|\(p[1])|\(p[2])") else { return nil }
        return FriendScore(name: p[0], score: sc, distance: di)
    }
}

// MARK: - Biomes (change with distance) and world themes (bought in the store)

enum Biome: Int {
    case farm = 0, city, desert

    static func at(_ distance: Int) -> Biome {
        let cycle = distance % 15000
        if cycle >= 10000 { return .desert }
        if cycle >= 5000 { return .city }
        return .farm
    }

    /// The map the player picked in MAPS (nil = AUTO: farm → city → desert as you fly).
    static var picked: Biome? {
        get {
            let v = UserDefaults.standard.object(forKey: "mapPick") as? Int ?? -1
            return Biome(rawValue: v)
        }
        set { UserDefaults.standard.set(newValue?.rawValue ?? -1, forKey: "mapPick") }
    }

    var blurb: String {
        switch self {
        case .farm: return "Barns, cows, sheep and the grumpy farmer"
        case .city: return "Streets, cars, police and lots of people"
        case .desert: return "Dunes, camels, tents and jeeps"
        }
    }

    var name: String {
        switch self {
        case .farm: return "THE FARM"
        case .city: return "THE CITY"
        case .desert: return "THE DESERT"
        }
    }
}

struct WorldTheme {
    enum Look { case normal, halloween, winter }
    let id: String
    let name: String
    let price: Int
    let look: Look
    let blurb: String

    static let all: [WorldTheme] = [
        WorldTheme(id: "normal", name: "Night Farm", price: 0, look: .normal, blurb: "The classic night"),
        WorldTheme(id: "halloween", name: "Halloween", price: 1500, look: .halloween, blurb: "Pumpkins, bats and an orange moon"),
        WorldTheme(id: "winter", name: "Winter", price: 1200, look: .winter, blurb: "Snowy fields and falling snow"),
    ]

    static func find(_ id: String) -> WorldTheme { return all.first { $0.id == id } ?? all[0] }
}

extension Store {
    var currentWorld: WorldTheme { return WorldTheme.find(d.world ?? "normal") }
    func ownsWorld(_ id: String) -> Bool { return id == "normal" || (d.worldsOwned ?? []).contains(id) }
}
