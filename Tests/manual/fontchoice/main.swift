import Foundation
import SwiftUI

var checks = 0
@MainActor func check(_ condition: @autoclosure () throws -> Bool, _ message: String) rethrows {
    guard try condition() else { fatalError(message) }
    checks += 1
    print("ok: \(message)")
}
let decoder = JSONDecoder()
let encoder = JSONEncoder()
check(ClockinFontChoice.selected(nil) == .system, "new and existing users with no font preference start on System")
check(ClockinFontChoice.selected("Future Font") == .system, "unknown preference falls back to System")
let expected: [Font.Design] = [.default, .rounded, .serif, .monospaced]
var resolvedFontNames: Set<String> = []
for (font, design) in zip(ClockinFontChoice.allCases, expected) {
    check(font.design == design && ClockinFontChoice.selected(font.rawValue) == font, "\(font) selection/design")
    let native = RollingNumberFont.resolve(size: 34, weight: .semibold, design: font.design)
    resolvedFontNames.insert(native.fontName)
    let layout = RollingNumberFont.layout("1,234.56", font: native)
    check(native.pointSize == 34 && layout.lineHeight > 0 && layout.widths.allSatisfy { $0 > 0 },
          "\(font) rolling font resolves and measures")
    for theme in ClockinThemeChoice.allCases {
        let colors = theme.palette
        let palette = theme.palette(font: font)
        check(colors.fontDesign == .default, "\(theme) never imposes typography")
        check(palette.fontDesign == design && palette.dynamicIslandPalette.fontDesign == design,
              "\(theme)/\(font) respects choice, including Dynamic Island")
        check(palette.background == colors.background && palette.accent == colors.accent
              && palette.secondary == colors.secondary && palette.colorScheme == colors.colorScheme
              && palette.actionForeground == colors.actionForeground, "\(theme)/\(font) keeps colors")
    }
}
check(resolvedFontNames.count == 4, "rolling font produces four distinct native designs")
let legacySnapshot = Data(#"{"day":810000000,"completedToday":3600,"earnedToday":25,"hourlyRate":25,"currencyCode":"USD","theme":"Synthwave"}"#.utf8)
let oldSnapshot = try decoder.decode(ClockinSnapshot.self, from: legacySnapshot)
check(oldSnapshot.font == .system && oldSnapshot.theme == .synthwave, "legacy snapshot keeps color, defaults font to System")
check(ClockinSnapshot.empty.font == .system, "empty snapshot uses System")
let legacyState = Data(#"{"timerStart":810000000,"hourlyRate":25,"note":"old relay","theme":"Terminal Amber"}"#.utf8)
let oldState = try decoder.decode(ClockinActivityState.self, from: legacyState)
check(oldState.font == .system && oldState.theme == .terminalAmber, "legacy full content state decodes without font")
let legacyTick = Data(#"{"remoteTick":true,"updatedAt":810000030}"#.utf8)
let tick = try decoder.decode(ClockinActivityState.self, from: legacyTick)
check(tick.remoteTick && tick.font == .system, "relay time-only push still decodes")
for font in ClockinFontChoice.allCases {
    var snapshot = oldSnapshot; snapshot.font = font
    try check(decoder.decode(ClockinSnapshot.self, from: encoder.encode(snapshot)) == snapshot, "\(font) snapshot round trip")
    check(font == .system || snapshot != oldSnapshot, "font-only change invalidates snapshot equality")
    var state = oldState; state.font = font; state.updatedAt = state.timerStart
    try check(decoder.decode(ClockinActivityState.self, from: encoder.encode(state)) == state, "\(font) state round trip")
    check(state.hasSameCalculation(as: oldState), "\(font) change does not require immutable attribute replacement")
    let applied = state.applyingTick(tick, expiresAt: nil, now: state.timerStart.addingTimeInterval(60))
    check(applied.font == font && applied.earnedAtUpdate > state.earnedAtUpdate, "tick retains local font while advancing earnings")
    check(oldState.displayFont(localFont: font) == font, "latest snapshot overrides font from immutable activity attributes")
    check(state.displayFont(localFont: nil) == font, "content font is fallback if snapshot unavailable")
}
for raw: Any in [NSNull(), "Future Font"] {
    for (data, isSnapshot) in [(legacySnapshot, true), (legacyState, false), (legacyTick, false)] {
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object["font"] = raw
        let payload = try JSONSerialization.data(withJSONObject: object)
        if isSnapshot {
            try check(decoder.decode(ClockinSnapshot.self, from: payload).font == .system, "null/unknown snapshot font defaults to System")
        } else {
            try check(decoder.decode(ClockinActivityState.self, from: payload).font == .system, "null/unknown activity font defaults to System")
        }
    }
}
print("\(checks) font choice checks passed")
