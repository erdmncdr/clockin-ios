# iOS TestFlight 0.2 (2)

Source: `ios/wardrobe` at `37acc79633924e90034e3107f5cd22878994eca6`, built in a clean worktree without merging to main or changing project version/signing settings. That branch was removed once 0.2 (23) replaced this work on main; the commit is kept reachable by the `archive/companion-3d-prototype` tag.

## Verification

- All README-listed check groups passed: 13 Mac and 29 iPhone. The Mac panel-host focus check failed on the first run and passed all 31 assertions when rerun alone after the other builds finished; no source change was made.
- Generic iOS Simulator build and signed Release archive passed. App and widget both report 0.2 (2); strict recursive signature verification passed.
- All 47 wardrobe, home and colorway resources are present in the app; JSON catalogs match source. PNGs are processed during packaging.
- No additional physical-device session was performed for this distribution.

## Distribution

- Uploaded successfully on 18 September 2026 at 16:48 Europe/Istanbul with automatic build renumbering disabled.
- Processing completed. Both Clockin Internal and Clockin Public Beta were added with the English and Turkish notes below and automatic tester notifications enabled.
- Beta review submission completed; Both Clockin Internal and Clockin Public Beta showed **Testing**, verified on their build lists. Build record: `bd9a1634-5d44-4cd5-96ee-915b9662767a`.

## What to Test

English:
Your companion now has a wardrobe and a home. Earn focus coins by working, then dress it up with hats, glasses, scarves, capes and more, pick a color, and furnish its hut. Tap the companion on Today to open it. It also celebrates level ups, badges and milestones, and gets tired or proud depending on how your work is going.

Turkish:
Maskotunun artık bir gardırobu ve evi var. Çalıştıkça odak jetonu kazan, şapka, gözlük, atkı, pelerin ve daha fazlasıyla giydir, rengini seç, kulübesini döşe. Açmak için Bugün ekranındaki maskota dokun. Seviye atlayınca, rozet kazanınca ve hedeflerde kutluyor, çalışmana göre yorgun ya da gururlu oluyor.
