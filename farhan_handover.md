# Handover for Farhan: 22–23 September 2026

What changed in `lamp-flutter` over the last two days, why, and what's still open.
Commits are by **ishmam259**. The work on the 23rd was done in a Claude Code session
and committed in four parts.

**Summary:** LaMP moved from a five-seat demo to a real app. People sign in with a PIN and
land on their own seat. All five seats were rebuilt to the design handoff (v2), and every
on-screen string was rewritten in plain language instead of chaincode names. Testing tools
are hidden in release builds. The recoloured logo, the new palette and the new typeface
(Anek) are in. `flutter analyze` is clean and all **151 tests pass**.

---

## 1. Commit map

| Date | Commit | Message | What it holds |
|---|---|---|---|
| 22 Sep | `26246a4` | UI SS for new redesign | Screenshots of every seat (`screenshots/`), `Luma App Tech Stack.md` |
| 22 Sep | `29f6622` | Merge branch 'luma-ui' | The Luma design layer (§2) |
| 22 Sep | `9a08248` | Redesigned UI | Palette tweak (dark brand set back to mint), launcher and MPO touch-ups. **Superseded on the 23rd** (§3.2) |
| 23 Sep | `c79a46f` | Demo Removed | Deletes the old logo PNGs, the unused IBM Plex Sans and Noto Sans Bengali fonts, and the seat launcher |
| 23 Sep | `40eab88` | Sign In Demo implemented | Most of the 23rd: logo and icons, palette, fonts, v2 adoption, MPO seat, plain-language copy, sign-in |
| 23 Sep | `a019e81` | Pharmacy And Bank Section redesigned | Pharmacy and Bank seats |
| 23 Sep | `e9db94b` | Mnaufacturer and Regulator redesigned and bug fixed | Manufacturer and Regulator seats |
| — | uncommitted | — | Regulator summary-row spacing, and this file |

---

## 2. 22 September: the Luma design layer (luma-ui merge)

This came in before the session on the 23rd and everything since builds on it.

- **`lib/core/design/`** (new): `luma_frost.dart` (frosted app bar, `LumaAppBar`,
  `lumaScrollPadding`), `luma_sheet.dart`, `luma_toast.dart`, `luma_press.dart`
  (press feedback and `LumaHaptics`), `luma_motion.dart`, `luma_elevation.dart`,
  `luma_auto_grid.dart`, `luma_container.dart`.
- **Screens:** all seats moved onto these widgets. A world/theme split was added to
  `LampPalette` (field vs portal, each in light and dark).
- **Type:** the typography moved to the system font. This was replaced on the 23rd (§3.3).
- **Docs and tests:** `docs/luma-ui.md` and `test/luma_design_test.dart`.
- **Palette commit (`9a08248`):** set `portalDark.brand` back to mint `#3DDC97`, the same as
  `verified`. The design handoff says that's wrong, and it was reversed on the 23rd.

---

## 3. 23 September: what changed

### 3.1 Logo and app icons
- **New logo files:** the recoloured PNGs are in `assets/images/`: `logo-mark-dark|light|white.png`
  and `logo-full-dark|light.png`. The old lime logo files are deleted.
- **`lib/widgets/lamp_mark.dart`** picks the dark or light file from the theme, has a `mono`
  (white) option, and defaults to 38 dp.
- **Launcher icons** come from masters in `assets/app_icon/` (not bundled into the app) via
  `flutter_launcher_icons` (dev dependency; config at the bottom of `pubspec.yaml`):
  - The iOS icon set and Android adaptive icons are regenerated, including a monochrome
    version for Android 13+ themed icons. The Android foreground inset is set to 0, because
    the master is already sized to the safe zone.
  - `web/icons/*` and `web/favicon.png` are copied from the masters, and the colours in
    `web/manifest.json` are set to `#0B120F`.
  - **Gotcha:** `dart run flutter_launcher_icons` corrupts
    `ios/Runner.xcodeproj/project.pbxproj` (it sets `…SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon`).
    Revert that file after every run.

### 3.2 Colour (`lib/core/constants/palette.dart`)
- **The action colour is no longer a status colour.**
  - **Dark themes:** `brand` is `#ECF2EE` (near-white) and `onBrand` is `#0A100D`.
  - **Light themes:** `brand` is `#0B5D42`; `portalLight` was teal before.
  - `verified` (mint) now means only "the ledger confirmed this".
- **Three states only:** confirmed, pending and refused. In dark themes these are
  `#3DDC97`, `#F0A93C` and `#FF6165`.
- **Chain blue is removed:** so are the `chain`/`chainSoft` slots and `LampTone.chain`.
- **Material's `secondary` colour** in `app_theme.dart` now points at `brand` and `brandSoft`
  instead of `verified`, so selected segments, chips and toggles are no longer mint.
- **`colors.dart`** is cut down to `LaMPColors.bKash` and `LaMPColors.nagad`, which are
  third-party logo colours.

### 3.3 Typography (`lib/core/constants/typography.dart`)
- **Fonts:** Anek Latin and Anek Bangla, in static 400/500/600 files cut from the Google
  Fonts variable fonts (OFL licence in `assets/fonts/Anek-OFL.txt`), plus IBM Plex Mono.
  Bengali text and the ৳ sign fall back to Anek Bangla.
- **Token names:** the file is v2's own. Names are `title`, `head`, `sub`, `body`, `meta`,
  `caption`, `displayFigure`, `figure`, `monoBody`, `monoCaption`, `label` and `monoMicro`.
  Mono text uses tabular figures.
- **Migration:** all inline `TextStyle(fontSize: …)` calls (about 120) and every
  `FontWeight.bold` (55) are gone, moved onto the tokens.
- **Rules:**
  - Mono is only for money, ids and codes. App-bar subtitles and names are sans.
  - Minimum size 11.
  - Weights 400/500/600.
- **Theme:** the font family is set on the base `ThemeData`, so Material buttons, tabs and
  the nav bar use Anek too.

### 3.4 Design system v2 (from `design_handoff_lamp_flutterv2/`)
- **`lib/widgets/ui/lamp_ledger_ui.dart`** holds the shared ledger widgets. They were
  extended during the session:
  - `LampStateDot`, `LampStateChip` (dot plus upper-case label)
  - `LampEyebrow` (optional hairline and trailing count)
  - `LampTickBar` (plus `.of(List<LampState?>)` for per-carton states in position)
  - `LampReceiptCard` and `LampReceiptFooter` (take a `ChainTx`)
  - `LampBlockPip` (the "Ledger" pill)
  - `LampSeatMenu` (the "⋯" menu: account, theme, sign out; testing items)
- **`test/design_lint_test.dart`** fails the build on raw colours, inline font sizes, bold,
  raw `TextStyle(`, inline `fontFamily` and `brightness ==` branches in `lib/features` and
  `lib/widgets`. Its colour regex was fixed so the `LaMPColors.bKash` exception actually works.
- **Allow-comments:** for a legitimate exception, end the line with
  `// design-lint: allow (reason)`. The barcode and QR widgets must stay black on white, and
  the camera scanner overlay reads `LampPalette.fieldDark`.
- **`docs/DESIGN_SYSTEM.md`** holds the rules. Two changes from v2's version:
  - §4 says to use `lumaScrollPadding`, because a fixed `EdgeInsets` hides content under the
    glass app bar.
  - A new §3a covers copy.
- **`CLAUDE.md`** has a design-system section near the top. The stale "Palette & widgets"
  paragraph is removed.
- **`analysis_options.yaml`** excludes `design_handoff_*/**`, because the Dart files inside
  the handoff folders were being analysed as project code.

### 3.5 Theme defaults
- **Seat defaults:** field seats (MPO, pharmacy) default to **light** and portals
  (manufacturer, bank, regulator) default to **dark**. This lives in `LaMPTheme.of`.
- **The toggle:** an explicit Light or Dark choice still applies everywhere. The third state
  is now called "Seat default".
- **Tests:** `ThemeController` takes an optional starting mode, which tests use to pin a
  theme.

### 3.6 Sign-in (replaces the seat picker)
- **Accounts:** `lib/core/auth/accounts.dart` builds the roster from the seed:
  - Kamrul Hasan (delivery officer)
  - Abdur Rahman (Rahman Medical Hall)
  - Shomota receivables desk
  - Meghna trade finance desk
  - Padma trade finance desk
  - Bangladesh Bank/DGDA supervision
- **`lib/core/auth/auth_controller.dart`:**
  - The PIN is set on first sign-in and stored only as a salted SHA-256 hash in
    SharedPreferences.
  - The session persists across restarts.
  - Five wrong PINs pause sign-in for 30 seconds.
  - The screens only call `createPin`, `signIn` and `signOut`, so a server can replace this
    class later.
- **Screen:** `lib/features/sign_in/sign_in_screen.dart` has an account list, then a PIN pad.
- **App shell (`main.dart`):** shows sign-in, then the signed-in account's seat, keyed by
  account.
  - Seats no longer have a back arrow; the mark sits in the leading slot.
  - System back leaves the app from a seat.
  - `LauncherScreen` is deleted.
- **`BankScreen(initialBank:)`** opens the right bank's desk.
- **Fixed:** the demo controls' "Jump to a seat" set a persona the shell never read. It now
  calls `AuthController.switchTo`.

### 3.7 Plain language (this is a real app, not a demo)
- **Translation layer:** `lib/core/constants/ledger_labels.dart` turns chaincode vocabulary
  into user copy:
  - `event(fn)`: for example `recordPoD` becomes "Carton scanned".
  - `status(TxStatus)`: "Recorded" or "Refused".
  - `org(mspId)`: `MeghnaMSP` becomes "Meghna Commercial Bank".
  - `reason(message)`: "Carton with hash … does not belong to invoice INV-00235" becomes
    "This carton isn't part of INV-00235."
- **Rule:** never print function names, MSP ids, the channel name, token keys, tx ids,
  policy expressions or raw errors. Block numbers and tx ids appear only under "Reference"
  in a ledger record's details.
- **Renames:**
  - Invoice states now read Issued, Being delivered, Delivered, Financed, Paid.
  - Delivery statuses got labels.
  - The lifecycle rail uses the same words.
- **Testing tools:** `lib/core/constants/app_mode.dart` defines `kDemoTools = !kReleaseMode`.
  It hides these in release builds:
  - Demo controls
  - Switch account
  - "Scan all" (auto-scan)
  - The planted misrouted carton, including its **silent substitution at position 14 in
    "Scan next"**, which would otherwise have shipped
  - The test-carton dialog

### 3.8 Seats (layout against the v2 mockups)
Every seat now has the same chrome: `LumaAppBar` with the mark, the "Ledger" pill, the
"⋯" menu and a bottom `NavigationBar`. The Regulator has a single page and no nav.

- **Delivery officer** (`mpo_screen.dart`):
  - **Route:** one open stop shown as a receipt card: status chip, a three-figure row,
    25-carton tick bar, "Scan cartons · N left", and a ledger footer. "Next" stops and the
    manifest follow.
  - **Scan:** "Cartons checked 13/25" with ticks, plus camera, "Scan next" and (testing
    only) "Scan all". A refused carton's reason appears on its own row; the red banner is gone.
  - **Sign and Returns:** "Confirm delivery"; the dispute button is outlined, not filled.
- **Pharmacy** (`pharmacy_screen.dart`):
  - **Credit card:** the ring reads as 8 separate arcs (butt caps; `credit_ring.dart`),
    with "N more on-time cycles unlock X — Y% advance" and "History ›".
  - **Due now:** a receipt card; once payable it shows "Pay ৳…".
  - **Recent:** rows with state dots.
  - **No tinted panels remain.**
  - **Fixed:** the Pay tab's empty state sat behind the app bar.
- **Manufacturer** (`manufacturer_screen.dart`):
  - **Invoices:** outstanding with a bar split by state, plus "Advanced by banks" and
    "Ready to finance". The book is a table; tapping a row opens its lifecycle rail,
    details and receipt.
  - **Tracking:** every consignment on the road, with carton ticks.
  - **New invoice:** a pharmacy picker (was locked to Rahman Medical Hall), all 10 medicines
    with steppers, a credit-period segmented control, a running total, and
    "Issue invoice · ৳…".
  - The lifecycle rail is rebuilt as four equal columns ("Financed" was cut to "Fi").
- **Bank** (`bank_screen.dart`):
  - **Queue:** a Ready / Waiting / Deployed strip. Each ready card shows
    "Checks · N of 4 passed" with a figure per check, the price row and "Finance ৳…".
    Waiting and recently financed invoices are compact rows. Results show as toasts.
  - **Rates:** a single table: tier, advance, fee and guarantee. It replaces
    `RecourseDial`, which truncated and highlighted one hard-coded pharmacy; the dial file
    is deleted.
  - **Portfolio:** only this bank's advances; it used to count every bank's.
  - The in-screen bank switch is removed; "Switch account" covers it.
- **Regulator** (`regulator_screen.dart`):
  - A "View only" line, then totals.
  - **Checks:** a list with counts and a Clean/flags chip per check.
  - **Open flags:** one card per refused record, in plain language, linking to the ledger.
  - **Traceability:** a tick strip of the last 40 carton scans, with refusals in position.
- **Ledger view** (`ledger_inspector_sheet.dart`): rows lead with the plain event, status,
  invoice, organisation and time. A record's details show Status, Why, Invoice, By, When and
  Approved by, with the reference (block and tx id) at the foot.
- **Launcher:** removed. Its ledger strip had hard-coded "Invoices 1" while the ledger held 7.

### 3.9 Other bug fixes
- **Known failing test:** `flows_test` "cannot sign for goods that were never scanned" had
  been failing since the 22nd, because `ElevatedButton.icon` is a private subclass. The test
  now matches `ButtonStyleButton`.
- **Truncating headings:** section eyebrows with a count ("DISPUTE WINDOW OPEN ── 1") keep
  natural widths with caps instead of an even flex split, so they no longer truncate.
- **Credit ring caption:** it used to scale to 9.6 px, under the 11 px floor, at 120 dp.
- **Receipt footer ids:** the footer printed "tx tx-…" because ids already carry the prefix.
- **Layout sweep coverage:** the sweep only knew top `Tab`s. It now steps through bottom-nav
  tabs, so the MPO, pharmacy, manufacturer and bank are checked on every tab.

---

## 4. Tests: 151, all passing

| File | Tests | Notes |
|---|---|---|
| `chaincode_test.dart` | 24 | Unchanged |
| `world_test.dart` | 20 | Unchanged |
| `flows_test.dart` | 11 | Updated for the new layouts and copy; pinned to the dark theme |
| `layout_test.dart` | 54 | Sign-in replaces the launcher; bottom-nav tabs swept; theme pinned per brightness |
| `palette_test.dart` | 21 | One per widget file |
| `luma_design_test.dart` | 10 | From the 22nd |
| `design_lint_test.dart` | 7 | New (v2) |
| `widget_test.dart` | 4 | Rewritten: sign-in list, first-PIN flow, wrong PIN, no splash flash |

The test counts in `CLAUDE.md` ("133 total") are out of date; the table above is current.

---

## 5. Running it on this machine

- **Toolchain:** `flutter` is on PATH (`C:\Users\16IRL8\flutter`). The in-project
  `.flutter/`, `.jdk/` and `.android-sdk/` paths described in `CLAUDE.md` **don't exist here**.
- **Test device:** the Samsung SM-S721B over **wireless debugging**. adb is at
  `C:\Users\16IRL8\AppData\Local\Android\sdk\platform-tools\adb.exe`.
  - It drops off whenever the phone's Wi-Fi sleeps. Re-enable *Developer options → Wireless
    debugging*.
  - `flutter run` sometimes fails at install over Wi-Fi. What worked instead:
    ```bash
    flutter build apk --debug
    adb install -r build/app/outputs/flutter-apk/app-debug.apk
    ```
    Then launch the app and use `flutter attach` for hot reload.
- **Test PIN:** on that phone, Kamrul Hasan's PIN is **1234**. Other accounts ask for a PIN
  on first sign-in.
- **Checks to run:**
  ```bash
  flutter analyze
  flutter test
  ```

---

## 6. Open items and decisions

1. **Launcher icon:** it reads small beside other apps. The mark isn't undersized; it's thin
   line-art with small "LM" letters on near-black. The proposal is a simplified bold "LM"
   glyph for the launcher, redrawn as a vector (the handoff already asks for a vector
   before store release). This needs a design decision.
2. **Sign-in is on-device.** For production, replace `AuthController`'s PIN check with a
   server (the screens won't change). The roster is also tied to the seed:
   `SeedData.pharmacies[0]` and `mpos[0]` are hard-wired into the pharmacy and MPO seats.
3. **Ledger view filters:** the mockup's All / Writes / Refused / Private chips aren't built.
4. **Regulator navigation:** it has no bottom nav, because it's a single page.
   `DESIGN_SYSTEM.md` says every seat gets one; either change the doc or add a second tab.
5. **Release build:** none has been made since these changes. Build one and check that
   `kDemoTools` hides the testing tools.
6. **Toolchain notes in `CLAUDE.md`:** the build section still describes the other machine
   (the `D:\VSCODE\...` paths).
7. **Design handoff folders:** `design_handoff_lamp_flutter/` (v1) and
   `design_handoff_lamp_flutterv2/` are committed. v2 is the one that was applied.
