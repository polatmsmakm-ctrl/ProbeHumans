import Foundation
import SpriteKit
import UIKit

// MARK: - Online race
// Everyone plays their own run at the same time. A small server (see /server) relays the live
// score + distance of every player in the room and sends the final ranking at the end.

struct RacePlayer {
    var id: String
    var name: String
    var score: Int
    var distance: Int
    var alive: Bool
    var done: Bool
}

enum RaceEvent {
    case joined(id: String, host: Bool)
    case lobby(players: [RacePlayer], hostId: String)
    case go(delay: Double)
    case board([RacePlayer])
    case results([RacePlayer])
    case error(String)
    case disconnected(String)
}

/// Thin WebSocket client (URLSession, no third-party code). Events are always delivered on the main thread.
final class RaceClient {
    static let shared = RaceClient()

    var onEvent: ((RaceEvent) -> Void)?
    private(set) var connected = false
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var generation = 0

    func connect(server: String, room: String, name: String) {
        disconnect()
        generation += 1
        let gen = generation
        var address = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.hasPrefix("ws://") && !address.hasPrefix("wss://") { address = "ws://" + address }
        guard let url = URL(string: address) else {
            onEvent?(.error("Bad server address"))
            return
        }
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 8
        let s = URLSession(configuration: cfg)
        session = s
        let t = s.webSocketTask(with: url)
        task = t
        t.resume()
        send(["t": "join", "room": room, "name": name])
        listen(t, gen)
        // give up if the server never answers
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self = self, gen == self.generation, !self.connected else { return }
            self.disconnect()
            self.onEvent?(.error("Could not reach the server"))
        }
    }

    func disconnect() {
        generation += 1
        connected = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    func send(_ obj: [String: Any]) {
        guard let task = task,
              let data = try? JSONSerialization.data(withJSONObject: obj),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { _ in }
    }

    private func listen(_ t: URLSessionWebSocketTask, _ gen: Int) {
        t.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, gen == self.generation else { return }
                switch result {
                case .failure(let err):
                    self.disconnect()
                    self.onEvent?(.disconnected(err.localizedDescription))
                case .success(let message):
                    switch message {
                    case .string(let text): self.handle(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) { self.handle(text) }
                    @unknown default: break
                    }
                    self.listen(t, gen)
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = obj["t"] as? String else { return }
        switch type {
        case "joined":
            connected = true
            onEvent?(.joined(id: obj["id"] as? String ?? "", host: obj["host"] as? Bool ?? false))
        case "lobby":
            onEvent?(.lobby(players: RaceClient.parse(obj["players"]), hostId: obj["hostId"] as? String ?? ""))
        case "go":
            onEvent?(.go(delay: obj["delay"] as? Double ?? 3))
        case "board":
            onEvent?(.board(RaceClient.parse(obj["players"])))
        case "results":
            onEvent?(.results(RaceClient.parse(obj["players"])))
        case "error":
            onEvent?(.error(obj["msg"] as? String ?? "Error"))
        default:
            break
        }
    }

    private static func parse(_ any: Any?) -> [RacePlayer] {
        guard let arr = any as? [[String: Any]] else { return [] }
        return arr.map { d in
            RacePlayer(id: d["id"] as? String ?? "",
                       name: d["name"] as? String ?? "?",
                       score: d["score"] as? Int ?? 0,
                       distance: d["distance"] as? Int ?? 0,
                       alive: d["alive"] as? Bool ?? true,
                       done: d["done"] as? Bool ?? false)
        }
    }
}

enum RacePage { case none, join, lobby }

/// Everything the scene needs to remember about the current online race.
final class RaceState {
    var page: RacePage = .none
    var inRoom = false
    var isHost = false
    var hostId = ""
    var myId = ""
    var active = false            // true from "go" until the results are in
    var players: [RacePlayer] = []
    var board: [RacePlayer] = []
    var results: [RacePlayer]? = nil
    var sendTimer: CGFloat = 0
    var countdownToken = 0
    var errorShown = false
    var panel = SKNode()
}

extension GameScene {
    // MARK: - Small helpers

    func raceToast(_ text: String, color: UIColor) {
        let l = UIK.label(text, size: 15, color: color, font: UIK.heavyItalic, y: -H * 0.36)
        l.zPosition = 300
        ui.addChild(l)
        l.run(.sequence([.wait(forDuration: 2.4), .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    func askText(title: String, message: String, text: String?, placeholder: String, onSave: @escaping (String) -> Void) {
        guard var vc = view?.window?.rootViewController else { return }
        while let p = vc.presentedViewController { vc = p }
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addTextField { tf in
            tf.text = text
            tf.placeholder = placeholder
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Save", style: .default) { [weak a] _ in
            let raw = a?.textFields?.first?.text ?? ""
            onSave(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        })
        vc.present(a, animated: true)
    }

    // MARK: - Join screen

    func showRaceJoin() {
        screen = .settings
        race.page = .join
        newOverlay(dim: 0.3)
        let pw = min(W - 40, 560)
        overlay.addChild(UIK.panel(pw, H - 40, y: -6))
        overlay.addChild(UIK.label("ONLINE RACE", size: 24, color: UIK.cyan, y: H / 2 - 44))
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in
            self?.race.page = .none
            self?.showMenu()
        }
        let server = store.d.raceServer ?? ""
        let room = store.d.raceRoom ?? "ALIEN"
        let me = store.d.playerName ?? "Player"
        let bw = min(pw - 60, 380)
        let y0 = H * 0.2
        let purple = Art.rgb(0.3, 0.25, 0.55)

        addButton("SERVER: " + (server.isEmpty ? "tap to set" : server), x: 0, y: y0, w: bw, h: 36, color: purple, fontSize: 14) { [weak self] in
            guard let self = self else { return }
            self.askText(title: "Server address", message: "Example: 100.64.0.5:8787", text: server, placeholder: "100.x.y.z:8787") { [weak self] value in
                self?.store.d.raceServer = String(value.prefix(80))
                self?.store.save()
                self?.showRaceJoin()
            }
        }
        addButton("ROOM: \(room)", x: 0, y: y0 - 46, w: bw, h: 36, color: purple, fontSize: 14) { [weak self] in
            guard let self = self else { return }
            self.askText(title: "Room name", message: "Everyone in the race types the same name", text: room, placeholder: "ALIEN") { [weak self] value in
                let clean = String(value.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(10))
                self?.store.d.raceRoom = clean.isEmpty ? "ALIEN" : clean
                self?.store.save()
                self?.showRaceJoin()
            }
        }
        addButton("NAME: \(me)", x: 0, y: y0 - 92, w: bw, h: 36, color: purple, fontSize: 14) { [weak self] in
            guard let self = self else { return }
            self.askText(title: "Your name", message: "Shown to the other players", text: me, placeholder: "Name") { [weak self] value in
                let clean = String(value.replacingOccurrences(of: "|", with: "").prefix(14))
                if !clean.isEmpty { self?.store.d.playerName = clean; self?.store.save() }
                self?.showRaceJoin()
            }
        }
        addButton("JOIN ROOM", x: 0, y: y0 - 150, w: 220, h: 46, color: UIK.green, fontSize: 24, enabled: !server.isEmpty) { [weak self] in
            self?.raceConnect()
        }
        overlay.addChild(UIK.label("Everyone plays their own run at the same time. Highest score wins.", size: 12,
                                   color: UIColor(white: 1, alpha: 0.7), y: -H * 0.38, shadow: nil))
    }

    func raceConnect() {
        let server = store.d.raceServer ?? ""
        if server.isEmpty { return }
        race.errorShown = false
        raceToast("Connecting...", color: UIK.yellow)
        RaceClient.shared.onEvent = { [weak self] e in self?.raceEvent(e) }
        RaceClient.shared.connect(server: server, room: store.d.raceRoom ?? "ALIEN", name: store.d.playerName ?? "Player")
    }

    // MARK: - Events from the server

    func raceEvent(_ e: RaceEvent) {
        switch e {
        case .joined(let id, let host):
            race.myId = id
            race.isHost = host
            race.inRoom = true
            race.results = nil
            if race.page == .join { showRaceLobby() }
        case .lobby(let players, let hostId):
            race.players = players
            race.hostId = hostId
            race.isHost = (hostId == race.myId)
            if race.page == .lobby && !race.active { showRaceLobby() }
        case .go(let delay):
            raceBegin(delay: delay)
        case .board(let list):
            race.board = list
            if screen == .playing { updateRaceHUD() }
            if screen == .over && race.active && race.results == nil { showRaceOver() }
        case .results(let list):
            race.results = list
            race.active = false
            if screen == .over { showRaceOver() }
        case .error(let msg):
            race.errorShown = true
            raceToast(msg, color: Art.rgb(1, 0.5, 0.5))
        case .disconnected(let why):
            let wasIn = race.inRoom
            race.inRoom = false
            race.active = false
            race.panel.isHidden = true
            if wasIn {
                raceToast("Disconnected from the race", color: Art.rgb(1, 0.5, 0.5))
                removeAction(forKey: "raceCountdown")
                race.countdownToken += 1
                switch screen {
                case .over: showRaceOver()
                case .settings: showRaceJoin()      // lobby or 3-2-1 countdown
                default: break                      // mid-run: just keep playing solo
                }
            } else if race.errorShown {
                race.errorShown = false
            } else {
                raceToast("Could not connect: \(why)", color: Art.rgb(1, 0.5, 0.5))
            }
        }
    }

    // MARK: - Lobby

    func showRaceLobby() {
        screen = .settings
        race.page = .lobby
        race.active = false
        newOverlay(dim: 0.3)
        let pw = min(W - 40, 560)
        overlay.addChild(UIK.panel(pw, H - 40, y: -6))
        overlay.addChild(UIK.label("ROOM \(store.d.raceRoom ?? "")", size: 24, color: UIK.cyan, y: H / 2 - 44))
        addButton("LEAVE", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in
            self?.raceLeave()
            self?.showMenu()
        }
        let step = min(28, (H - 190) / 8)
        for (i, p) in race.players.prefix(8).enumerated() {
            let y = H / 2 - 92 - CGFloat(i) * step
            let isMe = p.id == race.myId
            let col: UIColor = isMe ? UIK.yellow : .white
            overlay.addChild(UIK.label("\(i + 1).", size: 16, color: col, x: -pw / 2 + 50, y: y, align: .left, shadow: nil))
            overlay.addChild(UIK.label(p.name + (isMe ? " (you)" : ""), size: 16, color: col, x: -pw / 2 + 84, y: y, align: .left, shadow: nil))
            if p.id == race.hostId {
                overlay.addChild(UIK.label("HOST", size: 13, color: UIK.cyan, x: pw / 2 - 50, y: y, align: .right, shadow: nil))
            }
        }
        if race.isHost {
            addButton("START RACE", x: 0, y: -H / 2 + 52, w: 230, h: 46, color: UIK.green, fontSize: 24, enabled: race.players.count >= 2) {
                RaceClient.shared.send(["t": "start"])
            }
            if race.players.count < 2 {
                overlay.addChild(UIK.label("Waiting for friends to join this room...", size: 13,
                                           color: UIColor(white: 1, alpha: 0.7), y: -H / 2 + 96, shadow: nil))
            }
        } else {
            overlay.addChild(UIK.label("Waiting for the host to start the race...", size: 15,
                                       color: UIColor(white: 1, alpha: 0.8), y: -H / 2 + 52, shadow: nil))
        }
    }

    func raceLeave() {
        removeAction(forKey: "raceCountdown")
        race.countdownToken += 1
        RaceClient.shared.disconnect()
        race.inRoom = false
        race.active = false
        race.page = .none
        race.results = nil
        race.board = []
        race.players = []
        race.panel.removeFromParent()
    }

    // MARK: - Race start (3-2-1 then the normal game starts)

    func raceBegin(delay: Double) {
        if screen == .playing || screen == .paused { return }
        race.active = true
        race.results = nil
        race.board = []
        race.page = .none
        screen = .settings
        newOverlay(dim: 0.35)
        overlay.addChild(UIK.label("GET READY", size: 34, color: UIK.orange, y: H * 0.14, shadow: UIK.orangeDark))
        let total = max(1, Int(delay.rounded()))
        let n = UIK.label("\(total)", size: 90, color: .white, font: UIK.heavyItalic, y: -H * 0.02, shadow: UIK.orangeDark)
        overlay.addChild(n)
        sound.play("click", volume: 0.6)
        race.countdownToken += 1
        let token = race.countdownToken
        var steps: [SKAction] = []
        for i in stride(from: total - 1, through: 0, by: -1) {
            steps.append(.wait(forDuration: 1))
            steps.append(.run { [weak self, weak n] in
                guard let self = self, token == self.race.countdownToken, self.race.active else { return }
                if i > 0 {
                    if let n = n { self.setText(n, "\(i)") }
                    self.sound.play("click", volume: 0.6)
                } else {
                    self.startGame()
                }
            })
        }
        run(.sequence(steps), withKey: "raceCountdown")
    }

    // MARK: - Live standings while playing

    /// Called from startGame().
    func prepareRaceHUD() {
        race.panel.removeFromParent()
        race.panel = SKNode()
        race.panel.zPosition = 5
        race.sendTimer = 0
        hud.addChild(race.panel)
        race.panel.isHidden = !race.active
        if race.active { updateRaceHUD() }
    }

    func updateRaceHUD() {
        guard race.active else { return }
        race.panel.removeAllChildren()
        let rows = race.board.sorted { $0.score > $1.score }
        if rows.isEmpty { return }
        let hs = min(1.25, max(0.85, H / 390))
        let x = W / 2 - max(18, sideInset * 0.5) - 8
        let top = H / 2
        var shown = Array(rows.prefix(5))
        if let mine = rows.firstIndex(where: { $0.id == race.myId }), mine >= 5 {
            shown.append(rows[mine])
        }
        for (slot, p) in shown.enumerated() {
            let rank = (rows.firstIndex(where: { $0.id == p.id }) ?? slot) + 1
            let isMe = p.id == race.myId
            let mark = p.alive ? "" : "  X"
            let col: UIColor = isMe ? UIK.yellow : UIColor(white: 1, alpha: p.alive ? 0.92 : 0.5)
            let text = "\(rank). \(p.name)  \(UIK.coins(p.score))" + mark
            race.panel.addChild(UIK.label(text, size: 13 * hs, color: col, font: UIK.heavyItalic,
                                          x: x, y: top - (88 + CGFloat(slot) * 19) * hs, align: .right))
        }
    }

    /// Called every frame from step() while a race run is going.
    func raceTick(_ dt: CGFloat) {
        race.sendTimer += dt
        if race.sendTimer < 0.25 { return }
        race.sendTimer = 0
        RaceClient.shared.send(["t": "state", "score": score, "distance": distance, "alive": status != .dead])
    }

    // MARK: - End of my run

    /// Called from finishRun() instead of the normal game-over panel.
    func raceFinished() {
        RaceClient.shared.send(["t": "done", "score": score, "distance": distance])
        race.panel.isHidden = true
        showRaceOver()
    }

    func showRaceOver() {
        screen = .over
        newOverlay(dim: 0.25)
        coinBadge()
        let pw = min(W - 80, 500), ph = H * 0.86
        overlay.addChild(UIK.panel(pw, ph))
        let finished = race.results != nil
        let title = finished ? "RACE RESULTS" : (race.inRoom ? "WAITING FOR THE OTHERS..." : "CONNECTION LOST")
        overlay.addChild(UIK.label(title, size: 24, color: UIK.cyan, y: ph / 2 - 32))
        overlay.addChild(UIK.label("Your run: \(UIK.coins(score)) PTS  -  \(UIK.coins(distance)) M", size: 14,
                                   color: UIColor(white: 1, alpha: 0.85), y: ph / 2 - 58, shadow: nil))
        let rows = (race.results ?? race.board).sorted { $0.score > $1.score }
        let step = min(26, (ph - 170) / 8)
        let medals: [UIColor] = [UIK.yellow, Art.rgb(0.8, 0.85, 0.95), Art.rgb(0.85, 0.55, 0.3)]
        for (i, p) in rows.prefix(8).enumerated() {
            let y = ph / 2 - 92 - CGFloat(i) * step
            let isMe = p.id == race.myId
            var col: UIColor = i < 3 && finished ? medals[i] : .white
            if isMe { col = UIK.yellow }
            let name = p.name + (isMe ? " (you)" : "") + (finished || p.done ? "" : "  ...")
            overlay.addChild(UIK.label("\(i + 1).", size: 16, color: col, x: -pw / 2 + 40, y: y, align: .left, shadow: nil))
            overlay.addChild(UIK.label(name, size: 16, color: col, x: -pw / 2 + 72, y: y, align: .left, shadow: nil))
            overlay.addChild(UIK.label("\(UIK.coins(p.score)) PTS", size: 15, color: col, x: pw / 2 - 130, y: y, align: .right, shadow: nil))
            overlay.addChild(UIK.label("\(UIK.coins(p.distance)) M", size: 13, color: UIColor(white: 1, alpha: 0.7), x: pw / 2 - 40, y: y, align: .right, shadow: nil))
        }
        if finished && race.inRoom {
            addButton("BACK TO LOBBY", x: -110, y: -ph / 2 + 34, w: 210, h: 40, fontSize: 24, plain: true) { [weak self] in
                self?.showRaceLobby()
            }
            addButton("MAIN MENU", x: 120, y: -ph / 2 + 34, w: 160, h: 40, fontSize: 24, plain: true) { [weak self] in
                self?.raceLeave()
                self?.awardsThenMenu()
            }
        } else {
            addButton("MAIN MENU", x: 0, y: -ph / 2 + 34, w: 200, h: 40, fontSize: 24, plain: true) { [weak self] in
                self?.raceLeave()
                self?.awardsThenMenu()
            }
        }
    }
}
