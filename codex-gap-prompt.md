# Task: what does the Mac app have that the iPhone app does not?

Two checkouts on this machine:

- Mac app (the original): `/Users/erdemincedere/Desktop/Clockin/clockin-main`,
  sources under `Sources/Clockin`.
- iPhone app (the port): `/Users/erdemincedere/Desktop/Clockin/clockin-ios`,
  sources under `Clockin/`, `Shared/` and `ClockinWidgets/`.

The iPhone app was ported from the Mac app feature by feature. The owner wants
to know what is still missing, so the port can be finished.

**Read only. Do not modify any file in either checkout.** Another agent will
implement whatever the owner picks.

## What to produce

Go through the Mac app's user-facing surface systematically: every screen,
every menu, every keyboard shortcut, every setting, every preference key, every
import/export path, every notification or sound, every window or panel. For
each capability, say whether the iPhone app has it, and if not, why it might be
missing.

Sort the result into four groups, and be explicit about which group each item
belongs in:

1. **Missing and worth porting.** A real capability the iPhone lacks and that
   makes sense on a phone.
2. **Missing on purpose.** Mac-only by nature (the pinned floating window, menu
   bar items, multi-window, hover behaviour, keyboard-only affordances). Say
   what the iPhone equivalent would be, if any.
3. **Present but different.** Both have it, but the iPhone version is narrower
   or behaves differently. Describe the difference precisely.
4. **iPhone only.** Things the port added that the Mac does not have (Live
   Activity, widgets, Shortcuts, the mascot). Listed so the owner sees the
   whole picture, not to be ported back.

For every item in group 1, give: the Mac source file and line range that
implements it, roughly what porting it would involve on iOS, and a size
estimate of small, medium or large. Rank group 1 by value to a phone user,
most valuable first, and say briefly why you ranked the top three that way.

Be concrete and exhaustive rather than impressionistic. Check the Mac app's
Settings and any preferences it persists (`@AppStorage`, UserDefaults keys)
against the iPhone's `SettingsView.swift`, key by key: a key that exists in the
Mac app and has no iPhone UI is exactly the kind of thing that gets lost in a
port. `Clockin/Views/Mascot/MascotAsset.swift` reads a key named
`Clockin.MascotDefault` with values Auto, Typing, Coffee, Victory, Stretch,
Dance and Music, and nothing in the iPhone Settings sets it; check for others
like it in both directions.

Also note anything in the Mac app that looks like a bug or dead code while you
are reading, in a short separate section at the end. Do not fix it.

## House style

Never use an em dash. Use a comma, a colon, a full stop or parentheses.

## Deliverable

Write the report to the output file. Lead with a short table of contents and
the count of items in each group, so the owner can see the shape of it before
reading the detail.
