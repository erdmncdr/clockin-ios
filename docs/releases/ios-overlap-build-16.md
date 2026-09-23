# iOS 0.2 (16): adjacent minute handoffs

Request: 01:00–01:41 followed by another session starting at 01:41 must not show
an overlap. Exact endpoint equality already used half-open intervals and passed.
A separate seconds-only case reproduced the reported warning: an end of 01:41:35
and next start of 01:41:00, both displayed/edited as 01:41.

SessionOverlap now shares one predicate across pair checks, editor lookup and
history flags. If the preceding session ends in the next session's start minute,
and each session extends beyond that shared minute on its respective side, the
seconds-only handoff is ignored. This is not a blanket 60-second tolerance:
starting at 01:40:59 against an end at 01:41:35 still warns. Identical, contained
and overlapping short records remain conflicts. All overlapping candidates in
the sweep are still checked, so a third long session cannot be hidden.

Saved timestamps, durations, earnings, import matching and running timer behavior
are unchanged. Existing saved entries use the new rule without migration.

## Verification

- Regression failed before the change at the same-minute handoff example.
- All 30 overlap checks pass after it, including editor/history consistency,
  exact adjacency, midnight, duplicates, containment and input order.
- Release snapshot uses current companion-art UI plus owned changes, including
  Goals & Pace and previous privacy/persistence fixes.
- All 334 source hashes match; Release archive succeeds with app/widget 0.2 (16).
  Strict deep code-signature verification succeeds.
- Physical-device UI remains unverified; this changes the shared calculation
  already used by both affected screens.

## Distribution

Archive: `/tmp/clockin-overlap-16/Clockin.xcarchive`.
TestFlight upload succeeded on 2026-09-21 at 14:24 Europe/Istanbul.
App Store Connect build ID: `b36b8d7d-abc8-4038-82e2-998791083489`.
English and Turkish test notes saved. Both Clockin Internal and Clockin Public
Beta group build pages visibly show 0.2 (16) as **Testing** on 2026-09-21.
