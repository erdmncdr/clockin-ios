import Foundation

/// What the menu bar item shows: which icon, and the text beside it in minimal
/// mode. Kept free of SwiftUI so it can be checked on its own.
///
/// Not clocked in, there is no text at all: the icon alone says Clockin is idle.
/// It used to read "T 0m · $0 · ₺0", which looked like a running timer at zero.
/// Clocked in, the session timer appears and counts; paused, it stays frozen.
struct MenuBarStatus: Equatable {
    enum State: Equatable { case idle, running, paused }

    struct Fields: Equatable {
        var hours = true
        var seconds = false
        var earnings = true
        var tryEquivalent = true
        var goal = false
    }

    let state: State
    /// nil when only the icon should show.
    let text: String?

    static func make(
        isRunning: Bool,
        isPaused: Bool,
        sessionElapsed: TimeInterval,
        sessionEarnings: Double,
        currencyCode: String,
        tryRate: Double?,
        todayDuration: TimeInterval,
        monthDuration: TimeInterval,
        dailyGoalHours: Double,
        monthlyGoalHours: Double,
        fields: Fields
    ) -> MenuBarStatus {
        guard isRunning else { return MenuBarStatus(state: .idle, text: nil) }
        var parts: [String] = []
        if fields.hours {
            parts.append(MacDurationText.clock(sessionElapsed, includeSeconds: fields.seconds))
        }
        if fields.earnings {
            parts.append(compactMoney(sessionEarnings, code: currencyCode))
        }
        if fields.tryEquivalent, currencyCode == "USD", let tryRate {
            parts.append(compactMoney(sessionEarnings * tryRate, code: "TRY"))
        }
        if fields.goal {
            if dailyGoalHours > 0 { parts.append(String(localized: "D \(goalPercent(todayDuration, goal: dailyGoalHours))%", bundle: .app)) }
            if monthlyGoalHours > 0 { parts.append(String(localized: "M \(goalPercent(monthDuration, goal: monthlyGoalHours))%", bundle: .app)) }
        }
        return MenuBarStatus(state: isPaused ? .paused : .running, text: parts.isEmpty ? nil : parts.joined(separator: " · "))
    }

    static func goalPercent(_ elapsed: TimeInterval, goal: Double) -> Int {
        guard goal > 0 else { return 0 }
        return min(999, max(0, Int((elapsed / 3600 / goal * 100).rounded())))
    }

    /// Whole units only: the menu bar has little room. The formatters are made
    /// once; the label refreshes every second while a session runs.
    nonisolated(unsafe) private static var formatters: [String: NumberFormatter] = [:]
    private static let formatterLock = NSLock()

    static func compactMoney(_ value: Double, code: String) -> String {
        formatterLock.lock(); defer { formatterLock.unlock() }
        let cacheKey = "\(AppLanguage.formatLocale.identifier)|\(code)"
        let formatter = formatters[cacheKey] ?? {
            let made = NumberFormatter()
            made.locale = AppLanguage.formatLocale
            made.numberStyle = .currency
            made.currencyCode = code
            if code == "TRY" { made.currencySymbol = "₺" }
            made.minimumFractionDigits = 0
            made.maximumFractionDigits = 0
            formatters[cacheKey] = made
            return made
        }()
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(Int(value.rounded()))"
    }
}
