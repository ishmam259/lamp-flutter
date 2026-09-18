import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';

/// Loading states that keep the shape of what is coming.
///
/// A centred spinner tells someone that something is happening and nothing
/// else: the screen is blank, then it is full, and the jump between the two is
/// the moment an app feels cheap. A skeleton holds the layout it is about to
/// become, so the content arrives into a space already the right shape and
/// nothing moves when it lands.
///
/// The sweep is a single gradient moving across the placeholders, not one
/// animation per block — many independent shimmers read as noise, and on a
/// cheap phone they cost more than they earn.

/// Drives one shimmer across everything inside it.
class LampShimmer extends StatefulWidget {
  final Widget child;

  const LampShimmer({super.key, required this.child});

  @override
  State<LampShimmer> createState() => _LampShimmerState();
}

class _LampShimmerState extends State<LampShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    // Someone who has asked for less motion gets a flat placeholder. The
    // skeleton still communicates the shape; it just stops moving.
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.0 - 2 * (1 - t), 0),
              end: Alignment(1.0 - 2 * (1 - t), 0),
              colors: [
                c.surfaceSunken,
                Color.alphaBlend(c.inkFaint.withValues(alpha: 0.10), c.surfaceSunken),
                c.surfaceSunken,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// One placeholder block.
class LampSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const LampSkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = LaMPRadius.control,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.lamp.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A card-shaped placeholder: a heading, two lines, and a figure.
class LampSkeletonCard extends StatelessWidget {
  final int lines;

  const LampSkeletonCard({super.key, this.lines = 2});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(LaMPRadius.card),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LampSkeletonBox(width: 40, height: 40, radius: LaMPRadius.card),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LampSkeletonBox(width: 120, height: 14),
                    const SizedBox(height: Gap.sm),
                    LampSkeletonBox(
                      width: 180,
                      height: 10,
                      radius: LaMPRadius.control,
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (var i = 0; i < lines; i++) ...[
            const SizedBox(height: Gap.md),
            // The last line stops short, the way a paragraph actually ends. A
            // stack of identical full-width bars reads as a barcode.
            i == lines - 1
                ? const LampSkeletonBox(width: 140, height: 10)
                : const LampSkeletonBox(width: double.infinity, height: 10),
          ],
        ],
      ),
    );
  }
}

/// The whole-screen loading state.
///
/// Used where a persona is waiting on the seeded world. It mirrors the shape
/// every one of those screens opens with — a summary card, then a short list —
/// so the real content replaces it in place.
class LampLoadingScreen extends StatelessWidget {
  const LampLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LampShimmer(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.xl),
            children: const [
              LampSkeletonCard(lines: 2),
              SizedBox(height: Gap.lg),
              LampSkeletonCard(lines: 1),
              SizedBox(height: Gap.lg),
              LampSkeletonCard(lines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small inline spinner, for an action already in flight.
///
/// A skeleton answers "what is coming"; this answers "your tap is being
/// handled". They are different questions and the wrong one in either place
/// reads as a bug.
class LampBusy extends StatelessWidget {
  final double size;
  final Color? color;

  const LampBusy({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? context.lamp.brand,
      ),
    );
  }
}
