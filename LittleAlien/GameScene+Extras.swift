import SpriteKit
import UIKit

/// Things flying across the sky (crop duster).
final class Flyer: SKNode {
    var vx: CGFloat = 0
    var hitDone = false
}

/// Everything added in the "big update": combos, rare animals, weather, new enemies,
/// new powers, bosses, biomes, world looks and the retention screens.
extension GameScene {

    // MARK: - Setup / reset

    func setupExtras() {
        let dot = Art.softDot()

        // twin beam (second cone)
        for (b, z) in [(beamSprite2, CGFloat(598)), (landing3, CGFloat(597))] {
            b.removeFromParent()
            b.blendMode = .add
            b.colorBlendFactor = 1
            b.zPosition = z
            b.isHidden = true
            addChild(b)
        }
        beamSprite2.texture = Painter.beam()
        beamSprite2.anchorPoint = CGPoint(x: 0.5, y: 1)
        landing3.texture = Painter.landing()

        // shield bubble
        shieldNode.removeFromParent()
        let r = 120 * ufoScale
        shieldNode.path = CGPath(ellipseIn: CGRect(x: -r, y: -r * 0.62, width: r * 2, height: r * 1.24), transform: nil)
        shieldNode.fillColor = Art.rgb(0.3, 0.7, 1, 0.12)
        shieldNode.strokeColor = Art.rgb(0.6, 0.9, 1, 0.85)
        shieldNode.lineWidth = 2.5
        shieldNode.glowWidth = 5
        shieldNode.zPosition = 710
        shieldNode.isHidden = true
        addChild(shieldNode)

        // slow-mo tint, lightning flash, dawn
        slowTint.removeFromParent()
        slowTint.color = Art.rgb(0.3, 1, 0.8)
        slowTint.size = size
        slowTint.anchorPoint = .zero
        slowTint.alpha = 0
        slowTint.blendMode = .add
        slowTint.zPosition = 890
        addChild(slowTint)
        flashNode.removeFromParent()
        flashNode.color = .white
        flashNode.size = size
        flashNode.anchorPoint = .zero
        flashNode.alpha = 0
        flashNode.zPosition = 895
        addChild(flashNode)
        dawnNode.removeFromParent()
        dawnNode.texture = Art.gradient(size: CGSize(width: 8, height: 128),
                                        colors: [Art.rgb(0.4, 0.3, 0.6, 0), Art.rgb(0.95, 0.5, 0.45, 0.55), Art.rgb(1, 0.72, 0.4, 0.9)],
                                        locations: [0, 0.6, 1])
        dawnNode.anchorPoint = .zero
        dawnNode.size = CGSize(width: W, height: H - fieldTop + 10)
        dawnNode.position = CGPoint(x: 0, y: fieldTop - 10)
        dawnNode.zPosition = 1.5
        dawnNode.alpha = 0
        bg.addChild(dawnNode)

        // rain and snow
        rainNode.removeFromParent()
        rainNode.particleTexture = Painter.rainDrop()
        rainNode.particleBirthRate = 0
        rainNode.particleLifetime = 1.3
        rainNode.particleSize = CGSize(width: 3 * ws, height: 26 * ws)
        rainNode.particleAlpha = 0.55
        rainNode.particleAlphaRange = 0.25
        rainNode.emissionAngle = -CGFloat.pi / 2 - 0.22
        rainNode.particleRotation = -0.22
        rainNode.particleSpeed = 720 * ws
        rainNode.particleSpeedRange = 120 * ws
        rainNode.particlePositionRange = CGVector(dx: W * 1.5, dy: 0)
        rainNode.position = CGPoint(x: W * 0.6, y: H + 30)
        rainNode.zPosition = 880
        addChild(rainNode)

        snowNode.removeFromParent()
        snowNode.particleTexture = dot
        snowNode.particleBirthRate = 0
        snowNode.particleLifetime = 8
        snowNode.particleSize = CGSize(width: 5 * ws, height: 5 * ws)
        snowNode.particleScaleRange = 0.7
        snowNode.particleAlpha = 0.85
        snowNode.particleAlphaRange = 0.3
        snowNode.emissionAngle = -CGFloat.pi / 2
        snowNode.emissionAngleRange = 0.5
        snowNode.particleSpeed = 45 * ws
        snowNode.particleSpeedRange = 20 * ws
        snowNode.xAcceleration = -12 * ws
        snowNode.particlePositionRange = CGVector(dx: W * 1.4, dy: 0)
        snowNode.position = CGPoint(x: W * 0.6, y: H + 10)
        snowNode.zPosition = 880
        addChild(snowNode)

        // boss timer label
        bossLabel.removeFromParent()
        bossLabel = UIK.label("", size: 18, color: Art.rgb(1, 0.4, 0.4), font: UIK.heavyItalic, y: H / 2 - 120)
        hud.addChild(bossLabel)

        // lights: the beam lights up a pool on the field, the saucer glows from below
        for l in [beamLight, ufoLight, spotLight] {
            l.removeFromParent()
            l.categoryBitMask = 1
            l.shadowColor = .clear
            addChild(l)
        }
        beamLight.falloff = 1.4
        beamLight.ambientColor = Art.rgb(0.9, 0.91, 0.96)
        ufoLight.falloff = 2.6
        ufoLight.ambientColor = .black
        spotLight.falloff = 2.2
        spotLight.ambientColor = .black
        spotLight.lightColor = .black

        // cinematic grade: cool sky, warm ground, a little extra contrast (multiply x2, 0.5 = neutral)
        gradeNode.removeFromParent()
        gradeNode.texture = Art.gradient(size: CGSize(width: 8, height: 128),
                                         colors: [Art.rgb(0.47, 0.48, 0.58), Art.rgb(0.52, 0.5, 0.52), Art.rgb(0.55, 0.51, 0.46)],
                                         locations: [0, 0.5, 1])
        gradeNode.size = size
        gradeNode.anchorPoint = .zero
        gradeNode.blendMode = .multiplyX2
        gradeNode.zPosition = 898
        addChild(gradeNode)
        // soft neon halo around the saucer (bloom)
        ufoHalo.removeFromParent()
        ufoHalo.texture = Art.softDot()
        ufoHalo.size = CGSize(width: 330 * ufoScale, height: 150 * ufoScale)
        ufoHalo.blendMode = .add
        ufoHalo.colorBlendFactor = 1
        ufoHalo.zPosition = 699
        addChild(ufoHalo)
        applyCinematic()

        applyWorldLook()
    }

    func applyCinematic() {
        let on = FX.cinematic && !ProcessInfo.processInfo.arguments.contains("-nofx")
        gradeNode.isHidden = !on
        ufoHalo.isHidden = !on
    }

    /// Light positions/colours follow the beam every frame.
    func updateLights() {
        let on = beamVisible
        beamLight.position = beamPt
        beamLight.lightColor = on ? beamColorNow.withAlphaComponent(0.85) : .black
        ufoLight.position = CGPoint(x: ufo.position.x, y: ufo.position.y - 40 * ufoScale)
        ufoLight.lightColor = store.currentTheme.neon.withAlphaComponent(0.35)
        ufoHalo.position = CGPoint(x: ufo.position.x, y: ufo.position.y - 6 * ufoScale)
        ufoHalo.color = store.currentTheme.neon
        ufoHalo.alpha = 0.32 + 0.06 * sin(clock * 4)
        if let spot = searchLight {
            spotLight.position = spot.position
            spotLight.lightColor = Art.rgb(1, 0.95, 0.75)
        } else {
            spotLight.lightColor = .black
        }
    }

    /// Puddles reflect the beam when it is close and shimmer under the moon.
    func updatePuddles() {
        for d in decals where d.name == "puddle" {
            guard let refl = d.childNode(withName: "refl") as? SKSpriteNode else { continue }
            let dist = hypot(d.position.x - beamPt.x, (d.position.y - beamPt.y) * 2)
            let near = beamVisible ? max(0, 1 - dist / (W * 0.25)) : 0
            refl.color = beamColorNow
            refl.alpha = 0.12 + near * 0.95
            if let g = d.childNode(withName: "glint") {
                g.alpha = 0.18 + 0.15 * sin(clock * 2.5 + d.gx * 0.05) + near * 0.4
            }
        }
    }

    func resetExtras() {
        grabTimes = []
        lastMega = -10
        raining = false
        rainLeft = 0
        nextWeatherAt = 1500
        rainNode.particleBirthRate = 0
        snowNode.particleBirthRate = store.currentWorld.look == .winter ? 35 : 0
        lightningIn = 4
        for f in flyers { f.removeFromParent() }
        flyers = []
        warnNode?.removeFromParent()
        warnNode = nil
        dusterIn = CGFloat.random(in: 18...28)
        endSearchlight()
        searchIn = CGFloat.random(in: 16...24)
        spottedCooldown = 0
        bossNode?.removeFromParent()
        bossNode = nil
        bossTank = nil
        bossLeft = 0
        nextBossAt = 3000
        bossCount = 0
        setText(bossLabel, "")
        lastHitDistance = 0
        lastMissionTick = 0
        shotCooldown = 6
        aimingHunter = nil
        nextHeartAt = 1500
        dawnNode.alpha = 0
        slowTint.alpha = 0
        shieldNode.isHidden = true
        let startMap = Biome.picked ?? .farm
        if biome != startMap { applyBiome(startMap, animated: false) }
        store.refreshMissionsIfNeeded()
    }

    // MARK: - Per-frame

    /// World time runs slower during Slow-Mo; the saucer and beam stay at full speed.
    var worldRate: CGFloat { return power == .slowmo ? 0.4 : 1 }

    func extrasStep(_ dt: CGFloat) {
        let wdt = dt * worldRate
        updateBiome()
        updateWeather(dt)
        updateDusters(wdt)
        updateSearchlight(wdt)
        updateBoss(dt)
        updateBats(dt)
        updateHearts()
        cheatVacuum()
        updateLights()
        updatePuddles()
        if spottedCooldown > 0 { spottedCooldown -= dt }
        if shotCooldown > 0 { shotCooldown -= dt }

        // dawn slowly breaks the longer you fly
        dawnNode.alpha = max(0, min(0.6, CGFloat(distance - 4000) / 7000))
        slowTint.alpha += ((power == .slowmo ? 0.07 : 0) - slowTint.alpha) * min(1, dt * 5)

        // shield bubble
        if power == .shield {
            shieldNode.isHidden = false
            shieldNode.position = CGPoint(x: ufo.position.x, y: ufo.position.y + 18 * ufoScale)
            shieldNode.alpha = 0.7 + 0.3 * sin(clock * 6)
        } else {
            shieldNode.isHidden = true
        }

        // distance missions once a second
        if clock - lastMissionTick > 1, status == .play {
            lastMissionTick = clock
            var fin = store.mission(.distance, best: distance)
            fin += store.mission(.noHit, best: distance - lastHitDistance)
            missionDone(fin)
        }
    }

    // MARK: - Heart refill (every 1,500 points)

    func updateHearts() {
        if screen == .playing && status == .play && score >= nextHeartAt {
            nextHeartAt += 1500
            let d = CGFloat.random(in: (dMin + 0.25)...(dMax - 0.5))
            let h = HeartPickup()
            let glow = SKSpriteNode(texture: Art.softDot(), size: CGSize(width: 70, height: 70))
            glow.color = Art.rgb(1, 0.3, 0.4)
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.position = CGPoint(x: 0, y: 22)
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.4), .fadeAlpha(to: 1, duration: 0.4)])))
            h.addChild(Art.shadow(22))
            h.addChild(glow)
            let s = SKSpriteNode(texture: Painter.heart(), size: CGSize(width: 34, height: 33))
            s.position = CGPoint(x: 0, y: 22)
            s.run(.repeatForever(.group([
                .sequence([.moveBy(x: 0, y: 5, duration: 0.45), .moveBy(x: 0, y: -5, duration: 0.45)]),
                .sequence([.scale(to: 1.15, duration: 0.3), .scale(to: 1, duration: 0.3)])
            ])))
            h.addChild(s)
            h.gx = worldX(atX: W * 1.08, d: d)
            h.gd = d
            world.addChild(h)
            hearts.append(h)
            popupHUD("A heart appeared — beam it up to refill your health!", color: Art.rgb(1, 0.55, 0.6))
            sound.play("warn", volume: 0.4)
        }
        for h in hearts where !h.lifting {
            project(h)
            let hb = beamActive && screen == .playing ? beamHit(h.gx, h.gd, 1.3) : 0
            if hb > 0 {
                h.onTwin = hb == 2
                sound.laserGrab()
                startLift(h)
            }
        }
        hearts.removeAll { h in
            if !h.lifting && sx(h.gx, h.gd) < -150 * ws { h.removeFromParent(); return true }
            return false
        }
    }

    // MARK: - Twin beam

    var twinPt: CGPoint {
        let dir: CGFloat = beamPt.x < W * 0.62 ? 1 : -1
        return CGPoint(x: max(W * 0.12, min(W * 0.95, beamPt.x + dir * W * 0.17)), y: beamPt.y)
    }

    /// 0 = not in a beam, 1 = main beam, 2 = twin beam.
    func beamHit(_ x: CGFloat, _ d: CGFloat, _ k: CGFloat) -> Int {
        if groundDist(x, d, toScreen: beamPt) < k { return 1 }
        if power == .twin && groundDist(x, d, toScreen: twinPt) < k { return 2 }
        return 0
    }

    func drawTwin(base: UIColor) {
        guard power == .twin, beamVisible else {
            beamSprite2.isHidden = true
            landing3.isHidden = true
            return
        }
        let T = twinPt, U = ufoBottom
        let r = beamRadiusWorld * sc(depth(atY: T.y))
        let dx = T.x - U.x, dy = T.y - U.y
        beamSprite2.isHidden = false
        beamSprite2.position = U
        beamSprite2.size = CGSize(width: r * 2.4, height: max(4, hypot(dx, dy)))
        beamSprite2.zRotation = atan2(dx, -dy)
        beamSprite2.color = base
        beamSprite2.alpha = 0.75
        landing3.isHidden = false
        landing3.position = T
        landing3.size = CGSize(width: r * 3.4, height: r * 1.35)
        landing3.color = base
    }

    // MARK: - Grabs, combos, collections

    func registerGrab(_ c: Creature) {
        guard screen == .playing else { return }
        // haptics by weight
        if clock - lastHaptic > 0.06 {
            lastHaptic = clock
            if c.kind.weight >= 4 { hapticHeavy.impactOccurred() } else if c.kind.weight >= 2 { hapticMedium.impactOccurred() } else { hapticLight.impactOccurred() }
        }
        // grab the hunter while he is aiming: double points
        if c.kind == .hunter && c.aimTimer < 1.3 {
            c.value *= 2
            popup("QUICK DRAW x2", at: CGPoint(x: c.position.x, y: c.position.y + 40 * ws), color: UIK.yellow)
        }
        c.aimLine?.removeFromParent()
        c.aimLine = nil
        if aimingHunter === c { aimingHunter = nil }
        // MEGA PROBE: 5+ grabs inside 2 seconds
        grabTimes.append(clock)
        grabTimes.removeAll { clock - $0 > 2 }
        if grabTimes.count >= 5 && clock - lastMega > 2.5 {
            lastMega = clock
            let bonus = 20 * grabTimes.count * multiplier
            score += bonus
            banner("MEGA PROBE! +\(bonus)")
            sound.play("mega")
            grabTimes = []
        }
    }

    func onCollected(_ c: Creature) {
        store.addCaught(c.kind, c.variant, rare: c.rare)
        var fin: [String] = []
        switch c.kind {
        case .sheep: fin += store.mission(.sheep, add: 1)
        case .cow: fin += store.mission(.cows, add: 1)
        case .pig: fin += store.mission(.pigs, add: 1)
        default: if c.kind.isHuman { fin += store.mission(.humans, add: 1) }
        }
        if c.rare {
            store.d.raresCaught = (store.d.raresCaught ?? 0) + 1
            banner("RARE GOLDEN SHEEP!")
            sound.play("achieve")
        }
        if c.kind == .cow && c.variant == 3 { nuke() }
        missionDone(fin)
    }

    func missionDone(_ titles: [String]) {
        guard !titles.isEmpty else { return }
        banner("MISSION DONE!")
        popupHUD(titles[0], color: UIK.yellow)
        sound.play("achieve")
    }

    func popupHUD(_ text: String, color: UIColor) {
        let l = UIK.label(text, size: 16, color: color, font: UIK.heavyItalic, y: H * 0.02)
        l.zPosition = 60
        ui.addChild(l)
        l.run(.sequence([.wait(forDuration: 1.4), .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    /// Nuclear cow: everything on screen is pulled in, every obstacle explodes.
    func nuke() {
        store.d.nukes = (store.d.nukes ?? 0) + 1
        sound.play("nuke")
        hapticHeavy.impactOccurred()
        flashNode.color = Art.rgb(0.6, 1, 0.4)
        flashNode.removeAllActions()
        flashNode.alpha = 0.85
        flashNode.run(.fadeOut(withDuration: 0.8))
        banner("NUKE!")
        for c in creatures where !c.lifting {
            let x = sx(c.gx, c.gd)
            if x > 0 && x < W { startLift(c); registerGrab(c) }
        }
        for c in coins where !c.lifting {
            let x = sx(c.gx, c.gd)
            if x > 0 && x < W { startLift(c) }
        }
        for o in obstacles where !o.dead {
            let x = sx(o.gx, o.gd)
            if x > 0 && x < W && o.kind != .powerline { smash(o) }
        }
        obstacles.removeAll { o in
            if o.dead { o.wire?.removeFromParent(); o.removeFromParent(); return true }
            return false
        }
    }

    func spawnRareSheep(at x: CGFloat, d: CGFloat) {
        let c = spawnCreature(.sheep, variant: 2, x: x, d: d)
        c.rare = true
        c.value = 100
        c.walkSpeed *= 2.6
        let g = SKSpriteNode(texture: Art.softDot(), size: CGSize(width: 60, height: 40))
        g.color = Art.rgb(1, 0.85, 0.3)
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.position = CGPoint(x: 0, y: 18)
        g.zPosition = -0.5
        g.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.4), .fadeAlpha(to: 0.9, duration: 0.4)])))
        c.addChild(g)
    }

    func spawnNukeCow(at x: CGFloat, d: CGFloat) {
        let c = spawnCreature(.cow, variant: 3, x: x, d: d)
        let g = SKSpriteNode(texture: Art.softDot(), size: CGSize(width: 110, height: 70))
        g.color = Art.rgb(0.5, 1, 0.3)
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.position = CGPoint(x: 0, y: 26)
        g.zPosition = -0.5
        g.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        c.addChild(g)
    }

    // MARK: - Hunter

    func updateHunter(_ c: Creature, _ dt: CGFloat) {
        let x = c.position.x
        c.facing = ufo.position.x > x ? 1 : -1
        c.body.xScale = c.facing
        guard screen == .playing, status == .play, x > W * 0.05, x < W * 0.95 else {
            c.aimLine?.removeFromParent()
            c.aimLine = nil
            if aimingHunter === c { aimingHunter = nil }
            return
        }
        // only one hunter aims at a time, and only when nobody fired recently
        if aimingHunter == nil && shotCooldown <= 0 && c.aimTimer < 1.3 { aimingHunter = c }
        if aimingHunter !== c && c.aimTimer < 1.3 {
            c.aimTimer = 1.4
            return
        }
        c.aimTimer -= dt
        let s = sc(c.gd) * Art.creatureScale
        let muzzle = CGPoint(x: x + c.body.xScale * 30 * s, y: c.position.y + 23 * s)
        if c.aimTimer < 1.3 {
            if c.aimLine == nil {
                let l = SKShapeNode()
                l.strokeColor = Art.rgb(1, 0.2, 0.2, 0.8)
                l.lineWidth = 1.5
                l.zPosition = 640
                addChild(l)
                c.aimLine = l
                sound.play("warn", volume: 0.5, minGap: 0.5)
            }
            let p = CGMutablePath()
            p.move(to: muzzle)
            p.addLine(to: ufoBottom)
            c.aimLine?.path = p
            c.aimLine?.alpha = Int(clock * 10) % 2 == 0 ? 1 : 0.3
        }
        if c.aimTimer <= 0 {
            c.aimTimer = CGFloat.random(in: 5...7)
            aimingHunter = nil
            shotCooldown = CGFloat.random(in: 5...7)
            c.aimLine?.removeFromParent()
            c.aimLine = nil
            shoot(from: muzzle, speed: 620 * ws, big: false)
            c.body.run(.sequence([.moveBy(x: -4 * c.facing, y: 0, duration: 0.05), .moveBy(x: 4 * c.facing, y: 0, duration: 0.15)]))
            sound.play("shot")
        }
    }

    /// Projectile aimed at the saucer (hunter pellets, helicopter rockets).
    func shoot(from start: CGPoint, speed: CGFloat, big: Bool) {
        let m = Missile()
        if big {
            m.addChild(Art.missile())
            m.setScale(ws * 1.3)
        } else {
            let p = SKSpriteNode(texture: Art.softDot(), size: CGSize(width: 12 * ws, height: 12 * ws))
            p.color = Art.rgb(1, 0.85, 0.4)
            p.colorBlendFactor = 1
            p.blendMode = .add
            m.addChild(p)
            m.addChild(Art.circ(2.5 * ws, .white))
        }
        m.position = start
        let aim = ufo.position
        let ang = atan2(aim.y - start.y, aim.x - start.x)
        m.v = CGVector(dx: cos(ang) * speed, dy: sin(ang) * speed)
        m.zRotation = ang
        m.zPosition = 30
        fx.addChild(m)
        missiles.append(m)
        boom(at: start, size: big ? 6 : 3)
    }

    // MARK: - Crop duster

    func updateDusters(_ dt: CGFloat) {
        if status == .play && distance > 800 && bossNode == nil && bossTank == nil && warnNode == nil {
            dusterIn -= dt
            if dusterIn <= 0 {
                dusterIn = CGFloat.random(in: 22...36)
                let y = ufo.position.y
                let w = SKNode()
                w.position = CGPoint(x: W - 40 * ws, y: y)
                w.zPosition = 860
                let tri = Art.poly([CGPoint(x: -16, y: -14), CGPoint(x: 16, y: -14), CGPoint(x: 0, y: 16)], Art.rgb(1, 0.25, 0.2), stroke: .white)
                tri.setScale(ws)
                w.addChild(tri)
                w.addChild(UIK.label("!", size: 18 * ws, color: .white, font: UIK.heavyItalic, y: -3 * ws, shadow: nil))
                w.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)])))
                addChild(w)
                warnNode = w
                sound.play("warn")
                run(.wait(forDuration: 1.3)) { [weak self] in self?.launchDuster(y: y) }
            }
        }
        var gone: [Flyer] = []
        for f in flyers {
            f.position.x += f.vx * dt
            if Int(clock * 30) % 2 == 0 {
                let p = SKSpriteNode(texture: Art.softDot(), size: CGSize(width: 14 * ws, height: 14 * ws))
                p.color = Art.rgb(0.75, 0.95, 0.6)
                p.colorBlendFactor = 1
                p.alpha = 0.5
                p.position = CGPoint(x: f.position.x + 30 * ws, y: f.position.y - 14 * ws)
                p.zPosition = 690
                addChild(p)
                p.run(.sequence([.group([.moveBy(x: 20, y: -40 * ws, duration: 0.9), .scale(to: 2.5, duration: 0.9), .fadeOut(withDuration: 0.9)]), .removeFromParent()]))
            }
            if !f.hitDone && status == .play {
                let dx = f.position.x - ufo.position.x, dy = f.position.y - ufo.position.y
                if abs(dx) < 95 * ufoScale && abs(dy) < 30 * ws {
                    f.hitDone = true
                    takeDamage(1, byVehicle: true)
                }
            }
            if f.position.x < -200 { gone.append(f) }
        }
        for f in gone { f.removeFromParent() }
        flyers.removeAll { f in gone.contains { $0 === f } }
    }

    func launchDuster(y: CGFloat) {
        warnNode?.removeFromParent()
        warnNode = nil
        guard screen == .playing || screen == .paused else { return }
        let f = Flyer()
        let s = SKSpriteNode(texture: Painter.duster(), size: CGSize(width: 120, height: 56))
        s.setScale(ws * 1.05)
        f.addChild(s)
        f.position = CGPoint(x: W + 120 * ws, y: y)
        f.zPosition = 705
        f.vx = -560 * ws
        f.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.25), .moveBy(x: 0, y: -4, duration: 0.25)])))
        addChild(f)
        flyers.append(f)
        sound.play("plane", volume: 0.9)
    }

    // MARK: - Police searchlight

    func updateSearchlight(_ dt: CGFloat) {
        if let spot = searchLight, let cone = searchCone {
            searchLeft -= dt
            searchPhase += dt
            let d = 1.9 + 0.75 * sin(searchPhase * 0.6 + 1)
            let p = CGPoint(x: W * (0.5 + 0.38 * sin(searchPhase * 0.9)), y: sy(d))
            let r = 55 * sc(d)
            spot.position = p
            spot.size = CGSize(width: r * 3.2, height: r * 1.3)
            let top = CGPoint(x: W * 0.95, y: H + 40)
            let dx = p.x - top.x, dy = p.y - top.y
            cone.position = top
            cone.size = CGSize(width: r * 2.6, height: hypot(dx, dy))
            cone.zRotation = atan2(dx, -dy)
            if beamVisible && status == .play && spottedCooldown <= 0 {
                let ex = (beamPt.x - p.x) / (r * 1.5), ey = (beamPt.y - p.y) / (r * 0.6)
                if ex * ex + ey * ey < 1 {
                    spottedCooldown = 7
                    banner("SPOTTED! POLICE!")
                    sound.play("siren")
                    spawnVehicle(forced: .police)
                    run(.wait(forDuration: 0.6)) { [weak self] in self?.spawnVehicle(forced: .police) }
                }
            }
            if searchLeft <= 0 { endSearchlight() }
            return
        }
        guard status == .play, distance > 600, biome != .desert, bossNode == nil, bossTank == nil else { return }
        searchIn -= dt
        if searchIn <= 0 {
            searchIn = CGFloat.random(in: 22...34)
            searchLeft = 9
            searchPhase = CGFloat.random(in: 0...6)
            let spot = SKSpriteNode(texture: Painter.landing())
            spot.color = Art.rgb(1, 0.95, 0.7)
            spot.colorBlendFactor = 1
            spot.blendMode = .add
            spot.alpha = 0
            spot.zPosition = 450
            spot.run(.fadeAlpha(to: 0.9, duration: 0.5))
            addChild(spot)
            let cone = SKSpriteNode(texture: Painter.beam())
            cone.anchorPoint = CGPoint(x: 0.5, y: 1)
            cone.color = Art.rgb(1, 0.95, 0.75)
            cone.colorBlendFactor = 1
            cone.blendMode = .add
            cone.alpha = 0
            cone.zPosition = 449
            cone.run(.fadeAlpha(to: 0.28, duration: 0.5))
            addChild(cone)
            searchLight = spot
            searchCone = cone
            popupHUD("Avoid the searchlight!", color: Art.rgb(1, 0.95, 0.7))
        }
    }

    func endSearchlight() {
        for n in [searchLight, searchCone] {
            n?.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        }
        searchLight = nil
        searchCone = nil
    }

    // MARK: - Power lines

    func spawnPowerline(at x: CGFloat, d: CGFloat) {
        let a = spawnObstacle(.powerline, x: x, d: d)
        let b = spawnObstacle(.powerline, x: x + 300, d: d)
        a.span = 300
        a.pole2 = b
        let w = SKShapeNode()
        w.strokeColor = Art.rgb(0.08, 0.08, 0.1, 0.95)
        w.lineWidth = 1.4
        w.zPosition = 400 - d * 100 + 1
        world.addChild(w)
        a.wire = w
    }

    func wireEnds(_ o: Obstacle) -> (CGPoint, CGPoint)? {
        guard let b = o.pole2 as? Obstacle else { return nil }
        let s1 = sc(o.gd), s2 = sc(b.gd)
        return (CGPoint(x: o.position.x, y: o.position.y + 118 * s1), CGPoint(x: b.position.x, y: b.position.y + 118 * s2))
    }

    func updateWire(_ o: Obstacle) {
        if let b = o.pole2 as? Obstacle, b.dead {
            o.wire?.removeFromParent()
            o.wire = nil
            o.span = 0
            return
        }
        guard let w = o.wire, let ends = wireEnds(o) else { return }
        let (a, b) = ends
        let s = sc(o.gd)
        let p = CGMutablePath()
        for off in [-15, 0, 15] as [CGFloat] {
            let a2 = CGPoint(x: a.x + off * s, y: a.y), b2 = CGPoint(x: b.x + off * s, y: b.y)
            p.move(to: a2)
            p.addQuadCurve(to: b2, control: CGPoint(x: (a2.x + b2.x) / 2, y: (a2.y + b2.y) / 2 - 18 * s))
        }
        w.path = p
    }

    /// Does the beam cross the wires of this pole pair?
    func beamCrossesWire(_ o: Obstacle, U: CGPoint, T: CGPoint, tD: CGFloat) -> Bool {
        guard let ends = wireEnds(o) else { return false }
        let (a, b) = ends
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - 9 * sc(o.gd))
        for (p, q) in [(a, mid), (mid, b)] {
            if let t = segmentHit(U, T, p, q) {
                let dep = ufoDepth + (tD - ufoDepth) * t
                if abs(dep - o.gd) < 0.16 { return true }
            }
        }
        return false
    }

    func segmentHit(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGFloat? {
        let d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        if abs(d) < 0.0001 { return nil }
        let t = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
        let u = ((p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)) / d
        return (t >= 0 && t <= 1 && u >= 0 && u <= 1) ? t : nil
    }

    // MARK: - Bosses (every 3,000 M)

    func updateBoss(_ dt: CGFloat) {
        if status == .play && bossNode == nil && bossTank == nil && distance >= nextBossAt {
            nextBossAt += 3000
            bossCount += 1
            startBoss(heli: false)   // helicopter removed — the giant tank is the boss
        }
        guard bossNode != nil || bossTank != nil else { return }
        if status == .dead {
            bossNode?.removeFromParent(); bossNode = nil; bossTank = nil; setText(bossLabel, ""); return
        }
        bossLeft -= dt
        setText(bossLabel, "BOSS  •  SURVIVE \(max(0, Int(ceil(bossLeft))))")
        if let h = bossNode {
            let want = CGPoint(x: max(W * 0.45, min(W * 0.88, ufo.position.x + W * 0.28)), y: H * 0.86 + sin(clock * 1.7) * 10 * ws)
            h.position.x += (want.x - h.position.x) * min(1, dt * 1.2)
            h.position.y += (want.y - h.position.y) * min(1, dt * 1.2)
            h.zRotation = sin(clock * 1.3) * 0.05
            bossFireIn -= dt
            if bossFireIn <= 0 && status == .play {
                bossFireIn = CGFloat.random(in: 2.6...3.6)
                shoot(from: CGPoint(x: h.position.x - 50 * ws, y: h.position.y - 14 * ws), speed: 330 * ws, big: true)
                sound.play("missile", volume: 0.7)
            }
            if Int(clock * 2) != Int((clock - dt) * 2) { sound.play("heli", volume: 0.35, minGap: 0.4) }
        }
        if let t = bossTank {
            if t.dead {
                bossWon()
                return
            }
            t.gx = worldX(atX: W * 0.8, d: t.gd)
            t.gd = roadD(t.gx)
        }
        if bossLeft <= 0 { bossWon() }
    }

    func startBoss(heli: Bool) {
        bossLeft = 30
        bossFireIn = 2.5
        banner("BOSS INCOMING!")
        sound.play("siren")
        if heli {
            let h = SKNode()
            let body = SKSpriteNode(texture: Painter.helicopter(), size: CGSize(width: 150, height: 70))
            body.setScale(ws * 1.25)
            h.addChild(body)
            let rotor = SKSpriteNode(texture: Painter.rotor(), size: CGSize(width: 150, height: 10))
            rotor.setScale(ws * 1.25)
            rotor.position = CGPoint(x: -8 * ws, y: 40 * ws)
            rotor.run(.repeatForever(.sequence([.scaleX(to: 0.15 * ws, duration: 0.05), .scaleX(to: 1.25 * ws, duration: 0.05)])))
            h.addChild(rotor)
            h.position = CGPoint(x: W + 160 * ws, y: H * 0.9)
            h.zPosition = 706
            addChild(h)
            bossNode = h
        } else {
            let x = worldX(atX: W * 0.8, d: roadD(camX))
            let t = spawnObstacle(.tank, x: x, d: roadD(x))
            t.giant = true
            t.vx = 0.001
            t.fireTimer = 2
            bossTank = t
        }
    }

    func bossWon() {
        let reward = 50
        runCoins += reward
        score += 500 * multiplier
        store.d.bossesBeaten = (store.d.bossesBeaten ?? 0) + 1
        banner("BOSS BEATEN! +\(reward)")
        sound.play("achieve")
        setText(bossLabel, "")
        if let h = bossNode {
            h.run(.sequence([.moveBy(x: W, y: H * 0.3, duration: 1.5), .removeFromParent()]))
        }
        if let t = bossTank, !t.dead {
            t.vx = -140
            t.fireTimer = 999
        }
        bossNode = nil
        bossTank = nil
    }

    // MARK: - Weather

    func updateWeather(_ dt: CGFloat) {
        let winter = store.currentWorld.look == .winter
        if screen != .playing {
            rainNode.particleBirthRate = 0
            snowNode.particleBirthRate = winter ? 30 : 0
            return
        }
        if !raining && status == .play && distance >= nextWeatherAt {
            raining = true
            rainLeft = CGFloat.random(in: 22...32)
            lightningIn = CGFloat.random(in: 2...4)
            if winter { snowNode.particleBirthRate = 130 } else { rainNode.particleBirthRate = 240 }
        }
        if raining {
            rainLeft -= dt
            if !winter {
                lightningIn -= dt
                if lightningIn <= 0 {
                    lightningIn = CGFloat.random(in: 4...8)
                    flashNode.color = .white
                    flashNode.removeAllActions()
                    flashNode.run(.sequence([.fadeAlpha(to: 0.7, duration: 0.05), .fadeAlpha(to: 0.1, duration: 0.08),
                                             .fadeAlpha(to: 0.5, duration: 0.05), .fadeOut(withDuration: 0.35)]))
                    run(.wait(forDuration: 0.35)) { [weak self] in self?.sound.play("thunder", volume: 0.9) }
                    beamLight.ambientColor = Art.rgb(1, 1, 1)
                    run(.wait(forDuration: 0.2)) { [weak self] in self?.beamLight.ambientColor = Art.rgb(0.9, 0.91, 0.96) }
                }
            }
            if rainLeft <= 0 {
                raining = false
                nextWeatherAt = distance + Int.random(in: 1500...2500)
                rainNode.particleBirthRate = 0
                snowNode.particleBirthRate = winter ? 35 : 0
            }
        }
    }

    // MARK: - Biomes

    func updateBiome() {
        guard screen == .playing, status != .dead, Biome.picked == nil else { return }
        let b = Biome.at(distance)
        if b != biome {
            applyBiome(b, animated: true)
            banner("WELCOME TO \(b.name)!")
            store.d.furthestBiome = max(store.d.furthestBiome ?? 0, b.rawValue)
        }
    }

    func makeTiles(_ tex: SKTexture, _ h: CGFloat, _ y: CGFloat, _ z: CGFloat, alpha: CGFloat) -> [SKSpriteNode] {
        var out: [SKSpriteNode] = []
        for i in 0..<2 {
            let t = SKSpriteNode(texture: tex, size: CGSize(width: W, height: h))
            t.anchorPoint = .zero
            t.position = CGPoint(x: CGFloat(i) * W, y: y)
            t.zPosition = z
            t.alpha = alpha
            bg.addChild(t)
            out.append(t)
        }
        return out
    }

    func applyBiome(_ b: Biome, animated: Bool) {
        let prev = biome
        biome = b
        let fade: TimeInterval = animated ? 1.6 : 0
        let a0: CGFloat = animated ? 0 : 1
        func swap(_ old: [SKNode], _ new: [SKNode]) {
            for n in old { n.run(.sequence([.fadeOut(withDuration: fade), .removeFromParent()])) }
            for n in new { n.run(.fadeIn(withDuration: fade)) }
        }
        let winter = store.currentWorld.look == .winter
        // field
        let fsz = CGSize(width: W, height: fieldTop + 4)
        let ftex = b == .farm ? Painter.field(fsz) : Painter.ground(fsz, biome: b)
        let nf = SKSpriteNode(texture: ftex, size: fsz)
        nf.anchorPoint = .zero
        nf.zPosition = 5
        nf.alpha = a0
        nf.lightingBitMask = 1
        if winter && b != .desert { nf.color = Art.rgb(0.85, 0.92, 1); nf.colorBlendFactor = 0.55 }
        bg.addChild(nf)
        swap(fieldNode.map { [$0] } ?? [], [nf])
        fieldNode = nf

        // hills / skyline / dunes
        let nearH = H * (b == .city ? 0.2 : 0.13)
        let nearTex: SKTexture
        switch b {
        case .farm: nearTex = Painter.mountains(CGSize(width: W, height: nearH), seed: 4, top: Art.rgb(0.1, 0.13, 0.27), bottom: Art.rgb(0.05, 0.07, 0.15), rough: 0.35)
        case .city: nearTex = Painter.skyline(CGSize(width: W, height: nearH))
        case .desert: nearTex = Painter.dunes(CGSize(width: W, height: nearH), seed: 8, top: Art.rgb(0.32, 0.24, 0.26), bottom: Art.rgb(0.18, 0.13, 0.14))
        }
        let newNear = makeTiles(nearTex, nearH, fieldTop - 4, 4, alpha: a0)
        swap(nearTiles, newNear)
        nearTiles = newNear
        let hedgeH = H * 0.06
        let newHedge: [SKSpriteNode] = b == .farm ? makeTiles(Painter.hedge(CGSize(width: W, height: hedgeH)), hedgeH, fieldTop - hedgeH * 0.45, 6, alpha: a0) : []
        swap(hedgeTiles, newHedge)
        hedgeTiles = newHedge
        if b == .desert || prev == .desert {
            let farH = H * 0.25
            let ftex2 = b == .desert
                ? Painter.dunes(CGSize(width: W, height: farH), seed: 3, top: Art.rgb(0.36, 0.3, 0.42), bottom: Art.rgb(0.22, 0.18, 0.28))
                : Painter.mountains(CGSize(width: W, height: farH), seed: 21, top: Art.rgb(0.2, 0.24, 0.45), bottom: Art.rgb(0.12, 0.15, 0.3), rough: 0.6)
            let newFar = makeTiles(ftex2, farH, fieldTop - 4, 3, alpha: a0)
            swap(farTiles, newFar)
            farTiles = newFar
        }
        if winter {
            for t in farTiles + nearTiles { t.color = .white; t.colorBlendFactor = 0.3 }
        }
        switch b {
        case .farm: road.fillColor = Art.rgb(0.2, 0.17, 0.12, 0.92)
        case .city: road.fillColor = Art.rgb(0.1, 0.1, 0.13, 0.95)
        case .desert: road.fillColor = Art.rgb(0.32, 0.25, 0.18, 0.85)
        }
    }

    // MARK: - World look (Halloween / Winter)

    func applyWorldLook() {
        for b in bats { b.removeFromParent() }
        bats = []
        let look = store.currentWorld.look
        snowNode.particleBirthRate = look == .winter ? 30 : 0
        guard look != .normal else { return }
        if look == .halloween {
            // orange harvest moon glow
            let moon = SKSpriteNode(texture: Art.softDot(), size: CGSize(width: H * 0.5, height: H * 0.5))
            moon.color = Art.rgb(1, 0.5, 0.1)
            moon.colorBlendFactor = 1
            moon.blendMode = .add
            moon.alpha = 0.75
            moon.position = CGPoint(x: W * 0.2, y: H * 0.78)
            moon.zPosition = 1.2
            bg.addChild(moon)
            let tint = SKSpriteNode(color: Art.rgb(0.4, 0.1, 0.35), size: CGSize(width: W, height: H - fieldTop))
            tint.anchorPoint = .zero
            tint.position = CGPoint(x: 0, y: fieldTop)
            tint.alpha = 0.25
            tint.blendMode = .add
            tint.zPosition = 1.4
            bg.addChild(tint)
            for i in 0..<7 {
                let b = SKSpriteNode(texture: Painter.bat(), size: CGSize(width: 40 * ws, height: 20 * ws))
                b.position = CGPoint(x: CGFloat.random(in: 0...W), y: CGFloat.random(in: H * 0.62...H * 0.92))
                b.zPosition = 3.5
                b.setScale(CGFloat.random(in: 0.6...1.1))
                b.run(.repeatForever(.sequence([.wait(forDuration: Double(i) * 0.03), .scaleY(to: 0.3, duration: 0.12), .scaleY(to: b.yScale, duration: 0.12)])))
                bg.addChild(b)
                bats.append(b)
            }
        }
    }

    func updateBats(_ dt: CGFloat) {
        for (i, b) in bats.enumerated() {
            b.position.x -= (40 + CGFloat(i) * 6) * ws * dt
            b.position.y += sin(clock * 2 + CGFloat(i)) * 0.4
            if b.position.x < -40 { b.position.x = W + 40; b.position.y = CGFloat.random(in: H * 0.62...H * 0.92) }
        }
    }

    /// Small ground decoration that suits the current biome / world look.
    func biomeDecor() -> SKNode {
        let look = store.currentWorld.look
        if look == .halloween && biome == .farm && Int.random(in: 0..<14) == 0 {
            let p = SKSpriteNode(texture: Painter.pumpkin(), size: CGSize(width: 40, height: 34))
            p.anchorPoint = CGPoint(x: 0.5, y: 0.08)
            return p
        }
        let t = Art.tuft()
        if let s = t as? SKSpriteNode {
            switch biome {
            case .farm: if look == .winter { s.color = Art.rgb(0.9, 0.95, 1); s.colorBlendFactor = 0.7 }
            case .city: s.color = Art.rgb(0.35, 0.4, 0.45); s.colorBlendFactor = 0.6; s.alpha = 0.6
            case .desert: s.color = Art.rgb(0.6, 0.48, 0.3); s.colorBlendFactor = 0.8; s.alpha = 0.8
            }
        }
        return t
    }

    // MARK: - Biome spawns

    func spawnCityGroup(at x: CGFloat) {
        let d = CGFloat.random(in: (dMin + 0.1)...(dMax - 0.2))
        let r = Int.random(in: 0..<100)
        if r < 3 { spawnRareSheep(at: x, d: d); return }
        if r < 50 {
            for i in 0..<Int.random(in: 1...3) { spawnCreature(.citizen, variant: 0, x: x + CGFloat(i) * 28, d: d + CGFloat.random(in: -0.1...0.1)) }
        } else if r < 65 {
            spawnCreature(.reporter, variant: 0, x: x, d: d)
            spawnCreature(.citizen, variant: 0, x: x + 30, d: d)
        } else if r < 78 {
            for i in 0..<2 { spawnCreature(.fireman, variant: 0, x: x + CGFloat(i) * 26, d: d) }
        } else if r < 88 {
            for i in 0..<Int.random(in: 2...3) { spawnCreature(.soldier, variant: 0, x: x + CGFloat(i) * 26, d: d) }
        } else {
            spawnCreature(.dog, variant: 0, x: x, d: d)
            spawnCreature(.citizen, variant: 0, x: x + 30, d: d)
        }
    }

    func spawnDesertGroup(at x: CGFloat) {
        let d = CGFloat.random(in: (dMin + 0.1)...(dMax - 0.2))
        let r = Int.random(in: 0..<100)
        if r < 3 { spawnRareSheep(at: x, d: d); return }
        if r < 40 {
            for i in 0..<Int.random(in: 1...3) { spawnCreature(.camel, variant: 0, x: x + CGFloat(i) * 70, d: d + CGFloat(i) * 0.12) }
            spawnCreature(.bedouin, variant: 0, x: x - 40, d: d)
        } else if r < 70 {
            let flock = Flock(x: x, d: d)
            flocks.append(flock)
            for _ in 0..<Int.random(in: 2...4) {
                let c = spawnCreature(.sheep, variant: 0, x: x, d: d)
                c.flock = flock
                c.offX = CGFloat.random(in: -45...45)
                c.offD = CGFloat.random(in: -0.12...0.12)
            }
            spawnCreature(.bedouin, variant: 0, x: x + 60, d: d)
        } else {
            for i in 0..<Int.random(in: 2...3) { spawnCreature(.bedouin, variant: 0, x: x + CGFloat(i) * 30, d: d) }
        }
    }

    func biomeObstacle() -> ObKind? {
        switch biome {
        case .farm: return nil
        case .city: return [.building, .lamp, .lamp, .hydrant, .hydrant, .barrels].randomElement()
        case .desert: return [.tent, .palm, .palm, .barrels].randomElement()
        }
    }

    // MARK: - Screens: missions, daily chest, awards, collection, friends, worlds

    func claimDaily() {
        let (coins, day) = store.claimDailyReward()
        sound.play("chest")
        newOverlay(dim: 0.45)
        overlay.addChild(UIK.panel(min(W - 80, 420), H * 0.66))
        overlay.addChild(UIK.label("DAY \(day) CHEST", size: 28, color: UIK.yellow, y: H * 0.2))
        let chest = SKNode()
        chest.addChild(Art.rect(70, 44, Art.rgb(0.55, 0.32, 0.15), 0, 0, r: 6, stroke: Art.rgb(0.95, 0.75, 0.3)))
        chest.addChild(Art.rect(70, 6, Art.rgb(0.95, 0.75, 0.3), 0, 4))
        chest.addChild(Art.rect(10, 12, Art.rgb(1, 0.85, 0.4), 0, 2, r: 2))
        let glow = SKSpriteNode(texture: Painter.coin(), size: CGSize(width: 140, height: 140))
        glow.blendMode = .add
        glow.zPosition = -1
        chest.addChild(glow)
        chest.position = CGPoint(x: 0, y: H * 0.04)
        chest.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.4), .scale(to: 1, duration: 0.4)])))
        overlay.addChild(chest)
        overlay.addChild(UIK.label("+\(coins) coins", size: 24, color: .white, y: -H * 0.1))
        let next = Store.dailyRewards[min(day, 6)]
        overlay.addChild(UIK.label("Come back tomorrow for \(next)!", size: 13, color: UIK.cyan, y: -H * 0.17, shadow: nil))
        addButton("OK", x: 0, y: -H * 0.26, w: 120, h: 40, fontSize: 26, plain: true) { [weak self] in
            self?.awardsThenMenu()
        }
    }

    /// Shows any freshly earned achievements, then returns to the menu.
    func awardsThenMenu() {
        let new = store.checkAchievements()
        if new.isEmpty { showMenu(); return }
        sound.play("achieve")
        newOverlay(dim: 0.45)
        overlay.addChild(UIK.panel(min(W - 80, 460), H * 0.7))
        overlay.addChild(UIK.label("NEW TITLE!", size: 28, color: UIK.yellow, y: H * 0.22))
        for (i, a) in new.prefix(4).enumerated() {
            overlay.addChild(UIK.label("★ \(a.title)  +\(a.reward)", size: 18, color: .white, y: H * 0.1 - CGFloat(i) * 28))
        }
        addButton("OK", x: 0, y: -H * 0.25, w: 120, h: 40, fontSize: 26, plain: true) { [weak self] in self?.showMenu() }
    }

    func showMissions() {
        screen = .settings
        store.refreshMissionsIfNeeded()
        newOverlay(dim: 0.3)
        let pw = min(W - 40, 620)
        overlay.addChild(UIK.panel(pw, H - 40, y: -6))
        coinBadge()
        overlay.addChild(UIK.label("DAILY MISSIONS", size: 24, color: UIK.cyan, y: H / 2 - 44))
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in self?.showMenu() }
        let ms = store.d.missions ?? []
        for (i, m) in ms.enumerated() {
            let y = H * 0.2 - CGFloat(i) * H * 0.2
            let row = SKShapeNode(rectOf: CGSize(width: pw - 60, height: H * 0.16), cornerRadius: 10)
            row.fillColor = UIK.cardFill
            row.strokeColor = m.done ? UIK.yellow : UIColor(white: 1, alpha: 0.12)
            row.lineWidth = 2
            row.position = CGPoint(x: 0, y: y)
            overlay.addChild(row)
            let left = -pw / 2 + 50
            overlay.addChild(UIK.label(m.title, size: 16, color: .white, x: left, y: y + 12, align: .left))
            let bw = (pw - 60) * 0.5
            let track = SKShapeNode(rectOf: CGSize(width: bw, height: 8), cornerRadius: 4)
            track.fillColor = UIColor(white: 0, alpha: 0.4)
            track.strokeColor = .clear
            track.position = CGPoint(x: left + bw / 2, y: y - 12)
            overlay.addChild(track)
            let frac = min(1, CGFloat(m.progress) / CGFloat(max(1, m.target)))
            if frac > 0 {
                let fillW = max(8, bw * frac)
                let f = SKShapeNode(rectOf: CGSize(width: fillW, height: 8), cornerRadius: 4)
                f.fillColor = m.done ? UIK.yellow : Art.rgb(0.45, 0.82, 1)
                f.strokeColor = .clear
                f.position = CGPoint(x: left + fillW / 2, y: y - 12)
                overlay.addChild(f)
            }
            overlay.addChild(UIK.label("\(min(m.progress, m.target))/\(m.target)", size: 12, color: UIColor(white: 1, alpha: 0.8), x: left + bw + 10, y: y - 12, align: .left, shadow: nil))
            let rx = pw / 2 - 90
            if m.claimed {
                overlay.addChild(UIK.label("DONE ✓", size: 16, color: UIK.cyan, x: rx, y: y))
            } else if m.done {
                addButton("CLAIM \(m.reward)", x: rx, y: y, w: 120, h: 34, color: UIK.green, fontSize: 14) { [weak self] in
                    guard let self = self, var all = self.store.d.missions, i < all.count else { return }
                    all[i].claimed = true
                    self.store.d.missions = all
                    self.store.d.coins += m.reward
                    self.store.d.coinsEarnedTotal = (self.store.d.coinsEarnedTotal ?? 0) + m.reward
                    self.store.save()
                    self.sound.play("chest")
                    self.showMissions()
                }
            } else {
                let ci = UIK.coinIcon(7)
                ci.position = CGPoint(x: rx - 26, y: y)
                overlay.addChild(ci)
                overlay.addChild(UIK.label("\(m.reward)", size: 16, color: UIK.yellow, x: rx - 14, y: y, align: .left))
            }
        }
        overlay.addChild(UIK.label("New missions every day", size: 12, color: UIColor(white: 1, alpha: 0.6), y: -H / 2 + 34, shadow: nil))
    }

    func showAwards(tab: Int = 0, page: Int = 0) {
        screen = .settings
        newOverlay(dim: 0.3)
        let pw = min(W - 30, 720)
        overlay.addChild(UIK.panel(pw, H - 40, y: -6))
        coinBadge()
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in self?.showMenu() }
        for (i, t) in ["TITLES", "COLLECTION"].enumerated() {
            let x = (CGFloat(i) - 0.5) * 200
            if i == tab {
                let sel = SKShapeNode(rectOf: CGSize(width: 180, height: 30), cornerRadius: 6)
                sel.fillColor = UIK.cardFill
                sel.strokeColor = UIK.panelEdge
                sel.position = CGPoint(x: x, y: H / 2 - 46)
                overlay.addChild(sel)
            }
            addButton(t, x: x, y: H / 2 - 46, w: 180, h: 30, fontSize: 20, plain: true) { [weak self] in self?.showAwards(tab: i) }
        }
        if tab == 0 {
            let done = Set(store.d.achievements ?? [])
            overlay.addChild(UIK.label("Your title: \(store.title)", size: 16, color: UIK.yellow, y: H / 2 - 80))
            let per = 7
            let list = Array(Achievement.all.dropFirst(page * per).prefix(per))
            for (i, a) in list.enumerated() {
                let y = H / 2 - 112 - CGFloat(i) * min(32, (H - 190) / 7)
                let got = done.contains(a.id)
                overlay.addChild(UIK.label(got ? "★" : "☆", size: 18, color: got ? UIK.yellow : UIColor(white: 1, alpha: 0.4), x: -pw / 2 + 50, y: y, shadow: nil))
                overlay.addChild(UIK.label(a.title, size: 15, color: got ? .white : UIColor(white: 1, alpha: 0.55), x: -pw / 2 + 70, y: y, align: .left, shadow: nil))
                overlay.addChild(UIK.label(a.detail, size: 12, color: UIColor(white: 1, alpha: 0.6), x: -pw / 2 + 260, y: y, align: .left, shadow: nil))
                overlay.addChild(UIK.label("+\(a.reward)", size: 13, color: UIK.yellow, x: pw / 2 - 50, y: y, align: .right, shadow: nil))
            }
            let pages = Int(ceil(Double(Achievement.all.count) / Double(per)))
            if page < pages - 1 { addButton("▶", x: pw / 2 - 24, y: 0, w: 40, h: 50, fontSize: 28, plain: true) { [weak self] in self?.showAwards(tab: 0, page: page + 1) } }
            if page > 0 { addButton("◀", x: -pw / 2 + 24, y: 0, w: 40, h: 50, fontSize: 28, plain: true) { [weak self] in self?.showAwards(tab: 0, page: page - 1) } }
        } else {
            let per = 10
            let entries = Array(CollectionEntry.all.dropFirst(page * per).prefix(per))
            let seen = CollectionEntry.all.filter { store.caught($0.kind, $0.variant, rare: $0.rare) > 0 }.count
            overlay.addChild(UIK.label("\(seen)/\(CollectionEntry.all.count) found", size: 14, color: UIK.yellow, y: H / 2 - 78))
            let cw = min(120, (pw - 80) / 5), chh = min(110, (H - 150) / 2)
            for (i, e) in entries.enumerated() {
                let col = i % 5, row = i / 5
                let x = (CGFloat(col) - 2) * (cw + 8)
                let y = H * 0.08 - CGFloat(row) * (chh + 8)
                let n = store.caught(e.kind, e.variant, rare: e.rare)
                let cell = SKShapeNode(rectOf: CGSize(width: cw, height: chh), cornerRadius: 8)
                cell.fillColor = UIK.cardFill
                cell.strokeColor = e.special && n > 0 ? UIK.yellow : UIColor(white: 1, alpha: 0.12)
                cell.lineWidth = e.special && n > 0 ? 2.5 : 1.5
                cell.position = CGPoint(x: x, y: y)
                overlay.addChild(cell)
                let icon = Art.creature(e.kind, variant: e.variant)
                icon.setScale(e.kind == .cow || e.kind == .camel ? 0.75 : 1.1)
                icon.position = CGPoint(x: x, y: y - chh * 0.12)
                if n == 0 { icon.alpha = 0.12 }
                overlay.addChild(icon)
                overlay.addChild(UIK.label(n > 0 ? e.name : "???", size: 11, color: .white, x: x, y: y + chh / 2 - 12, shadow: nil))
                overlay.addChild(UIK.label(n > 0 ? "×\(n)" : "", size: 12, color: UIK.yellow, x: x, y: y - chh / 2 + 10, shadow: nil))
            }
            let pages = Int(ceil(Double(CollectionEntry.all.count) / Double(per)))
            if page < pages - 1 { addButton("▶", x: pw / 2 - 24, y: 0, w: 40, h: 50, fontSize: 28, plain: true) { [weak self] in self?.showAwards(tab: 1, page: page + 1) } }
            if page > 0 { addButton("◀", x: -pw / 2 + 24, y: 0, w: 40, h: 50, fontSize: 28, plain: true) { [weak self] in self?.showAwards(tab: 1, page: page - 1) } }
        }
    }

    func showFriends() {
        screen = .settings
        newOverlay(dim: 0.3)
        let pw = min(W - 40, 640)
        overlay.addChild(UIK.panel(pw, H - 40, y: -6))
        overlay.addChild(UIK.label("FRIENDS", size: 24, color: UIK.cyan, y: H / 2 - 44))
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in self?.showMenu() }
        let me = store.d.playerName ?? "Me"
        addButton("NAME: \(me)", x: -pw / 2 + 120, y: H / 2 - 82, w: 190, h: 30, color: Art.rgb(0.3, 0.25, 0.55), fontSize: 13) { [weak self] in self?.askName() }
        addButton("COPY MY CODE", x: 0, y: H / 2 - 82, w: 150, h: 30, color: UIK.green, fontSize: 13) { [weak self] in
            guard let self = self else { return }
            UIPasteboard.general.string = ScoreCode.make(name: me, score: self.store.d.bestScore, distance: self.store.d.bestDistance)
            self.popupHUD("Code copied — send it to your friends!", color: UIK.yellow)
        }
        addButton("ADD FRIEND CODE", x: pw / 2 - 100, y: H / 2 - 82, w: 170, h: 30, color: Art.rgb(0.25, 0.45, 0.9), fontSize: 13) { [weak self] in
            guard let self = self else { return }
            guard let text = UIPasteboard.general.string, let f = ScoreCode.read(text) else {
                self.popupHUD("Copy a friend's ALIEN- code first", color: Art.rgb(1, 0.5, 0.5))
                return
            }
            var list = (self.store.d.friends ?? []).filter { $0.name != f.name }
            list.append(f)
            self.store.d.friends = list
            self.store.save()
            self.sound.play("coin")
            self.showFriends()
        }
        var rows = store.d.friends ?? []
        rows.append(FriendScore(name: me + " (you)", score: store.d.bestScore, distance: store.d.bestDistance))
        rows.sort { $0.score > $1.score }
        let step = min(30, (H - 170) / 7)
        for (i, r) in rows.prefix(7).enumerated() {
            let y = H / 2 - 122 - CGFloat(i) * step
            let col: UIColor = r.name.hasSuffix("(you)") ? UIK.yellow : .white
            overlay.addChild(UIK.label("\(i + 1).", size: 16, color: col, x: -pw / 2 + 50, y: y, align: .left, shadow: nil))
            overlay.addChild(UIK.label(r.name, size: 16, color: col, x: -pw / 2 + 84, y: y, align: .left, shadow: nil))
            overlay.addChild(UIK.label("\(UIK.coins(r.score)) PTS", size: 15, color: col, x: pw / 2 - 170, y: y, align: .right, shadow: nil))
            overlay.addChild(UIK.label("\(UIK.coins(r.distance)) M", size: 13, color: UIColor(white: 1, alpha: 0.7), x: pw / 2 - 50, y: y, align: .right, shadow: nil))
        }
        if rows.count == 1 {
            overlay.addChild(UIK.label("Copy your code and send it on WhatsApp. When a friend sends theirs, copy it and tap ADD.",
                                       size: 12, color: UIColor(white: 1, alpha: 0.7), y: -H * 0.2, shadow: nil))
        }
    }

    func askName() {
        guard var vc = view?.window?.rootViewController else { return }
        while let p = vc.presentedViewController { vc = p }
        let a = UIAlertController(title: "Your name", message: "Shown to your friends", preferredStyle: .alert)
        a.addTextField { [weak self] tf in
            tf.text = self?.store.d.playerName
            tf.placeholder = "Name"
        }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak a] _ in
            guard let self = self else { return }
            let raw = a?.textFields?.first?.text ?? ""
            let clean = String(raw.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespaces).prefix(14))
            if !clean.isEmpty { self.store.d.playerName = clean; self.store.save() }
            self.showFriends()
        })
        vc.present(a, animated: true)
    }

    func worldCards() -> [Card] {
        let coins = store.d.coins
        return WorldTheme.all.map { (w: WorldTheme) -> Card in
            let icon = SKNode()
            switch w.look {
            case .normal:
                icon.addChild(UIK.label("☾", size: 46, color: Art.rgb(1, 0.95, 0.8), shadow: nil))
            case .halloween:
                let p = SKSpriteNode(texture: Painter.pumpkin(), size: CGSize(width: 64, height: 54))
                icon.addChild(p)
            case .winter:
                icon.addChild(UIK.label("❄︎", size: 46, color: Art.rgb(0.8, 0.92, 1), shadow: nil))
            }
            if !store.ownsWorld(w.id) {
                return Card(title: w.name.uppercased(), icon: icon, desc: w.blurb, price: w.price, buttonText: nil, enabled: coins >= w.price, status: nil,
                            action: { [weak self] in
                                guard let self = self else { return }
                                self.buy(w.price) {
                                    var owned = self.store.d.worldsOwned ?? []
                                    owned.append(w.id)
                                    self.store.d.worldsOwned = owned
                                    self.store.d.world = w.id
                                }
                                self.rebuildForWorld()
                            })
            }
            if store.currentWorld.id == w.id {
                return Card(title: w.name.uppercased(), icon: icon, desc: w.blurb, price: nil, buttonText: nil, enabled: true, status: "SELECTED", action: nil)
            }
            return Card(title: w.name.uppercased(), icon: icon, desc: w.blurb, price: nil, buttonText: "USE", enabled: true, status: nil,
                        action: { [weak self] in
                            guard let self = self else { return }
                            self.store.d.world = w.id
                            self.store.save()
                            self.rebuildForWorld()
                        })
        }
    }

    func rebuildForWorld() {
        setup()
        showStore(.worlds)
    }

    // MARK: - Art templates

    /// Paints every texture once and saves them as PNGs (Documents/art) to use as templates
    /// for replacing the code-drawn art with professional artwork.
    func exportArt() {
        let kinds: [Kind] = [.sheep, .cow, .pig, .grumpa, .farmer, .dog, .fireman, .soldier, .reporter, .hunter, .camel, .bedouin, .citizen]
        for k in kinds { for v in 0..<4 { _ = Art.creature(k, variant: v) } }
        let obs: [ObKind] = [.fence, .shed, .barrels, .car, .police, .jeep, .truck, .windmill, .silo, .house, .fireTruck, .barn, .tank,
                             .powerline, .building, .lamp, .hydrant, .tent, .palm]
        for o in obs { for _ in 0..<5 { _ = Art.obstacle(o) } }
        for t in UFOTheme.all { _ = Art.ufo(theme: t) }
        for p in PowerType.allCases { _ = Art.capsule(p) }
        _ = Painter.heart(); _ = Painter.pumpkin(); _ = Painter.bat(); _ = Painter.duster(); _ = Painter.helicopter()
        _ = Painter.rotor(); _ = Painter.rock(); _ = Painter.puddle(); _ = Painter.dirt(); _ = Painter.signBoard()
        for v in 0..<3 { _ = Painter.tuft(v); _ = Painter.building(v) }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("art")
        let n = Painter.exportAll(to: docs)
        popupHUD("Exported \(n) art templates", color: UIK.yellow)
    }

    // MARK: - Cheat mode

    /// "Suck everything": the beam pulls in everything on screen — coins, animals, people,
    /// power-ups, hearts and even cars and buildings (a few per frame so it stays smooth).
    func cheatVacuum() {
        guard Cheats.vacuum, screen == .playing, status == .play else { return }
        var budget = 4
        func onScreen(_ g: GroundThing) -> Bool {
            let x = sx(g.gx, g.gd)
            return x > -20 && x < W * 0.97
        }
        for c in coins where budget > 0 && !c.lifting && onScreen(c) { startLift(c); budget -= 1 }
        for c in creatures where budget > 0 && !c.lifting && onScreen(c) {
            startLift(c)
            registerGrab(c)
            switch c.kind {
            case .sheep: sound.creature(.sheep)
            case .cow, .camel: sound.creature(.cow)
            case .pig: sound.creature(.pig)
            case .dog: sound.creature(.dog)
            default: sound.creature(.oldMan)
            }
            budget -= 1
        }
        for p in pickups where budget > 0 && !p.lifting && onScreen(p) { startLift(p); budget -= 1 }
        for h in hearts where budget > 0 && !h.lifting && onScreen(h) { startLift(h); budget -= 1 }
        if budget > 0, let o = obstacles.first(where: { !$0.dead && !$0.lifting && $0.kind != .powerline && !$0.giant && onScreen($0) }) {
            startLift(o)
            sound.laserGrab()
        }
    }

    /// MAPS: pick a fixed map, or AUTO (the map changes as you fly).
    func showMaps() {
        screen = .settings
        newOverlay(dim: 0.3)
        let pw = min(W - 40, 620)
        overlay.addChild(UIK.panel(pw, H - 40, y: -6))
        overlay.addChild(UIK.label("MAPS", size: 26, color: UIK.cyan, y: H / 2 - 44))
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in self?.showMenu() }
        let pick = Biome.picked
        let opts: [(Biome?, String, String)] = [
            (nil, "AUTO", "Farm → City → Desert as you fly")
        ] + [Biome.farm, .city, .desert].map { ($0, $0.name, $0.blurb) }
        let cw = min((pw - 50) / 4, 140)
        let ch = min(H * 0.5, 170)
        for (i, o) in opts.enumerated() {
            let x = (CGFloat(i) - 1.5) * (cw + 10)
            let y = H * 0.02
            let sel = o.0 == pick
            let card = SKNode()
            card.position = CGPoint(x: x, y: y)
            card.zPosition = 2
            let frame = SKShapeNode(rectOf: CGSize(width: cw, height: ch), cornerRadius: 12)
            frame.fillColor = sel ? Art.rgb(0.12, 0.4, 0.25) : Art.rgb(0.12, 0.1, 0.25)
            frame.strokeColor = sel ? UIK.green : UIColor(white: 1, alpha: 0.25)
            frame.lineWidth = sel ? 3 : 1.5
            card.addChild(frame)
            // little preview of the ground
            let pv = CGSize(width: cw - 14, height: ch * 0.42)
            let tex: SKTexture
            if let b = o.0 { tex = b == .farm ? Painter.field(pv) : Painter.ground(pv, biome: b) }
            else { tex = Painter.field(pv) }
            let img = SKSpriteNode(texture: tex, size: pv)
            img.position = CGPoint(x: 0, y: ch * 0.2)
            if o.0 == nil {
                // AUTO preview: farm / city / desert in three strips
                img.removeFromParent()
                for (j, b) in [Biome.farm, .city, .desert].enumerated() {
                    let sz = CGSize(width: pv.width / 3, height: pv.height)
                    let t = b == .farm ? Painter.field(sz) : Painter.ground(sz, biome: b)
                    let s = SKSpriteNode(texture: t, size: sz)
                    s.position = CGPoint(x: (CGFloat(j) - 1) * sz.width, y: ch * 0.2)
                    card.addChild(s)
                }
            } else {
                card.addChild(img)
            }
            card.addChild(UIK.label(o.1, size: 15, color: sel ? UIK.green : .white, y: -ch * 0.08))
            let words = o.2.split(separator: " ")
            var lines: [String] = [""]
            for w in words {
                if (lines[lines.count - 1] + " " + w).count > 17 { lines.append(String(w)) }
                else { lines[lines.count - 1] += (lines[lines.count - 1].isEmpty ? "" : " ") + w }
            }
            for (k, l) in lines.prefix(3).enumerated() {
                card.addChild(UIK.label(l, size: 10, color: UIColor(white: 1, alpha: 0.75), y: -ch * 0.2 - CGFloat(k) * 13, shadow: nil))
            }
            overlay.addChild(card)
            addButton(sel ? "✓ SELECTED" : "CHOOSE", x: x, y: y - ch / 2 + 18, w: cw - 20, h: 26,
                      color: sel ? UIK.green : UIK.orange, fontSize: 12) { [weak self] in
                guard let self = self else { return }
                Biome.picked = o.0
                let b = o.0 ?? .farm
                if self.biome != b { self.applyBiome(b, animated: false) }
                self.showMaps()
            }
        }
        overlay.addChild(UIK.label(pick == nil ? "The map changes every 5,000 m" : "Every run stays on \(pick!.name.lowercased())",
                                   size: 12, color: UIColor(white: 1, alpha: 0.6), y: -H / 2 + 30, shadow: nil))
    }

    func showCheats() {
        screen = .settings
        newOverlay(dim: 0.3)
        let pw = min(W - 40, 560)
        overlay.addChild(UIK.panel(pw, H - 40, y: -6))
        overlay.addChild(UIK.label("CHEAT MODE", size: 26, color: UIK.red, y: H / 2 - 44))
        addButton("BACK", x: -W / 2 + 60, y: -H / 2 + 26, w: 100, h: 36, fontSize: 26, plain: true) { [weak self] in self?.showSettings() }
        let on = Cheats.on
        addButton(on ? "CHEATS: ON" : "CHEATS: OFF", x: 0, y: H * 0.25, w: 240, h: 40, color: on ? UIK.red : UIColor(white: 0.4, alpha: 1), fontSize: 18) { [weak self] in
            Cheats.on.toggle()
            self?.showCheats()
        }
        // speed picker
        let sp = Cheats.speed
        let idx = Cheats.speeds.firstIndex(of: sp) ?? 3
        overlay.addChild(UIK.label("Saucer speed  x\(sp == sp.rounded() ? String(Int(sp)) : String(sp))", size: 18, color: on ? .white : UIColor(white: 1, alpha: 0.5), y: H * 0.12))
        addButton("−", x: -110, y: H * 0.12, w: 50, h: 36, fontSize: 24, enabled: idx > 0) { [weak self] in
            Cheats.speed = Cheats.speeds[max(0, idx - 1)]
            self?.showCheats()
        }
        addButton("+", x: 110, y: H * 0.12, w: 50, h: 36, fontSize: 24, enabled: idx < Cheats.speeds.count - 1) { [weak self] in
            Cheats.speed = Cheats.speeds[min(Cheats.speeds.count - 1, idx + 1)]
            self?.showCheats()
        }
        addButton("INFINITE HEALTH: \(Cheats.god ? "ON" : "OFF")", x: 0, y: -H * 0.02, w: 280, h: 36,
                  color: Cheats.god ? UIK.green : UIColor(white: 0.4, alpha: 1), fontSize: 15) { [weak self] in
            Cheats.god.toggle()
            self?.showCheats()
        }
        addButton("SUCK EVERYTHING: \(Cheats.suckAll ? "ON" : "OFF")", x: 0, y: -H * 0.14, w: 280, h: 36,
                  color: Cheats.suckAll ? UIK.green : UIColor(white: 0.4, alpha: 1), fontSize: 15) { [weak self] in
            Cheats.suckAll.toggle()
            self?.showCheats()
        }
        overlay.addChild(UIK.label(on ? "Cheats are active in your next run" : "Turn cheats on to use these", size: 12,
                                   color: UIColor(white: 1, alpha: 0.6), y: -H * 0.27, shadow: nil))
    }
}
