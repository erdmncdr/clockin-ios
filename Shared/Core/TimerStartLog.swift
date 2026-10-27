import Combine
import Foundation

enum TimerOrigin: String, Codable, CaseIterable, Sendable {
    case app = "app"
    case widget = "widget"
    case controlCenter = "controlCenter"
    case sync = "sync"
    case shortcut = "shortcut"
    case link = "link"
    case pulse = "pulse"

    var title: String {
        switch self {
        case .app: String(localized: "In the app", bundle: .app)
        case .widget: String(localized: "Widget, Siri or Shortcuts", bundle: .app)
        case .controlCenter: String(localized: "Control Center", bundle: .app)
        case .sync: String(localized: "Another device (iCloud)", bundle: .app)
        case .shortcut: String(localized: "Keyboard shortcut", bundle: .app)
        case .link: String(localized: "Link from another app", bundle: .app)
        case .pulse: String(localized: "Pulse (Chrome)", bundle: .app)
        }
    }
}

@MainActor
final class TimerStartLog: ObservableObject {
    static let key = "Clockin.TimerStartLog.v1"
    static let shared = TimerStartLog()

    enum Action: String, Codable, Sendable {
        case clockIn = "clockIn"
        case resume = "resume"
        case clockOut = "clockOut"

        var title: String {
            switch self {
            case .clockIn: String(localized: "Clock in", bundle: .app)
            case .resume: String(localized: "Resume", bundle: .app)
            case .clockOut: String(localized: "Clock out", bundle: .app)
            }
        }
    }

    enum SyncProvenance: String, Codable, Sendable {
        case remoteChange = "remoteChange"
        case initialImport = "initialImport"

        var title: String {
            switch self {
            case .remoteChange: String(localized: "Remote change", bundle: .app)
            case .initialImport: String(localized: "Initial import", bundle: .app)
            }
        }
    }

    struct Entry: Codable, Equatable, Identifiable, Sendable {
        var id: UUID = UUID()
        let date: Date
        let action: Action
        let origin: TimerOrigin
        let wasRunning: Bool?
        let provenance: SyncProvenance?
    }

    @Published private(set) var entries: [Entry]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
        entries = Array(saved.prefix(100))
    }

    func record(_ action: Action, origin: TimerOrigin, at date: Date = .now,
                wasRunning: Bool? = nil, provenance: SyncProvenance? = nil) {
        let entry = Entry(date: date, action: action, origin: origin,
                          wasRunning: wasRunning, provenance: provenance)
        let next = Array(([entry] + entries).prefix(100))
        guard let encoded = try? JSONEncoder().encode(next) else { return }
        defaults.set(encoded, forKey: Self.key)
        entries = next
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
        entries = []
    }
}

enum ExternalTimerStarts {
    static let key = "Clockin.ExternalStartsEnabled"

    static var isEnabled: Bool {
        #if os(iOS)
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
        #else
        true
        #endif
    }
}
