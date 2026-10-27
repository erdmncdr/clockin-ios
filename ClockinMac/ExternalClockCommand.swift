import AppKit
import Foundation
import Security

/// `clockin://clock-in` and `clockin://clock-out`, sent by the Pulse Chrome
/// extension through Clockin's own native-host process when someone presses
/// their work site's Clock in or Clock out button. Any app or web page on the
/// Mac can open the same URLs, so the receiver acts at once only for Clockin's
/// own process or a URL carrying the pass it left on disk, and asks for
/// everything else. The commands only ever start or end the timer, the same
/// way the global shortcuts do, and never open a window.
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

    /// The `pass` query item, see `ExternalClockPass`.
    static func pass(in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "pass" }?.value
    }

    @MainActor
    func wouldChange(_ store: ClockStore) -> Bool {
        switch self {
        case .clockIn: store.running == nil || store.running?.isPaused == true
        case .clockOut: store.running != nil
        }
    }

    /// Start, resume or end the session. A command that is already true (in
    /// while working, out while idle) does nothing.
    @MainActor
    func perform(on store: ClockStore, origin: TimerOrigin = .link) {
        switch self {
        case .clockIn:
            if store.running == nil { store.clockIn(origin: origin) }
            else if store.running?.isPaused == true { store.resume(origin: origin) }
        case .clockOut:
            if store.running != nil { _ = store.clockOut(origin: origin) }
        }
    }
}

/// A one-time secret between the native-host process and the running app:
/// the host writes it to the data folder (which only this user's processes can
/// write) and puts it in the URL; the app accepts the URL without asking when
/// the two match, and removes the file either way.
enum ExternalClockPass {
    static var fileURL: URL { AppGroup.directory.appending(path: "pulse-pass") }

    /// A fresh pass, written for the URL about to be sent.
    static func issue() -> String? {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        let pass = bytes.map { String(format: "%02x", $0) }.joined()
        try? FileManager.default.createDirectory(at: AppGroup.directory, withIntermediateDirectories: true)
        guard (try? Data(pass.utf8).write(to: fileURL, options: .atomic)) != nil else { return nil }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        return pass
    }

    /// Whether the pass is the one on disk. The file goes either way, so a
    /// pass can be used once and a stale one never lingers.
    static func redeem(_ pass: String?) -> Bool {
        guard let pass, pass.count == 64, let data = try? Data(contentsOf: fileURL) else { return false }
        try? FileManager.default.removeItem(at: fileURL)
        let stored = String(decoding: data, as: UTF8.self)
        guard stored.utf8.count == pass.utf8.count else { return false }
        return zip(stored.utf8, pass.utf8).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

/// Receives the URLs directly from the Apple Event, before SwiftUI could try
/// to open a scene for them.
@MainActor
final class ExternalClockCommandReceiver: NSObject {
    static let shared = ExternalClockCommandReceiver()

    private var confirming = false

    func install() {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handle(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc private func handle(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text),
              let command = ExternalClockCommand(url: url) else { return }
        let store = SharedStore.clock
        guard command.wouldChange(store) else { return }
        let sender = event.attributeDescriptor(forKeyword: keySenderPIDAttr)
            .flatMap { NSRunningApplication(processIdentifier: $0.int32Value) }
        let ownProcess = sender?.executableURL.map { executable in
            Bundle.main.executableURL.map {
                executable.resolvingSymlinksInPath().standardizedFileURL == $0.resolvingSymlinksInPath().standardizedFileURL
            } ?? false
        } ?? false
        // The pass covers Launch Services reporting another sender for the URL.
        if ownProcess || ExternalClockPass.redeem(ExternalClockCommand.pass(in: url)) {
            command.perform(on: store, origin: .pulse)
            return
        }
        // Modal alerts pump events; do not nest a second confirmation.
        guard !confirming else { return }
        confirming = true
        defer { confirming = false }
        let alert = NSAlert()
        let name = sender?.localizedName ?? String(localized: "Another app", bundle: .app)
        switch command {
        case .clockIn:
            alert.messageText = String(localized: "Clock in from a link?", bundle: .app)
            alert.informativeText = String(localized: "\(name) wants to start the Clockin timer.", bundle: .app)
            alert.addButton(withTitle: String(localized: "Clock in", bundle: .app))
        case .clockOut:
            alert.messageText = String(localized: "Clock out from a link?", bundle: .app)
            alert.informativeText = String(localized: "\(name) wants to stop the Clockin timer.", bundle: .app)
            alert.addButton(withTitle: String(localized: "Clock out", bundle: .app))
        }
        alert.addButton(withTitle: String(localized: "Cancel", bundle: .app))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        command.perform(on: store, origin: .link)
    }
}
