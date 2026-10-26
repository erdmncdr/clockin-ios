# 32 — Level-up share on the iPhone: review result

Date: 2026-10-26. Review only, from source and the SDK; no build or device run
in the review itself.

Findings, all applied in the same change:

1. The `performChanges` block inherited the main actor; it now carries
   `@Sendable` and captures only the PNG `Data`.
2. The Save/Copy row did not adapt to Turkish at large text: it is a
   `ViewThatFits` that stacks the two buttons when one line does not fit;
   labels stay one line and are not scaled down.
3. Repeated taps on Save started separate saves while the permission question
   was up: `isSaving` guards the save and disables the button meanwhile.
4. The Photos permission text was English only: `Clockin/InfoPlist.xcstrings`
   adds the Turkish wording.
5. `.restricted` got the "allow it in Settings" message although the user may
   not be able to change that: it has its own message now, pointing to Share
   and Copy.

Confirmed fine: add-only authorization and the plist key, the async
`performChanges` overload, `ImageRenderer` of the Canvas stage at 3x
(1080 × 1920 and 1080 × 1350), `.width(.expanded)` on iOS 17, the PNG
`Transferable` for `ShareLink`, `UIPasteboard` with `UTType.png`, the sheet's
control order, the Mac sheet unchanged, and the Turkish strings.

Not verified: the rendered PNGs on an iPhone (the `--level-share-render DIR`
fixture now exists in the iPhone debug build for that; CoreSimulator on this
Mac was out of date, so no simulator run was possible on the day).
