# iOS 0.2 (22): Decorative desks and independent seated companion

- Portrait display scale increases from 0.60 to 0.85 (about 42% larger in each
  dimension), with its center lowered to retain clearance from the ceiling.
- All three desk items are independent wall decorations. Each is centered under
  the bookshelf with an eight-point gap and feet aligned to the back-wall floor.
  Artwork retains its original proportions; the shortened-leg compositor is removed.
  The desk lamp glow and monitor steam follow their new decoration positions.
- A running session always uses the typing pose, even without a desk. Desk choice
  no longer changes activity or companion position. With the bean bag equipped,
  working and resting poses sit on it; without it they sit on the floor. Existing
  bed sleep behavior remains. No furniture is purchased or equipped automatically.
- Room left faces left; Room right faces right, for both typing and resting.
  The two pose sources have opposite native directions, handled separately.
  Stored layout values are preserved. Preview selectors no longer require a desk
  to preview work, or a bean bag to preview seated rest.

## Verification

2,795 wardrobe checks passed, including work with no desk, unchanged position
across desk selections, bean/floor rest, facing direction, portrait/wall/window
clearance, desk/shelf gap and alignment, aspect ratio, and existing wardrobe/cache
behavior. Production-geometry scenes were rendered and inspected in both directions
and while working/resting. Review files: [room-layout-22](art-review/room-layout-22).
These are offline composition checks; interactive iPhone visual verification is
not available in this environment.

## Release

Frozen source: `/tmp/clockin-room-22-final/source`.
Archive: `/tmp/clockin-room-22-final/Clockin.xcarchive`.
Signed Release archive passed without compiler warnings/errors. App and widget
are 0.2 (22); strict deep codesign passed and all 349 source hashes matched.
Upload succeeded on 2026-09-21 at 17:42 Europe/Istanbul.
Build ID: `8bb4f7c8-adfa-4628-8b3a-421670b5aa6d`.
English and Turkish notes saved; automatic tester notifications enabled.
Verified **Testing** in both Clockin Public Beta and Clockin Internal on 2026-09-21.
