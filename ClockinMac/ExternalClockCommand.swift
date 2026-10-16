import AppKit
import Foundation

/// `clockin://clock-in` and `clockin://clock-out`, sent by the Clockin Chrome
/// extension when someone presses their work site's Clock in or Clock out
/// button. The commands only ever start or end the timer, the same way the
/// global shortcuts do, and never open a window.
enum ExternalClockCommand: Equatable, Sendable {
    case clockIn
    case clockOut

    init?(url: URL) {
        guard url.scheme?.lowercased() == "clockin" else { return nil }
        switch (url.host() ?? "").lowercased() {
        case "clock-in": self = .clockIn
        case "clock-out": self = .clockOut
        default: return nil
        }
    }

    /// Start, resume or end the session. A command that is already true (in
    /// while working, out while idle) does nothing.
    @MainActor
    func perform(on store: ClockStore) {
        switch self {
        case .clockIn:
            if store.running == nil { store.clockIn() }
            else if store.running?.isPaused == true { store.resume() }
        case .clockOut:
            if store.running != nil { _ = store.clockOut() }
        }
    }
}

/// Receives the URLs directly from the Apple Event, before SwiftUI could try
/// to open a scene for them.
@MainActor
final class ExternalClockCommandReceiver: NSObject {
    static let shared = ExternalClockCommandReceiver()

    func install() {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handle(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc private func handle(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text),
              let command = ExternalClockCommand(url: url) else { return }
        command.perform(on: SharedStore.clock)
    }
}
