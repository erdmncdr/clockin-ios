#if DEBUG
import SwiftUI

struct LevelEffectsPreview: View {
    @State private var level = 450
    @State private var still = false
    @State private var showBars = false
    @State private var showCrests = false
    @State private var compact = false
    @State private var largeText = false
    @State private var companion = true
    @State private var replay = 0
    @State private var pinned: Double?
    @State private var clean = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var policy = RollingAnimationPolicy.shared
    private var moving: Bool { policy.allowsAnimation(reduceMotion: still || reduceMotion, contentActive: true, sceneActive: scenePhase == .active, visible: true) }
    @ViewBuilder private var controls: some View {
        HStack {
            Button(showBars ? "Celebration" : "All bars") { showBars.toggle() }
            Button("Rank frames") { showCrests.toggle() }.padding(.leading, 12)
            Button("Replay") { replay += 1 }.padding(.leading, 12)
            Spacer()
            Toggle("Still", isOn: $still).fixedSize()
        }.padding(.horizontal, 24).padding(.top, 12)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach([1, 74, 75, 150, 225, 300, 375, 450, 451, 500, 525, 600], id: \.self) { item in
                    Button("\(item)") { level = item }
                        .padding(8).background(level == item ? Color.white.opacity(0.18) : .clear, in: Capsule())
                }
            }.padding(.horizontal, 20)
        }.padding(.top, 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !clean { controls }
            if showCrests {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach([1, 75, 150, 225, 300, 375, 450, 525, 600], id: \.self) { item in
                            let rank = LevelPrestige(level: item)
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(rank.name).font(.headline)
                                    Text(rank.detail).font(.caption).foregroundStyle(.secondary)
                                    Text(item == 1 ? "1–74" : "\(item / 75 * 75)–\(item / 75 * 75 + 74)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 20)
                                LevelBadge(level: item, xp: 325, active: moving)
                            }.frame(minHeight: 66)
                        }
                    }.padding(.horizontal, 24).padding(.top, 12)
                }
            } else if showBars {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach([1, 75, 150, 225, 300, 375, 500, 525, 600], id: \.self) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack { VStack(alignment: .leading, spacing: 4) { Text(LevelPrestige(level: item).name).font(.headline); Text(LevelPrestige(level: item).detail).font(.caption2).foregroundStyle(.secondary) }; Spacer(); LevelBadge(level: item, xp: 325, active: moving) }
                                PrestigeProgressBar(level: item, progress: 0.65, active: moving)
                                Text(item == 1 ? "Levels 1–74" : "Levels \(item / 75 * 75)–\(item / 75 * 75 + 74)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.padding(24)
                }
            } else {
                LevelUpCard(level: level, hours: max(1, (level - 1) * 5), xp: 162825, moving: moving,
                            companionEnabled: companion, dismiss: { showBars = true }, share: {}, pinnedTime: pinned)
                    .id("\(level)-\(replay)")
                    .dynamicTypeSize(largeText ? .accessibility3 : .large)
                    .frame(width: compact ? 320 : nil, height: compact ? 560 : nil)
                Spacer(minLength: 0)
            }
        }
        .background(Color(red: 0.018, green: 0.026, blue: 0.047)).preferredColorScheme(.dark)
        .foregroundStyle(.white).tint(LevelPrestige(level: level).highlight)
        .task {
            // Opt-in recording fixture; no user XP, persistence, or release code.
            guard ProcessInfo.processInfo.arguments.contains("--preview-card-demo") else { return }
            do {
                try await Task.sleep(for: .seconds(5))
                level = 450
                try await Task.sleep(for: .seconds(8))
                level = 500
            } catch { return }
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--preview-level"), args.indices.contains(i + 1), let value = Int(args[i + 1]) { level = value }
            showBars = args.contains("--preview-bars")
            showCrests = args.contains("--preview-crests")
            still = args.contains("--preview-still")
            compact = args.contains("--preview-compact")
            largeText = args.contains("--preview-large-text")
            companion = !args.contains("--preview-no-companion")
            clean = args.contains("--preview-clean")
            if let i = args.firstIndex(of: "--preview-time"), args.indices.contains(i + 1) { pinned = Double(args[i + 1]) }
        }
    }
}
#endif
