import Foundation

@main struct IPhoneFollowChecks {
    @MainActor static func main() async throws {
        let domain = "clockin-follow-\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        let directory = FileManager.default.temporaryDirectory.appending(path: domain)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: domain)
            try? FileManager.default.removeItem(at: directory)
        }
        var count = 0
        func check(_ value: Bool, _ name: String) {
            precondition(value, name)
            count += 1; print("ok: \(name)")
        }
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let store = ClockStore(fileURL: directory.appending(path: "clock.json"), now: { date })
        var active = false
        var permitted = true
        var posted: [Date] = []
        func makeNotifier() -> RemoteClockInNotification {
            RemoteClockInNotification(defaults: defaults, isActive: { active },
                canNotify: { permitted }, post: { posted.append($0) })
        }
        let notifier = makeNotifier()
        notifier.start(store: store)
        store.clockIn(at: date)
        await notifier.finishPendingUpdates()
        check(posted.isEmpty, "own clock-in never notifies")
        let own = store.data
        check(store.applySynced(own), "local echo persists")
        await notifier.finishPendingUpdates()
        check(posted.isEmpty, "own clock-in echo never notifies")
        store.cancelRunning()
        check(store.applySynced(own), "late local echo persists")
        await notifier.finishPendingUpdates()
        check(posted.isEmpty, "own start remains suppressed after idle")
        func remote(_ offset: Double, paused: Bool = false) -> ClockinData {
            var data = ClockinData()
            let start = date.addingTimeInterval(offset)
            data.running = RunningSession(start: start, accumulated: 0, resumedAt: paused ? nil : start, note: "private")
            return data
        }
        let other = remote(120)
        check(store.applySynced(other), "other device start persists")
        await notifier.finishPendingUpdates()
        check(posted == [date.addingTimeInterval(120)], "remote start notifies once by default")
        check(store.applySynced(other), "remote echo persists")
        await notifier.finishPendingUpdates()
        check(posted.count == 1, "sync echo does not notify twice")
        _ = store.applySynced(ClockinData())
        let restarted = makeNotifier()
        restarted.start(store: store)
        _ = store.applySynced(other)
        await restarted.finishPendingUpdates()
        await notifier.finishPendingUpdates()
        check(posted.count == 1, "already notified start survives relaunch and idle")
        active = true
        _ = store.applySynced(remote(240))
        await notifier.finishPendingUpdates()
        check(posted.count == 1, "active app does not notify")
        active = false
        _ = store.applySynced(remote(240, paused: true))
        await notifier.finishPendingUpdates()
        check(posted.count == 1, "foreground arrival cannot later notify on pause echo")
        defaults.set(false, forKey: RemoteClockInNotification.enabledKey)
        _ = store.applySynced(remote(360))
        await notifier.finishPendingUpdates()
        check(posted.count == 1, "device-local opt-out suppresses notification")
        defaults.set(true, forKey: RemoteClockInNotification.enabledKey)
        permitted = false
        _ = store.applySynced(remote(480))
        await notifier.finishPendingUpdates()
        check(posted.count == 1, "missing notification permission is respected")
        permitted = true
        _ = store.applySynced(remote(600))
        active = true
        await notifier.finishPendingUpdates()
        check(posted.count == 1, "activation before async delivery suppresses notification")
        active = false
        _ = store.applySynced(remote(720))
        _ = store.applySynced(ClockinData())
        await notifier.finishPendingUpdates()
        check(posted.count == 1, "clock-out before delivery suppresses obsolete notification")
        let blocker = directory.appending(path: "blocker")
        try Data().write(to: blocker)
        let broken = ClockStore(fileURL: blocker.appending(path: "clock.json"))
        let brokenNotifier = makeNotifier()
        brokenNotifier.start(store: broken)
        check(!broken.applySynced(remote(840)), "failed archive apply is rejected")
        await brokenNotifier.finishPendingUpdates()
        check(posted.count == 1, "failed archive apply never notifies")
        print("All \(count) iPhone follow checks passed.")
    }
}
