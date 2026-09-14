# Clockin download website

Static Turkish product page, with the existing app icon, mascot and genuine macOS UI captures populated with synthetic demo data. Native application source and private operational notes are not included in this website.

Serve `dist/` with a static HTTP server. No install or build step is needed. Hosting is configured in `.openai/hosting.json`.

When a signed installer has been published and its anonymous download verified, set `DOWNLOAD_URL` in `dist/app.js` to that exact HTTPS DMG URL. Until then the download action explicitly explains that the package is being prepared.

Screenshots were captured from a separate app bundle and separate demo JSON. They do not contain the user's work records. The labels on the site are Turkish; application captures reflect its current English interface.

Images: 1755 × 3021 PNG exports from the actual app window at 150% interface size, rendered at 3× through AppKit. Each uses a distinct large-image filename to avoid stale low-resolution browser caches. Mobile image width is up to 420 CSS pixels with 20px side margins.

Validation: all three image selections checked in the browser at 390px viewport width, native image dimensions confirmed, no horizontal overflow. Desktop image dimensions and overflow checked at 1280px; no browser console errors. JavaScript syntax and local asset references checked.


## Interactive companion

The hero greets visitors, cycles through the app's original typing, coffee and celebration artwork, and responds to clicks and download-button hover/focus. Speech is written text. “Birlikte bakalım” opens a three-step tour synchronized with the real screenshot gallery. A pause button, reduced-motion preference, tab visibility and on-screen visibility gate automatic animation. The tour can be closed or finished; focus returns to the active gallery selector. No external service or audio is used.

Companion validation: mobile 390px walkthrough (all three steps, finish and close), click-to-change pose, pause/resume frame changes, focus restoration and no horizontal overflow or console errors.
