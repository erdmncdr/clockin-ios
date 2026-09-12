import SwiftUI

enum MascotAsset: String {
    case idle, working, paused, celebrate

    /// Tek karakterli gorsel. `idle`/`paused` dosyalari dort maskotluk birer
    /// sayfaydi; kartta yarim robotlar gorunuyordu, o dosyalar kaldirildi.
    var imageName: String {
        switch self {
        case .idle: "pose2"
        case .paused: "coffee1"
        case .working: "working"
        case .celebrate: "celebrate"
        }
    }

    var message: String {
        switch self {
        case .idle: "Ready when you are"
        case .working: "You are doing great, keep going!"
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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("Clockin.MascotDefault") private var defaultMode = "Auto"
    let state: MascotAsset
    @State private var pose: Int?
    @State private var poseToken = UUID()

    var body: some View {
        // Esikler secim aninda uygulanir; burada yalnizca kayitli ad okunur.
        let mode = CompanionMode(rawValue: defaultMode) ?? .auto
        return ZStack {
            if state == .celebrate {
                ClockinMascotImage(asset: state.imageName)
            } else if let pose {
                ClockinPoseMascot(index: pose)
            } else if mode == .typing {
                ClockinFrameMascot(prefix: "frame", interval: 0.18)
            } else if mode == .coffee {
                ClockinFrameMascot(prefix: "coffee", interval: 0.28)
            } else if let fixed = mode.fixedPoseIndex {
                ClockinPoseMascot(index: fixed)
            } else {
                switch state {
                case .working: ClockinFrameMascot(prefix: "frame", interval: 0.18)
                case .paused: ClockinFrameMascot(prefix: "coffee", interval: 0.28)
                case .idle, .celebrate: ClockinMascotImage(asset: state.imageName)
                }
            }
            if !reduceMotion && pose != nil && state != .celebrate {
                ClockinMascotEffects()
                    .id(poseToken)
                    .allowsHitTesting(false)
            }
        }
        .phaseAnimator(breathing ? [false, true] : [false]) { content, lifted in
            content
                .offset(y: breathing && lifted ? -1.5 : 0)
                .scaleEffect(breathing && lifted ? 1.018 : 1, anchor: .bottom)
        } animation: { _ in
            breathing ? .easeInOut(duration: 2.4) : nil
        }
        .phaseAnimator([false, true, false], trigger: state) { content, settling in
            content
                .scaleEffect(!reduceMotion && settling ? 0.96 : 1)
                .offset(y: !reduceMotion && settling ? 2 : 0)
        } animation: { settling in
            reduceMotion ? nil : (settling ? .easeOut(duration: 0.1) : .spring(duration: 0.4, bounce: 0.2))
        }
        .phaseAnimator([false, true, false], trigger: poseToken) { content, reacting in
            content
                .scaleEffect(!reduceMotion && reacting ? 1.12 : 1)
                .rotationEffect(.degrees(!reduceMotion && reacting ? -7 : 0))
                .offset(y: !reduceMotion && reacting ? -4 : 0)
        } animation: { reacting in
            reduceMotion ? nil : .spring(duration: reacting ? 0.2 : 0.45, bounce: 0.3)
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
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

    private var breathing: Bool { state == .working && !reduceMotion && scenePhase == .active }

    private func showPose() {
        guard state != .celebrate else { return }
        pose = (1...4).filter { $0 != pose }.randomElement()
        poseToken = UUID()
    }
}

private struct ClockinPoseMascot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @Environment(\.scenePhase) private var scenePhase

    private var isAnimating: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        ClockinMascotImage(asset: "pose\(index)")
            .phaseAnimator(isAnimating ? [false, true] : [false]) { content, phase in
                let moving = isAnimating && phase
                content
                    .scaleEffect(moving ? (index == 3 ? 1.05 : 0.98) : 1)
                    .offset(x: moving && index == 3 ? 3 : 0, y: moving ? -2 : 0)
                    .rotationEffect(.degrees(moving && index == 2 ? 4 : (moving && index == 4 ? -3 : 0)))
            } animation: { _ in
                isAnimating ? .easeInOut(duration: index == 3 ? 0.4 : 0.9) : nil
            }
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
