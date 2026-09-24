import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lamp_flutter/core/constants/app_theme.dart';
import 'package:lamp_flutter/core/constants/palette.dart';
import 'package:lamp_flutter/core/models/domain_models.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/state/theme_controller.dart';
import 'package:lamp_flutter/core/world/queries.dart';
import 'package:lamp_flutter/core/world/seed.dart';
import 'package:lamp_flutter/features/bank/bank_screen.dart';
import 'package:lamp_flutter/features/mpo/mpo_screen.dart';
import 'package:lamp_flutter/features/pharmacy/pharmacy_screen.dart';

/// The five defects in `Bug report/Report 01.md`, asserted on screen.
///
/// `world_test.dart` pins the rules; this file pins that the screens obey
/// them. Every one of these was reported by someone holding the phone, so the
/// check that matters is what the phone shows — not what the predicate
/// returns.
///
/// A 360x800 Android viewport, the cheap phone the screenshots came from.
const Size _phone = Size(360, 800);

Future<LaMPState> _pump(
  WidgetTester tester,
  Widget Function() build, {
  LampWorld world = LampWorld.field,
}) async {
  tester.view.physicalSize = _phone * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final state = LaMPState();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LaMPState>.value(value: state),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: MaterialApp(
        theme: LaMPTheme.build(world, Brightness.dark),
        home: build(),
      ),
    ),
  );

  await _settle(tester);
  return state;
}

/// Some screens animate indefinitely; a timeout here is not a failure.
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } on FlutterError {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }
}

Future<void> _tapTab(WidgetTester tester, int index) async {
  final tabs = find.byType(Tab);
  expect(tabs.evaluate().length, greaterThan(index));
  await tester.tap(tabs.at(index), warnIfMissed: false);
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Pharmacy', () {
    testWidgets(
      'does not offer to pay for goods that have not arrived (report #1)',
      (tester) async {
        await _pump(tester, () => PharmacyScreen(onBackToLauncher: () {}));

        // The hero consignment is CREATED at demo start: minted, not yet
        // delivered. The screen used to show "Pay now" against it.
        expect(find.text('Pay now'), findsNothing);
        expect(
          find.text('Payable once the delivery is confirmed on the ledger.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('offers to pay once the ledger records the delivery',
        (tester) async {
      final state =
          await _pump(tester, () => PharmacyScreen(onBackToLauncher: () {}));

      final me = SeedData.pharmacies[0].did;
      final view = state.openForPharmacy(me).first;
      await state.drainScanQueue(
        view.tokenId,
        view.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await _settle(tester);

      expect(state.getToken(view.tokenId)!.state, TokenState.delivered);
      expect(find.text('Pay now'), findsOneWidget);
    });

    testWidgets('a settled invoice leaves "Due now" (report #2)',
        (tester) async {
      final state =
          await _pump(tester, () => PharmacyScreen(onBackToLauncher: () {}));

      final me = SeedData.pharmacies[0].did;
      final view = state.openForPharmacy(me).first;
      await state.drainScanQueue(
        view.tokenId,
        view.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await _settle(tester);
      expect(find.text('Pay now'), findsOneWidget);

      final settle = await state.settleReceivable(
        view.tokenId,
        view.token.declaredValue,
        'bKash',
      );
      expect(settle.ok, isTrue, reason: settle.error);
      await _settle(tester);

      // Gone from the list, and said to be gone rather than silently absent.
      expect(find.text('Pay now'), findsNothing);
      expect(find.text('Nothing outstanding'), findsOneWidget);
      expect(state.openForPharmacy(me), isEmpty);
    });

    testWidgets('financing does not discharge the debt', (tester) async {
      final state =
          await _pump(tester, () => PharmacyScreen(onBackToLauncher: () {}));

      final me = SeedData.pharmacies[0].did;
      final view = state.openForPharmacy(me).first;
      await state.drainScanQueue(
        view.tokenId,
        view.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      state.advanceHours(25); // close the objection period
      final financed =
          await state.financeReceivable(view.tokenId, Msp.meghnaMSP);
      expect(financed.ok, isTrue, reason: financed.error);
      await _settle(tester);

      // The screen used to call this "Nothing to settle". A bank advancing
      // against the receivable pays the manufacturer; the pharmacy still owes.
      expect(state.getToken(view.tokenId)!.state, TokenState.financed);
      expect(find.text('Pay now'), findsOneWidget);
      expect(find.text('Nothing outstanding'), findsNothing);
    });
  });

  group('Bank', () {
    testWidgets('a financed receivable leaves the financing queue (report #3)',
        (tester) async {
      final state = await _pump(
        tester,
        () => BankScreen(onBackToLauncher: () {}),
        world: LampWorld.portal,
      );

      final target =
          state.tokenViews.firstWhere((v) => v.token.isFinanceable(state.now));

      expect(find.text('Eligible for financing'), findsOneWidget);
      expect(
        find.textContaining('Finance ', findRichText: true),
        findsWidgets,
      );

      final before = state.tokenViews
          .where((v) => v.token.isFinanceable(state.now))
          .length;

      final res = await state.financeReceivable(target.tokenId, Msp.meghnaMSP);
      expect(res.ok, isTrue, reason: res.error);
      await _settle(tester);

      // It moved sections rather than staying put with a live button that the
      // chaincode would refuse.
      expect(
        state.tokenViews.where((v) => v.token.isFinanceable(state.now)).length,
        before - 1,
      );
      expect(find.text('Recently financed'), findsOneWidget);
    });

    testWidgets('an undelivered receivable is not in the queue at all',
        (tester) async {
      final state = await _pump(
        tester,
        () => BankScreen(onBackToLauncher: () {}),
        world: LampWorld.portal,
      );

      // The hero invoice is CREATED. It must appear in no section.
      final hero = state.viewFor('RCV-00235')!;
      expect(hero.token.state, TokenState.created);
      expect(find.text(hero.token.invoiceId), findsNothing);
    });
  });

  group('MPO', () {
    testWidgets('the route lists every outstanding stop (report #4)',
        (tester) async {
      final state = await _pump(tester, () => MpoScreen(onBackToLauncher: () {}));

      final route = state.routeFor(SeedData.mpos[0].id);
      expect(route.length, greaterThan(1));
      expect(find.text('Stop 1 of ${route.length}'), findsOneWidget);
      expect(find.text('Stop ${route.length} of ${route.length}'),
          findsOneWidget);
    });

    testWidgets('a signed-for stop leaves the route (report #4)',
        (tester) async {
      final state = await _pump(tester, () => MpoScreen(onBackToLauncher: () {}));

      final route = state.routeFor(SeedData.mpos[0].id);
      final stop = route.first;
      expect(find.text(stop.pharmacy!.name), findsOneWidget);

      await state.drainScanQueue(
        stop.tokenId,
        stop.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await state.confirmDelivery(stop.tokenId, 'signature-stroke');
      await _settle(tester);

      expect(find.text(stop.pharmacy!.name), findsNothing);
      expect(state.routeFor(SeedData.mpos[0].id).length, route.length - 1);
      // And the next stop is now the head of the round.
      expect(find.text(route[1].pharmacy!.name), findsOneWidget);
    });

    testWidgets('cannot sign for goods that were never scanned (report #5)',
        (tester) async {
      final state = await _pump(tester, () => MpoScreen(onBackToLauncher: () {}));
      await _tapTab(tester, 2); // Sign

      final stop = state.routeFor(SeedData.mpos[0].id).first;
      expect(stop.token.scanned, 0);

      expect(
        find.text('Scan all ${stop.token.declaredCartons} cartons before signing'),
        findsOneWidget,
      );

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm Receipt & Submit PoD'),
      );
      expect(button.onPressed, isNull, reason: 'the submit button is live');
    });

    testWidgets('the sign gate opens on what the ledger holds, not the UI',
        (tester) async {
      final state = await _pump(tester, () => MpoScreen(onBackToLauncher: () {}));
      final stop = state.routeFor(SeedData.mpos[0].id).first;

      await state.drainScanQueue(
        stop.tokenId,
        stop.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await _settle(tester);
      await _tapTab(tester, 2);

      expect(
        find.textContaining('cartons before signing'),
        findsNothing,
      );
      // Still gated on the signature itself.
      expect(find.text('Sign above to enable submission'), findsOneWidget);
    });

    testWidgets('the manifest comes from the invoice, not three literals',
        (tester) async {
      final state = await _pump(tester, () => MpoScreen(onBackToLauncher: () {}));
      final stop = state.routeFor(SeedData.mpos[0].id).first;
      final lines = stop.invoice!.lineItems;

      for (final line in lines) {
        expect(
          find.text('${line.name} ${line.strength}...'),
          findsOneWidget,
          reason: '${line.name} ${line.strength} missing from the manifest',
        );
      }
    });
  });
}
