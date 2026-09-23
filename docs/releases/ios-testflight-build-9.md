# iOS TestFlight 0.1 (9)

Source: main at `58baf01c56bb4f80238c6d0daa70395c962c502b`, including PR #38. Build 9 is used because build 8 was already distributed from an earlier source revision.

## Verification

- All README-listed checks passed: 12 Mac suites and 24 iPhone suites.
- Generic iOS Simulator build and signed Release archive passed.
- App and widget versions are both 0.1 (9). The app contains all 8 notification CAF sounds and all 45 mascot PNGs.
- Strict recursive signature verification passed. Version and signing settings were supplied at build time; project settings were not changed.
- No new physical-device thermal or battery measurements were performed for this release.

## What to Test

English:
Rolling digits are back on Today without the battery cost, the home screen widget is centered with a larger companion, History's title and totals roll on every page, History pages cross-fade instead of sliding, the number pad closes when you tap elsewhere, imported timecards no longer show the provider's name, and the tab icons are clearer. Please check that the phone stays cool while a session runs.

Turkish:
Bugün ekranındaki rakamların yuvarlanma efekti pil tüketmeden geri geldi, ana ekran widget'ı ortalandı ve maskot büyüdü, History'de başlık ve toplamlar her sayfada yuvarlanıyor, sayfalar kaymak yerine yumuşakça değişiyor, sayı klavyesi boşluğa dokununca kapanıyor, içe aktarılan kayıtlarda sağlayıcı adı görünmüyor ve sekme simgeleri daha anlaşılır. Sayaç çalışırken telefonun ısınıp ısınmadığını kontrol edin.

## Distribution

- Upload succeeded on 17 September 2026 at 14:00 Europe/Istanbul. Processing completed.
- Build 0.1 (9) was added to Clockin Internal and Clockin Public Beta with the English and Turkish notes above.
- Beta review submission completed with automatic tester notifications enabled. Final live status in Clockin Public Beta > Builds: **Testing**. Both group assignments were verified on the build detail page.
