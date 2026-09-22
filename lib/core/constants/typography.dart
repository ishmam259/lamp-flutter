import 'package:flutter/material.dart';

/// The LaMP type scale.
///
/// Ported from `app/globals.css` in the Next.js application, and then moved
/// up one step on this branch. The web numbers were set for a desktop portal
/// read at 60cm on a 1440px display; carried to a phone unchanged they gave a
/// 14px body and a 17px section head, which is a spreadsheet, not an
/// interface. Luma sets a phone at roughly 15/16 for body and list primaries
/// and 19-24 for anything that heads a section, with the leading to match.
///
/// One step, not three: this is still a ledger, and the figures still have to
/// fit three across a 360dp card. The layout sweep in `test/layout_test.dart`
/// is what holds that line.
///
/// Two families, each with a job. The interface face carries prose and
/// headings. IBM Plex Mono carries anything a person compares down a column:
/// money, hashes, transaction ids, block numbers, invoice codes. That split is
/// the whole typographic idea, and mixing them at random is what makes an
/// instrument panel look like a brochure.
///
/// ## The interface face is the device's own
///
/// This used to be IBM Plex Sans, bundled. It is now the platform's system
/// typeface, which is the single most consequential thing Luma does to its
/// type and the one most often mistaken for a font choice rather than an
/// engineering one. Their CSS ships no webfont at all:
///
/// ```css
/// -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Inter,
/// "Helvetica Neue", Arial, "Noto Sans", sans-serif
/// ```
///
/// The web argument is about latency — no WOFF2 round trip, so no flash of
/// unstyled text and no layout shift. That argument is weaker in a Flutter app
/// where the font is in the bundle already. The argument that carries over,
/// and the reason this branch follows it, is the other one: text set in San
/// Francisco on an iPhone and in Roboto on a Pixel is text that *matches the
/// operating system it is sitting in*. Every native control the app cannot
/// re-skin — the share sheet, the keyboard's autocorrect bar, the permission
/// dialogs, the scanner's own prompts — is already set in that face. An app
/// with its own sans is in a slightly different voice from all of them, and
/// the mismatch is felt as being in an app rather than on a phone even by
/// someone who could not name what changed.
///
/// There is a real cost, taken knowingly: the app no longer looks identical on
/// iOS and Android, and screenshots taken on one will not match the other.
/// That is the trade Luma makes on purpose — native over uniform.
class LaMPType {
  /// The interface font cascade, in the platform order.
  ///
  /// Flutter resolves these left to right and silently skips a family the
  /// device does not have, which is exactly the CSS behaviour. San Francisco
  /// answers on Apple hardware, Segoe UI on Windows, Roboto on Android; the
  /// tail is there for desktop Linux and the web build. Nothing in the list is
  /// bundled, so every entry either resolves instantly or costs nothing.
  static const List<String> sansCascade = <String>[
    '.SF Pro Text', // iOS / macOS, the name the engine registers it under
    'SF Pro Text',
    'Segoe UI', // Windows
    'Roboto', // Android
    'Inter',
    'Helvetica Neue',
    'Arial',
    'Noto Sans',
    bengali, // last, so Latin never resolves here — see below
  ];

  static const String mono = 'IBMPlexMono';
  static const String bengali = 'NotoSansBengali';

  /// Bengali has no coverage in IBM Plex, and the taka sign (৳ U+09F3) is in
  /// none of the Latin faces. Listing Noto as a fallback keeps Latin resolving
  /// from Plex and takes only the missing glyphs from a face we chose, rather
  /// than whatever the device happens to ship.
  static const List<String> fallback = <String>[bengali];

  /// No `fontFamily`, only a cascade.
  ///
  /// With the primary left null the engine walks `fontFamilyFallback` in
  /// order and lands on the system default if none of them resolve — which is
  /// the correct outcome and the same one the CSS `sans-serif` keyword gives.
  static const TextStyle _base = TextStyle(
    fontFamilyFallback: sansCascade,
  );

  /// 30 — the largest figure, for a dashboard tile.
  static final TextStyle displayFigure = _base.copyWith(
    fontFamily: mono,
    fontSize: 30,
    height: 1.05,
    letterSpacing: -0.03 * 30,
    fontWeight: FontWeight.w600,
  );

  /// 24 — a figure quoted inline in a card.
  static final TextStyle figure = _base.copyWith(
    fontFamily: mono,
    fontSize: 24,
    height: 1.1,
    letterSpacing: -0.025 * 24,
    fontWeight: FontWeight.w600,
  );

  /// 24 — screen titles.
  ///
  /// Negative tracking grows with size, as it must: letter-spacing that reads
  /// as normal at 14 reads as loose at 24, which is why large type set at
  /// default tracking always looks slightly amateur.
  static final TextStyle title = _base.copyWith(
    fontSize: 24,
    height: 1.18,
    letterSpacing: -0.024 * 24,
    fontWeight: FontWeight.w600,
  );

  /// 19 — section heads and card titles.
  static final TextStyle head = _base.copyWith(
    fontSize: 19,
    height: 1.28,
    letterSpacing: -0.018 * 19,
    fontWeight: FontWeight.w600,
  );

  /// 16 — list primaries. The line a person is actually reading down.
  static final TextStyle sub = _base.copyWith(
    fontSize: 16,
    height: 1.4,
    letterSpacing: -0.01 * 16,
  );

  /// 15 — body copy, at the leading prose wants rather than the leading a
  /// table wants.
  static final TextStyle body = _base.copyWith(fontSize: 15, height: 1.55);

  /// 13 — dense rows.
  static final TextStyle small = _base.copyWith(fontSize: 13, height: 1.5);

  /// 13 — captions and secondary metadata. Twelve was under the floor at
  /// which a subtitle is read rather than skipped.
  static final TextStyle caption = _base.copyWith(fontSize: 13, height: 1.45);

  /// 11 — the smallest readable step.
  static final TextStyle micro = _base.copyWith(fontSize: 11, height: 1.45);

  /// The eyebrow label. Kept uppercase and tracked out because that is what
  /// the LaMP system specifies for field labels in both worlds.
  static final TextStyle label = _base.copyWith(
    fontFamily: mono,
    fontSize: 10.5,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.11 * 10.5,
  );

  /// Monospace body, for hashes, ids and money set in a column.
  static final TextStyle monoBody = _base.copyWith(
    fontFamily: mono,
    fontSize: 13,
    height: 1.5,
  );

  static final TextStyle monoCaption = _base.copyWith(
    fontFamily: mono,
    fontSize: 12,
    height: 1.4,
  );

  /// Material's slots, filled from the scale above so anything that does not
  /// name a style explicitly still lands inside the system.
  static TextTheme textTheme(Color ink, Color ink2) => TextTheme(
    displayLarge: title.copyWith(fontSize: 32, height: 1.1, letterSpacing: -0.03 * 32, color: ink),
    displayMedium: title.copyWith(fontSize: 28, height: 1.15, letterSpacing: -0.028 * 28, color: ink),
    displaySmall: title.copyWith(color: ink),
    headlineLarge: title.copyWith(color: ink),
    headlineMedium: head.copyWith(fontSize: 19, color: ink),
    headlineSmall: head.copyWith(color: ink),
    titleLarge: head.copyWith(color: ink),
    titleMedium: sub.copyWith(fontWeight: FontWeight.w600, color: ink),
    titleSmall: small.copyWith(fontWeight: FontWeight.w600, color: ink),
    bodyLarge: sub.copyWith(color: ink),
    bodyMedium: body.copyWith(color: ink),
    bodySmall: caption.copyWith(color: ink2),
    labelLarge: small.copyWith(fontWeight: FontWeight.w600, color: ink),
    labelMedium: caption.copyWith(color: ink2),
    labelSmall: label.copyWith(color: ink2),
  );
}

/// The radii, each with a job — from the same system.
///
/// There were twelve before it was cut down, which reads as unconsidered at
/// close range however carefully the rest is set.
///
/// The three that survived have all grown on this branch — 6/10/14 became
/// 10/14/20 — because the old set was tuned for a dense web table and reads as
/// severe on a phone held at arm's length. The ratio between them is what
/// matters and it is unchanged: a control is rounder than its own corner
/// suggests, a card is rounder than the control inside it, and a sheet is
/// rounder than the card, so nesting reads as depth rather than as three
/// rectangles of slightly different sharpness.
class LaMPRadius {
  /// Chips, inputs, buttons — things you touch.
  static const double control = 10;

  /// Panels and cards — things that hold content.
  static const double card = 16;

  /// Drawers, sheets, modals — things that arrive.
  static const double surface = 20;

  /// Fully round: toasts, progress tracks, the grabber, a status dot's
  /// container. Not a size — a shape, and never used on anything holding more
  /// than one line.
  static const double pill = 999;
}
