# iOS 0.2 (42): A stern visor, no dark backdrop

Repository: `erdmncdr/clockin-ios`.
Source: main at `43f732a17136d94d7e75a9ee3d53be19a5a6bf31`.

- The HD skins no longer stand in a dark backdrop. In a light room every
  skin sat inside a thick black shape: the source's dark outline and its
  mid-grey shading were drawn as near-black joints round the plates, and
  the plates' shadows fell past the figure. The lighter shading now belongs
  to the plate, the dark outline is peeled back beside the plates (keeping
  the antenna's stem) and plates and shadows stay inside the silhouette.
- Seated, the armoured companion's head is in proportion. The coffee and
  typing frames draw the head about half as big again as the standing
  ones; it is now scaled about the neck to the standing ratio in every
  frame, so the seated companion looks like the standing one sitting down.
- Every skin wears the level-up paladin's face: a dark glass visor with two
  hard glowing slits in the skin's eye colour and no mouth, instead of the
  happy arcs and smile. The slits close to a line on a blink or in sleep,
  narrow when sleepy and sharpen when angry.
- Debug builds' skin preview can show a light ground (`--light`).
- Everything from 0.2 (41).

## Verification

```text
Checks: 34 of 34 passed
Archive: succeeded, 0 warnings, 0 errors
Clockin.app: 0.2 (42)
ClockinWidgets.appex: 0.2 (42)
Signature: satisfies its Designated Requirement
Sounds: 8 chimes, 3 level-up cues
Turkish strings: 1288 of 1288
```

## Release

Upload succeeded at 2026-09-29 02:28:04 Europe/Istanbul; processing completed.
Build ID: `ef2ec343-c477-45d7-8ac5-8e196d125b4c`.
The English and Turkish test notes below were saved and tester notification
was enabled. Both groups, Clockin Public Beta and Clockin Internal, were added
from the build's page in one step and the build was submitted for review.
Both groups' Builds lists then showed 0.2 (42) as **Testing**.

## What to Test

### English

The armour skins no longer stand in a dark shape on light rooms. Sitting with coffee or at the laptop, the armoured companion's head is now in proportion, and every skin has a stern visor with glowing eye slits instead of a smiling face. Check the skins in a light room and in every pose.

### Turkish

Zırh skinleri açık renkli odalarda artık koyu bir zeminin içinde durmuyor. Kahveyle ya da laptopta otururken zırhlı arkadaşın kafası artık orantılı, ve her skinde gülen yüz yerine parlayan göz yarıklı ciddi bir vizör var. Skinleri açık renkli bir odada ve her pozda kontrol edin.
