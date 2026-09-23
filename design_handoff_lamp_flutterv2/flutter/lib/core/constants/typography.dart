import 'package:flutter/material.dart';

/// The LaMP type system. The only place a font size, weight or tracking value
/// may be written. Screens pick a named style and `copyWith(color: …)` —
/// nothing else.
///
/// Families (registered in pubspec.yaml):
///   * AnekLatin + AnekBangla — one superfamily, shared metrics, so an English
///     and a Bengali pharmacy name sit on the same baseline. The taka sign ৳
///     only exists in the Bangla half, which is why it is the fallback.
///   * IBMPlexMono — ONLY for things compared down a column: money, hashes,
///     tx ids, block numbers, carton codes, and the uppercase eyebrow label.
///     Never for names, subtitles or prose.
///
/// Scale  sans 12.5 · 14 · 15 · 16 · 20      mono 11 · 12.5 · 15 · 22 · 28
/// Weights 400 · 500 · 600 only (no w700 / bold anywhere).
/// Floor   11. Nothing smaller, ever.
/// Tracking −0.02em at ≥20 · 0 at 12.5–16 · +0.12em on uppercase labels.
class LaMPType {
  static const String sans = 'AnekLatin';
  static const String bengali = 'AnekBangla';
  static const String mono = 'IBMPlexMono';
  static const List<String> fallback = <String>[bengali];

  static const TextStyle _sans = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const TextStyle _mono = TextStyle(
    fontFamily: mono,
    fontFamilyFallback: fallback,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /* ── Sans ─────────────────────────────────────────────────────────── */

  /// 20 · w600 — screen title. One per screen.
  static const TextStyle title = TextStyle(
    fontFamily: sans, fontFamilyFallback: fallback,
    fontSize: 20, height: 1.2, fontWeight: FontWeight.w600,
    letterSpacing: -0.02 * 20,
  );

  /// 16 · w600 — section heads, card titles.
  static final TextStyle head =
      _sans.copyWith(fontSize: 16, height: 1.3, fontWeight: FontWeight.w600);

  /// 15 · w500 — list primaries, button labels.
  static final TextStyle sub =
      _sans.copyWith(fontSize: 15, height: 1.35, fontWeight: FontWeight.w500);

  /// 14 · w400 — body copy.
  static final TextStyle body = _sans.copyWith(fontSize: 14, height: 1.5);

  /// 12.5 · w500 — tabs, nav labels, chip text, snackbars, secondary lines.
  static final TextStyle meta =
      _sans.copyWith(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500);

  /// 12.5 · w400 — captions under a row; people's names in dense tables.
  static final TextStyle caption = _sans.copyWith(fontSize: 12.5, height: 1.45);

  /// Aliases kept so existing call sites compile. Prefer the names above.
  static final TextStyle small = caption;
  static final TextStyle micro = caption; // 11 is reserved for mono labels.

  /* ── Mono ─────────────────────────────────────────────────────────── */

  /// 28 · w600 — the one hero figure on a dashboard.
  static final TextStyle displayFigure = _mono.copyWith(
      fontSize: 28, height: 1.05, fontWeight: FontWeight.w600,
      letterSpacing: -0.02 * 28);

  /// 22 · w600 — a figure quoted in a card (৳ amounts, counts).
  static final TextStyle figure = _mono.copyWith(
      fontSize: 22, height: 1.1, fontWeight: FontWeight.w600,
      letterSpacing: -0.02 * 22);

  /// 15 · w500 — money / ids in a table column.
  static final TextStyle monoBody =
      _mono.copyWith(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500);

  /// 12.5 — hashes, carton codes inline.
  static final TextStyle monoCaption = _mono.copyWith(fontSize: 12.5, height: 1.4);

  /// 11 · w500 · +0.12em — UPPERCASE eyebrow labels and the receipt footer.
  /// Pass text already uppercased.
  static final TextStyle label = _mono.copyWith(
      fontSize: 11, height: 1.4, fontWeight: FontWeight.w500,
      letterSpacing: 0.12 * 11);

  /// 11 — receipt footer (`BLK 1204 · tx 9f3a…c21e`). Not uppercased.
  static final TextStyle monoMicro = _mono.copyWith(fontSize: 11, height: 1.4);

  /// Material slots, so any widget that doesn't name a style still lands in
  /// the system.
  static TextTheme textTheme(Color ink, Color ink2) => TextTheme(
        displayLarge: displayFigure.copyWith(color: ink),
        displayMedium: figure.copyWith(color: ink),
        displaySmall: title.copyWith(color: ink),
        headlineLarge: title.copyWith(color: ink),
        headlineMedium: title.copyWith(color: ink),
        headlineSmall: head.copyWith(color: ink),
        titleLarge: title.copyWith(color: ink),
        titleMedium: head.copyWith(color: ink),
        titleSmall: sub.copyWith(color: ink),
        bodyLarge: sub.copyWith(color: ink),
        bodyMedium: body.copyWith(color: ink),
        bodySmall: caption.copyWith(color: ink2),
        labelLarge: sub.copyWith(fontWeight: FontWeight.w600, color: ink),
        labelMedium: meta.copyWith(color: ink2),
        labelSmall: label.copyWith(color: ink2),
      );
}

/// Radii, each with a job. Control < card < surface so nesting reads as depth.
class LaMPRadius {
  static const double control = 10; // buttons, inputs, chips you press
  static const double card = 16; // things that hold content
  static const double surface = 20; // sheets, dialogs — things that arrive
  static const double pill = 999; // status chips, tracks, grabber
}
