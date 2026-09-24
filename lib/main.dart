import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/palette.dart';
import 'core/state/lamp_state.dart';
import 'core/state/theme_controller.dart';
import 'features/bank/bank_screen.dart';
import 'features/launcher/launcher_screen.dart';
import 'features/manufacturer/manufacturer_screen.dart';
import 'features/mpo/mpo_screen.dart';
import 'features/pharmacy/pharmacy_screen.dart';
import 'features/regulator/regulator_screen.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LaMPState()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const LaMPApp(),
    ),
  );
}

class LaMPApp extends StatelessWidget {
  const LaMPApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The launcher is a portal surface; each persona re-themes itself to its
    // own world on entry. Both brightnesses are supplied so the app can follow
    // the phone, and so the toggle has somewhere to switch to.
    final themeMode = context.watch<ThemeController>().mode;

    return MaterialApp(
      title: 'LaMP — Last Mile Pharmacy',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: LaMPTheme.build(LampWorld.portal, Brightness.light),
      darkTheme: LaMPTheme.build(LampWorld.portal, Brightness.dark),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          /// Bound the system font scale.
          ///
          /// These are dense financial screens — a 25-row carton manifest, a
          /// credit history table — laid out against a fixed type scale. A
          /// device set to 130% was breaking words mid-syllable ("Paracetamol /
          /// ") and overflowing rows. Clamping respects someone who has
          /// turned text up without letting the instrument panel come apart;
          /// the floor stops a device set small from rendering 9px hashes.
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  PersonaId? _activePersona;

  /// How long to wait before admitting the app is loading at all.
  ///
  /// Platform guidance on both sides is that a launch screen should disappear
  /// as soon as possible and is not a branding opportunity — extending one
  /// makes an app measurably slower in order to look more considered. A
  /// restored world parses in tens of milliseconds, so showing a splash for it
  /// would be a flash, which is worse than showing nothing.
  ///
  /// So nothing is shown for the first quarter second. Seeding a fresh world
  /// takes longer than that and earns the splash; restoring does not and skips
  /// it entirely, going straight from the platform's own launch screen to the
  /// launcher.
  static const Duration _showSplashAfter = Duration(milliseconds: 250);

  /// Once it *has* appeared, hold it long enough to be read.
  ///
  /// The other half of the same problem: a splash that appears and vanishes in
  /// 80ms reads as a glitch, and its entrance animation is caught mid-flight.
  static const Duration _minimumSplashVisible = Duration(milliseconds: 650);

  bool _handedOver = false;
  bool _splashShowing = false;
  DateTime? _splashShownAt;
  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();

    final state = context.read<LaMPState>();
    if (state.isInitialized) {
      _handedOver = true;
      return;
    }

    state.addListener(_onWorldChanged);
    _showTimer = Timer(_showSplashAfter, () {
      if (!mounted || _handedOver) return;
      setState(() {
        _splashShowing = true;
        _splashShownAt = DateTime.now();
      });
    });
  }

  void _onWorldChanged() {
    if (!mounted) return;
    final state = context.read<LaMPState>();
    if (!state.isInitialized) return;

    state.removeListener(_onWorldChanged);
    _showTimer?.cancel();

    // Never appeared: hand over now, and the platform splash was the whole
    // launch experience — which is the intended outcome for a restore.
    if (!_splashShowing) {
      setState(() => _handedOver = true);
      return;
    }

    final shownFor = DateTime.now().difference(_splashShownAt!);
    final remaining = _minimumSplashVisible - shownFor;
    if (remaining <= Duration.zero) {
      setState(() => _handedOver = true);
    } else {
      _hideTimer = Timer(remaining, () {
        if (mounted) setState(() => _handedOver = true);
      });
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toLauncher() => setState(() => _activePersona = null);

  @override
  Widget build(BuildContext context) {
    // Seats are swapped by setState rather than pushed, so the navigator only
    // ever holds one route. Without this, the system back gesture found
    // nothing to pop and closed the app from inside a persona — which reads as
    // a crash, not as navigation.
    //
    // canPop is true only on the launcher, where leaving the app is what back
    // should do. Anywhere else it is intercepted and returns to the launcher,
    // matching the arrow in the app bar.
    // Three states, not two: handed over, showing the splash, or showing
    // nothing yet because the load may still turn out to be instant. That last
    // one is what stops a fast restore from flashing a splash it did not need.
    final phase = context.watch<LaMPState>().loadPhase;

    return PopScope(
      canPop: _activePersona == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toLauncher();
      },
      // Cross-fade rather than cut. The splash has just finished its own
      // entrance; replacing it in a single frame throws that away.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: switch ((_handedOver, _splashShowing)) {
          (true, _) => _seat(),
          (false, true) => SplashScreen(
              key: const ValueKey('splash'),
              phase: phase,
            ),
          // Loading, but not for long enough to say so yet. The platform's own
          // launch screen is still the last thing drawn, so holding its ground
          // colour here is continuous rather than blank.
          (false, false) => ColoredBox(
              key: const ValueKey('quiet'),
              color: context.lamp.bg,
              child: const SizedBox.expand(),
            ),
        },
      ),
    );
  }

  Widget _seat() {
    return KeyedSubtree(
      key: const ValueKey('app'),
      child: switch (_activePersona) {
        null => LauncherScreen(
            onSelectPersona: (p) => setState(() => _activePersona = p),
          ),
        PersonaId.mpo => MpoScreen(onBackToLauncher: _toLauncher),
        PersonaId.pharmacy => PharmacyScreen(onBackToLauncher: _toLauncher),
        PersonaId.manufacturer =>
          ManufacturerScreen(onBackToLauncher: _toLauncher),
        PersonaId.bank => BankScreen(onBackToLauncher: _toLauncher),
        PersonaId.regulator => RegulatorScreen(onBackToLauncher: _toLauncher),
      },
    );
  }
}
