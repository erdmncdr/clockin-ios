# iOS 0.2 (36): A strike across the whole screen

Repository: `erdmncdr/clockin-ios`.
Source: main at `e097e13ca970ab9ec66c63227bc5a96668c1fa60`.

- The level-up charge runs 1.6 s. Arcs of energy crack from the floor sigil
  into the crest on each pulse and more often as it builds, the camera pushes
  slowly in, and the screen darkens round the crest, closing in through the
  hush while the crest stays lit.
- The strike is drawn over the whole card: the darkness snaps off under a
  single full-screen flash, a shock wave runs off the screen's edges, a lens
  streak crosses it, beams fire out for an instant and sparks fly to the
  edges. The hold is 0.1 s, the stage shakes harder, the camera is knocked
  back, and the impact's rumble is heavier. A new rank's second beat, now at
  2.95 s, gets a smaller strike of the same kind.
- The companion breathes faster, quickening through the charge, holding its
  breath in the hush and pressed down by the strike. It blinks every 3.1 s
  instead of every 6.5 s, every other time twice.
- The stage draws at up to 120 fps on ProMotion phones during the entrance.
  The floor sigil no longer rebuilds its rings every frame; offscreen frame
  time on the simulator fell from 2.85 to 1.90 ms on average.
- Everything from 0.2 (35).

## Verification

```text
Checks: 32 of 32 passed
Archive: succeeded, 0 warnings, 0 errors
Clockin.app: 0.2 (36)
ClockinWidgets.appex: 0.2 (36)
Signature: satisfies its Designated Requirement
Chime sounds: 8
Turkish strings: 1272 of 1272
```

## Release

Upload succeeded at 2026-09-27 12:30:48 Europe/Istanbul; processing completed.
Build ID: `d3819f8b-d364-4710-9957-47c95f254a94`.
The English and Turkish test notes below were saved and tester notification
was enabled. The build was added to Clockin Public Beta and submitted for
review, then to Clockin Internal from the group's Builds tab. Both groups'
Builds lists then showed 0.2 (36) as **Testing**.

## What to Test

### English

The level-up now builds for longer: arcs of energy crack into the crest, the screen darkens around it and the companion breathes faster. Then the strike fills the whole screen with a flash, a shock wave and sparks flying to the edges. On ProMotion iPhones it runs at up to 120 fps.

### Turkish

Seviye atlama artık daha uzun güç topluyor: armaya enerji arkları çakıyor, ekran etrafında kararıyor ve arkadaşın daha hızlı nefes alıyor. Ardından vuruş bütün ekranı bir parlama, bir şok dalgası ve kenarlara uçan kıvılcımlarla dolduruyor. ProMotion ekranlı iPhone'larda 120 fps'e kadar akıyor.
