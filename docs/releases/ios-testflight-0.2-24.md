# iOS TestFlight 0.2 (24)

Source: `main` at `ecdb9e72fec443b2159b16ac77575b6f24b94a8d`, archived directly. Main is
the release baseline now, so there is no separate frozen worktree for this build.

A tester's crash report for 0.2 (23) symbolicated against that build's dSYM to the
notification delegate: the Objective-C completion block generated for
`userNotificationCenter(_:didReceive:)` ran on a Swift cooperative thread, and UIKit
asserts inside it because it expects the main thread. Writing the delegate as
`nonisolated async` is what put the completion off the main thread. The completion
handler form reads only sendable values from the notification, decides on the main actor
and calls the block there.

The chime queue changed with it. Twenty notifications cover only 3 hours 20 minutes at
the default ten minute interval and nothing refills the queue unless the app is brought
to the foreground, so a long session in a pocket went silent; forty five cover 7.5 hours,
within the 64 pending iOS allows once the reminder and nudges are reserved. Changing the
sound left queued chimes ringing with the old one because reconciliation compared dates
alone. All chimes now share one thread identifier and collapse into a single stack, and
delivered chimes are cleared when the app comes forward.

## Verification

- All 29 check groups passed using the exact `iOS/README.md` commands, 5,196 assertions.
  The largest are wardrobe 2,795, companion2 694, earnings 284, mascot 270, rolling 197
  and insights 148. The `feedback` group had been red since before 0.2 (23) on a stale
  assertion about the handoff minute and was corrected first.
- The Release archive finished with no errors and no warnings. An earlier attempt warned
  that a main actor-isolated constant could not be read from the delivered-notification
  callback; that was fixed before this archive.
- App and widget extension both report `0.2` and `24`. Automatic version and build
  renumbering was disabled for the upload.
- The eight `clockin-*.caf` chime sounds sit at the app bundle root, where a notification
  looks for them by bare filename. No `.glb`, `.usdz` or `.scn` files are in the bundle.
- Strict deep signature verification passed: valid on disk and satisfies its Designated
  Requirement.
- No physical-device session was performed for this distribution. The original crash
  needed a real device and could not be re-triggered in the simulator, so the fix rests
  on the symbolicated frame and on the completion block now being called on the main
  actor by construction.

## Release

Uploaded on 2026-09-22 at 15:07 Europe/Istanbul.
Build ID: `58454d43-7e11-485c-9054-13d59c9b9139`.
Processing completed. English and Turkish notes saved. Both existing groups were
selected with automatic tester notifications enabled, and beta review was submitted.
Clockin Internal and Clockin Public Beta were both reported **Testing** on their own
build lists on 2026-09-22.

## What to Test

English:

Fixes a crash that could close Clockin when a focus chime notification arrived or was
tapped. Focus chimes no longer stop after about three and a half hours, so a long session
keeps chiming while your phone is in your pocket. Changing the chime sound now also
changes the chimes already waiting to play. Chime notifications collapse into a single
group instead of filling Notification Center, and they are cleared when you open Clockin.

Turkish:

Odak çanı bildirimi geldiğinde ya da ona dokunduğunda Clockin'i kapatabilen bir çökme
giderildi. Odak çanları artık yaklaşık üç buçuk saat sonra susmuyor; telefon cebindeyken
uzun mesaide de çalmaya devam ediyor. Çan sesini değiştirdiğinde sırada bekleyen çanlar
da yeni sesle çalıyor. Çan bildirimleri Bildirim Merkezi'ni doldurmak yerine tek bir
grupta toplanıyor ve Clockin'i açtığında temizleniyor.
