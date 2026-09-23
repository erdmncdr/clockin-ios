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
        .accessibilityLabel("Companion home. \(activity.title). \(state.homeLayout.title). Lamp \(state.homeLampOn ? String(localized: "on") : String(localized: "off")).")
        .task(id: imageKey) {
            let state = state
            let decoded = await Task.detached(priority: .utility) {
                var result: [String: CGImage] = [:]
                if let room = WardrobeArt.home.rooms[state.room] { result[room.file] = WardrobeArt.decode(room.file, folder: "Home") }
                for id in state.furniture.values {
                    if let item = WardrobeArt.home.items[id] { result[item.file] = WardrobeArt.decode(item.file, folder: "Home") }
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
                companion(room)
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

    private var sleepingOutfit: WardrobeState {
        var copy = state
        copy.equipped = [:]
        return copy
    }

    private func companion(_ room: WardrobeRoom) -> some View {
        let center = activity.center(in: room, layout: state.homeLayout, furniture: state.furniture, roomID: state.room, arrangement: state.homeArrangement)
        return Group {
            if activity == .sleeping {
                ClockinMascotStill(mood: .tired, maxPixelSize: 314, outfit: sleepingOutfit)
                    .mask {
                        Ellipse().frame(width: activity.side * 98 / 314, height: activity.side * 84 / 314)
                            .position(x: activity.side * 166 / 314, y: activity.side * 112 / 314)
                    }
                    .rotationEffect(.degrees(state.homeLayout.mirrored ? 90 : -90))
            } else {
                ClockinMotionMascot(mood: activity == .idle ? mood : activity.mood, tap: reaction, outfitOverride: stateOverride)
            }
        }
        .frame(width: activity.side, height: activity.side)
        .scaleEffect(x: HomeSceneLayout.mirrorsCompanion(activity, layout: state.homeLayout) ? -1 : 1, y: 1)
        .position(x: center.x, y: center.y)
        .environment(\.clockinContentActive, moving)
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
