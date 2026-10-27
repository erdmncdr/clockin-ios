import SwiftUI

struct TimerLogRow: View {
    let entry: TimerStartLog.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.action.title).fontWeight(.medium)
                Spacer()
                Text(entry.date.formatted(.relative(presentation: .named).locale(AppLanguage.formatLocale)))
                Text(entry.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened,
                                                          locale: AppLanguage.formatLocale)))
            }
            Text(entry.origin.title).foregroundStyle(.secondary)
            if let provenance = entry.provenance, let wasRunning = entry.wasRunning {
                Text("\(provenance.title) · \(wasRunning ? String(localized: "Session already present", bundle: .app) : String(localized: "No previous session", bundle: .app))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.vertical, 2)
    }
}

struct TimerLogView: View {
    @ObservedObject private var log = TimerStartLog.shared

    var body: some View {
        List {
            if log.entries.isEmpty {
                Text("Nothing yet. Every start, resume and clock-out is listed here with where it came from.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(log.entries) { TimerLogRow(entry: $0) }
            }
        }
        .navigationTitle("Timer log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear") { log.clear() }
                    .disabled(log.entries.isEmpty)
            }
        }
    }
}

#if os(macOS)
struct TimerLogSection: View {
    @ObservedObject private var log = TimerStartLog.shared

    var body: some View {
        Section("Timer log") {
            if log.entries.isEmpty {
                Text("Nothing yet. Every start, resume and clock-out is listed here with where it came from.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(log.entries.prefix(10)) { TimerLogRow(entry: $0) }
            }
            Button("Clear") { log.clear() }
                .disabled(log.entries.isEmpty)
        }
    }
}
#endif
