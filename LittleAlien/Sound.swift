import AVFoundation
import QuartzCore

/// Plays sound effects and music.
/// Files named u_* are the owner's own sounds (laser, animals, old man, theme);
/// when one is missing the synthesized fallback is used instead.
final class Sound {
    static let shared = Sound()

    private var pools: [String: [AVAudioPlayer]] = [:]
    private var next: [String: Int] = [:]
    private var music: AVAudioPlayer?
    private var musicName = ""
    private var lastPlay: [String: TimeInterval] = [:]
    /// Starting players can block for a moment, so it happens off the game's main thread.
    private let audioQ = DispatchQueue(label: "sound.play", qos: .userInitiated)

    var sfxOn: Bool {
        get { UserDefaults.standard.object(forKey: "sfxOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sfxOn") }
    }
    /// 0...1, set with the bars in Options.
    var sfxVolume: Float {
        get { UserDefaults.standard.object(forKey: "sfxVolume") as? Float ?? 1 }
        set { UserDefaults.standard.set(max(0, min(1, newValue)), forKey: "sfxVolume") }
    }
    var musicVolume: Float {
        get { UserDefaults.standard.object(forKey: "musicVolume") as? Float ?? 1 }
        set {
            UserDefaults.standard.set(max(0, min(1, newValue)), forKey: "musicVolume")
            let v = musicBase * musicVolume
            let p = music
            audioQ.async { p?.volume = v }
        }
    }
    private var musicBase: Float = 0.5

    var musicOn: Bool {
        get { UserDefaults.standard.object(forKey: "musicOn") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "musicOn")
            if newValue { let n = musicName; musicName = ""; playMusic(n) } else { music?.stop() }
        }
    }

    /// Old man voice lines made at build time (grumpa_1...); falls back to synthesized grumbles.
    private(set) var grumpaLines: [String] = []

    /// Variants of each animal / human sound (owner's sounds first, synth as fallback).
    private var sheepSounds: [String] = []
    private var pigSounds: [String] = []
    private var cowSounds: [String] = []
    private var oldManSounds: [String] = []

    // grabs that happen close together are counted and played as a group
    private var pending: [String: Int] = [:]
    private var flushScheduled = false

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let names = ["sheep_0", "sheep_1", "sheep_2", "cow", "pig", "dog", "grumble_0", "grumble_1", "grumble_2",
                     "coin", "collect", "grab", "hit", "explode", "powerup", "levelup", "crash", "missile", "ufo_in", "click",
                     "thunder", "shot", "plane", "heli", "nuke", "chest", "achieve", "siren", "mega", "warn"]
        for n in names { load(n, copies: n == "coin" || n == "collect" ? 4 : 2) }
        for i in 1...8 {
            let n = "grumpa_\(i)"
            if load(n, copies: 1) { grumpaLines.append(n) }
        }
        if grumpaLines.isEmpty { grumpaLines = ["grumble_0", "grumble_1", "grumble_2"] }

        load("u_laser_open", copies: 1)
        load("u_laser_grab", copies: 4)
        sheepSounds = loadSet("u_sheep", copies: 4, fallback: ["sheep_0", "sheep_1", "sheep_2"])
        pigSounds = loadSet("u_pig", copies: 4, fallback: ["pig"])
        cowSounds = loadSet("u_cow", copies: 4, fallback: ["cow"])
        oldManSounds = loadSet("u_oldman", copies: 4, fallback: grumpaLines)
    }

    /// Loads u_name, u_name_0, u_name_1 ... and returns the names that exist.
    private func loadSet(_ base: String, copies: Int, fallback: [String]) -> [String] {
        var found: [String] = []
        if load(base, copies: copies) { found.append(base) }
        for i in 0..<8 where load("\(base)_\(i)", copies: copies) { found.append("\(base)_\(i)") }
        return found.isEmpty ? fallback : found
    }

    @discardableResult
    private func load(_ name: String, copies: Int) -> Bool {
        let url = Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
        guard let u = url else { return false }
        var arr: [AVAudioPlayer] = []
        for _ in 0..<copies {
            if let p = try? AVAudioPlayer(contentsOf: u) {
                p.enableRate = true
                p.prepareToPlay()
                arr.append(p)
            }
        }
        guard !arr.isEmpty else { return false }
        pools[name] = arr
        next[name] = 0
        return true
    }

    func has(_ name: String) -> Bool { return pools[name] != nil }

    /// minGap stops the same sound from stacking up too many times per second.
    func play(_ name: String, volume: Float = 1, rate: Float = 1, minGap: TimeInterval = 0.04) {
        guard sfxOn, sfxVolume > 0.001, let pool = pools[name] else { return }
        let volume = volume * sfxVolume
        let now = CACurrentMediaTime()
        if let last = lastPlay[name], now - last < minGap { return }
        lastPlay[name] = now
        let i = next[name] ?? 0
        next[name] = (i + 1) % pool.count
        let p = pool[i]
        audioQ.async {
            p.volume = volume
            p.rate = rate
            p.currentTime = 0
            p.play()
        }
    }

    // MARK: Beam

    /// Beam switching on (start of a run / after a head start).
    func laserOpen() {
        if has("u_laser_open") { play("u_laser_open", volume: 0.9) } else { play("ufo_in") }
    }

    /// Something got caught in the beam.
    func laserGrab() {
        if has("u_laser_grab") { play("u_laser_grab", volume: 0.55, rate: Float.random(in: 0.95...1.08), minGap: 0.12) } else { play("grab", volume: 0.5) }
    }

    // MARK: Animals & people, grouped by how many were grabbed

    enum Voice: String { case sheep, pig, cow, oldMan, dog }

    /// Queue one grabbed creature. Grabs within ~0.12s are played together:
    /// one creature = one sound, a whole flock = several overlapping, varied sounds.
    func creature(_ v: Voice) {
        pending[v.rawValue, default: 0] += 1
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.flush() }
    }

    private func flush() {
        flushScheduled = false
        let groups = pending
        pending = [:]
        guard sfxOn else { return }
        for (key, count) in groups {
            guard let v = Voice(rawValue: key) else { continue }
            let set: [String]
            switch v {
            case .sheep: set = sheepSounds
            case .pig: set = pigSounds
            case .cow: set = cowSounds
            case .oldMan: set = oldManSounds
            case .dog: set = ["dog"]
            }
            let voices = min(count, 4)
            var order = set.shuffled()
            for k in 0..<voices {
                if order.isEmpty { order = set.shuffled() }
                let name = order.removeFirst()
                let delay = k == 0 ? 0 : Double(k) * Double.random(in: 0.09...0.18)
                // each extra animal sounds a little different: pitch and loudness vary
                let rate: Float = voices == 1 ? Float.random(in: 0.96...1.04) : Float.random(in: 0.82...1.22)
                let vol: Float = max(0.45, 1 - Float(k) * 0.15)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.play(name, volume: vol, rate: rate, minGap: 0)
                }
            }
        }
    }

    func sheep() { creature(.sheep) }
    func grumpa() {
        if oldManSounds.first?.hasPrefix("u_") == true {
            play(oldManSounds.randomElement() ?? "", volume: 0.9, rate: Float.random(in: 0.95...1.05), minGap: 1.2)
        } else if let n = grumpaLines.randomElement() {
            play(n, volume: 1, minGap: 0.8)
        }
    }

    // MARK: Music

    func playMusic(_ name: String) {
        // the owner's theme (u_theme) replaces the gameplay loop when present
        let file = (name == "music" && (Bundle.main.url(forResource: "u_theme", withExtension: "m4a") != nil
                                        || Bundle.main.url(forResource: "u_theme", withExtension: "mp3") != nil)) ? "u_theme" : name
        guard file != musicName else { return }
        musicName = file
        music?.stop()
        guard musicOn else { return }
        let url = Bundle.main.url(forResource: file, withExtension: "wav")
            ?? Bundle.main.url(forResource: file, withExtension: "m4a")
            ?? Bundle.main.url(forResource: file, withExtension: "mp3")
        guard let u = url, let p = try? AVAudioPlayer(contentsOf: u) else { return }
        p.numberOfLoops = -1
        musicBase = file == "u_theme" ? 0.6 : 0.45
        p.volume = musicBase * musicVolume
        p.play()
        music = p
    }
}
