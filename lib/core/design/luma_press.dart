import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'luma_motion.dart';

/// A pressable surface that answers the finger with a transform.
///
/// Material's answer is the ink ripple: a circle of colour expanding from the
/// touch point, repainted every frame over the whole control. It is a good
/// answer for a list row and the wrong one for a card, where the ripple has to
/// travel a long way and arrives after the finger has gone. Luma's answer is a
/// 2.5% squeeze — the card acknowledges the press at the moment of contact,
/// and the only thing animating is a matrix the compositor already has.
///
/// The haptic goes with it. On a phone the tap is confirmed by the hand before
/// the eye gets there, which is most of why a native app feels faster than a
/// web one doing the same work at the same speed.
class LumaPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far it travels. Small surfaces need more than large ones to read at
  /// all — a chip at 0.975 looks broken rather than pressed.
  final double scale;

  /// Off for a control that already fires its own haptic, so a confirmation
  /// does not arrive as a double tick.
  final bool haptic;

  /// Rounds the hit surface, so a press at the corner of a rounded card is
  /// outside it rather than in the invisible square.
  final BorderRadius? borderRadius;

  const LumaPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = LumaMotion.pressScale,
    this.haptic = true,
    this.borderRadius,
  });

  @override
  State<LumaPress> createState() => _LumaPressState();
}

class _LumaPressState extends State<LumaPress> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool down) {
    if (!_enabled || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () {
        if (widget.haptic) HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: LumaMotion.duration(context, LumaMotion.instant),
        curve: LumaMotion.press,
        // Filtering quality is left alone deliberately: a 2.5% scale on a
        // static subtree does not need resampling, and asking for it would
        // turn a compositor transform into a raster pass.
        child: widget.child,
      ),
    );
  }
}

/// The haptic vocabulary, named by what happened rather than how hard it
/// buzzes.
///
/// Three patterns, used consistently, are legible: a person learns within a
/// session that the short tick means the app took the input and the double
/// means the ledger wrote it. Ten patterns used approximately are noise, which
/// is how most apps end up with haptics turned off in Settings.
class LumaHaptics {
  /// Something was selected, toggled or opened. The lightest tick there is.
  static void select() => HapticFeedback.selectionClick();

  /// A scan landed, a signature took, a step completed.
  static void confirm() => HapticFeedback.mediumImpact();

  /// Money moved, a block was written, a delivery closed out. Two beats, so
  /// the irreversible ones do not feel like the reversible ones.
  static Future<void> commit() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  /// Refused, disputed, out of range.
  static void reject() => HapticFeedback.heavyImpact();
}
