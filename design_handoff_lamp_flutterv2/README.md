# Handoff: LaMP Flutter app — UI redesign + recoloured logo

## Overview
LaMP (Last Mile Pharmacy) is a **Flutter mobile app** (`lamp-flutter`, `lib/`) for a consortium receivables ledger: delivery officers (MPO) scan cartons at the pharmacy door, the ledger verifies them, and banks finance the resulting invoices. This package holds (1) the recoloured brand logo and ready-to-ship app-icon files, and (2) the UI redesign spec for the in-app screens.

## About the design files
Files in `reference/` are **design references built in HTML**. They show the intended look and behaviour; they are not production code. Recreate them in the existing Flutter codebase using its patterns: `LampPalette` (ThemeExtension, `lib/core/constants/palette.dart`), `LaMPType` (`typography.dart`), `Gap`/`IconSize` tokens, and the `luma_*` widgets in `lib/core/design/`. Open the `.dc.html` files in a browser (keep `support.js` next to them).

## Fidelity
**High fidelity.** Colours, type sizes, tracking and spacing in the reference are final. Match them using the existing token system. Don't hard-code hex values in widgets.

---

## 0. Start here: task order for Claude Code

1. **Fix the build.** `app_theme.dart` and `pharmacy_screen.dart` call `LaMPType.sans` and `LaMPType.meta`, which the current `typography.dart` doesn't define. Replace the file with `flutter/lib/core/constants/typography.dart` from this package. It uses Anek Latin/Bangla (already registered in `pubspec.yaml`) and keeps every existing style name, so the other call sites still compile.
2. **Add `flutter/lib/widgets/ui/lamp_ledger_ui.dart`.** It provides `LampSeatTitle`, `LampBlockPip`, `LampReceiptCard`/`LampReceiptFooter`, `LampTickBar`, `LampStateDot` and `LampEyebrow`.
3. **Put the rules in the repo:** copy `DESIGN_SYSTEM.md` to `docs/DESIGN_SYSTEM.md`. In `CLAUDE.md`, **delete the stale "Palette & widgets" paragraph** (it describes teal and sky brand colours that no longer exist) and paste `CLAUDE_md_design_section.md` near the top. This makes every future session, and every new screen, follow the same system.
4. **Add `flutter/test/design_lint_test.dart`** to `test/`. It fails on raw colours, inline font sizes, bold, raw `TextStyle(`, inline `fontFamily` and `brightness ==` branches in `lib/features` and `lib/widgets`. It **will fail at first**, because it lists the call sites to migrate in §3 below. Work through them until it passes. After that, a new screen can't drift without a red test.
5. **Logo and icons (§1).** `pubspec.yaml` already has the `flutter_launcher_icons` block. Copy `assets/app_icon/` and `assets/images/` into place, update `lamp_mark.dart`, then run `dart run flutter_launcher_icons`.
6. **Screens (§4).** Rebuild each seat against `DESIGN_SYSTEM.md` §4, using the reference sheet as the visual source.
7. Run `flutter analyze` and `flutter test` (all suites, including layout at 360×800 in light and dark).

`palette.dart` in the repo **already matches the design**: brand ≠ verified, three states, no chain slot. Don't change it. Delete `colors.dart` except `bKash`/`nagad` once nothing else imports it.

---

## 1. Logo (do this first — smallest, highest-visibility change)

The logo **design is unchanged**. Only its colours changed, to the app palette:
- **On dark grounds:** gradient mint `#3DDC97` → pale mint `#B4F3D4`
- **On light grounds:** deep green `#0B5D42` → mint `#23B97A`
- **Monochrome:** pure white `#FFFFFF` (for status bars and themed icons)

### Files → where they go
| File in this package | Destination in lamp-flutter |
|---|---|
| `assets/images/logo-mark-dark.png` | `assets/images/logo-mark-dark.png` |
| `assets/images/logo-mark-light.png` | `assets/images/logo-mark-light.png` |
| `assets/images/logo-mark-white.png` | `assets/images/logo-mark-white.png` |
| `assets/images/logo-full-dark.png` | `assets/images/logo-full-dark.png` (mark + "LaMP" wordmark) |
| `assets/images/logo-full-light.png` | `assets/images/logo-full-light.png` |

The mark PNGs are tight-cropped (280×291, transparent). Then delete the old `assets/images/logo-mark.png`, `logo-removebg-preview.png` and `logo.png`. `pubspec.yaml` already bundles `assets/images/` and registers the Anek + Plex fonts, so no pubspec change is needed.

### Update `lib/widgets/lamp_mark.dart`
Make it brightness-aware. Today it always loads the old lime PNG.
```dart
class LampMark extends StatelessWidget {
  final double size;
  final bool markOnly;
  final bool mono; // white, for coloured/photo grounds
  const LampMark({super.key, this.size = 28, this.markOnly = true, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final String path = mono
        ? 'assets/images/logo-mark-white.png'
        : markOnly
            ? (dark ? 'assets/images/logo-mark-dark.png' : 'assets/images/logo-mark-light.png')
            : (dark ? 'assets/images/logo-full-dark.png' : 'assets/images/logo-full-light.png');
    return Image.asset(path, width: size, height: size, fit: BoxFit.contain,
        filterQuality: FilterQuality.medium);
  }
}
```
**Usage:** app-bar header uses the mark at **38dp**, followed by "LaMP" set at 16sp w600. Splash uses `markOnly: false` at ~160dp. Don't place the mark below **32dp**: its cubes and shield blur together under that size.

### App icons (`assets/app_icon/`)
All icons use a solid `#0B120F` ground with the dark-variant mark. Corners are **not** pre-rounded, because the OS applies the mask.
- `ios_appicon_1024.png` → `ios/Runner/Assets.xcassets/AppIcon.appiconset`. The mark is 74% of the canvas.
- `android_adaptive_foreground_432.png` (transparent, mark 56% so it fits the 66/108 safe zone) + `android_adaptive_background_432.png` (solid `#0B120F`) + `android_adaptive_monochrome_432.png` (white, for Android 13+ themed icons).
- `play_store_512.png`: the Google Play listing icon.
- `web_icon_192/512.png`, `web_icon_maskable_192/512.png`, `favicon_32.png` → `web/icons/` and `web/favicon.png`.

**Easiest path:** add `flutter_launcher_icons` as a dev dependency and generate all sizes from these masters:
```yaml
flutter_launcher_icons:
  image_path: "assets/app_icon/ios_appicon_1024.png"
  ios: true
  remove_alpha_ios: true
  android: true
  adaptive_icon_background: "#0B120F"
  adaptive_icon_foreground: "assets/app_icon/android_adaptive_foreground_432.png"
  adaptive_icon_monochrome: "assets/app_icon/android_adaptive_monochrome_432.png"
```
Then run `dart run flutter_launcher_icons`. Keep `assets/app_icon/` out of the runtime bundle.

`_preview.png` shows the result under the iOS, Android circle, themed and favicon masks. It's for review only; don't ship it.

**Caveat:** these files are raster exports of a 500px source. Before the store release, redraw the mark as a vector (SVG → `flutter_svg`, or a font glyph) so it stays crisp at 1024px.

---

## 2. Colour (`lib/core/constants/palette.dart`)
Rules from the redesign sheet (turn 2):
- **The action colour is not a status colour.** Mint means "the ledger confirmed this" and nothing else. In `portalDark` (and `fieldDark`), `brand` and `verified` are both `#3DDC97`. Change the dark-theme primary action to the top of the ink ramp:
  - `portalDark` / `fieldDark`: `brand: #ECF2EE`, `onBrand: #0A100D`
  - Light themes keep `brand: #0B5D42` / `onBrand: #FFFFFF`. On light grounds, set `verified` to `#0B6B4C` so it separates from brand by tone and shape (a dot + chip, never a filled button).
- **Three states only:** confirmed `#3DDC97` · pending `#F0A93C` · refused `#FF6165` (dark themes). **Retire chain blue** (`#7BA6E8`/`#2F5FA8`/`#225698`): provenance is shown by typography (mono `BLK · tx` footer under a hairline), not colour. Remove the `chain` and `chainSoft` slots and migrate their call sites to `inkMuted` + mono.
- **Accent is a budget, split 60/30/10:** 60% ground, 30% surfaces, 10% accent. State colour appears only on 6dp dots, chip text and figures that carry state. No accent-filled cards and no tinted panels.

Dark ground and surfaces used in the reference: ground `#0B120F`/`#080B0A`, surface `#121714`, raised `#1A211D`/`#222A26`, hairline `#232C28`, ink `#ECF2EE`, muted `#B6C3BC`, faint `#8A9791`.

## 3. Typography (`lib/core/constants/typography.dart`)
- **Families:** bundle **Anek Latin + Anek Bangla** (one superfamily, so Latin and Bengali share metrics on the same line) and keep **IBM Plex Mono**. Replace the system-font cascade and `NotoSansBengali`. Add the `.ttf` files (Google Fonts, OFL) to `assets/fonts/` and register them in `pubspec.yaml`.
- **Mono is only for** money, hashes, transaction ids, block numbers and carton codes: anything compared down a column. **App-bar subtitles and people's names must be sans.**
- **Scale:** sans 12.5 / 14 / 15 / 16 / 20; mono 11 / 12.5 / 15 / 22 / 28. **Minimum size is 11**; nothing smaller.
- **Weights:** 400 / 500 / 600 only. Remove every `FontWeight.bold` (w700).
- **Tracking:** −0.02em at 20sp and above · 0 for 12.5–16sp · +0.12em for uppercase labels only.
- **Migration:** 87 inline `TextStyle(fontSize: …)` call sites bypass `LaMPType`. They're in `mpo_screen.dart` (32), `manufacturer_screen.dart` (31), `bank_screen.dart` (22) and `credit_ring.dart` (2). Move all of them onto the tokens. The worst cases are the 8px `MISROUTED TEST` badge (`mpo_screen.dart:812`), which should become an 11 mono uppercase chip in refused red, and the 9px bank eligibility labels (`bank_screen.dart:727`).

## 4. Screens (see `reference/LaMP Redesign.dc.html`, turn 1 and the ten phone mockups)
Principles applied to every seat (MPO, pharmacy, manufacturer, bank, regulator):
1. **Chrome:** one app bar with the monogram (`LampMark` 38dp), the seat name, and a live **block pip** (mint dot + block number) that opens `ledger_inspector_sheet.dart`. The three unlabelled action icons are removed. Every seat gets the same bottom nav.
2. **Receipts:** anything written to the ledger renders as a receipt card with a mono `BLK n · tx-xxxxx…` footer under a hairline. Off-chain rows stay plain.
3. **Countable:** carton verification is **25 ticks** (one per carton, with the misroute in its own position, red), not a percentage bar. Pharmacy credit is **8 arcs**, one per cycle (`credit_ring.dart`).
4. **Density:** screen titles 20, figures 22–26 (mono), body 14. Field seats (MPO, pharmacy) keep 44dp minimum touch targets. Desk seats (manufacturer, bank, regulator) use tables rather than stacks of cards.
5. **Themes:** field seats default to light (sunlight legibility) and portals to dark. Both themes must exist for every seat, because `LampPalette.resolve` already supports that.

Turns 3–6 of the sheet cover the icon set, font pairing, type audit and a self-audit. The phone mockups in the sheet are the source of truth for layout.

## Files
- `DESIGN_SYSTEM.md`: the rules every screen follows, including new ones (goes to `docs/`).
- `CLAUDE_md_design_section.md`: paste into the repo's `CLAUDE.md`.
- `flutter/lib/core/constants/typography.dart`: drop-in replacement (fixes the build).
- `flutter/lib/widgets/ui/lamp_ledger_ui.dart`: new shared widgets.
- `flutter/test/design_lint_test.dart`: enforces the tokens.
- `reference/LaMP Redesign.dc.html`: full UI redesign sheet with all phone screens and rules (newest turn at top).
- `reference/LaMP Logo Recolor.dc.html`: logo in light, dark, app-icon, small-size and mono uses.
- `reference/support.js` + `reference/assets/`: needed to open the references offline.
- `assets/images/`: in-app logo PNGs.
- `assets/app_icon/`: launcher/store/web icon masters.
