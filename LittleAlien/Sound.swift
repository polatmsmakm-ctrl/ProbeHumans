import AVFoundation
import QuartzCore

/// Plays the synthesized effects and the music loop.
final class Sound {
    static let shared = Sound()

    private var pools: [String: [AVAudioPlayer]] = [:]
    private var next: [String: Int] = [:]
    private var music: AVAudioPlayer?
    private var musicName = ""
    private var lastPlay: [String: TimeInterval] = [:]

    var sfxOn: Bool {
        get { UserDefaults.standard.object(forKey: "sfxOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sfxOn") }
    }
    var musicOn: Bool {
        get { UserDefaults.standard.object(forKey: "musicOn") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "musicOn")
            if newValue { let n = musicName; musicName = ""; playMusic(n) } else { music?.stop() }
        }
    }

    /// Old man voice lines made at build time (grumpa_1...); falls back to synthesized grumbles.
    private(set) var grumpaLines: [String] = []

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let names = ["sheep_0", "sheep_1", "sheep_2", "cow", "pig", "dog", "grumble_0", "grumble_1", "grumble_2",
                     "coin", "collect", "grab", "hit", "explode", "powerup", "levelup", "crash", "missile", "ufo_in", "click"]
        for n in names { load(n, copies: n == "coin" || n == "collect" ? 4 : 2) }
        for i in 1...8 {
            let n = "grumpa_\(i)"
            if load(n, copies: 1) { grumpaLines.append(n) }
        }
        if grumpaLines.isEmpty { grumpaLines = ["grumble_0", "grumble_1", "grumble_2"] }
    }

    @discardableResult
    private func load(_ name: String, copies: Int) -> Bool {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return false }
        var arr: [AVAudioPlayer] = []
        for _ in 0..<copies {
            if let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                arr.append(p)
            }
        }
        guard !arr.isEmpty else { return false }
        pools[name] = arr
        next[name] = 0
        return true
    }

    /// minGap stops the same sound from stacking up too many times per second.
    func play(_ name: String, volume: Float = 1, rate: Float = 1, minGap: TimeInterval = 0.04) {
        guard sfxOn, let pool = pools[name] else { return }
        let now = CACurrentMediaTime()
        if let last = lastPlay[name], now - last < minGap { return }
        lastPlay[name] = now
        let i = next[name] ?? 0
        next[name] = (i + 1) % pool.count
        let p = pool[i]
        p.volume = volume
        if rate != 1 { p.enableRate = true; p.rate = rate }
        p.currentTime = 0
        p.play()
    }

    func sheep() { play("sheep_\(Int.random(in: 0..<3))", volume: 0.8, rate: Float.random(in: 0.9...1.15), minGap: 0.25) }
    func grumpa() { if let n = grumpaLines.randomElement() { play(n, volume: 1, minGap: 0.8) } }

    func playMusic(_ name: String) {
        guard name != musicName else { return }
        musicName = name
        music?.stop()
        guard musicOn, let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.numberOfLoops = -1
        p.volume = 0.45
        p.play()
        music = p
    }
}
