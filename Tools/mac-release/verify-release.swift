import CryptoKit
import Foundation

// Verify with the public key embedded in the application, never the private
// Keychain key. This also catches accidentally signing with a different key.
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw NSError(domain: "ClockinRelease", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

func verify() throws {
    if CommandLine.arguments.dropFirst().contains("--dry-run") {
        print("Verify feed length and Ed25519 signature before XML parsing; verify HTTPS enclosure lengths and signatures with the shipped public key, then release metadata. No files read.")
        return
    }
    try require(CommandLine.arguments.count == 3, "Usage: swift Tools/mac-release/verify-release.swift appcast.xml Info.plist [--dry-run]")
    let feedURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let plistURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as? [String: Any]
    guard let encodedKey = plist?["SUPublicEDKey"] as? String, let keyData = Data(base64Encoded: encodedKey) else {
        throw NSError(domain: "ClockinRelease", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing public update key"])
    }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    let feed = try Data(contentsOf: feedURL)
    let marker = Data("<!-- sparkle-signatures:\n".utf8)
    guard let markerRange = feed.range(of: marker, options: .backwards),
          let block = String(data: feed[markerRange.lowerBound...], encoding: .utf8) else {
        throw NSError(domain: "ClockinRelease", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing feed signature"])
    }
    let lines = block.components(separatedBy: "\n")
    try require(lines.count == 5 && lines[3] == "-->" && lines[4].isEmpty, "Invalid signature block")
    guard let signatureLine = lines.first(where: { $0.hasPrefix("edSignature: ") }),
          let signature = Data(base64Encoded: String(signatureLine.dropFirst("edSignature: ".count))),
          let lengthLine = lines.first(where: { $0.hasPrefix("length: ") }),
          let length = Int(lengthLine.dropFirst("length: ".count)) else {
        throw NSError(domain: "ClockinRelease", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid feed signature metadata"])
    }
    let content = feed[..<markerRange.lowerBound]
    try require(length == content.count, "Feed length mismatch")
    try require(key.isValidSignature(signature, for: content), "Feed signature does not match the app's public key")
    let document = try XMLDocument(data: content, options: .nodeLoadExternalEntitiesNever)
    let items = try document.nodes(forXPath: "/rss/channel/item")
    try require(items.count == 1, "Expected exactly one full update (no deltas)")
    let enclosures = try document.nodes(forXPath: "/rss/channel/item/enclosure")
    try require(enclosures.count == 1, "Expected exactly one archive enclosure")
    for node in enclosures {
        guard let element = node as? XMLElement,
              let urlString = element.attribute(forName: "url")?.stringValue,
              let downloadURL = URL(string: urlString),
              let encodedSignature = element.attribute(forName: "sparkle:edSignature")?.stringValue,
              let archiveSignature = Data(base64Encoded: encodedSignature),
              let lengthString = element.attribute(forName: "length")?.stringValue,
              let archiveLength = Int(lengthString) else {
            throw NSError(domain: "ClockinRelease", code: 1, userInfo: [NSLocalizedDescriptionKey: "Incomplete enclosure"])
        }
        try require(downloadURL.scheme == "https" && downloadURL.host != nil, "Update URL must use HTTPS")
        // Bind signed metadata to this build, not merely to another valid release.
        guard let version = plist?["CFBundleShortVersionString"] as? String,
              let build = plist?["CFBundleVersion"] as? String,
              let item = items.first as? XMLElement else {
            throw NSError(domain: "ClockinRelease", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing release version/build"])
        }
        let namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"
        try require(item.elements(forLocalName: "version", uri: namespace).first?.stringValue == build, "Feed build does not match app")
        try require(item.elements(forLocalName: "shortVersionString", uri: namespace).first?.stringValue == version, "Feed version does not match app")
        try require(item.elements(forLocalName: "minimumSystemVersion", uri: namespace).first?.stringValue == "14.0", "Expected macOS 14.0 minimum")
        let expectedURL = "https://github.com/ismailakdag/clockin/releases/download/macos-v\(version)/Clockin-\(version)-\(build).dmg"
        try require(urlString == expectedURL, "Unexpected release archive URL")
        let name = downloadURL.lastPathComponent
        try require(!name.isEmpty && name != "." && name != ".." && !name.contains("/"), "Invalid archive name")
        let archive = try Data(contentsOf: feedURL.deletingLastPathComponent().appendingPathComponent(name), options: .mappedIfSafe)
        try require(archive.count == archiveLength, "Archive length mismatch: \(name)")
        try require(key.isValidSignature(archiveSignature, for: archive), "Invalid archive signature: \(name)")
        print("Verified archive: \(name)")
    }
    print("Verified signed feed with the application's public key.")
}

do { try verify() } catch {
    FileHandle.standardError.write(Data("Verification failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
