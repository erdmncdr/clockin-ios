import SwiftUI

@MainActor
struct DashboardLevelBadge: View {
    @EnvironmentObject private var store: ClockStore
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    let showInsights: () -> Void
    @State private var level = 1
    @State private var xp = 0
    @State private var refreshedAt: Date?

    var body: some View {
        Button(action: showInsights) {
            LevelBadge(level: level, xp: xp)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Level \(level), \(xp) XP")
        .accessibilityValue("\(500 - xp % 500) XP to next level")
        .accessibilityHint("Opens Insights")
        .task {
            // Body ve store bildirimleri tum kayitlari tekrar taramasin.
            // Sekmeye geri donuste de son hesaplamadan 60 saniye beklenir.
            while !Task.isCancelled {
                let now = Date()
                let remaining = refreshedAt.map { 60 - now.timeIntervalSince($0) } ?? 0
                if remaining > 0 {
                    do { try await Task.sleep(for: .seconds(remaining)) }
                    catch { return }
                    continue
                }
                let stats = InsightsSnapshot(store: store, now: now,
                                             dailyGoal: dailyGoalHours, monthlyGoal: monthlyGoalHours)
                level = stats.level
                xp = stats.xp
                refreshedAt = now
            }
        }
    }
}

private struct LevelBadge: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let level: Int
    let xp: Int

    private var progress: Double { min(max(Double(xp % 500) / 500, 0), 1) }

    var body: some View {
        // Kupa yerine dolgunun yuzdesi. Kupa hicbir seye karsilik gelmiyordu;
        // rozetin anlatmak istedigi zaten bir sonraki seviyeye ne kadar
        // kaldigi ve o sayi arkadaki dolguyu da okunur kiliyor.
        HStack(spacing: 6) {
            Text("LV \(level)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.accent.opacity(0.65))
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(palette.accent.opacity(0.12))
                GeometryReader { geometry in
                    let fill = geometry.size.width * progress
                    // Isik dolgunun bittigi yerde bitsin: tarama rozetin
                    // tamamini gezerse ilerlemeyi degil rozeti anlatir.
                    //
                    // Kirpma dolgunun kendi kapsul sekliyle yapilir. Dikdortgen
                    // kirpma, yuvarlak ucun uzerinde duz bir cizgi birakiyordu.
                    Capsule(style: .continuous)
                        .fill(palette.accent.opacity(0.22))
                        .frame(width: fill)
                        .overlay {
                            if !reduceMotion { BadgeSweep() }
                        }
                        .clipShape(Capsule(style: .continuous))
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous).stroke(palette.accent.opacity(0.26), lineWidth: 1)
            }
        }
        .phaseAnimator([false, true, false], trigger: level) { content, highlighted in
            content.overlay {
                Capsule(style: .continuous)
                    .stroke(palette.accent.opacity(!reduceMotion && highlighted ? 0.85 : 0), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .brightness(!reduceMotion && highlighted ? 0.12 : 0)
        } animation: { highlighted in
            reduceMotion ? nil : .easeOut(duration: highlighted ? 0.2 : 0.7)
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
    }
}

private struct BadgeSweep: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            // Kare yenilemesi sadece isikta kalir; XP hesabi tetiklenmez.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { context in
                let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6)
                let phase = min(cycle / 1.8, 1)
                // Bant dolgunun kendisine gore olculur. Sabit genislikte bir
                // bant, dar bir dolguyu bastan sona kaplayip taramak yerine
                // tek parca yanip sonuyordu.
                let band = max(6, geometry.size.width * 0.5)
                LinearGradient(
                    colors: [.clear, .white.opacity(0.45), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: band, height: geometry.size.height)
                .offset(x: -band + (geometry.size.width + band) * phase)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
