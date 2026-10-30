import SwiftUI
import SpriteKit

@main
struct LittleAlienApp: App {
    var body: some Scene {
        WindowGroup {
            GameContainer()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

final class GameSKView: SKView {
    private var started = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !started, bounds.width > bounds.height, bounds.height > 0 else { return }
        started = true
        ignoresSiblingOrder = true
        let scene = GameScene(size: bounds.size)
        scene.scaleMode = .resizeFill
        presentScene(scene)
    }
}

struct GameContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> GameSKView {
        let v = GameSKView(frame: .zero)
        v.backgroundColor = .black
        // run at the phone's full refresh rate (120 Hz on ProMotion iPhones)
        v.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        return v
    }

    func updateUIView(_ uiView: GameSKView, context: Context) {}
}
