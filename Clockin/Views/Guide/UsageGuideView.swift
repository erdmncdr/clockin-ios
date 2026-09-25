import SwiftUI

struct UsageGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            List {
                Section {
                    topic(String(localized: "Clock in, pause, and clock out", bundle: .app), icon: "play.fill",
                          detail: String(localized: "Tap Clock in on Today to start. Pause stops adding time and keeps the session open; Resume continues it. Clock out saves the session and shows its summary. Cancel session discards the active session after confirmation.", bundle: .app))
                    topic(String(localized: "Start with elapsed time", bundle: .app), icon: "clock.arrow.circlepath",
                          detail: String(localized: "If you forgot to start, tap Start with elapsed time on Today while no session is running. Enter hours and minutes, add an optional note, check the preview, then tap Start. The timer continues from that duration.", bundle: .app))
                    topic(String(localized: "Add and edit past entries", bundle: .app), icon: "pencil",
                          detail: String(localized: "Tap the plus button on Today or History to add completed work. Choose the day, start and end times, and a note. An end time earlier than the start means the next day. Tap a session in Today or History to edit it, then Save. To remove one, tap Delete entry at the bottom of the editor, or swipe left on it in History.", bundle: .app))
                    topic(String(localized: "Overlap warnings", bundle: .app), icon: "exclamationmark.triangle",
                          detail: String(localized: "The entry editor warns when your times overlap another saved entry. History also flags overlaps. Back-to-back entries are allowed, including a seconds-only handoff where one entry ends and the next starts in the same displayed minute. Duplicate or contained entries are still flagged. You can still save, but both entries count toward your totals. Review their times if your totals look too high.", bundle: .app))
                } header: {
                    Text("Track your time")
                }

                Section {
                    topic(String(localized: "Import a CSV or pasted timecards", bundle: .app), icon: "doc.text.magnifyingglass",
                          detail: String(localized: "Tap the gear on Today to open Settings, then Data > Import timecards. Choose CSV file, or paste a task block or timecards page and tap Review. CSV needs Start Time and End Time columns with ISO 8601 dates. Pasted text needs English dates, a status, source, and 24-hour times; include the date range and years when available. Check recognized dates, duration, and any Approved total warning before importing. Review New, Matched corrections, and Duplicate skipped entries. Matched entries are corrected; duplicates do not add another copy. Every new entry and correction starts selected: tap a row, or None and All in a section, to leave it out. Only selected rows are imported.", bundle: .app))
                    topic(String(localized: "Review your own entries", bundle: .app), icon: "checklist",
                          detail: String(localized: "In the import review, Your own entries lists Clockin entries not covered by the incoming rows. Days in file checks only dates with imported rows; Whole range checks every day from the first to the last imported date. Review these entries and choose what to keep or delete before importing. Deletions require confirmation. Import older history first and check totals before adding newer exports.", bundle: .app))
                    topic(String(localized: "Rate schedules", bundle: .app), icon: "calendar.badge.plus",
                          detail: String(localized: "In Settings > Pay, turn on Earlier work had a different rate and enter the change date and earlier rate. When you change the hourly rate, choose Today, Pick a date, or Always after reviewing the earnings impact. Work uses the rate for the day it started, including running sessions. Use Rate schedule for more complex periods.", bundle: .app))
                } header: {
                    Text("Manage your records")
                }

                Section {
                    topic(String(localized: "Earnings chart and USD/TRY", bundle: .app), icon: "chart.bar.xaxis",
                          detail: String(localized: "History starts on this calendar month. Choose Week for days 1–7, 8–14, 15–21, 22–28 or the remaining days of each month, Month for a month starting on the 1st, 6 months for six months with monthly bars, or All. Swipe right over the chart or tap the back arrow for an earlier period; swipe left or tap forward to return, up to the current period. Vertical swipes scroll History. Totals and sessions follow the page. Changing range keeps your place in time. Your range is remembered, but reopening the app starts on its current period. Tap a day, or a month in 6 months, for hours and money. Empty periods say there is no work. USD accounts can switch all History money values to TRY using each session's start calendar day rate or the nearest earlier available rate. The choice is remembered across launches. A small secondary line keeps the other currency visible where available. Missing rates keep affected values in USD and show Some rates are unavailable once. Totals with missing rates stay in USD so currencies are never added together. TRY charts omit days without rates, or months containing those days. With no rates, the chart shows USD. This changes only History's display, not stored entries or the app currency. Today shows the latest USD/TRY rate and its status. Overnight sessions count toward the date they started.", bundle: .app))
                    topic(String(localized: "This month performance", bundle: .app), icon: "chart.xyaxis.line",
                          detail: String(localized: "In Month, the month summary shows hours, earnings, worked days and average hours and earnings per worked day. Earnings, earnings per worked day and projected earnings follow History's USD/TRY selection using historical daily rates. The hours chart combines daily bars with a cumulative solid line. For the current month, projected earnings use completed earnings from the last 7 days, converted at their historical daily rates, averaged over 7 days for each day after today. Monthly targets and hour forecasts live in Progress > Goals. The comparison uses the same number of days in the previous month, stopping at its last day if that month is shorter. Past months show final numbers.", bundle: .app))
                    topic(String(localized: "Money Momentum", bundle: .app), icon: "flame.fill",
                          detail: String(localized: "Today shows your effective hourly rate divided by 3,600, plus TRY per second for USD accounts when a rate is available. While a session is open, the strip tracks its next multiple-of-ten earnings target. At an exact multiple, the target moves to the next ten. When paused or idle, Your earning power shows the potential rate; paused time does not earn more money.", bundle: .app))
                    topic(String(localized: "Goals & Pace", bundle: .app), icon: "chart.line.uptrend.xyaxis",
                          detail: String(localized: "Open Progress > Goals to plan your month. Goals & Pace opens directly; no extra card to tap. Set monthly and daily hours, then choose how many days you work each week. Remaining workdays are approximate: remaining calendar days including today, multiplied by workdays per week and rounded up. Today's hours are credited when calculating the full-day target. Apply the quarter-hour suggestion to change your daily goal. The outlook uses up to seven finished calendar days, including days without work; today's partial day counts toward progress but not the average. Solid and dashed lines show actual and projected totals, with a dotted monthly target. The daily chart compares work against your saved daily goal. Estimates use session start dates, match your current plan and stay on-device.", bundle: .app))
                    topic(String(localized: "Progress", bundle: .app), icon: "chart.line.uptrend.xyaxis",
                          detail: String(localized: "Progress brings Goals, Reports and Badges into one tab. Use the selector at the top to switch sections. Goals is the single place to edit daily and monthly hours, choose workdays and see your pace. Reports contains the work heatmap, rhythm, totals and records; use its share button to share your stats. Today shows your daily goal, monthly progress and suggested hours for today based on your remaining workdays. Customize Today can show or hide this Goals & daily pace card; Adjust goals & pace opens the full plan. Set goals opens Your plan and focuses Daily. Not now hides that reminder for 7 days; once you set any goal it stays hidden. Zero turns a goal off. Goals do not change XP or badges.", bundle: .app))
                    topic(String(localized: "Companion: outfits, coins and home", bundle: .app), icon: "face.smiling",
                          detail: String(localized: "Tap the companion on Today, or open Progress > Badges > Companion, to dress it and decorate its home. The text row on Today's card opens Progress > Badges. Outfit has one item per slot and a body colorway; None removes an item. Headphones unlock at 25h, Mug at 50h, Cape at 100h and Gold antenna at 250h. Earned items stay yours. Shop purchases ask for confirmation and equip immediately. Focus coins come from completed work: 10 per hour after rounding each session down to minutes, 25 per day meeting your current daily goal, 50 per archive badge and 100 per reached level including level 1. Archive edits and goal changes recalculate the balance, which never goes below zero. Choose home items, then tap Edit room to drag them into place. Arrows fine-tune; Save keeps your layout, Cancel discards changes, and Reset room restores the preset. Each room remembers its layout. Cozy is free; Studio and Night cost coins. Settings > Show home in desk mode controls the dimmed landscape background. Your outfit follows drawn poses, moods, celebrations and the widget. A hand item hides while its hand is occupied or absent. Missing artwork stays hidden. The companion rests when offscreen, in the background, or when motion and power settings require it. Exported and automatic backups include your wardrobe, purchases and home; older backups leave your wardrobe unchanged.", bundle: .app))
                    topic(String(localized: "Companion celebrations", bundle: .app), icon: "sparkles",
                          detail: String(localized: "Your companion celebrates new levels across every tab and in desk mode. Tap to dismiss, or use Share to open your stats card. Celebrations wait while a sheet or alert is open. New badge banners open Progress > Badges when tapped; several unlocks show up to three badges and a remaining count. Existing progress is marked seen when this feature first starts. During active use, playful reactions to money targets, streak milestones and session actions are limited to once every 20 seconds. Pride for achievements has its own four-second window. Goal and money reactions are checked on the next minute refresh. Reduce Motion keeps a still companion; turning Focus companion off leaves celebration text only.", bundle: .app))
                    topic(String(localized: "Level and badges", bundle: .app), icon: "rosette",
                          detail: String(localized: "Open Progress > Badges, or tap your level on Today, to see your level, XP, streaks and all badges. Expand How XP works for the breakdown. Choose a mission tier: Launch, Orbit, Lunar, Solar, Galactic or Eternal. Tap a mission for its goal, progress and reward preview. Eternal holds the four hardest achievements. Collection missions count different purchases, including earlier ones, but exclude free gifts and grant no coins or XP. Current-streak badges lock again when a streak ends.", bundle: .app))
                } header: {
                    Text("Understand your progress")
                }

                Section {
                    topic(String(localized: "Backups and restoring", bundle: .app), icon: "externaldrive.fill",
                          detail: String(localized: "In Settings, Data > Export backup shares a portable JSON copy. Automatic backups lists saved copies with their dates and entry counts; open one to restore it. Clockin saves an automatic copy once a day while you use it. Restore from file lets you choose a JSON backup. Restoring replaces the current entries and running timer, but saves your current data first. Use Automatic backups to return to that saved copy.", bundle: .app))
                    topic(String(localized: "Haptics", bundle: .app), icon: "hand.tap",
                          detail: String(localized: "Settings > Appearance > Haptics controls gentle feedback for taps, selections, and completed actions. Turn it off to silence Clockin feedback. Scrolling and the running timer stay silent.", bundle: .app))
                    topic(String(localized: "Focus chime", bundle: .app), icon: "bell.badge",
                          detail: String(localized: "In Settings > Focus chime, turn on Focus chime to request notification permission. Choose 1-120 minutes of worked time and one of eight original sounds: Soft Bell, Glass, Marimba, Chime, Pop, Wood Block, Singing Bowl or Tiny Ping. Chime is the default. Preview plays immediately without notification permission; choosing a sound also previews it. Volume ranges from 10-100%, starts at 75%, and applies while Clockin is open. Background notifications use the system volume and follow silent mode, Focus and iOS delivery timing. Pauses do not count. New sessions and interval or enable changes skip past chimes and use the next worked-time boundary. Up to 45 chimes are queued, refreshed while Clockin is open and when you return. Pausing, clocking out or cancelling clears pending chimes, including from widgets, Live Activities or Shortcuts. While Clockin is open, chimes play without a notification and mix with other audio. Chimes that arrive while it is closed collapse into one group, cleared when you open Clockin. With Focus radio stopped, they respect the silent switch. If Focus radio is playing, chimes remain audible in silent mode.", bundle: .app))
                    topic(String(localized: "Long session reminder", bundle: .app), icon: "clock.badge.exclamationmark",
                          detail: String(localized: "In Settings, choose Off, 8 h, 10 h (default), or 12 h for Long session reminder and allow notifications. Breaks do not count. Still working? lets you Clock out in the background, Set end time in the app, or Remind in 1 hour for this session. The end time must be between when you last resumed and now. Pausing, ending or cancelling the session, or choosing Off clears the reminder. An already reached threshold prompts once per session, including after reopening Clockin; only Remind in 1 hour requests another alert. Tapping the notification body opens Clockin.", bundle: .app))
                    topic(String(localized: "Companion nudges", bundle: .app), icon: "bubble.left.and.bubble.right",
                          detail: String(localized: "In Settings > Companion nudges, choose playful Grumpy or supportive Friendly reminders. Turn Nudges on or tap Allow notifications to grant permission. Your companion checks in after 45 minutes and 2 hours of a paused session, an hour after leaving below your daily goal, at 21:00 for an unfinished goal, and at 20:30 for a streak at risk. Expected work days and the usual start time come from the previous 28 days, with weekday mornings as the starting default. No-work reminders cover the next week; after at least three quiet days, return reminders target days 3 and 7. At most two nudges arrive per calendar day, normally at least two hours apart; the second pause reminder is the exception to spacing. Nothing is scheduled between 22:00 and 08:00. Notifications stay silent while Clockin is open; the companion shows its mood instead. Open Companion from Today; equipping an item brings a small reaction. Tapping a nudge opens Today. Resume or finish work to update the plan, or turn Nudges off anytime.", bundle: .app))
                    topic(String(localized: "Focus radio", bundle: .app), icon: "radio",
                          detail: String(localized: "In Settings > Focus radio, choose Radio Paradise (Main Mix), Mellow Mix, Global Mix or Serenity (ambient), then tap Play. Clockin remembers your station; changing it while playing switches immediately. Today shows a compact radio card below the timer and companion with a station menu, play/pause and Stop. Pause keeps the card and Lock Screen controls so you can resume. Stop removes the card and clears Now Playing and remote controls. Volume from 0-100% stays in Settings. Connecting and error messages report loading or connection failure; tap Play to retry. Errors clear system controls but keep the Today retry card. Audio interruptions and unplugging headphones stop playback; press Play in Settings to restart. Streaming uses internet data and continues with the screen locked.", bundle: .app))
                    topic(String(localized: "Desk mode", bundle: .app), icon: "iphone.landscape",
                          detail: String(localized: "Turn the phone sideways for a large timer with live earnings, today's total, your daily goal and the session controls. While a session runs, the screen stays on. Turn it off in Settings if you want Clockin to stay upright.", bundle: .app))
                    topic(String(localized: "Widgets and Live Activity", bundle: .app), icon: "apps.iphone",
                          detail: String(localized: "Add Clockin's Today widget to your Home Screen or Lock Screen to see time and earnings. The medium Home Screen widget shows your companion alongside the timer and earnings, with Clock in, Pause or Resume, and Clock out controls. During a session, Live Activity shows the timer on the Lock Screen and on supported devices in Dynamic Island, when Live Activities are allowed. Its Lock Screen and expanded island controls let you pause, resume, or clock out.", bundle: .app))
                    if #available(iOS 18.0, *) {
                        topic(String(localized: "Control Center, Lock Screen, and Action Button", bundle: .app), icon: "timer",
                              detail: String(localized: "In Control Center, touch and hold to edit, tap Add a Control, and search for Clockin. Add Clock In / Clock Out or Pause / Resume. To add a Lock Screen control, touch and hold the Lock Screen, tap Customize > Lock Screen, remove a bottom control, and tap plus to choose Clockin. On supported iPhones, open Settings > Action Button, choose Controls, and select a Clockin control. Clockin stays on while working or paused; turning it off saves the session. Pause / Resume does nothing when no session is running.", bundle: .app))
                    }
                    topic(String(localized: "Shortcuts and Siri", bundle: .app), icon: "square.stack.3d.up",
                          detail: String(localized: "In Shortcuts, use Clockin's Clock In, Clock Out, and Pause or Resume actions. You can also ask Siri to clock in with Clockin, clock out with Clockin, or pause Clockin. Pause or Resume toggles the current session's state, and Clock In also resumes a paused session.", bundle: .app))
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
