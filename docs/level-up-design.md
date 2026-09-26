# The level-up moment

Reaching a new level used to open a card with a floating astronaut and a pulse
of rings. This brief replaces it with a moment staged the way MOBAs and
MMORPGs stage a level-up, kept in Clockin's space setting. The code is in
`Clockin/Celebrations/LevelUpCard.swift`, `LevelUpStage.swift`,
`LevelUpCrest.swift`, `LevelUpAura.swift`, `LevelUpWarrior.swift`,
`LevelUpTiming.swift` and `LevelUpHaptics.swift`.

## What the genre does

- **World of Warcraft**: a column of golden light rises round the character,
  motes drift up, and the new level is announced with a sound everyone knows.
- **League of Legends**: a flash and a ring at the champion's feet, and the
  level on the portrait pulses. Ranked promotions go further: a dark stage,
  energy gathering, a burst, the emblem landing with a shock ring, the tier
  name after it, then the emblem idling with its own particles.
- **Action MMOs and mobile RPGs** (Lost Ark, Genshin Impact, Honkai: Star
  Rail): large metallic numerals in an ornate ring or banner, a magic circle
  on the ground, and the rewards listed underneath, one line at a time.
- **Effects practice**: an effect has three stages. Anticipation builds, the
  impact has the biggest contrast and saturation, and the dissipation is short
  and quiet ([VFX staples](https://80.lv/articles/vfx-staples-shape-color-and-motion)).
  The build-up is what makes the reward feel earned.

## Principles

1. **Three beats.** Charge for 0.62 s, impact, settle. After about three
   seconds only slow light remains.
2. **One focal point.** The level number, struck into a forged crest, is what
   the eye follows. Everything else points at it: dust spirals into it, the
   column rises through it, rays turn behind it.
3. **Light adds up.** All effects use additive blending in the rank's colour,
   so overlapping light gets brighter instead of covering.
4. **The XP bar is part of the story.** It fills to the end during the charge,
   flashes on the impact, then empties and refills to the XP carried into the
   new level.
5. **A new rank gets its own beat.** A level that opens a rank (every 75)
   levels up in the old rank's colours; 1.7 s in, the crest re-forges in the
   new metal and stone and the new colour floods the scene.
6. **Each rank has its own light.** The crest takes the rank's metal, face,
   stone cut and a number of points that grows with the rank; the stage adds the
   rank's signature from `docs/rank-and-medal-design.md` at stage scale (see
   below).
7. **Safe to watch.** One soft bloom per beat, never a strobe. With Reduce
   Motion or Low Power Mode the card opens on its final frame. The title is
   decoration; assistive technologies read "Level up, Level N".
8. **Felt as well as seen.** The haptic pattern follows the same clock: a hum
   that builds during the charge, a heavy double thump on the impact and, on a
   new rank, a second beat with three light sparkles.

## The companion

With the companion enabled it stands on the sigil in the column of light,
dressed as a paladin in the pose MMORPG heroes strike at a level-up: a runed
greatsword planted in front, both gauntlets closed round the grip, wings of
light and a halo behind. Its face, the screen with two eyes of light that
makes it the companion, looks out through the visor. It is drawn smooth
rather than as the pixel sprite, so it sits in the shaded plate. The eyes are
hard slits whose top edge falls toward the nose, the stern look of a hero
rather than the companion's everyday smile: narrow and gathering light during
the charge, a white flare when the level lands, then a steady burn with a rare
blink. Small, dim tongues of magic fire in the rank's colour crawl along the
upper edge of each flight feather and die at the tip, with an ember rising
off a tip now and then: felt more than seen, never a flare. The plate is the rank's metal made pale, the trim
(pauldron edges and feathers, helm wings, circlet, scrollwork, couters, cuffs,
crossguard) is the rank's metal, the tabard is the rank's colours and the light
(wings, halo, runes, gems) is the rank's colour, so its gear rises with the
rank. On a new rank it changes with the crest on the second beat.

The armour is shaded as formed metal rather than flat colour: one key light
from the upper left as on the badges, the column behind the figure as a rim
light, a shadow cast by each part onto the one behind it, occlusion where a
plate turns away and a specular spot on polished faces. It is drawn once per
rank; only the wings, halo, runes and gems move, so the detail does not cost a
redraw per frame. Two other looks (plate knight, power-suit pilot) were drawn
and set aside in favour of this one.

## Timeline

| Time (s) | What happens |
|---|---|
| 0 to 0.62 | Dark stage. The floor sigil draws itself round; stardust spirals into the crest, faster as it arrives; the crest, still dark steel with the old level, trembles; a thread of light finds it from the floor; the XP bar runs to full |
| 0.62 | Impact: soft bloom, shock ring, a ring across the floor, sparks thrown out with drag; the column of light shoots off the top of the stage; the crest lights and the new number, serif numerals struck in the rank's metal, lands from twice its size |
| 0.7 to 1.1 | The title closes in from wide letter spacing with its rules; rays spin up and settle to a slow turn; the XP bar empties |
| 1.1 to 1.9 | The XP bar refills; the rank panel (centred, under a titled rule) and the next rank land. The top rank has no next look, so that row is left out |
| 1.7 (new rank) | Second beat: another bloom and ring, the crest re-forges in the new rank, the colours cross-fade, the rank badge lands with its unlock burst |
| After | Embers rise through the column, the sigil turns, the rays breathe, a sheen crosses the number every 4.5 s, and the rank's own light plays |

## Rank light on the stage

| Rank | Crest | Stage light |
|---|---|---|
| Spark | Blued steel, no points | A crackle of sparks off the stone every few seconds |
| Orbit | Bronze, two points | Two moons on a tilted orbit, passing behind the crest |
| Nebula | Violet silver, two points | Drifting cloud puffs with twinkling stars |
| Solar | Gold, four points | A corona of flame tongues behind the crest |
| Nova | Platinum, four points | A four-point star behind the crest and a periodic shock ring |
| Aurora | Emerald, seven points | Aurora ribbons across the sky |
| Sovereign | Gold over ruby, seven points | A gleam that runs round the crest's rim, the ruby beating warmly and ruby sparks drifting round it; no crown over the crest, which crowded the number |
| Celestial | Silver over midnight, seven long points | A constellation drawing itself round the crest |
| Eternal | White gold, seven long points | Iridescent wings unfolding behind the crest |

## Reviewing it

The debug build has a preview: launch with `--level-effects-preview`, add
`--preview-level N` for a level, `--preview-time S` to hold every part of the
card at one moment, `--preview-clean` to hide the controls, and
`--preview-no-companion`, `--preview-large-text` or `--preview-still` for the
variants. `--warrior-portrait` shows the companion's armour large on a lit
stage instead of the card. `--feedback-review overlay` shows the card inside
the real celebration overlay.
