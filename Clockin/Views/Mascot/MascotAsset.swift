import SwiftUI
import UIKit

extension MascotAnimationRate {
    func apply(to animation: CAAnimation) {
        animation.preferredFrameRateRange = CAFrameRateRange(
            minimum: minimum, maximum: maximum, preferred: preferred)
        // Grup ve alt animasyonlar ayni siniri kullanir.
        if let group = animation as? CAAnimationGroup {
            group.animations?.forEach { apply(to: $0) }
        }
    }
}

struct ClockinMascotImage: View {
    let asset: String
    @ObservedObject private var wardrobe = WardrobeStore.shared
    @State private var image: CGImage?

    var body: some View {
        MascotLayerRepresentable(image: image, frameID: asset, outfit: wardrobe.state,
            feet: 0.88, moving: false, swaying: false, angry: false, tired: false,
            hop: .init(id: 0, height: 1), pop: 0, wiggle: 0, squash: 0, dark: false)
            .accessibilityHidden(true)
            .task(id: asset + "/" + wardrobe.state.colorway + "/" + String(WardrobeArt.hidesAntenna(wardrobe.state))) {
                let asset = asset
                let colorway = wardrobe.state.colorway
                let hidingAntenna = WardrobeArt.hidesAntenna(wardrobe.state)
                await MascotFrames.shared.preloadOutfit()
                let decoded = await WardrobeFrameCache.shared.image(asset, colorway: colorway, fixedPose: true, hidingAntenna: hidingAntenna)
                guard !Task.isCancelled else { return }
                image = decoded
            }
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
    @ObservedObject private var celebrations = CelebrationCenter.shared
    @State private var companionID = UUID()
    @State private var lastReaction: MascotReaction?

    @Environment(\.clockinContentActive) private var contentActive
    @State private var appeared = false
    @ObservedObject private var animationPolicy = RollingAnimationPolicy.shared
    private var moving: Bool {
        animationPolicy.allowsAnimation(reduceMotion: reduceMotion, contentActive: contentActive,
                                        sceneActive: scenePhase == .active, visible: appeared)
    }

    var body: some View {
        let mode = CompanionMode.resolve(defaultMode, totalHours: (store.totalDuration + store.elapsed()) / 3600)
        let current = mood(for: mode)
        Group {
            if current == .proud {
                ClockinMotionMascot(mood: .proud)
            } else if moving, let reaction = celebrations.reaction(for: companionID) {
                CelebrationMascot(mood: reaction.mood, reaction: reaction.mascotReaction, moving: true)
                    .id(celebrations.presentationID)
            } else if moving, let tap {
                CelebrationMascot(mood: tap.reaction.mood(from: current ?? .hello) ?? current ?? .hello,
                                  reaction: tap.reaction, moving: true)
                    .id(tap.id)
            } else if let mood = current {
                ClockinMotionMascot(mood: mood, tap: tap)
            } else if let fixed = mode.fixedPoseIndex {
                ClockinMascotImage(asset: "pose\(fixed)")
            }
        }
        .background(CelebrationVisibilityProbe(id: companionID, enabled: moving))
        .contentShape(Rectangle())
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .onTapGesture { react() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state == .celebrate ? "Celebrating focus companion" : "Focus companion")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { react() }
        .task(id: tap) {
            guard tap != nil else { return }
            do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
            tap = nil
        }
        .onChange(of: moving) { _, active in if !active { tap = nil } }
        .onChange(of: state) { _, _ in tap = nil }
        .onChange(of: mode) { _, _ in tap = nil }
    }

    private func mood(for mode: CompanionMode) -> MascotMood? {
        if [.celebrate, .angry, .tired, .proud].contains(state) { return state.mood }
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
        guard moving, celebrations.reserveTap() else { return }
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
    var outfitOverride: WardrobeState? = nil
    private var outfit: WardrobeState { outfitOverride ?? wardrobe.state }
    @ObservedObject private var wardrobe = WardrobeStore.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var frame: String?
    @State private var performingEvent = false
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
        let colorway: String
        let hidingAntenna: Bool
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
    @ObservedObject private var animationPolicy = RollingAnimationPolicy.shared
    private var moving: Bool {
        animationPolicy.allowsAnimation(reduceMotion: reduceMotion, contentActive: contentActive,
                                        sceneActive: scenePhase == .active, visible: appeared)
    }
    private var clips: MascotMoodClips? { MascotFrames.shared.library?[mood] }

    var body: some View {
        MascotLayerRepresentable(
            image: displayedFrame.flatMap { MascotFrames.shared.image($0, colorway: outfit.colorway, hidingAntenna: WardrobeArt.hidesAntenna(outfit)) },
            frameID: displayedFrame, outfit: outfit,
            feet: mood.feet,
            moving: moving,
            swaying: moving && mood != .angry && clips?.standing == true,
            angry: mood == .angry, tired: mood == .tired,
            hop: hop, pop: pop, wiggle: wiggle, squash: squash,
            dark: colorScheme == .dark
        )
        .accessibilityHidden(true)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .task(id: RunKey(mood: mood, moving: moving, lead: leadClip?.id, colorway: outfit.colorway, hidingAntenna: WardrobeArt.hidesAntenna(outfit))) { await run() }
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

    private var displayedFrame: String? {
        guard loadedMood == mood, let rest = clips?.rest else { return nil }
        let current = (moving && frameMood == mood ? frame : nil) ?? rest
        return current
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
        performingEvent = false
        frame = clips.rest
        frameMood = mood
        loadedMood = nil
        await MascotFrames.shared.preload(mood, colorway: outfit.colorway, hidingAntenna: WardrobeArt.hidesAntenna(outfit))
        guard !Task.isCancelled else { return }
        loadedMood = mood
        guard moving else { return }
        var director = MascotDirector(clips, tired: mood == .tired)
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
                performingEvent = true
                startHop(height: mood == .angry ? 0.3 : height)
                do { try await Task.sleep(for: .seconds(MascotMotion.hopDuration(height: height))) } catch { return }
                performingEvent = false
            case .clip(let name):
                if let steps = clips.clips[name] { await play(steps) }
            case nil:
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    private func play(_ steps: [MascotStep]) async {
        performingEvent = true
        defer { performingEvent = false }
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
    let frameID: String?
    let outfit: WardrobeState
    let feet: Double
    let moving: Bool
    let swaying: Bool
    let angry: Bool
    let tired: Bool
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
        view.update(image: image, frameID: frameID, outfit: outfit, feet: feet, moving: moving, swaying: swaying, angry: angry, tired: tired,
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
    private let robot = CALayer()
    private let canvas = CALayer()
    private var overlayLayers: [String: CALayer] = [:]
    private var drawnFrame: String?
    private var drawnEquipment: [String: String] = [:]
    private var feet = 0.88
    private var swaying = false
    private var lastHop: HopRequest?
    private var lastPop = 0
    private var lastWiggle = 0
    private var lastSquash = 0
    private var angry = false
    private var tired = false
    private var swayTask: Task<Void, Never>?
    private var wingTask: Task<Void, Never>?
    private var motionEnabled = false
    private var dark: Bool?
    private var swaySide: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false
        layer.masksToBounds = false
        robot.contentsGravity = .resizeAspect
        robot.minificationFilter = .nearest
        robot.magnificationFilter = .nearest
        canvas.anchorPoint = .zero
        body.addSublayer(canvas)
        canvas.addSublayer(robot)
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

    func update(image: CGImage?, frameID: String?, outfit: WardrobeState, feet: Double, moving: Bool, swaying: Bool, angry: Bool, tired: Bool, hop: HopRequest, pop: Int, wiggle: Int, squash: Int, dark: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let imageChanged = (robot.contents as! CGImage?) !== image
        if imageChanged { robot.contents = image }
        if imageChanged || drawnFrame != frameID || drawnEquipment != outfit.equipped {
            drawnFrame = frameID
            drawnEquipment = outfit.equipped
            let parts = frameID.map { WardrobeArt.overlays(frame: $0, outfit: outfit, images: MascotFrames.shared.overlayImages) } ?? []
            let ids = Set(parts.map(\.id))
            for id in Array(overlayLayers.keys) where !ids.contains(id) {
                overlayLayers.removeValue(forKey: id)?.removeFromSuperlayer()
            }
            for (index, part) in parts.enumerated() {
                let overlay = overlayLayers[part.id] ?? CALayer()
                if overlay.superlayer == nil { canvas.addSublayer(overlay); overlayLayers[part.id] = overlay }
                overlay.anchorPoint = .zero
                overlay.bounds = CGRect(x: 0, y: 0, width: part.image.width, height: part.image.height)
                overlay.position = CGPoint(x: part.origin.x, y: part.origin.y)
                overlay.transform = CATransform3DMakeRotation(part.tilt * .pi / 180, 0, 0, 1)
                overlay.zPosition = CGFloat(part.behind ? -10 + index : 1 + index)
                overlay.contents = part.image
                overlay.minificationFilter = .nearest
                overlay.magnificationFilter = .nearest
                if part.id == "wings" { configureWings(overlay, image: part.image) }
            }
        }
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

        motionEnabled = moving
        updateWingMotion()

        if !moving {
            stopMotion()
            lastHop = hop
            lastPop = pop
            lastWiggle = wiggle
            lastSquash = squash
            return
        }
        let wantsSway = swaying || angry
        if self.angry != angry || self.tired != tired || self.swaying != wantsSway {
            self.angry = angry
            self.tired = tired
            self.swaying = wantsSway
            restartSwayBursts()
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

    deinit { swayTask?.cancel(); wingTask?.cancel() }

    private func configureWings(_ container: CALayer, image: CGImage) {
        container.contents = nil
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let hinge = WardrobeArt.sprites["wings"]?.pivot ?? .init(Double(width / 2), Double(height / 2))
        if container.sublayers?.count != 2 {
            container.sublayers?.forEach { $0.removeFromSuperlayer() }
            container.addSublayer(CALayer())
            container.addSublayer(CALayer())
        }
        for (index, wing) in (container.sublayers ?? []).enumerated() {
            let left = index == 0
            let split = CGFloat(hinge.x)
            wing.bounds = CGRect(x: 0, y: 0, width: left ? split : width - split, height: height)
            wing.anchorPoint = CGPoint(x: left ? 1 : 0, y: CGFloat(hinge.y) / height)
            wing.position = CGPoint(x: hinge.x, y: hinge.y)
            wing.contents = image
            wing.contentsRect = CGRect(x: left ? 0 : split / width, y: 0,
                                       width: (left ? split : width - split) / width, height: 1)
            wing.minificationFilter = .nearest
            wing.magnificationFilter = .nearest
        }
    }

    private func updateWingMotion() {
        guard motionEnabled, window != nil, overlayLayers["wings"] != nil else {
            wingTask?.cancel()
            wingTask = nil
            overlayLayers["wings"]?.sublayers?.forEach { $0.removeAllAnimations() }
            return
        }
        guard wingTask == nil else { return }
        wingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let wings = self?.overlayLayers["wings"]?.sublayers else { return }
                for (index, wing) in wings.enumerated() {
                    let animation = CAKeyframeAnimation(keyPath: "transform")
                    animation.values = MascotMotion.samples(count: 49) { progress in
                        let pose = MascotWingMotion.pose(progress: progress)
                        let rotation = CATransform3DMakeRotation(index == 0 ? pose.radians : -pose.radians, 0, 0, 1)
                        return NSValue(caTransform3D: CATransform3DScale(rotation, pose.scaleX, 1, 1))
                    }
                    animation.duration = MascotWingMotion.duration
                    animation.calculationMode = .linear
                    MascotAnimationRate.sway.apply(to: animation)
                    wing.add(animation, forKey: "wingFlap")
                }
                do { try await Task.sleep(for: .seconds(MascotWingMotion.duration + MascotWingMotion.rest)) }
                catch { return }
            }
        }
    }

    func stopMotion() {
        wingTask?.cancel()
        wingTask = nil
        overlayLayers["wings"]?.sublayers?.forEach { $0.removeAllAnimations() }
        swayTask?.cancel()
        swayTask = nil
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
        canvas.bounds = CGRect(x: 0, y: 0, width: 314, height: 314)
        canvas.position = .zero
        canvas.transform = CATransform3DMakeScale(side / 314, side / 314, 1)
        robot.frame = CGRect(x: 0, y: 0, width: 314, height: 314)
        body.position = CGPoint(x: square.width / 2, y: square.height * anchor.y)
        shadowLayer.bounds = CGRect(x: 0, y: 0, width: side * 0.38, height: side * 0.04)
        shadowLayer.position = CGPoint(x: square.width / 2, y: square.height * anchor.y)
        CATransaction.commit()
        if swaying, side != swaySide { restartSwayBursts() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        let scale = traitCollection.displayScale
        [rig, shadowLayer, sway, popLayer, reactLayer, body].forEach { $0.contentsScale = scale }
        if window == nil { stopMotion() }
        else { updateWingMotion() }
    }

    private func restartSwayBursts() {
        swayTask?.cancel()
        swayTask = nil
        sway.removeAllAnimations()
        swaySide = min(bounds.width, bounds.height)
        guard swaying, swaySide > 0 else { return }
        let schedule = MascotSwaySchedule.schedule(for: angry ? .angry : (tired ? .tired : .hello))
        // Sonlu CA kendiliginden biter; dinlenmede katmanda animasyon kalmaz.
        swayTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                self?.playSwayBurst(schedule)
                do { try await Task.sleep(for: .seconds(schedule.cycle)) } catch { return }
            }
        }
    }

    private func playSwayBurst(_ schedule: MascotSwaySchedule) {
        guard window != nil, swaying else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = MascotMotion.samples(count: 61) { progress in
            if angry {
                let shake = MascotMotion.wiggle(progress: progress) * schedule.amplitude
                return NSValue(caTransform3D: CATransform3DMakeRotation(shake * .pi / 180, 0, 0, 1))
            }
            let pose = MascotMotion.sway(time: progress * MascotMotion.swayPeriod)
            return NSValue(caTransform3D: CATransform3DRotate(
                CATransform3DMakeTranslation(0, pose.offsetY * swaySide * schedule.amplitude, 0),
                pose.rotationDegrees * schedule.amplitude * .pi / 180, 0, 0, 1))
        }
        animation.duration = schedule.active
        animation.calculationMode = .linear
        (angry ? MascotAnimationRate.reaction : .sway).apply(to: animation)
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
        MascotAnimationRate.reaction.apply(to: bodyAnimation)
        body.add(bodyAnimation, forKey: "hop")
        let shadowAnimation = CAKeyframeAnimation(keyPath: "transform")
        shadowAnimation.values = poses.map { NSValue(caTransform3D: CATransform3DMakeScale($0.shadowScaleX, $0.shadowScaleY, 1)) }
        shadowAnimation.duration = duration
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = poses.map { NSNumber(value: $0.shadowOpacity) }
        fade.duration = duration
        MascotAnimationRate.reaction.apply(to: shadowAnimation)
        MascotAnimationRate.reaction.apply(to: fade)
        shadowLayer.add(shadowAnimation, forKey: "hop")
        shadowLayer.add(fade, forKey: "hopFade")
    }

    private func playReaction(duration: Double, _ transform: (Double) -> CATransform3D) {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = MascotMotion.samples(count: max(2, Int(duration * 120))) { NSValue(caTransform3D: transform($0)) }
        animation.duration = duration
        MascotAnimationRate.reaction.apply(to: animation)
        reactLayer.add(animation, forKey: "reaction")
    }

    private func playPop() {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = MascotMotion.samples(count: 40) { progress in
            let scale = MascotMotion.pop(progress: progress)
            return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1))
        }
        animation.duration = MascotMotion.popDuration
        MascotAnimationRate.reaction.apply(to: animation)
        popLayer.add(animation, forKey: "pop")
    }

}
