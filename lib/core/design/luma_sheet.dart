import 'package:flutter/material.dart';

import '../constants/palette.dart';
import '../constants/typography.dart';
import 'luma_container.dart';
import 'luma_frost.dart';
import 'luma_motion.dart';

/// The drawer, which is the component Luma is known for.
///
/// Two ideas are borrowed here. The first is the arrival: the sheet travels on
/// an ease-out-expo rather than Material's decelerate, so it covers most of
/// the distance immediately and settles, instead of gliding at a constant
/// speed and stopping. The second is `100dvh` — the sheet is measured against
/// the height the screen actually has right now, not a height it had before
/// the keyboard came up or the browser chrome retracted. On a phone the
/// keyboard is the whole of that problem: a sheet sized to 88% of the window
/// puts its primary button under the keyboard the moment a field takes focus.
///
/// The header is glass, so content scrolling under the title stays faintly
/// visible instead of disappearing at a hard edge.
class LumaSheet {
  /// Opens a sheet and returns whatever it pops with.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    String? subtitle,
    List<Widget> actions = const [],

    /// Fraction of the available height the sheet may occupy. Not of the
    /// window — of what is left after the keyboard and the system bars, which
    /// is the distinction `dvh` exists to make.
    double maxHeightFraction = 0.9,

    /// A sheet that is exactly as tall as its content, for a short
    /// confirmation. The fraction above is still a ceiling.
    bool fitContent = false,
    bool dismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.44),
      // Material's own sheet curve is `decelerate` over 250ms. This is the
      // house curve, and the extra time is affordable because most of it is
      // spent in the settle rather than the travel.
      sheetAnimationStyle: AnimationStyle(
        curve: LumaMotion.enter,
        duration: LumaMotion.sheet,
        reverseCurve: LumaMotion.exit,
        reverseDuration: LumaMotion.slow,
      ),
      builder: (ctx) => LumaSheetShell(
        title: title,
        subtitle: subtitle,
        actions: actions,
        maxHeightFraction: maxHeightFraction,
        fitContent: fitContent,
        child: Builder(builder: builder),
      ),
    );
  }

  /// Opens a sheet that builds its own [LumaSheetShell].
  ///
  /// [show] takes a static title, which is the common case and the wrong one
  /// for a sheet whose header changes — the demo controls put the world clock
  /// up there, and it ticks. Those build the shell themselves, inside their
  /// own `watch`, and use this for the route options alone.
  static Future<T?> showOwnShell<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool dismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.44),
      sheetAnimationStyle: AnimationStyle(
        curve: LumaMotion.enter,
        duration: LumaMotion.sheet,
        reverseCurve: LumaMotion.exit,
        reverseDuration: LumaMotion.slow,
      ),
      builder: builder,
    );
  }
}

/// The chrome every sheet gets: grabber, frosted header, `dvh` ceiling.
///
/// Exposed on its own so an existing sheet widget can adopt the shell without
/// being rewritten to go through [LumaSheet.show].
class LumaSheetShell extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final double maxHeightFraction;
  final bool fitContent;

  const LumaSheetShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.maxHeightFraction = 0.9,
    this.fitContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final media = MediaQuery.of(context);

    // The dvh calculation. `size.height` is the window; subtracting the
    // keyboard leaves the part of it a person can actually see, which is what
    // the sheet should be a fraction of.
    final visible = media.size.height - media.viewInsets.bottom;
    final maxHeight = visible * maxHeightFraction;

    final radius = BorderRadius.vertical(
      top: Radius.circular(LaMPRadius.surface),
    );

    return Padding(
      // Lift the whole sheet clear of the keyboard rather than letting it
      // overlap. A field halfway down a sheet is otherwise typed into blind.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radius,
            border: Border(top: BorderSide(color: c.line)),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 40,
                spreadRadius: -8,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            // A sheet is a query root of its own: it is narrower than the
            // screen on a tablet, and a card inside it should lay out for the
            // sheet, not for the window behind it.
            child: LumaContainer(
              child: Column(
                mainAxisSize: fitContent ? MainAxisSize.min : MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Grabber(color: c.lineStrong),
                  if (title != null) _Header(title: title!, subtitle: subtitle, actions: actions),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  final Color color;

  const _Grabber({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm, bottom: 2),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const _Header({required this.title, this.subtitle, required this.actions});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    return LumaFrost(
      blur: 24,
      opacity: 0.8,
      border: Border(bottom: BorderSide(color: c.line)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: LaMPType.head.copyWith(color: c.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: LaMPType.caption.copyWith(color: c.inkFaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            ...actions,
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              iconSize: IconSize.md,
              color: c.inkFaint,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
