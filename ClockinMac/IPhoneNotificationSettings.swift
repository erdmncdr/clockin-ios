import AppKit

enum IPhoneNotificationSettings {
    static let anchoredURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?RemoteNotificationSettings")!
    static let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!

    @MainActor
    @discardableResult
    static func open(using openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) }) -> Bool {
        openURL(anchoredURL) || openURL(fallbackURL)
    }
}
