import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// The two worlds.
///
/// LaMP splits its surfaces on an axis that is a product decision, not a user
/// preference:
///
///   **portal** — the institutional instrument panels (manufacturer, bank,
///   regulator). Dark, dense, quiet, for people who sit in front of them all
///   day.
///
///   **field** — the two field applications (MPO, pharmacy). Light, always,
///   because a rider reading a phone in Bangladeshi sun is not expressing a
///   preference.
///
/// Each persona screen wraps itself in one of these. Before they existed each
/// screen called `ThemeData.dark().copyWith(...)`, which quietly discarded the
/// application font and left every screen in the platform default.
class LaMPTheme {
  static ThemeData portal() => _build(
    brightness: Brightness.dark,
    ground: LaMPColors.portalGround,
    surface: LaMPColors.portalSurface,
    ink: LaMPColors.portalInk,
    ink2: LaMPColors.portalInk2,
    line: LaMPColors.portalLine,
  );

  static ThemeData field() => _build(
    brightness: Brightness.light,
    ground: LaMPColors.fieldGround,
    surface: LaMPColors.fieldSurface,
    ink: LaMPColors.fieldInk,
    ink2: LaMPColors.fieldInk2,
    line: LaMPColors.fieldLine,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color ground,
    required Color surface,
    required Color ink,
    required Color ink2,
    required Color line,
  }) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();

    return base.copyWith(
      scaffoldBackgroundColor: ground,
      primaryColor: LaMPColors.brand,
      dividerColor: line,
      colorScheme: (brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
        primary: LaMPColors.brand,
        secondary: LaMPColors.verified,
        surface: surface,
        error: LaMPColors.dispute,
      ),
      textTheme: LaMPType.textTheme(ink, ink2),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: LaMPType.head.copyWith(color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.card),
          side: BorderSide(color: line),
        ),
      ),
      // One radius per job, so nothing is rounded by accident.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LaMPColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: LaMPType.small.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaMPRadius.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LaMPColors.brand,
          side: const BorderSide(color: LaMPColors.brand),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: LaMPType.small.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaMPRadius.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LaMPColors.brand,
          textStyle: LaMPType.small.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: LaMPColors.brand,
        unselectedLabelColor: ink2,
        labelStyle: LaMPType.small.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: LaMPType.small,
        indicatorColor: LaMPColors.brand,
        dividerColor: line,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: LaMPType.head.copyWith(color: ink),
        contentTextStyle: LaMPType.body.copyWith(color: ink2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.surface),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? LaMPColors.portalSurface3
            : LaMPColors.fieldInk,
        contentTextStyle: LaMPType.small.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
