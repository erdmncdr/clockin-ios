import CryptoKit
import Foundation

// No shipping key is accessed. The throwaway private key exists only in memory.
if CommandLine.arguments.dropFirst().contains("--dry-run") {
    print("Create synthetic signed feeds, fake DMGs and public-key plists under the supplied /tmp directory; no Keychain or network.")
    exit(0)
}
guard CommandLine.arguments.count == 2, CommandLine.arguments[1].hasPrefix("/tmp/") else {
    fatalError("Usage: swift test-fixtures.swift /tmp/fixture-directory")
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let key = Curve25519.Signing.PrivateKey()
let archive = Data("This is a synthetic DMG payload, not an installable application.".utf8)
let archiveName = "Clockin-2.0.0-11.dmg"
let archiveSignature = try key.signature(for: archive).base64EncodedString()
let cases = ["valid", "same-length-feed", "missing-signature", "wrong-key", "archive-length", "http", "wrong-build", "wrong-url", "bad-block"]
for test in cases {
    let directory = root.appendingPathComponent(test)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = "\(test == "http" ? "http" : "https")://github.com/ismailakdag/clockin/releases/download/macos-v\(test == "wrong-url" ? "9.9.9" : "2.0.0")/\(archiveName)"
    let xml = """
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
    <title>Clockin 2.0.0</title><sparkle:version>\(test == "wrong-build" ? "12" : "11")</sparkle:version>
    <sparkle:shortVersionString>2.0.0</sparkle:shortVersionString><sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    <enclosure url="\(url)" length="\(archive.count)" sparkle:edSignature="\(archiveSignature)" type="application/octet-stream"/>
    </item></channel></rss>

    """
    let content = Data(xml.utf8)
    let signature = try key.signature(for: content).base64EncodedString()
    var feed = xml + "<!-- sparkle-signatures:\nedSignature: \(signature)\nlength: \(content.count)\n-->\n"
    if test == "same-length-feed" { feed = feed.replacingOccurrences(of: "<title>Clockin", with: "<title>Clackin") }
    if test == "missing-signature" { feed = xml }
    if test == "bad-block" { feed += "trailing junk" }
    try Data(feed.utf8).write(to: directory.appendingPathComponent("appcast.xml"))
    try (test == "archive-length" ? archive + Data([0]) : archive).write(to: directory.appendingPathComponent(archiveName))
    let publicKey = test == "wrong-key" ? Curve25519.Signing.PrivateKey().publicKey : key.publicKey
    let plist: [String: Any] = ["SUPublicEDKey": publicKey.rawRepresentation.base64EncodedString(),
                                "CFBundleShortVersionString": "2.0.0", "CFBundleVersion": "11"]
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        .write(to: directory.appendingPathComponent("Info.plist"))
}
