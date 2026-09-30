# 14: "Show details in the menu bar" switch on the Mac

Implement your recommendation from `13-live-activity-on-mac-result.md`: a
device-local master switch that makes Clockin for Mac's status item icon-only
without touching Minimal mode, pinning, the per-field choices or the iPhone.
The user has both apps, Minimal mode on and hours + earnings shown, so the
Mac shows the time next to the iPhone's mirrored Live Activity.

## Scope

- `ClockinMac/MacSettingsSection.swift`, `ClockinMac/MenuBarHost.swift`,
  `Shared/Localizable.xcstrings` (English keys, Turkish translations in the
  catalog; the app says "puantaj" for timecard and "menü çubuğu" for menu bar).
- Key `Clockin.MacShowMenuBarDetails`, default true, standard defaults, NOT in
  `SyncPreferences` (it must stay on this Mac).
- Label "Show details in the menu bar"; help text says turning it off shows
  only the Clockin icon and that an iPhone's Live Activity can also appear in
  the menu bar (System Settings > Notifications > Allow Live Activities from
  iPhone). Keep it short.
- When off: the status item keeps its running/paused/idle icon and
  accessibility value, no title text; the field toggles stay but are disabled
  and keep their values.

## Deliver

`docs/codex/14-menubar-details-switch-result.md`. For the catalog, add keys
with `json.dumps(indent=2, ensure_ascii=False, separators=(',', ': '))` and
sorted keys, like the existing file, so the diff stays small.
