import Foundation

/// Clockin's own language, chosen in Settings. The app and the widget
/// extension both read it from the App Group, so the widgets, the Live
/// Activity and the controls follow the same choice as the app.
///
/// Self-contained so the standalone checks can compile it on its own.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Follow the iPhone's languages.
    case automatic
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }
    static let key = "Clockin.Language"
    /// The same suite as `AppGroup.identifier`.
    nonisolated(unsafe) static let shared = UserDefaults(suiteName: "group.com.erdmncdr.clockin")

    static var stored: AppLanguage {
        shared?.string(forKey: key).flatMap(AppLanguage.init(rawValue:)) ?? .automatic
    }

    /// The language's name written in that language, so it reads the same
    /// whichever language the app is in.
    var nativeName: String? {
        guard self != .automatic else { return nil }
        let locale = Locale(identifier: rawValue)
        return locale.localizedString(forLanguageCode: rawValue)?.capitalized(with: locale)
    }

    /// For SwiftUI's `\.locale`, which picks the language of `Text` literals.
    static var locale: Locale {
        let language = stored
        return language == .automatic ? .autoupdatingCurrent : Locale(identifier: language.rawValue)
    }

    /// For dates and numbers formatted in code: the chosen language with the
    /// iPhone's region, which is what iOS itself uses after a relaunch.
    static var formatLocale: Locale {
        let language = stored
        guard language != .automatic else { return .autoupdatingCurrent }
        var components = Locale.Components(locale: .autoupdatingCurrent)
        components.languageComponents = .init(identifier: language.rawValue)
        return Locale(components: components)
    }

    /// For weekday and month names built from calendar symbols.
    static var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = formatLocale
        return calendar
    }

    /// Lets iOS's own text (system buttons, the next launch) follow the choice.
    static func applyToSystem() {
        let language = stored
        if language == .automatic {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}

extension Bundle {
    /// Where `String(localized:)` looks strings up: the chosen language's
    /// folder, or the main bundle when following the iPhone. Every lookup
    /// passes it, so a change in Settings applies without a relaunch.
    static var app: Bundle { AppLanguageBundle.current }
}

private enum AppLanguageBundle {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: (code: String, bundle: Bundle)?

    static var current: Bundle {
        let language = AppLanguage.stored
        guard language != .automatic else { return .main }
        return lock.withLock {
            if let cache, cache.code == language.rawValue { return cache.bundle }
            let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
            cache = (language.rawValue, bundle)
            return bundle
        }
    }
}
