#if os(iOS)
import Foundation
import Combine
import UIKit
import UserNotifications

extension RemoteClockInNotification {
    static let shared = RemoteClockInNotification(defaults: .standard,
        isActive: { UIApplication.shared.applicationState == .active },
        canNotify: {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        }, post: { start in
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Clocked in on your Mac", bundle: .app)
            content.body = String(localized: "Open Clockin to show the timer on the Lock Screen and in the Dynamic Island.", bundle: .app)
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: identifierPrefix + String(start.timeIntervalSinceReferenceDate),
                content: content, trigger: nil)
            try await UNUserNotificationCenter.current().add(request)
        })
}

/// Retained request also works when the notification delegate runs before views
/// exist. Each tap changes the value so existing tabs and sheets can respond.
@MainActor
final class RemoteClockInNavigation: ObservableObject {
    static let shared = RemoteClockInNavigation()
    @Published private(set) var request: UUID?
    func openToday() { request = UUID() }
}
#endif
