import SwiftUI
import UIKit

struct ClockinMascotImage: View {
    let asset: String

    var body: some View {
        Image(asset).resizable().interpolation(.none).scaledToFit()
            .accessibilityHidden(true)
    }
}

@MainActor
struct ClockinMascotStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: ClockStore
    @AppStorage("Clockin.MascotDefault") private var defaultMode = "Auto"
    let state: MascotAsset
    @State private var tap: MascotTap?
    @State private var reactionMood: MascotMood?
    @State private var lastReaction: MascotReaction?

    @Environment(\.clockinContentActive) private var contentActive
    @State private var appeared = false
    private var moving: Bool { appeared && contentActive && !reduceMotion && scenePhase == .active }

    private struct ReactionKey: Equatable {
        let tap: MascotTap?
        let moving: Bool
        let state: MascotAsset
        let mode: CompanionMode
    }

    var body: some View {
        let mode = CompanionMode.resolve(defaultMode, totalHours: (store.totalDuration + store.elapsed()) / 3600)
        let current = mood(for: mode)
        Group {
            if let mood = (moving ? reactionMood : nil) ?? current {
                ClockinMotionMascot(mood: mood, tap: tap)
            } else if let fixed = mode.fixedPoseIndex {
                ClockinMascotImage(asset: "pose\(fixed)")
            }
        }
        .contentShape(Rectangle())
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .onTapGesture { react() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state == .celebrate ? "Celebrating focus companion" : "Focus companion")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { react() }
        .task(id: ReactionKey(tap: tap, moving: moving, state: state, mode: mode)) {
            guard moving, let tap else { reactionMood = nil; return }
            if current == nil && reactionMood == nil { reactionMood = .hello }
            do {
                if let next = tap.reaction.mood(from: reactionMood ?? current ?? .hello) {
                    try await Task.sleep(for: .milliseconds(330))
                    reactionMood = next
                    try await Task.sleep(for: .seconds(3.2))
                } else {
                    try await Task.sleep(for: .seconds(1.6))
                }
            } catch { return }
            reactionMood = nil
        }
        .onChange(of: moving) { _, active in
            if !active { tap = nil; reactionMood = nil }
        }
        .onChange(of: state) { _, _ in tap = nil; reactionMood = nil }
        .onChange(of: mode) { _, _ in tap = nil; reactionMood = nil }
    }

    private func mood(for mode: CompanionMode) -> MascotMood? {
        if state == .celebrate || state == .angry { return state.mood }
        switch mode {
        case .auto: return state.mood
        case .typing: return .working
        case .coffee: return .coffee
        case .victory: return .celebrate
        case .stretch, .dance, .music: return nil
        }
    }

    private func react() {
        guard appeared, contentActive, scenePhase == .active else { return }
        Haptics.play(.companionReaction)
        guard moving else { return }
        var random = SystemRandomNumberGenerator()
        let reaction = MascotReaction.pick(after: lastReaction, using: &random)
        lastReaction = reaction
        tap = MascotTap(id: (tap?.id ?? 0) + 1, reaction: reaction)
    }
}

struct MascotTap: Equatable {
    let id: Int
    let reaction: MascotReaction
}

@MainActor
struct ClockinMotionMascot: View {
    let mood: MascotMood
    var tap: MascotTap?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var frame: String?
    @State private var hop = MascotLayerView.HopRequest(id: 0, height: 1)
    @State private var hopUntil = Date.distantPast
    @State private var pop = 0
    @State private var wiggle = 0
    @State private var squash = 0
    @State private var leadClip: LeadClip?
    @State private var clipAfterPoseChange: MascotTap?
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadedMood: MascotMood?
    @State private var frameMood: MascotMood?

    private struct RunKey: Equatable {
        let mood: MascotMood
        let moving: Bool
        let lead: Int?
    }

    private struct ReactionKey: Equatable {
        let tap: MascotTap?
        let moving: Bool
    }

    private struct LeadClip: Equatable {
        let id: Int
        let name: String
    }

    @Environment(\.clockinContentActive) private var contentActive
    @State private var appeared = false
    private var moving: Bool { appeared && contentActive && !reduceMotion && scenePhase == .active }
    private var clips: MascotMoodClips? { MascotFrames.shared.library?[mood] }

    var body: some View {
        MascotLayerRepresentable(
            image: loadedMood == mood ? ((moving && frameMood == mood ? frame : nil) ?? clips?.rest)
                .flatMap { MascotFrames.shared.image($0) } : nil,
            feet: mood.feet,
            moving: moving,
            swaying: moving && mood != .angry && clips?.standing == true,
            angry: mood == .angry,
            hop: hop, pop: pop, wiggle: wiggle, squash: squash,
            dark: colorScheme == .dark
        )
        .accessibilityHidden(true)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .task(id: RunKey(mood: mood, moving: moving, lead: leadClip?.id)) { await run() }
        .onChange(of: mood) { _, newMood in
            if moving { pop += 1 }
            if let waiting = clipAfterPoseChange {
                clipAfterPoseChange = nil
                queueClip(for: waiting, in: newMood)
            }
        }
        .onChange(of: tap, initial: true) { _, tap in
            guard moving, let tap else { return }
            switch tap.reaction.motion {
            case .hop(let height): startHop(height: height, force: true)
            case .doubleHop: startHop(height: 0.75, force: true)
            case .wiggle: wiggle += 1
            case .squash: squash += 1
            }
            if let next = tap.reaction.mood(from: mood), next != mood {
                clipAfterPoseChange = tap
            } else {
                clipAfterPoseChange = nil
                queueClip(for: tap, in: mood)
            }
        }
        .task(id: ReactionKey(tap: tap, moving: moving)) {
            guard moving, let tap, tap.reaction.motion == .doubleHop else { return }
            do { try await Task.sleep(for: .seconds(MascotMotion.hopDuration(height: 0.75) * 0.92)) } catch { return }
            startHop(height: 0.95, force: true)
        }
    }

    private func queueClip(for tap: MascotTap, in mood: MascotMood) {
        guard moving, let clips = MascotFrames.shared.library?[mood] else { return }
        var random = SystemRandomNumberGenerator()
        guard let name = tap.reaction.clip(in: mood, clips: clips, using: &random) else { return }
        leadClip = LeadClip(id: tap.id, name: name)
    }

    private func startHop(height: Double, force: Bool = false) {
        guard moving, !Task.isCancelled, force || Date() >= hopUntil else { return }
        hopUntil = Date().addingTimeInterval(MascotMotion.hopDuration(height: height))
        hop = MascotLayerView.HopRequest(id: hop.id + 1, height: height)
    }

    private func run() async {
        guard let clips else { return }
        frame = clips.rest
        frameMood = mood
        await MascotFrames.shared.preload(mood)
        guard !Task.isCancelled else { return }
        loadedMood = mood
        guard moving else { return }
        var director = MascotDirector(clips)
        var random = SystemRandomNumberGenerator()
        if let lead = leadClip, let steps = clips.clips[lead.name] {
            await play(steps)
            if Task.isCancelled { return }
        }
        while !Task.isCancelled {
            if let base = clips.base {
                await play(base)
            } else {
                do { try await Task.sleep(for: .seconds(director.restDelay(using: &random))) } catch { return }
            }
            if Task.isCancelled || director.skipsEvent(using: &random) { continue }
            switch director.next(using: &random) {
            case .hop(let height):
                startHop(height: mood == .angry ? 0.3 : height)
                do { try await Task.sleep(for: .seconds(MascotMotion.hopDuration(height: height))) } catch { return }
            case .clip(let name):
                if let steps = clips.clips[name] { await play(steps) }
            case nil:
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    private func play(_ steps: [MascotStep]) async {
        for step in steps {
            guard !Task.isCancelled else { return }
            frame = step.frame
            guard step.milliseconds > 0 else { continue }
            do { try await Task.sleep(for: .milliseconds(step.milliseconds)) } catch { return }
        }
    }
}

private struct MascotLayerRepresentable: UIViewRepresentable {
    let image: CGImage?
    let feet: Double
    let moving: Bool
    let swaying: Bool
    let angry: Bool
    let hop: MascotLayerView.HopRequest
    let pop: Int
    let wiggle: Int
    let squash: Int
    let dark: Bool

    func makeUIView(context: Context) -> MascotLayerView {
        let view = MascotLayerView(frame: .zero)
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: MascotLayerView, context: Context) {
        view.update(image: image, feet: feet, moving: moving, swaying: swaying, angry: angry,
                    hop: hop, pop: pop, wiggle: wiggle, squash: squash, dark: dark)
    }

    static func dismantleUIView(_ view: MascotLayerView, coordinator: ()) {
        view.stopMotion()
    }
}

final class MascotLayerView: UIView {
    struct HopRequest: Equatable {
        let id: Int
        let height: Double
    }


    private let rig = CALayer()
    private let shadowLayer = CAGradientLayer()
    private let sway = CALayer()
    private let popLayer = CALayer()
    private let reactLayer = CALayer()
    private let body = CALayer()
    private var feet = 0.88
    private var swaying = false
    private var lastHop: HopRequest?
    private var lastPop = 0
    private var lastWiggle = 0
    private var lastSquash = 0
    private var angry = false
    private var dark: Bool?
    private var swaySide: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false
        layer.masksToBounds = false
        body.contentsGravity = .resizeAspect
        body.minificationFilter = .nearest
        body.magnificationFilter = .nearest
        shadowLayer.type = .radial
        shadowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        shadowLayer.endPoint = CGPoint(x: 1, y: 1)
        reactLayer.addSublayer(body)
        popLayer.addSublayer(reactLayer)
        sway.addSublayer(popLayer)
        rig.addSublayer(shadowLayer)
        rig.addSublayer(sway)
        layer.addSublayer(rig)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(image: CGImage?, feet: Double, moving: Bool, swaying: Bool, angry: Bool, hop: HopRequest, pop: Int, wiggle: Int, squash: Int, dark: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if (body.contents as! CGImage?) !== image { body.contents = image }
        if self.feet != feet {
            self.feet = feet
            setNeedsLayout()
        }
        if self.dark != dark {
            self.dark = dark
            let tint = dark ? UIColor.black.withAlphaComponent(0.55) : UIColor(red: 23 / 255, green: 34 / 255, blue: 55 / 255, alpha: 0.24)
            shadowLayer.colors = [tint.cgColor, tint.withAlphaComponent(0).cgColor]
        }
        CATransaction.commit()

        if !moving {
            stopMotion()
            lastHop = hop
            lastPop = pop
            lastWiggle = wiggle
            lastSquash = squash
            return
        }
        if self.angry != angry {
            self.angry = angry
            sway.removeAllAnimations()
        }
        if angry, sway.animation(forKey: "angry") == nil { startAngry() }
        if self.swaying != swaying {
            self.swaying = swaying
            if swaying { startSway() } else { sway.removeAnimation(forKey: "sway") }
        }
        if lastHop == nil {
            lastHop = hop
        } else if lastHop != hop {
            lastHop = hop
            playHop(height: hop.height)
        }
        if pop != lastPop {
            lastPop = pop
            playPop()
        }
        if wiggle != lastWiggle {
            lastWiggle = wiggle
            playReaction(duration: MascotMotion.wiggleDuration) { progress in
                CATransform3DMakeRotation(MascotMotion.wiggle(progress: progress) * .pi / 180, 0, 0, 1)
            }
        }
        if squash != lastSquash {
            lastSquash = squash
            playReaction(duration: MascotMotion.squashDuration) { progress in
                let scale = MascotMotion.squash(progress: progress)
                return CATransform3DMakeScale(scale.scaleX, scale.scaleY, 1)
            }
        }
    }

    func stopMotion() {
        swaying = false
        angry = false
        [rig, shadowLayer, sway, popLayer, reactLayer, body].forEach { $0.removeAllAnimations() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = min(bounds.width, bounds.height)
        let square = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        // UIKit koordinatlarinda ayak noktasi ustten olculur.
        let anchor = CGPoint(x: 0.5, y: feet)
        for layer in [rig, sway, popLayer, reactLayer] {
            layer.anchorPoint = anchor
            layer.bounds = CGRect(origin: .zero, size: square.size)
            layer.position = CGPoint(x: square.midX - square.minX, y: square.height * anchor.y)
        }
        rig.position = CGPoint(x: square.midX, y: square.minY + square.height * anchor.y)
        body.anchorPoint = anchor
        body.bounds = CGRect(origin: .zero, size: square.size)
        body.position = CGPoint(x: square.width / 2, y: square.height * anchor.y)
        shadowLayer.bounds = CGRect(x: 0, y: 0, width: side * 0.38, height: side * 0.04)
        shadowLayer.position = CGPoint(x: square.width / 2, y: square.height * anchor.y)
        CATransaction.commit()
        if swaying, side != swaySide { startSway() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        let scale = traitCollection.displayScale
        [rig, shadowLayer, sway, popLayer, reactLayer, body].forEach { $0.contentsScale = scale }
        if window == nil { stopMotion() }
    }

    private func startAngry() {
        // Kisa titreme ve bekleme render sunucusunda tekrar eder.
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = MascotMotion.samples(count: 121) { progress in
            let shake = progress < 0.3 ? MascotMotion.wiggle(progress: progress / 0.3) * 0.45 : 0
            return NSValue(caTransform3D: CATransform3DMakeRotation(shake * .pi / 180, 0, 0, 1))
        }
        animation.duration = 2.2
        animation.repeatCount = .infinity
        sway.add(animation, forKey: "angry")
    }

    private func startSway() {
        let side = min(bounds.width, bounds.height)
        swaySide = side
        guard side > 0 else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = MascotMotion.samples(count: 61) { progress in
            let pose = MascotMotion.sway(time: progress * MascotMotion.swayPeriod)
            return NSValue(caTransform3D: CATransform3DRotate(CATransform3DMakeTranslation(0, pose.offsetY * side, 0),
                                                              pose.rotationDegrees * .pi / 180, 0, 0, 1))
        }
        animation.duration = MascotMotion.swayPeriod
        animation.repeatCount = .infinity
        animation.calculationMode = .linear
        animation.beginTime = CACurrentMediaTime()
        sway.add(animation, forKey: "sway")
    }

    private func playHop(height: Double) {
        let side = min(bounds.width, bounds.height)
        let duration = MascotMotion.hopDuration(height: height)
        let count = max(2, Int(duration * 120))
        let poses = MascotMotion.samples(count: count) { MascotMotion.hop(progress: $0, height: height) }
        let bodyAnimation = CAKeyframeAnimation(keyPath: "transform")
        bodyAnimation.values = poses.map { pose in
            NSValue(caTransform3D: CATransform3DScale(CATransform3DMakeTranslation(0, pose.offsetY * side, 0), pose.scaleX, pose.scaleY, 1))
        }
        bodyAnimation.duration = duration
        body.add(bodyAnimation, forKey: "hop")
        let shadowAnimation = CAKeyframeAnimation(keyPath: "transform")
        shadowAnimation.values = poses.map { NSValue(caTransform3D: CATransform3DMakeScale($0.shadowScaleX, $0.shadowScaleY, 1)) }
        shadowAnimation.duration = duration
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = poses.map { NSNumber(value: $0.shadowOpacity) }
        fade.duration = duration
        shadowLayer.add(shadowAnimation, forKey: "hop")
        shadowLayer.add(fade, forKey: "hopFade")
    }

    private func playReaction(duration: Double, _ transform: (Double) -> CATransform3D) {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = MascotMotion.samples(count: max(2, Int(duration * 120))) { NSValue(caTransform3D: transform($0)) }
        animation.duration = duration
        reactLayer.add(animation, forKey: "reaction")
    }

    private func playPop() {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = MascotMotion.samples(count: 40) { progress in
            let scale = MascotMotion.pop(progress: progress)
            return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1))
        }
        animation.duration = MascotMotion.popDuration
        popLayer.add(animation, forKey: "pop")
    }

}
