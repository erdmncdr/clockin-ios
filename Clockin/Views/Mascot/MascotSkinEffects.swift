#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// The light a skin adds round the companion: a soft glow behind it, a sheen
/// that sweeps across its armour every few seconds and a few particles of its
/// aura. All three live in the mascot's 314-point canvas, so they scale, hop
/// and sway with it, and they stop with the rest of its motion.
@MainActor
final class MascotSkinEffects {
    private let glow = CAGradientLayer()
    private let sheen = CAGradientLayer()
    private let sheenMask = CALayer()
    private let aura = CAEmitterLayer()
    private var effects: WardrobeSkinEffects?
    private var moving = false

    init() {
        glow.type = .radial
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.frame = CGRect(x: 157 - 135, y: 172 - 135, width: 270, height: 270)
        glow.zPosition = -40
        // A band across the figure from upper left to lower right, masked to
        // the robot's own pixels so only the armour catches it.
        sheen.frame = CGRect(x: 0, y: 0, width: 314, height: 314)
        sheen.startPoint = CGPoint(x: 0, y: 0.15)
        sheen.endPoint = CGPoint(x: 1, y: 0.85)
        sheen.locations = [-0.3, -0.2, -0.1]
        sheen.zPosition = 30
        sheenMask.frame = sheen.bounds
        sheenMask.contentsGravity = .resizeAspect
        sheenMask.minificationFilter = .nearest
        sheenMask.magnificationFilter = .nearest
        sheen.mask = sheenMask
        aura.frame = CGRect(x: 0, y: 0, width: 314, height: 314)
        aura.zPosition = 50
        aura.renderMode = .unordered
        aura.birthRate = 0
        for layer in [glow, sheen, aura] as [CALayer] { layer.isHidden = true }
    }

    func install(in canvas: CALayer) {
        for layer in [glow, sheen, aura] as [CALayer] where layer.superlayer == nil { canvas.addSublayer(layer) }
    }

    /// The robot's current frame, whose pixels the sheen is masked to.
    func mask(_ image: CGImage?) {
        if (sheenMask.contents as! CGImage?) !== image { sheenMask.contents = image }
    }

    func update(_ effects: WardrobeSkinEffects?, moving: Bool) {
        let changed = effects != self.effects
        guard changed || moving != self.moving else { return }
        self.effects = effects
        self.moving = moving
        guard let effects else {
            for layer in [glow, sheen, aura] as [CALayer] { layer.isHidden = true; layer.removeAllAnimations() }
            aura.birthRate = 0
            aura.emitterCells = nil
            return
        }
        if changed {
            let light = Self.color(effects.glow)
            glow.colors = [light.withAlphaComponent(0.42).cgColor, light.withAlphaComponent(0.14).cgColor, light.withAlphaComponent(0).cgColor]
            glow.locations = [0, 0.45, 1]
            let shine = Self.color(effects.sheen)
            sheen.colors = [shine.withAlphaComponent(0).cgColor, shine.withAlphaComponent(0.7).cgColor, shine.withAlphaComponent(0).cgColor]
            aura.emitterCells = Self.cells(for: effects)
            Self.shape(aura, for: effects.aura)
        }
        glow.isHidden = false
        sheen.isHidden = !moving
        aura.isHidden = !moving
        // Particles already in the air finish their lives when motion stops.
        aura.birthRate = moving ? 1 : 0
        if moving { animate() } else { [glow, sheen].forEach { $0.removeAllAnimations() } }
    }

    /// Stops the motion and the particles, keeping the still glow.
    func stop() { update(effects, moving: false) }

    private func animate() {
        if glow.animation(forKey: "breathe") == nil {
            let breathe = CABasicAnimation(keyPath: "opacity")
            breathe.fromValue = 0.7
            breathe.toValue = 1
            breathe.duration = 2.4
            breathe.autoreverses = true
            breathe.repeatCount = .infinity
            breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            MascotAnimationRate.sway.apply(to: breathe)
            glow.add(breathe, forKey: "breathe")
        }
        if sheen.animation(forKey: "sweep") == nil {
            // One pass of about a second, then a rest, like light turning on metal.
            let sweep = CABasicAnimation(keyPath: "locations")
            sweep.fromValue = [-0.3, -0.2, -0.1]
            sweep.toValue = [1.1, 1.2, 1.3]
            sweep.duration = 1.1
            sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            let cycle = CAAnimationGroup()
            cycle.animations = [sweep]
            cycle.duration = 5.2
            cycle.repeatCount = .infinity
            cycle.beginTime = CACurrentMediaTime() + 1.2
            MascotAnimationRate.sway.apply(to: cycle)
            sheen.add(cycle, forKey: "sweep")
        }
    }

    // MARK: Aura

    private static func shape(_ aura: CAEmitterLayer, for kind: String) {
        switch kind {
        case "embers", "sparks":
            // Rising off the ground round the feet.
            aura.emitterShape = .line
            aura.emitterPosition = CGPoint(x: 157, y: 280)
            aura.emitterSize = CGSize(width: 180, height: 0)
        case "feathers":
            // Drifting down from above the shoulders.
            aura.emitterShape = .line
            aura.emitterPosition = CGPoint(x: 157, y: 60)
            aura.emitterSize = CGSize(width: 230, height: 0)
        default:
            aura.emitterShape = .rectangle
            aura.emitterPosition = CGPoint(x: 157, y: 165)
            aura.emitterSize = CGSize(width: 250, height: 240)
        }
    }

    private static func cells(for effects: WardrobeSkinEffects) -> [CAEmitterCell] {
        let colors = effects.auraColors.isEmpty ? [effects.glow] : effects.auraColors
        return colors.enumerated().map { index, hex in
            let cell = CAEmitterCell()
            cell.contents = sprite(effects.aura)
            cell.color = color(hex).cgColor
            cell.minificationFilter = CALayerContentsFilter.nearest.rawValue
            cell.magnificationFilter = CALayerContentsFilter.nearest.rawValue
            let share = Float(colors.count)
            switch effects.aura {
            case "embers":
                cell.birthRate = 5 / share
                cell.lifetime = 3.2; cell.lifetimeRange = 1
                cell.velocity = 34; cell.velocityRange = 14
                cell.emissionLongitude = -.pi / 2; cell.emissionRange = .pi / 7
                cell.yAcceleration = -6
                cell.alphaSpeed = -0.28
                cell.scale = 1; cell.scaleRange = 0.35; cell.scaleSpeed = -0.12
            case "sparks":
                cell.birthRate = 7 / share
                cell.lifetime = 0.9; cell.lifetimeRange = 0.4
                cell.velocity = 70; cell.velocityRange = 40
                cell.emissionLongitude = -.pi / 2; cell.emissionRange = .pi / 3
                cell.yAcceleration = 60
                cell.alphaSpeed = -0.9
                cell.spin = 3; cell.spinRange = 6
                cell.scale = 0.9; cell.scaleRange = 0.3
            case "stars":
                cell.birthRate = 3 / share
                cell.lifetime = 1.8; cell.lifetimeRange = 0.6
                cell.velocity = 4; cell.velocityRange = 3
                cell.alphaRange = 0.2; cell.alphaSpeed = -0.5
                cell.scale = 1; cell.scaleRange = 0.4; cell.scaleSpeed = -0.35
            case "feathers":
                cell.birthRate = 1.6 / share
                cell.lifetime = 4.5; cell.lifetimeRange = 1
                cell.velocity = 16; cell.velocityRange = 6
                cell.emissionLongitude = .pi / 2; cell.emissionRange = .pi / 6
                cell.alphaSpeed = -0.2
                cell.spin = 0.6; cell.spinRange = 1.4
                cell.scale = 1; cell.scaleRange = 0.25
            default: // motes
                cell.birthRate = 3.5 / share
                cell.lifetime = 3.6; cell.lifetimeRange = 1
                cell.velocity = 9; cell.velocityRange = 6
                cell.emissionLongitude = -.pi / 2; cell.emissionRange = .pi
                cell.yAcceleration = -3
                cell.alphaSpeed = -0.26
                cell.scale = 1; cell.scaleRange = 0.4
            }
            // Stagger the colours so they do not start in step.
            cell.beginTime = Double(index) * 0.37
            return cell
        }
    }

    /// White pixel sprites in the robot's 2-point cells; each emitter cell
    /// tints its own copy.
    private static func sprite(_ kind: String) -> CGImage? {
        let rows: [String] = switch kind {
        case "stars": ["..#..", "..#..", "#####", "..#..", "..#.."]
        case "sparks": ["#.", "##", ".#"]
        case "feathers": ["..#", ".##", ".##", "##.", "#.."]
        case "motes": [".#.", "###", ".#."]
        default: ["##", "##"]
        }
        let cell = 2, width = rows[0].count * cell, height = rows.count * cell
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(PlatformColor.white.cgColor)
        for (y, row) in rows.enumerated() {
            for (x, mark) in row.enumerated() where mark == "#" {
                context.fill(CGRect(x: x * cell, y: height - (y + 1) * cell, width: cell, height: cell))
            }
        }
        return context.makeImage()
    }

    private static func color(_ hex: String) -> PlatformColor {
        guard let value = WardrobePalette.rgb(hex) else { return .white }
        return PlatformColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}
