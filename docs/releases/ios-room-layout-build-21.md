# iOS 0.2 (21): Companion room placement

The portrait's 60×80 frame extended above the usable wall; the 72×52 flag touched
its window frame. The scene only checked outer-canvas bounds, not wall/window
clearance. The desk also clipped the working sprite at its surface and redrew a
foreground desk over it, hiding the laptop and much of the body.

## Changes

- Portrait displays at 60% with a 10-point downward adjustment; the flag displays
  at 75%, moved 5 points left. The original bundled artwork is untouched. Both
  remain upright in either room layout.
- Desk variants are 65% wide. Their upper artwork retains its aspect ratio while
  legs use 22% vertical scale, creating a floor table. Its surface is lower and
  the working pose aligns its laptop edge with that surface.
- The full cached working sprite, hands, laptop and boots draw in front of the
  furniture. Removed the room's extra body clip, separate legs and foreground desk
  pass. The working pose mirrors with the room, keeping the laptop over the table.
- HomeSceneLayout supplies shared furniture bounds and working placement to the
  SwiftUI scene and offline compositor. Stored ownership, equipment and rooms are
  unchanged; existing users get the corrected layout immediately.

## Verification

- 2,645 wardrobe checks passed, including wall/ceiling/window clearance in all
  three rooms and both layouts, low-table floor bounds, existing ownership,
  artwork, outfit layering and cache behavior.
- Rendered three room themes, both layouts and all three desk variants while
  working, plus idle/rest/sleep scenes. Inspected normal and mirrored working
  scenes and idle furniture. Review files: [room-layout-21](art-review/room-layout-21).
- These are production-geometry render checks, not interactive device screenshots.
  The exact SwiftUI composition remains to be visually checked on an iPhone.

## Release

Source: `/tmp/clockin-room-21-final/source`.
Archive: `/tmp/clockin-room-21-final/Clockin.xcarchive`.
Signed Release archive passed without compiler warnings/errors. App and widget
are both 0.2 (21); strict deep codesign passed and all 349 source hashes matched.
Upload succeeded on 2026-09-21 at 17:24 Europe/Istanbul.
Build ID: `98f4f633-a1d3-4619-b99d-af4d62b5f067`.
English and Turkish test notes saved; automatic tester notifications enabled.
Verified **Testing** on both Clockin Public Beta and Clockin Internal group Builds
pages on 2026-09-21.
