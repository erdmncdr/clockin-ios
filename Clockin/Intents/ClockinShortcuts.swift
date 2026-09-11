import AppIntents

/// Kisayollar uygulamasi, Siri ve Eylem dugmesi icin hazir kisayollar.
/// Uygulama basina tek bir saglayici olabilir; bu yuzden uzantida degil.
struct ClockinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ClockInIntent(),
            phrases: ["Clock in with \(.applicationName)", "Start \(.applicationName)"],
            shortTitle: "Clock In",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: ClockOutIntent(),
            phrases: ["Clock out with \(.applicationName)", "Stop \(.applicationName)"],
            shortTitle: "Clock Out",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: TogglePauseIntent(),
            phrases: ["Pause \(.applicationName)", "Resume \(.applicationName)"],
            shortTitle: "Pause or Resume",
            systemImageName: "pause.fill"
        )
    }
}
