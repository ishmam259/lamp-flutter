import 'package:flutter/foundation.dart';
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
import 'package:lamp_flutter/widgets/demo_director_sheet.dart';
import 'package:lamp_flutter/widgets/ledger_inspector_sheet.dart';

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

/// A device to lay out against.
///
/// Three, deliberately. A 360x800 Android is the narrow end of the platform,
/// where horizontal overflow shows up first. The iPhone SE is *shorter* than
/// anything Android in this list — 667 logical points against 800 — so it is
/// the one that catches content running off the bottom, which is how the demo
/// sheet hid its own reset button. The 15 Pro is the common modern size and
/// the one with a home indicator eating the bottom inset.
typedef Device = ({String name, Size size, double dpr, TargetPlatform platform});

const List<Device> _devices = [
  (name: 'android 360x800', size: Size(1080, 2400), dpr: 3.0, platform: TargetPlatform.android),
  (name: 'iPhone SE 375x667', size: Size(750, 1334), dpr: 2.0, platform: TargetPlatform.iOS),
  (name: 'iPhone 15 Pro 393x852', size: Size(1179, 2556), dpr: 3.0, platform: TargetPlatform.iOS),
];

Future<List<String>> _sweep(
  WidgetTester tester, {
  required Widget screen,
  required LampWorld world,
  required Brightness brightness,
  required int tabCount,
  required String label,
  required Device device,
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

  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = device.dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Drives the platform-dependent parts of layout: iOS uses different page
  // transitions, scroll physics and default typography metrics, and any of the
  // three can change where a line wraps.
  // Reset before the sweep returns, not in a tearDown: the test binding
  // asserts every foundation debug variable is back to null at the end of the
  // test body, which runs first.
  debugDefaultTargetPlatformOverride = device.platform;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LaMPState()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: MaterialApp(
        theme: LaMPTheme.build(world, brightness),
        home: MediaQuery(
          // The notch and the home indicator. Without them the test lays out
          // against a taller window than the phone actually offers, which is
          // precisely the margin a bottom-anchored button lives in.
          data: MediaQueryData(
            size: device.size / device.dpr,
            devicePixelRatio: device.dpr,
            padding: device.platform == TargetPlatform.iOS
                ? const EdgeInsets.only(top: 47, bottom: 34)
                : const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: screen,
        ),
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
  debugDefaultTargetPlatformOverride = null;
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
    for (final device in _devices) {
      for (final brightness in Brightness.values) {
        testWidgets('${entry.key} on ${device.name} (${brightness.name})',
            (tester) async {
        final problems = await _sweep(
          tester,
          screen: entry.value.build(),
          world: entry.value.world,
          brightness: brightness,
          tabCount: entry.value.tabs,
          device: device,
          label: '${entry.key}/${device.name}/${brightness.name}',
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

  // The sheets are pages too. The first version of this sweep walked the six
  // screens and stopped there, so the demo director and the ledger inspector
  // went unchecked while the suite reported that every page had been covered.
  final sheets = <String, Widget Function()>{
    'demo director': () => const DemoDirectorSheet(),
    'ledger inspector': () => const LedgerInspectorSheet(),
  };

  for (final entry in sheets.entries) {
    for (final device in _devices) {
      for (final brightness in Brightness.values) {
        testWidgets('${entry.key} sheet on ${device.name} (${brightness.name})',
            (tester) async {
        final problems = await _sweep(
          tester,
          // A sheet is opened from a screen, so it is pumped inside a Scaffold
          // rather than as a bare widget — it inherits a Material ancestor and
          // the same bounded width it gets in the app.
          screen: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: entry.value(),
            ),
          ),
          world: LampWorld.portal,
          brightness: brightness,
          tabCount: 1,
          device: device,
          label: '${entry.key}/${device.name}/${brightness.name}',
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
}
