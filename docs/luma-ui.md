# The Luma layer

This branch rebuilds LaMP's presentation on the techniques behind
[lu.ma](https://lu.ma) — a web product whose interface quality is usually
credited to taste and is mostly the result of specific engineering decisions.

Luma's own stack is React, Next.js and styled-jsx on the web, with native
Swift and Kotlin clients on mobile. None of that ports to a Flutter app, and
copying it would mean throwing this one away. What ports is the layer
underneath: the reasons those choices were made, and the behaviour they buy.
Each of them has a Flutter equivalent, and this branch is those equivalents.

Everything new lives in `lib/core/design/`. Nothing there knows anything about
receivables, cartons or the ledger — it is a design system, and it would drop
into another app unchanged.

---

## What was ported, and what it became

| Luma does | in CSS / Swift | here |
| --- | --- | --- |
| No webfont — the OS typeface | `-apple-system, "Segoe UI", Roboto, …` | `LaMPType.sansCascade` in [`typography.dart`](../lib/core/constants/typography.dart) |
| Components size to their own box | `container-type: inline-size` + `@container` | `LumaContainer` / `context.lumaWidth` |
| Fluid columns with no breakpoints | `repeat(auto-fit, minmax(200px, 1fr))` | `LumaAutoGrid` |
| Frosted bars and headers | `backdrop-filter: blur(20px) saturate(180%)` | `LumaFrost`, `LumaAppBar` |
| Sheets measured against the visible screen | `100dvh` | `LumaSheetShell` |
| Animate only what the compositor owns | `transform`, `opacity`, `filter` | `LumaMotion`, `LumaPress` |
| Form state without listeners | `:focus-within`, `:invalid` | `inputDecorationTheme` in `app_theme.dart` |
| Optimistic UI, confirmed by touch | instant mutation + `UIImpactFeedbackGenerator` | `LumaToast`, `LumaHaptics` |
| Layered elevation | two-shadow `box-shadow` | `LumaElevation` |

---

## The five that changed the most

### 1. The interface font is the device's own

IBM Plex Sans is no longer bundled. Text is set in San Francisco on an iPhone,
Roboto on a Pixel, Segoe UI on Windows.

On the web this is a latency argument — no WOFF2 round trip, no flash of
unstyled text. In a Flutter app the font was already in the bundle, so that
argument does not carry. The one that does: every native surface the app
cannot re-skin — the share sheet, the keyboard, permission dialogs, the
scanner's own prompts — is already set in the system face. An app with its own
sans is in a slightly different voice from all of them, and that mismatch
reads as *being in an app* rather than *on a phone*.

The cost, taken knowingly: iOS and Android no longer look identical, and
screenshots from one will not match the other. Luma makes that trade on
purpose.

IBM Plex **Mono** stays bundled. A ledger's money and hashes have to align
down a column, and the system monospace is Courier on one platform and missing
on another.

### 2. Components measure themselves, not the window

`MediaQuery.sizeOf` answers a question components rarely mean to ask. A seat
card gets about 328dp on a phone and about 288dp in a two-up grid on a small
tablet — screen width puts the *smaller* box on the *larger* device.

`LumaContainer` publishes the measured width of its own subtree, so a
component reads the box it will actually be handed, and the threshold it
compares against is its own:

```dart
final stacked = context.lumaContainerWidth < 300;
```

300 is a fact about that card's contents — an icon, two lines and a chevron
stop fitting on one line below it — and means nothing to any other component.
That is exactly what `@container (min-width: …)` is for, and why it is written
per-component rather than against a shared breakpoint.

### 3. Column counts are computed, not declared

`LumaAutoGrid` is `repeat(auto-fit, minmax(min, 1fr))`, arithmetic included:
`n = floor((available + gap) / (min + gap))`. The launcher names no screen
size; it gets one column on a phone and two or three on a tablet because that
is how many fit.

It does not use `IntrinsicHeight` to equalise row heights, and cannot: every
cell contains a `LayoutBuilder`, which refuses to answer an intrinsic query.
`_RenderGridRow` lays each row out twice instead — once loose to find the
tallest cell, once tight to stretch the rest — because *laying out* is not the
same as *asking*, and a `LayoutBuilder` is happy to be laid out twice.

### 4. The bars are glass

`LumaFrost` is `blur(20px) saturate(180%)`. The saturation is the half people
leave off and the half that does the work: blur alone averages everything
behind the bar toward grey, so a frosted header over a coloured card looks
like a frosted header over nothing.

Every screen sets `extendBodyBehindAppBar: true`, because there has to be
something behind the glass. The scroll views take their top inset from
`lumaScrollPadding(context)`, which reads the padding the Scaffold folds into
the body's `MediaQuery` — correct for a bar with a tab strip, and correct on a
device with a notch, without either number appearing in a screen.

### 5. Confirmation is a pill and a haptic, not a slab

`SnackBar` is the wrong shape for optimistic UI. It queues, so the second
confirmation arrives four seconds after the action that caused it, and it is
heavy enough that firing one per tap becomes noise.

`LumaToast` replaces the newest with the newest — the latest thing is the true
thing — and pairs with three haptics named for what happened rather than how
hard they buzz: `select` for a tap taken, `commit` (two beats) for something
written to the ledger, `reject` for a refusal.

---

## Working in it

- Colour still comes from `context.lamp`. The palette is unchanged; this
  branch changes shape, type, motion and depth, not hue.
- Radii grew: 6/10/14 → 10/14/20, plus `LaMPRadius.pill`. The ratio between
  them is what matters and is unchanged.
- Animate with `Transform`, `Opacity` and `ImageFilter`. Animating a width, a
  padding or a flex relayouts the subtree on every frame; durations and curves
  come from `LumaMotion`, which also honours "reduce motion".
- `LumaPress` for anything card-sized. Keep `InkWell` for list rows, where a
  ripple has a short distance to travel and still reads.

## Verifying it

`test/layout_test.dart` sweeps every screen and tab at three phone sizes in
both themes and fails on a `RenderFlex` overflow. Run it before claiming a
layout change works:

```bash
flutter test
```

Shortening the portal tab labels on this branch made two tabs reachable that
the sweep had been silently failing to tap, which surfaced four pre-existing
overflows in the manufacturer's tracking tab. They are fixed here.
