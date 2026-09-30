# 12 — Mac pinned focus chime card

## Changes

Only `Clockin/Views/CompactChimeCard.swift` changed. Its new layout is behind
`#if os(macOS)`; `DashboardShortcuts.swift` did not need changes.

- The title row contains the bell, the localized “Focus chime” title, and a
  trailing small switch. It reuses `FocusChimeToggle` with `.labelsHidden()`,
  `.toggleStyle(.switch)` and `.controlSize(.small)`, preserving its binding,
  accessibility identifier, haptic action and notification-permission request.
- The second row places the interval text, a small intrinsic-size stepper and
  sound name together. The stepper retains the 1–120 minute range, an accessible
  interval label/value and `chime.interval` identifier. Only the stepper is
  disabled when off; both descriptive texts keep their normal contrast.
- The existing options actions now sit in a 24-point borderless ellipsis menu
  with its indicator hidden. Sound/volume settings and unpinning stay available
  when the chime is off.
- The content expands to the offered width **before** padding and `.card(palette)`
  paint the background. Padding is 14 points, matching the pinned reminder card;
  the shared surface, outline and corner radius are unchanged.

The original used automatic Mac toggle/menu styles and had no expanding frame
or spacer. The default controls and intrinsic-width layout caused the reported
checkbox, floating arrows, pull-down chrome and narrow card. The parent Today
stack already offers sufficient width, so no parent adjustment was necessary.

The iPhone layout is retained verbatim in the non-Mac branch. The existing
interval normalization on appearance remains shared and unchanged.

## Other pinned cards — inspected, not changed

| Card shown by `DashboardPinnedTools` | Mac findings from source inspection |
| --- | --- |
| `FocusRadioCard` (`Clockin/Audio/FocusRadioCard.swift`) | Its pinned ellipsis menu has the same automatic-style problem: a 44-point image label with no borderless menu style, hidden indicator or constrained menu width. Its rows already contain expanding spacers, so it does not share the chime card’s intrinsic-width cause. No toggle or stepper is present. Its station picker is intentionally a menu. |
| `DashboardReminderCard` (`DashboardShortcuts.swift`) | No matching checkbox, stepper or ellipsis-menu issue. Its spacer expands the row. The native “Adjust” button retains an iPhone-sized 44-point minimum layout height, which could receive a separate Mac density review. |

## Verification

- Focused `swiftc -typecheck` checks passed with the installed macOS SDK targeting
  macOS 14 and iPhone Simulator SDK targeting iOS 17. They compile the actual
  changed card, actual sound/theme sources, and extracted unchanged
  `FocusChimeToggle`/`DashboardPinButton` declarations. Temporary stand-ins replace
  permission/haptic services, bundle lookup and the palette environment macro.
  These are view-level checks, not complete app builds.
- An offscreen `NSHostingView` harness rendered the original and updated cards
  with chime on/off at 360- and 688-point container widths. Inspected images
  reproduce the original narrow card, checkbox and pull-down menu, and show the
  updated card aligned with a neighbouring full-width card, a native switch,
  compact arrows and an ellipsis without a chevron. The off-state interval and
  sound remain readable. The harness uses isolated volatile preferences.
- A source comparison confirmed the iPhone view body is byte-for-byte unchanged
  and the appearance-time normalization is retained. `git diff --check` passed.
- Full build attempted:

  ```sh
  xcodebuild -project Clockin.xcodeproj -scheme ClockinMac \
    -configuration Debug -destination 'platform=macOS' \
    -derivedDataPath /tmp/clockin-12-mac-build CODE_SIGNING_ALLOWED=NO build
  ```

  It exited 74 before compilation: Sparkle could not be fetched because the
  sandbox could not resolve `github.com`. Log: `/tmp/clockin-12-mac-build.log`.

Temporary SDK-check sources, logs and before/after images are under
`/tmp/clockin-12-check/`. Live app interactions, notification permission prompts,
menu action invocation and an on-device iPhone visual check were not verified.
