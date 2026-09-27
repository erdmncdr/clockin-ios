# iOS 0.2 (40): Bass on a phone speaker

Repository: `erdmncdr/clockin-ios`.
Source: main at `0b24251974bbd466f267c148898e4fb60c9cefe7`.

- The level-up's boom, heartbeat and wall of fifths sit below what a phone
  speaker plays. They now carry overtones the ear rebuilds the low note
  from, and the deepest sub no longer uses up the headroom. Through a filter
  standing in for a phone speaker, the heartbeat is about 3 dB louder, the
  strike 2 dB and the wall after it 9 dB. Headphones keep the full sub under
  the heartbeat; the wall is fuller there too.
- Debug builds can open the level-up review at any level
  (`--review-level`), to hear a new rank's cue.
- Everything from 0.2 (39).

## Verification

```text
Checks: 32 of 32 passed
Archive: succeeded, 0 warnings, 0 errors
Clockin.app: 0.2 (40)
ClockinWidgets.appex: 0.2 (40)
Signature: satisfies its Designated Requirement
Sounds: 8 chimes, 3 level-up cues
Turkish strings: 1273 of 1273
```

## Release

Upload succeeded at 2026-09-27 18:43:35 Europe/Istanbul; processing completed.
Build ID: `4a0ef2e0-868d-4377-bc5e-7aba4ad44fb7`.
The English and Turkish test notes below were saved and tester notification
was enabled. Both groups, Clockin Public Beta and Clockin Internal, were added
from the build's page in one step and the build was submitted for review.
Both groups' Builds lists then showed 0.2 (40) as **Testing**.

## What to Test

### English

The level-up's deep sounds, the heartbeat, the boom and the heavy wall after the thunder, should now come through on the phone's own speaker, not only on headphones.

### Turkish

Seviye atlamadaki derin sesler, kalp atışları, patlamadaki gümleme ve gök gürültüsünden sonraki ağır ses duvarı artık kulaklık olmadan telefonun kendi hoparlöründen de duyulmalı.
