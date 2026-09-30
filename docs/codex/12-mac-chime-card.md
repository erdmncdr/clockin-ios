# 12: The pinned focus chime card on the Mac

On the Mac, the focus chime card pinned to Today (`CompactChimeCard`, shown by
`Clockin/Views/DashboardShortcuts.swift`) looks small and broken: the on/off
switch renders as a bare checkbox next to "Odak çanı", the stepper arrows float
beside "Her 10 dk / Minik Ding", the options menu (`ellipsis`) renders as a
wide pull-down button with a chevron, and the whole card is narrower than the
cards around it.

## Scope

- `Clockin/Views/CompactChimeCard.swift` and, if the width comes from there,
  the Mac branch of `Clockin/Views/DashboardShortcuts.swift`. Look at
  `FocusChimeToggle` for how the switch is built. The iPhone must look exactly
  as it does now: put Mac changes behind `#if os(macOS)` or the existing
  platform helpers in `Clockin/Views/Components/PlatformModifiers.swift`.

## Direction

- Mac: title row = bell icon, "Focus chime", switch at the trailing edge
  (`.toggleStyle(.switch)`, `.controlSize(.small)` if it fits the row);
  second row = interval text + stepper + sound name; options as a borderless
  icon menu (`.menuStyle(.borderlessButton)`, hidden indicator, fixed size).
- Full width like the neighbouring Today cards, same padding and card style.
- Disabled state when the chime is off stays readable.

## Deliver

`docs/codex/12-mac-chime-card-result.md`: what changed and why; say if other
pinned shortcut cards in `DashboardShortcuts.swift` have the same Mac problems
(list them, do not fix them in this task).
