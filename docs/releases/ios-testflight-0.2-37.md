# iOS 0.2 (37): From dark chaos into light, with sound

Repository: `erdmncdr/clockin-ios`.
Source: main at `898514358c8fd7df96d25bcf7cc6fee758a21fad`.

- The level-up charge runs 2.2 s and gets darker and wilder as it builds:
  the screen goes nearly black round the crest, arcs crack in twice as
  often (some forking, some out of the air), the stage trembles harder and
  motes are dragged up off the floor. Everything stops for a 0.3 s hush.
- The strike floods the screen with light from the crest within 0.2 s,
  holds it bright, then eases back to the scene over about a second; the
  title comes up out of the fading light and the rewards follow.
- The level-up has a sound, synthesized on the same clock: a rising drone
  with a heartbeat on every pulse and crackle on every arc, silence for the
  hush, then a boom, crack and air blast into a hall reverb and a C major
  chord that fades with the light. A new rank adds a rising bell arpeggio.
  It plays only while Clockin is open, mixes with other audio, follows the
  silent switch unless Focus radio is playing, and can be turned off in
  Settings (Level-up sound).
- The sound and haptics stop with the card when it is dismissed early.
- Everything from 0.2 (36).

## Verification

```text
Checks: 32 of 32 passed
Archive: succeeded, 0 warnings, 0 errors
Clockin.app: 0.2 (37)
ClockinWidgets.appex: 0.2 (37)
Signature: satisfies its Designated Requirement
Sounds: 8 chimes, 3 level-up cues
Turkish strings: 1273 of 1273
```

## Release

Upload succeeded at 2026-09-27 14:11:29 Europe/Istanbul; processing completed.
Build ID: `aff8681d-b283-46ac-a657-f02b428000e1`.
The English and Turkish test notes below were saved and tester notification
was enabled. The build was added to Clockin Public Beta and submitted for
review, then to Clockin Internal from the group's Builds tab. Both groups'
Builds lists then showed 0.2 (37) as **Testing**.

## What to Test

### English

The level-up now has sound: power builds in the dark with a heartbeat and crackling arcs, falls silent, then explodes into a bright chord as the screen floods with light. The charge is longer and darker, and the light holds for a moment before the screen returns to normal. You can turn the sound off in Settings. It follows the silent switch.

### Turkish

Seviye atlamanın artık sesi var: karanlıkta kalp atışları ve çıtırdayan arklarla güç toplanıyor, bir an susuyor, sonra ekran ışıkla dolarken parlak bir akorla patlıyor. Güç toplama daha uzun ve daha karanlık, ışık da ekran normale dönmeden önce bir süre kalıyor. Sesi Ayarlar'dan kapatabilirsin. Sessiz moda uyar.
