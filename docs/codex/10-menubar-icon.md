# 10: A larger, distinctive menu bar icon

The user: the mascot head in the menu bar looks small because the antenna
takes vertical space. Remove the antenna and make the head bigger, the same
visual size as the neighbouring system icons (AirPods, Wi-Fi, battery), while
still reading as Clockin and not as a generic robot or stopwatch.

## Scope

- `ClockinMac/MenuBarIcon.swift` only (the three states idle / running /
  paused stay; `image(_:pointSize:)` API stays; template image, drawn in code).
- A throwaway render script you write under `/tmp` (not committed) that draws
  the new icon with this file's code and writes
  `docs/codex/10-menubar-preview.png`: each state at 18 pt, @2x, on a light
  and a dark menu bar strip, next to SF Symbols `airpods`, `wifi` and
  `battery.75percent` rendered as template images at the menu bar's size, so
  the visual weight can be compared. Include your recommended design and one
  alternative in the sheet, clearly labelled.

## Direction

- Height should match SF Symbols in the menu bar (about 14-16 pt of ink on
  the 18 pt canvas); the icon may be wider than tall if that helps (status
  items can be wider); keep it within about 20 x 18 pt and tell me the final
  size so the status item can use it.
- Keep the mascot's helmet + visor idea (running: solid head with the visor
  cut out and happy eyes; idle: outline, closed/sleeping eyes; paused: outline
  with pause bars). Ears are optional; drop anything that shrinks the head.
- Stroke weight like SF Symbols regular in the menu bar; must stay crisp at
  1x and 2x.

## Deliver

`docs/codex/10-menubar-icon-result.md`: what you changed, final dimensions,
why you recommend it over the alternative, anything you disagree with in this
brief. `swiftc -typecheck` the file against the macOS SDK.
