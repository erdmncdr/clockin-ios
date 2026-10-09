# Clockin product website

Static HTML/CSS/JavaScript in `dist/`. No build step, package install or runtime dependency. English/Turkish copy lives in `locale.js`; `preferences.js` applies the existing local language and OS/saved appearance preferences.

Production: https://getclockin.netlify.app/. This redesign is local and **has not been deployed**. See [DESIGN.md](DESIGN.md) for the visual direction and [redesign result](../docs/codex/31-website-redesign-result.md) for review notes.

## Preview and checks

From the repository root:

```sh
python3 -m http.server 8310 --bind 127.0.0.1 --directory website/dist
python3 website/tools/verify.py
```

Open `http://127.0.0.1:8310`. If the environment cannot bind a local port, open `website/dist/index.html` directly, or make the offline review harness:

```sh
python3 website/tools/review.py
```

Open `/tmp/clockin-review.html`. Its iframe has an exact 1440×900, 1024×800 or 375×812 viewport; the outer page scales it to fit the screen. It inlines the current site CSS/JS and loads the unchanged local images. The review buttons select sections, language and theme. “Run browser checks” exercises overflow in both languages/themes, real-screen selections, the sample timers and companion navigation; its visible JSON lists pass/fail results. To test reduced motion, enable the browser's `prefers-reduced-motion: reduce` emulation (or the OS setting) and run again. Re-run `review.py` and reload after changing site files. The harness stays outside `dist/`.

`verify.py` checks local links, EN/TR parity, image aspect ratios, sprite frames, generated-asset checksums, JavaScript syntax, exact download/beta URLs and absence of `dist/privacy/`. It reports uncompressed payload estimates, not measured network transfer or a Lighthouse score. It needs Python 3 and an existing Node executable for syntax checks.

## Assets and offline generation

- **Mac captures:** `dist/assets/shot-*.png`, with original and `-small` responsive candidates. Today, History, Progress and Settings are 1920×1720; small versions are 1120 wide. Menu bar: 640×632; pinned timer: 640×224; desk: 1920×1205. These files were preserved unchanged.
- **iPhone captures:** `phone-today.png`, `phone-history.png`, `phone-progress.png`, 690×1500. Original app captures with synthetic data, unchanged. Their English UI remains part of the capture in either site language.
- **Existing sprite clips:** `assets/companion/clips.json` is the source manifest; `clips.js` is its generated classic-script equivalent so file previews also work without a fetch/CORS requirement. `sprite.js` retains AVIF detection, PNG fallback, decoded-frame caching, original clips and compositor hops/sway.
- **New gallery PNGs:** `assets/gallery/`, generated from the app's source by `tools/gallery/main.swift` and the standard-library Python compile runner. No image-generation service or new dependency is used.

```sh
python3 website/tools/gallery/render.py
```

Requires macOS, Xcode's Swift compiler and system frameworks. The runner compiles Swift 6 into a temporary directory; it does not build/launch the app or read user preferences/data. It copies the drawing portion of `WardrobeArt.swift` verbatim, excluding the runtime cache actor, and compiles the shared wardrobe/geometry/home/HD armor code and the actual prestige badge art. A tiny `Bundle.app` shim uses the tool's bundle, so it does not access the app's shared defaults.

Generated gallery:

| Files | Source and method |
| --- | --- |
| `outfit-base`, `outfit-1…3`, `layer-cap`, `layer-round-glasses`, `layer-scarf` | `Frames/h01.png`, `Wardrobe/*.png`, `mascot-anchors.json`, `wardrobe-sprites.json`; `WardrobeArt.overlays/composite` and antenna removal. 628×628. Layers use the exact final canvas, allowing transform-only assembly. |
| `room-cozy`, `room-night`, `room-studio` | `Home/home-items.json`, original room/furniture PNGs, `HomeSceneLayout.furnitureRect` and companion placement. 1080×720. Each has seven furniture/decor items. |
| `armor-0…3` | `ArmorHD`, `ArmorHDParts`, `ArmorHDPixels`; Paladin materials for ranks 0/3/5/8. 700×700. |
| `rank-0…3` | `LevelPrestige`, `PrestigeForge`, `RankMaterial`, `ForgedCrown`, `LevelPrestigeViews`, `RankSignatures` with fixed time; SwiftUI `ImageRenderer`. 630×288. Badge levels 1/225/375/600. |
| `a01/02/06/07/08/10/11`, `z01/02/06/07/08/10/11` | App angry/sleepy frames; 314×314. `clips.json` derives their events from hello, as the app does. |

`assets/gallery/manifest.json` records source/output SHA-256 hashes and output byte counts; it extends provenance alongside the unchanged legacy `assets/image-manifest.json`. `outfit-1/2` are reproducible inspection artifacts; scroll playback uses the base/layers, and reduced motion uses `outfit-3`. New exports use PNG: an ImageIO AVIF probe failed to finalize in this sandbox. Existing AVIFs remain in use. Below-the-fold images are lazy and have explicit dimensions; no imagery is served by third parties.

The historical screenshot tool is `bash website/tools/screenshots/run`; inspect its checkout/build assumptions before retaking screenshots. It uses an isolated demo app and sample data. This redesign does not retake screenshots or touch the user's app data.

## Behavior

`journey.js` preserves the focus/break/results interactive workday and resets each scene's example on entry. `gallery.js` coordinates nearby section entrances, scroll-pinned companion chapters and the foreground-only iPhone example. CSS view timelines handle entrances where supported; IntersectionObserver/rAF provides the fallback. No scroll hijacking, animation package, animated blur or external fonts.

Reduced motion stops decorative playback, displays the complete companion gallery in normal reading order, and leaves explicit sample-timer interaction available. Viewports below 650 px high also unpin the companion so content does not become clipped. `sprite.js` cancels active sway/hops immediately when stopped and removes settled timeout abort listeners.

The Live Activity and Dynamic Island are **labelled HTML illustrations**, not captures or connections to the app. The illustration starts at 1h24m / TRY 420 at TRY 300/hour; pause freezes it; clock-out ends only the example; try-again restarts it. No session is saved or sent anywhere. Control Center availability is stated as iOS 18+; the iPhone beta requires iOS 17+.

## Deployment — owner only

Do not deploy for this task. Netlify bills every deploy. The owner reviews and runs:

```sh
python3 website/tools/deploy --dry-run
python3 website/tools/deploy
```

`--dry-run` reads/authenticates the live site; it is not an offline validation command. The tool carries the existing Live Activity relay/functions/schedule and `/privacy/` into the deployment and verifies them. **Never upload bare `dist/`, a dist ZIP, or use another deployment mechanism. Never create a `privacy/` folder in dist.** The old README's manual-upload advice is superseded.

All Mac download actions must point to:
`https://github.com/ismailakdag/clockin/releases/download/macos-updates/Clockin.dmg`

The fixed release asset is updated by the Mac release flow without redeploying the site. Never switch to GitHub's shared `latest` asset, since that repository also ships iPhone builds. The public iPhone beta is labelled and links to `https://testflight.apple.com/join/tr6kSDMN`. Footer/source links retain the public MIT repository.
