# 32: Review the level-up share sheet on the iPhone

Mac 2.0.25 made Share milestone on the level-up card share the card itself as
a picture (`Clockin/Views/Share/LevelShareCard.swift`, `ShareLevelView.swift`,
`LevelShareLayout.swift`, see `docs/level-up-design.md`, "Sharing it"). The
same views compile into the iPhone app, and the uncommitted diff in this
checkout (`git diff`) finishes the iPhone side:

- `ShareLevelView`: on UIKit, a Save to Photos button beside Copy image
  (add-only `PHPhotoLibrary` access, `PHAssetCreationRequest` with the PNG
  data), success/failure haptics through the existing `HapticSignal`, and the
  copy path moved into `copy(_:)` for both platforms.
- `Config/Clockin-Info.plist`: `NSPhotoLibraryAddUsageDescription`.
- `Clockin/ClockinAppDelegate.swift`: the `--level-share-render DIR` fixture
  also runs in the iPhone debug build.
- `Shared/Localizable.xcstrings`: four new strings with Turkish.

## What to do

Review only; do not edit files. Read the diff and the three share files and
report, in `docs/codex/32-level-share-ios-result.md`:

1. Correctness on iOS 17+: the Photos add-only flow (authorization states,
   `.limited`, the `performChanges` async overload), `ImageRenderer` of
   `LevelShareCard` on the iPhone (the stage `Canvas`, `.width(.expanded)`
   fonts, 3x scale giving 1080 × 1920 and 1080 × 1350), `ShareLink` with the
   `Transferable` PNG, and `UIPasteboard` with the PNG type.
2. Swift 6 strict concurrency: `save(_:)` is called from a `Task` inside a
   `@MainActor` view; check nothing crosses actors unsafely.
3. The sheet on an iPhone: a 390 pt wide sheet with the preview capped at
   440 pt, the format picker, the hours toggle, Share image, then the
   Save/Copy row at `.controlSize(.large)`. Point out anything that would
   look wrong, truncate in Turkish, or fight Dynamic Type.
4. Anything the Mac sheet loses from the change (it should behave as before).
5. Turkish wording of the four strings.

Rules: no new dependencies, no file edits, no Codex/Claude names in anything
that could land in a commit. Keep the result short: findings with file and
line, each with a suggested fix, then anything you confirmed is fine.
