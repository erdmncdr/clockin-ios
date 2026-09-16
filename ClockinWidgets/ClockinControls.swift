import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct ClockinControlProvider: ControlValueProvider {
    var previewValue: ClockinControlState { .off }

    func currentValue() async throws -> ClockinControlState {
        ClockinControlState(snapshot: ClockinSnapshot.load() ?? .empty)
    }
}

@available(iOS 18.0, *)
struct ClockinTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.erdmncdr.clockin.clockInOut",
            provider: ClockinControlProvider()
        ) { state in
            ControlWidgetToggle("Clockin", isOn: state.isOn, action: SetClockedInIntent()) { isOn in
                Label(state.valueLabel(isOn: isOn), systemImage: isOn ? "timer" : "clock")
            }
        }
        .displayName("Clock In / Clock Out")
        .description("Start the timer or clock out and save your session. Paused sessions stay on.")
    }
}

@available(iOS 18.0, *)
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
        .displayName("Pause / Resume")
        .description("Pause or resume your Clockin session. Does nothing when no session is running.")
    }
}
