import Combine
import Foundation
import UserNotifications

enum LongSessionReminderNotification {
    static let identifier = "Clockin.LongSessionReminder"
    static let category = "Clockin.LongSessionReminder.Actions"
    static let clockOut = "Clockin.LongSessionReminder.ClockOut"
    static let setEndTime = "Clockin.LongSessionReminder.SetEndTime"
    static let snooze = "Clockin.LongSessionReminder.Snooze"
    static let startKey = "sessionStart"

    static func register(on center: UNUserNotificationCenter) {
        center.setNotificationCategories([UNNotificationCategory(identifier: category, actions: [
            UNNotificationAction(identifier: clockOut, title: "Clock out", options: []),
            UNNotificationAction(identifier: setEndTime, title: "Set end time", options: [.foreground]),
            UNNotificationAction(identifier: snooze, title: "Remind in 1 hour", options: [])
        ], intentIdentifiers: [], options: [])])
    }
}

@MainActor
final class LongSessionReminderController: ObservableObject {
    static let shared = LongSessionReminderController()
    @Published var pendingEndTime: Date?
    @Published private(set) var errorMessage: String?
    private let center = UNUserNotificationCenter.current()
    private let stateKey = "Clockin.LongSessionReminderState"
    private var state: LongSessionReminderState?
    private var input: Input?
    private var revision = 0
    private var worker: Task<Void, Never>?

    private struct Input: Equatable {
        let running: RunningSession?
        let hours: Int
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: stateKey) {
            state = try? JSONDecoder().decode(LongSessionReminderState.self, from: data)
        }
    }

    var hours: Int {
        let value = UserDefaults.standard.object(forKey: LongSessionReminderSchedule.preferenceKey) as? Int
        return value.flatMap { LongSessionReminderSchedule.choices.contains($0) ? $0 : nil }
            ?? LongSessionReminderSchedule.defaultHours
    }

    func update(running: RunningSession?, force: Bool = false) {
        let next = Input(running: running, hours: hours)
        guard force || input != next else { return }
        input = next
        if pendingEndTime != nil, !LongSessionReminderSchedule.matches(start: pendingEndTime, running: running) {
            pendingEndTime = nil
        }
        if state?.start != running?.start {
            state = running.map { LongSessionReminderState(start: $0.start) }
            center.removeDeliveredNotifications(withIdentifiers: [LongSessionReminderNotification.identifier])
        }
        if running == nil || running?.isPaused == true || next.hours == 0 {
            if let running { _ = state?.reconcile(running: running, hours: next.hours, now: .now) }
            center.removeDeliveredNotifications(withIdentifiers: [LongSessionReminderNotification.identifier])
        }
        persist()
        revision += 1
        center.removePendingNotificationRequests(withIdentifiers: [LongSessionReminderNotification.identifier])
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            await self.drain()
            self.worker = nil
        }
    }

    private func drain() async {
        // Tek yazici, duraklatmadan once baslayan eklemenin geride kalmasini onler.
        var processed = -1
        while processed != revision {
            processed = revision
            center.removePendingNotificationRequests(withIdentifiers: [LongSessionReminderNotification.identifier])
            errorMessage = nil
            guard let input, let running = input.running, !running.isPaused, input.hours > 0 else { continue }
            let permission = await center.notificationSettings()
            guard processed == revision else { continue }
            guard [.authorized, .provisional, .ephemeral].contains(permission.authorizationStatus) else { continue }
            let now = Date.now
            var next = state ?? LongSessionReminderState(start: running.start)
            guard let date = next.reconcile(running: running, hours: input.hours, now: now) else {
                state = next
                persist()
                continue
            }
            let pending = await center.pendingNotificationRequests()
            guard processed == revision else { continue }
            // Eski surumun dolu can kuyrugundan da bir yer geri alinabilir.
            if pending.count >= 64, let chime = pending.last(where: { $0.identifier.hasPrefix("Clockin.FocusChime.") }) {
                center.removePendingNotificationRequests(withIdentifiers: [chime.identifier])
            }
            let content = UNMutableNotificationContent()
            content.title = "Still working?"
            content.body = "Clockin has been running for \(DurationText.compact(running.elapsed(at: date)))."
            content.sound = .default
            content.categoryIdentifier = LongSessionReminderNotification.category
            content.userInfo = [LongSessionReminderNotification.startKey: running.start.timeIntervalSinceReferenceDate]
            let request = UNNotificationRequest(identifier: LongSessionReminderNotification.identifier, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false))
            do {
                try await center.add(request)
                guard processed == revision else { continue }
                state = next
                persist()
            } catch {
                guard processed == revision else { continue }
                errorMessage = "Could not schedule reminder: \(error.localizedDescription)"
            }
        }
    }

    func handle(action: String, start: Date?) async {
        let store = SharedStore.clock
        guard LongSessionReminderSchedule.matches(start: start, running: store.running) else { return }
        switch action {
        case LongSessionReminderNotification.clockOut:
            store.clockOut()
            SessionMirror.shared.refresh()
            await SessionMirror.shared.finishPendingUpdates()
        case LongSessionReminderNotification.setEndTime:
            pendingEndTime = start
        case LongSessionReminderNotification.snooze:
            guard let running = store.running, !running.isPaused, hours > 0 else { return }
            if state?.start != running.start { state = LongSessionReminderState(start: running.start) }
            state?.snooze(now: .now)
            persist()
            update(running: running, force: true)
            await finishPendingUpdates()
        default: break
        }
    }

    func shouldPresent(start: Date?) -> Bool {
        let running = SharedStore.clock.running
        return hours > 0 && running?.isPaused == false
            && LongSessionReminderSchedule.matches(start: start, running: running)
    }

    func finishPendingUpdates() async { await worker?.value }

    private func persist() {
        if let state, let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: stateKey)
        }
    }
}
