import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    precondition(condition, name)
    checks += 1
    print("ok: \(name)")
}

check(HapticPolicy.enabledKey == "Clockin.HapticsEnabled", "stable preference key")
check(HapticPolicy.isEnabled(storedValue: nil), "enabled by default")
check(HapticPolicy.isEnabled(storedValue: true), "explicit enabled")
check(!HapticPolicy.isEnabled(storedValue: false), "explicit disabled")

let expected: [(HapticEvent, HapticFeedback)] = [
    (.levelUp, .notification(.success)),
    (.buttonPress, .lightImpact), (.selection, .selection),
    (.sessionStarted, .start), (.sessionPaused, .lightImpact),
    (.sessionResumed, .lightImpact), (.sessionEnded, .stop),
    (.entrySaved, .notification(.success)), (.rateSaved, .notification(.success)),
    (.backupRestored, .notification(.success)), (.importFinished, .notification(.success)),
    (.validationFailed, .notification(.error)), (.destructiveConfirmation, .notification(.warning)),
    (.companionReaction, .softImpact(intensity: 0.6))
]
check(expected.count == HapticEvent.allCases.count, "every event has a specification")
for event in HapticEvent.allCases {
    check(expected.filter { $0.0 == event }.count == 1, "unique mapping for \(event)")
    check(HapticPolicy.feedback(for: event, enabled: true) == expected.first { $0.0 == event }?.1,
          "correct mapping for \(event)")
    check(HapticPolicy.feedback(for: event, enabled: false) == nil, "disabled silences \(event)")
}
for event: HapticEvent in [.entrySaved, .rateSaved, .backupRestored, .importFinished, .validationFailed, .destructiveConfirmation] {
    if case .notification = HapticPolicy.feedback(for: event, enabled: true) {
        check(true, "\(event) is a notification")
    } else { check(false, "\(event) must be a notification") }
}
check(HapticPolicy.pressBegan(wasPressed: false, isPressed: true, enabled: true) == .lightImpact,
      "press begins with light impact")
check(HapticPolicy.pressBegan(wasPressed: true, isPressed: false, enabled: true) == nil, "release stays silent")
check(HapticPolicy.pressBegan(wasPressed: true, isPressed: true, enabled: true) == nil, "held press stays silent")
check(HapticPolicy.pressBegan(wasPressed: false, isPressed: false, enabled: true) == nil, "idle render stays silent")
check(HapticPolicy.pressBegan(wasPressed: false, isPressed: true, enabled: false) == nil, "disabled press stays silent")
var signal = HapticSignal()
let initial = signal
check(signal == initial, "reading a signal does not trigger feedback")
signal.send(.sessionStarted)
check(signal != initial && signal.event == .sessionStarted, "explicit action advances signal")
let first = signal
signal.send(.sessionStarted)
check(signal != first, "repeated explicit actions remain distinct")
print("\(checks) haptics checks passed")
