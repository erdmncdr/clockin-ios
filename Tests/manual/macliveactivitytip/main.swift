import Combine
import Foundation

var checks = 0
@MainActor func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { print("FAILED: \(message)"); exit(1) }
    checks += 1
    print("ok: \(message)")
}

MainActor.assumeIsolated {
    let directory = FileManager.default.temporaryDirectory.appending(path: "clockin-tip-\(UUID())")
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let suite = "clockin-tip-\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let date = Date(timeIntervalSince1970: 1_790_000_000)
    @MainActor func makeStore(_ name: String) -> ClockStore {
        ClockStore(fileURL: directory.appending(path: name + ".json"), now: { date })
    }
    @MainActor func freshTip(_ store: ClockStore) -> MacLiveActivityTip {
        defaults.removePersistentDomain(forName: suite)
        let tip = MacLiveActivityTip(defaults: defaults)
        tip.start(store: store)
        return tip
    }
    func remote(_ start: Date, paused: Bool = false) -> ClockinData {
        var data = ClockinData()
        data.running = RunningSession(start: start, accumulated: 0,
                                      resumedAt: paused ? nil : start, note: "remote")
        return data
    }

    let store = makeStore("normal")
    let tip = freshTip(store)
    check(!tip.isVisible, "idle launch does not show the tip")
    check(store.applySynced(ClockinData()) && !tip.isVisible, "history/settings-only sync does not qualify")
    store.clockIn(at: date)
    check(!tip.isVisible, "local clock-in never shows the tip")
    check(defaults.object(forKey: MacLiveActivityTip.localStartKey) as? Date == date,
          "successful local clock-in remembers its start on this Mac")
    var echo = store.data
    check(store.applySynced(echo) && !tip.isVisible, "local timer echoed through sync does not qualify")
    echo.running?.resumedAt = nil
    check(store.applySynced(echo) && !tip.isVisible, "remote pause of a locally started timer does not qualify")
    echo.running?.resumedAt = date.addingTimeInterval(60)
    check(store.applySynced(echo) && !tip.isVisible, "remote resume of a locally started timer does not qualify")
    store.cancelRunning()
    let reopened = makeStore("normal")
    let reopenedTip = MacLiveActivityTip(defaults: defaults)
    reopenedTip.start(store: reopened)
    check(reopened.applySynced(echo) && !reopenedTip.isVisible,
          "local origin survives restart even if the previous visible timer is nil")

    var localWrites = 0
    let observation = reopened.didPersist.sink { localWrites += 1 }
    let elsewhere = remote(date.addingTimeInterval(120))
    check(reopened.applySynced(elsewhere) && reopenedTip.isVisible,
          "a new running session arriving from sync qualifies, including replacement of a local timer")
    check(localWrites == 0, "tip observation does not echo a synced apply as a local write")
    check(reopened.running == elsewhere.running, "tip leaves the applied timer untouched")
    check(MacLiveActivityTip(defaults: defaults).isVisible, "undismissed advice survives restart")
    reopenedTip.dismiss()
    check(!reopenedTip.isVisible && defaults.bool(forKey: MacLiveActivityTip.dismissedKey),
          "close hides shared state and persists dismissal")
    check(reopened.applySynced(remote(date.addingTimeInterval(240))) && !reopenedTip.isVisible,
          "later remote timers never show dismissed advice again")
    let dismissed = MacLiveActivityTip(defaults: defaults)
    dismissed.start(store: reopened)
    check(!dismissed.isVisible, "dismissal survives restart")
    withExtendedLifetime(observation) {}

    let pausedStore = makeStore("paused")
    let pausedTip = freshTip(pausedStore)
    check(pausedStore.applySynced(remote(date, paused: true)) && pausedTip.isVisible,
          "a paused remote active session also qualifies because its Live Activity can mirror")

    // An archive restored before observation is not evidence that the Mac just received sync.
    let restored = makeStore("restored")
    restored.clockIn(at: date)
    let restoredStore = makeStore("restored")
    let restoredTip = freshTip(restoredStore)
    check(!restoredTip.isVisible, "loading an existing timer is not mistaken for a sync apply")
    check(restoredStore.applySynced(restoredStore.data) && !restoredTip.isVisible,
          "an existing timer's first identical sync echo is not mistaken for a remote start")

    // Force primary persistence to fail: a regular file cannot be an archive directory.
    let blocker = directory.appending(path: "blocker")
    try! Data("block".utf8).write(to: blocker)
    let broken = ClockStore(fileURL: blocker.appending(path: "clock.json"), now: { date })
    let brokenTip = freshTip(broken)
    broken.clockIn(at: date)
    check(broken.running == nil && defaults.object(forKey: MacLiveActivityTip.localStartKey) == nil,
          "failed local persistence never records a successful clock-in")
    check(!broken.applySynced(remote(date)) && !brokenTip.isVisible,
          "failed sync persistence never shows the tip")
    check(broken.running == nil, "failed sync persistence retains the previous timer")

    let otherSuite = "clockin-tip-other-mac-\(UUID())"
    let otherDefaults = UserDefaults(suiteName: otherSuite)!
    defer { otherDefaults.removePersistentDomain(forName: otherSuite) }
    let otherTip = MacLiveActivityTip(defaults: otherDefaults)
    otherTip.start(store: pausedStore)
    brokenTip.dismiss()
    check(pausedStore.applySynced(remote(date.addingTimeInterval(360))) && otherTip.isVisible,
          "one defaults domain's dismissal does not affect another Mac")

    var opened: [URL] = []
    check(IPhoneNotificationSettings.open { opened.append($0); return true }, "anchored opener reports success")
    check(opened.map(\.absoluteString) == ["x-apple.systempreferences:com.apple.Notifications-Settings.extension?RemoteNotificationSettings"],
          "successful anchored URL does not open the fallback")
    opened = []
    check(IPhoneNotificationSettings.open { opened.append($0); return opened.count == 2 },
          "failed anchored open falls back successfully")
    check(opened == [IPhoneNotificationSettings.anchoredURL, IPhoneNotificationSettings.fallbackURL],
          "fallback is the plain Notifications pane, in order")
    opened = []
    check(!IPhoneNotificationSettings.open { opened.append($0); return false } && opened.count == 2,
          "both URLs failing returns false without retry loops")
    print("All \(checks) Mac Live Activity tip checks passed.")
}
