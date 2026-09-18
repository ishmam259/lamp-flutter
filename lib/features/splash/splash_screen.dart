import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../widgets/lamp_mark.dart';

/// First run, while the world seeds.
///
/// There is real work happening behind this: the seeder replays a rate curve
/// for each bank, seven settled credit cycles, and the hero consignment
/// through the chaincode, hashing every carton on the way. That is fast, but
/// it is not instant, and until it finishes the launcher would show a block
/// height of zero and then visibly correct itself.
///
/// So the app holds here and says what it is doing. One orchestrated entrance
/// — the mark settles, the wordmark follows, the line underneath fills — and
/// then it hands over. Nothing repeats or loops for its own sake; a splash
/// that draws attention to itself is a splash that has outstayed its welcome.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // The mark arrives first and settles rather than bouncing; easeOutCubic
  // decelerates without overshoot, which is the difference between confident
  // and cartoonish in a financial app.
  late final Animation<double> _markFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
  );

  late final Animation<double> _markScale = Tween<double>(
    begin: 0.88,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
  ));

  late final Animation<double> _wordFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
  );

  late final Animation<double> _lineFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    // Someone who has asked for less motion gets the finished frame, not the
    // sequence that arrives at it.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Opacity(
                    opacity: _markFade.value,
                    child: Transform.scale(
                      scale: _markScale.value,
                      child: const LampMark(size: 88),
                    ),
                  ),
                ),

                const SizedBox(height: Gap.xl),

                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Opacity(
                    opacity: _wordFade.value,
                    child: Column(
                      children: [
                        Text(
                          'LaMP',
                          style: LaMPType.title.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          'Last Mile Pharmacy',
                          style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // The progress line is indeterminate on purpose. The seeder
                // does not report percentages, and inventing one would be a
                // lie told in a financial interface.
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Opacity(
                    opacity: _lineFade.value,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor: c.surfaceSunken,
                              valueColor: AlwaysStoppedAnimation(c.brand),
                            ),
                          ),
                        ),
                        const SizedBox(height: Gap.md),
                        Text(
                          'Building the ledger',
                          style: LaMPType.caption.copyWith(color: c.inkFaint),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: Gap.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
