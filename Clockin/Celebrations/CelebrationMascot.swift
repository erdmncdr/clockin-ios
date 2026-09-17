import SwiftUI
import UIKit

extension CelebrationReaction {
    var mascotReaction: MascotReaction {
        switch self {
        case .dailyGoal, .streak: .cheer
        case .moneyMilestone: .wiggle
        case .clockIn: .squash
        case .pause: .busy
        case .clockOut: .wave
        }
    }

    var mood: MascotMood {
        switch self {
        case .dailyGoal, .streak: .celebrate
        case .pause: .coffee
        case .moneyMilestone, .clockIn, .clockOut: .hello
        }
    }
}

struct CelebrationMascot: View {
    let mood: MascotMood
    let reaction: MascotReaction
    let moving: Bool
    @State private var loaded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.clockinContentActive) private var contentActive
    @ObservedObject private var animationPolicy = RollingAnimationPolicy.shared

    var body: some View {
        CelebrationMascotRenderer(mood: mood, reaction: reaction, moving: moving && loaded && animationPolicy.allowsAnimation(
            reduceMotion: reduceMotion, contentActive: contentActive, sceneActive: scenePhase == .active, visible: true),
            loaded: loaded)
            .accessibilityHidden(true)
            .task(id: mood) {
                loaded = false
                await MascotFrames.shared.preload(mood)
                guard !Task.isCancelled else { return }
                loaded = true
            }
    }
}

private struct CelebrationMascotRenderer: UIViewRepresentable {
    let mood: MascotMood
    let reaction: MascotReaction
    let moving: Bool
    let loaded: Bool

    func makeUIView(context: Context) -> CelebrationMascotLayerView { CelebrationMascotLayerView() }
    func updateUIView(_ view: CelebrationMascotLayerView, context: Context) {
        view.configure(mood: mood, reaction: reaction, moving: moving, loaded: loaded)
    }
    static func dismantleUIView(_ view: CelebrationMascotLayerView, coordinator: ()) { view.stop() }
}

final class CelebrationMascotLayerView: UIView {
    private let drawing = CALayer()
    private var mood: MascotMood = .hello
    private var reaction: MascotReaction = .wave
    private var moving = false
    private var loaded = false
    private var played = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        drawing.contentsGravity = .resizeAspect
        drawing.magnificationFilter = .nearest
        drawing.minificationFilter = .nearest
        layer.addSublayer(drawing)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(mood: MascotMood, reaction: MascotReaction, moving: Bool, loaded: Bool) {
        if self.mood != mood || self.reaction != reaction { stop(); played = false }
        self.mood = mood
        self.reaction = reaction
        self.moving = moving
        self.loaded = loaded
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        drawing.contents = loaded ? (MascotFrames.shared.library?[mood].rest).flatMap { MascotFrames.shared.image($0) } : nil
        CATransaction.commit()
        if !moving { stop() }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        drawing.anchorPoint = CGPoint(x: 0.5, y: mood.feet)
        drawing.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        drawing.position = CGPoint(x: bounds.midX, y: bounds.midY + (mood.feet - 0.5) * side)
        CATransaction.commit()
        guard window != nil, side > 0, moving, loaded, !played else { return }
        played = true
        play(side: side)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() } else { setNeedsLayout() }
    }

    func stop() { drawing.removeAllAnimations() }

    private func play(side: CGFloat) {
        guard let clips = MascotFrames.shared.library?[mood] else { return }
        var random = SystemRandomNumberGenerator()
        if let name = reaction.clip(in: mood, clips: clips, using: &random), let steps = clips.clips[name] {
            let total = Double(steps.reduce(0) { $0 + $1.milliseconds }) / 1000
            var elapsed = 0.0
            var images: [CGImage] = []
            var times: [NSNumber] = []
            for step in steps {
                if let image = MascotFrames.shared.image(step.frame) {
                    images.append(image)
                    times.append(NSNumber(value: total > 0 ? min(1, elapsed / total) : 0))
                }
                elapsed += Double(step.milliseconds) / 1000
            }
            if images.count > 1, total > 0 {
                let animation = CAKeyframeAnimation(keyPath: "contents")
                animation.values = images
                animation.keyTimes = times
                animation.calculationMode = .discrete
                animation.duration = total
                drawing.add(animation, forKey: "clip")
            }
        }
        let duration: Double
        switch reaction.motion {
        case .hop(let height): duration = MascotMotion.hopDuration(height: height)
        case .doubleHop: duration = 1.6
        case .wiggle: duration = MascotMotion.wiggleDuration
        case .squash: duration = MascotMotion.squashDuration
        }
        let motion = CAKeyframeAnimation(keyPath: "transform")
        motion.values = MascotMotion.samples(count: 90) { progress in
            switch reaction.motion {
            case .hop(let height):
                let pose = MascotMotion.hop(progress: progress, height: height)
                return NSValue(caTransform3D: CATransform3DScale(CATransform3DMakeTranslation(0, pose.offsetY * side, 0), pose.scaleX, pose.scaleY, 1))
            case .doubleHop:
                let pose = MascotMotion.hop(progress: (progress * 2).truncatingRemainder(dividingBy: 1), height: 0.75)
                return NSValue(caTransform3D: CATransform3DScale(CATransform3DMakeTranslation(0, pose.offsetY * side, 0), pose.scaleX, pose.scaleY, 1))
            case .wiggle:
                return NSValue(caTransform3D: CATransform3DMakeRotation(MascotMotion.wiggle(progress: progress) * .pi / 180, 0, 0, 1))
            case .squash:
                let scale = MascotMotion.squash(progress: progress)
                return NSValue(caTransform3D: CATransform3DMakeScale(scale.scaleX, scale.scaleY, 1))
            }
        }
        motion.duration = duration
        drawing.add(motion, forKey: "reaction")
    }
}
