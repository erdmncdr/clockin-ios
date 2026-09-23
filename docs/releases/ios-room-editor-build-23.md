# iOS 0.2 (23): Room editor

Companion now has an Edit room button for arranging equipped decorations. Drag
items or use the directional controls. Four-point snapping, wall/floor bounds,
window clearance and overlap feedback help keep the room tidy. Rugs can sit
under furniture. Save commits; Cancel discards; Reset room and selected-item
reset modify only the draft. Normal room scenes do not accept placement gestures.

Layouts are saved per room and per item in the existing wardrobe JSON. Canonical
360×240 coordinates preserve placement across screen sizes and room direction.
Existing saves retain their exact default layout. Malformed placement entries
are ignored without discarding wardrobe ownership. Save merges only the edited
room into current state; backups retain all placements. The existing one-equipped
item per category model remains.

Bean bags and beds carry their companion pose with them. Floor/desk lamp glow,
coffee/monitor steam, furniture shadows and room previews use the same placements.
The parent animation pauses while the editor is open; image decoding is keyed to
room/equipped assets, not drag position.

## Verification

- 2,795 existing wardrobe checks and 895 new room editor checks passed against
  final frozen source, including legacy JSON, malformed entries, save/cancel
  isolation, backup restore, theme isolation, bounds, mirroring, collisions and
  actual bean-bag/bed asset attachment sizes.
- Shared production RoomEditorCanvas exercised through native macOS SwiftUI:
  drag, draft-only change, Cancel, Save, normal-mode gesture rejection, Reset,
  window/collision rejection, mirrored room and 300/358-point canvas widths.
  A 40-room-point movement stayed consistent across both widths. The harness is
  `iOS/Tests/manual/roomeditor/Review.swift`; it uses disposable in-memory state.
- This validates the shared gesture surface, not a full interactive iPhone run.
  The complete iOS UI compiled in a signed Release archive without warnings/errors.
- All 354 frozen source hashes verified. App and widget both 0.2 (23); strict deep
  signature verification passed with host keychain access. No GLB/USDZ experiments.

Reproduce the automated checks. The first script was removed once main became
the release baseline; it and the worktree it reads are only in history and on
the `archive/companion-art-polish` tag.

```sh
python3 scripts/prepare-ios-live-activity-release.py \
  --ui-source /Users/erdemincedere/Clockin/clockin-companion-art \
  --output /tmp/clockin-room-editor-new-check
python3 scripts/check-ios-room-editor.py /tmp/clockin-room-editor-new-check
```

## Release

Frozen source: `/tmp/clockin-room-editor-23-final/source`.
Archive: `/tmp/clockin-room-editor-23-final/Clockin.xcarchive`.
Upload succeeded on 2026-09-21 at 18:19 Europe/Istanbul.
Build ID: `72839a0e-7111-4bcc-9c0a-1bdf747b35a2`.
English and Turkish notes saved. Both existing groups selected with automatic
notifications enabled. Verified **Testing** in both Clockin Public Beta and
Clockin Internal on 2026-09-21.
