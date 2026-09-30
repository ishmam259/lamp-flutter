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
        ChangeNotifierProvider(create: (_) => ThemeController(ThemeMode.dark)),
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

/// The pay button on the Overview. It carries the amount — `Pay ৳1,82,400`
/// — so it is matched on its shape, not a fixed label.
final Finder _payCta = find.textContaining(RegExp(r'^Pay ৳'));

/// The bank checks the invoice PDF and records it. The chaincode refuses an
/// advance without it, and the bank's Finance button stays held back until it
/// is done, so any test that finances has to do this first.
///
/// The PDF is rendered afresh here, well after the seed minted the invoice:
/// that it still matches the hash taken at mint is the point.
Future<void> _anchor(LaMPState state, String tokenId) async {
  final pdf = await state.generateInvoicePdf(tokenId);
  final res = await state.anchorInvoiceDocument(
    tokenId,
    Msp.meghnaMSP,
    sha256: pdf.sha256,
    byteLength: pdf.bytes.length,
    filename: pdf.filename,
  );
  expect(res.ok, isTrue, reason: res.error);
}

Future<void> _tapTab(WidgetTester tester, int index) async {
  // Every seat navigates from the bottom bar now.
  final tabs = find.byType(NavigationDestination);
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
        await _pump(tester, () => const PharmacyScreen());

        // The hero consignment is CREATED at demo start: minted, not yet
        // delivered. The screen used to show "Pay now" against it.
        expect(_payCta, findsNothing);
        expect(
          find.text('You can pay once the delivery is confirmed.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('offers to pay once the ledger records the delivery',
        (tester) async {
      final state =
          await _pump(tester, () => const PharmacyScreen());

      final me = SeedData.pharmacies[0].did;
      final view = state.openForPharmacy(me).first;
      await state.drainScanQueue(
        view.tokenId,
        view.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await _settle(tester);

      expect(state.getToken(view.tokenId)!.state, TokenState.delivered);
      expect(_payCta, findsOneWidget);
    });

    testWidgets('a settled invoice leaves "To pay" (report #2)',
        (tester) async {
      final state =
          await _pump(tester, () => const PharmacyScreen());

      final me = SeedData.pharmacies[0].did;
      final view = state.openForPharmacy(me).first;
      await state.drainScanQueue(
        view.tokenId,
        view.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await _settle(tester);
      expect(_payCta, findsOneWidget);

      final settle = await state.settleReceivable(
        view.tokenId,
        view.token.declaredValue,
        'bKash',
      );
      expect(settle.ok, isTrue, reason: settle.error);
      await _settle(tester);

      // Gone from the list, and said to be gone rather than silently absent.
      expect(_payCta, findsNothing);
      expect(find.text('Nothing outstanding'), findsOneWidget);
      expect(state.openForPharmacy(me), isEmpty);
    });

    testWidgets('financing does not discharge the debt', (tester) async {
      final state =
          await _pump(tester, () => const PharmacyScreen());

      final me = SeedData.pharmacies[0].did;
      final view = state.openForPharmacy(me).first;
      await state.drainScanQueue(
        view.tokenId,
        view.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      state.advanceHours(25); // close the objection period
      await _anchor(state, view.tokenId);
      final financed =
          await state.financeReceivable(view.tokenId, Msp.meghnaMSP);
      expect(financed.ok, isTrue, reason: financed.error);
      await _settle(tester);

      // The screen used to call this "Nothing to settle". A bank advancing
      // against the receivable pays the manufacturer; the pharmacy still owes.
      expect(state.getToken(view.tokenId)!.state, TokenState.financed);
      expect(_payCta, findsOneWidget);
      expect(find.text('Nothing outstanding'), findsNothing);
    });

    testWidgets('the invoice in "To pay" is not listed again under Recent',
        (tester) async {
      await _pump(tester, () => const PharmacyScreen());
      // The hero invoice is the one "To pay" shows. Recent used to list every
      // invoice for this counter, so it appeared twice.
      expect(find.text('INV-00235'), findsOneWidget);
      expect(find.text('TO PAY'), findsOneWidget);
    });

    testWidgets('a tier held down by late payments does not claim no history',
        (tester) async {
      final probe = await _pump(tester, () => const SizedBox());
      final held = SeedData.pharmacies.firstWhere((p) {
        final credit = probe.creditFor(p.did);
        return credit != null &&
            credit.cycles.isNotEmpty &&
            credit.lateCount >= 2 &&
            credit.tier == RecourseTier.newTier;
      });

      await _pump(tester, () => PharmacyScreen(pharmacyDid: held.did));
      expect(find.textContaining('No on-chain history'), findsNothing);
      expect(find.textContaining('late payments hold this'), findsOneWidget);
    });

    testWidgets('disputes: only a delivery inside its window can be reported',
        (tester) async {
      final state = await _pump(tester, () => const PharmacyScreen());
      await _tapTab(tester, 3);

      // Nothing has arrived yet: nothing to report, and no button that would
      // dispute "the first open invoice" regardless.
      expect(find.textContaining('Nothing to report'), findsOneWidget);
      expect(find.text('Report a problem'), findsOneWidget); // the heading

      final me = SeedData.pharmacies[0].did;
      final view = state.openForPharmacy(me).first;
      await state.drainScanQueue(
        view.tokenId,
        view.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await _settle(tester);
      expect(find.byKey(ValueKey('dispute-${view.tokenId}')), findsOneWidget);

      // The window closes 24 hours after delivery; the button goes with it.
      state.clock.advanceHours(25);
      state.notifyListeners();
      await _settle(tester);
      expect(find.byKey(ValueKey('dispute-${view.tokenId}')), findsNothing);
      expect(find.textContaining('Nothing to report'), findsOneWidget);
    });

    testWidgets('disputes: the reason is asked for and the result is honest',
        (tester) async {
      final state = await _pump(tester, () => const PharmacyScreen());
      final me = SeedData.pharmacies[0].did;
      final view = state.openForPharmacy(me).first;
      await state.drainScanQueue(
        view.tokenId,
        view.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await _tapTab(tester, 3);

      await tester.tap(find.byKey(ValueKey('dispute-${view.tokenId}')));
      await _settle(tester);
      expect(find.text('What went wrong?'), findsOneWidget);
      await tester.tap(find.text('Cartons missing'));
      await _settle(tester);
      await tester.tap(find.text('Report problem'));
      await _settle(tester);

      final token = state.getToken(view.tokenId)!;
      expect(token.state, TokenState.disputed);
      expect(token.disputeReason, startsWith('Cartons missing'));
      expect(find.text('UNDER REVIEW'), findsOneWidget);
    });
  });

  group('Signed-in seat', () {
    testWidgets("a second pharmacy sees its own invoices, not the first one's",
        (tester) async {
      final probe = LaMPState();
      await tester.runAsync(() async {
        while (!probe.isInitialized) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      // Any pharmacy other than the first that owes something.
      final other = SeedData.pharmacies.skip(1).firstWhere(
            (p) => probe.openForPharmacy(p.did).isNotEmpty,
          );

      final state = await _pump(
        tester,
        () => PharmacyScreen(pharmacyDid: other.did),
      );
      final own = state.openForPharmacy(other.did).first.token.invoiceId;
      final first = state.openForPharmacy(SeedData.pharmacies[0].did).first.token.invoiceId;

      expect(find.text(other.name), findsOneWidget);
      expect(find.text(own), findsWidgets);
      expect(find.text(first), findsNothing);
    });
  });

  group('Bank', () {
    testWidgets('a financed receivable leaves the financing queue (report #3)',
        (tester) async {
      final state = await _pump(
        tester,
        () => const BankScreen(),
        world: LampWorld.portal,
      );

      final target =
          state.tokenViews.firstWhere((v) => v.token.isFinanceable(state.now));
      // Finance is held back until the invoice PDF is anchored.
      await _anchor(state, target.tokenId);
      await _settle(tester);

      // Section titles are eyebrows, set in capitals.
      expect(find.text('READY TO FINANCE'), findsOneWidget);
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
      // Below the fold in a lazily built list: scroll to it as a person would.
      await tester.scrollUntilVisible(
        find.text('RECENTLY FINANCED'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('RECENTLY FINANCED'), findsOneWidget);
    });

    testWidgets('an undelivered receivable is not in the queue at all',
        (tester) async {
      final state = await _pump(
        tester,
        () => const BankScreen(),
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
      final state = await _pump(tester, () => const MpoScreen());

      final route = state.routeFor(SeedData.mpos[0].id);
      expect(route.length, greaterThan(1));
      // One stop is open; every other one is listed under it.
      expect(find.text('STOP 1 OF ${route.length}'), findsOneWidget);
      for (final stop in route) {
        expect(find.text(stop.pharmacy!.name), findsOneWidget,
            reason: '${stop.pharmacy!.name} missing from the round');
      }
    });

    testWidgets('a signed-for stop leaves the route (report #4)',
        (tester) async {
      final state = await _pump(tester, () => const MpoScreen());

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
      final state = await _pump(tester, () => const MpoScreen());
      await _tapTab(tester, 2); // Sign

      final stop = state.routeFor(SeedData.mpos[0].id).first;
      expect(stop.token.scanned, 0);

      expect(
        find.text('Scan all ${stop.token.declaredCartons} cartons before signing'),
        findsOneWidget,
      );

      // `ElevatedButton.icon` is a private subclass, so match on the base.
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Confirm delivery'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull, reason: 'the submit button is live');
    });

    testWidgets('the sign gate opens on what the ledger holds, not the UI',
        (tester) async {
      final state = await _pump(tester, () => const MpoScreen());
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
      final state = await _pump(tester, () => const MpoScreen());
      final stop = state.routeFor(SeedData.mpos[0].id).first;
      final lines = stop.invoice!.lineItems;

      for (final line in lines) {
        expect(
          find.text('${line.name} ${line.strength}'),
          findsOneWidget,
          reason: '${line.name} ${line.strength} missing from the manifest',
        );
        expect(find.text(line.sku), findsOneWidget);
      }
    });
  });
}
