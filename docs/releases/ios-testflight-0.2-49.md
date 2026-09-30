# iOS 0.2 (49): Poll iCloud while open

Repository: `erdmncdr/clockin-ios`.
Source: main at `1e6c16c`. Everything from 0.2 (48).

- While a scene is active the app asks iCloud for changes every 60 seconds
  (`SyncCoordinator.setPolling`), in addition to push. Same change as Mac 2.0.4
  (`docs/releases/mac-2.0.4-15.md`).
- Internal group only; uploaded 2026-09-30.

## What to Test

### English

While Clockin is open it asks iCloud for changes every minute, so changes from your Mac arrive within a minute even if iCloud's instant notification goes missing.

### Turkish

Clockin açıkken iCloud'a dakikada bir değişiklik soruyor; iCloud'un anlık bildirimi gelmese bile Mac'teki değişiklikler en geç bir dakikada gelir.
