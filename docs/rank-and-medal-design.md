# Rank badges and mission medals

The level badge and the mission medals are drawn in code from one material
(`Clockin/Celebrations/PrestigeForge.swift`): one light above and to the left,
each face shaded by the angle it makes with it. That gives depth. It does not
give identity: after the first pass the nine ranks differed mostly in hue, and
the six mission tiers in how many rings they had. This file is the brief for
telling them apart.

## Principles

Taken from how games that live on rank progression handle it (Valorant, League
of Legends, Rocket League), and from Apple's guidance on motion.

1. **A rank is recognisable without its colour.** Each rank has its own
   silhouette, so a grey-scale screenshot still tells them apart. Colour is the
   second cue, not the only one.
2. **Higher ranks take more space and more structure.** The outline grows
   ornaments outward (a ring, flares, points, a crest, wings) instead of adding
   loose decoration inside.
3. **Each rank has its own material.** Metal, face and stone are chosen
   separately, and the upper ranks pair two materials for contrast.
4. **The gem is the focal point**, and its cut changes with the rank.
5. **Motion is a reward that grows.** The first rank barely moves; the last one
   is the only one whose whole body moves. Every rank has one signature
   motion, never several competing ones.
6. **Motion is calm and periodic.** One event every few seconds, or one slow
   continuous drift. Nothing flashes. With Reduce Motion, Low Power Mode or the
   badge off screen, each rank shows a still frame chosen to show its
   signature, and nothing about the rank depends on motion to be understood.

## Level ranks

Every 75 levels. The compact badge on Today is 106 x 44 points; ornaments may
reach outside that box, as the crest already does.

| Rank | Levels | Material | Silhouette cue | Gem | Signature motion | Still frame |
|---|---|---|---|---|---|---|
| Spark | 1-74 | Blued steel, matte | Plain rounded plate | Smooth cabochon | A single spark leaps off the gem every ~7 s | No spark |
| Orbit | 75-149 | Bronze | A tilted orbit ring breaks out of the plate around the gem | Round brilliant | A moon circles the gem, passing behind it | Moon in front |
| Nebula | 150-224 | Violet-cast silver | Shallow chamfered corners | Cabochon with drifting nebula clouds inside | Clouds drift; a star in the face twinkles | Clouds mid-drift |
| Solar | 225-299 | Gold | Pointed flares at both ends | Round brilliant with a corona behind it | Corona rays turn slowly and breathe | Rays at rest |
| Nova | 300-374 | Platinum with cyan | Four-point star behind the gem, points past the rim | Brilliant | Gem charges, then a shock ring crosses the plate every ~6 s | Star lit, no ring |
| Aurora | 375-449 | Emerald enamel | Arched top edge, two-tier rim | Emerald step cut | Aurora ribbons flow slowly across the face | Ribbons mid-flow |
| Sovereign | 450-524 | Gold metal, ruby face | Three-point crown on top | Ruby, kite cut | Crown stones light in turn, then a glint runs round the rim | Crown lit |
| Celestial | 525-599 | Silver metal, midnight face | Crown, arch and small side wings | Star sapphire (six-ray star) | A constellation draws itself between stars in the face | Constellation drawn |
| Eternal | 600+ | Prismatic white gold | Swept wings, crown and a hanging seal | Diamond with fire | Iridescence travels across the whole badge | Iridescent at rest |

The rank's tint (progress bars, the level card) comes from its stone, not its
metal, so neighbouring ranks no longer share a colour.

## Mission medals

Six tiers, six mission families. The **tier** decides the medal and its effect;
the **family** decides the emblem and a small movement of the emblem.

| Tier | Ring | Reveal effect (once) | In the detail view (continuous, slow) |
|---|---|---|---|
| Launch | Single ring | Sparks rise from the stone like exhaust and fade | None |
| Orbit | Single ring, engraved line | A satellite runs once around the ring, passing behind it | The satellite keeps orbiting |
| Lunar | Two-tier ring | A crescent shadow crosses the face, uncovering the emblem | The face slowly goes through its phases |
| Solar | Two-tier ring, engraved line | A corona opens behind the medal | The corona turns slowly |
| Galactic | Two-tier ring, engraved line | Particles spiral into the centre | A faint spiral turns in the face |
| Eternal | Double ring | The two rings turn against each other under a prismatic sweep | Prismatic shimmer |

| Family | Emblem movement on reveal |
|---|---|
| Flight | Lifts slightly and settles |
| Signal | Pulses twice along its line |
| Orbit (days) | Turns a few degrees and back |
| Archive | Layers drop into place one by one |
| Habitat | Builds up from the bottom |
| Suit | A glint crosses the visor |

Locked medals stay matte steel with an engraved emblem and have no effect.

## Performance

- The drawn body of a badge or medal does not change per frame; only its effect
  layer does. A grid of medals animates only while it reveals.
- Continuous motion runs only where one badge is in view (Today, the rank
  gallery's large preview, a medal's detail view), through a `TimelineView`
  that pauses when the view is hidden, motion is reduced or power is low.
