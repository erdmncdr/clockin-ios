import AppKit
import Foundation

/// The Chrome extension's direct line to Clockin (Chrome "native messaging").
/// Chrome starts this app's executable with the extension's origin as an
/// argument, sends one length-prefixed JSON message on stdin and reads one
/// reply on stdout. The process hands the command to the running Clockin (or
/// launches it) and answers whether the timer actually changed, so the
/// extension can show that a press counted, without Chrome's "Open Clockin?"
/// prompt or any page navigation.
enum ChromeNativeHost {
    static let name = "com.erdmncdr.clockin"
    /// Fixed by the public key in the extension's manifest.json.
    static let extensionID = "iaikoicampaamoakicipdacniaaonkpc"

    static func isHostLaunch(_ arguments: [String] = CommandLine.arguments) -> Bool {
        arguments.dropFirst().contains { $0.hasPrefix("chrome-extension://") }
    }

    /// Answers one message and exits; never returns.
    static func run() -> Never {
        let reply: [String: Any]
        if let message = readMessage(), let action = message["action"] as? String {
            reply = perform(action)
        } else {
            reply = ["ok": false, "error": "unreadable message"]
        }
        writeMessage(reply)
        exit(0)
    }

    static func perform(_ action: String) -> [String: Any] {
        guard let plain = URL(string: "clockin://" + action), let command = ExternalClockCommand(url: plain) else {
            return ["ok": false, "error": "unknown action"]
        }
        // With the pass, the app acts without asking even if Launch Services
        // names another process as the sender.
        let url = ExternalClockPass.issue().flatMap { URL(string: "clockin://\(action)?pass=\($0)") } ?? plain
        // To this very app bundle, so another copy on the Mac never gets it.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        let delivered = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failure: String?
        NSWorkspace.shared.open([url], withApplicationAt: Bundle.main.bundleURL, configuration: configuration) { _, error in
            failure = error?.localizedDescription
            delivered.signal()
        }
        guard delivered.wait(timeout: .now() + 10) == .success else { return ["ok": false, "error": "Clockin did not answer"] }
        if let failure { return ["ok": false, "error": failure] }
        // The running app saves right after it changes the timer.
        let wantRunning = command == .clockIn
        for _ in 0..<30 {
            if isRunning(in: AppGroup.dataFileURL) == wantRunning { return ["ok": true, "confirmed": true, "action": action] }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return ["ok": true, "confirmed": false, "action": action]
    }

    /// Whether the saved data has a session running. Reads only the top level.
    static func isRunning(in file: URL) -> Bool? {
        guard let data = try? Data(contentsOf: file),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let running = object["running"], !(running is NSNull) { return true }
        return false
    }

    // Chrome's framing: a 32-bit length in native byte order, then UTF-8 JSON.
    static func readMessage(from handle: FileHandle = .standardInput) -> [String: Any]? {
        guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return nil }
        let length = header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        guard length > 0, length < 1_048_576, let body = try? handle.read(upToCount: Int(length)), body.count == Int(length) else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }

    static func writeMessage(_ message: [String: Any], to handle: FileHandle = .standardOutput) {
        guard let body = try? JSONSerialization.data(withJSONObject: message) else { return }
        var length = UInt32(body.count)
        handle.write(Data(bytes: &length, count: 4) + body)
    }

    /// The host manifest Chrome-family browsers look for, pointing at this
    /// executable. Written next to each installed browser's profile folder.
    static func writeManifests() {
        guard let executable = Bundle.main.executablePath else { return }
        let manifest: [String: Any] = [
            "name": name,
            "description": "Clockin",
            "path": executable,
            "type": "stdio",
            "allowed_origins": ["chrome-extension://\(extensionID)/"],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]) else { return }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let browsers = ["Google/Chrome", "Google/Chrome Beta", "Google/Chrome Dev", "Google/Chrome Canary", "Chromium",
                        "BraveSoftware/Brave-Browser", "Microsoft Edge", "Vivaldi", "Arc/User Data"]
        for browser in browsers {
            let folder = support.appendingPathComponent(browser, isDirectory: true)
            guard FileManager.default.fileExists(atPath: folder.path) else { continue }
            let hosts = folder.appendingPathComponent("NativeMessagingHosts", isDirectory: true)
            try? FileManager.default.createDirectory(at: hosts, withIntermediateDirectories: true)
            try? data.write(to: hosts.appendingPathComponent("\(name).json"), options: .atomic)
        }
    }
}
