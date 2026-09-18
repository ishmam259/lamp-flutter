import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lamp_flutter/core/constants/app_theme.dart';
import 'package:lamp_flutter/core/constants/palette.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/state/theme_controller.dart';
import 'package:lamp_flutter/features/bank/bank_screen.dart';
import 'package:lamp_flutter/features/launcher/launcher_screen.dart';
import 'package:lamp_flutter/features/manufacturer/manufacturer_screen.dart';
import 'package:lamp_flutter/features/mpo/mpo_screen.dart';
import 'package:lamp_flutter/features/pharmacy/pharmacy_screen.dart';
import 'package:lamp_flutter/features/regulator/regulator_screen.dart';

/// Every screen, every tab, in both themes, at the size of a real phone.
///
/// This exists because the layout defects in this app were only ever found by
/// looking at it — a RenderFlex overflow is painted as a striped banner and
/// logged, but it throws nothing and fails no test, so a suite can be entirely
/// green over a screen that is visibly broken. Driving the device by hand found
/// them one at a time and took about twenty minutes a pass.
///
/// The harness below installs its own FlutterError handler, walks each tab of
/// each persona, and reports the overflow instead of letting it paint quietly.
/// A 360x800 viewport is deliberately small: it is a cheap phone, which is what
/// a delivery officer in Bogura is actually holding.

/// Logical 360x800 — the narrow end of Android, where things break first.
const Size _phone = Size(1080, 2400);
const double _dpr = 3.0;

Future<List<String>> _sweep(
  WidgetTester tester, {
  required Widget screen,
  required LampWorld world,
  required Brightness brightness,
  required int tabCount,
  required String label,
}) async {
  final problems = <String>[];

  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final text = details.exceptionAsString();
    // Overflow is the class of defect this sweep is for. Everything else is
    // re-thrown so a genuine crash is not swallowed by a layout check.
    if (text.contains('overflowed')) {
      // The message alone says how far it overflowed but not what did it. The
      // library's own diagnostics carry the offending widget and the source
      // line, which is the part that makes this actionable.
      final dump = details.toDiagnosticsNode().toStringDeep();
      final where = dump.split('\n').firstWhere(
            (l) => l.contains('.dart:'),
            orElse: () => dump
                .split('\n')
                .firstWhere((l) => l.contains('widget was'), orElse: () => '?'),
          );
      problems.add('$label: ${text.split('\n').first}  <- ${where.trim()}');
    } else {
      previous?.call(details);
    }
  };

  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LaMPState()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: MaterialApp(
        theme: LaMPTheme.build(world, brightness),
        home: screen,
      ),
    ),
  );

  // The world seeds asynchronously; without settling, every screen is still
  // showing its spinner and the sweep proves nothing.
  await tester.pumpAndSettle(const Duration(seconds: 2));

  for (var i = 0; i < tabCount; i++) {
    if (i > 0) {
      final tabs = find.byType(Tab);
      if (tabs.evaluate().length > i) {
        await tester.tap(tabs.at(i), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }
    // Scroll the tab to its end, so content below the fold is built and
    // measured rather than never mounted.
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -2000));
      await tester.pumpAndSettle();
    }
  }

  FlutterError.onError = previous;
  return problems;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final screens = <String, ({Widget Function() build, LampWorld world, int tabs})>{
    'launcher': (
      build: () => LauncherScreen(onSelectPersona: (_) {}),
      world: LampWorld.portal,
      tabs: 1,
    ),
    'mpo': (
      build: () => MpoScreen(onBackToLauncher: () {}),
      world: LampWorld.field,
      tabs: 4,
    ),
    'pharmacy': (
      build: () => PharmacyScreen(onBackToLauncher: () {}),
      world: LampWorld.field,
      tabs: 4,
    ),
    'manufacturer': (
      build: () => ManufacturerScreen(onBackToLauncher: () {}),
      world: LampWorld.portal,
      tabs: 3,
    ),
    'bank': (
      build: () => BankScreen(onBackToLauncher: () {}),
      world: LampWorld.portal,
      tabs: 3,
    ),
    'regulator': (
      build: () => RegulatorScreen(onBackToLauncher: () {}),
      world: LampWorld.portal,
      tabs: 1,
    ),
  };

  for (final entry in screens.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('${entry.key} lays out on a 360x800 phone (${brightness.name})',
          (tester) async {
        final problems = await _sweep(
          tester,
          screen: entry.value.build(),
          world: entry.value.world,
          brightness: brightness,
          tabCount: entry.value.tabs,
          label: '${entry.key}/${brightness.name}',
        );

        expect(
          problems,
          isEmpty,
          reason: 'Layout overflowed:\n${problems.join('\n')}',
        );
      });
    }
  }
}
