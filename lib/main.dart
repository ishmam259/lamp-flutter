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

  @override
  Widget build(BuildContext context) {
    if (_activePersona == null) {
      return LauncherScreen(
        onSelectPersona: (p) => setState(() => _activePersona = p),
      );
    }

    switch (_activePersona!) {
      case PersonaId.mpo:
        return MpoScreen(onBackToLauncher: () => setState(() => _activePersona = null));
      case PersonaId.pharmacy:
        return PharmacyScreen(onBackToLauncher: () => setState(() => _activePersona = null));
      case PersonaId.manufacturer:
        return ManufacturerScreen(onBackToLauncher: () => setState(() => _activePersona = null));
      case PersonaId.bank:
        return BankScreen(onBackToLauncher: () => setState(() => _activePersona = null));
      case PersonaId.regulator:
        return RegulatorScreen(onBackToLauncher: () => setState(() => _activePersona = null));
    }
  }
}
