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

      final tokenJson = await ledger.readWorld('token:tok-00235');
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
          'tokenId': 'tok-00235',
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
      final rawToken = await ledger.readWorld('token:tok-00235');
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
}
