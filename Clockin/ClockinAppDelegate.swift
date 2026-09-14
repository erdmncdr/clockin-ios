import UIKit

final class ClockinAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Soguk bildirim acilisinda delegate, launch bitmeden hazir olmali.
        _ = FocusChimeController.shared
        return true
    }
}
