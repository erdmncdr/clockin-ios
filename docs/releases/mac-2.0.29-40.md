# Mac 2.0.29 (40): one timer counts once

Source: `erdmncdr/clockin-ios` main at `9acb201`. Published to `erdmncdr/clockin-macos`
by the owner from the terminal (the assistant's publish call was refused by its
permission classifier). Notes: `docs/release-notes-mac-2.0.29.md`. Brief and result:
`docs/codex/35-same-timer-double-count*.md`.

Background: a tester with a Mac and an iPhone saw the same work counted twice after
clocking out on the Mac while the iPhone still showed the timer and ended it too.

- `SyncCore` (`Shared/Sync/Cloud/SyncMerge.swift`): Clockin-sourced sessions sharing
  the same running-timer start (`sessionFact.clockinStart`, or `start` for a local
  session not yet captured) are one group together with import-key aliases; a group
  with same-timer aliases keeps the earliest end (ties: lowest UUID). Applied in
  projection, first-merge counts, recovery capture (reason "Same timer") and deletion
  fan-out. `docs/sync-design.md` updated.
- Propagation analysis (no code change): foreground poll every 60 s plus push; a
  suspended or force-quit iPhone has no bounded delay until it is opened.
- Built with Xcode 27.2 (27B52), installed from the App Store on 2026-10-30.

Verification: sync 296, syncapp 118 (real stores: Mac ends the timer, the phone ends it
40 s later before fetching → one entry, one hour, phone entry in recovery), crashaudit
206, timer log; Mac and iOS Debug builds; build.sh 2.0.29 40; notarize.sh (Accepted,
stapled, Gatekeeper accepted); package.sh; publish.sh --yes by the owner; live appcast
2.0.29 (40); website zip = release zip (18549359 bytes), dmg 19525277 bytes.
Not verified on two real devices: the owner checks listed in the Codex 35 result.
