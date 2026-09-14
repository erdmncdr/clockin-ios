import SwiftUI

struct UsageGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            List {
                Section {
                    topic("Clock in, pause, and clock out", icon: "play.fill",
                          detail: "Tap Clock in on Today to start. Pause stops adding time and keeps the session open; Resume continues it. Clock out saves the session and shows its summary. Cancel session discards the active session after confirmation.")
                    topic("Start with elapsed time", icon: "clock.arrow.circlepath",
                          detail: "If you forgot to start, tap Start with elapsed time on Today while no session is running. Enter hours and minutes, add an optional note, check the preview, then tap Start. The timer continues from that duration.")
                    topic("Add and edit past entries", icon: "pencil",
                          detail: "Tap the plus button on Today or History to add completed work. Choose the day, start and end times, and a note. An end time earlier than the start means the next day. Tap a session in Today or History to edit it, then Save.")
                    topic("Overlap warnings", icon: "exclamationmark.triangle",
                          detail: "The entry editor warns when your times overlap another saved entry. History also flags overlaps. You can still save, but both entries count toward your totals. Review their times if your totals look too high.")
                } header: {
                    Text("Track your time")
                }

                Section {
                    topic("Import a CSV or pasted timecards", icon: "doc.text.magnifyingglass",
                          detail: "Tap the gear on Today to open Settings, then Data > Import timecards. Choose CSV file, or paste a task block or timecards page and tap Review. CSV needs Start Time and End Time columns with ISO 8601 dates. Pasted text needs English dates, a status, source, and 24-hour times; include the date range and years when available. Check recognized dates, duration, and any Approved total warning before importing. Review New, Matched corrections, and Duplicate skipped entries. Matched entries are corrected; duplicates do not add another copy. Every new entry and correction starts selected: tap a row, or None and All in a section, to leave it out. Only selected rows are imported.")
                    topic("Review your own entries", icon: "checklist",
                          detail: "In the import review, Your own entries lists Clockin entries not covered by the incoming rows. Days in file checks only dates with imported rows; Whole range checks every day from the first to the last imported date. Review these entries and choose what to keep or delete before importing. Deletions require confirmation. Import older history first and check totals before adding newer exports.")
                    topic("Rate schedules", icon: "calendar.badge.plus",
                          detail: "In Settings (the gear on Today), open Pay > Rate schedule. Add a rate period or tap one to edit its hourly rate, start date, and optional end date. The end date is included. If periods overlap, the applicable one with the latest start wins. Completed sessions use the rate for their start date; the running session uses the currently effective rate. Changing periods recalculates earnings.")
                } header: {
                    Text("Manage your records")
                }

                Section {
                    topic("Earnings chart and USD/TRY", icon: "chart.bar.xaxis",
                          detail: "Open History, choose a period, and tap a day in the earnings chart for its hours and money. USD accounts can switch the chart to TRY using each day's rate or the nearest earlier available rate. Days without a historical rate are omitted in TRY. The approximate TRY amount beside the period total uses the current rate instead. Today shows the latest USD/TRY rate and its status. Overnight sessions count toward the date they started.")
                    topic("Money Momentum", icon: "flame.fill",
                          detail: "Today shows your effective hourly rate divided by 3,600, plus TRY per second for USD accounts when a rate is available. While a session is open, the strip tracks its next multiple-of-ten earnings target. At an exact multiple, the target moves to the next ten. When paused or idle, Your earning power shows the potential rate; paused time does not earn more money.")
                    topic("Insights", icon: "chart.xyaxis.line",
                          detail: "Insights shows your goals, the work heatmap by day, week or month, your rhythm and reports. Use Edit goals to set daily and monthly hours, including values like 7.5; zero turns a goal off. Once a goal is set, Today shows its progress too. While you work, the goals card says when you reach today's goal; otherwise it says when you would reach it if you started now. Goals are for tracking only and do not change your level or badges.")
                    topic("Level and badges", icon: "rosette",
                          detail: "Open Badges, or tap your level or the companion card on Today, to see your level, XP, streaks and all badges. Expand How XP works for the breakdown. Tap a badge for its requirement and current progress. Current-streak badges lock again when a streak ends.")
                } header: {
                    Text("Understand your progress")
                }

                Section {
                    topic("Backups and restoring", icon: "externaldrive.fill",
                          detail: "In Settings, Data > Export backup shares a portable JSON copy. Automatic backups lists saved copies with their dates and entry counts; open one to restore it. Clockin saves an automatic copy once a day while you use it. Restore from file lets you choose a JSON backup. Restoring replaces the current entries and running timer, but saves your current data first. Use Automatic backups to return to that saved copy.")
                    topic("Focus chime", icon: "bell.badge",
                          detail: "In Settings > Focus, turn on Focus chime to request notification permission. Choose 1-120 minutes of worked time and the default notification sound or ringtone. Preview needs notification permission. Pauses do not count. New sessions and interval or enable changes skip past chimes and use the next worked-time boundary. Up to 20 chimes are queued, refreshed while Clockin is open and when you return. Pausing, clocking out or cancelling clears pending chimes, also when you do it from the widget, the Live Activity or Shortcuts. iOS controls volume, silent mode, Focus, and delivery timing; there is no chime volume slider or Mac sound library.")
                    topic("Long session reminder", icon: "clock.badge.exclamationmark",
                          detail: "In Settings, choose Off, 8 h, 10 h (default), or 12 h for Long session reminder and allow notifications. Breaks do not count. Still working? lets you Clock out in the background, Set end time in the app, or Remind in 1 hour for this session. The end time must be between when you last resumed and now. Pausing, ending or cancelling the session, or choosing Off clears the reminder. An already reached threshold prompts once per session, including after reopening Clockin; only Remind in 1 hour requests another alert. Tapping the notification body opens Clockin.")
                    topic("Focus radio", icon: "radio",
                          detail: "In Settings > Focus, play or stop Radio Paradise and adjust radio volume from 0-100%. Streaming uses internet data. Connecting and error messages report loading or connection failure; tap Play to retry. Lock Screen Now Playing offers play and pause. Audio interruptions and unplugging headphones stop playback; press Play to restart. Playback continues with the screen locked.")
                    topic("Widgets and Live Activity", icon: "apps.iphone",
                          detail: "Add Clockin's Today widget to your Home Screen or Lock Screen to see time and earnings. The medium Home Screen widget has Clock in, Pause or Resume, and Clock out controls. During a session, Live Activity shows the timer on the Lock Screen and on supported devices in Dynamic Island, when Live Activities are allowed. Its Lock Screen and expanded island controls let you pause, resume, or clock out.")
                    topic("Shortcuts and Siri", icon: "square.stack.3d.up",
                          detail: "In Shortcuts, use Clockin's Clock In, Clock Out, and Pause or Resume actions. You can also ask Siri to clock in with Clockin, clock out with Clockin, or pause Clockin. Pause or Resume toggles the current session's state, and Clock In also resumes a paused session.")
                } header: {
                    Text("Keep Clockin handy")
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("How to use Clockin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
    }

    private func topic(_ title: String, icon: String, detail: String) -> some View {
        // Acilir satirlar uzun rehberde konu bulmayi ve buyuk yaziyla okumayi kolaylastirir.
        DisclosureGroup {
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        } label: {
            Label {
                Text(title).foregroundStyle(.primary)
            } icon: {
                Image(systemName: icon).foregroundStyle(palette.accent)
            }
        }
        .listRowBackground(palette.surface)
    }
}
