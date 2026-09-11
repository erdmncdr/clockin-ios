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
        HStack(spacing: 5) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 10))
            Text("LV \(level)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(palette.accent.opacity(0.12))
                GeometryReader { geometry in
                    // Bant ve yol dolguya oranlanir; az XP'de isik parlamaya donusmez.
                    let fill = geometry.size.width * progress
                    Capsule(style: .continuous)
                        .fill(palette.accent.opacity(0.22))
                        .frame(width: fill)
                        .overlay {
                            if !reduceMotion {
                                // `withAnimation(...repeatForever)` bu ekranda hic ilerlemedi:
                                // bir tam tur boyunca dolguda tek piksel degismedi. Bant konumu
                                // artik dogrudan saatten hesaplaniyor. Yol dolgunun disinda
                                // basliyor ve bitiyor; sicrama gorunmuyor, bekleme de oradan geliyor.
                                TimelineView(.animation) { context in
                                    let phase = context.date.timeIntervalSinceReferenceDate
                                        .truncatingRemainder(dividingBy: 5.2) / 5.2
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.30), .clear],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                    .frame(width: fill * 0.55)
                                    .offset(x: fill * (-1.4 + 4.1 * phase))
                                }
                            }
                        }
                        .clipShape(Capsule(style: .continuous))
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous).stroke(palette.accent.opacity(0.26), lineWidth: 1)
            }
        }
    }
}
