import SwiftUI
import UIKit

/// Masa modu tercihi ve uygulamanin donebilecegi yonler.
///
/// SwiftUI'da ekran bazinda yon kilidi yok. Info.plist yatayi da acar, yon
/// maskesi burada tercihe gore daraltilir: masa modu kapaliyken uygulama
/// eskisi gibi hep dikey kalir, diger ekranlar yatay duzen gormez.
enum DeskMode {
    static let enabledKey = "Clockin.DeskModeEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var orientations: UIInterfaceOrientationMask {
        isEnabled ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
    }

    /// Tercih degisince sistem maskeyi yeniden sorsun; kapatilirken yataysa
    /// ekran dikeye doner.
    @MainActor
    static func refreshOrientations() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        }
    }
}

final class ClockinAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        DeskMode.orientations
    }
}
