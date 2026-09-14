# Clockin download website

Static Turkish product page, with the existing app icon, mascot and genuine macOS UI captures populated with synthetic demo data. Native application source and private operational notes are not included in this website.

Serve `dist/` with a static HTTP server. No install or build step is needed. Hosting is configured in `.openai/hosting.json`.

When a signed installer has been published and its anonymous download verified, set `DOWNLOAD_URL` in `dist/app.js` to that exact HTTPS DMG URL. Until then the download action explicitly explains that the package is being prepared.

Screenshots were captured from a separate app bundle and separate demo JSON. They do not contain the user's work records. The labels on the site are Turkish; application captures reflect its current English interface.

Images: 1755 × 3021 PNG exports from the actual app window at 150% interface size, rendered at 3× through AppKit. Each uses a distinct large-image filename to avoid stale low-resolution browser caches. Mobile image width is up to 420 CSS pixels with 20px side margins.

Validation: all three image selections checked in the browser at 390px viewport width, native image dimensions confirmed, no horizontal overflow. Desktop image dimensions and overflow checked at 1280px; no browser console errors. JavaScript syntax and local asset references checked.


## Interactive workday

The hero uses the original Clockin mascot frames and written greetings. “Birlikte bakalım” opens a scroll-driven three-scene demo: focus, break and daily results. Scene navigation also works by keyboard. This illustrative web demo is labeled separately from the genuine app screenshot gallery below it.

`journey.js` derives the scene and panel perspective from the page's native scroll position. No wheel interception or third-party animation runtime. The sample timer starts only after the visitor presses its button, uses monotonic elapsed time, and pauses when leaving the work scene. Its sample hourly rate is explicit; the final daily summary is independently labeled sample data. Nothing is recorded or sent to a service.

The OS reduced-motion preference disables sprite playback, perspective changes and scene transitions. Motion toggle buttons are not shown. Sprite and timer repaint intervals stop off-screen or in a hidden tab. A running sample timer retains elapsed time without background repaints.

Validation: actual browser interaction at 1280×850, 390×844 and 320×667. Scroll and scene navigation, timer start/pause/resume and frozen paused value, all three real screenshot selections and the download dialog checked. No horizontal overflow or console errors; all screenshots remain 1755px wide. Reduced-motion CSS and preference listener reviewed; OS preference emulation was not available in this browser.
