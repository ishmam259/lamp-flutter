import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/palette.dart';
import '../constants/typography.dart';
import '../../widgets/lamp_mark.dart';

/// `backdrop-filter: blur(20px) saturate(180%)`.
///
/// The saturation is the half of that rule people leave off, and it is the
/// half that does the work. Blur alone averages everything behind the bar
/// toward grey, so a frosted header over a green card looks like a frosted
/// header over nothing. Pushing saturation back up to 180% restores the colour
/// the blur washed out, and the bar reads as a pane of glass with something
/// coloured underneath rather than as a flat translucent rectangle.
///
/// Both filters run on the compositor. The cost is a saved layer per frosted
/// surface, which is why this is used on the three surfaces that earn it —
/// the app bar, the tab strip, a sheet's header — and not on cards.
class LumaFrost extends StatelessWidget {
  final Widget child;

  /// `blur(Npx)`. 20 on bars; sheets take more, because there is more moving
  /// behind them.
  final double blur;

  /// `saturate(N)`. 1.8 is the rule as written; the whole effect collapses
  /// below about 1.4.
  final double saturation;

  /// How much of the surface colour is laid over the blur. Too opaque and
  /// there is no point blurring; too sheer and text on the bar loses its
  /// contrast against whatever scrolls under it. 0.72 holds 4.5:1 for body
  /// text against every palette in this app.
  final double opacity;

  final Color? tint;
  final BorderRadius? borderRadius;

  /// The hairline that separates the glass from what it is over. Without it
  /// the bar has no edge at all once the content behind it runs out.
  final Border? border;

  const LumaFrost({
    super.key,
    required this.child,
    this.blur = 20,
    this.saturation = 1.8,
    this.opacity = 0.72,
    this.tint,
    this.borderRadius,
    this.border,
  });

  /// The saturation half of the filter, as a colour matrix.
  ///
  /// Luminance-preserving: each channel is pulled toward the pixel's own
  /// brightness by `1 - s`, so `s = 1` is identity and `s = 0` is greyscale.
  /// The weights are Rec. 709, the same ones the CSS filter specification
  /// names for `saturate()`.
  static ColorFilter _saturate(double s) {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final r = (1 - s) * lumR, g = (1 - s) * lumG, b = (1 - s) * lumB;
    return ColorFilter.matrix(<double>[
      r + s, g,     b,     0, 0,
      r,     g + s, b,     0, 0,
      r,     g,     b + s, 0, 0,
      0,     0,     0,     1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final radius = borderRadius ?? BorderRadius.zero;

    return ClipRRect(
      // Unclipped, a BackdropFilter samples the entire layer behind it and
      // then paints only where its child is — the blur leaks past the corners
      // of a rounded sheet as a square of haze.
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.compose(
          outer: _saturate(saturation),
          inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (tint ?? c.surface).withValues(alpha: opacity),
            borderRadius: radius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The app bar, as glass.
///
/// Every persona wrote its own `AppBar` before this — six leading arrows, six
/// title Columns, three different subtitle sizes, and one that set
/// `elevation: 1` so it had a shadow nothing else had. This is that bar once,
/// so the six seats read as one product.
///
/// It is transparent and relies on [Scaffold.extendBodyBehindAppBar] being
/// set, which is what puts the content underneath it to be blurred. Use
/// [lumaScrollPadding] for the body's top inset — the Scaffold adds this bar's
/// height to the body's `MediaQuery` padding, so nothing has to hard-code 56.
class LumaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// The second line — a role, an organisation, a person. Sans: names are
  /// prose, and mono's extra width is what used to truncate them.
  final String? subtitle;

  /// An identifier that follows the subtitle — a device id, an MSP. Set in
  /// mono beside the sans subtitle: same line, two faces, each doing its job.
  final String? subtitleId;

  final Widget? leading;

  /// Width of the [leading] slot. Flutter's default of 56 is too narrow for
  /// the 38dp brand mark once it has its padding.
  final double? leadingWidth;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  const LumaAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleId,
    this.leading,
    this.leadingWidth,
    this.onBack,
    this.actions = const [],
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      // The bar itself draws nothing; the glass behind it draws everything,
      // and it has to cover the status bar too or the top strip is clear while
      // the bar under it is frosted.
      flexibleSpace: LumaFrost(
        border: Border(bottom: BorderSide(color: c.line.withValues(alpha: 0.9))),
        child: const SizedBox.expand(),
      ),
      // A seat is the signed-in user's home, with nothing behind it to go
      // back to, so the slot carries the mark instead of an arrow.
      leadingWidth: leadingWidth ?? (onBack == null ? Gap.lg + 38 + Gap.md : null),
      leading: leading ??
          (onBack == null
              ? const Padding(
                  padding: EdgeInsets.only(left: Gap.lg, right: Gap.md),
                  child: Center(child: LampMark(size: 38)),
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: c.ink,
                  tooltip: 'Back',
                  onPressed: onBack,
                )),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: LaMPType.head.copyWith(color: c.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null || subtitleId != null)
            Text.rich(
              TextSpan(children: [
                if (subtitle != null) TextSpan(text: subtitle),
                if (subtitle != null && subtitleId != null)
                  const TextSpan(text: ' · '),
                if (subtitleId != null)
                  TextSpan(text: subtitleId, style: LaMPType.monoCaption),
              ]),
              style: LaMPType.caption.copyWith(color: c.inkFaint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [...actions, const SizedBox(width: Gap.xs)],
      bottom: bottom,
    );
  }
}

/// The top inset for a scroll view living under a [LumaAppBar].
///
/// With `extendBodyBehindAppBar` the Scaffold folds the bar's height into the
/// body's `MediaQuery` top padding, so reading it back here is both correct
/// for a bar with a tab strip and correct on a device with a notch, without
/// either number appearing in a screen.
EdgeInsets lumaScrollPadding(
  BuildContext context, {
  double horizontal = Gap.lg,
  double top = Gap.md,
  double bottom = Gap.section,
}) {
  final inset = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    horizontal,
    inset.top + top,
    horizontal,
    bottom + inset.bottom,
  );
}
