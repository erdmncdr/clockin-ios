import Combine
import Foundation
import UIKit

@MainActor
final class CelebrationCenter: ObservableObject {
    static let shared = CelebrationCenter()
    @Published private(set) var event: CelebrationEvent?
    @Published private(set) var presentationID = 0
    @Published private(set) var snapshot: InsightsSnapshot?
    @Published private(set) var hasBlockingPresentation = false
    @Published private(set) var proudUntil: Date?
    private var prideExpiry: Task<Void, Never>?
    private var pendingPride = false
    @Published private(set) var snapshotDate = Date.now
    private(set) var lastWorkedDay: Date?

    private let defaults: UserDefaults
    private var queue: CelebrationQueue
    weak var window: UIWindow?
    private var active = false
    private var blockers: Set<UUID> = []
    private var companions: [UUID: CelebrationVisibilityView] = [:]
    private var reactionOwner: UUID?
    private var visibleCompanions: [UUID] {
        guard defaults.object(forKey: "Clockin.MascotEnabled") as? Bool != false,
              !UIAccessibility.isReduceMotionEnabled else { return [] }
        return companions.filter { $0.value.isCompanionVisible }.map(\.key)
    }
    private var dismissal: Task<Void, Never>?
    private var releaseTasks: [UUID: Task<Void, Never>] = [:]
    private var soundedLevels: Set<Int> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        queue = CelebrationQueue(
            lastLevel: defaults.object(forKey: CelebrationRules.levelKey) as? Int,
            seenBadgeIDs: defaults.stringArray(forKey: CelebrationRules.badgesKey).map(Set.init),
            seenAccessoryIDs: defaults.stringArray(forKey: CompanionAccessory.seenKey).map(Set.init)
        )
    }

    deinit {
        dismissal?.cancel()
        prideExpiry?.cancel()
        releaseTasks.values.forEach { $0.cancel() }
    }

    #if DEBUG
    func previewLevelForReview() {
        var seed = CelebrationState(); seed.level = 499
        queue.ingest(seed, now: 0, canReact: false)
        seed.level = 500; seed.focusHours = 2495
        queue.ingest(seed, now: 1, canReact: false)
        setActive(true)
    }
    #endif

    // SessionMirror ve mevcut dakika yenilemesi tek ortak ozeti besler.
    func refresh(store: ClockStore, now: Date = .now) {
        let dailyGoal = defaults.double(forKey: "Clockin.GoalDailyHours")
        let wardrobe = WardrobeStore.shared.refresh(sessions: store.sessions, now: now, dailyGoal: dailyGoal)
        queue.wardrobeUnlocked(first: wardrobe.first, names: wardrobe.items.compactMap { WardrobeCatalog.item($0)?.name })
        let stats = InsightsSnapshot(store: store, now: now, dailyGoal: dailyGoal,
                                     monthlyGoal: defaults.double(forKey: "Clockin.GoalMonthlyHours"))
        snapshot = stats
        lastWorkedDay = stats.daily.filter { $0.value > 0 && $0.key <= now }.keys.max()
        snapshotDate = now
        let running = store.running
        let earnings = store.currentEarnings(at: now)
        let momentum = MoneyMomentum(hourlyRate: 0, currentEarnings: earnings,
                                     state: running == nil ? .idle : (running!.isPaused ? .paused : .working),
                                     currencyCode: store.currencyCode, usdTryRate: nil)
        var state = CelebrationState()
        state.level = stats.level
        state.totalHours = stats.totalDuration / 3600
        state.focusHours = Int(max(0, stats.totalDuration / 3600))
        state.badges = stats.badges.filter(\.unlocked).map { CelebrationBadge(id: $0.id, title: $0.title, icon: $0.icon) }
        state.day = Calendar.current.startOfDay(for: now)
        state.dailyHours = stats.daily[state.day, default: 0] / 3600
        state.dailyGoal = dailyGoal
        state.streak = stats.currentStreak
        state.sessionStart = running?.start
        state.paused = running?.isPaused ?? false
        state.earnings = earnings
        state.nextMoneyTarget = momentum.nextTarget
        state.currency = store.currencyCode
        if let previousStart = queue.previous?.sessionStart, running == nil {
            let saved = store.sessions.first { $0.start == previousStart }
            state.savedPreviousSession = saved != nil
            state.savedPreviousDuration = saved?.duration ?? 0
        }
        let earnedPride = CelebrationRules.earnsPride(from: queue.previous, to: state)
        let oldPending = queue.pending
        queue.ingest(state, now: ProcessInfo.processInfo.systemUptime,
                     canReact: active && UIApplication.shared.applicationState == .active && blockers.isEmpty && !visibleCompanions.isEmpty, includeAccessories: false)
        if earnedPride || queue.pending.contains(where: { $0.startsPride && !oldPending.contains($0) }) {
            // Widget olayi hemen alir; kapali kart sheet sonrasi kendi penceresini acar.
            showPride()
            pendingPride = true
        }
        persist()
        requestPresentation()
    }

    func companionState(running: RunningSession?, angry: Bool, friendly: Bool) -> MascotAsset {
        MascotAsset.session(running: running, angry: angry, friendly: friendly,
                            quietDays: MascotAsset.quietDays(since: lastWorkedDay, now: snapshotDate),
                            proudUntil: proudUntil)
    }

    private func showPride() {
        pendingPride = false
        prideExpiry?.cancel()
        proudUntil = Date.now.addingTimeInterval(CelebrationRules.proudDuration)
        prideExpiry = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(CelebrationRules.proudDuration)) } catch { return }
            self?.proudUntil = nil
            self?.prideExpiry = nil
        }
    }

    func setActive(_ value: Bool) {
        active = value
        if !value { suspend() } else { requestPresentation() }
    }

    func setCompanion(_ id: UUID, view: CelebrationVisibilityView?) {
        companions[id] = view
    }

    func reaction(for id: UUID) -> CelebrationReaction? {
        guard id == reactionOwner, case .reaction(let reaction) = event else { return nil }
        return reaction
    }

    func reserveTap() -> Bool {
        guard active, blockers.isEmpty else { return false }
        return queue.reserveTap(now: ProcessInfo.processInfo.systemUptime)
    }

    func setBlocked(_ id: UUID, _ blocked: Bool, waitForDismissal: Bool = true) {
        releaseTasks[id]?.cancel()
        releaseTasks[id] = nil
        if blocked {
            blockers.insert(id)
            hasBlockingPresentation = true
            suspend()
        } else if waitForDismissal, blockers.contains(id) {
            // Alert kapanisinin son karesiyle kutlama cakismasin.
            releaseTasks[id] = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
                guard let self else { return }
                self.releaseTasks[id] = nil
                self.blockers.remove(id)
                self.hasBlockingPresentation = !self.blockers.isEmpty
                self.requestPresentation()
            }
        } else {
            blockers.remove(id)
            hasBlockingPresentation = !blockers.isEmpty
            requestPresentation()
        }
    }

    func dismiss() {
        dismissal?.cancel()
        dismissal = nil
        queue.finish()
        event = nil
        requestPresentation()
    }

    private func suspend() {
        dismissal?.cancel()
        dismissal = nil
        queue.suspend()
        event = nil
    }

    private func requestPresentation() {
        guard event == nil, active, blockers.isEmpty else { return }
        dismissal?.cancel()
        // SwiftUI sunum baglantilari ayni olay turunda once yerlessin.
        dismissal = Task { [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, self.active, UIApplication.shared.applicationState == .active, self.blockers.isEmpty else { return }
            guard self.screenIsFree() else { self.queue.suspend(); return }
            self.queue.presentNext(active: true, blocked: false, companionVisible: !self.visibleCompanions.isEmpty,
                                   now: ProcessInfo.processInfo.systemUptime)
            if self.pendingPride { self.showPride() }
            guard let event = self.queue.current else { self.dismissal = nil; return }
            if event.startsPride { self.showPride() }
            self.reactionOwner = event.isReaction ? self.visibleCompanions.first : nil
            self.presentationID &+= 1
            self.event = event
            if case .levelUp(let level, _) = event, self.soundedLevels.insert(level).inserted {
                LevelUpHaptics.play(milestone: LevelPrestige(level: level).isMilestone)
            }
            self.persist()
            guard let delay = event.autoDismissDelay else {
                self.dismissal = nil
                return
            }
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard !Task.isCancelled else { return }
            self.dismiss()
        }
    }

    private func screenIsFree() -> Bool {
        guard let root = window?.rootViewController else { return false }
        func presented(in controller: UIViewController) -> UIViewController? {
            if let modal = controller.presentedViewController { return modal }
            return controller.children.lazy.compactMap { presented(in: $0) }.first
        }
        guard let modal = presented(in: root) else { return true }
        if let transition = modal.transitionCoordinator, modal.isBeingDismissed {
            transition.animate(alongsideTransition: nil) { [weak self] _ in
                Task { @MainActor in self?.requestPresentation() }
            }
        }
        return false
    }

    func screenAttached() { requestPresentation() }

    private func persist() {
        if let ids = queue.seenAccessoryIDs,
           defaults.stringArray(forKey: CompanionAccessory.seenKey).map(Set.init) != ids {
            defaults.set(ids.sorted(), forKey: CompanionAccessory.seenKey)
        }
        if let level = queue.lastLevel, defaults.object(forKey: CelebrationRules.levelKey) as? Int != level {
            defaults.set(level, forKey: CelebrationRules.levelKey)
        }
        if let ids = queue.seenBadgeIDs, Set(defaults.stringArray(forKey: CelebrationRules.badgesKey) ?? []) != ids
            || defaults.object(forKey: CelebrationRules.badgesKey) == nil {
            defaults.set(ids.sorted(), forKey: CelebrationRules.badgesKey)
        }
    }
}

extension CelebrationEvent {
    var isReaction: Bool { if case .reaction = self { return true }; return false }
}
