import AppKit

/// Clockin Applications disinda acilinca oraya tasimayi teklif eder.
///
/// DMG'nin icinden acilan kopya calisir ama salt okunur oldugu icin Sparkle
/// guncelleme kuramaz ve DMG cikarilinca uygulama kaybolur. Indirilenler'de
/// kalan kopya da Spotlight'ta ikinci bir Clockin olarak gorunur. Konum
/// tespiti ve kopyalama `ApplicationMover`'da; burada yalnizca soru ve
/// yeniden acilis var.
@MainActor
enum MoveToApplications {
    private static let suppressionKey = "Clockin.MoveToApplicationsSuppressed"

    /// Clockin Applications'taki kopyadan yeniden acilmak uzere kapanacaksa
    /// `true` doner; cagiran baska bir sey baslatmamali.
    static func offerIfNeeded() -> Bool {
        #if DEBUG
        // Debug derlemesi hic tasima onermez: gelistirme kopyasi yayindaki
        // uygulamanin yerine gecip onu Cop Kutusu'na atmisti.
        return false
        #else
        let location = ApplicationMover.locate(Bundle.main.bundleURL)
        guard location.shouldOfferMove else { return false }
        // DMG'den calisan kopya icin "bir daha sorma" sunulmaz: orada kalmak
        // hicbir zaman dogru secim degil.
        let canSuppress = location.kind != .readOnlyVolume
        if canSuppress, UserDefaults.standard.bool(forKey: suppressionKey) { return false }

        let destination: URL
        do {
            destination = try ApplicationMover.destinationDirectory()
        } catch {
            showFailure(error)
            return false
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = String(localized: "Move Clockin to your Applications folder?", bundle: .app)
        alert.informativeText = explanation(for: location, destination: destination)
        alert.addButton(withTitle: String(localized: "Move to Applications", bundle: .app))
        alert.addButton(withTitle: location.kind == .readOnlyVolume ? String(localized: "Keep Running from Disk Image", bundle: .app) : String(localized: "Not Now", bundle: .app))
        if canSuppress {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = String(localized: "Don't ask again", bundle: .app)
        }
        let response = alert.runModal()
        if canSuppress, alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: suppressionKey)
        }
        guard response == .alertFirstButtonReturn else { return false }

        do {
            let installed = try move(location, into: destination)
            try relaunch(installed,
                         afterExitOf: ProcessInfo.processInfo.processIdentifier,
                         ejecting: location.kind == .readOnlyVolume ? location.volumeURL : nil)
            return true
        } catch {
            showFailure(error)
            return false
        }
        #endif
    }

    static func explanation(for location: ApplicationLocation, destination: URL) -> String {
        let folder = destination.path(percentEncoded: false)
        switch location.kind {
        case .readOnlyVolume:
            return String(localized: "Clockin is running from the disk image, where updates can't be installed and the app disappears once the disk image is ejected. Clockin will copy itself to \(folder), reopen from there and eject the disk image.", bundle: .app)
        default:
            let current = location.originalURL.deletingLastPathComponent().lastPathComponent
            return String(localized: "Clockin is running from \(current). In \(folder) it can install updates and there is only one copy on this Mac. Clockin will move itself there and reopen.", bundle: .app)
        }
    }

    /// Kopyalar ve yazilabilir bir yerdeki eski kopyayi Cop Kutusu'na atar.
    /// DMG'deki kopyaya dokunulmaz; o disk zaten cikarilacak.
    static func move(_ location: ApplicationLocation, into destination: URL,
                     fileManager: FileManager = .default) throws -> URL {
        let existing = destination.appendingPathComponent(location.originalURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: existing.path),
           ApplicationMover.bundleIdentifier(of: existing) != ApplicationMover.bundleIdentifier(of: location.originalURL) {
            throw ApplicationMoverError.differentApplication(existing)
        }
        let installed: URL
        if let existingBuild = buildNumber(of: existing), let ownBuild = buildNumber(of: location.originalURL),
           existingBuild >= ownBuild {
            // Applications'taki kopya ayni ya da daha yeni: eski bir DMG'den
            // acilan surum, Sparkle'in guncelledigi uygulamanin yerine gecmesin.
            installed = existing
        } else {
            installed = try ApplicationMover.install(location.originalURL, into: destination, fileManager: fileManager)
        }
        if location.kind != .readOnlyVolume,
           installed.standardizedFileURL.resolvingSymlinksInPath() != location.originalURL.standardizedFileURL.resolvingSymlinksInPath() {
            // Basarisiz olursa sorun degil: yeni kopya yerinde, eskisi kalir.
            try? fileManager.trashItem(at: location.originalURL, resultingItemURL: nil)
        }
        return installed
    }

    static func buildNumber(of app: URL) -> Int? {
        let plist = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let build = info["CFBundleVersion"] as? String else { return nil }
        return Int(build)
    }

    /// Bu surec kapaninca yeni kopyayi acan ve istenirse DMG'yi cikaran kucuk
    /// bir kabuk sureci baslatir. Iki Clockin ayni anda ayni veri dosyasina
    /// yazmasin diye yeni kopya eskisi kapanmadan acilmaz; DMG de ancak
    /// ondan calisan surec kapaninca cikarilabilir.
    static func relaunch(_ app: URL, afterExitOf pid: Int32, ejecting volume: URL?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", relaunchScript, "clockin-relaunch", String(pid),
                             app.path(percentEncoded: false), volume?.path(percentEncoded: false) ?? ""]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    /// `$1` beklenen surec, `$2` acilacak uygulama, `$3` cikarilacak disk (bos olabilir).
    /// En fazla 30 sn beklenir; takilirsa yine de acilir.
    static let relaunchScript = """
    i=0
    while kill -0 "$1" 2>/dev/null && [ "$i" -lt 150 ]; do sleep 0.2; i=$((i+1)); done
    /usr/bin/open "$2"
    if [ -n "$3" ]; then /usr/bin/hdiutil detach -quiet "$3" || true; fi
    """

    private static func showFailure(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Clockin couldn't move itself to Applications", bundle: .app)
        alert.informativeText = String(localized: "\(error.localizedDescription)\n\nYou can drag Clockin into the Applications folder in Finder instead.", bundle: .app)
        alert.addButton(withTitle: String(localized: "OK", bundle: .app))
        alert.runModal()
    }
}
