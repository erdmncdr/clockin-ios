enum HapticEvent: CaseIterable, Sendable {
    case buttonPress, selection
    case sessionStarted, sessionPaused, sessionResumed, sessionEnded
    case entrySaved, rateSaved, backupRestored, importFinished
    case validationFailed, destructiveConfirmation, companionReaction
}

enum HapticFeedback: Equatable, Sendable {
    enum Notification: Sendable { case success, warning, error }
    case lightImpact
    case softImpact(intensity: Double)
    case selection, start, stop
    case notification(Notification)
}

enum HapticPolicy {
    static let enabledKey = "Clockin.HapticsEnabled"

    static func isEnabled(storedValue: Bool?) -> Bool { storedValue ?? true }

    static func feedback(for event: HapticEvent, enabled: Bool) -> HapticFeedback? {
        guard enabled else { return nil }
        switch event {
        case .buttonPress, .sessionPaused, .sessionResumed: return .lightImpact
        case .selection: return .selection
        case .sessionStarted: return .start
        case .sessionEnded: return .stop
        case .entrySaved, .rateSaved, .backupRestored, .importFinished: return .notification(.success)
        case .validationFailed: return .notification(.error)
        case .destructiveConfirmation: return .notification(.warning)
        case .companionReaction: return .softImpact(intensity: 0.6)
        }
    }

    static func pressBegan(wasPressed: Bool, isPressed: Bool, enabled: Bool) -> HapticFeedback? {
        guard !wasPressed, isPressed else { return nil }
        return feedback(for: .buttonPress, enabled: enabled)
    }
}

struct HapticSignal: Equatable {
    private(set) var count = 0
    private(set) var event: HapticEvent = .selection

    mutating func send(_ event: HapticEvent) {
        self.event = event
        count += 1
    }
}
