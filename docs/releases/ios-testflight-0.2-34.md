# iOS 0.2 (34): Level-up polish

Repository: `erdmncdr/clockin-ios`.
Source: main at `5be28e968be3dc7df63b21cb7ebe3385758df742`.

- The paladin's halo and wing tips, and the stage's rays and shock rings, no
  longer end in straight lines; the stage light fades out before the top edge.
- The star marks on the floor sigil's dashed ring always sit in a gap, never
  on a dash. Measured over a full turn, the closest line stays 1.9 pt from a
  mark's edge; before, every moment had at least one overlap.
- The level on the crest is centred by eye: drawn from its glyph outlines,
  centred on its ink and moved three quarters of the way toward the centre of
  its ink's area, so a figure like 45 no longer reads as shifted right.
- Everything from 0.2 (33).

## Verification

```text
Checks: 32 of 32 passed
Archive: succeeded, 0 warnings, 0 errors
Clockin.app: 0.2 (34)
ClockinWidgets.appex: 0.2 (34)
Signature: satisfies its Designated Requirement
Chime sounds: 8
Turkish strings: 1272 of 1272
```

## Release

Upload succeeded at 2026-09-26 15:44:02 Europe/Istanbul; processing completed.
Build ID: `a7c00b52-3fdc-49e3-be84-5bda137f9007`.
The English and Turkish test notes below were saved and tester notification
was enabled. The build was added to Clockin Public Beta and submitted for
review, then to Clockin Internal from the group's Builds tab. The iOS Builds
list then showed 0.2 (34) as **Testing** in both groups.

## What to Test

### English

The level-up screen is tidier: light no longer ends in straight lines above the companion or under the status bar, the marks on the floor ring stay clear of its dashes, and the level number sits visually centred on the crest.

### Turkish

Seviye atlama ekranı daha düzenli: ışık artık arkadaşın üstünde ve bildirim çubuğunun altında düz çizgiyle kesilmiyor, zemindeki halkanın elmasları çizgilere değmiyor ve seviye sayısı armanın ortasında duruyor.
