# 29: Font is the user's choice, not the theme's

Today every theme forces a font design (`ClockinPalette.fontDesign` in
`Shared/Theme/Themes.swift`: Carbon rounded, Neon Orange / Data Dense / Terminal
Amber monospaced, Synthwave serif, ...). Changing the theme silently changes the
font. The user wants the font chosen separately and never imposed by a theme.

Decision:
- Themes change colors only.
- New setting "Font" / "Yazı tipi": System (default), Rounded, Serif, Monospaced.
  Everyone starts on System, including existing users (no migration to the old
  theme pairing; that is the point). Each option previews in its own design.
- Place it next to Theme: iPhone Settings > Appearance (keep the section order
  otherwise unchanged), Mac Settings > General.

Apply the chosen design everywhere the theme font is used today (24 files read
`palette.fontDesign`): app screens on iPhone and Mac, rolling numbers
(`RollingNumberFont`), desk mode, Mac menu bar panel and pinned timer, Home
Screen / Mac widgets (`ClockinSnapshot` carries what the extension needs), and the
Live Activity. Prefer one source of truth (for example the palette gets its font
from the setting) over threading a new parameter through every view.

Careful:
- Live Activity content state is also decoded from relay pushes. Any new field
  must be optional/defaulted so pushes and older payloads without it still decode;
  never make an existing push fail. Attributes are immutable; do not require a new
  activity just for this.
- Widget snapshot: older snapshots without the field must decode (default System).
- Sync: syncing the choice like `Clockin.Theme` would be nice. Do it only if
  clients already shipped (Mac 2.0.7/2.0.8, iPhone 0.2 (52)) safely ignore an
  unknown preference record (no quarantine noise, no rejection, no loop); verify
  in `Shared/Sync/Cloud/SyncPreferences.swift` and the merge code. If not
  provably safe, keep it device-local and say so.
- No layout-time state writes (see 28).

English + Turkish strings in `Shared/Localizable.xcstrings` (usual serialization).
Focused tests (palette/font resolution, snapshot and content-state decoding with
and without the field, sync allowlist decision), all README suites without
xcodebuild, `Tests/manual/macpolish/ios_paths.py` is expected to show the
intended iOS changes only, and the SDK typecheck. Write
`docs/codex/29-font-choice-result.md` with what to check visually on iPhone and Mac.
