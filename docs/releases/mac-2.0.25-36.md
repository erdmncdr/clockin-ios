# Mac 2.0.25 (36): the level-up card as the shared picture

Source: `erdmncdr/clockin-ios` main at `39f6e18`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.25.md`. Design: `docs/level-up-design.md`, "Sharing it".

- `CelebrationOverlay.share` passes a `LevelShareSnapshot` (level, hours, xp, streak, date,
  companion) taken at the press; both roots open `ShareLevelView` instead of `ShareStatsView`.
  Insights still shares the stats rewind.
- `LevelShareCard`: `LevelUpStage` at `LevelUpCurve.still`, banner, rank panel, streak ≥ 2, date,
  CLOCKIN mark on `LevelUpBackdrop`. Story 360 × 640 and post 360 × 450 pt at 3x. The block is
  centred, so a story without the companion does not leave the bottom half empty.
- Sheet: picture up to 440 pt, format picker, hours switch, Share image (ShareLink), Copy image.
  Mac sheet 520 × 760. Turkish added for the seven new strings.
- iOS side changed too (RootView, UIKit PNG path); it goes out with the next TestFlight build.

Verification: share checks 32/32; Mac Debug and Release builds; iOS Debug build (generic device,
no signing); `--level-share-render`: 9 pictures at 1080 × 1920 / 1080 × 1350, reviewed by eye for
levels 12, 75 and 450; `--level-share-sheet` captured on the Mac (Turkish). publish.sh --yes; live
appcast 2.0.25 (36); website zip = release zip (18463618 bytes).
Not verified: the sheet on an iPhone (simulator unavailable on this Mac) and a real level-up.
