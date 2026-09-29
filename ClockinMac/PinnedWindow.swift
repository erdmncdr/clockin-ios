import AppKit
import Combine
import SwiftUI

@MainActor
final class PinnedWindowController: NSObject, NSWindowDelegate {
    static let shared = PinnedWindowController()
    private var panel: NSPanel?
    private var changes: AnyCancellable?
    private var preferences: AnyCancellable?
    private var lastMode: String?
    private var lastVisible: Bool?

    func start(store: ClockStore) {
        guard changes == nil else { return }
        changes = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.refresh(store: store) }
        }
        preferences = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refresh(store: store) }
            }
        refresh(store: store)
    }

    private func refresh(store: ClockStore) {
        let mode = UserDefaults.standard.string(forKey: "Clockin.PinnedMode") ?? "Money"
        let visible = store.pinVisible && !UserDefaults.standard.bool(forKey: "Clockin.MinimalMode")
        if visible != lastVisible {
            update(isVisible: visible, store: store)
            lastVisible = visible
        }
        if let lastMode, mode != lastMode { applyPreset(mode) }
        lastMode = mode
    }

    func update(isVisible: Bool, store: ClockStore) {
        if isVisible {
            if panel == nil { panel = makePanel(store: store) }
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }

    func applyPreset(_ mode: String) {
        guard let panel else { return }
        let size = savedSize(for: mode) ?? defaultSize(for: mode)
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true, animate: true)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveCurrentSize()
    }

    func windowDidMove(_ notification: Notification) {
        panel?.saveFrame(usingName: "ClockinPinnedTimer")
    }

    /// Default sizes remain in points; existing per-layout sizes take precedence.
    private func defaultSize(for mode: String) -> NSSize {
        let base: NSSize = switch mode {
        case "Compact": NSSize(width: 246, height: 72)
        case "Goal": NSSize(width: 300, height: 116)
        case "All": NSSize(width: 370, height: 230)
        case "Total": NSSize(width: 340, height: 156)
        default: NSSize(width: 320, height: 112)
        }
        return base
    }

    private func savedSize(for mode: String) -> NSSize? {
        let defaults = UserDefaults.standard
        let widthKey = "Clockin.PinnedWidth.\(mode)"
        let heightKey = "Clockin.PinnedHeight.\(mode)"
        guard defaults.object(forKey: widthKey) != nil, defaults.object(forKey: heightKey) != nil else { return nil }
        let width = defaults.double(forKey: widthKey)
        let height = defaults.double(forKey: heightKey)
        guard width > 0, height > 0 else { return nil }
        return NSSize(width: width, height: height)
    }

    private func saveCurrentSize() {
        guard let panel else { return }
        let mode = UserDefaults.standard.string(forKey: "Clockin.PinnedMode") ?? "Money"
        UserDefaults.standard.set(panel.frame.width, forKey: "Clockin.PinnedWidth.\(mode)")
        UserDefaults.standard.set(panel.frame.height, forKey: "Clockin.PinnedHeight.\(mode)")
        panel.saveFrame(usingName: "ClockinPinnedTimer")
    }

    private func makePanel(store: ClockStore) -> NSPanel {
        let savedMode = UserDefaults.standard.string(forKey: "Clockin.PinnedMode") ?? "Money"
        let initialSize = defaultSize(for: savedMode)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 246, height: 72)
        panel.maxSize = NSSize(width: 640, height: 500)
        panel.setFrameAutosaveName("ClockinPinnedTimer")
        panel.delegate = self
        panel.contentView = NSHostingView(rootView:
            MacLocalizedContent { PinnedTimerView() }
                .environmentObject(store)
                .environmentObject(SharedStore.exchangeRates)
                .environmentObject(FocusRadioController.shared)
        )

        let restored = panel.setFrameUsingName("ClockinPinnedTimer")
        if let saved = savedSize(for: savedMode) {
            var frame = panel.frame
            frame.origin.y += frame.height - saved.height
            frame.size = saved
            panel.setFrame(frame, display: false)
        } else if !restored, let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - 266, y: visible.maxY - 92))
        }
        return panel
    }
}

struct PinnedTimerView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @EnvironmentObject private var radio: FocusRadioController
    @AppStorage("Clockin.PinnedMode") private var mode = "Money"
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        Group {
            if mode == "Compact" { compactContent } else if mode == "Goal" { goalContent } else if mode == "All" { allContent } else if mode == "Total" { totalContent } else { moneyContent }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.surfaceStroke))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 7)).foregroundStyle(.white.opacity(0.2)).padding(6)
        }
        .preferredColorScheme(theme.colorScheme)
        .fontDesign(theme.fontDesign)
        .environment(\.palette, theme)
        .onReceive(timer) { now = $0 }
    }

    private var compactContent: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(store.running == nil ? Color.secondary : (store.running?.isPaused == true ? .orange : theme.accent))
                .frame(width: 8, height: 8)


            VStack(alignment: .leading, spacing: 2) {
                Text(store.running == nil ? String(localized: "Ready", bundle: .app) : (store.running?.isPaused == true ? String(localized: "Paused", bundle: .app) : String(localized: "Clocked in", bundle: .app)))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                MacRollingText(DurationText.clock(store.elapsed(at: now)), value: store.elapsed(at: now),
                            size: 23, weight: .medium, design: .monospaced)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                let earned = store.currentEarnings(at: now)
                MacRollingText(earned.money(code: store.currencyCode), value: earned, size: 13,
                            weight: .semibold, design: .rounded, color: theme.accent)
                if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                    MacRollingText((earned * rate).money(code: "TRY"), value: earned * rate, size: 9,
                                weight: .medium, design: .rounded, color: Color.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var moneyContent: some View {
        let usd = store.currentEarnings(at: now)
        let rate = exchangeRates.latestRate
        let isEarning = store.running?.isPaused == false
        let perHour = store.currentRate(at: now)
        return VStack(spacing: 8) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(isEarning ? theme.accent : (store.running == nil ? .secondary : .orange))
                        .frame(width: 7, height: 7)
                    Text(store.running == nil ? String(localized: "Ready", bundle: .app) : (isEarning ? String(localized: "Earning", bundle: .app) : String(localized: "Paused", bundle: .app)))
                        .font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(.secondary)
                }
                Spacer()
                MacRollingText(DurationText.clock(store.elapsed(at: now)), value: store.elapsed(at: now),
                            size: 16, weight: .medium, design: .monospaced)
            }
            HStack(alignment: .firstTextBaseline) {
                MacRollingText(usd.money(code: store.currencyCode), value: usd, size: 21, weight: .bold,
                            design: .rounded, color: theme.accent)
                Spacer()
                if store.currencyCode == "USD", let rate {
                    MacRollingText((usd * rate).money(code: "TRY"), value: usd * rate, size: 15,
                                weight: .semibold, design: .rounded)
                }
            }
            HStack {
                Text("\(perHour.money(code: store.currencyCode))/h")
                Spacer()
                if store.currencyCode == "USD", let rate {
                    Text("\((perHour * rate).money(code: "TRY"))/h")
                }
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(isEarning ? theme.accent : .secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private var goalContent: some View {
        let day = store.todayDuration(at: now) / 3600
        let month = store.monthDuration(at: now) / 3600
        return VStack(alignment: .leading, spacing: 9) {
            HStack { Image(systemName: "target").foregroundStyle(theme.accent); Text("Goals").font(.system(size: 9, weight: .black)); Spacer(); Text(DurationText.clock(store.elapsed(at: now))).font(.system(size: 14, design: .monospaced)) }
            goalGauge(String(localized: "Today", bundle: .app), value: day, goal: dailyGoalHours)
            goalGauge(String(localized: "Month", bundle: .app), value: month, goal: monthlyGoalHours)
        }
        .padding(14)
    }

    private var allContent: some View {
        let earning = store.currentEarnings(at: now)
        let rate = exchangeRates.latestRate
        let active = store.running?.isPaused == false
        let perHour = store.currentRate(at: now)
        let day = store.todayDuration(at: now) / 3600
        let month = store.monthDuration(at: now) / 3600
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(active ? theme.accent : (store.running == nil ? .secondary : .orange)).frame(width: 7, height: 7)
                    Text(store.running == nil ? String(localized: "Ready", bundle: .app) : (active ? String(localized: "Earning", bundle: .app) : String(localized: "Paused", bundle: .app)))
                        .font(.system(size: 9, weight: .black)).foregroundStyle(.secondary)
                }
                Spacer()
                MacRollingText(DurationText.clock(store.elapsed(at: now)), value: store.elapsed(at: now),
                            size: 16, design: .monospaced)
            }
            HStack(alignment: .firstTextBaseline) {
                MacRollingText(earning.money(code: store.currencyCode), value: earning, size: 23, weight: .bold,
                            design: .rounded, color: theme.accent)
                Spacer()
                if store.currencyCode == "USD", let rate {
                    MacRollingText((earning * rate).money(code: "TRY"), value: earning * rate, size: 14, weight: .semibold)
                }
            }
            HStack {
                Text("\(perHour.money(code: store.currencyCode))/h")
                Spacer()
                Text("Today \(hoursText(day))").foregroundStyle(theme.secondary)
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            HStack(spacing: 6) {
                let averages = allTimeAverages(at: now)
                averageChip(String(localized: "Avg day", bundle: .app), hours: averages.day)
                averageChip(String(localized: "Avg week", bundle: .app), hours: averages.week)
                averageChip(String(localized: "Avg month", bundle: .app), hours: averages.month)
            }
            if dailyGoalHours > 0 { goalGauge(String(localized: "Day", bundle: .app), value: day, goal: dailyGoalHours) }
            if monthlyGoalHours > 0 { goalGauge(String(localized: "Month", bundle: .app), value: month, goal: monthlyGoalHours) }
            HStack(spacing: 7) {
                Image(systemName: radio.isPlaying ? "music.note.list" : "music.note").foregroundStyle(radio.isPlaying ? theme.accent : .secondary)
                Text(radio.isPlaying ? String(localized: "Radio on", bundle: .app) : String(localized: "Radio off", bundle: .app)).font(.system(size: 9, weight: .bold, design: .monospaced))
                Spacer()
                Button { if radio.isPlaying { radio.stop() } else { radio.play() } } label: { Image(systemName: radio.isPlaying ? "stop.fill" : "play.fill") }.buttonStyle(.hitTarget)
                    .accessibilityLabel(radio.isPlaying ? String(localized: "Stop focus radio", bundle: .app) : String(localized: "Play focus radio", bundle: .app))
                Slider(value: $radio.volume, in: 0...1) { Text("Volume") }.frame(width: 65).tint(theme.accent)
            }
        }
        .padding(12)
    }

    private var totalContent: some View {
        let active = store.running?.isPaused == false
        let current = store.currentEarnings(at: now)
        let total = store.allEarnings(at: now)
        let totalDuration = store.allDuration(at: now)
        let today = store.todayEarnings(at: now)
        let rate = exchangeRates.latestRate
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Circle().fill(active ? theme.accent : (store.running == nil ? .secondary : .orange)).frame(width: 7, height: 7)
                Text("Total earned")
                    .font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(.secondary)
                Spacer()
                MacRollingText(DurationText.clock(store.elapsed(at: now)), value: store.elapsed(at: now),
                            size: 13, design: .monospaced)
            }
            HStack(alignment: .firstTextBaseline) {
                MacRollingText(total.money(code: store.currencyCode), value: total, size: 24, weight: .bold,
                            design: .rounded, color: theme.accent)
                Spacer()
                if store.currencyCode == "USD", let rate {
                    MacRollingText((total * rate).money(code: "TRY"), value: total * rate, size: 13, weight: .semibold)
                }
            }
            HStack(spacing: 6) {
                totalChip(String(localized: "Total", bundle: .app), DurationText.compact(totalDuration))
                totalChip(String(localized: "Today", bundle: .app), today.money(code: store.currencyCode))
                totalChip(String(localized: "Session", bundle: .app), current.money(code: store.currencyCode))
            }
        }
        .padding(14)
    }

    private func totalChip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 9, weight: .semibold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5).padding(.horizontal, 6)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 6))
    }

    private func goalGauge(_ label: String, value: Double, goal: Double) -> some View {
        let progress = goal > 0 ? min(max(value / goal, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(goal > 0 ? String(localized: "\(hoursText(value)) / \(hoursText(goal))", bundle: .app) : String(localized: "Set in Settings", bundle: .app))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
            }
            HStack(spacing: 8) {
                GeometryReader { geometry in
                    Capsule().fill(theme.surfaceStroke)
                    Capsule().fill(progress >= 1 ? Color.green : theme.accent)
                        .frame(width: geometry.size.width * progress)
                }
                .frame(height: 4)
                .accessibilityLabel("\(label) goal")
                .accessibilityValue("\(Int(progress * 100)) percent")
                if goal > 0 {
                    Text(progress >= 1 ? String(localized: "Goal reached", bundle: .app) : String(localized: "\(hoursText(max(0, goal - value))) left", bundle: .app))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(progress >= 1 ? .green : theme.accent)
                        .fixedSize()
                }
            }
        }
    }

    private func hoursText(_ hours: Double) -> String { DurationText.compact(hours * 3600) }

    private func averageChip(_ label: String, hours: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            Text(hoursText(hours)).font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 6))
    }

    private func allTimeAverages(at date: Date) -> (day: Double, week: Double, month: Double) {
        let calendar = Calendar.autoupdatingCurrent
        let earliest = store.sessions.map(\.start).min() ?? store.running?.start ?? date
        let start = calendar.startOfDay(for: earliest)
        let end = calendar.startOfDay(for: date)
        let calendarDays = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let daily = store.allDuration(at: date) / 3600 / Double(calendarDays)
        return (daily, daily * 7, daily * 30.44)
    }

}
