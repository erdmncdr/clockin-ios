# iOS 0.2 (58): one timer counts once

Repository: `erdmncdr/clockin-ios`. Source: main at `9acb201`. Everything from 0.2 (57),
plus the same-timer collapse shipped on the Mac as 2.0.29 (40),
`docs/releases/mac-2.0.29-40.md`. Brief and result: `docs/codex/35-same-timer-double-count*.md`.

- `SyncCore` (`Shared/Sync/Cloud/SyncMerge.swift`): Clockin-sourced sessions that share
  the same running-timer start are one group; the earliest end wins. A Mac clock-out
  followed by a later iPhone clock-out of the same timer is one entry; the later one
  lands in Settings > iCloud > Sync changes with the reason "Same timer".
- Built with Xcode 27.2 (27B52), installed from the App Store on 2026-10-30.

Archive `build/ios-release/Clockin-0.2-58.xcarchive`, team LU36PKDPT3. App Store Connect
refused the upload six times on 2026-10-30 between 17:10 and 20:21 (+03) with
"Unsupported SDK or Xcode version" because 27B52 was not yet on its accepted list; the
seventh attempt at 20:54 (+03) uploaded; processed by 21:05. Build id
`bd98f3ce-2259-4fd6-87e1-35639fc07a09`. What to Test in English and
Turkish; added to Clockin Internal and Clockin Public Beta; beta review submitted
(WAITING_FOR_REVIEW); internal and external state IN_BETA_TESTING.

Verification: sync 296, syncapp 118, crashaudit 206, timer log; iOS Debug build (see the
Mac 2.0.29 record for the full list). Not verified on two real devices: the owner checks
listed in the Codex 35 result.
