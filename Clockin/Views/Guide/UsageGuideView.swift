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
                          detail: "In Settings > Pay, turn on Earlier work had a different rate and enter the change date and earlier rate. When you change the hourly rate, choose Today, Pick a date, or Always after reviewing the earnings impact. Work uses the rate for the day it started, including running sessions. Use Rate schedule for more complex periods.")
                } header: {
                    Text("Manage your records")
                }

                Section {
                    topic("Earnings chart and USD/TRY", icon: "chart.bar.xaxis",
                          detail: "History starts on this calendar month. Choose W for a calendar week, M for a month starting on the 1st, 6M for six months with monthly bars, or All. Swipe right over the chart or tap the back arrow for an earlier period; swipe left or tap forward to return, up to the current period. Vertical swipes scroll History. Totals and sessions follow the page. Changing range keeps your place in time. Your range is remembered, but reopening the app starts on its current period. Tap a day, or a month in 6M, for hours and money. Empty periods say there is no work. USD accounts can switch all History money values to TRY using each session's start calendar day rate or the nearest earlier available rate. The choice is remembered across launches. A small secondary line keeps the other currency visible where available. Missing rates keep affected values in USD and show Some rates are unavailable once. Totals with missing rates stay in USD so currencies are never added together. TRY charts omit days without rates, or months containing those days. With no rates, the chart shows USD. This changes only History's display, not stored entries or the app currency. Today shows the latest USD/TRY rate and its status. Overnight sessions count toward the date they started.")
                    topic("This month performance", icon: "chart.xyaxis.line",
                          detail: "On M, the month summary shows hours, earnings, worked days and average hours and earnings per worked day. Earnings, earnings per worked day and projected earnings follow History's USD/TRY selection using historical daily rates. The hours chart combines daily bars with a cumulative solid line. A monthly goal adds a dashed line from zero on the 1st to the goal on the last day, plus percent and remaining hours. For the current month, projected earnings use completed earnings from the last 7 days, converted at their historical daily rates, averaged over 7 days for each day after today. The hours projection uses Insights' average completed work over the same window. The comparison uses the same number of days in the previous month, stopping at its last day if that month is shorter. Past months show final numbers without a projection, using your current goal for comparison.")
                    topic("Money Momentum", icon: "flame.fill",
                          detail: "Today shows your effective hourly rate divided by 3,600, plus TRY per second for USD accounts when a rate is available. While a session is open, the strip tracks its next multiple-of-ten earnings target. At an exact multiple, the target moves to the next ten. When paused or idle, Your earning power shows the potential rate; paused time does not earn more money.")
                    topic("Insights", icon: "target",
                          detail: "Insights shows your goals, the work heatmap by day, week or month, your rhythm and reports. Use Edit goals to set daily and monthly hours, including values like 7.5; zero turns a goal off. Once a goal is set, Today shows its progress too. After your first completed session, if no goals are set, Today offers Set goals, which opens Edit goals and focuses Daily. Not now hides that reminder for 7 days. Once you set any goal, the reminder stays hidden even if you later turn goals off. While you work, the goals card says when you reach today's goal; otherwise it says when you would reach it if you started now. Goals are for tracking only and do not change your level or badges.")
                    topic("Level and badges", icon: "rosette",
                          detail: "Open Badges, or tap your level or the companion card on Today, to see your level, XP, streaks and all badges. Expand How XP works for the breakdown. Tap a badge for its requirement and current progress. Current-streak badges lock again when a streak ends.")
                } header: {
                    Text("Understand your progress")
                }

                Section {
                    topic("Backups and restoring", icon: "externaldrive.fill",
                          detail: "In Settings, Data > Export backup shares a portable JSON copy. Automatic backups lists saved copies with their dates and entry counts; open one to restore it. Clockin saves an automatic copy once a day while you use it. Restore from file lets you choose a JSON backup. Restoring replaces the current entries and running timer, but saves your current data first. Use Automatic backups to return to that saved copy.")
                    topic("Haptics", icon: "hand.tap",
                          detail: "Settings > Appearance > Haptics controls gentle feedback for taps, selections, and completed actions. Turn it off to silence Clockin feedback. Scrolling and the running timer stay silent.")
                    topic("Focus chime", icon: "bell.badge",
                          detail: "In Settings > Focus chime, turn on Focus chime to request notification permission. Choose 1-120 minutes of worked time and one of eight original sounds: Soft Bell, Glass, Marimba, Chime, Pop, Wood Block, Singing Bowl or Tiny Ping. Chime is the default. Preview plays immediately without notification permission; choosing a sound also previews it. Volume ranges from 10-100%, starts at 75%, and applies while Clockin is open. Background notifications use the system volume and follow silent mode, Focus and iOS delivery timing. Pauses do not count. New sessions and interval or enable changes skip past chimes and use the next worked-time boundary. Up to 20 chimes are queued, refreshed while Clockin is open and when you return. Pausing, clocking out or cancelling clears pending chimes, including from widgets, Live Activities or Shortcuts. Foreground chimes keep a banner and mix with other audio. With Focus radio stopped, they respect the silent switch. If Focus radio is playing, chimes remain audible in silent mode.")
                    topic("Long session reminder", icon: "clock.badge.exclamationmark",
                          detail: "In Settings, choose Off, 8 h, 10 h (default), or 12 h for Long session reminder and allow notifications. Breaks do not count. Still working? lets you Clock out in the background, Set end time in the app, or Remind in 1 hour for this session. The end time must be between when you last resumed and now. Pausing, ending or cancelling the session, or choosing Off clears the reminder. An already reached threshold prompts once per session, including after reopening Clockin; only Remind in 1 hour requests another alert. Tapping the notification body opens Clockin.")
                    topic("Companion nudges", icon: "bubble.left.and.bubble.right",
                          detail: "In Settings > Companion nudges, choose playful Grumpy or supportive Friendly reminders. Turn Nudges on or tap Allow notifications to grant permission. Your companion checks in after 45 minutes and 2 hours of a paused session, an hour after leaving below your daily goal, at 21:00 for an unfinished goal, and at 20:30 for a streak at risk. Expected work days and the usual start time come from the previous 28 days, with weekday mornings as the starting default. No-work reminders cover the next week; after at least three quiet days, return reminders target days 3 and 7. At most two nudges arrive per calendar day, normally at least two hours apart; the second pause reminder is the exception to spacing. Nothing is scheduled between 22:00 and 08:00. Notifications stay silent while Clockin is open; the companion shows its mood instead. Tap the companion on Today to make it react with a hop, wiggle, or playful pose. Tapping a nudge opens Today. Resume or finish work to update the plan, or turn Nudges off anytime.")
                    topic("Focus radio", icon: "radio",
                          detail: "In Settings > Focus radio, choose Radio Paradise (Main Mix), Mellow Mix, Global Mix or Serenity (ambient), then tap Play. Clockin remembers your station; changing it while playing switches immediately. Today shows a compact radio card below the timer and companion with a station menu, play/pause and Stop. Pause keeps the card and Lock Screen controls so you can resume. Stop removes the card and clears Now Playing and remote controls. Volume from 0-100% stays in Settings. Connecting and error messages report loading or connection failure; tap Play to retry. Errors clear system controls but keep the Today retry card. Audio interruptions and unplugging headphones stop playback; press Play in Settings to restart. Streaming uses internet data and continues with the screen locked.")
                    topic("Desk mode", icon: "iphone.landscape",
                          detail: "Turn the phone sideways for a large timer with live earnings, today's total, your daily goal and the session controls. While a session runs, the screen stays on. Turn it off in Settings if you want Clockin to stay upright.")
                    topic("Widgets and Live Activity", icon: "apps.iphone",
                          detail: "Add Clockin's Today widget to your Home Screen or Lock Screen to see time and earnings. The medium Home Screen widget shows your companion alongside the timer and earnings, with Clock in, Pause or Resume, and Clock out controls. During a session, Live Activity shows the timer on the Lock Screen and on supported devices in Dynamic Island, when Live Activities are allowed. Its Lock Screen and expanded island controls let you pause, resume, or clock out.")
                    if #available(iOS 18.0, *) {
                        topic("Control Center, Lock Screen, and Action Button", icon: "timer",
                              detail: "In Control Center, touch and hold to edit, tap Add a Control, and search for Clockin. Add Clock In / Clock Out or Pause / Resume. To add a Lock Screen control, touch and hold the Lock Screen, tap Customize > Lock Screen, remove a bottom control, and tap plus to choose Clockin. On supported iPhones, open Settings > Action Button, choose Controls, and select a Clockin control. Clockin stays on while working or paused; turning it off saves the session. Pause / Resume does nothing when no session is running.")
                    }
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
