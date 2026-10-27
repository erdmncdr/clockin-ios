# Mac 2.0.26 (37): timer log, link confirmation, shortcut switch

Source: `erdmncdr/clockin-ios` main at `5428b1b`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.26.md`. Brief and result: `docs/codex/33-timer-start-log*.md`.

Background: the owner saw the timer start "on its own" on the iPhone. Nothing starts
without an input, but none of the inputs left a trace, and `clockin://` URLs were
accepted from any app.

- `TimerStartLog` (device-local, 100 entries, `Clockin.TimerStartLog.v1`): every clock-in,
  resume and clock-out with its origin (app, widget/Siri, Control Center, sync from another
  device with provenance, Mac shortcut, link, Pulse). Settings > General on the Mac,
  Settings > Data > Timer log on the iPhone.
- `ExternalClockCommandReceiver`: acts at once only when the Apple Event sender is Clockin's
  own executable (the native host) or the URL carries the one-time `ExternalClockPass` the
  host wrote to the data folder; otherwise an NSAlert names the sender and asks.
- `KeyboardShortcutController`: `Clockin.GlobalShortcutsEnabled` switch; ⌥⌘I conflict note.
- iPhone: `Clockin.ExternalStartsEnabled` switch refuses starts and resumes from intents.
- Also in this build from `d3e8387`: the level-up share sheet's iPhone side (Save to Photos).

Verification: Codex 33 suites (timer log, sync 276, syncapp 105, iphonefollowsmac,
crashaudit typecheck of four targets); Mac and iOS simulator Debug builds; the timer log
check re-run after the pass handshake; build.sh / notarize.sh / package.sh; publish.sh --yes;
live appcast 2.0.26 (37); website zip = release zip (18520523 bytes).
Not verified in a running app: the Pulse path through the real native host (sender
attribution plus the pass), the link alert, Control Center refusal, the log views.
