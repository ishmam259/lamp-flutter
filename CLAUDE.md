# LaMP Flutter — project notes for future Claude

## What this project is

A Flutter port of the LaMP (Last Mile Pharmacy) consortium receivables ledger demo.
The TypeScript reference at `../LaMP` is authoritative — `README.md` says so.

The demo's central claim is "the ledger, not the UI, is the system of record."
**Start at `lib/core/world/queries.dart`.** Every screen filters through it, and
the rule it exists to enforce is that a screen must not offer an action the
chaincode is going to refuse.

## Build (one-liner)

Everything lives in-project to dodge the bash sandbox blocking `C:\Users\...`:

| Tool         | Path         |
| ------------ | ------------ |
| Flutter SDK  | `.flutter/`  |
| JDK 21       | `.jdk/`      |
| Android SDK  | `.android-sdk/` |

```bash
cd "D:/VSCODE/Blockchain Olympiad/lamp-flutter"
export JAVA_HOME='D:\VSCODE\Blockchain Olympiad\lamp-flutter\.jdk'
export ANDROID_HOME='D:\VSCODE\Blockchain Olympiad\lamp-flutter\.android-sdk'
export ANDROID_SDK_ROOT="$ANDROID_HOME"
./.flutter/bin/flutter analyze                                            # must be clean
./.flutter/bin/flutter test                                               # 130+ tests
./.flutter/bin/flutter run -d chrome                                      # web smoke
./.flutter/bin/flutter build apk --release --android-skip-build-dependency-validation   # APK → build/app/outputs/flutter-apk/app-release.apk
```

First-run gotchas (do these once per machine):

```bash
yes | ./.flutter/bin/flutter doctor --android-licenses                    # accept SDK + NDK licenses; triggers auto-install of platforms/build-tools/ndk/cmake
```

That's it. The four non-obvious knobs below are already wired in. Don't touch them unless you understand the failure mode.

### Why these knobs exist (do not delete without fixing the underlying problem)

1. **`kotlin.incremental=false`** in `android/gradle.properties` — Pub cache is on `C:\`, project on `D:\`. Kotlin incremental compiler refuses cross-drive paths. Move `PUB_CACHE=D:\...` to re-enable.
2. **`gradle-wrapper.properties` pinned to `8.14-all`** — Flutter 3.47 rejects 8.12.
3. **`--android-skip-build-dependency-validation`** — AGP is pinned to 8.9.1; Flutter 3.47 wants ≥8.11.1. Bump AGP, drop this flag.
4. **`android.newDsl=false`** in `android/gradle.properties` — required for AGP 8.9.x to read the project's `build.gradle.kts`. Bump AGP, remove.

`JAVA_HOME` for the APK build must be **absolute, Windows-style, quoted** — Gradle forks its own daemon and ignores relative paths. `flutter analyze` and `flutter test` accept relative `./.jdk` fine.

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
