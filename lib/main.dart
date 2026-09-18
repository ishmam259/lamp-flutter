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
          /// device set to 130% was breaking words mid-syllable ("Paracetam /
          /// ol") and overflowing rows. Clamping respects someone who has
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
    // Hold on the splash until the world is seeded. isInitialized existed and
    // nothing read it, so the launcher rendered a block height of zero and
    // then visibly corrected itself.
    final ready = context.watch<LaMPState>().isInitialized;

    return PopScope(
      canPop: _activePersona == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toLauncher();
      },
      // Cross-fade rather than cut. The splash has just finished its own
      // entrance; replacing it in a single frame throws that away.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: !ready
            ? const SplashScreen(key: ValueKey('splash'))
            : _seat(),
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
