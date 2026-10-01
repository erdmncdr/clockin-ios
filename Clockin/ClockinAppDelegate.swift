import CloudKit
import OSLog
import UIKit

final class ClockinAppDelegate: NSObject, UIApplicationDelegate {
    private var cloudAccountObserver: NSObjectProtocol?
    private var checkpointTask: UIBackgroundTaskIdentifier = .invalid
    private var checkpointGeneration = UUID()

    func flushSyncForBackground() {
        guard checkpointTask == .invalid else { return }
        let generation = UUID()
        checkpointGeneration = generation
        checkpointTask = UIApplication.shared.beginBackgroundTask(withName: "Sync checkpoint") { @Sendable [weak self] in
            Task { @MainActor in self?.endCheckpointTask(generation: generation) }
        }
        Task { @MainActor in
            _ = await SyncCoordinator.shared.flushPersistence()
            endCheckpointTask(generation: generation)
        }
    }

    private func endCheckpointTask(generation: UUID) {
        guard checkpointTask != .invalid, checkpointGeneration == generation else { return }
        UIApplication.shared.endBackgroundTask(checkpointTask)
        checkpointTask = .invalid
    }

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Soguk bildirim acilisinda delegate, launch bitmeden hazir olmali.
        _ = FocusChimeController.shared
        // Eszamanlama arka planda baslayan (Kisayollar, bildirim) acilislarda da
        // calismali. iCloud yetkisi olmayan derlemede hicbir sey yapmaz.
        let sync = SyncCoordinator.shared
        sync.start()
        if sync.isEnabled { application.registerForRemoteNotifications() }
        #if DEBUG
        // Review fixture: `--clear-sync-inbox` clears the recovery inbox once sync is up.
        if ProcessInfo.processInfo.arguments.contains("--clear-sync-inbox") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                SyncCoordinator.shared.acknowledgeAllRecoveries()
            }
        }
        #endif
        cloudAccountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: nil
        ) { @Sendable _ in
            Task { @MainActor in SyncCoordinator.shared.accountMayHaveChanged() }
        }
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        DeskMode.orientations
    }

    @MainActor
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        Logger(subsystem: "com.erdmncdr.clockin", category: "sync").notice("push delivered to the app")
        let sync = SyncCoordinator.shared
        guard sync.isEnabled,
              let notice = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification,
              notice.containerIdentifier == ClockinCloudRecord.containerID,
              notice.databaseScope == .private else { return .noData }
        let result = await sync.handleRemoteNotification()
        await SessionMirror.shared.finishPendingUpdates()
        Logger(subsystem: "com.erdmncdr.clockin", category: "sync")
            .notice("push fetch result: \(String(describing: result), privacy: .public)")
        switch result {
        case .newData: return .newData
        case .noData: return .noData
        case .failed: return .failed
        }
    }
}
