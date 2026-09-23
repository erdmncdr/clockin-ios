import SwiftUI

private struct TimerPersistenceAlert: ViewModifier {
    @EnvironmentObject private var store: ClockStore

    func body(content: Content) -> some View {
        content.alert("Could not save timer", isPresented: Binding(
            get: { store.timerPersistenceError != nil },
            set: { if !$0 { store.timerPersistenceError = nil } }
        )) {
            Button("OK") { store.timerPersistenceError = nil }
        } message: {
            Text(store.timerPersistenceError ?? String(localized: "Please try again."))
        }
    }
}

extension View {
    func timerPersistenceAlert() -> some View { modifier(TimerPersistenceAlert()) }
}
