import AppIntents
import Foundation

// `LiveActivityIntent`: widget ya da Live Activity dugmesinden cagrilsa bile
// uygulamanin surecinde calisir, boylece ekrandaki magazayla ayni ornegi
// degistirir. Tipler widget uzantisinda da derlenmeli ki dugmeler onlara
// basvurabilsin; uzantidaki dal hic calismaz. Mac'te Live Activity yok;
// ayni niyetler Kisayollar icin duz `AppIntent` olur.
#if os(iOS)
typealias ClockinActionIntent = LiveActivityIntent
#else
typealias ClockinActionIntent = AppIntent
#endif

struct ClockInIntent: ClockinActionIntent {
    #if os(macOS)
    // Mac'te Live Activity niyeti yok; widget dugmesi magazayi degistirebilsin
    // diye uygulamanin surecinde calisir, gerekirse uygulama baslatilir.
    static let openAppWhenRun = true
    #endif
    static let title: LocalizedStringResource = "Clock In"
    static let description = IntentDescription("Starts the Clockin timer, or resumes it if it is paused.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: await run(origin: .widget))
    }

    @MainActor
    func run(origin: TimerOrigin) async -> IntentDialog {
        #if WIDGET_EXTENSION
        return "Open Clockin to continue."
        #else
        guard ExternalTimerStarts.isEnabled else {
            return "Starting from widgets, Control Center and Siri is off in Clockin settings."
        }
        let store = SharedStore.clock
        // Mac'teki Option-Command-I gibi: duraklatilmis oturum devam eder.
        if let running = store.running {
            guard running.isPaused else {
                return "A session is already running."
            }
            store.resume(origin: origin)
            guard store.running?.isPaused == false else {
                return "Could not save the timer change. Open Clockin and try again."
            }
            SessionMirror.shared.refresh()
            await SessionMirror.shared.finishPendingUpdates()
            return "Resumed."
        }
        store.clockIn(origin: origin)
        guard store.running != nil else {
            return "Could not save the timer change. Open Clockin and try again."
        }
        SessionMirror.shared.refresh()
        await SessionMirror.shared.finishPendingUpdates()
        return "Clocked in."
        #endif
    }
}

struct ClockOutIntent: ClockinActionIntent {
    #if os(macOS)
    // Mac'te Live Activity niyeti yok; widget dugmesi magazayi degistirebilsin
    // diye uygulamanin surecinde calisir, gerekirse uygulama baslatilir.
    static let openAppWhenRun = true
    #endif
    static let title: LocalizedStringResource = "Clock Out"
    static let description = IntentDescription("Stops the running session and saves it to history.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: await run(origin: .widget))
    }

    @MainActor
    func run(origin: TimerOrigin) async -> IntentDialog {
        #if WIDGET_EXTENSION
        return "Open Clockin to continue."
        #else
        let store = SharedStore.clock
        guard store.running != nil else {
            // The widget may still show a session that is gone; redraw it.
            SessionMirror.shared.refresh()
            return "No session is running."
        }
        guard let session = store.clockOut(origin: origin) else {
            return "Could not save the session. Your timer has not been stopped. Open Clockin and try again."
        }
        SessionMirror.shared.refresh()
        await SessionMirror.shared.finishPendingUpdates()
        let duration = DurationText.compact(session.duration)
        let earned = store.earnings(for: session).money(code: store.currencyCode)
        return "Clocked out after \(duration), earned \(earned)."
        #endif
    }
}

struct TogglePauseIntent: ClockinActionIntent {
    #if os(macOS)
    // Mac'te Live Activity niyeti yok; widget dugmesi magazayi degistirebilsin
    // diye uygulamanin surecinde calisir, gerekirse uygulama baslatilir.
    static let openAppWhenRun = true
    #endif
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
            guard ExternalTimerStarts.isEnabled else {
                return .result(dialog: "Starting from widgets, Control Center and Siri is off in Clockin settings.")
            }
            store.resume(origin: .widget)
            guard store.running?.isPaused == false else {
                return .result(dialog: "Could not save the timer change. Open Clockin and try again.")
            }
            SessionMirror.shared.refresh()
            await SessionMirror.shared.finishPendingUpdates()
            return .result(dialog: "Resumed.")
        }
        store.pause()
        guard store.running?.isPaused == true else {
            return .result(dialog: "Could not save the timer change. Open Clockin and try again.")
        }
        SessionMirror.shared.refresh()
        await SessionMirror.shared.finishPendingUpdates()
        return .result(dialog: "Paused.")
        #endif
    }
}
