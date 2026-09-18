import 'package:flutter/material.dart';

/// The LaMP type scale.
///
/// Ported from `app/globals.css` in the Next.js application, which is the
/// system of record — the sizes, line heights and tracking here are the same
/// numbers, so the phone and the web portals set type identically.
///
/// Two families, each with a job. IBM Plex Sans carries prose and headings.
/// IBM Plex Mono carries anything a person compares down a column: money,
/// hashes, transaction ids, block numbers, invoice codes. That split is the
/// whole typographic idea, and mixing them at random is what makes an
/// instrument panel look like a brochure.
///
/// Both are bundled rather than fetched, so the demo does not need a network.
class LaMPType {
  static const String sans = 'IBMPlexSans';
  static const String mono = 'IBMPlexMono';
  static const String bengali = 'NotoSansBengali';

  /// Bengali has no coverage in IBM Plex, and the taka sign (৳ U+09F3) is in
  /// none of the Latin faces. Listing Noto as a fallback keeps Latin resolving
  /// from Plex and takes only the missing glyphs from a face we chose, rather
  /// than whatever the device happens to ship.
  static const List<String> fallback = <String>[bengali];

  static const TextStyle _base = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: fallback,
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

  /// 22 — screen and card titles.
  static final TextStyle title = _base.copyWith(
    fontSize: 22,
    height: 1.22,
    letterSpacing: -0.022 * 22,
    fontWeight: FontWeight.w600,
  );

  /// 17 — section heads.
  static final TextStyle head = _base.copyWith(
    fontSize: 17,
    height: 1.32,
    letterSpacing: -0.016 * 17,
    fontWeight: FontWeight.w600,
  );

  /// 15 — lead paragraphs and list primaries.
  static final TextStyle sub = _base.copyWith(
    fontSize: 15,
    height: 1.45,
    letterSpacing: -0.008 * 15,
  );

  /// 14 — body copy.
  static final TextStyle body = _base.copyWith(fontSize: 14, height: 1.55);

  /// 13 — dense rows.
  static final TextStyle small = _base.copyWith(fontSize: 13, height: 1.5);

  /// 12 — captions and secondary metadata.
  static final TextStyle caption = _base.copyWith(fontSize: 12, height: 1.5);

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
    fontSize: 11.5,
    height: 1.45,
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

/// The three radii, each with a job — from the same system.
///
/// There were twelve before it was cut down, which reads as unconsidered at
/// close range however carefully the rest is set.
class LaMPRadius {
  /// Chips, inputs, buttons — things you touch.
  static const double control = 6;

  /// Panels and cards — things that hold content.
  static const double card = 10;

  /// Drawers, sheets, modals — things that arrive.
  static const double surface = 14;
}
