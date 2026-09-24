import SwiftUI
import Observation

/// Switches Clockin's language from Settings without a relaunch. The app's
/// root view is keyed on `language`, so every view is rebuilt and text
/// computed once inside a view is looked up again.
@MainActor @Observable
final class LanguageSwitch {
    static let shared = LanguageSwitch()
    private(set) var language = AppLanguage.stored
    /// Set just before the rebuild, so Today reopens Settings where the user left it.
    var reopenSettings = false

    func choose(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }
        // Lookups switch before the views are rebuilt.
        AppLanguage.shared?.set(newLanguage.rawValue, forKey: AppLanguage.key)
        AppLanguage.applyToSystem()
        reopenSettings = true
        language = newLanguage
        // Text already handed to iOS is rebuilt too: widgets, the Live
        // Activity and pending notifications.
        let store = SharedStore.clock
        SessionMirror.shared.refresh()
        SessionMirror.shared.refreshChimes(force: true)
        LongSessionReminderController.shared.update(running: store.running, force: true)
        NudgeController.shared.update(store: store)
    }
}
