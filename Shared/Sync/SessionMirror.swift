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

    private func sync() {
        guard let store else { return }
        let snapshot = ClockinSnapshot(store: store)
        if snapshot != lastSnapshot {
            lastSnapshot = snapshot
            try? snapshot.write()
            WidgetCenter.shared.reloadAllTimelines()
        }
        syncActivity(running: store.running, hourlyRate: snapshot.hourlyRate,
                     earned: store.currentEarnings(at: .now), currencyCode: store.currencyCode)
    }

    private func syncActivity(running: RunningSession?, hourlyRate: Double, earned: Double, currencyCode: String) {
        guard let running else {
            lastState = nil
            Task { await Self.endAll() }
            return
        }
        let state = ClockinActivityAttributes.ContentState(
            running: running, hourlyRate: hourlyRate, earned: earned,
            usdTryRate: currencyCode == "USD" ? SharedStore.exchangeRates.latestRate : nil
        )
        // Yeniden kurulum surerken gelen senkronlar atlanir; yoksa eski etkinlik
        // kapanmadan ikinci bir etkinlik istenebilirdi.
        guard !isRestartingActivity else { return }
        let activities = Activity<ClockinActivityAttributes>.activities
        let content = ActivityContent(state: state, staleDate: nil)
        // Para birimi yalnizca etkinlik baslatilirken sabit alanlara yaziliyor;
        // guncellemeler onu degistiremez. Birim degistiyse etkinlik kapatilip
        // yeni birimle yeniden baslatilir, yoksa kilit ekrani eski birimde kalir.
        if activities.contains(where: { $0.attributes.currencyCode != currencyCode }) {
            isRestartingActivity = true
            lastState = state
            Task { [weak self] in
                await Self.endAll()
                Self.request(currencyCode: currencyCode, content: content)
                self?.isRestartingActivity = false
            }
            return
        }
        guard state != lastState || activities.isEmpty else { return }
        lastState = state
        if activities.isEmpty {
            Self.request(currencyCode: currencyCode, content: content)
        } else {
            Task { await Self.updateAll(content) }
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
