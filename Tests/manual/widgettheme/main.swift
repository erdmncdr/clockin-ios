// Depo kokunden: swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-widgettheme-module-cache Shared/Core/AppLanguage.swift Shared/Theme/ClockinThemeChoice.swift Shared/Core/Models.swift Shared/Sync/AppGroup.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/widgettheme/main.swift -o /tmp/clockin-widgettheme-checks && /tmp/clockin-widgettheme-checks
import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

let legacy = Data(#"{"day":810000000,"completedToday":3600,"earnedToday":25,"running":{"start":810000100,"accumulated":600,"note":"Theme check"},"hourlyRate":25,"currencyCode":"USD"}"#.utf8)
let decoder = JSONDecoder()
let old = try decoder.decode(ClockinSnapshot.self, from: legacy)
check(old.theme == .carbon, "legacy snapshot defaults to Carbon")
check(old.completedToday == 3600 && old.earnedToday == 25 && old.running?.accumulated == 600,
      "legacy totals and paused session survive decoding")
check(ClockinSnapshot.empty.theme == .carbon, "empty snapshot defaults to Carbon")

for theme in ClockinThemeChoice.allCases {
    var snapshot = old
    snapshot.theme = theme
    let encoded = try JSONEncoder().encode(snapshot)
    let restored = try decoder.decode(ClockinSnapshot.self, from: encoded)
    check(restored == snapshot, "\(theme.rawValue) snapshot round trips")
    if theme != .carbon {
        check(snapshot != old, "\(theme.rawValue) alone changes mirror equality")
    }
    let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    check(object["theme"] as? String == theme.rawValue, "\(theme.rawValue) uses the Settings raw value")
}

var object = try JSONSerialization.jsonObject(with: legacy) as! [String: Any]
object["theme"] = "Future Theme"
let unknown = try decoder.decode(ClockinSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
check(unknown == old, "unknown theme safely falls back to Carbon")
object["theme"] = NSNull()
let nullTheme = try decoder.decode(ClockinSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
check(nullTheme == old, "null theme safely falls back to Carbon")
check(ClockinThemeChoice.selected("invalid") == .carbon, "invalid Settings value falls back to Carbon")

// Tema uyumlulugu, bozuk zorunlu alanlari gecerli veri gibi gostermemeli.
object["hourlyRate"] = "invalid"
let malformed = try JSONSerialization.data(withJSONObject: object)
check((try? decoder.decode(ClockinSnapshot.self, from: malformed)) == nil,
      "invalid required data is still rejected")
print("\(checks) widget theme checks passed")
