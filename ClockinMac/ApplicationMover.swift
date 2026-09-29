import Foundation
import Security

@_silgen_name("SecTranslocateIsTranslocatedURL")
private func moverIsTranslocated(_ url: CFURL, _ result: UnsafeMutablePointer<Bool>,
                                 _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> UInt8
@_silgen_name("SecTranslocateCreateOriginalPathForURL")
private func moverOriginalPath(_ url: CFURL,
                               _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?

struct ApplicationLocation: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case installed, readOnlyVolume, translocated, elsewhere, development
    }
    let kind: Kind
    let bundleURL: URL
    let originalURL: URL
    let volumeURL: URL?

    var shouldOfferMove: Bool {
        switch kind {
        case .readOnlyVolume, .translocated, .elsewhere: true
        case .installed, .development: false
        }
    }
}

enum ApplicationMoverError: LocalizedError {
    case invalidDestination
    case sameLocation
    case operation(URL, String)
    case recovery(URL, String)

    var errorDescription: String? {
        switch self {
        case .invalidDestination: String(localized: "No writable Applications directory is available.", bundle: .app)
        case .sameLocation: String(localized: "Clockin is already at the destination.", bundle: .app)
        case let .operation(url, reason): String(localized: "Clockin can't be copied to \(url.path): \(reason)", bundle: .app)
        case let .recovery(url, reason):
            String(localized: "Clockin couldn't restore the previous app. A backup remains at \(url.path): \(reason)", bundle: .app)
        }
    }
}

enum ApplicationMover {
    struct Environment: Sendable {
        var applicationsDirectories: [URL]
        var translocatedOriginal: @Sendable (URL) -> URL?
        var isReadOnlyVolume: @Sendable (URL) -> Bool
        var volumeURL: @Sendable (URL) -> URL?
        var isDevelopmentBuild: @Sendable (URL) -> Bool

        static let live = Environment(
            applicationsDirectories: [URL(fileURLWithPath: "/Applications", isDirectory: true),
                                      FileManager.default.homeDirectoryForCurrentUser
                                        .appendingPathComponent("Applications", isDirectory: true)],
            translocatedOriginal: { url in
                var translocated = false
                guard moverIsTranslocated(url as CFURL, &translocated, nil) != 0,
                      translocated,
                      let original = moverOriginalPath(url as CFURL, nil) else { return nil }
                return original.takeRetainedValue() as URL
            },
            isReadOnlyVolume: { (try? $0.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly == true },
            volumeURL: { (try? $0.resourceValues(forKeys: [.volumeURLKey]))?.volume },
            isDevelopmentBuild: { url in
                if isDevelopmentPath(url) { return true }
                var code: SecStaticCode?
                guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
                      let code else { return true }
                var information: CFDictionary?
                guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation),
                                                   &information) == errSecSuccess,
                      let information else { return true }
                return (information as NSDictionary)[kSecCodeInfoTeamIdentifier] == nil
            }
        )
    }

    private static func resolved(_ url: URL) -> URL {
        // Resolve existing parents even when the final destination does not exist yet.
        url.standardizedFileURL.pathComponents.dropFirst().reduce(URL(fileURLWithPath: "/")) {
            $0.appendingPathComponent($1).resolvingSymlinksInPath().standardizedFileURL
        }
    }

    private static func isDevelopmentPath(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".build" || $0 == "dist" }
    }

    static func locate(_ bundleURL: URL, environment: Environment = .live) -> ApplicationLocation {
        let bundle = resolved(bundleURL)
        func location(_ kind: ApplicationLocation.Kind, original: URL? = nil) -> ApplicationLocation {
            let original = original ?? bundle
            return ApplicationLocation(kind: kind, bundleURL: bundle, originalURL: original,
                                       volumeURL: kind == .readOnlyVolume ? environment.volumeURL(original) : nil)
        }
        if isDevelopmentPath(bundle) || environment.isDevelopmentBuild(bundle) {
            return location(.development)
        }
        let translocated = environment.translocatedOriginal(bundle).map(resolved)
        let original = translocated ?? bundle
        if isDevelopmentPath(original) || (translocated != nil && environment.isDevelopmentBuild(original)) {
            return location(.development, original: original)
        }
        if environment.applicationsDirectories.contains(where: {
            original.pathComponents.starts(with: resolved($0).pathComponents)
        }) {
            return location(.installed, original: original)
        }
        if environment.isReadOnlyVolume(original) {
            return location(.readOnlyVolume, original: original)
        }
        return location(translocated == nil ? .elsewhere : .translocated, original: original)
    }

    static func destinationDirectory(environment: Environment = .live,
                                     fileManager: FileManager = .default) throws -> URL {
        guard let system = environment.applicationsDirectories.first else {
            throw ApplicationMoverError.invalidDestination
        }
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: system.path, isDirectory: &isDirectory),
           isDirectory.boolValue, fileManager.isWritableFile(atPath: system.path) { return system }
        guard let user = environment.applicationsDirectories.dropFirst().first else {
            throw ApplicationMoverError.invalidDestination
        }
        do {
            try fileManager.createDirectory(at: user, withIntermediateDirectories: true)
            guard fileManager.isWritableFile(atPath: user.path) else {
                throw ApplicationMoverError.invalidDestination
            }
            return user
        } catch {
            throw ApplicationMoverError.operation(user, error.localizedDescription)
        }
    }

    /// Stage the new copy before touching the old app, and retain a rollback copy until the rename succeeds.
    static func install(_ source: URL, into directory: URL,
                        fileManager: FileManager = .default) throws -> URL {
        let final = directory.appendingPathComponent(source.lastPathComponent)
        guard resolved(source) != resolved(final) else { throw ApplicationMoverError.sameLocation }
        let temporary = directory.appendingPathComponent(".clockin-install-\(UUID().uuidString).app")
        let backup = directory.appendingPathComponent(".clockin-backup-\(UUID().uuidString).app")
        var hasBackup = false
        var displaced = false
        defer { try? fileManager.removeItem(at: temporary) }
        do {
            try fileManager.copyItem(at: source, to: temporary)
            try removeQuarantine(temporary, fileManager: fileManager)
            // attributesOfItem also detects a dangling destination symlink.
            if (try? fileManager.attributesOfItem(atPath: final.path)) != nil {
                try fileManager.copyItem(at: final, to: backup)
                hasBackup = true
                do {
                    try fileManager.trashItem(at: final, resultingItemURL: nil)
                } catch {
                    // The rollback copy protects against partial removal too.
                    displaced = true
                    try fileManager.removeItem(at: final)
                }
                displaced = true
            }
            try fileManager.moveItem(at: temporary, to: final)
        } catch {
            if hasBackup && displaced {
                do {
                    if (try? fileManager.attributesOfItem(atPath: final.path)) != nil {
                        try fileManager.removeItem(at: final)
                    }
                    try fileManager.moveItem(at: backup, to: final)
                } catch {
                    // Do not erase the only recoverable copy if the filesystem refuses rollback.
                    throw ApplicationMoverError.recovery(backup, error.localizedDescription)
                }
            } else {
                try? fileManager.removeItem(at: backup)
            }
            throw ApplicationMoverError.operation(directory, error.localizedDescription)
        }
        try? fileManager.removeItem(at: backup)
        return final
    }

    /// Never follow bundle symlinks: they can point outside the staged copy.
    private static func removeQuarantine(_ url: URL, fileManager: FileManager) throws {
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return removexattr(path, "com.apple.quarantine", XATTR_NOFOLLOW)
        }
        if result != 0 && errno != ENOATTR {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        if attributes[.type] as? FileAttributeType == .typeDirectory {
            for child in try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                try removeQuarantine(child, fileManager: fileManager)
            }
        }
    }
}
