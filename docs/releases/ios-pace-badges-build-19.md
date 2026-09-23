# iOS 0.2 (19): Today pace, month-aligned weeks and badge tiers

## Behavior

- Today’s Goals & daily pace card shows monthly progress, a suggested full-day
  target, work remaining today and a warning when the saved daily goal is lower.
  It uses the same quarter-hour recommendation as Progress > Goals, credits work
  already completed today, and labels remaining workdays as estimates. Missing
  workday setup, a reached goal and an impossible pace have explicit messages.
  Customize controls the actual card. Its calculation uses the shared minute
  snapshot; the per-second timer does not rescan the session archive.
- The pinned Focus Chime card has two compact rows: enable/options, then interval
  and sound. Sound/volume and unpin are in its options menu. The existing enable
  permission action and 1–120 minute interval are preserved; controls retain
  44-point hit targets.
- History W and Reports Week use 1–7, 8–14, 15–21, 22–28, then any remaining days
  in the month. Paging crosses short final weeks without gaps or overlaps. Daily
  heatmap rows retain weekday alignment. Hours, money and start-date attribution
  remain unchanged.
- All 46 existing work badge IDs and conditions are preserved. Five tiers are
  Bronze, Silver, Gold, Platinum and Diamond. Placement considers total effort,
  repeated sessions/days, and consecutive streak requirements, rather than equal
  group sizes. Each tier has color, ornament and completion count. Detail views
  add a brief earned-badge animation, stronger at higher tiers. The grid is static;
  Reduce Motion, locked badges and Low Power Mode skip the reveal animation.
- Fifteen cosmetic purchase badges count distinct positive-cost, catalog-valid
  purchases, including prior ledger entries. Free unlocks, unknown items, duplicate
  ledger entries and equipping do not count. Total-item thresholds are 1/5/10/20/40;
  outfit/color thresholds 1/3/6/12/20; home/room thresholds 1/3/6/12/18. All are
  reachable with the current catalog. Purchase badges appear in the shared stats
  snapshot, reports and celebration queue, while work-only coin calculations
  remain independent. They grant no additional coins or XP. A successful purchase
  refreshes the snapshot immediately.

## Verification

- 284 earnings and month-week checks: all days across 2024–2028, partial final
  weeks, leap years, DST, backward/forward paging, chart/list boundaries and money.
- 148 insights checks: weekly aggregation, monthly totals and unchanged work badges.
- 42 tier/purchase checks: thresholds immediately below/at unlock, category counts,
  duplicates/free/unknown records, stable IDs and reachable highest tiers.
- 28 monthly plan checks; 2,474 existing wardrobe checks including real art,
  persistence, coin logic and cache behavior.
- Both signed Release archives succeeded with no compiler warnings or errors;
  app/widget both 0.2 (19), strict deep codesign verification passed, and all 342
  source hashes matched in each archive. The final source differs only in updated in-app guidance.
- Device visual acceptance remains unverified: the available UI tool could not
  open a usable iOS Simulator/DeviceHub in this session’s established workflow.
  Check Today text wrapping, compact chime options, tier detail motion, large text
  and purchase celebrations on an iPhone.

## Release provenance

The current companion UI working tree is frozen with
`scripts/prepare-ios-live-activity-release.py`; main alone is not the release UI.
Source: `/tmp/clockin-pace-badges-19-final/source`.
Archive: `/tmp/clockin-pace-badges-19-final/Clockin.xcarchive`.
Upload succeeded on 2026-09-21 at 16:19 Europe/Istanbul.
Build ID: `b58bc40f-d8f0-4e8c-9177-20dc711ea39a`. English and Turkish notes saved,
tester notifications enabled. Verified 0.2 (19) as **Testing** on both Clockin
Public Beta and Clockin Internal group Builds pages on 2026-09-21.
