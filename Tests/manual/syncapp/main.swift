import Combine
import Foundation

@MainActor final class FakeTransport: SyncTransport {
    let bridge: SyncBridge
    var status: SyncStatus = .off { didSet { didChange?() } }
    var lastSuccessfulSync: Date?
    var didChange: (@MainActor @Sendable () -> Void)?
    var launches = 0
    var sends = 0
    var stopped = false
    var afterSend: TestSignal?
    init(_ bridge: SyncBridge) { self.bridge = bridge }
    func launch() async {
        launches += 1
        do { try bridge.reconcileLocalArchive() } catch { status = .paused(.invalidData); return }
        await synchronize()
    }
    func synchronize() async {
        guard !stopped else { return }
        sends += 1; status = .syncing
        bridge.markFetchComplete(true); bridge.allowInitialUploadIfSafe()
        if bridge.state.permitsUpload {
            for key in bridge.state.pending {
                if let value = bridge.state.records[key] { bridge.acknowledge(value, fields: Data()) }
            }
        }
        _ = await bridge.persist()
        lastSuccessfulSync = .now
        status = bridge.state.needsFirstMergeReview ? .paused(.firstMerge) : .upToDate
        afterSend?.signal()
    }
    func accountMayHaveChanged() async { await launch() }
    func stop() async { stopped = true; status = .off }
    func deliver(_ snapshot: SyncSnapshot, date: Date) throws {
        var remote = SyncSidecar(deviceID: "other-device")
        try remote.capture(previous: nil, current: bridge.snapshot, at: date)
        try remote.capture(previous: bridge.snapshot, current: snapshot, at: date.addingTimeInterval(1))
        do {
            try bridge.receive(Array(remote.records.values))
            bridge.markFetchComplete(true)
        } catch {
            status = .paused(.invalidData)
            throw error
        }
    }
}

@MainActor final class Fixture {
    let directory: URL
    let domain = "syncapp-" + UUID().uuidString
    let languageDomain = "syncapp-language-" + UUID().uuidString
    let defaults: UserDefaults
    let language: UserDefaults
    let store: ClockStore
    let wardrobe: WardrobeStore
    let clock = ManualSyncClock()
    var transport: FakeTransport?
    var refreshes = 0
    var storeCreations = 0
    var wardrobeCreations = 0
    var languageAccesses = 0
    var transportCreations = 0
    var supported = true
    lazy var coordinator = SyncCoordinator(defaults: defaults, supportsSync: { [unowned self] in supported },
        makeStore: { [unowned self] in storeCreations += 1; return store },
        makeWardrobe: { [unowned self] in wardrobeCreations += 1; return wardrobe },
        languageDefaults: { [unowned self] in languageAccesses += 1; return language },
        makeTransport: { [unowned self] bridge in
            transportCreations += 1
            let fake = FakeTransport(bridge); transport = fake; return fake
        }, refreshServices: { [unowned self] in refreshes += 1 }, clock: clock)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("syncapp-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: domain)!
        language = UserDefaults(suiteName: languageDomain)!
        defaults.set("Carbon", forKey: "Clockin.Theme")
        defaults.set(4.0, forKey: "Clockin.GoalDailyHours")
        language.set("tr", forKey: AppLanguage.key)
        var state = WardrobeState(); state.seeded = true
        defaults.set(state.json, forKey: WardrobeState.stateKey)
        wardrobe = WardrobeStore(defaults: defaults)
        store = ClockStore(fileURL: directory.appendingPathComponent("clockin.json"))
    }
    func begin(approved: Bool = true) async throws {
        if approved {
            var state = SyncSidecar(deviceID: "this-device"); state.firstMergeCompleted = true
            try await SyncSidecarStore(archiveURL: store.archiveURL).save(state)
        }
        await coordinator.start()?.value
    }
    func notify() { NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults) }
    func cleanup() async {
        supported = false
        await coordinator.start()?.value
        clock.drain()
        defaults.removePersistentDomain(forName: domain)
        language.removePersistentDomain(forName: languageDomain)
        try? FileManager.default.removeItem(at: directory)
    }
}

@main struct SyncAppChecks {
    @MainActor static var count = 0
    @MainActor static func check(_ value: Bool, _ name: String) {
        guard value else { fatalError("FAILED: " + name) }
        count += 1
        try? FileHandle.standardOutput.write(contentsOf: Data(("ok: " + name + "\n").utf8))
    }
    @MainActor static func main() async throws {
        // Nothing gets constructed or mutated while either gate is off, even with triggers.
        for unsupported in [true, false] {
            let f = try Fixture()
            f.supported = !unsupported
            if !unsupported { f.defaults.set(false, forKey: SyncCoordinator.preferenceKey) }
            let archive = try Data(contentsOf: f.store.archiveURL)
            let preferences = f.defaults.dictionaryRepresentation() as NSDictionary
            check(!f.coordinator.isEnabled, "disabled capability/user setting is checked")
            await f.coordinator.start()?.value
            f.coordinator.sceneDidBecomeActive(); f.coordinator.accountMayHaveChanged()
            await f.coordinator.handleRemoteNotification()
            await f.coordinator.approveFirstMerge(); f.coordinator.postponeFirstMerge(); f.coordinator.acknowledge("absent")
            check(f.storeCreations + f.wardrobeCreations + f.languageAccesses + f.transportCreations == 0,
                  "disabled calls do not initialize stores, suites or transport")
            check(!FileManager.default.fileExists(atPath: f.directory.appendingPathComponent("sync-state.json").path), "disabled calls never open sidecar")
            check(try Data(contentsOf: f.store.archiveURL) == archive && f.defaults.dictionaryRepresentation() as NSDictionary == preferences,
                  "disabled calls preserve primary bytes and defaults")
            check(f.coordinator.status == .off && f.refreshes == 0, "disabled calls do not refresh services")
            await f.cleanup()
        }
        check(SyncCoordinator().isEnabled == false, "absent Info.plist key defaults to off")

        let f = try Fixture()
        try await f.begin()
        let fake = f.transport!
        check(f.coordinator.isEnabled && fake.launches == 1, "supported builds default to user sync on")
        check(f.coordinator.lastSuccessfulSync != nil && f.coordinator.status == .upToDate,
              "transport publishes successful sync date and status")
        check(fake.bridge.localSaveCount == 0, "load and initial reconciliation are not local save hooks")
        check(fake.bridge.snapshot.preferences[AppLanguage.key] == nil, "app language stays on this device")
        check(SyncPreferenceStore(standard: f.defaults, language: f.defaults).suite(for: AppLanguage.key) === f.defaults,
              "macOS language mapping supports standard defaults")

        f.store.clockIn(note: "a local timer", at: f.clock.now)
        check(fake.bridge.localSaveCount == 1, "one successful store save calls localDidSave exactly once synchronously")
        check(fake.bridge.snapshot.data.running == f.store.running
              && fake.bridge.snapshot.preferences["Clockin.Theme"] == .string("Carbon")
              && fake.bridge.snapshot.wardrobe == f.wardrobe.state
              && fake.bridge.snapshot.ledger == f.wardrobe.ledger, "store save captures the full snapshot together")
        await f.coordinator.start()?.value
        f.wardrobe.setHomeLamp(!f.wardrobe.state.homeLampOn)
        check(fake.bridge.localSaveCount == 2 && fake.bridge.snapshot.wardrobe == f.wardrobe.state,
              "wardrobe persistence is captured once with the current ledger")
        f.wardrobe.setHomeLamp(f.wardrobe.state.homeLampOn)
        check(fake.bridge.localSaveCount == 2, "no-op wardrobe refresh does not emit a save")
        await f.coordinator.start()?.value

        let beforePreferences = fake.bridge.localSaveCount
        f.defaults.set(117, forKey: "Clockin.UIScale"); f.notify()
        await f.coordinator.handleRemoteNotification()
        check(fake.bridge.localSaveCount == beforePreferences, "device-local preference changes are ignored")
        let registrations = f.clock.registrations
        f.defaults.set("Ocean", forKey: "Clockin.Theme"); f.notify()
        await f.clock.registered(registrations + 1)
        f.clock.advance(0.1)
        f.defaults.set(25, forKey: "Clockin.ChimeIntervalMinutes"); f.notify()
        await f.clock.registered(registrations + 2)
        f.clock.advance(0.1)
        // The language is device-local: it changes locally without scheduling a sync.
        f.language.set("en", forKey: AppLanguage.key); f.notify()
        check(fake.bridge.localSaveCount == beforePreferences, "preference bursts wait for debounce")
        let delivered = TestSignal(); fake.afterSend = delivered
        f.clock.advance(0.5)
        await delivered.wait()
        fake.afterSend = nil
        check(fake.bridge.localSaveCount == beforePreferences + 1, "debounce coalesces the burst into one localDidSave")
        check(fake.bridge.snapshot.preferences["Clockin.ChimeIntervalMinutes"] == .integer(25)
              && fake.bridge.snapshot.preferences[AppLanguage.key] == nil, "debounce captures allowlisted values and skips the language")

        f.store.setPinned(true)
        await f.coordinator.start()?.value
        let beforeApply = fake.bridge.localSaveCount
        var remote = fake.bridge.snapshot
        remote.data.pinVisible = false
        remote.data.running = nil
        remote.data.hourlyRate = 51
        remote.preferences["Clockin.Theme"] = .string("remote-theme")
        remote.preferences["Clockin.GoalDailyHours"] = nil
        remote.wardrobe.homeLampOn.toggle(); remote.wardrobe.seeded = false
        let item = WardrobeCatalog.items.first { $0.unlock.price != nil }!
        remote.wardrobe.owned.insert(item.id)
        remote.ledger = [.init(itemID: item.id, cost: item.unlock.price!, date: f.clock.now)]
        try fake.deliver(remote, date: f.clock.now.addingTimeInterval(10))
        f.notify()
        await f.coordinator.handleRemoteNotification()
        check(f.store.hourlyRate == 51 && f.store.running == nil, "remote state writes the real ClockStore")
        let saved = try JSONDecoder().decode(ClockinData.self, from: Data(contentsOf: f.store.archiveURL))
        check(saved.hourlyRate == 51 && saved.pinVisible && f.store.pinVisible, "pinVisible survives apply in memory and on disk")
        check(f.defaults.string(forKey: "Clockin.Theme") == "remote-theme"
              && f.defaults.object(forKey: "Clockin.GoalDailyHours") == nil, "remote preferences apply and absent keys reset")
        check(f.defaults.integer(forKey: "Clockin.UIScale") == 117 && f.language.string(forKey: AppLanguage.key) == "en"
              && f.defaults.object(forKey: AppLanguage.key) == nil, "remote apply preserves device keys, including the language")
        check(f.wardrobe.ledger == remote.ledger && f.wardrobe.state.homeLampOn == remote.wardrobe.homeLampOn
              && f.wardrobe.state.owned.contains(item.id) && f.wardrobe.state.seeded,
              "remote wardrobe and ledger persist together and retain local seeding")
        check(WardrobeStore(defaults: f.defaults).ledger == remote.ledger, "wardrobe ledger survives recreation")
        check(f.refreshes == 1 && fake.bridge.localSaveCount == beforeApply, "remote apply refreshes services and produces no store/defaults/wardrobe echo")
        check(!f.coordinator.recoveryInbox.isEmpty && f.coordinator.recoveryInbox.allSatisfy { $0.recoveredAt != nil && $0.fromDeviceID != nil },
              "recovery publishes source, capture time and replaced payload metadata")
        if let entry = f.coordinator.recoveryInbox.first {
            f.coordinator.acknowledge(entry.id)
            await f.coordinator.start()?.value
            check(!f.coordinator.recoveryInbox.contains { $0.id == entry.id }, "acknowledgment removes recovery entry")
        }

        // Primary write fails: no published replacement, no defaults/wardrobe mutation or refresh.
        let previousData = try SyncCoding.encode(f.store.data)
        let previousPrefs = f.defaults.dictionaryRepresentation() as NSDictionary
        let previousWardrobe = f.wardrobe.state
        let previousLedger = f.wardrobe.ledger
        let refreshes = f.refreshes
        var publications = 0
        let observation = f.store.$data.dropFirst().sink { _ in publications += 1 }
        try FileManager.default.removeItem(at: f.store.archiveURL)
        try FileManager.default.createDirectory(at: f.store.archiveURL, withIntermediateDirectories: false)
        var failedRemote = fake.bridge.snapshot
        failedRemote.data.hourlyRate = 99
        failedRemote.preferences["Clockin.Theme"] = .string("must-not-publish")
        failedRemote.wardrobe.homeLampOn.toggle()
        var failed = false
        do { try fake.deliver(failedRemote, date: f.clock.now.addingTimeInterval(30)) } catch { failed = true }
        check(try failed && SyncCoding.encode(f.store.data) == previousData && publications == 0,
              "failed primary apply leaves visible ClockStore unchanged without partial publication")
        check(f.defaults.dictionaryRepresentation() as NSDictionary == previousPrefs && f.wardrobe.state == previousWardrobe
              && f.wardrobe.ledger == previousLedger && f.refreshes == refreshes, "failed primary apply leaves preferences, wardrobe, ledger and services untouched")
        check(f.coordinator.status == .paused(.storage) && fake.bridge.localSaveCount == beforeApply, "failed apply reports storage error without echo")
        observation.cancel()
        f.store.clockIn(at: f.clock.now)
        check(fake.bridge.localSaveCount == beforeApply, "failed local write never emits didPersist")
        await f.cleanup()

        let burst = try Fixture(); try await burst.begin()
        let burstTransport = burst.transport!
        burst.defaults.set("unsent-local-theme", forKey: "Clockin.Theme"); burst.notify()
        await burst.clock.registered(1)
        var duringBurst = burstTransport.bridge.snapshot
        duringBurst.data.hourlyRate = 42
        try burstTransport.deliver(duringBurst, date: burst.clock.now.addingTimeInterval(10))
        check(burstTransport.bridge.localSaveCount == 1, "in-flight fetch flushes pending preference capture before merging")
        check(burst.coordinator.recoveryInbox.contains { entry in
            if case .preference(let key, .string(let value)) = entry.value {
                return key == "Clockin.Theme" && value == "unsent-local-theme"
            }
            return false
        }, "preference replaced during debounce is retained in recovery")
        await burst.coordinator.start()?.value
        burst.clock.drain()
        await burst.cleanup()

        let restored = try Fixture(); try await restored.begin()
        var restoredWardrobe = restored.wardrobe.state
        restoredWardrobe.homeLampOn.toggle()
        restored.defaults.set(restoredWardrobe.json, forKey: WardrobeState.stateKey)
        _ = restored.wardrobe.refresh(sessions: [], now: restored.clock.now, dailyGoal: 4)
        check(restored.transport!.bridge.localSaveCount == 1
              && restored.transport!.bridge.snapshot.wardrobe.homeLampOn == restoredWardrobe.homeLampOn,
              "wardrobe refresh captures externally persisted backup restoration once")
        await restored.cleanup()

        let invalid = try Fixture(); try await invalid.begin()
        let invalidTransport = invalid.transport!
        invalid.store.clockIn(note: String(repeating: "x", count: 2001), at: invalid.clock.now)
        check(invalid.coordinator.issues.contains { $0.kind == .localValue && $0.recordKey == "Running:Running" },
              "over-limit local value is published as an issue and kept locally")
        var validSibling = invalidTransport.bridge.snapshot
        validSibling.data.hourlyRate = 62
        try invalidTransport.deliver(validSibling, date: invalid.clock.now.addingTimeInterval(10))
        check(invalid.store.hourlyRate == 62 && invalid.store.running?.note.count == 2001,
              "whole-snapshot validation preserves unchanged local-only invalid values while applying valid remote siblings")
        var rejected = invalidTransport.bridge.state.records.values.first!
        rejected.schema = 99
        try invalidTransport.bridge.receive([rejected])
        check(invalid.coordinator.issues.contains { $0.kind == .quarantine && $0.quarantine != nil },
              "quarantine issues expose review bytes without publishing raw diagnostics as UI copy")
        let oldTransport = invalidTransport
        invalid.coordinator.setSyncEnabled(false)
        invalid.coordinator.setSyncEnabled(true)
        await invalid.coordinator.start()?.value
        check(oldTransport.stopped && invalid.transport !== oldTransport,
              "fast off/on drains the previous worker before reopening sidecar and transport")
        await invalid.cleanup()

        // First merge uses the real backup/approval gate; postpone cannot apply or upload foreign data.
        let review = try Fixture(); try await review.begin(approved: false)
        let reviewTransport = review.transport!
        var foreign = reviewTransport.bridge.snapshot
        foreign.data.sessions = [.init(id: UUID(), start: review.clock.now.addingTimeInterval(-3600), end: review.clock.now,
                                      duration: 3600, note: "other device", hourlyRate: 25, source: "Clockin")]
        try reviewTransport.deliver(foreign, date: review.clock.now.addingTimeInterval(10))
        check(review.coordinator.pendingFirstMerge?.remoteCount == 1 && review.store.sessions.isEmpty, "first merge preview publishes foreign counts without applying")
        review.coordinator.postponeFirstMerge()
        check(review.coordinator.status == .paused(.postponed) && review.store.sessions.isEmpty, "postpone keeps local state and pending preview")
        review.defaults.set("changed-after-preview", forKey: "Clockin.Theme"); review.notify()
        await review.clock.registered(1)
        await review.coordinator.approveFirstMerge()
        check(review.store.sessions.isEmpty && review.coordinator.status == .paused(.firstMerge),
              "pending preference edits invalidate approval of a stale preview")
        await review.coordinator.start()?.value
        let beforeApproval = reviewTransport.bridge.localSaveCount
        await review.coordinator.approveFirstMerge()
        check(review.store.sessions.count == 1 && review.coordinator.pendingFirstMerge == nil
              && reviewTransport.bridge.state.firstBackupPath != nil, "approval backs up archive then applies and resumes sync")
        check(reviewTransport.bridge.localSaveCount == beforeApproval, "first merge approval produces no echo")
        review.coordinator.setSyncEnabled(false)
        await review.coordinator.start()?.value
        let offCount = reviewTransport.bridge.localSaveCount
        review.store.setPinned(true); review.wardrobe.setHomeLamp(false)
        check(reviewTransport.bridge.localSaveCount == offCount && review.coordinator.status == .off,
              "turning sync off detaches store hooks")
        await review.cleanup()
        print("All \(count) sync app checks passed.")
    }
}
