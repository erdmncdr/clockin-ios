# 21: Double-check before Mac 2.0.7 / iOS 0.2 (52)

Fresh reviewer pass over `git diff ddb33c2..0f4b7ee` (source; docs are
context). It contains: the Mac "two timers" tip and settings button (19), the
Mac sheet frame for sheets opened from Settings, and the iPhone-follows-Mac
work (20): Live Activity replacement decision, silent-push fetch results,
remote clock-in notification, shared `ClockStore` events, the new setting.

Look hardest for:
- Live Activities: can a card now be duplicated (old + new both alive), never
  replaced after returning to the foreground, or left running after clock-out
  (including when the app is launched in the background by the push and
  suspended mid-operation)? Interaction with `LiveActivityIntent` starts, the
  relay registration/deletion, and `finishPendingUpdates`.
- Notification: wrong-device notifications (the iPhone's own clock-in arriving
  back through sync, a restore from backup, first merge applying an old running
  session, a timer edited on the Mac), duplicates across relaunch, growth of the
  handled-starts store, behaviour with the setting off and permission denied.
- Fetch result mapping: any path that returns `.newData` forever or never
  calls the completion, or blocks the delegate for long.
- Mac: the tip detector after this change (events now on iOS too), and the
  Settings sheets with `macSheetFrame` (Form inside NavigationStack inside a
  sized sheet; nested sheets such as the rate editor).

Same rules as 16: no source edits; probes under `/tmp`; run the README suites
that do not need xcodebuild. Write `docs/codex/21-double-check-result.md`
(most severe first, file:line, scenario, fix) or say plainly that nothing
should block the release.
