# 31 — Website redesign result

Date: 2026-10-09. Work is local, ready for owner review. **No deployment or deploy dry-run was performed.** No dependencies or build step were added. Application code, existing real captures, the relay and deployment tooling were not changed.

## Page and visual direction

The page follows the requested dark hardware-gallery reference, adapted to Clockin's robot and orange `#f78a18` actions. Light mode retains porcelain surfaces. System fonts, 600-weight display headlines, quiet supporting copy, 28 px media corners and shadow-free media replace the previous presentation. References and final decisions are recorded in [website/DESIGN.md](../../website/DESIGN.md).

1. **Hero:** animated original mascot, sculptural headline, Mac download and explicitly labelled iPhone beta, platform requirements.
2. **Workday:** preserved interactive focus/break/results story, shortened scroll distance and restrained transform/opacity motion.
3. **Mac:** bounded sticky Mac/iPhone navigation, four real window captures with a working picker, menu bar and pinned timer captures, shortcuts, Sparkle updates and desk mode.
4. **iCloud / iPhone:** personal-iCloud bridge; labelled HTML Live Activity, Dynamic Island and Mac clock-in notification illustration; visible earnings counter with pause, clock-out and restart; widgets and iOS 18+ Control Center details; three real iPhone captures.
5. **Companion:** scroll-pinned moods, three wardrobe pieces landing on the app's anchors, Cozy/Night/Studio rooms with furniture, and four HD armor/rank pairs. Controls also allow direct selection. Reduced motion and short viewports expose the complete gallery in document order.
6. **Features and promises:** CSV/puantaj as source of truth, rates over time, goals/pace, focus chime/radio, local data and narrowly described Live Activity relay, free/MIT/open source.
7. **Closing:** both platform actions and requirements again.

Every site string, accessible label and image description is supplied in EN/TR. Captures retain their original English app UI and sample data. “Canlı Etkinlik”, “Dinamik Ada” and “puantaj” are used in Turkish. Theme/language storage continues through the existing preferences mechanism.

## Generated assets

32 PNG files, **3,111,728 bytes total**, in `website/dist/assets/gallery/`. All were rendered offline on macOS with `python3 website/tools/gallery/render.py`; no AI imagery, external image service or new dependency.

| Assets | Construction |
| --- | --- |
| 7 wardrobe images, 628×628 | Base, three complete outfit stages and three transparent clothing layers. Original mascot/wardrobe PNGs, app anchor JSON, `WardrobeArt.overlays/composite`, including antenna removal. Playback uses base + layers; reduced motion uses the final composite. |
| 3 rooms, 1080×720 | Original Home room/furniture art, seven items per arrangement, `HomeSceneLayout.furnitureRect` and companion placement. |
| 4 armor images, 700×700 | Actual `ArmorHD`, `ArmorHDParts`, `ArmorHDPixels` renderers, Paladin rank materials 0/3/5/8. |
| 4 badges, 630×288 | Actual prestige/crown/rank SwiftUI art via `ImageRenderer`, fixed time, levels 1/225/375/600. |
| 14 mood frames, 314×314 | Seven angry and seven sleepy original app poses; existing hello-derived clip timing and `sprite.js` playback. |

`gallery/manifest.json` records source/output SHA-256 checksums and byte counts alongside the untouched legacy `image-manifest.json`. The Swift 6 renderer compiles only drawing/model code into a temporary directory, with a minimal bundle shim; it does not launch the app or read user data. `clips.js` is generated from `clips.json` to support offline file previews. The system AVIF export probe could not finalize in this sandbox, so new assets use PNG; existing AVIF clips remain active. Below-the-fold images are lazy-loaded and dimensioned.

## Page weight

Reproducible with `python3 website/tools/verify.py`. Decimal units, **uncompressed estimates, not network measurements**:

| Scope | Bytes | Approximate size |
| --- | ---: | ---: |
| Loaded HTML/CSS/JS inventory | 146,167 | 146 KB |
| Code + icon + complete hero AVIF clip | 477,018 | 477 KB |
| Newly generated PNGs on disk | 3,111,728 | 3.11 MB |
| All static images + every AVIF clip + new PNG moods, conservative upper bound | 8,234,240 | 8.23 MB |
| All PNG images/clips fallback, conservative upper bound | 13,967,042 | 13.97 MB |
| Entire dist directory, including unused legacy assets and alternative formats | 27,612,314 | 27.61 MB |

Hero estimate excludes any near-viewport lazy images a browser elects to fetch. Full-page bounds include hidden variants at original resolution, not just the selected responsive images. Browser caching, lazy loading and Netlify text compression reduce actual transfer; no live transfer size or Lighthouse score is claimed.

## Verification and limits

- `verify.py` passed: 166 used localized keys, matching EN/TR dictionaries, 54 local references, all sprite poses, PNG aspect ratios, generated output checksums, JavaScript syntax, exact Mac/beta links, no `dist/privacy/`.
- `git diff --check` and Python tool syntax checks passed.
- Native Chrome, offline review harness: **51/51 checks passed at each of 1440×900, 1024×800 and 375×812**. The suite tests seven sections in both languages and themes for overflow, four real-screen choices, live earnings/pause/end/restart, workday start/pause, five chapter selections, angry/sleepy frames, room/rank selection, image decoding and site runtime errors. No horizontal overflow or captured site runtime errors.
- Visual inspection included desktop hero/moods, 1024 px iPhone composition, and 375 px Turkish hero and armor gallery. Real outfit, room and HD armor outputs were also inspected directly.
- Chrome's actual `prefers-reduced-motion: reduce` emulation: **43/43 checks passed at 1440×900 and 375×812**, including all gallery chapters exposed and explicit sample-timer interaction. The harness reloads the iframe before each run so a previous timer restart cannot leak into the next run's initial state. DevTools must remain open for Chrome's emulation to stay active.
- Safari automation was unavailable in this session. Physical iPhone, touch behavior, Safari performance and a full screen-reader pass remain owner-review items; the 375 px evidence is a Chrome iframe viewport, not a physical device.
- This sandbox disallows binding a local HTTP port, so checks used `website/tools/review.py`, which inlines the current CSS/JS in an exact-size iframe and loads unchanged image files. Local-file security warnings can appear in Chrome; the site's runtime error collector remained empty. Production HTTP headers, relay behavior and `/privacy/` were not exercised.

## Owner browser review

Run the static check, then preview without deploying:

```sh
python3 website/tools/verify.py
python3 -m http.server 8310 --bind 127.0.0.1 --directory website/dist
```

Open `http://127.0.0.1:8310`. Alternative: `python3 website/tools/review.py`, then open `/tmp/clockin-review.html`. Regenerate the harness after edits.

- **1440 desktop:** review the whole story at natural scroll speed; Mac/iPhone sticky navigation should end with the platform chapters. Check clothing alignment and transitions into all rooms and rank pairs.
- **1024:** check headline wrapping, two-column Mac/iPhone content, screen-picker labels and sticky stage fit.
- **375 mobile:** check no sideways scrolling, CTA wrapping, full Live Activity controls, all companion text/controls and closing actions. Also try a short landscape viewport; the companion should become a normal-flow gallery.
- **Reduced motion:** emulate `prefers-reduced-motion: reduce` while DevTools remains open, reload and scroll. Robot decorations stop; all chapters, rooms and ranks are readable; the completed outfit is shown; timers run only after explicit interaction.
- **TR/EN + light/dark:** switch at the hero and mid-page, refresh to check persistence, inspect the translated mock controls and Turkish terms. Captures intentionally remain English.
- **Keyboard:** Tab through the skip link, preferences, CTAs, screenshot picker, timer controls and gallery choices. Check visible focus and that hidden chapter controls are skipped. Enter/Space should activate buttons.
- **Safari/Chrome:** inspect native scrolling and CPU smoothness; check the section entrances with and without CSS view-timeline support. Verify actual phone touch scrolling separately if available.
- **Links:** inspect the fixed Mac URL, public TestFlight beta and MIT/source links. `/privacy/` is expected only through the owner's deploy flow, not this bare local dist preview.

## Deployment boundary

Only the owner runs `website/tools/deploy` after review. It carries the Live Activity relay/functions/schedule and `/privacy/`. No `privacy/` folder was added to dist, and no direct Netlify upload was performed.

Mac: `https://github.com/ismailakdag/clockin/releases/download/macos-updates/Clockin.dmg`

iPhone beta: `https://testflight.apple.com/join/tr6kSDMN`
