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
/// The surface tokens of whichever world a widget happens to be inside.
///
/// Shared widgets — the lifecycle rail, the private seal, the recourse dial —
/// are dropped into both worlds, and each of them had the field palette
/// hardcoded: `Colors.black12` circles and `Colors.black38` labels. In a light
/// field app that is correct. On a dark portal card it is invisible, which is
/// how the rail came to show "Delivered" and "Financed" as barely-there grey.
///
/// Resolving from the ambient Theme means a widget asks which world it is in
/// rather than assuming, and there is exactly one place to change either
/// palette.
class LaMPSurface {
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color line;
  final Color surface;
  final Color muted;

  const LaMPSurface({
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.surface,
    required this.muted,
  });

  static const LaMPSurface portal = LaMPSurface(
    ink: LaMPColors.portalInk,
    ink2: LaMPColors.portalInk2,
    ink3: LaMPColors.portalInk3,
    line: LaMPColors.portalLine2,
    surface: LaMPColors.portalSurface2,
    muted: LaMPColors.portalSurface3,
  );

  static const LaMPSurface field = LaMPSurface(
    ink: LaMPColors.fieldInk,
    ink2: LaMPColors.fieldInk2,
    ink3: LaMPColors.fieldInk3,
    line: LaMPColors.fieldLine2,
    surface: LaMPColors.fieldSurface2,
    muted: LaMPColors.fieldSurface3,
  );

  static LaMPSurface of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? portal : field;
}

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
