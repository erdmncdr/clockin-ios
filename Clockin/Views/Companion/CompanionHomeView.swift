import SwiftUI

struct CompanionHomeView: View {
    var reaction: MascotTap? = nil
    var outfitCloseup = false
    var stateOverride: WardrobeState? = nil
    var activityOverride: CompanionHomeActivity? = nil
    var lightOverride: CompanionHomeLight? = nil
    @ObservedObject private var wardrobe = WardrobeStore.shared
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var celebrations = CelebrationCenter.shared
    @ObservedObject private var nudges = NudgeController.shared
    @ObservedObject private var animationPolicy = RollingAnimationPolicy.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.clockinContentActive) private var contentActive
    @AppStorage(NudgePlanner.toneKey) private var tone = NudgeTone.grumpy.rawValue
    @AppStorage("Clockin.MascotEnabled") private var enabled = true
    @State private var images: [String: CGImage] = [:]
    @State private var appeared = false
    @State private var now = Date.now

    private var state: WardrobeState { stateOverride ?? wardrobe.state }
    private var mood: MascotMood {
        celebrations.companionState(running: store.running, angry: nudges.mood?.isAngry == true,
                                    friendly: tone == NudgeTone.friendly.rawValue).mood
    }
    private var activity: CompanionHomeActivity {
        activityOverride ?? .resolve(working: store.running?.isPaused == false, paused: store.running?.isPaused == true,
                                    elapsed: store.running?.elapsed(at: now) ?? 0, tired: mood == .tired,
                                    furniture: state.furniture)
    }
    private var moving: Bool {
        animationPolicy.allowsAnimation(reduceMotion: reduceMotion, contentActive: contentActive,
                                        sceneActive: scenePhase == .active, visible: appeared)
    }
    private var light: CompanionHomeLight { lightOverride ?? .at(hour: Calendar.current.component(.hour, from: now)) }
    private var imageKey: String { state.room + "/" + state.colorway + "/" + state.furniture.values.sorted().joined(separator: "/") }

    var body: some View {
        Group {
            if outfitCloseup && (enabled || stateOverride != nil) {
                // Try-on needs free hands even when a work session is running.
                ClockinMotionMascot(mood: .hello, tap: reaction, outfitOverride: stateOverride)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(6)
                    .accessibilityLabel("Companion outfit")
            } else { home }
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .task(id: appeared && contentActive && scenePhase == .active) {
            guard appeared, contentActive, scenePhase == .active else { return }
            now = .now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                now = .now
            }
        }
    }

    private var home: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 360, geometry.size.height / 240)
            if let room = WardrobeArt.home.rooms[state.room] {
                roomScene(room)
                    .frame(width: 360, height: 240)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: 360 * scale, height: 240 * scale, alignment: .topLeading)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Companion home. \(activity.title). \(state.homeLayout.title). Lamp \(state.homeLampOn ? String(localized: "on", bundle: .app) : String(localized: "off", bundle: .app)).")
        .task(id: imageKey) {
            let state = state
            let decoded = await Task.detached(priority: .utility) {
                var result: [String: CGImage] = [:]
                if let room = WardrobeArt.home.rooms[state.room] { result[room.file] = WardrobeArt.decode(room.file, folder: "Home") }
                for id in state.furniture.values {
                    guard let item = WardrobeArt.home.items[id] else { continue }
                    result[item.file] = WardrobeArt.decode(item.file, folder: "Home")
                    // A bed's sleeper layers; the figure and its arms wear the
                    // companion's colours.
                    if let sleeper = item.sleeper {
                        result[sleeper.cover] = WardrobeArt.decode(sleeper.cover, folder: "Home")
                        for file in [sleeper.figure, sleeper.arms] {
                            result[file] = WardrobeArt.decode(file, folder: "Home")
                                .map { WardrobeArt.recolor($0, colorway: state.colorway) }
                        }
                    }
                }
                return result
            }.value
            guard !Task.isCancelled else { return }
            images = decoded
        }
    }

    private func roomScene(_ room: WardrobeRoom) -> some View {
        ZStack(alignment: .topLeading) {
            if let image = images[room.file] {
                Image(decorative: image, scale: 1).resizable().interpolation(.none)
                    .frame(width: 360, height: 240).scaleEffect(x: state.homeLayout.mirrored ? -1 : 1, y: 1)
            }
            CompanionWindowLight(light: light, mirrored: state.homeLayout.mirrored)
            ForEach([WardrobeSlot.rug] + WardrobeSlot.furniture.filter { $0 != .rug }, id: \.self) { slot in
                furniture(slot, room: room)
            }
            if enabled || stateOverride != nil {
                if activity == .sleeping { asleep(room) } else { companion(room) }
            }
            CompanionHomeAtmosphere(state: state, room: room, light: light, moving: moving)
                .frame(width: 360, height: 240).allowsHitTesting(false)
        }
        .clipped()
    }

    @ViewBuilder private func furniture(_ slot: WardrobeSlot, room: WardrobeRoom) -> some View {
        if let id = state.furniture[slot.rawValue], let item = WardrobeArt.home.items[id],
           item.slot == slot.rawValue, let image = images[item.file] {
            let rect = HomeSceneLayout.furnitureRect(item, in: room,
                imageSize: CGSize(width: image.width, height: image.height), layout: state.homeLayout,
                roomID: state.room, arrangement: state.homeArrangement)
            if [.floorLeft, .floorRight, .desk].contains(slot) {
                Ellipse().fill(.black.opacity(0.16)).frame(width: rect.width * 0.84, height: 9)
                    .position(x: rect.midX, y: rect.maxY - 2)
            }
            CompanionFurnitureImage(image: image,
                mirrored: state.homeLayout.mirrored && !HeritageArt.preservesOrientation(id),
                swaying: moving && ["potted-plant", "big-plant"].contains(id))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
        }
    }

    private func companion(_ room: WardrobeRoom) -> some View {
        let center = activity.center(in: room, layout: state.homeLayout, furniture: state.furniture, roomID: state.room, arrangement: state.homeArrangement)
        return ClockinMotionMascot(mood: activity == .idle ? mood : activity.mood, tap: reaction, outfitOverride: stateOverride)
        .frame(width: activity.side, height: activity.side)
        .scaleEffect(x: HomeSceneLayout.mirrorsCompanion(activity, layout: state.homeLayout) ? -1 : 1, y: 1)
        .position(x: center.x, y: center.y)
        .environment(\.clockinContentActive, moving)
    }
}

extension CompanionHomeView {
    /// The companion asleep in its bed, lying on its back: its head on the
    /// pillow toward the headboard, its body on the sheet, its legs under the
    /// blanket (the bed's cover layer) and its arms on top of it. It rises and
    /// falls slowly with its breath; Zs drift up off the pillow.
    @ViewBuilder fileprivate func asleep(_ room: WardrobeRoom) -> some View {
        if let item = WardrobeArt.home.items["companion-bed"], let sleeper = item.sleeper, let bed = images[item.file],
           let figure = images[sleeper.figure], let arms = images[sleeper.arms], let cover = images[sleeper.cover] {
            let rect = HomeSceneLayout.furnitureRect(item, in: room,
                imageSize: CGSize(width: bed.width, height: bed.height), layout: state.homeLayout,
                roomID: state.room, arrangement: state.homeArrangement)
            let mirrored = state.homeLayout.mirrored
            let center = CGPoint(x: mirrored ? rect.maxX - sleeper.center.x : rect.minX + sleeper.center.x,
                                 y: rect.minY + sleeper.center.y)
            let head = CGPoint(x: mirrored ? rect.maxX - sleeper.head.x : rect.minX + sleeper.head.x,
                               y: rect.minY + sleeper.head.y)
            let size = CGSize(width: Double(figure.width) * sleeper.scale, height: Double(figure.height) * sleeper.scale)
            // The figure on the sheet, the blanket over its legs, its arms on
            // the blanket; the figure and its arms breathe together.
            lying(figure, size: size, at: center, mirrored: mirrored)
            Image(decorative: cover, scale: 1).resizable().interpolation(.none)
                .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)
            lying(arms, size: size, at: center, mirrored: mirrored)
            CompanionSleepZs(head: CGPoint(x: head.x, y: head.y - 8), mirrored: mirrored, moving: moving)
                .frame(width: 360, height: 240)
                .allowsHitTesting(false)
        }
    }

    private func lying(_ image: CGImage, size: CGSize, at center: CGPoint, mirrored: Bool) -> some View {
        Image(decorative: image, scale: 1).resizable().interpolation(.none)
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .modifier(CompanionBreathing(active: moving))
            .frame(width: size.width, height: size.height)
            .position(center)
            .allowsHitTesting(false)
    }
}

/// A slow breath: the sleeper rises about a pixel.
private struct CompanionBreathing: ViewModifier {
    let active: Bool
    @State private var inhale = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: inhale ? 1.035 : 1, anchor: .bottom)
            .animation(active ? .easeInOut(duration: 1.7).repeatForever(autoreverses: true) : .default, value: inhale)
            .onAppear { inhale = active }
            .onChange(of: active) { _, now in inhale = now }
    }
}

/// Pixel Zs rising from the sleeping head and fading, snapped to whole
/// points so they stay crisp. Still, two of them hang in place.
private struct CompanionSleepZs: View {
    let head: CGPoint
    let mirrored: Bool
    let moving: Bool
    private static let period = 2.7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: !moving)) { context in
            let t = moving ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { canvas, _ in
                let phases = moving
                    ? (0..<3).map { ((t / Self.period) + Double($0) / 3).truncatingRemainder(dividingBy: 1) }
                    : [0.35, 0.72]
                for p in phases { draw(&canvas, progress: p, fade: moving ? sin(p * .pi) : 0.9) }
            }
        }
    }

    private func draw(_ canvas: inout GraphicsContext, progress p: Double, fade: Double) {
        // Up and away from the headboard, growing as they rise.
        let side: Double = mirrored ? -1 : 1
        let size = p > 0.5 ? 7 : 5
        let x = (head.x + side * (9 + 12 * p) - Double(size) / 2).rounded()
        let y = (head.y - 13 - 20 * p - Double(size) / 2).rounded()
        // A Z: top row, bottom row and the diagonal between them.
        var cells: [(Int, Int)] = (0..<size).map { ($0, 0) } + (0..<size).map { ($0, size - 1) }
        cells += (1..<(size - 1)).map { (size - 1 - $0, $0) }
        for (shade, offset) in [(Color(red: 0.15, green: 0.19, blue: 0.29), 1.0), (Color(red: 0.8, green: 0.86, blue: 0.93), 0.0)] {
            for (cx, cy) in cells {
                let r = CGRect(x: x + Double(cx) + offset, y: y + Double(cy) + offset, width: 1, height: 1)
                canvas.fill(Path(r), with: .color(shade.opacity(fade)))
            }
        }
    }
}

private struct CompanionWindowLight: View {
    let light: CompanionHomeLight
    let mirrored: Bool
    private var tint: Color { light == .night ? .indigo : (light == .dusk ? .orange : .yellow) }
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(light == .night ? 0.13 : 0)
            Circle().fill(tint.opacity(light == .night ? 0.32 : 0.17))
                .frame(width: 76, height: 76).position(x: 284, y: 75)
            Path { p in
                p.move(to: CGPoint(x: 246,y: 116)); p.addLine(to: CGPoint(x: 319,y: 116))
                p.addLine(to: CGPoint(x: 260,y: 230)); p.addLine(to: CGPoint(x: 166,y: 208)); p.closeSubpath()
            }.fill(tint.opacity(light == .night ? 0.07 : 0.13))
        }.frame(width: 360,height: 240).scaleEffect(x: mirrored ? -1 : 1,y: 1).allowsHitTesting(false)
    }
}
