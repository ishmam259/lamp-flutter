import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/luma_motion.dart';
import '../state/theme_controller.dart';
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
    // The family goes on the base, not only the text theme: buttons, tabs
    // and the nav bar build their labels from Material's own typography and
    // would otherwise land on Roboto.
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: LaMPType.sans,
      fontFamilyFallback: LaMPType.fallback,
    );

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

      // Every route change in the app is the same rise-and-fade, on every
      // platform, because a seat swap should read as the same surface
      // continuing rather than as Android's zoom on one device and iOS's
      // horizontal push on another.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: LumaPageTransitions(),
          TargetPlatform.iOS: LumaPageTransitions(),
          TargetPlatform.macOS: LumaPageTransitions(),
          TargetPlatform.windows: LumaPageTransitions(),
          TargetPlatform.linux: LumaPageTransitions(),
          TargetPlatform.fuchsia: LumaPageTransitions(),
        },
      ),

      colorScheme: (brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
        brightness: brightness,
        primary: p.brand,
        onPrimary: p.onBrand,
        // Not `verified`: Material paints selected segments, chips and
        // toggles from `secondary`, and mint is reserved for what the
        // ledger confirmed. A selected control is a choice, not a fact.
        secondary: p.brand,
        onSecondary: p.onBrand,
        secondaryContainer: p.brandSoft,
        onSecondaryContainer: p.ink,
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
        // Transparent by default now: `LumaAppBar` paints a blurred pane in
        // `flexibleSpace`, and a solid background here would sit in front of
        // it and there would be nothing to see through.
        backgroundColor: Colors.transparent,
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
                systemNavigationBarColor: p.bg,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: p.bg,
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
          textStyle: LaMPType.caption.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.brand,
        unselectedLabelColor: p.inkFaint,
        labelStyle: LaMPType.caption.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: LaMPType.caption,
        indicatorColor: p.brand,
        dividerColor: p.line,
      ),

      navigationBarTheme: NavigationBarThemeData(
        // Transparent, because the pharmacy's bar is wrapped in `LumaFrost`
        // and the list scrolls underneath it. A solid colour here would put
        // an opaque plate in front of the glass.
        backgroundColor: Colors.transparent,
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
          (s) => LaMPType.caption.copyWith(
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
        contentTextStyle: LaMPType.caption.copyWith(color: p.bg),
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
        // A status badge is a word, never a container, so it takes the pill
        // rather than the control radius — the shape itself says "this is a
        // state, not something you press".
        shape: const StadiumBorder(),
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

      // Form state, declared once.
      //
      // The CSS version of this idea is `:focus-within`, `:invalid` and
      // `:out-of-range` — the browser tracks the state and the stylesheet
      // reacts, with no listener anywhere. Flutter's equivalent is that the
      // framework already knows whether a field is focused or has an error,
      // and `InputDecorationTheme` is where that knowledge is spent. Every
      // field in the app gets a focus ring and an error state from here, so
      // no screen writes a FocusNode listener to colour a border.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        hintStyle: LaMPType.body.copyWith(color: p.inkFaint),
        errorStyle: LaMPType.caption.copyWith(color: p.dispute),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
          borderSide: BorderSide(color: p.dispute),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
          borderSide: BorderSide(color: p.dispute, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.control),
          borderSide: BorderSide(color: p.line.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  /// The theme for a world.
  ///
  /// An explicit Light or Dark choice applies everywhere. Left on the default,
  /// each world takes its own: field seats are light, for a phone read in
  /// sunlight at a pharmacy door; portals are dark, for a desk.
  static ThemeData of(BuildContext context, LampWorld world) {
    final mode = Provider.of<ThemeController?>(context)?.mode;
    final brightness = mode == ThemeMode.system
        ? defaultBrightness(world)
        : Theme.of(context).brightness;
    return build(world, brightness);
  }

  static Brightness defaultBrightness(LampWorld world) => switch (world) {
        LampWorld.field => Brightness.light,
        LampWorld.portal => Brightness.dark,
      };
}
