import AppKit
import Combine
import SwiftUI

extension MenuBarController.Host {
    @MainActor
    static func clockin() -> Self {
        let store = SharedStore.clock
        let exchangeRates = SharedStore.exchangeRates
        @Sendable func flag(_ key: String, _ fallback: Bool) -> Bool {
            UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
        }
        let openApp: @MainActor () -> Void = {
            MenuBarController.shared.close(animated: false)
            MainWindowController.shared.show(store: store, exchangeRates: exchangeRates)
        }
        return Self(
            status: {
                // Idle there is nothing to compute: only the icon shows.
                guard let running = store.running else { return MenuBarStatus(state: .idle, text: nil) }
                // This Mac's display preference leaves minimal mode and saved fields intact.
                guard flag("Clockin.MacShowMenuBarDetails", true) else {
                    return MenuBarStatus(state: running.isPaused ? .paused : .running, text: nil)
                }
                let now = Date()
                return MenuBarStatus.make(
                    isRunning: true,
                    isPaused: running.isPaused,
                    sessionElapsed: store.elapsed(at: now),
                    sessionEarnings: store.currentEarnings(at: now),
                    currencyCode: store.currencyCode,
                    tryRate: exchangeRates.latestRate,
                    todayDuration: store.todayDuration(at: now),
                    monthDuration: store.monthDuration(at: now),
                    dailyGoalHours: UserDefaults.standard.double(forKey: "Clockin.GoalDailyHours"),
                    monthlyGoalHours: UserDefaults.standard.double(forKey: "Clockin.GoalMonthlyHours"),
                    fields: .init(
                        hours: flag("Clockin.MinimalShowHours", true),
                        seconds: flag("Clockin.MinimalShowSeconds", false),
                        earnings: flag("Clockin.MinimalShowEarnings", true),
                        tryEquivalent: flag("Clockin.MinimalShowTRY", true),
                        goal: flag("Clockin.MinimalShowGoal", false)
                    )
                )
            },
            minimalMode: { flag("Clockin.MinimalMode", false) },
            changes: Publishers.Merge3(
                store.objectWillChange.map { _ in () },
                exchangeRates.objectWillChange.map { _ in () },
                // Defaults bildirimi arka planda gelebilir; `map` de ana aktor sayilip
                // giriste coker, `@Sendable` onu yalitimsiz tutar (25).
                NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).map { @Sendable _ in () }
            ).eraseToAnyPublisher(),
            content: { close in
                AnyView(
                    MacLocalizedContent { MenuBarPanelView(actions: MenuBarPanelActions(
                        openApp: openApp,
                        close: close,
                        checkForUpdates: {
                            MenuBarController.shared.close(animated: false)
                            UpdateChecker.shared.checkForUpdates()
                        },
                        quit: { NSApp.terminate(nil) }
                    ))
                    // Uyari store'u ortamdan okur; ortam nesnelerinin icinde kalmali.
                    .timerPersistenceAlert(store: store)
                    .environmentObject(store)
                    .environmentObject(exchangeRates)
                    .environmentObject(FocusRadioController.shared)
                    .environmentObject(UpdateChecker.shared)
                    }
                )
            },
            menu: {
                let menu = NSMenu()
                menu.addItem(ClosureMenuItem(String(localized: "Open Clockin", bundle: .app), action: openApp))
                menu.addItem(.separator())
                let pending = UpdateChecker.shared.pendingVersion
                let updates = ClosureMenuItem(pending.map { String(localized: "Install Clockin \($0)…", bundle: .app) } ?? String(localized: "Check for Updates…", bundle: .app)) {
                    UpdateChecker.shared.checkForUpdates()
                }
                updates.isEnabled = UpdateChecker.shared.isReady
                menu.addItem(updates)
                menu.addItem(ClosureMenuItem(String(localized: "Quit Clockin", bundle: .app)) { NSApp.terminate(nil) })
                menu.autoenablesItems = false
                return menu
            }
        )
    }
}

