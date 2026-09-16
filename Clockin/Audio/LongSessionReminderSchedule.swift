import Foundation

enum LongSessionReminderSchedule {
    static let preferenceKey = "Clockin.LongSessionReminderHours"
    static let defaultHours = 10
    static let choices = [0, 8, 10, 12]

    static func fireDate(now: Date, worked: TimeInterval, isPaused: Bool,
                         hours: Int, alreadyReminded: Bool = false, snoozedUntil: Date? = nil) -> Date? {
        guard choices.contains(hours), hours > 0, !isPaused,
              worked.isFinite, worked >= 0, SessionDuration.isValidDate(now) else { return nil }
        if let snoozedUntil {
            return SessionDuration.isValidDate(snoozedUntil) && snoozedUntil > now ? snoozedUntil : nil
        }
        guard !alreadyReminded else { return nil }
        // Gecmis esik bir kez bildirilir; tekrar engeli oturumla saklanir.
        return now.addingTimeInterval(max(1, Double(hours) * 3600 - worked))
    }

    static func snoozeDate(now: Date) -> Date { now.addingTimeInterval(3600) }

    static func matches(start: Date?, running: RunningSession?) -> Bool {
        guard let start, let running else { return false }
        return SessionDuration.isValidDate(start) && start == running.start
    }

    /// Son devamdan once bitis secilemez: oncesindeki molalarin yeri bilinmiyor,
    /// biriken sure o saate kadar gecen sureden uzun kaydedilirdi.
    static func earliestEnd(running: RunningSession, now: Date) -> Date {
        min(now, max(running.start, running.resumedAt ?? running.start))
    }

    static func validEnd(_ date: Date, running: RunningSession, now: Date) -> Bool {
        SessionDuration.isValidDate(date) && date >= earliestEnd(running: running, now: now) && date <= now
    }
}

struct LongSessionReminderState: Codable {
    let start: Date
    var hasReminded = false
    var scheduledDate: Date?
    var snoozedUntil: Date?

    mutating func reconcile(running: RunningSession, hours: Int, now: Date) -> Date? {
        if let scheduledDate, scheduledDate <= now { hasReminded = true }
        guard !running.isPaused, hours > 0 else {
            scheduledDate = nil
            snoozedUntil = nil
            return nil
        }
        if hasReminded, let scheduledDate, scheduledDate > now { return scheduledDate }
        scheduledDate = LongSessionReminderSchedule.fireDate(now: now, worked: running.elapsed(at: now),
            isPaused: running.isPaused, hours: hours, alreadyReminded: hasReminded, snoozedUntil: snoozedUntil)
        if scheduledDate != nil, running.elapsed(at: now) >= Double(hours) * 3600 { hasReminded = true }
        return scheduledDate
    }

    mutating func snooze(now: Date) {
        hasReminded = true
        snoozedUntil = LongSessionReminderSchedule.snoozeDate(now: now)
        scheduledDate = snoozedUntil
    }
}
