# Clockin website design

## Direction

Reference inspected on 2026-10-09: [Refero — Apple iPhone 18 Pro, Midnight hardware gallery](https://styles.refero.design/style/40be36d7-7fe6-4451-9f2d-7ceccfd43be8), including its embedded DESIGN.md. Use its exhibition-like composition: one subject per stage, black and charcoal bands, large 600-weight display type, tight tracking, compact supporting copy, 28 px media corners and no media drop shadows.

Secondary reference: [Refero — Slush](https://styles.refero.design/style/8b6b547f-a357-4f1b-9842-4579c62dd42b). Borrow only the playful sticker placement: wardrobe pieces arrive from different directions and land on the companion as the visitor scrolls. Keep the surrounding gallery dark. Neither reference supplies Clockin's artwork or product copy.

Clockin's adaptation makes its robot and actual application the subjects. The one action accent is app-icon orange `#f78a18`, with dark button text for contrast. No external fonts, dependencies, videos or generic decorative illustrations.

## Color, type and surfaces

- Light: porcelain `#f5f6f8`, alternate surface `#eceef1`, ink `#20242b`, secondary `#626873`, border `#d9dde3`.
- Dark: near-black `#08090b`, charcoal `#111316`, raised controls `#1b1d21`, text `#f5f6f8`, secondary `#a1a6b0`, border `#2c2f35`.
- Companion and desk-mode exhibitions retain their dark stages in both themes. Cyan stays inside mascot artwork; mint/amber communicate the sample timer's actual running/paused state.
- Native system font stack. Hero 60–102 px; section titles 44–80 px; gallery titles 42–65 px; body 15–19 px; captions 11–13 px. Headings use weight 600 and negative tracking. Mobile scales titles to roughly 39–53 px.
- 1180 px maximum content width, 48/32/20 px responsive side gutters, 60–130 px section spacing. Media corners are 28 px on desktop, smaller for tiny mobile captures. No animated blur/filter stacks and no media shadows.

## Composition

1. Hero: asymmetric headline and animated robot, both Mac download and iPhone public beta actions, platform requirements, and a workday entry.
2. Workday: the original focus/break/results interaction in a tighter native-scroll chapter. Clearly labelled sample data; clock state is independent of the scene's colors.
3. Platforms: large introduction, then a compact sticky Mac/iPhone anchor switch bounded by those chapters. Mac gets the real window's four screen choices, menu bar, pinned timer, shortcuts, Sparkle updates and desk mode. A quiet iCloud bridge leads to iPhone.
4. iPhone: labelled HTML Live Activity / Dynamic Island illustration, foreground-only sample earnings and functional pause/clock-out/restart controls. Home Screen widgets, iOS 18+ Control Center controls and the Mac clock-in notification are explained. Three unaltered real app captures follow. The public TestFlight link is explicitly a beta.
5. Companion: one sticky exhibition with four chapters—moods, wardrobe, rooms, HD armor and ranks. Moods use `sprite.js`; three clothing layers land at app-authored anchors; rooms advance through Cozy/Night/Studio; four armor/badge pairs advance with scroll. Every chapter and variant has a keyboard-accessible control.
6. Practical details: editorial rows for timecard import, dated rates, goals/pace, chime/radio; then privacy and free/MIT source promises.
7. Closing: repeat both actions and platform requirements.

No pricing/testimonial/logo wall. Gallery art is generated from application source; it is not claimed to be an app screenshot. Real captures retain sample records and their original English interface.

## Motion and fallback

Native scrolling only. CSS view timelines move/fade section entrances when available. The small IntersectionObserver/rAF fallback measures only nearby entrance elements and writes transforms/opacity. The pinned companion stage and workday derive their chapter from scroll position; neither intercepts wheel/touch input. Selection buttons use native scroll positions and real button state.

Sprites stop off-screen, in hidden tabs and under reduced motion. Existing clips are reused; angry/sleepy clips use the app's derived hello timings. The Live Activity counter runs only while visible in a foreground tab, at a stated sample rate. It never calls the relay or saves a session.

Reduced motion removes decorative transitions and sprite playback. The companion expands into normal document flow with the complete outfit, all three rooms and all four armor/rank pairs visible. Short viewports below 650 px also get this readable layout. Reduced-motion visitors can explicitly run either example timer. All section entrances are in their final state. Theme and language changes are immediate.

## Accessibility and localization

EN defaults independently of browser language; TR translates visible copy, page metadata, controls, image descriptions and live sample states using `locale.js`. Use “puantaj”, “Canlı Etkinlik” and “Dinamik Ada”. Both platforms' names and TestFlight are proper names. Amounts remain TRY; only number formatting changes.

Language and light/dark preferences retain the existing storage behavior. Theme follows the OS until the visitor makes a choice. Orange focus outlines, semantic links/buttons, skip link, labelled groups, explicit active states and inert hidden chapters preserve keyboard navigation. No earnings counter is a continuously announcing live region; only explicit clock-out feedback uses `role=status`.

## Distribution boundaries

The Mac URL stays exactly `https://github.com/ismailakdag/clockin/releases/download/macos-updates/Clockin.dmg`. iPhone uses `https://testflight.apple.com/join/tr6kSDMN`. `/privacy/` is supplied by the relay-aware deploy tool; never create `dist/privacy/`. Only the owner deploys using `website/tools/deploy`. Do not use a bare dist ZIP, direct Netlify upload or Sites deployment.
