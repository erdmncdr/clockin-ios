import SwiftUI

enum MacSettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case timer = "Timer & goals"
    case pay = "Pay & currency"
    case menuBar = "Menu bar"
    case notifications = "Notifications"
    case icloud = "iCloud"
    case data = "Data & import"
    case help = "Help & about"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .timer: "timer"
        case .pay: "banknote"
        case .menuBar: "menubar.rectangle"
        case .notifications: "bell"
        case .icloud: "icloud"
        case .data: "tray.and.arrow.down"
        case .help: "questionmark.circle"
        }
    }
}
