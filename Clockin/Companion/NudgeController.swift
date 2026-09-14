import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class NudgeController: ObservableObject {
    static let shared = NudgeController()
    @Published private(set) var mood: NudgeMood?
    @Published private(set) var errorMessage: String?
    @Published var openToday = false
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let stateKey = "Clockin.NudgeState"
    private var state: State
    private var input: NudgeInput?
    private var revision = 0
    private var worker: Task<Void, Never>?

    private struct State: Codable {
        var pause: NudgePauseObservation?
        var scheduled: [PlannedNudge] = []
    }

    private init() {
        state = defaults.data(forKey: stateKey).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    func update(store: ClockStore) {
        let now = Date.now
        let calendar = Calendar.current
        state.pause = NudgePauseObservation.reconcile(state.pause, running: store.running, now: now)
        // Saat dilimi degisince store'un gun onbellegi eski sinirlari tasiyabilir.
        var daily: [Date: TimeInterval] = [:]
        for session in store.sessions {
            daily[calendar.startOfDay(for: session.start), default: 0] += session.duration
        }
        input = NudgeInput(now: now, calendar: calendar, dailyDurations: daily, sessions: store.sessions,
            running: store.running, observedPauseDate: state.pause?.date,
            dailyGoalHours: defaults.double(forKey: "Clockin.GoalDailyHours"),
            tone: NudgeTone(rawValue: defaults.string(forKey: NudgePlanner.toneKey) ?? "") ?? .grumpy,
            enabled: defaults.object(forKey: NudgePlanner.enabledKey) as? Bool ?? true)
        if input?.enabled == false || store.running?.isPaused == false { mood = nil }
        persist()
        revision += 1
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            await self.drain()
            self.worker = nil
        }
    }

    private func drain() async {
        // Tek yazici; eski ekleme bitmeden yeni plan silme/ekleme yapmaz.
        var processed = -1
        while processed != revision {
            processed = revision
            let permission = await center.notificationSettings()
            guard processed == revision else { continue }
            let pending = await center.pendingNotificationRequests()
            guard processed == revision, var input else { continue }
            input.now = .now
            input.enabled = input.enabled && [.authorized, .provisional, .ephemeral].contains(permission.authorizationStatus)
            input.consumed = state.scheduled.filter { $0.fireDate <= input.now }
            mood = NudgePlanner.currentMood(input)
            errorMessage = nil
            let plan = NudgePlanner.plan(input)
            let desired = Dictionary(uniqueKeysWithValues: plan.map { ($0.identifier, $0) })
            let ours = pending.filter { $0.identifier.hasPrefix(NudgePlanner.prefix) }
            let removed = ours.filter { desired[$0.identifier] == nil }.map(\.identifier)
            if !removed.isEmpty { center.removePendingNotificationRequests(withIdentifiers: removed) }
            // Gecmis teslimler silinse bile gunluk sinir tekrar acilmaz.
            let cutoff = input.calendar.date(byAdding: .day, value: -8, to: input.now)!
            state.scheduled.removeAll {
                $0.fireDate < cutoff || ($0.fireDate > input.now && desired[$0.identifier] == nil)
            }
            persist()

            let existing = Dictionary(uniqueKeysWithValues: ours.map { ($0.identifier, $0) })
            let newCount = plan.filter { existing[$0.identifier] == nil }.count
            let reminderReserve = pending.contains { $0.identifier == LongSessionReminderNotification.identifier } ? 0 : 1
            let shortage = max(0, pending.count - removed.count + newCount + reminderReserve - 64)
            // Onceki surumden kalan dolu can kuyrugu yeni bildirimleri ac birakmasin.
            let evicted = pending.filter { $0.identifier.hasPrefix("Clockin.FocusChime.") }
                .suffix(shortage).map(\.identifier)
            if !evicted.isEmpty { center.removePendingNotificationRequests(withIdentifiers: evicted) }
            var available = max(0, 64 - pending.count + removed.count + evicted.count - reminderReserve)

            for nudge in plan {
                guard processed == revision else { break }
                guard nudge.fireDate > .now else { continue }
                if let old = existing[nudge.identifier], matches(old, nudge: nudge, calendar: input.calendar) { continue }
                if existing[nudge.identifier] == nil && available == 0 {
                    errorMessage = "No notification slots available. Reopen Clockin later to try again."
                    continue
                }
                let content = UNMutableNotificationContent()
                content.title = nudge.title
                content.body = nudge.body
                content.sound = .default
                content.threadIdentifier = "Clockin.Nudges"
                content.userInfo = ["imageName": nudge.imageName, "fireDate": nudge.fireDate.timeIntervalSinceReferenceDate]
                if let attachment = attachment(for: nudge) { content.attachments = [attachment] }
                var components = input.calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second], from: nudge.fireDate)
                components.calendar = input.calendar
                components.timeZone = input.calendar.timeZone
                let request = UNNotificationRequest(identifier: nudge.identifier, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                do {
                    try await center.add(request)
                    // Eski revizyon da teslim edilebilir; bir sonraki tur bunu uzlastirir.
                    state.scheduled.removeAll { $0.identifier == nudge.identifier && $0.fireDate > input.now }
                    state.scheduled.append(nudge)
                    persist()
                    if existing[nudge.identifier] == nil { available -= 1 }
                } catch {
                    guard processed == revision else { break }
                    errorMessage = "Could not schedule nudges: \(error.localizedDescription)"
                }
            }
        }
    }

    private func matches(_ request: UNNotificationRequest, nudge: PlannedNudge, calendar: Calendar) -> Bool {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return false }
        let imageAvailable = UIImage(named: nudge.imageName) != nil
        return request.content.title == nudge.title && request.content.body == nudge.body
            && request.content.threadIdentifier == "Clockin.Nudges"
            && request.content.userInfo["imageName"] as? String == nudge.imageName
            && request.content.userInfo["fireDate"] as? Double == nudge.fireDate.timeIntervalSinceReferenceDate
            && trigger.dateComponents.timeZone == calendar.timeZone
            && trigger.dateComponents.calendar?.identifier == calendar.identifier
            && (!imageAvailable || !request.content.attachments.isEmpty)
    }

    private func attachment(for nudge: PlannedNudge) -> UNNotificationAttachment? {
        guard let data = UIImage(named: nudge.imageName)?.pngData(),
              let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = cache.appendingPathComponent("NudgeAttachments", isDirectory: true)
        let file = folder.appendingPathComponent("\(nudge.identifier).\(UUID().uuidString).png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            // Sistem dosyayi eklerken kendi deposuna tasir; eklemeden once silmek gorseli dusurur.
            return try UNNotificationAttachment(identifier: nudge.imageName, url: file)
        } catch {
            return nil
        }
    }

    func finishPendingUpdates() async { await worker?.value }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: stateKey) }
    }
}
