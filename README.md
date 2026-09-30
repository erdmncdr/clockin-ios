# Clockin download website

Static English/Turkish product page, with the existing app icon, mascot and genuine macOS UI captures populated with synthetic demo data. Native application source and private operational notes are not included in this website.

Serve `dist/` with a static HTTP server. No install or build step is needed.

## Hosting

Netlify is the active hosting destination. `netlify.toml` sets the publish directory to `dist`; leave the build command empty. For a manual deployment, upload only the `dist/` folder (or a ZIP of its contents with `index.html` at the archive root). Future manual updates must target the same Netlify project's Deploys page. Git-based automatic deployment is not configured yet.

The existing Sites deployment remains live; its configuration is retained in `.openai/hosting.json`. Publish future website changes to Netlify, not to Sites by default.

Production URL: https://getclockin.netlify.app/. Netlify project ID: `406e1766-2c8b-4b61-99a1-f4736b8c512a`, team `erdmncdr`. Initial published deploy: `6aa7fd4d8b185570c5388b7c` (2026-09-14). Deploy updates through https://app.netlify.com/projects/getclockin/deploys. The user selected `getclockin` after Netlify reported `clockin` and `clockinapp` unavailable. The separate existing `erdoderdo` project was not modified.

Deployment validation: all 24 public files returned HTTP 200 anonymously; JavaScript, CSS and PNG bytes matched the local originals. The live page rendered and English/Turkish switching worked without browser console errors.

Downloads link to the fixed GitHub asset https://github.com/ismailakdag/clockin/releases/download/macos-updates/Clockin.dmg (attachment, `application/octet-stream`), which `scripts/publish-mac.sh` replaces with every Mac release. The site itself hosts no installer and has no `_headers` file, so a Mac release does not deploy the site; Netlify bills every deploy and every byte it serves. Deploy only for site changes, with `python3 scripts/publish-mac-release.py website` from the repository. Do not use GitHub's shared latest-release URL because the repository also ships iPhone builds. In-app updates still come through the signed `macos-updates/appcast.xml` feed. The footer links to the public MIT-licensed source repository.

Until 1.1.6 the DMG was served from `dist/downloads/` on Netlify and every release redeployed the site.

2026-09-15 download fix: direct Netlify download returned HTTP 200 without redirects, attachment headers and the correct SHA-256. Clicking the live hero link in desktop Chrome completed a 12.1 MB download while keeping the website open. The download hover greeting remained functional; the refreshed live page reported no console errors. This check does not cover every embedded mobile browser.

Screenshots were captured from a separate app bundle and separate demo JSON. They do not contain the user's work records. The site labels and companion copy switch between English and Turkish; genuine application captures retain the app’s English interface.

Images: 1755 × 3021 PNG exports from the actual app window at 150% interface size, rendered at 3× through AppKit. Each uses a distinct large-image filename to avoid stale low-resolution browser caches. Mobile image width is up to 420 CSS pixels with 20px side margins.

Validation: all three image selections checked in the browser at 390px viewport width, native image dimensions confirmed, no horizontal overflow. Desktop image dimensions and overflow checked at 1280px; no browser console errors. JavaScript syntax and local asset references checked.


## Interactive workday

The hero uses the original Clockin mascot frames and written greetings. “Birlikte bakalım” opens a scroll-driven three-scene demo: focus, break and daily results. Scene navigation also works by keyboard. This illustrative web demo is labeled separately from the genuine app screenshot gallery below it.

`journey.js` derives the scene and panel perspective from the page's native scroll position. No wheel interception or third-party animation runtime. The sample timer starts only after the visitor presses its button, uses monotonic elapsed time, and pauses when entering the break or results scene. Every scene entry resets its example: focus starts at zero, break starts paused at one hour, and results show the fixed sample day. Resuming advances the current scene’s timer until the next scene change. Timer colors and the mascot follow the running/paused state in either scene. Its sample hourly rate is explicit; the final daily summary is independently labeled sample data. Nothing is recorded or sent to a service.

The OS reduced-motion preference disables sprite playback, perspective changes and scene transitions. Motion toggle buttons are not shown. Sprite and timer repaint intervals stop off-screen or in a hidden tab. A running sample timer retains elapsed time without background repaints.

Validation: actual browser interaction at 1280×850, 390×844 and 320×667. Scroll and scene navigation, timer start/pause/resume and frozen paused value, all three real screenshot selections and the download dialog checked. No horizontal overflow or console errors; all screenshots remain 1755px wide. Reduced-motion CSS and preference listener reviewed; OS preference emulation was not available in this browser.

## Language and appearance

English is the default language, independent of browser locale. EN/TR changes all page copy, dynamic messages, metadata and accessibility labels. An explicit language choice is saved locally. Light/dark appearance initially follows the OS; the header toggle saves an explicit override. Storage failures do not prevent the site from working. Appearance is applied before the first paint. Currency remains TRY in both languages; only formatting changes, not values.

Play/pause controls use consistent inline SVG strokes. No movement-toggle buttons are reintroduced.

Validation for language/theme update: desktop 1280×850 and phone 320×667, both themes, English/Turkish and persistence after reload; focus start/pause, one-hour break reset and resume with green/amber colors and matching mascot. Sample earnings, scene navigation, localized image selector and download dialog checked.

Scene reset validation: forward/backward scroll and scene navigation restore timer, button, mascot and floating note together. Staying within the same scene does not reset a running timer.
