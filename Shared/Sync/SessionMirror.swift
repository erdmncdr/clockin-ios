#if !WIDGET_EXTENSION
#if os(iOS)
import ActivityKit
import UIKit
#endif
import Combine
import Foundation
import WidgetKit

/// Magaza degistikce widget ozetini yazar ve Live Activity'yi gunceller.
///
/// Gorunumlerde degil burada: Kisayollar uygulamayi arka planda
/// baslattiginda hicbir ekran yuklenmez, ama widget ve kilit ekrani yine
/// guncellenmeli.
@MainActor
final class SessionMirror {
    static let shared = SessionMirror()

    private weak var store: ClockStore?
    private var subscription: AnyCancellable?
    private var companionSubscriptions: Set<AnyCancellable> = []
    private var moodSubscription: AnyCancellable?
    private var lastSnapshot: ClockinSnapshot?
    #if os(iOS)
    private var lastState: ClockinActivityAttributes.ContentState?
    private var activityTask: Task<Void, Never>?
    #endif

    func start(observing store: ClockStore) {
        self.store = store
        #if os(iOS)
        LiveActivityPush.shared.retryPendingDeletions()
        #endif
        // `objectWillChange` deger yazilmadan once gelir; yeni degeri okumak
        // icin bir sonraki turda senkronlanir.
        subscription = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
        moodSubscription = NudgeController.shared.$mood
            .map { $0?.isAngry == true }
            .removeDuplicates()
            .sink { [weak self] angry in
                // Published yeni degeri once yollar; controller tekrar okunmaz.
                self?.syncSnapshot(angry: angry)
            }
        companionSubscriptions.removeAll()
        CelebrationCenter.shared.$snapshotDate.sink { [weak self] _ in
            Task { @MainActor in self?.refreshCompanion() }
        }.store(in: &companionSubscriptions)
        CelebrationCenter.shared.$proudUntil.removeDuplicates().sink { [weak self] _ in
            Task { @MainActor in self?.refreshCompanion() }
        }.store(in: &companionSubscriptions)
        sync()
    }

    func refreshCompanion() {
        syncSnapshot(angry: NudgeController.shared.mood?.isAngry == true)
    }

    func refresh() {
        #if os(iOS)
        LiveActivityPush.shared.retryPendingDeletions()
        #endif
        sync()
    }

    // Uzun omurlu gorevler ayarlari yeniden okusun; baslarken aldiklari
    // `@AppStorage` degerleri eskimis olabilir.
    func refreshChimes(force: Bool = false) {
        guard let store else { return }
        syncChimes(running: store.running, force: force)
    }

    // Bildirim yaniti tamamlanmadan arka plan aynalarini bitir.
    func finishPendingUpdates() async {
        // Also reconcile synchronously: objectWillChange schedules a later task,
        // which must not be the only route from a silent fetch to clock-out.
        sync()
        #if os(iOS)
        // End the card before waiting for notification scheduling/network cleanup.
        await activityTask?.value
        await RemoteClockInNotification.shared.finishPendingUpdates()
        #endif
        await LongSessionReminderController.shared.finishPendingUpdates()
        await FocusChimeController.shared.finishPendingUpdates()
        await NudgeController.shared.finishPendingUpdates()
        #if os(iOS)
        await LiveActivityPush.shared.finishPendingUploads()
        #endif
    }

    private func sync() {
        guard let store else { return }
        // Standart UserDefaults uzantidan okunamaz. Temayi mevcut atomik
        // ozete eklemek ikinci bir paylasim kanali gerektirmez; tema degisimi
        // de esitsizlik yaratarak timeline ve acik etkinligi yeniler.
        CelebrationCenter.shared.refresh(store: store)
        let theme = ClockinThemeChoice.selected(UserDefaults.standard.string(forKey: "Clockin.Theme") ?? "Carbon")
        let snapshot = syncSnapshot(angry: NudgeController.shared.mood?.isAngry == true)
        LongSessionReminderController.shared.update(running: store.running)
        syncChimes(running: store.running)
        NudgeController.shared.update(store: store)
        #if os(iOS)
        syncActivity(running: store.running, hourlyRate: snapshot?.hourlyRate ?? 0,
                     earned: store.currentEarnings(at: .now), currencyCode: store.currencyCode, theme: theme)
        #endif
    }

    @discardableResult
    private func syncSnapshot(angry: Bool) -> ClockinSnapshot? {
        guard let store else { return nil }
        let theme = ClockinThemeChoice.selected(UserDefaults.standard.string(forKey: "Clockin.Theme") ?? "Carbon")
        var snapshot = ClockinSnapshot(store: store, theme: theme)
        snapshot.font = .selected(UserDefaults.standard.string(forKey: ClockinFontChoice.preferenceKey))
        snapshot.isAngry = angry && store.running?.isPaused != false
        snapshot.companionFriendly = UserDefaults.standard.string(forKey: NudgePlanner.toneKey) == NudgeTone.friendly.rawValue
        snapshot.companionLastWorkedDay = CelebrationCenter.shared.lastWorkedDay
        snapshot.companionProudUntil = CelebrationCenter.shared.proudUntil
        snapshot.wardrobeJSON = WardrobeStore.shared.state.json
        snapshot.companionAccessoryID = CompanionAccessory.resolve(
            UserDefaults.standard.string(forKey: CompanionAccessory.storageKey) ?? "Auto",
            totalHours: (store.totalDuration + store.elapsed()) / 3600)?.id
        if snapshot != lastSnapshot {
            do {
                try snapshot.write()
                lastSnapshot = snapshot
                WidgetCenter.shared.reloadAllTimelines()
                #if os(iOS)
                if #available(iOS 18.0, *) {
                    ControlCenter.shared.reloadAllControls()
                }
                #endif
            } catch {
                // Basarisiz yazim sonraki yenilemede tekrar denenir.
            }
        }
        return snapshot
    }

    /// Odak cani burada yeniden kurulur, gorunumde degil.
    ///
    /// Once `RootView` izliyordu. Kilit ekranindaki Live Activity dugmesi ya da
    /// Kisayollar mesaiyi bitirdiginde uygulama arka planda, hicbir ekran
    /// yuklenmeden calisiyor; bekleyen yirmi bildirim silinmiyor ve mesai
    /// bittikten sonra saatlerce calmaya devam ediyordu.
    private func syncChimes(running: RunningSession?, force: Bool = false) {
        let defaults = UserDefaults.standard
        FocusChimeController.shared.update(
            running: running,
            enabled: defaults.bool(forKey: "Clockin.ChimeEnabled"),
            interval: defaults.integer(forKey: "Clockin.ChimeIntervalMinutes"),
            // Salt okuma: tazeleme tercihi geri yazarsa senkronla gelen secimi ezip yankilar.
            sound: FocusChimeSound.selected(defaults.string(forKey: FocusChimeSound.preferenceKey)).rawValue,
            force: force
        )
    }

    #if os(iOS)
    private func syncActivity(running: RunningSession?, hourlyRate: Double, earned: Double, currencyCode: String, theme: ClockinThemeChoice) {
        guard let running else {
            lastState = nil
            enqueueActivityOperation { await Self.endAll() }
            return
        }
        let state = ClockinActivityAttributes.ContentState(
            running: running, hourlyRate: hourlyRate, earned: earned,
            usdTryRate: currencyCode == "USD" ? SharedStore.exchangeRates.latestRate : nil,
            theme: theme, font: .selected(UserDefaults.standard.string(forKey: ClockinFontChoice.preferenceKey))
        )
        lastState = state
        enqueueActivityOperation { [weak self] in
            guard self?.lastState == state else { return }
            let activities = Activity<ClockinActivityAttributes>.activities.sorted { $0.id < $1.id }
            let content = ActivityContent(state: state, staleDate: state.staleDate)
            let remote = LiveActivityPrivacy.enabled && LiveActivityPush.endpoint != nil && !state.isPaused
            let matching = activities.first { activity in
                guard activity.attributes.currencyCode == currencyCode else { return false }
                if remote {
                    return activity.attributes.remoteUpdatesUntil != nil
                        && activity.attributes.localState?.hasSameCalculation(as: state) == true
                }
                return activity.attributes.remoteUpdatesUntil == nil
            }
            // Kesilmis bir degisimden kalan uygun karti once bul. Yeni istek
            // reddedilse bile eski kartlar ve relay kayitlari temizlenebilmeli.
            let retainedID = (matching ?? activities.first)?.id
            if let retainedID { await Self.endAll(except: retainedID) }
            if !LiveActivityPrivacy.enabled {
                for activity in activities where activity.id == retainedID {
                    await LiveActivityPush.shared.stop(id: activity.id, token: activity.pushToken,
                        expiresAt: activity.attributes.remoteUpdatesUntil)
                }
            }
            guard self?.lastState == state else { return }
            switch LiveActivityDecision.action(running: true, hasActivity: !activities.isEmpty,
                needsReplacement: matching == nil, appIsActive: UIApplication.shared.applicationState == .active) {
            case .request:
                _ = Self.request(currencyCode: currencyCode, content: content)
            case .replace:
                // Tek yedek kart, istek basarisiz olursa yerinde kalir. Islem
                // yeni karttan sonra kesilirse sonraki yenileme onu secer.
                if let replacementID = Self.request(currencyCode: currencyCode, content: content) {
                    await Self.endAll(except: replacementID)
                }
            case .keep:
                // Eski relay tick'i sabit localState'i geri getirebilir;
                // yedek karti degistirmeden on plan yenilemesini bekle.
                break
            case .update:
                await Self.updateAll(content)
                for activity in Activity<ClockinActivityAttributes>.activities {
                    LiveActivityPush.shared.observe(activity)
                }
            case .end:
                await Self.endAll()
            }
        }
    }

    // Hizli tema degisikliklerinde eski bir async guncelleme yenisini ezmesin.
    private func enqueueActivityOperation(_ operation: @escaping @MainActor @Sendable () async -> Void) {
        let previous = activityTask
        activityTask = Task {
            await previous?.value
            await operation()
        }
    }

    private static func request(currencyCode: String, content: ActivityContent<ClockinActivityAttributes.ContentState>) -> String? {
        let remote = LiveActivityPrivacy.enabled && LiveActivityPush.endpoint != nil && !content.state.isPaused
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            if remote { LiveActivityPush.shared.activityCouldNotStart() }
            return nil
        }
        if let activity = try? Activity.request(
            attributes: ClockinActivityAttributes(currencyCode: currencyCode,
                remoteUpdatesUntil: remote ? .now.addingTimeInterval(8 * 3600) : nil,
                localState: remote ? content.state : nil),
            content: content, pushType: remote ? .token : nil
        ) {
            LiveActivityPush.shared.observe(activity)
            return activity.id
        } else if remote {
            LiveActivityPush.shared.activityCouldNotStart()
        }
        return nil
    }

    // `Activity` Sendable degil; ana aktorden bir goreve gecirilemiyor. Bu
    // yuzden etkinlikler ana aktor disinda, kullanildiklari yerde alinir.
    nonisolated private static func endAll(except retainedID: String? = nil) async {
        for activity in Activity<ClockinActivityAttributes>.activities where activity.id != retainedID {
            let id = activity.id
            let token = activity.pushToken
            let expiry = activity.attributes.remoteUpdatesUntil
            await activity.end(nil, dismissalPolicy: .immediate)
            await LiveActivityPush.shared.stop(id: id, token: token, expiresAt: expiry)
        }
    }

    nonisolated private static func updateAll(_ content: ActivityContent<ClockinActivityAttributes.ContentState>) async {
        for activity in Activity<ClockinActivityAttributes>.activities {
            await activity.update(content)
        }
    }
    #endif
}
#endif
