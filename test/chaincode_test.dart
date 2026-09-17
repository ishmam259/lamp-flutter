import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamp_flutter/core/chain/ledger.dart';
import 'package:lamp_flutter/core/chain/policy.dart';
import 'package:lamp_flutter/core/models/domain_models.dart';
import 'package:lamp_flutter/core/models/ledger_models.dart';
import 'package:lamp_flutter/core/world/clock.dart';
import 'package:lamp_flutter/core/world/seed.dart';

void main() {
  group('LaMP Policy Parser Tests', () {
    test('parses and evaluates AND policies', () {
      const policy = "AND('ManufacturerMSP.peer', 'MeghnaMSP.peer')";
      expect(PolicyParser.satisfies(policy, ['ManufacturerMSP', 'MeghnaMSP']), isTrue);
      expect(PolicyParser.satisfies(policy, ['ManufacturerMSP']), isFalse);
    });

    test('parses and evaluates OR policies', () {
      const policy = "OR('MeghnaMSP.peer', 'PadmaMSP.peer')";
      expect(PolicyParser.satisfies(policy, ['MeghnaMSP']), isTrue);
      expect(PolicyParser.satisfies(policy, ['PadmaMSP']), isTrue);
      expect(PolicyParser.satisfies(policy, ['ManufacturerMSP']), isFalse);
    });

    test('parses and evaluates OutOf policies', () {
      const policy = "OutOf(2, 'ManufacturerMSP.peer', 'MeghnaMSP.peer', 'PadmaMSP.peer')";
      expect(PolicyParser.satisfies(policy, ['ManufacturerMSP', 'MeghnaMSP']), isTrue);
      expect(PolicyParser.satisfies(policy, ['MeghnaMSP', 'PadmaMSP']), isTrue);
      expect(PolicyParser.satisfies(policy, ['ManufacturerMSP']), isFalse);
    });

    test('nested policy: AND(Mfr, OR(Meghna, Padma))', () {
      const policy = "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))";
      expect(PolicyParser.satisfies(policy, ['ManufacturerMSP', 'MeghnaMSP']), isTrue);
      expect(PolicyParser.satisfies(policy, ['ManufacturerMSP', 'PadmaMSP']), isTrue);
      expect(PolicyParser.satisfies(policy, ['MeghnaMSP', 'PadmaMSP']), isFalse);
      expect(PolicyParser.satisfies(policy, ['ManufacturerMSP']), isFalse);
    });
  });

  group('LaMP Chaincode State Machine & Ledger Tests', () {
    late LocalLedger ledger;
    late DemoClock clock;

    setUp(() {
      ledger = LocalLedger();
      clock = DemoClock();
    });

    test('buildWorld seeds entities, rate curves, and INV-00235', () async {
      final res = await SeedData.buildWorld(ledger, clock);
      expect(res['invoices'], isNotEmpty);
      expect(res['deliveries'], isNotEmpty);
      expect(ledger.height, greaterThan(0));

      final tokenJson = await ledger.readWorld('token:RCV-00235');
      expect(tokenJson, isNotNull);
      final token = ReceivableToken.fromJson(Map<String, dynamic>.from(tokenJson as Map));
      expect(token.invoiceId, equals('INV-00235'));
      expect(token.cartonHashes.length, equals(25));
      expect(token.state, equals(TokenState.created));
    });

    test('rejects scanning carton with unknown hash', () async {
      await SeedData.buildWorld(ledger, clock);
      final scanRes = await ledger.submit(
        fn: 'recordPoD',
        args: {
          'tokenId': 'RCV-00235',
          'cartonHash': 'foreign-bogus-hash-from-other-invoice',
          'mpoSignature': 'sig:kamrul',
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: clock.now,
      );

      expect(scanRes.ok, isFalse);
      expect(scanRes.error, contains('does not belong to invoice INV-00235'));
      expect(scanRes.tx.status, equals(TxStatus.chaincodeError));
    });

    test('settling 8th cycle upgrades recourse tier from Building to Established', () async {
      await SeedData.buildWorld(ledger, clock);

      // Fast-forward delivery
      final rawToken = await ledger.readWorld('token:RCV-00235');
      final token = ReceivableToken.fromJson(Map<String, dynamic>.from(rawToken as Map));

      // Batch scan all 25 cartons
      await ledger.submit(
        fn: 'recordPoDBatch',
        args: {
          'tokenId': token.tokenId,
          'cartonHashes': token.cartonHashes,
          'mpoSignature': 'sig:kamrul',
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: clock.now,
      );

      // Advance clock +24h to close dispute window
      clock.advanceHours(25);

      // Match and advance by Meghna Bank
      final finRes = await ledger.submit(
        fn: 'matchAndAdvance',
        args: {'tokenId': token.tokenId},
        asMsp: Msp.meghnaMSP,
        nowTimestamp: clock.now,
      );
      expect(finRes.ok, isTrue);

      // Padma Bank attempts duplicate financing -> must be refused!
      final dupFinRes = await ledger.submit(
        fn: 'matchAndAdvance',
        args: {'tokenId': token.tokenId},
        asMsp: Msp.padmaMSP,
        nowTimestamp: clock.now,
      );
      expect(dupFinRes.ok, isFalse);
      expect(dupFinRes.error, contains('already financed'));

      // Settle invoice
      final settleRes = await ledger.submit(
        fn: 'settle',
        args: {
          'tokenId': token.tokenId,
          'paymentRef': 'BKASH-849201',
          'method': 'bKash',
          'amount': token.declaredValue,
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: clock.now,
      );
      expect(settleRes.ok, isTrue);

      // Check tier upgrade
      final rawCredit = await ledger.readWorld('credit:${token.buyerDid}');
      expect(rawCredit, isNotNull);
      final credit = CreditHistory.fromJson(Map<String, dynamic>.from(rawCredit as Map));
      expect(credit.cycles.length, equals(8));
      expect(credit.tier, equals(RecourseTier.established));
    });
  });

  group('LaMP Persistence Tests', () {
    test('ledger survives a snapshot/restore round trip', () async {
      final ledger = LocalLedger();
      final clock = DemoClock();
      await SeedData.buildWorld(ledger, clock);

      final heightBefore = ledger.height;
      final txCountBefore = ledger.txs.length;
      final tipHashBefore = ledger.blocks.last.hash;

      final snapshot = ledger.snapshot();

      // Round-trip through JSON, exactly as the store does — an object that
      // survives restore() in memory but not jsonEncode would pass a naive
      // test and still fail on a real device.
      final wire = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;

      final restored = LocalLedger();
      restored.restore(wire);

      expect(restored.height, equals(heightBefore));
      expect(restored.txs.length, equals(txCountBefore));
      expect(restored.blocks.last.hash, equals(tipHashBefore));

      // World state and the hero token come back intact.
      final tokenJson = await restored.readWorld('token:RCV-00235');
      expect(tokenJson, isNotNull);
      final token = ReceivableToken.fromJson(Map<String, dynamic>.from(tokenJson as Map));
      expect(token.invoiceId, equals('INV-00235'));
      expect(token.cartonHashes.length, equals(25));

      // Private data keeps its membership, so a non-member still reads a seal.
      final asOutsider = await restored.readPrivate(
        'rateCurves',
        'CURVE-MEGHNA-2026Q3',
        Msp.padmaMSP.id,
      );
      expect(asOutsider, isA<Map>());
      expect((asOutsider as Map)['sealed'], isTrue);

      final asOwner = await restored.readPrivate(
        'rateCurves',
        'CURVE-MEGHNA-2026Q3',
        Msp.meghnaMSP.id,
      );
      expect(asOwner, isNotNull);
      expect((asOwner as Map)['sealed'], isNot(isTrue));
    });

    test('a restored ledger still accepts new transactions', () async {
      final ledger = LocalLedger();
      final clock = DemoClock();
      await SeedData.buildWorld(ledger, clock);

      final restored = LocalLedger();
      restored.restore(
        jsonDecode(jsonEncode(ledger.snapshot())) as Map<String, dynamic>,
      );
      final heightBefore = restored.height;

      final raw = await restored.readWorld('token:RCV-00235');
      final token = ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));

      final res = await restored.submit(
        fn: 'recordPoD',
        args: {
          'tokenId': token.tokenId,
          'cartonHash': token.cartonHashes.first,
          'mpoSignature': 'sig:LMP-DEV-4471',
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: clock.now,
      );

      expect(res.ok, isTrue);
      expect(restored.height, equals(heightBefore + 1));
      // The chain continues from the restored tip rather than from genesis.
      expect(restored.blocks.last.prevHash, equals(ledger.blocks.last.hash));
    });

    test('clock offset survives restore', () {
      final clock = DemoClock();
      clock.advanceDays(30);
      final offsetBefore = clock.offset;

      final restored = DemoClock();
      restored.restore(jsonDecode(jsonEncode(clock.toJson())) as Map<String, dynamic>);

      expect(restored.offset, equals(offsetBefore));
      expect(restored.now, closeTo(clock.now, 1000));
    });
  });
}
