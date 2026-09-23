# iOS 0.2 (20): Space missions and free room gifts

## Behavior

- Launch, Orbit, Lunar, Solar, Galactic and Eternal replace the metal ranks.
  Eternal contains only Time titan (1,500 hours), Year of hundreds (12 months
  with 100 hours), Year-round (365-day streak) and Permanent practice (500 days).
  All 61 existing badge IDs and unlock conditions remain intact.
- Six tabs show one tier at a time. Accessibility text sizes use a 3×2 selector.
  Each tier shows its progress and the next locked mission; tapping a badge
  opens its requirement, progress and effect preview. Level & XP is collapsed
  beneath the missions so it does not push the collection below the fold.
- Original vector insignia replace the tier symbols. Six effect families follow
  work time, streaks, active days, sessions, home collection and outfits; tier
  and stable badge seed vary their appearance. Effects appear in the tabs,
  selected-tier header and badge seals. Motion is finite and skips Reduce Motion
  and Low Power Mode; the detail view has a replay control.
- Atatürk portrait and Turkish flag are free wall items, automatically owned on
  refresh by new and existing users. They use separate slots, remain correctly
  oriented in mirrored rooms, and do not count toward purchase badges. Equipping
  remains optional. Assets are bundled, with no new runtime requests.
- Session and Today columns are centered. Focus Chime's options menu is on its
  lower row. Pace, customization, collection and settings explanations are shorter;
  privacy consent and destructive-action warnings retain their meaning.

## Verification

- Signed Release archive succeeded with no compiler warnings/errors.
- App and widget both identify as 0.2 (20); strict deep codesign verification passed.
- All 348 frozen source hashes match. Both gifts match their source bytes in the
  app and widget resource bundles.
- 51 tier/purchase/gift checks passed: thresholds, ultimate-tier membership,
  existing and new-user free ownership, idempotence, simultaneous equipping and
  exclusion of free gifts from purchase progress.
- 2,573 wardrobe checks passed, including real artwork, layout collision bounds,
  persistence, earnings, mirroring and cache behavior.
- 19 geometry/render checks passed. Insignia and both room orientations were
  rendered with production geometry and inspected. Review images are in
  [art-review/space-missions](art-review/space-missions).
- These render checks are not an interactive iPhone UI test. On-device tab layout,
  text wrapping and animations remain unverified in this environment.

## Source and attribution

Frozen source: `/tmp/clockin-space-20-final/source`.
Signed archive: `/tmp/clockin-space-20-final/Clockin.xcarchive`.
The release script preserves the current companion UI and merges main-owned
features; the main checkout alone is not the release UI.

Art direction and original-photo/flag references:
[space-missions-design.md](space-missions-design.md).

## Distribution

Upload succeeded on 2026-09-21 at 17:04 Europe/Istanbul. Verified **Testing**
on both Clockin Public Beta and Clockin Internal group Builds pages. Build ID: `89aa9a35-7c0d-4c2d-910f-487838a3ef44`.
English and Turkish test notes saved; automatic tester notifications enabled.
