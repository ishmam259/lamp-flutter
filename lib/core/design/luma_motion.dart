import 'package:flutter/material.dart';

/// Motion, on the terms Luma sets for it.
///
/// Luma's rule is stated as a CSS one — animate only `transform`, `opacity`
/// and `filter`, because those are the three the compositor can run without
/// asking the layout engine anything. The Flutter translation is the same rule
/// with different words: animate with [Transform], [Opacity] and [ImageFilter],
/// never by animating a width, a padding, a flex or a font size. A `Container`
/// that grows over 200ms relayouts its subtree sixty times; a `Transform.scale`
/// over the same 200ms is one matrix the raster thread already knows how to
/// apply.
///
/// So this file is two short lists — how long, and on what curve — and one
/// helper that turns both off when the person has asked the OS for less
/// motion. Screens name a duration from here instead of inventing 180.
class LumaMotion {
  /// A press, a hover, a chip toggling. Below ~100ms a transition reads as a
  /// cut; above ~150ms a press feels like it is lagging the finger.
  static const Duration instant = Duration(milliseconds: 120);

  /// The default. Cards settling, values counting over, toasts arriving.
  static const Duration base = Duration(milliseconds: 220);

  /// A section changing under a tab, a list reflowing.
  static const Duration slow = Duration(milliseconds: 320);

  /// A drawer or sheet travelling most of the screen. Long enough that the eye
  /// can follow the thing from where it was to where it lands, which is the
  /// entire point of animating a sheet rather than cutting to it.
  static const Duration sheet = Duration(milliseconds: 420);

  /// The house curve: fast out of the gate, long settle.
  ///
  /// This is `cubic-bezier(0.16, 1, 0.3, 1)` — the ease-out-expo that gives
  /// Luma's drawers their particular feel of arriving rather than sliding.
  /// Most of the distance is covered in the first third of the duration, so
  /// the interface reads as immediate while the tail does the softening.
  static const Curve enter = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Leaving is quicker and more linear than arriving. Nobody needs to watch
  /// something they have dismissed decelerate.
  static const Curve exit = Cubic(0.4, 0.0, 1.0, 1.0);

  /// Symmetric moves — a cross-fade, a value changing in place.
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// A press-down. No overshoot: a control that bounces under the finger
  /// reads as loose.
  static const Curve press = Curves.easeOutCubic;

  /// How far a pressable surface travels under a finger.
  ///
  /// Scale rather than colour, because scale is a transform and a hover tint
  /// is a repaint — and because on a card the size of a seat tile a 2% squeeze
  /// is felt more than it is seen, which is the right ratio for feedback.
  static const double pressScale = 0.975;

  /// Respect the OS "reduce motion" setting.
  ///
  /// Flutter surfaces it as [MediaQueryData.disableAnimations]. Everything
  /// here routes through this, so honouring the setting is the default and
  /// forgetting it would take effort.
  static Duration duration(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// The app's page transition: fade up, on the compositor.
///
/// Material's default on Android is `ZoomPageTransitionsBuilder`, which is a
/// fine transition and not this one. Luma's view changes are a short rise and
/// a fade — no zoom, no shadow sweep — so a route change reads as the same
/// surface continuing rather than a new window opening over the old.
///
/// Both properties animated here are compositor-only.
class LumaPageTransitions extends PageTransitionsBuilder {
  const LumaPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: LumaMotion.enter,
      reverseCurve: LumaMotion.exit,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        // 2% of the page height, not 20. The rise is there to give the fade a
        // direction, not to be noticed on its own.
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
