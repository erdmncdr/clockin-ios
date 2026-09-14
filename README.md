# Clockin download website

Static Turkish product page, with the existing app icon, mascot and genuine macOS UI captures populated with synthetic demo data. Native application source and private operational notes are not included in this website.

Serve `dist/` with a static HTTP server. No install or build step is needed. Hosting is configured in `.openai/hosting.json`.

When a signed installer has been published and its anonymous download verified, set `DOWNLOAD_URL` in `dist/app.js` to that exact HTTPS DMG URL. Until then the download action explicitly explains that the package is being prepared.

Screenshots were captured from a separate app bundle and separate demo JSON. They do not contain the user's work records. The labels on the site are Turkish; application captures reflect its current English interface.

Validation: JavaScript syntax and local HTML asset references checked. Browser interaction and viewport testing has not yet been performed.
