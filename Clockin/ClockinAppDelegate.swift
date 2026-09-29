import CloudKit
import UIKit

final class ClockinAppDelegate: NSObject, UIApplicationDelegate {
    private var cloudAccountObserver: NSObjectProtocol?

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Soguk bildirim acilisinda delegate, launch bitmeden hazir olmali.
        _ = FocusChimeController.shared
        // Eszamanlama arka planda baslayan (Kisayollar, bildirim) acilislarda da
        // calismali. iCloud yetkisi olmayan derlemede hicbir sey yapmaz.
        let sync = SyncCoordinator.shared
        sync.start()
        if sync.isEnabled { application.registerForRemoteNotifications() }
        cloudAccountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: nil
        ) { _ in
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
        let sync = SyncCoordinator.shared
        guard sync.isEnabled,
              let notice = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification,
              notice.containerIdentifier == ClockinCloudRecord.containerID,
              notice.databaseScope == .private else { return .noData }
        await sync.handleRemoteNotification()
        await SessionMirror.shared.finishPendingUpdates()
        return .noData
    }
}
