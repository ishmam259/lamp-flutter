# LaMP Flutter — project notes for future Claude

## What this project is

A Flutter port of the LaMP (Last Mile Pharmacy) consortium receivables ledger demo.
The TypeScript reference at `../LaMP` is authoritative — `README.md` says so.

The demo's central claim is "the ledger, not the UI, is the system of record."
**Start at `lib/core/world/queries.dart`.** Every screen filters through it, and
the rule it exists to enforce is that a screen must not offer an action the
chaincode is going to refuse.

## Design system (authoritative — read before touching any UI)

Rules: `docs/DESIGN_SYSTEM.md`. Enforced by `test/design_lint_test.dart`.

- Colour only via `context.lamp.*` (`lib/core/constants/palette.dart`). The brand colour is near-white in dark themes and `#0B5D42` in light themes. Mint `#3DDC97` = `verified` only. There are three states (confirmed/pending/refused) and no chain blue.
- Type only via `LaMPType.*` (`typography.dart`): Anek Latin/Bangla sans + IBM Plex Mono for money, ids and labels. Weights 400/500/600, minimum size 11.
- Spacing is `Gap.*`, radii are `LaMPRadius.*`, and icons are `IconSize.*`.
- Seat chrome: `LumaAppBar` (mark in the leading slot) + `LampBlockPip` + `LampSeatMenu` (`lib/widgets/ui/lamp_ledger_ui.dart`). People sign in (`lib/core/auth/`, `features/sign_in/`) and land on their own seat; there is no seat picker. Ledger writes use `LampReceiptCard`, counts use `LampTickBar`, and state uses `LampStateDot`.
- Logo: `LampMark` (brightness-aware assets `logo-mark-dark/light/white.png`).
- **This is a real app for real users, not a demo.** Copy is plain language: no chaincode names, MSP ids, tx ids or raw errors on screen — use `LedgerLabels` (`lib/core/constants/ledger_labels.dart`). Testing tools sit behind `kDemoTools` (`app_mode.dart`), off in release builds. See `docs/DESIGN_SYSTEM.md` §3a.
- A new screen follows the checklist in `docs/DESIGN_SYSTEM.md` §6.

## Sign-in and registration

People sign in with **Google** or a **phone number + 6-digit code**, then, if new, register
by choosing a seat (role, and which pharmacy / delivery round / bank). Firebase does it; setup
is in `docs/FIREBASE_SETUP.md`.

- `lib/core/auth/auth_service.dart` is the interface. `firebase_auth_service.dart` is the real
  one (Firebase Auth + Firestore `users/{uid}`, `claims/{id}`); `local_auth_service.dart` is a
  stand-in for tests and offline debug work (accepts code `123456`, keeps data on the device).
- `AuthController` turns the signed-in person plus their profile into the `Account` the shell
  shows. `main.dart` reads only `auth.current`. The PIN sign-in is gone.
- `auth_bootstrap.dart` starts Firebase. In a **debug** build with no `firebase_options.dart`
  configured it falls back to the local stand-in; a **release** build never does.
- `lib/firebase_options.dart` and `android/app/google-services.json` are generated for the
  Firebase project `lamp-bcolbd` (Android only; iOS, web and desktop are not configured).
  The Google Services Gradle plugin is applied only when `google-services.json` exists.
- Android build notes: the Kotlin Gradle plugin is 2.3.0 (the Firebase libraries need it), so
  `kotlinOptions` is gone in favour of `kotlin { compilerOptions }`; Gradle heap is 4G and the
  Kotlin daemon 2G in `android/gradle.properties`, because 8G ran a 16 GB machine out of memory.
- Rules: `firestore.rules`. A pharmacy or round profile can only be written together with its
  `claims/` document, and a claim is written once, so the first person keeps the seat.
- Known limits: anyone can register as any role; seats still read seeded data
  (`SeedData.pharmacies[0]` etc.), so a new pharmacy sees seeded invoices.
- Tests use `LocalAuthService`: `test/auth_test.dart`, `test/widget_test.dart`.

## Toolchain (read this before running anything)

The current development machine uses a normal install; nothing is copied into
the project.

| Tool        | Where                                                        |
| ----------- | ------------------------------------------------------------ |
| Flutter SDK | `C:\Users\16IRL8\flutter` (3.35.7 stable, Dart 3.9.2), on PATH |
| JDK 21      | Android Studio's bundled JBR: `C:\Program Files\Android\Android Studio\jbr` |
| Android SDK | `C:\Users\16IRL8\AppData\Local\Android\sdk` (platform 36.1, build-tools 36.1.0) |
| adb         | `C:\Users\16IRL8\AppData\Local\Android\sdk\platform-tools\adb.exe` |

`android/local.properties` is machine-specific and not committed. On this
machine it holds:

```
flutter.sdk=C:\Users\16IRL8\flutter
sdk.dir=C:\Users\16IRL8\AppData\Local\Android\sdk
```

`flutter doctor` finds the JDK through Android Studio, so no `JAVA_HOME` is
needed.

**The other machine** (`D:\VSCODE\Blockchain Olympiad\lamp-flutter`, user
`Lenovo`, Flutter 3.47) used to carry the SDKs inside the project as `.flutter/`,
`.jdk/` and `.android-sdk/`. Those were deleted; it now uses global scoop
installs, and three things are needed to build there:

- **Tools:** Flutter `C:\Users\Lenovo\scoop\apps\flutter\current`, JDK 21
  `...\scoop\apps\oraclejdk-lts\current`, Android SDK
  `...\scoop\apps\android-clt\current` (`ANDROID_HOME` set).
- **JDK:** run `flutter config --jdk-dir="C:\Users\Lenovo\scoop\apps\oraclejdk-lts\current"`.
  Otherwise Flutter picks Android Studio's bundled Java 25, which Gradle 8.14
  rejects.
- **AGP check:** pass `--android-skip-build-dependency-validation`. AGP is pinned
  to 8.9.1 and Flutter 3.47 wants 8.11.1 or newer. Studio's `main.dart` run
  configuration carries the flag.

Day-to-day work there is on the `lamp_pixel` emulator (Pixel 7 skin, 1080x2400,
API 35). The emulator's camera is a virtual room and cannot scan a laptop
screen, so real scanning is checked on the wireless phone.

## How to run

```bash
flutter analyze        # must be clean
flutter test           # 152 tests, all passing (breakdown under "Tests reference")
flutter run -d chrome  # quick smoke test in a browser
```

### On a phone (wireless debugging)

The test phone is a Samsung SM-S721B connected over **wireless debugging**. It
shows up in `flutter devices` as `SM S721B (wireless)`. It drops off whenever
the phone's Wi-Fi sleeps; re-enable *Developer options → Wireless debugging*
and it reappears.

`flutter run` sometimes loses the connection during install over Wi-Fi. What
works reliably is to install with adb, launch the app, and attach:

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.lamp.bcolbd.lamp_flutter/.MainActivity
flutter attach -d <device id from flutter devices>
```

Screenshots from the phone: `adb exec-out screencap -p > shot.png`.

### Release APK (for sideloading)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. It's signed with the
debug keystore (`android/app/build.gradle.kts`) for sideload convenience;
replace that with a real signing config for the Play Store. A release build
hides the testing tools (`kDemoTools`, see the design section).

Piping the build through `tail` swallows Gradle's exit code, so check for the
`Built build\app\outputs...` line rather than trusting `$?`.

### Launcher icons

Masters are in `assets/app_icon/` (not bundled). Regenerate with
`dart run flutter_launcher_icons`, then **revert**
`ios/Runner.xcodeproj/project.pbxproj`, which the tool corrupts
(`…SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon`). The web icons are copied from the
masters by hand.

## Non-obvious build knobs (and why)

These are the things that took the most time to figure out. Do not "simplify"
them without understanding the failure mode. They were found on the earlier
D:-drive machine with Flutter 3.47; on this machine (Flutter 3.35.7) the
current settings build without `--android-skip-build-dependency-validation`,
but leave the other knobs alone.

### 1. `kotlin.incremental=false` in `android/gradle.properties`

The Pub cache lives on `C:\` (default user-profile location) while the project
is on `D:\`. Kotlin's incremental compiler refuses to track files across drive
roots and crashes during `compileReleaseKotlin` with:

```
IllegalArgumentException: this and base files have different roots:
  C:\Users\Lenovo\AppData\Local\Pub\Cache\hosted\pub.dev\shared_preferences_android-2.4.23\...
  D:\VSCODE\Blockchain Olympiad\lamp-flutter\android
```

Disabling incremental compilation forces full rebuilds but unblocks the build.
If you move the Pub cache to the same drive as the project
(`PUB_CACHE=D:\...`), this can be turned back on.

### 2. `gradle-wrapper.properties` pinned to 8.14

The original `8.12-all.zip` was rejected by Flutter 3.47 ("minimum supported
version of 8.14.0"). Bumped to `gradle-8.14-all.zip`. If you bump Flutter,
check the wrapper compatibility table again.

### 3. `--android-skip-build-dependency-validation`

The project pins `com.android.application` 8.9.1 in `android/settings.gradle.kts`,
which is below Flutter 3.47's minimum of 8.11.1. Upgrading AGP would require
coordinated changes in `build.gradle.kts` files (the project already opts out
of `android.newDsl=false`, which is part of the AGP-9 migration). The bypass
flag keeps the existing AGP working without the validation abort.

If you do upgrade AGP, also delete `kotlin.incremental=false` and the
`--android-skip-build-dependency-validation` flag — both were escape hatches
around the older toolchain.

### 4. `android/gradle.properties` has `android.newDsl=false`

Required for AGP 8.9.1 to read the project's `build.gradle.kts` files (which
were authored against the older DSL). Don't remove without upgrading AGP first.

## The state-derivation pass (most recent session)

`Bug report/Report 01.md` listed five defects. They were one defect: **the app
rendered a single hard-coded `demoTokenId` where the TypeScript derives every
list from ledger state.** Nothing could be filtered because there was nothing to
filter — one consignment, one invoice, one stop on the route.

Read `core/world/queries.dart` before changing any screen. It is the seam.

### New

- **`lib/core/world/queries.dart`** — a port of `../LaMP/lib/world/queries.ts`.
  `TokenView` joins a token with its invoice, pharmacy and delivery;
  `listTokenViews` builds them all. The `TokenQueries` extension on
  `ReceivableToken` holds the predicates the screens filter on: `isOpen`,
  `isPayable`, `isFinanceable(now)`, `isAwaitingWindow(now)`, `isFullyScanned`,
  `scanned`, `disputeWindowClosed(now)`. Everything is synchronous —
  `LocalLedger._world` is a plain map and `build()` cannot await.
- **`LocalLedger.listKeysSync`** beside the async `listKeys`.
- **`LaMPState.tokenViews`** — cached, invalidated in `notifyListeners`. Plus
  `viewFor`, `openForPharmacy`, `forPharmacy`, `routeFor`, `creditFor`.
  `demoTokenId` survives only as the demo director's bookmark.
- **`test/world_test.dart`** (20) and **`test/flows_test.dart`** (11).

### Seed (`core/world/seed.dart`)

Now the TypeScript's seven pharmacies (was four), each with a credit history,
plus five in-flight consignments — three carried to DELIVERED through
`recordPoDBatch`, two left CREATED — so the route, the bank's queue and the
manufacturer's board hold real distribution. Seeded from `Random(_rngSeed)` so
the world is reproducible. `RCV-SEED-HIST` is now settled rather than left
DELIVERED, or it would sit in every derived list as a year-old open receivable.

Carton serials carry the invoice number (`seed.ts:149-153`). Two invoices
minting an identical GS1 payload would let a carton from one satisfy the
other's membership test.

### The five defects, and where each was fixed

1. *Bill due before the goods arrived* — `pharmacy_screen.dart` `_dueNowCard`
   hid the card only for SETTLED/FINANCED, so a CREATED token showed **Pay
   now**. The CTA is gated on `isPayable` now.
2. *Settled invoice stayed on screen* — the list is `openForPharmacy`, so a
   settled token leaves it; a "Recent deliveries" section is where it goes.
   **FINANCED was also inverted**: the screen called it "nothing to settle". A
   bank advancing against the receivable pays the manufacturer; the pharmacy
   still owes, and `settle` accepts FINANCED.
3. *Financed invoice stayed in the bank's queue* — `bank_screen.dart` now
   partitions into Eligible / Awaiting dispute window / Recently financed. The
   Finance button is disabled when the checklist fails; it used to guard only
   `_isAdvancing`, and "Not already financed" was hard-coded `isPassed: true`.
   "Dispute window closed" compares the clock to `disputeWindowClosesAt` rather
   than the off-chain delivery status.
4. *Delivered stop stuck on the route* — `mpo_screen.dart` reads
   `state.routeFor(mpos[0].id)` and draws a list with an empty state. Selecting
   a stop drives the Scan / Sign / Returns tabs.
5. *Could sign without scanning* — the gate reads `token.isFullyScanned` (the
   ledger), not `Carton.scannedAt` (the off-chain rows).

### Two things the previous patch had broken

- **`confirmDelivery` reset every `carton.scannedAt` to null** "so a re-run of
  the demo starts clean". The bank counted those rows, so signing for a delivery
  made its checklist read 0/25 on the consignment it had just confirmed. Removed
  — `resetWorld()` is what re-runs the demo.
- **The offline queue marked cartons scanned optimistically** while
  `drainScanQueue` only writes on success, so a refused batch left them all
  reading verified. `_nextCartonIndex` now skips queued cartons instead.

### Chaincode and world

- `recordPoD` / `recordPoDBatch` flip to DELIVERED at
  `confirmationThreshold` (0.90), not 1.0. That constant existed and was dead on
  this path, and 1.0 contradicted the figure the bank's checklist prints.
- `DemoClock.demoEpoch` was 23 Aug 2026, a day behind the comment beside it and
  behind `clock.ts`. Now `1787540400000`.
- `LaMPFormatters` renders Asia/Dhaka, not UTC. Everything on every screen was
  six hours early, and anything after 18:00 local showed the previous day.
- `mintInvoice` uses `_nextInvoiceNumber()` (ported from `mint.ts:45-51`) for
  monotonic zero-padded ids; `Random().nextInt(800) + 300` could collide with
  the seeded `INV-00235`. Cartons take the SKU of the line they belong to.

### Also

- `signature_pad.dart` drew on a hard-coded white canvas with `c.ink` ink — in
  the dark field theme the signature was invisible as it was drawn.
- Hard-coded values replaced with live ones across every screen: the MPO's three
  literal manifest rows, its four copies of the device id, the pharmacy's "Due
  in 45 days" and "Now Established · 85% advance", the bank's portfolio
  literals, the manufacturer's `PrivateSeal` (which carried the SHA-256 of the
  empty string) and its fixed 45-day term, the launcher's `'1'` invoice count.
- The regulator lists the endorsement-policy failures it had been counting and
  never showing.

## Code changes from the session before that

### Chaincode (`lib/core/chain/`)

- **`contract.dart`** — `mintReceivable` adds 3 data validations
  (cartonHashes.isEmpty, declaredValue≤0, dueDate≤issuedAt). `recordPoD` and
  `recordPoDBatch` throw on duplicates and unknowns. `matchAndAdvance` reads
  every registered curve via `privateKeys`, picks the best band (highest
  advance %, lowest fee %), and refuses non-DELIVERED tokens (state guard
  fires before the ratio check, matching TS `contract.ts:448–453`). `settle`
  guards state and applies late-cycle penalty via `_earnedTier` + `_dropOneTier`
  (≥2 lates drops one tier). `raiseDispute` rejects FINANCED/SETTLED/DEFAULTED.
  `resolveDispute` throws when no active dispute exists, validates restoreTo,
  and re-arms `disputeWindowClosesAt` only when restoring to DELIVERED. New
  `confirmReceipt` function persists pharmacy signature on-chain.
- **`ledger.dart`** — `_LedgerCtx` exposes `privateKeys`, gates `getPrivate` by
  membership, clones reads via `_clone`, dedupes puts via `indexWhere`.
  `LocalLedger.readWorldSync` and `LocalLedger.readPrivate(..., readerMsp)`
  are public. `confirmReceipt` is registered in `defaultPolicies` and the
  dispatch table.
- **`policy.dart`** — empty `AND()`/`OR()` throw on parse, missing `.role` on
  leaves throws, `OutOf` validates count range, unknown operator throws.
  `satisfies` denies on any parse failure.

### State & screens (`lib/core/state/`, `lib/features/`)

- **`state/lamp_state.dart`** — `confirmDelivery` now submits `confirmReceipt`
  and gates off-chain writes on `res.ok`. `scanCarton` mutates the real row
  (no phantom `Carton(UNKNOWN, ...)`). `drainScanQueue` mutates only on
  success. `initWorld` calls `saveNow()` after restore. `getToken` actually
  returns the token (was a `return null;` stub).
- **`features/bank/bank_screen.dart`** — `_activeCurve()` and `_activeBand()`
  flow through dial, advance %, advance amount, success banner. Hard-coded
  `182400` / `'80.0%'` removed. `_isAdvancing` guard wraps the button with a
  spinner.
- **`features/manufacturer/manufacturer_screen.dart`** — `_tokenStateFor`
  reads the chaincode-authoritative token state first. `LifecycleRail` shows
  Financed after financing. `invoiceValue` is hoisted to the top of
  `_buildReceivablesTab` so both the metric row and the header see it (an
  analyzer bug was introduced when it lived inside a `LayoutBuilder` closure).
- **`features/mpo/mpo_screen.dart`** — hard-coded amounts replaced.
  `Colors.purple` MISROUTED badge swapped for `c.dispute` / `c.disputeSoft`.
- **`features/pharmacy/pharmacy_screen.dart`** — `_invoiceAmountFor(state)`
  reads from `state.invoices`.

### Theme

- **`core/state/theme_controller.dart`** — `cycle()` captures the starting
  mode before mutation, so two rapid taps no longer advance two steps.

## How to test by hand (on the phone)

The app opens on **Sign in**. Pick an account and set a 4-digit PIN the first
time (on the test phone, Kamrul Hasan's PIN is 1234). In a debug build the
"⋯" menu has **Switch account** (no PIN) and **Demo controls** (move the clock,
reset the world) for walking the whole flow on one phone.

1. **Pharmacy (Abdur Rahman)**: no pay button at the start. The hero invoice is
   issued but not delivered, so the card reads "You can pay once the delivery is
   confirmed."
2. **Delivery officer (Kamrul Hasan) → Route**: stop 1 is open, and the other
   stops are listed under "Next". Tap one to open it.
3. **→ Sign, before scanning**: the button is disabled and says "Scan all N
   cartons before signing".
4. **→ Scan → Scan all**, then **Sign**: the gate opens. Sign, and the stop
   leaves the route.
5. **Bank (Meghna)**: the invoice appears under *Dispute window open*. Move the
   clock +24h from Demo controls and it moves to *Ready to finance*. Finance
   it and it moves to *Recently financed*, with no button.
6. **Pharmacy**: still **Pay ৳…**, because financing doesn't discharge the
   debt. Pay it: it leaves "Due now", appears under Recent, and the credit ring
   gains a cycle.
7. **Manufacturer → New invoice**: the new invoice appears on the officer's
   route and in the manufacturer's book.

Also worth checking:

- Carton 14 of the hero consignment is the planted wrong carton (debug builds
  only). "Scan next" presents a foreign code there and the ledger refuses it;
  the refusal shows on the carton's row, and in the Regulator seat as an open
  flag.
- The theme toggle cycles Light → Dark → Seat default without skipping.
- Kill the app right after launch on a populated store; relaunch shows the same
  records and the same signed-in account.

## Tests reference

`test/chaincode_test.dart` — 24 tests:

- **Group 1** (4 tests): policy parser — AND/OR/OutOf/nested.
- **Group 2** (3 tests): buildWorld, reject unknown carton, 8th-cycle tier upgrade.
- **Group 3** (3 tests): snapshot/restore round-trip, post-restore txs, clock offset.
- **Group 4** (13 tests): T1–T13 closing the gaps from the port-to-TS sweep.
  - T1 settle happy, T2/T2b late penalty, T3 settle state guard,
    T4 dispute state guard, T5 re-arm dispute window, T6 resolveDispute throws
    on missing dispute, T7 matchAndAdvance requires DELIVERED,
    T8 best-band selection, T9 recordPoD duplicate, T10 recordPoDBatch unknown,
    T11 mint validations, T12 readPrivate membership, T13 PolicyParser edge cases.

`test/world_test.dart` — 20 tests: the seeded world's shape (seven pharmacies,
seven tokens, unique carton hashes), the predicates every screen filters on,
the 90% confirmation threshold, the MPO route dropping a signed-for stop, and
minting reaching both the route and the book.

`test/flows_test.dart` — 12 tests: the five reported defects asserted on screen,
plus a second pharmacy seeing only its own invoices,
at 360x800, rather than in the model. If one of these fails, a user can see it.

`test/layout_test.dart` (54 tests): layout checks for sign-in and every seat,
on every tab, at three device sizes (iPhone SE, iPhone 15 Pro, Android
360×800) in light and dark. These guard against overflow regressions.

`test/design_lint_test.dart` (7 tests): fails on raw colours, inline font
sizes, bold, raw `TextStyle(`, inline `fontFamily` and `brightness ==`
branches in `lib/features` and `lib/widgets`. See `docs/DESIGN_SYSTEM.md`.

`test/widget_test.dart` (4 tests): sign-in lists every account, the first
sign-in sets a PIN and opens the account's own seat, a wrong PIN doesn't sign
in, and a fast load never flashes the splash.

`test/palette_test.dart` (21 tests, one per widget file): no screen reads a
fixed world palette. `test/luma_design_test.dart` (10 tests): the Luma
widgets.

Total: 152.

## If you break something

- The chaincode is in `lib/core/chain/contract.dart`; mirror the TS at
  `../LaMP/lib/chain/contract.ts`. State guards, validation order, and the
  curve-selection loop all came from that file.
- The endorsement policy for `confirmReceipt` is in
  `defaultPolicies['confirmReceipt']` (top of `lib/core/chain/ledger.dart`).
  It is intentionally ManufacturerMSP-only — the pharmacy's signature flows
  through the MPO device in this demo.
- The seed data (`lib/core/world/seed.dart`) is a port of the TS seed
  (`../LaMP/lib/world/seed.ts`). If you change rates, change both.
