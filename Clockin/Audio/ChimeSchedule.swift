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

    struct Reconciliation {
        let removed: [Int]
        let additions: [Int: Date]
    }

    static func reconcile(desired: [Date], existing: [Int: Date]) -> Reconciliation {
        var kept = Set<Int>()
        var missing: [Date] = []
        for date in desired.prefix(maximumCount) {
            if let slot = existing.keys.sorted().first(where: {
                !kept.contains($0) && abs(existing[$0]!.timeIntervalSince(date)) < 0.01
            }) {
                kept.insert(slot)
            } else {
                missing.append(date)
            }
        }
        let free = (0..<maximumCount).filter { !kept.contains($0) }
        return Reconciliation(removed: existing.keys.filter { !kept.contains($0) }.sorted(),
                              additions: Dictionary(uniqueKeysWithValues: zip(free, missing)))
    }

}
