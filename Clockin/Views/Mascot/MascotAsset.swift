import SwiftUI

enum MascotAsset: String {
    case idle, working, paused, celebrate

    var message: String {
        switch self {
        case .idle: "Ready when you are"
        case .working: "You are doing great — keep going!"
        case .paused: "Taking a reset break"
        case .celebrate: "Every focused hour makes your companion stronger."
        }
    }
}

struct ClockinMascotImage: View {
    let asset: String

    var body: some View {
        Image(asset)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

@MainActor
struct ClockinMascotStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("Clockin.MascotDefault") private var defaultMode = "Auto"
    let state: MascotAsset
    @State private var pose: Int?
    @State private var poseToken = UUID()

    var body: some View {
        ZStack {
            if state == .celebrate {
                ClockinMascotImage(asset: state.rawValue)
            } else if let pose {
                ClockinPoseMascot(index: pose)
            } else if defaultMode == "Typing" {
                ClockinFrameMascot(prefix: "frame", interval: 0.18)
            } else if defaultMode == "Coffee" {
                ClockinFrameMascot(prefix: "coffee", interval: 0.28)
            } else if let fixed = ["Victory", "Stretch", "Dance", "Music"].firstIndex(of: defaultMode) {
                ClockinPoseMascot(index: fixed + 1)
            } else {
                switch state {
                case .working: ClockinFrameMascot(prefix: "frame", interval: 0.18)
                case .paused: ClockinFrameMascot(prefix: "coffee", interval: 0.28)
                case .idle, .celebrate: ClockinMascotImage(asset: state.rawValue)
                }
            }
            if !reduceMotion && state != .celebrate {
                ClockinMascotEffects()
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showPose() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state == .celebrate ? "Celebrating focus companion" : "Focus companion")
        .accessibilityAddTraits(state == .celebrate ? [] : .isButton)
        .accessibilityAction { showPose() }
        .task(id: poseToken) {
            guard pose != nil else { return }
            // Yeni dokunus eski beklemeyi iptal eder; poz erken kapanmaz.
            do { try await Task.sleep(for: .seconds(2.2)) }
            catch { return }
            pose = nil
        }
    }

    private func showPose() {
        guard state != .celebrate else { return }
        pose = Int.random(in: 1...4)
        poseToken = UUID()
    }
}

private struct ClockinPoseMascot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var moving = false

    var body: some View {
        ClockinMascotImage(asset: "pose\(index)")
            .scaleEffect(moving ? (index == 3 ? 1.05 : 0.98) : 1)
            .offset(x: moving && index == 3 ? 5 : 0, y: moving ? -2 : 2)
            .rotationEffect(.degrees(moving && index == 2 ? 5 : (moving && index == 4 ? -4 : 0)))
            .animation(reduceMotion ? nil : .easeInOut(duration: index == 3 ? 0.28 : 0.7)
                .repeatForever(autoreverses: true), value: moving)
            .onAppear { moving = !reduceMotion }
            .onChange(of: reduceMotion) { _, reduced in moving = !reduced }
    }
}

@MainActor
private struct ClockinFrameMascot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let prefix: String
    let interval: Double
    @State private var frame = 1

    private var isAnimating: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        ClockinMascotImage(asset: "\(prefix)\(frame)")
            .task(id: isAnimating) {
                guard isAnimating else { return }
                // Gorev gorunumle yasar; sayacin yenilenmesi kareleri sifirlamaz.
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(interval)) }
                    catch { return }
                    frame = frame % 4 + 1
                }
            }
    }
}

private struct ClockinMascotEffects: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var start = Date()
    @State private var seed = Int.random(in: 0...4)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(start))
            let phase = min(elapsed.truncatingRemainder(dividingBy: 8) / 1.6, 1)
            let eased = 1 - pow(1 - phase, 3)
            let effect = (seed + Int(elapsed / 8)) % 5
            Group {
                switch effect {
                case 0:
                    Text("$  $  $").font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.green).offset(x: 13, y: -24 + 51 * eased).opacity(1 - eased)
                case 1:
                    Text("✦  ✧  ✦").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange).scaleEffect(0.7 + 0.55 * eased).opacity(1 - 0.8 * eased)
                case 2:
                    Text("♪  ♫  ♪").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.cyan).offset(x: -8 + 26 * eased, y: 8 - 28 * eased).opacity(1 - eased)
                case 3:
                    Text("✹  ✹").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.yellow).rotationEffect(.degrees(-15 + 50 * eased)).opacity(1 - 0.8 * eased)
                default:
                    Text("+XP").font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.green).offset(y: 2 - 27 * eased).opacity(1 - eased)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
