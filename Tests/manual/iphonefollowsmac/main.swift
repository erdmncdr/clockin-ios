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

        let loadedURL = directory.appending(path: "loaded.json")
        let beforeUpgrade = ClockStore(fileURL: loadedURL, now: { date })
        beforeUpgrade.clockIn(at: date.addingTimeInterval(-1200))
        let loaded = ClockStore(fileURL: loadedURL, now: { date })
        let loadedNotifier = makeNotifier()
        loadedNotifier.start(store: loaded)
        var edited = loaded.data
        check(edited.running != nil, "upgrade fixture loads the existing phone timer")
        loaded.cancelRunning()
        edited.running?.resumedAt = nil
        _ = loaded.applySynced(edited)
        await loadedNotifier.finishPendingUpdates()
        check(posted.count == 1, "upgrade/load then discard then remote edit stays silent without an echo first")

        let backup = directory.appending(path: "restore.json")
        var restored = remote(-600)
        try JSONEncoder().encode(restored).write(to: backup)
        loaded.cancelRunning()
        check(loaded.restoreBackup(from: backup), "valid running backup restores")
        await loadedNotifier.finishPendingUpdates()
        check(posted.count == 1, "successful restore itself stays silent")
        loaded.cancelRunning()
        restored.running?.resumedAt = nil
        _ = loaded.applySynced(restored)
        await loadedNotifier.finishPendingUpdates()
        check(posted.count == 1, "restore then discard then remote edit stays silent")

        let same = remote(-300).running!
        loaded.didApplySyncedRunning.send((previous: same, current: same, provenance: .remoteChange))
        loaded.cancelRunning()
        _ = loaded.applySynced(remote(-300, paused: true))
        await loadedNotifier.finishPendingUpdates()
        check(posted.count == 1, "same-start sync arrival establishes a silent baseline")

        let historyDomain = domain + "-history"
        let historyDefaults = UserDefaults(suiteName: historyDomain)!
        defer { historyDefaults.removePersistentDomain(forName: historyDomain) }
        historyDefaults.set(false, forKey: RemoteClockInNotification.enabledKey)
        let legacy = (0..<1500).map { date.addingTimeInterval(Double($0) - 10000) }
        historyDefaults.set(legacy, forKey: RemoteClockInNotification.handledStartsKey)
        let historyStore = ClockStore(fileURL: directory.appending(path: "history.json"), now: { date })
        var historyPosts: [Date] = []
        func historyNotifier() -> RemoteClockInNotification {
            RemoteClockInNotification(defaults: historyDefaults, isActive: { false },
                canNotify: { true }, post: { historyPosts.append($0) })
        }
        func recentCount() -> Int {
            (historyDefaults.array(forKey: RemoteClockInNotification.handledStartsKey) as? [Date] ?? []).count
        }
        var history: RemoteClockInNotification? = historyNotifier()
        history!.start(store: historyStore)
        check(recentCount() <= 256, "legacy unbounded history is pruned on idle attachment while setting is off")
        for i in 0..<1500 {
            historyStore.clockIn(at: date.addingTimeInterval(Double(i) - 5000))
            historyStore.cancelRunning()
        }
        check(recentCount() <= 256 && historyPosts.isEmpty, "1500 local starts remain bounded while notifications are off")
        let localCutoff = historyDefaults.object(forKey: RemoteClockInNotification.handledCutoffKey) as? Date
        check(localCutoff != nil, "pruning persists a notification eligibility cutoff")
        for i in 0..<400 { _ = historyStore.applySynced(remote(Double(i) - 2000)) }
        await history!.finishPendingUpdates()
        let cutoff = historyDefaults.object(forKey: RemoteClockInNotification.handledCutoffKey) as! Date
        check(recentCount() <= 256 && cutoff > localCutoff! && historyPosts.isEmpty,
              "remote arrivals also prune and advance cutoff while opted out")
        history = nil
        historyStore.cancelRunning()
        historyDefaults.set(true, forKey: RemoteClockInNotification.enabledKey)
        let reopened = historyNotifier()
        reopened.start(store: historyStore)
        _ = historyStore.applySynced(remote(-10000))
        await reopened.finishPendingUpdates()
        check(historyPosts.isEmpty, "evicted legacy start cannot notify after notifier recreation")
        _ = historyStore.applySynced(remote(-5000))
        await reopened.finishPendingUpdates()
        check(historyPosts.isEmpty, "evicted local start cannot notify after re-enabling")
        _ = historyStore.applySynced(remote(-1601))
        await reopened.finishPendingUpdates()
        check(historyPosts.isEmpty, "recent retained local start also stays silent")
        var boundary = remote(-1601)
        boundary.running?.start = cutoff
        _ = historyStore.applySynced(boundary)
        await reopened.finishPendingUpdates()
        check(historyPosts.isEmpty, "cutoff equality is ineligible after relaunch")
        _ = historyStore.applySynced(remote(-30000))
        await reopened.finishPendingUpdates()
        check(historyPosts.isEmpty && historyDefaults.object(forKey: RemoteClockInNotification.handledCutoffKey) as? Date == cutoff,
              "previously unseen start below watermark is silent and cannot move cutoff backwards")
        _ = historyStore.applySynced(remote(-1000))
        await reopened.finishPendingUpdates()
        check(historyPosts == [date.addingTimeInterval(-1000)], "new remote start above retained cutoff still notifies")
        print("All \(count) iPhone follow checks passed.")
    }
}
