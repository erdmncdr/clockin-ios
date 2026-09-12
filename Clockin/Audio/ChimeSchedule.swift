import Foundation

/// Mac gibi mevcut kovayi atlar; ayar degisince gecmis esikler calinmaz.
/// Duvar saati yerine molalar cikarilmis calisma suresi verilir.
enum ChimeSchedule {
    static let maximumCount = 20

    static func fireDates(now: Date, worked: TimeInterval, isPaused: Bool,
                          enabled: Bool, intervalMinutes: Int, count: Int = maximumCount) -> [Date] {
        guard enabled, !isPaused, worked.isFinite, worked >= 0,
              now.timeIntervalSinceReferenceDate.isFinite else { return [] }
        let minutes = min(120, max(1, intervalMinutes == 0 ? 10 : intervalMinutes))
        let interval = Double(minutes * 60)
        // Tam sinirda tekrar bildirim yok; sonraki tam aralik beklenir.
        let remaining = interval - worked.truncatingRemainder(dividingBy: interval)
        return (0..<min(maximumCount, max(0, count))).map {
            now.addingTimeInterval(remaining + Double($0) * interval)
        }
    }
}
