import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';
import 'typography.dart';

/// Builds the app's themes from a [LampPalette].
///
/// Everything visual resolves from the palette — surfaces, text, buttons,
/// dividers, sheets, the system status bar. A screen should never need to
/// name a colour to look right, and never need a `brightness == dark` branch.
class LaMPTheme {
  static ThemeData build(LampWorld world, Brightness brightness) {
    final p = LampPalette.resolve(world, brightness);
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    // The field apps sit closer to the eye and take more air; the portals are
    // instrument panels and earn their density.
    final dense = world == LampWorld.portal;

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[p],
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      primaryColor: p.brand,
      dividerColor: p.line,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: (brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
        brightness: brightness,
        primary: p.brand,
        onPrimary: p.onBrand,
        secondary: p.verified,
        onSecondary: p.onBrand,
        surface: p.surface,
        onSurface: p.ink,
        surfaceContainerHighest: p.surfaceAlt,
        outline: p.lineStrong,
        outlineVariant: p.line,
        error: p.dispute,
        onError: Colors.white,
      ),

      textTheme: LaMPType.textTheme(p.ink, p.inkMuted),

      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: LaMPType.head.copyWith(color: p.ink),
        iconTheme: IconThemeData(color: p.ink, size: IconSize.lg),
        // Status-bar icons have to invert with the theme or they vanish into
        // the bar on one of the two.
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: p.surface,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: p.surface,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),

      iconTheme: IconThemeData(color: p.inkMuted, size: IconSize.md),

      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.card),
          side: BorderSide(color: p.line),
        ),
      ),

      // 48dp minimum on Android, so every primary control clears the touch
      // target floor without each screen having to remember.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onBrand,
          disabledBackgroundColor: p.surfaceSunken,
          disabledForegroundColor: p.inkFaint,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: EdgeInsets.symmetric(horizontal: dense ? Gap.lg : Gap.xl),
          textStyle: LaMPType.sub.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaMPRadius.control),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.brand,
          side: BorderSide(color: p.lineStrong),
          minimumSize: const Size(0, 48),
          padding: EdgeInsets.symmetric(horizontal: dense ? Gap.lg : Gap.xl),
          textStyle: LaMPType.sub.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaMPRadius.control),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          minimumSize: const Size(0, 44),
          textStyle: LaMPType.small.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.brand,
        unselectedLabelColor: p.inkFaint,
        labelStyle: LaMPType.small.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: LaMPType.small,
        indicatorColor: p.brand,
        dividerColor: p.line,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.brandSoft,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: IconSize.md,
            color: s.contains(WidgetState.selected) ? p.brand : p.inkFaint,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => LaMPType.micro.copyWith(
            fontWeight:
                s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? p.brand : p.inkFaint,
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: LaMPType.head.copyWith(color: p.ink),
        contentTextStyle: LaMPType.body.copyWith(color: p.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.surface),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LaMPRadius.surface),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: LaMPType.small.copyWith(color: p.bg),
        actionTextColor: p.brand,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        side: BorderSide(color: p.line),
        labelStyle: LaMPType.caption.copyWith(color: p.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearTrackColor: p.surfaceSunken,
        circularTrackColor: p.surfaceSunken,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onBrand : p.inkFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.brand : p.surfaceSunken,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        hintStyle: LaMPType.body.copyWith(color: p.inkFaint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
          borderSide: BorderSide(color: p.brand, width: 2),
        ),
      ),
    );
  }

  /// The theme for a world, following whatever brightness is already in force.
  static ThemeData of(BuildContext context, LampWorld world) =>
      build(world, Theme.of(context).brightness);
}
