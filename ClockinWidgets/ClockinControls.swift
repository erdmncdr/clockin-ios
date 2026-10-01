import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, macOS 26.0, *)
struct ClockinControlProvider: ControlValueProvider {
    var previewValue: ClockinControlState { .off }

    func currentValue() async throws -> ClockinControlState {
        ClockinControlState(snapshot: ClockinSnapshot.load() ?? .empty)
    }
}

@available(iOS 18.0, macOS 26.0, *)
struct ClockinTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.erdmncdr.clockin.clockInOut",
            provider: ClockinControlProvider()
        ) { state in
            ControlWidgetToggle(LocalizedStringResource(String.LocalizationValue("Clockin"), bundle: .atURL(Bundle.main.bundleURL)), isOn: state.isOn, action: SetClockedInIntent()) { isOn in
                Label(state.valueLabel(isOn: isOn), systemImage: isOn ? "timer" : "clock")
            }
        }
        .displayName(LocalizedStringResource(String.LocalizationValue("Clock In / Clock Out"), bundle: .atURL(Bundle.main.bundleURL)))
        .description(LocalizedStringResource(String.LocalizationValue("Start the timer or clock out and save your session. Paused sessions stay on."), bundle: .atURL(Bundle.main.bundleURL)))
    }
}

@available(iOS 18.0, macOS 26.0, *)
struct ClockinPauseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.erdmncdr.clockin.pauseResume",
            provider: ClockinControlProvider()
        ) { state in
            ControlWidgetButton(action: TogglePauseIntent()) {
                Label(state.pauseTitle, systemImage: state.pauseSymbol)
            }
        }
        .displayName(LocalizedStringResource(String.LocalizationValue("Pause / Resume"), bundle: .atURL(Bundle.main.bundleURL)))
        .description(LocalizedStringResource(String.LocalizationValue("Pause or resume your Clockin session. Does nothing when no session is running."), bundle: .atURL(Bundle.main.bundleURL)))
    }
}
