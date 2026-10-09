# 31: Website redesign (getclockin.netlify.app)

The user (Turkish, owner) wants the site to be clearly better before the next
deploy (Netlify bills every deploy, so this ships once). Work in `website/`
(static HTML/CSS/JS in `website/dist`, no build step, no new dependencies; EN/TR
via `locale.js`; light/dark via `preferences.js`). Keep the download link
`https://github.com/ismailakdag/clockin/releases/download/macos-updates/Clockin.dmg`
(the deploy tool checks it). Do not deploy; I review and deploy with
`website/tools/deploy` (it carries the Live Activity relay and /privacy/ — never
put a `privacy/` folder in dist).

## What the user asked

1. Separate macOS and iOS clearly on the site.
2. Show the mascot and its "products" clearly: outfits/wardrobe, rooms and
   furniture, level-up HD armor skins and rank badges, moods.
3. iOS: link to the public TestFlight beta
   `https://testflight.apple.com/join/tr6kSDMN` (label it as a beta).
4. Mascot animations on the site.
5. Use the scroll-driven, moving style (like the current workday demo) across the
   whole page, not only one section.
6. Present the app's features and promises as well as possible.

## Direction (record it in website/DESIGN.md, replacing the parts it changes)

Reference: Refero "Apple iPhone 18 Pro" — Midnight hardware gallery
(https://styles.refero.design/style/40be36d7-7fe6-4451-9f2d-7ceccfd43be8):
each section is a dark, museum-like stage for one precisely lit subject; huge
600-weight display headlines with tight negative tracking over black/charcoal
bands; 28 px media corners; near-invisible elevation (no drop shadows on media);
one accent reserved for actions; dense, quiet supporting copy. Our adaptation:
the subject is the Clockin robot and the real app, the action accent is Clockin
orange from the app icon (#f78a18) instead of Apple blue, light mode keeps the
existing porcelain palette. For the mascot world borrow one idea from Refero
"Slush" (https://styles.refero.design/style/8b6b547f-a357-4f1b-9842-4579c62dd42b):
wardrobe items behave like stickers that fly onto the mascot as you scroll — but
inside the dark gallery, not on pastel paper. System font stack (no web fonts).

## Page outline (adapt as you see fit, keep it coherent)

1. Hero: animated mascot (existing sprite clips), sculptural headline, two CTAs:
   "Download for Mac" (primary) and "Join the iPhone beta" (TestFlight). Small
   platform line (macOS 14+, Apple Silicon & Intel / iOS 17+, TestFlight).
2. The workday (existing interactive scroll demo) — keep, tighten.
3. Two platforms, one Clockin: a clear Mac | iPhone split (sticky toggle or two
   pinned chapters).
   - Mac: menu bar panel, pinned timer, desk mode, the window (existing real
     captures in `dist/assets/shot-*`), global shortcuts, Sparkle updates.
   - iPhone: Lock Screen Live Activity and Dynamic Island showing money going up
     with pause/clock-out, Home Screen widgets, Control Center controls, the
     "Clocked in on your Mac" notification; real captures in
     `dist/assets/phone-*`; build the Dynamic Island / Live Activity as an
     animated HTML/CSS mock that counts up while in view.
   - Between them: iCloud sync through the user's own iCloud, no account/server.
4. Meet your companion (scroll-pinned stage, the centrepiece):
   moods (happy, typing, sleeping, celebrating, angry when you slack), outfits
   flying on one by one (render composites from `Shared/Mascot/Frames` +
   `Shared/Mascot/Wardrobe` with the app's own anchors), rooms (cozy, night,
   studio with furniture from `Shared/Mascot/Home`), level-up: the HD armor
   skins and rank badges as a gallery that advances with scroll.
   Render these images offline with Swift tools in `website/tools/` reusing the
   app's renderers (`WardrobeArt`, `HomeSceneLayout`, `ArmorHD*`, level badge
   art) where possible; commit the generated AVIF/PNG (keep total page weight
   reasonable; lazy-load below the fold; `image-manifest.json` if you extend it).
5. Features and promises: timecard import that treats the CSV as the truth,
   rates that change over time, goals and pace, focus chime and radio, desk mode,
   privacy (pay/earnings/notes stay on device; Live Activity relay only gets a
   temporary push address; no account), free and open source (MIT, GitHub link).
6. Closing: both CTAs again.

## Motion rules

Scroll-driven with CSS scroll-driven animations where supported and a small
IntersectionObserver/rAF fallback; transforms and opacity only; no scroll
hijacking; sprites via the existing `sprite.js`; `prefers-reduced-motion` stops
decorative motion (content stays readable and in final state). Keep it smooth on
Mac Safari/Chrome: no large animated blur/filter stacks.

## Rules

English and Turkish for every string (the app says "puantaj", "Canlı Etkinlik",
"Dinamik Ada"). Real app captures stay real (sample data); label mocks honestly.
Accessible: alt text, focus states, contrast, keyboard. Mobile 375 px without
horizontal scroll. Update `website/README.md` (tools, assets) and
`website/DESIGN.md`. Write `docs/codex/31-website-redesign-result.md` with the
section list, assets made and how, page weight, and what I should check in a
browser (desktop 1440, 1024, mobile 375; reduced motion; TR/EN; light/dark).
