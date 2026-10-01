// Type-check-only boundaries for unrelated app services. ActivityKit, WidgetKit,
// UserNotifications, ClockStore, SessionMirror and LiveActivityPush are real.
import Combine
import Foundation

@MainActor final class CelebrationCenter {
    static let shared = CelebrationCenter()
    @Published var snapshotDate = Date.now
    @Published var proudUntil: Date?
    var lastWorkedDay: Date?
    func refresh(store: ClockStore) {}
}
@MainActor final class NudgeController {
    struct Mood { var isAngry = false }
    static let shared = NudgeController()
    @Published var mood: Mood?
    func update(store: ClockStore) {}
    func finishPendingUpdates() async {}
}
enum NudgePlanner { static let toneKey = "Clockin.NudgeTone" }
enum NudgeTone: String { case friendly }
@MainActor final class WardrobeStore {
    struct State { var json = "" }
    static let shared = WardrobeStore()
    let state = State()
}
@MainActor final class LongSessionReminderController {
    static let shared = LongSessionReminderController()
    func update(running: RunningSession?) {}
    func finishPendingUpdates() async {}
}
@MainActor final class FocusChimeController {
    static let shared = FocusChimeController()
    func update(running: RunningSession?, enabled: Bool, interval: Int, sound: String, force: Bool) {}
    func finishPendingUpdates() async {}
}
