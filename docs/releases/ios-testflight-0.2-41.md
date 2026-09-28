# iOS 0.2 (41): Armour skins in HD

Repository: `erdmncdr/clockin-ios`.
Source: main at `1efa39258b2bc88bdf0301a98baf3d6115fe3e6d`.

- The companion's shop opens with a Skins category: fourteen armour skins
  that dress the companion as a whole. Nine paladins come first, one per
  rank, each in its rank's metal and light, from the Spark Paladin at 2000
  coins to the Eternal Paladin at 12000; then the Nova Pilot, Aurora Warden,
  Celestial Guardian, Obsidian Knight and Eternal Seraph, each its own
  design. While a skin is worn the other garments are hidden and come back
  when it is taken off.
- Skins are rendered in HD in the look of the level-up paladin: the
  companion's own frames are rebuilt into smooth, lit plates and dressed in
  vector armour, so every pose, expression and prop stays right, with the
  wings raised and capes pooled behind it when it sits. A soft glow, a
  sheen across the armour and the skin's own particles play while it
  moves. Frames render once and are cached; widgets show them too.
- Resting in its bed, the companion now lies there in full view: head on
  the pillow, body on the sheet and arms on the blanket over its legs, in a
  redrawn, deeper bed.
- Debug builds gain `--skin-preview` (every skin, or `--skin <id>` in five
  moods), `--companion-shop` and `--companion-sleep-preview`.
- Everything from 0.2 (40).

## Verification

```text
Checks: 34 of 34 passed
Archive: succeeded, 0 warnings, 0 errors
Clockin.app: 0.2 (41)
ClockinWidgets.appex: 0.2 (41)
Signature: satisfies its Designated Requirement
Sounds: 8 chimes, 3 level-up cues
Turkish strings: 1288 of 1288
```

## Release

Upload succeeded at 2026-09-28 22:01:54 Europe/Istanbul; processing completed.
Build ID: `5097accf-c5e4-40e0-bd52-445a29ed7f92`.
The English and Turkish test notes below were saved and tester notification
was enabled. Both groups, Clockin Public Beta and Clockin Internal, were added
from the build's page in one step and the build was submitted for review.
Both groups' Builds lists then showed 0.2 (41) as **Testing**.

## What to Test

### English

New in the companion's shop: fourteen armour skins. Nine paladins in the level-up's rank metals come first, then Nova Pilot, Aurora Warden, Celestial Guardian, Obsidian Knight and Eternal Seraph. Try them on and watch the companion wave, dance, sip coffee and type at the laptop in each one; check the glow, the sheen across the armour and the particles. Resting in bed, the companion now lies there in full view.

### Turkish

Arkadaşın mağazasında yeni: on dört zırh skini. Başta seviye atlamadaki rütbe metallerinden dokuz paladin, ardından Nova Pilotu, Aurora Bekçisi, Göksel Muhafız, Obsidyen Şövalye ve Ebedi Seraf. Hepsini deneyin; her birinde arkadaşın el sallamasına, dansına, kahve içmesine ve laptopta yazmasına bakın, zırhtaki ışığı, parıltıyı ve parçacıkları kontrol edin. Yatakta dinlenirken arkadaş artık tüm bedeniyle yatıyor görünüyor.
