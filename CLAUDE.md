# LaMP Flutter — project notes for future Claude

This file exists so the next Claude session does not have to redo the discovery work
that cost the previous session an entire afternoon of debugging toolchain setup.

## What this project is

A Flutter port of the LaMP (Last Mile Pharmacy) consortium receivables ledger demo.
The TypeScript reference at `../LaMP` is authoritative — `README.md` says so.

The demo's central claim is "the ledger, not the UI, is the system of record."
That claim used to be false in several places — most of them one root cause: the
screens rendered a single hard-coded token instead of deriving their lists from
the chain. The most recent session closed that; the sections below list what
changed and where, plus the non-obvious toolchain quirks that will trip up
anyone trying to rebuild.

**Start at `lib/core/world/queries.dart`.** Every screen filters through it, and
the rule it exists to enforce is that a screen must not offer an action the
chaincode is going to refuse.

## Toolchain layout (read this before running anything)

The Flutter SDK, JDK, and Android SDK were all installed outside the project
(`C:\Users\Lenovo\scoop\apps\...`) but **copied into the project** at the
following paths, because the bash sandbox blocks references to `C:\Users\...`:

| Tool         | Path inside the project                       |
| ------------ | --------------------------------------------- |
| Flutter SDK  | `.flutter/`                                   |
| JDK 21       | `.jdk/`                                       |
| Android SDK  | `.android-sdk/` (cmdline-tools, platforms, …) |

If you need to invoke them, use the project-local paths:

```bash
FLUTTER=./.flutter/bin/flutter
JAVA_HOME=./.jdk
ANDROID_HOME=./.android-sdk
```

`android/local.properties` already points at the in-project SDK locations:

```
flutter.sdk=D:\\VSCODE\\Blockchain Olympiad\\lamp-flutter\\.flutter
sdk.dir=D:/VSCODE/Blockchain Olympiad/lamp-flutter/.android-sdk
```

## One-time configuration that already happened

```bash
./.flutter/bin/flutter config --android-studio-dir=     # cleared (was bogus "none")
yes | sdkmanager --licenses                              # accepted (10 packages)
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
```

The `--jdk-dir` config setting was problematic — passing the path through
`flutter config` got the bash sandbox to choke on the space in `D:\VSCODE\...`.
Set `JAVA_HOME` inline instead and leave `flutter config --jdk-dir` empty.

## How to run

### Static analysis

```bash
cd "D:/VSCODE/Blockchain Olympiad/lamp-flutter"
JAVA_HOME=./.jdk ./$FLUTTER_BIN/flutter analyze
```

Must be clean. Currently is.

### Tests (unit + widget + layout)

```bash
JAVA_HOME=./.jdk ./$FLUTTER_BIN/flutter test
```

133 total, all passing: 24 chaincode, 20 world/query, 11 UI flow, 78 layout.

### Run on Chrome for quick smoke-testing

```bash
JAVA_HOME=./.jdk ./$FLUTTER_BIN/flutter run -d chrome
```

### Build a release APK (for sideloading to a phone)

**`JAVA_HOME` has to be absolute here, and Windows-style.** The relative
`./.jdk` that works for `analyze` and `test` never reaches Gradle, which
forks its own daemon with its own working directory and reports
`JAVA_HOME is set to an invalid directory: ./.jdk`. The space in the path is
fine as long as the value is quoted.

```bash
cd "D:/VSCODE/Blockchain Olympiad/lamp-flutter"
JAVA_HOME='D:\VSCODE\Blockchain Olympiad\lamp-flutter\.jdk' \
ANDROID_HOME='D:\VSCODE\Blockchain Olympiad\lamp-flutter\.android-sdk' \
ANDROID_SDK_ROOT='D:\VSCODE\Blockchain Olympiad\lamp-flutter\.android-sdk' \
  ./.flutter/bin/flutter build apk --release --android-skip-build-dependency-validation
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (~70 MB).

Piping the build through `tail` swallows Gradle's exit code, so check for
the `Built build\app\outputs...` line rather than trusting `$?`.

The APK is signed with the debug keystore (`android/app/build.gradle.kts` is
configured this way for sideload convenience). For Play Store, replace with a
real signing config.

## Non-obvious build knobs (and why)

These are the things that took the most time to figure out. Do not "simplify"
them without understanding the failure mode:

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

### Palette & widgets

- **`core/constants/palette.dart`** — `portalLight.brand` shifted from
  `#059669` (emerald, same as verified) to `#0F766E` (teal). `portalDark.brand`
  shifted from `#3DDC97` (mint, same as verified) to `#38BDF8` (sky). The
  brand and verified tokens are now distinguishable.
- **`widgets/lifecycle_rail.dart`** — uses `context.lamp` tokens, not the
  legacy `LaMPColors`.

### Theme

- **`core/state/theme_controller.dart`** — `cycle()` captures the starting
  mode before mutation, so two rapid taps no longer advance two steps.

## How to test the demo (manual, on a phone or in Chrome)

The five reported defects, in the order they were reported:

1. **Pharmacy, at demo start** — no **Pay now**. The hero consignment is
   CREATED, so the card reads "Payable once the delivery is confirmed on the
   ledger."
2. **MPO → Route** — three stops, not one. Tap one to select it; its manifest
   opens beneath.
3. **MPO → Sign, before scanning** — the submit button is disabled and says
   "Scan all N cartons before signing".
4. **MPO → Scan → Auto Cascade**, then **Sign** — the gate opens. Sign, and the
   stop leaves the route; the next one becomes stop 1.
5. **Bank** — the consignment appears under *Awaiting dispute window*. Advance
   the clock 24h from the demo director; it moves to *Eligible*. Finance it; it
   moves to *Recently financed*, with no Finance button.
6. **Pharmacy** — still **Pay now**, because financing does not discharge the
   debt. Pay it: it leaves "Due now", appears under Recent deliveries, and the
   credit ring gains a cycle.
7. **Manufacturer → Mint** — the new invoice appears on the MPO's route and on
   the manufacturer's book. Before this pass it appeared nowhere.

Still worth checking by hand:

- Carton 14 of the hero consignment is the planted misroute; the cascade submits
  a foreign payload and the chaincode refuses it for real.
- Theme toggle cycles Light → Dark → System without skipping.
- Kill the app right after launch on a populated store; relaunch shows the same
  blocks.

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

`test/flows_test.dart` — 11 tests: the five reported defects asserted on screen
at 360x800, rather than in the model. If one of these fails, a user can see it.

`test/layout_test.dart` (78 tests): golden-style layout tests for every screen
at multiple device sizes (iPhone SE, iPhone 15 Pro, Android 360×800) in both
light and dark mode. These guard against overflow regressions.

`test/widget_test.dart` (a few tests): persona launcher smoke test and
back-button behavior.

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
