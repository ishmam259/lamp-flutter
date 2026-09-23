# LaMP design system — rules for every screen, including new ones

Read this before creating or editing any widget in `lib/features/` or `lib/widgets/`.
`test/design_lint_test.dart` enforces the mechanical rules; the rest are review rules.

## 1. Where values live (the only places)
| What | File | Access |
|---|---|---|
| Colour | `lib/core/constants/palette.dart` (`LampPalette`, 4 palettes) | `context.lamp.ink` etc. |
| Type | `lib/core/constants/typography.dart` (`LaMPType`) | `LaMPType.body.copyWith(color: c.ink)` |
| Radius | `LaMPRadius.control / card / surface / pill` | — |
| Spacing | `Gap.xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · section 40 · card 20 · group 36` | — |
| Icon size | `IconSize.sm 16 · md 20 · lg 24 · xl 32` | — |
| Motion / elevation | `lib/core/design/luma_motion.dart`, `luma_elevation.dart` | `LumaMotion.*`, `LumaElevation.*` |
| Theme wiring | `lib/core/constants/app_theme.dart` (`LaMPTheme.build(world, brightness)`) | automatic |

A screen **never** writes `Color(0x…)`, `Colors.x` (except `transparent`), `fontSize:`, `fontFamily:`,
`FontWeight.bold/w700`, `TextStyle(` from scratch, a new radius, or a spacing number not in `Gap`.
If a value is missing, add a token to the constants file first, then use it.

## 2. Colour
- **Brand is not status.** Brand (`c.brand`) is for pressable actions only. Dark themes: near-white `#ECF2EE` on `#0A100D`. Light themes: deep green `#0B5D42` on white.
- **Mint is reserved.** `c.verified` means "the ledger confirmed this". Never for a button, link, or selected tab.
- **Three states only.** confirmed `c.verified` · pending `c.pending` · refused `c.dispute`. Use the `LampState` enum and `LampStateDot`. No blue "chain" colour; provenance = `LampReceiptFooter` (mono, under a hairline).
- **Accent budget 60/30/10.** State colour appears on 6dp dots, chip text, tick bars and figures that carry state. Never as card fills or tinted panels (the `*Soft` tints are for chip backgrounds only).
- Cards are separated from the page by being lighter (`c.surface` on `c.bg`) plus a `c.line` hairline, not by shadows.
- Exceptions: the bKash/Nagad marks on the pay sheet (`LaMPColors.bKash / nagad`) are third-party logos.
- The camera scanner is drawn over the live feed, which is dark in either theme, so it reads
  `LampPalette.fieldDark` directly instead of `context.lamp`.
- A line that genuinely needs a raw value (a barcode must be black on white to scan) ends in
  `// design-lint: allow (reason)`. The reason is not optional.

## 3. Type
- Anek Latin/Bangla for everything human; IBM Plex Mono **only** for money, hashes, tx ids, block numbers, carton codes, and UPPERCASE eyebrow labels. Names, subtitles, and app-bar text are sans.
- Scale: `title 20` (one per screen) · `head 16` · `sub 15` · `body 14` · `meta / caption 12.5` · mono `displayFigure 28` · `figure 22` · `monoBody 15` · `monoCaption 12.5` · `label / monoMicro 11`.
- Nothing below 11. Weights 400/500/600. Money is always mono with `৳` (tabular figures are on by default).
- Bangla strings need no special handling: Anek Bangla is the fallback of every style.

## 3a. Copy
LaMP is used by pharmacists, delivery officers and bank staff, not by the people who wrote the chaincode.
- Sentence case, plain words. Never show chaincode function names (`recordPoD`), MSP ids (`MeghnaMSP`), the channel name, token keys (`RCV-00235`), policy expressions or raw error text.
- Ledger events, statuses, organisations and refusal reasons go through `LedgerLabels` (`lib/core/constants/ledger_labels.dart`): `event(fn)`, `status(s)`, `org(mspId)`, `reason(message)`. Add a mapping there rather than printing the raw value.
- Block numbers and transaction ids appear only under "Reference" in the ledger view's record details.
- Testing tools (demo controls, auto-scan, the planted test carton, the bank switch) are wrapped in `kDemoTools` (`lib/core/constants/app_mode.dart`) and never reach a release build.

## 4. Structure of a seat screen
```
Scaffold(bg)
 └ LumaAppBar / AppBar
     title: 'Rahman Medical Hall', subtitle: 'Bogura Sadar'   (the mark sits in the leading slot automatically)
     actions: [LampBlockPip(onTap: openLedgerInspector), LampSeatMenu()]
 └ body: ListView(padding: lumaScrollPadding(context, top: Gap.lg))
     LampEyebrow('Due now') → SizedBox(height: Gap.sm) → cards…
     SizedBox(height: Gap.group) between groups
 └ bottom: NavigationBar (same component on every seat)
```
- **Body padding** is `lumaScrollPadding(context)`, never a fixed `EdgeInsets`. The app bar is
  glass and the body runs underneath it (`extendBodyBehindAppBar`), so a fixed inset puts the
  first card behind the bar.
- **Ledger writes** render as `LampReceiptCard(block:, tx:)`. Off-chain rows use `LampCard` / `LampRow`, with no footer.
- **Counts** render as `LampTickBar` (one tick per carton, misroutes red in position), not `%` bars. Credit = 8 arcs (`credit_ring.dart`).
- **Empty states** use `LampEmpty`. **Toasts** use `LumaToast`. **Sheets** use `LumaSheet` / `LumaSheetShell`. **Press feedback** uses `LumaPress`.
- **Field seats** (MPO, pharmacy: `LampWorld.field`) have 44dp minimum touch targets, one primary action per screen, and default to the light theme.
- **Portal seats** (manufacturer, bank, regulator: `LampWorld.portal`) are denser, use tables and `LumaAutoGrid` rather than card stacks, and default to the dark theme.
- **Theme:** every screen must work in both themes with **no** `brightness ==` checks. If something looks wrong in one theme, the palette slot is wrong; fix it in the palette.

## 5. Logo
`LampMark(size:)` picks the dark or light asset by theme; pass `mono: true` for photo or coloured backgrounds. It is 38dp in app bars, never below 32dp. Don't recolour, crop, or add effects.

## 6. New-screen checklist
- [ ] Wrapped by `LaMPTheme.build(world, …)` with the right `LampWorld`
- [ ] App bar = `LumaAppBar` + `LampBlockPip` + `LampSeatMenu`; no unlabelled icon buttons
- [ ] Every text style is a `LaMPType.*` name
- [ ] Every colour is a `context.lamp.*` slot
- [ ] Spacing is only `Gap.*`
- [ ] Ledger data uses a receipt footer; counts use ticks
- [ ] Checked in light and dark at 360×800 (add the screen to `test/layout_test.dart`)
- [ ] `flutter analyze` and `flutter test` (including `design_lint_test.dart`) pass
