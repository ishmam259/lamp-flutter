import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/palette.dart';
import '../constants/typography.dart';
import 'luma_elevation.dart';
import 'luma_motion.dart';
import 'luma_press.dart';

/// What confirmation looks like when the UI is optimistic.
///
/// Luma's rule is that an action never waits on the network to be reflected:
/// the RSVP flips the moment it is tapped, the request goes out behind it, and
/// the socket reconciles later if the server disagreed. The interface has to
/// hold up its end of that bargain — if the state changes instantly, the
/// acknowledgement has to be instant too, or the person taps again.
///
/// Material's `SnackBar` is the wrong shape for this. It is a full-width slab
/// that pushes a floating action button out of the way, it queues (so the
/// second confirmation appears four seconds after the action that caused it),
/// and it is heavy enough that showing one for every tap becomes noise. This
/// is a pill: it arrives in 220ms, it never queues — a new one replaces the
/// old one, because the newest thing is the true thing — and it is small
/// enough to fire on every committed action without the screen feeling busy.
class LumaToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  /// Shows a confirmation. Safe to call from a callback that also mutated
  /// state in the same frame.
  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    LumaToastTone tone = LumaToastTone.neutral,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _dismiss();

    // The palette is read here, from the calling screen's context, rather than
    // inside the overlay — an overlay entry sits above the per-seat `Theme`,
    // so a toast built in there would come out in the launcher's palette while
    // the bank's portal is on screen.
    final palette = context.lamp;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;

    final entry = OverlayEntry(
      builder: (_) => _ToastPill(
        message: message,
        icon: icon,
        tone: tone,
        palette: palette,
        bottomInset: bottomInset,
        onTap: _dismiss,
      ),
    );

    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

enum LumaToastTone { neutral, verified, pending, dispute }

class _ToastPill extends StatefulWidget {
  final String message;
  final IconData? icon;
  final LumaToastTone tone;
  final LampPalette palette;
  final double bottomInset;
  final VoidCallback onTap;

  const _ToastPill({
    required this.message,
    required this.icon,
    required this.tone,
    required this.palette,
    required this.bottomInset,
    required this.onTap,
  });

  @override
  State<_ToastPill> createState() => _ToastPillState();
}

class _ToastPillState extends State<_ToastPill> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    // One frame at zero, then the target — the cheapest way to get an
    // entrance out of implicit animation without an AnimationController for
    // something that lives for two seconds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final accent = switch (widget.tone) {
      LumaToastTone.neutral => p.inkMuted,
      LumaToastTone.verified => p.verified,
      LumaToastTone.pending => p.pending,
      LumaToastTone.dispute => p.dispute,
    };

    final duration = LumaMotion.duration(context, LumaMotion.base);

    return Positioned(
      left: Gap.lg,
      right: Gap.lg,
      bottom: widget.bottomInset + Gap.xl,
      child: IgnorePointer(
        ignoring: _t == 0,
        child: AnimatedOpacity(
          opacity: _t,
          duration: duration,
          curve: LumaMotion.standard,
          child: AnimatedSlide(
            // Compositor-only, like everything else that moves here: the pill
            // rises 16dp worth of its own height and fades. No layout runs.
            offset: Offset(0, (1 - _t) * 0.4),
            duration: duration,
            curve: LumaMotion.enter,
            child: Center(
              child: LumaPress(
                haptic: false,
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.md,
                  ),
                  decoration: BoxDecoration(
                    // Inverted against the page, the way a toast has been
                    // since Android 1.0 — it is the one surface that should
                    // not look like it belongs to the screen underneath.
                    color: p.ink,
                    borderRadius: BorderRadius.circular(999),
                    // The palette is carried in rather than read from this
                    // context, for the same reason the colours above are.
                    boxShadow: LumaElevation.floatingFrom(p.shadow),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: IconSize.sm, color: accent),
                        const SizedBox(width: Gap.sm),
                      ],
                      Flexible(
                        child: Text(
                          widget.message,
                          style: LaMPType.small.copyWith(
                            color: p.bg,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
