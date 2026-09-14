import SwiftUI

struct ReminderEndTimeView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    let running: RunningSession
    @State private var end: Date
    @State private var summary: WorkSession?
    @State private var errorMessage: String?

    init(running: RunningSession) {
        self.running = running
        _end = State(initialValue: .now)
    }

    var body: some View {
        Group {
            if let summary {
                SessionSummaryView(session: summary)
            } else {
                NavigationStack {
                    Form {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            DatePicker("Stopped working at", selection: $end,
                                in: LongSessionReminderSchedule.earliestEnd(running: running, now: context.date)...max(running.start, context.date),
                                displayedComponents: [.date, .hourAndMinute])
                        }
                        if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    }
                    .scrollContentBackground(.hidden)
                    .background(palette.background)
                    .navigationTitle("Set end time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Clock out", action: clockOut)
                        }
                    }
                }
            }
        }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
    }

    private func clockOut() {
        guard LongSessionReminderSchedule.matches(start: running.start, running: store.running) else {
            errorMessage = "This session is no longer running."
            return
        }
        guard LongSessionReminderSchedule.validEnd(end, running: running, now: .now) else {
            errorMessage = "Choose a time between when you last resumed and now."
            return
        }
        let saved = store.clockOut(at: end)
        SessionMirror.shared.refresh()
        guard store.running == nil, let saved else {
            errorMessage = store.statusMessage ?? "Could not save this session."
            return
        }
        summary = saved
    }
}
