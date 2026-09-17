import Foundation
import Combine

@MainActor
final class RollingAnimationPolicy: ObservableObject {
    static let shared = RollingAnimationPolicy()

    @Published private(set) var lowPower: Bool
    @Published private(set) var thermalState: ProcessInfo.ThermalState
    private var observers: [NSObjectProtocol] = []

    private init() {
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
        // Tek uygulama omurlu dinleyici cifti; hucre basina gozlemci yok.
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange,
                     ProcessInfo.thermalStateDidChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) {
                [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            })
        }
    }

    func refresh() {
        let process = ProcessInfo.processInfo
        if lowPower != process.isLowPowerModeEnabled { lowPower = process.isLowPowerModeEnabled }
        if thermalState != process.thermalState { thermalState = process.thermalState }
    }

    func allowsAnimation(reduceMotion: Bool, contentActive: Bool, sceneActive: Bool, visible: Bool) -> Bool {
        rollingAnimationAllowed(reduceMotion: reduceMotion, lowPower: lowPower, thermalState: thermalState,
                                contentActive: contentActive, sceneActive: sceneActive, visible: visible)
    }
}
