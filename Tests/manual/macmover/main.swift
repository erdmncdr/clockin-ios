// Moving a downloaded Clockin into Applications. A copy opened from Downloads
// runs translocated: macOS mirrors it read-only elsewhere, and the original in
// Downloads may be unreadable to the app. The move must still be offered and
// must copy from the mirror.
//
// swiftc -swift-version 6 Shared/Core/AppLanguage.swift ClockinMac/ApplicationMover.swift ClockinMac/MoveToApplications.swift Tests/manual/macmover/main.swift -o /tmp/clockin-macmover && /tmp/clockin-macmover
import Foundation

var passed = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
    passed += 1
}

let fileManager = FileManager.default
let root = fileManager.temporaryDirectory.appendingPathComponent("clockin-macmover-\(UUID().uuidString)", isDirectory: true)
defer { try? fileManager.removeItem(at: root) }
let applications = root.appendingPathComponent("Applications", isDirectory: true)
let downloads = root.appendingPathComponent("Downloads", isDirectory: true)
let mirror = root.appendingPathComponent("AppTranslocation/ABC/d", isDirectory: true)
for directory in [applications, downloads, mirror] {
    try! fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
}

@MainActor func makeApp(at url: URL, build: String) {
    let contents = url.appendingPathComponent("Contents", isDirectory: true)
    try! fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
    let info: [String: Any] = ["CFBundleIdentifier": "com.ismailakdag.clockin", "CFBundleVersion": build,
                               "CFBundleExecutable": "Clockin", "CFBundlePackageType": "APPL"]
    try! PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: contents.appendingPathComponent("Info.plist"))
}

let original = downloads.appendingPathComponent("Clockin.app")
let translocated = mirror.appendingPathComponent("Clockin.app")
makeApp(at: translocated, build: "24")

// The original is unreadable, like Downloads without permission: any check
// of its signature fails, and the old code took that for a development build.
let environment = ApplicationMover.Environment(
    applicationsDirectories: [applications],
    translocatedOriginal: { $0.standardizedFileURL == translocated.standardizedFileURL ? original : nil },
    isReadOnlyVolume: { _ in false },
    volumeURL: { _ in nil },
    isDevelopmentBuild: { url in url.standardizedFileURL.path.hasPrefix(downloads.standardizedFileURL.path) }
)
let location = ApplicationMover.locate(translocated, environment: environment)
check(location.kind == .translocated, "a translocated download is recognised (got \(location.kind))")
check(location.shouldOfferMove, "a translocated download offers to move to Applications")

let installed = try! MoveToApplications.move(location, into: applications)
check(installed.standardizedFileURL == applications.appendingPathComponent("Clockin.app").standardizedFileURL,
      "the move lands in Applications")
check(MoveToApplications.buildNumber(of: installed) == 24, "the copy comes from the translocated mirror")
check(fileManager.fileExists(atPath: translocated.path), "the mirror is left alone")

// An older copy already in Applications is replaced; a newer one is kept.
makeApp(at: translocated, build: "25")
let upgraded = try! MoveToApplications.move(location, into: applications)
check(MoveToApplications.buildNumber(of: upgraded) == 25, "an older installed copy is replaced")
makeApp(at: translocated, build: "20")
let kept = try! MoveToApplications.move(location, into: applications)
check(MoveToApplications.buildNumber(of: kept) == 25, "a newer installed copy is kept")

// Untranslocated copies elsewhere and development builds behave as before.
let elsewhere = downloads.appendingPathComponent("Plain/Clockin.app")
makeApp(at: elsewhere, build: "24")
let plainEnvironment = ApplicationMover.Environment(
    applicationsDirectories: [applications], translocatedOriginal: { _ in nil },
    isReadOnlyVolume: { _ in false }, volumeURL: { _ in nil }, isDevelopmentBuild: { _ in false })
check(ApplicationMover.locate(elsewhere, environment: plainEnvironment).kind == .elsewhere, "an untranslocated copy is 'elsewhere'")
let development = ApplicationMover.Environment(
    applicationsDirectories: [applications], translocatedOriginal: { _ in nil },
    isReadOnlyVolume: { _ in false }, volumeURL: { _ in nil }, isDevelopmentBuild: { _ in true })
check(ApplicationMover.locate(elsewhere, environment: development).kind == .development, "an unsigned build never offers to move")
check(ApplicationMover.locate(applications.appendingPathComponent("Clockin.app"), environment: plainEnvironment).kind == .installed,
      "the copy in Applications is installed")

print("\(passed) Mac mover checks passed")
