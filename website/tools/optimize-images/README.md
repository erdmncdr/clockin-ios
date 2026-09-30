# Clockin image assets

Run from `website/`:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/clockin-image-module-cache swiftc -O tools/optimize-images/main.swift -o /tmp/clockin-optimize
/tmp/clockin-optimize
```

`--output-root /tmp/clockin-preview-new` stages a separate preview tree. `--png-only` generates and verifies only the four icons and three screenshot PNG fallbacks. The manifest explicitly marks that result as partial.

Image files are add-only. A rerun reads existing assets with matching manifest/source checksums and rechecks their decoded dimensions, transparency, and errors. New images are held in memory until all encodes pass. An existing image without matching provenance causes an error; it is never replaced. The JSON manifest may be refreshed. Use a fresh preview directory to try different qualities without overwriting images.

RGB error uses sRGB 8-bit straight channels at source pixels with alpha exactly 255. The percentile pools the three per-channel errors using the nearest-rank definition. Alpha error includes every pixel. Resized output is compared with the high-quality scaled source. Mascot candidates are tried in ascending order: 0.80, 0.85, 0.90, 0.94. If none meets all thresholds, the run fails. Screenshot quality is 0.82; its RGB errors are informational, and transparency is checked. PNG quality is not applicable.

Byte savings compare full-resolution mascot AVIFs plus 720w screenshot AVIFs against their unique original PNG sources. They exclude icons, alternative sizes and fallbacks. All generated-variant bytes are also reported. Originals stay on disk. Original preservation is verified using FNV-1a 64-bit checksums and exact byte equality.

## Current execution status

The optimized Swift build and PNG-only rerun pass. Seven PNG assets total 644,749 bytes. The three screenshot PNG fallbacks total 599,565 bytes versus 1,750,932 source bytes (65.76% smaller). All 74 source files remained byte-identical.

AVIF encoding is blocked in the current execution environment: ImageIO finalization returns false, writes zero bytes and emits `kIOSurfaceMethodSetCoreVideoBridgedKeys failed: 10000003`. A separate minimal probe reproduced this on the unscaled original `companion/frame1.png` at qualities 0.80, 0.90 and 0.94. No AVIF asset or `compare.png` has been produced, and AVIF quality thresholds or halos have not been verified. Run the full command in an environment where ImageIO AVIF encoding works, then inspect the generated contact sheet before integrating assets.
