# iOS 0.2 (35): A level-up that hits

Repository: `erdmncdr/clockin-ios`.
Source: main at `1fb0528ba6e81b9fbd961b5d1d7e879d6c968826`.

- The level-up charge runs 1.3 s instead of 0.62 s, under a pulse that
  quickens: the crest swells, the floor sigil beats and the phone taps on each
  one, while the crest shakes harder as the charge builds.
- For the last 0.22 s before the strike the scene darkens, the light is drawn
  in round the crest, the crest shrinks and goes still, the old number heats
  and the haptics fall silent.
- The strike holds for 0.08 s, the way a fighting game freezes on a hit, then
  the stage jolts down and shakes for half a second and the new number lands
  from further out. The bloom, shock ring and sparks are a little stronger.
- The title, XP refill and rank panel follow a little more slowly; a new
  rank's second beat moves from 1.7 s to 2.65 s and gets a smaller jolt.
- Everything from 0.2 (34).

## Verification

```text
Checks: 32 of 32 passed
Archive: succeeded, 0 warnings, 0 errors
Clockin.app: 0.2 (35)
ClockinWidgets.appex: 0.2 (35)
Signature: satisfies its Designated Requirement
Chime sounds: 8
Turkish strings: 1272 of 1272
```

## Release

Upload succeeded at 2026-09-27 03:18:34 Europe/Istanbul; processing completed.
Build ID: `ee63114c-a9e0-436f-9cef-83aa84ccd057`.
The English and Turkish test notes below were saved and tester notification
was enabled. The build was added to Clockin Public Beta and submitted for
review, then to Clockin Internal from the group's Builds tab. Both groups'
Builds lists then showed 0.2 (35) as **Testing**.

## What to Test

### English

The level-up hits harder. The charge builds for longer under a quickening pulse you can feel in your hand, everything goes quiet for a moment, then the new level strikes with a brief freeze and a jolt of the stage. The rewards after it arrive a little more slowly.

### Turkish

Seviye atlama artık daha vurucu. Güç toplama daha uzun sürüyor ve hızlanan nabzı elinde de hissediyorsun. Ardından her şey bir an susuyor, yeni seviye kısa bir donma ve sahne sarsıntısıyla iniyor. Sonrasında gelen ödüller de biraz daha yavaş açılıyor.
