import Foundation

/// The old menu bar can omit seconds without changing the shared formatter.
enum MacDurationText {
    static func clock(_ interval: TimeInterval, includeSeconds: Bool) -> String {
        if includeSeconds { return DurationText.clock(interval) }
        let minutes = Int(SessionDuration.clamped(interval) / 60)
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

