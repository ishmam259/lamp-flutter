import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lamp_flutter/core/chain/contract.dart';
import 'package:lamp_flutter/core/chain/ledger.dart';
import 'package:lamp_flutter/core/models/domain_models.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/world/clock.dart';
import 'package:lamp_flutter/core/world/queries.dart';
import 'package:lamp_flutter/core/world/seed.dart';

/// The rules every screen now derives its lists from.
///
/// Each of the five defects in `Bug report/Report 01.md` was a screen offering
/// an action the chaincode was going to refuse, or keeping a row in a list it
/// had already left. The screens ask [TokenQueries] those questions now, so
/// this file is where the answers are pinned.
void main() {
  late LocalLedger ledger;
  late DemoClock clock;
  late List<Invoice> invoices;
  late List<Delivery> deliveries;

  Future<void> buildWorld() async {
    ledger = LocalLedger();
    clock = DemoClock();
    final result = await SeedData.buildWorld(ledger, clock);
    invoices = List<Invoice>.from(result['invoices'] as List);
    deliveries = List<Delivery>.from(result['deliveries'] as List);
  }

  List<TokenView> views() =>
      LaMPQueries.listTokenViews(ledger, invoices, deliveries);

  TokenView viewOf(String tokenId) =>
      views().firstWhere((v) => v.tokenId == tokenId);

  group('Seeded world', () {
    setUp(buildWorld);

    test('carries the TypeScript seed\'s seven pharmacies', () {
      expect(SeedData.pharmacies.length, 7);
      // Every one of them has a credit history to price against.
      for (final p in SeedData.pharmacies) {
        expect(
          LaMPQueries.getCredit(ledger, p.did),
          isNotNull,
          reason: '${p.name} has no credit key',
        );
      }
    });

    test('has more than one consignment in flight', () {
      final all = views();
      // The hero, one settled historical cycle, and five in flight.
      expect(all.length, 7);

      final created =
          all.where((v) => v.token.state == TokenState.created).toList();
      final delivered =
          all.where((v) => v.token.state == TokenState.delivered).toList();

      // Without both sides of this, the bank's queue and the MPO's route each
      // hold one row and nothing can be seen to move between sections.
      expect(created.length, greaterThan(1));
      expect(delivered.length, greaterThan(1));
    });

    test('token views join their invoice, pharmacy and delivery', () {
      final hero = viewOf('RCV-00235');
      expect(hero.invoice, isNotNull);
      expect(hero.pharmacy?.name, 'Rahman Medical Hall');
      expect(hero.delivery, isNotNull);
      expect(hero.invoice!.lineItems, isNotEmpty);
    });

    test('carton hashes are unique across every consignment', () {
      // Two invoices minting an identical GS1 payload would let a carton from
      // one satisfy the other's membership test — the very check the
      // misrouted-carton beat exists to demonstrate.
      final seen = <String>{};
      for (final v in views()) {
        for (final hash in v.token.cartonHashes) {
          expect(seen.add(hash), isTrue, reason: 'duplicate carton hash $hash');
        }
      }
    });
  });

  group('What a pharmacy owes', () {
    setUp(buildWorld);

    test('an undelivered receivable is owed but not payable', () {
      // Report 01 #1: "I have not even received the products but it is showing
      // a bill is due."
      final hero = viewOf('RCV-00235');
      expect(hero.token.state, TokenState.created);
      expect(hero.token.isOpen, isTrue);
      expect(hero.token.isPayable, isFalse);
    });

    test('a financed receivable is still payable', () {
      // The bank advances against the receivable to the manufacturer. It does
      // not discharge the buyer's debt, and `settle` accepts FINANCED.
      final token = viewOf('RCV-00235').token;
      token.state = TokenState.financed;
      expect(token.isPayable, isTrue);
      expect(token.isOpen, isTrue);
    });

    test('a settled receivable leaves the list entirely', () {
      // Report 01 #2: "once paid, the transaction does not disappear."
      final settled =
          views().where((v) => v.token.state == TokenState.settled).toList();
      expect(settled, isNotEmpty);
      for (final v in settled) {
        expect(v.token.isOpen, isFalse);
        expect(v.token.isPayable, isFalse);
      }
    });

    test('a disputed receivable is not payable', () {
      final token = viewOf('RCV-00235').token;
      token.state = TokenState.disputed;
      expect(token.isPayable, isFalse);
    });
  });

  group('What a bank may finance', () {
    setUp(buildWorld);

    test('delivered with the window closed is financeable', () {
      final delivered = views()
          .where((v) => v.token.state == TokenState.delivered)
          .toList();
      expect(delivered, isNotEmpty);

      for (final v in delivered) {
        final closesAt = v.token.disputeWindowClosesAt;
        expect(closesAt, isNotNull);
        // Seeded deliveries are days old, so their objection period has run.
        expect(v.token.isFinanceable(clock.now), isTrue);
        expect(v.token.isAwaitingWindow(clock.now), isFalse);
      }
    });

    test('delivered inside the window is awaiting, not financeable', () {
      final token = views()
          .firstWhere((v) => v.token.state == TokenState.delivered)
          .token;
      // Rewind to one hour after the proof of delivery.
      final justDelivered = token.podAt! + 3600 * 1000;
      expect(token.isFinanceable(justDelivered), isFalse);
      expect(token.isAwaitingWindow(justDelivered), isTrue);
    });

    test('an undelivered receivable is in neither section', () {
      final token = viewOf('RCV-00235').token;
      expect(token.isFinanceable(clock.now), isFalse);
      expect(token.isAwaitingWindow(clock.now), isFalse);
    });

    test('a financed receivable is in neither section', () async {
      // Report 01 #3: "I have financed it, why is it still showing."
      final view =
          views().firstWhere((v) => v.token.isFinanceable(clock.now));
      final res = await ledger.submit(
        fn: 'matchAndAdvance',
        args: {'tokenId': view.tokenId},
        asMsp: Msp.meghnaMSP,
        nowTimestamp: clock.now,
      );
      expect(res.ok, isTrue, reason: res.error);

      final after = viewOf(view.tokenId).token;
      expect(after.state, TokenState.financed);
      expect(after.isFinanceable(clock.now), isFalse);
      expect(after.isAwaitingWindow(clock.now), isFalse);
      expect(after.isFinanced, isTrue);
    });
  });

  group('Delivery confirmation', () {
    setUp(buildWorld);

    test('a consignment is delivered at the 90% threshold', () async {
      // Whitepaper 4.2. The Dart port required every last carton, which left
      // `confirmationThreshold` dead and disagreed with the figure the bank's
      // eligibility checklist prints.
      final view = viewOf('RCV-00235');
      final cartons = view.delivery!.cartons;
      final needed =
          (cartons.length * LaMPContract.confirmationThreshold).ceil();

      for (int i = 0; i < needed; i++) {
        final res = await ledger.submit(
          fn: 'recordPoD',
          args: {
            'tokenId': view.tokenId,
            'cartonHash': cartons[i].hash,
            'mpoSignature': 'sig:test',
          },
          asMsp: Msp.manufacturerMSP,
          nowTimestamp: clock.now,
        );
        expect(res.ok, isTrue, reason: res.error);
      }

      final token = viewOf(view.tokenId).token;
      expect(token.scanned, needed);
      expect(token.scanned, lessThan(token.declaredCartons));
      expect(token.state, TokenState.delivered);
      expect(token.deliveryRatio,
          greaterThanOrEqualTo(LaMPContract.confirmationThreshold));
    });

    test('below the threshold it is only partially fulfilled', () async {
      final view = viewOf('RCV-00235');
      final cartons = view.delivery!.cartons;

      await ledger.submit(
        fn: 'recordPoD',
        args: {
          'tokenId': view.tokenId,
          'cartonHash': cartons.first.hash,
          'mpoSignature': 'sig:test',
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: clock.now,
      );

      final token = viewOf(view.tokenId).token;
      expect(token.state, TokenState.partiallyFulfilled);
      expect(token.isFullyScanned, isFalse);
      expect(token.isPayable, isFalse);
    });

    test('isFullyScanned tracks the ledger, not the off-chain rows', () async {
      final view = viewOf('RCV-00235');
      final hashes = view.delivery!.cartons.map((c) => c.hash).toList();

      expect(view.token.isFullyScanned, isFalse);

      await ledger.submit(
        fn: 'recordPoDBatch',
        args: {
          'tokenId': view.tokenId,
          'cartonHashes': hashes,
          'mpoSignature': 'sig:test',
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: clock.now,
      );

      expect(viewOf(view.tokenId).token.isFullyScanned, isTrue);
    });
  });

  group('The MPO route', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('drops a stop once it is delivered and signed for', () async {
      final state = LaMPState();
      while (!state.isInitialized) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final mpoId = SeedData.mpos[0].id;
      final before = state.routeFor(mpoId);
      // Report 01 #4: "New scans should show up, instead of the previous one
      // just being stuck there." More than one stop, so there is something to
      // move on to.
      expect(before.length, greaterThan(1));

      final stop = before.first;
      final hashes = stop.delivery!.cartons.map((c) => c.hash).toList();

      final scan = await state.drainScanQueue(
        stop.tokenId,
        stop.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      expect(scan.ok, isTrue, reason: scan.error);
      expect(state.getToken(stop.tokenId)!.scannedHashes.length, hashes.length);

      final confirm =
          await state.confirmDelivery(stop.tokenId, 'signature-stroke');
      expect(confirm.ok, isTrue, reason: confirm.error);

      final after = state.routeFor(mpoId);
      expect(after.map((v) => v.tokenId), isNot(contains(stop.tokenId)));
      expect(after.length, before.length - 1);
    });

    test('signing does not erase what the ledger recorded', () async {
      // `confirmDelivery` used to null every `Carton.scannedAt` on success, so
      // the bank — which counts those rows — saw 0 of 25 cartons on a
      // consignment it had just been told was complete.
      final state = LaMPState();
      while (!state.isInitialized) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final stop = state.routeFor(SeedData.mpos[0].id).first;
      await state.drainScanQueue(
        stop.tokenId,
        stop.delivery!.cartons.map((c) => c.gs1).toList(),
        SeedData.mpos[0].deviceId,
      );
      await state.confirmDelivery(stop.tokenId, 'signature-stroke');

      final delivery = state.getDelivery(stop.tokenId)!;
      expect(
        delivery.cartons.where((c) => c.scannedAt != null).length,
        delivery.cartons.length,
      );
      expect(state.getToken(stop.tokenId)!.isFullyScanned, isTrue);
    });
  });

  group('Settlement result', () {
    setUp(buildWorld);

    test('carries the tier either side, which the banner reads', () async {
      final view = viewOf('RCV-00235');
      await ledger.submit(
        fn: 'recordPoDBatch',
        args: {
          'tokenId': view.tokenId,
          'cartonHashes': view.delivery!.cartons.map((c) => c.hash).toList(),
          'mpoSignature': 'sig:test',
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: clock.now,
      );

      final res = await ledger.submit(
        fn: 'settle',
        args: {
          'tokenId': view.tokenId,
          'amount': view.token.declaredValue,
          'method': 'bKash',
          'paymentRef': 'BKASH-000001',
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: clock.now,
      );
      expect(res.ok, isTrue, reason: res.error);

      // The pharmacy's upgrade banner is built from these two. It used to be a
      // fixed line reading "Now Established - 85% advance" whatever happened.
      final result = res.result as Map;
      expect(result['tierBefore'], isA<RecourseTier>());
      expect(result['tierAfter'], isA<RecourseTier>());
      // Rahman arrives with seven settled cycles; the eighth earns Established.
      expect(result['tierBefore'], RecourseTier.building);
      expect(result['tierAfter'], RecourseTier.established);
    });
  });

  group('Minting', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('a minted invoice reaches the route and the book', () async {
      final state = LaMPState();
      while (!state.isInitialized) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final tokensBefore = state.tokenViews.length;
      final routeBefore = state.routeFor(SeedData.mpos[0].id).length;

      final product = SeedData.products.first;
      final res = await state.mintInvoice(
        pharmacyDid: SeedData.pharmacies[1].did,
        termsDays: 30,
        lineItems: [
          LineItem(
            sku: product.sku,
            name: product.name,
            strength: product.strength,
            quantity: product.unitsPerCarton * 4,
            cartons: 4,
            unitPrice: product.unitPrice,
            lineValue: product.unitPrice * product.unitsPerCarton * 4,
          ),
        ],
      );
      expect(res.ok, isTrue, reason: res.error);

      // Before this, minting inserted rows nothing ever read.
      expect(state.tokenViews.length, tokensBefore + 1);
      expect(state.routeFor(SeedData.mpos[0].id).length, routeBefore + 1);
    });

    test('minted invoice ids are monotonic and never collide', () async {
      final state = LaMPState();
      while (!state.isInitialized) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final product = SeedData.products.first;
      LineItem line() => LineItem(
            sku: product.sku,
            name: product.name,
            strength: product.strength,
            quantity: product.unitsPerCarton * 2,
            cartons: 2,
            unitPrice: product.unitPrice,
            lineValue: product.unitPrice * product.unitsPerCarton * 2,
          );

      for (int i = 0; i < 3; i++) {
        final res = await state.mintInvoice(
          pharmacyDid: SeedData.pharmacies[1].did,
          termsDays: 45,
          lineItems: [line()],
        );
        expect(res.ok, isTrue, reason: res.error);
      }

      final ids = state.invoices.map((i) => i.invoiceId).toList();
      expect(ids.toSet().length, ids.length, reason: 'invoice id collision');

      // And the carton hashes of two separate mints must not collide either.
      final hashes = <String>{};
      for (final v in state.tokenViews) {
        for (final h in v.token.cartonHashes) {
          expect(hashes.add(h), isTrue, reason: 'duplicate carton hash');
        }
      }
    });
  });
}
