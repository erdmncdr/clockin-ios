#if !WIDGET_EXTENSION
import Foundation
import Security

enum CloudSyncCapability {
    static let containerID = "iCloud.com.erdmncdr.clockin"

    // Info.plist tek basina imzali yetkiyi kanitlamaz. Sonuc surec boyunca sabittir.
    static let isEntitled: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let containers = SecTaskCopyValueForEntitlement(task,
            "com.apple.developer.icloud-container-identifiers" as CFString, nil) as? [String]
        let services = SecTaskCopyValueForEntitlement(task,
            "com.apple.developer.icloud-services" as CFString, nil) as? [String]
        return permits(containers: containers, services: services)
        #else
        // SecTask iOS'un herkese acik SDK'sinda yok. Yuklenen Mach-O'nun imzali
        // XML yetki blogunu oku; eksik/bilinmeyen bicimde CloudKit'e girme.
        guard let url = Bundle.main.executableURL,
              let bytes = try? Data(contentsOf: url, options: .mappedIfSafe),
              let entitlements = signedEntitlements(in: bytes) else { return false }
        return permits(containers: entitlements["com.apple.developer.icloud-container-identifiers"] as? [String],
                       services: entitlements["com.apple.developer.icloud-services"] as? [String])
        #endif
    }()

    static func permits(containers: [String]?, services: [String]?) -> Bool {
        containers?.contains(containerID) == true && services?.contains("CloudKit") == true
    }

    // Sinir denetimli okuyucu: ne hizalanmamis pointer ne de zorunlu donusum kullanir.
    static func signedEntitlements(in bytes: Data) -> [String: Any]? {
        func word(_ offset: Int, bigEndian: Bool = false) -> Int? {
            guard offset >= 0, bytes.count >= 4, offset <= bytes.count - 4 else { return nil }
            let part = bytes[offset..<(offset + 4)]
            return (bigEndian ? Array(part) : Array(part.reversed())).reduce(0) { ($0 << 8) | Int($1) }
        }
        guard word(0) == 0xfeedfacf, let count = word(16), count <= 4096,
              let commandBytes = word(20), commandBytes <= bytes.count - 32 else { return nil }
        let commandsEnd = 32 + commandBytes
        var cursor = 32
        for _ in 0..<count {
            guard let command = word(cursor), let size = word(cursor + 4), size >= 8,
                  size <= commandsEnd - cursor else { return nil }
            if command == 0x1d { // LC_CODE_SIGNATURE
                guard size >= 16, let offset = word(cursor + 8), let length = word(cursor + 12),
                      length >= 12, length <= 1_048_576, offset <= bytes.count - length,
                      word(offset, bigEndian: true) == 0xfade0cc0,
                      let blobLength = word(offset + 4, bigEndian: true), blobLength <= length, blobLength >= 12,
                      let slots = word(offset + 8, bigEndian: true), slots <= (blobLength - 12) / 8 else { return nil }
                for index in 0..<slots {
                    let entry = offset + 12 + index * 8
                    guard let kind = word(entry, bigEndian: true),
                          let relative = word(entry + 4, bigEndian: true), relative >= 12,
                          relative <= blobLength - 8 else { return nil }
                    guard kind == 5 else { continue } // CSSLOT_ENTITLEMENTS
                    let start = offset + relative
                    guard word(start, bigEndian: true) == 0xfade7171,
                          let size = word(start + 4, bigEndian: true), size >= 8,
                          size <= blobLength - relative else { return nil }
                    return (try? PropertyListSerialization.propertyList(
                        from: bytes.subdata(in: (start + 8)..<(start + size)), format: nil)) as? [String: Any]
                }
                return nil
            }
            cursor += size
        }
        return nil
    }
}
#endif
