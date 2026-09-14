import AppIntents
import Foundation

// `LiveActivityIntent`: widget ya da Live Activity dugmesinden cagrilsa bile
// uygulamanin surecinde calisir, boylece ekrandaki magazayla ayni ornegi
// degistirir. Tipler widget uzantisinda da derlenmeli ki dugmeler onlara
// basvurabilsin; uzantidaki dal hic calismaz.

struct ClockInIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Clock In"
    static let description = IntentDescription("Starts the Clockin timer, or resumes it if it is paused.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if WIDGET_EXTENSION
        return .result(dialog: "Open Clockin to continue.")
        #else
        let store = SharedStore.clock
        // Mac'teki Option-Command-I gibi: duraklatilmis oturum devam eder.
        if let running = store.running {
            guard running.isPaused else {
                return .result(dialog: "A session is already running.")
            }
            store.resume()
            SessionMirror.shared.refresh()
            await SessionMirror.shared.finishPendingUpdates()
            return .result(dialog: "Resumed.")
        }
        store.clockIn()
        SessionMirror.shared.refresh()
        await SessionMirror.shared.finishPendingUpdates()
        return .result(dialog: "Clocked in.")
        #endif
    }
}

struct ClockOutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Clock Out"
    static let description = IntentDescription("Stops the running session and saves it to history.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if WIDGET_EXTENSION
        return .result(dialog: "Open Clockin to continue.")
        #else
        let store = SharedStore.clock
        guard let session = store.clockOut() else {
            return .result(dialog: "No session is running.")
        }
        SessionMirror.shared.refresh()
        await SessionMirror.shared.finishPendingUpdates()
        let duration = DurationText.compact(session.duration)
        let earned = store.earnings(for: session).money(code: store.currencyCode)
        return .result(dialog: "Clocked out after \(duration), earned \(earned).")
        #endif
    }
}

struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume"
    static let description = IntentDescription("Pauses the running session, or resumes it if it is paused.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if WIDGET_EXTENSION
        return .result(dialog: "Open Clockin to continue.")
        #else
        let store = SharedStore.clock
        guard let running = store.running else {
            return .result(dialog: "No session is running.")
        }
        if running.isPaused {
            store.resume()
            SessionMirror.shared.refresh()
            await SessionMirror.shared.finishPendingUpdates()
            return .result(dialog: "Resumed.")
        }
        store.pause()
        SessionMirror.shared.refresh()
        await SessionMirror.shared.finishPendingUpdates()
        return .result(dialog: "Paused.")
        #endif
    }
}
