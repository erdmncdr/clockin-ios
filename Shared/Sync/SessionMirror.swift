#if !WIDGET_EXTENSION
import ActivityKit
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
    private var lastSnapshot: ClockinSnapshot?
    private var lastState: ClockinActivityAttributes.ContentState?
    private var isRestartingActivity = false
    private var activityTask: Task<Void, Never>?

    func start(observing store: ClockStore) {
        self.store = store
        // `objectWillChange` deger yazilmadan once gelir; yeni degeri okumak
        // icin bir sonraki turda senkronlanir.
        subscription = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
        sync()
    }

    func refresh() {
        sync()
    }

    // Bildirim yaniti tamamlanmadan arka plan aynalarini bitir.
    func finishPendingUpdates() async {
        await LongSessionReminderController.shared.finishPendingUpdates()
        await FocusChimeController.shared.finishPendingUpdates()
        await NudgeController.shared.finishPendingUpdates()
        await activityTask?.value
    }

    private func sync() {
        guard let store else { return }
        // Standart UserDefaults uzantidan okunamaz. Temayi mevcut atomik
        // ozete eklemek ikinci bir paylasim kanali gerektirmez; tema degisimi
        // de esitsizlik yaratarak timeline ve acik etkinligi yeniler.
        let theme = ClockinThemeChoice.selected(UserDefaults.standard.string(forKey: "Clockin.Theme") ?? "Carbon")
        let snapshot = ClockinSnapshot(store: store, theme: theme)
        if snapshot != lastSnapshot {
            do {
                try snapshot.write()
                lastSnapshot = snapshot
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                // Basarisiz yazimi onbellege alma; sonraki yenileme tekrar dener.
            }
        }
        LongSessionReminderController.shared.update(running: store.running)
        syncChimes(running: store.running)
        NudgeController.shared.update(store: store)
        syncActivity(running: store.running, hourlyRate: snapshot.hourlyRate,
                     earned: store.currentEarnings(at: .now), currencyCode: store.currencyCode, theme: theme)
    }

    /// Odak cani burada yeniden kurulur, gorunumde degil.
    ///
    /// Once `RootView` izliyordu. Kilit ekranindaki Live Activity dugmesi ya da
    /// Kisayollar mesaiyi bitirdiginde uygulama arka planda, hicbir ekran
    /// yuklenmeden calisiyor; bekleyen yirmi bildirim silinmiyor ve mesai
    /// bittikten sonra saatlerce calmaya devam ediyordu.
    private func syncChimes(running: RunningSession?) {
        let defaults = UserDefaults.standard
        FocusChimeController.shared.update(
            running: running,
            enabled: defaults.bool(forKey: "Clockin.ChimeEnabled"),
            interval: defaults.integer(forKey: "Clockin.ChimeIntervalMinutes"),
            sound: defaults.string(forKey: "Clockin.ChimeSound") ?? FocusChimeSound.notification.rawValue
        )
    }

    private func syncActivity(running: RunningSession?, hourlyRate: Double, earned: Double, currencyCode: String, theme: ClockinThemeChoice) {
        guard let running else {
            lastState = nil
            enqueueActivityOperation { await Self.endAll() }
            return
        }
        let state = ClockinActivityAttributes.ContentState(
            running: running, hourlyRate: hourlyRate, earned: earned,
            usdTryRate: currencyCode == "USD" ? SharedStore.exchangeRates.latestRate : nil,
            theme: theme
        )
        // Yeniden kurulum surerken gelen senkronlar atlanir; yoksa eski etkinlik
        // kapanmadan ikinci bir etkinlik istenebilirdi.
        guard !isRestartingActivity else { return }
        let activities = Activity<ClockinActivityAttributes>.activities
        let content = ActivityContent(state: state, staleDate: state.staleDate)
        // Para birimi yalnizca etkinlik baslatilirken sabit alanlara yaziliyor;
        // guncellemeler onu degistiremez. Birim degistiyse etkinlik kapatilip
        // yeni birimle yeniden baslatilir, yoksa kilit ekrani eski birimde kalir.
        if activities.contains(where: { $0.attributes.currencyCode != currencyCode }) {
            isRestartingActivity = true
            lastState = state
            enqueueActivityOperation { [weak self] in
                await Self.endAll()
                Self.request(currencyCode: currencyCode, content: content)
                self?.isRestartingActivity = false
                // Bekleme sirasinda tema degismisse en son secimi de aktar.
                self?.sync()
            }
            return
        }
        guard state != lastState || activities.isEmpty else { return }
        lastState = state
        if activities.isEmpty {
            enqueueActivityOperation {
                if Activity<ClockinActivityAttributes>.activities.isEmpty {
                    Self.request(currencyCode: currencyCode, content: content)
                } else {
                    await Self.updateAll(content)
                }
            }
        } else {
            enqueueActivityOperation { await Self.updateAll(content) }
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

    private static func request(currencyCode: String, content: ActivityContent<ClockinActivityAttributes.ContentState>) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(
            attributes: ClockinActivityAttributes(currencyCode: currencyCode),
            content: content
        )
    }

    // `Activity` Sendable degil; ana aktorden bir goreve gecirilemiyor. Bu
    // yuzden etkinlikler ana aktor disinda, kullanildiklari yerde alinir.
    nonisolated private static func endAll() async {
        for activity in Activity<ClockinActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    nonisolated private static func updateAll(_ content: ActivityContent<ClockinActivityAttributes.ContentState>) async {
        for activity in Activity<ClockinActivityAttributes>.activities {
            await activity.update(content)
        }
    }
}
#endif
