import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../chain/crypto.dart';
import '../chain/ledger.dart';
import '../models/domain_models.dart';
import '../models/ledger_models.dart';
import '../world/clock.dart';
import '../world/gs1.dart';
import '../world/seed.dart';

enum PersonaId {
  mpo('mpo', 'MPO App', 'Delivery Proof', Msp.manufacturerMSP, true),
  pharmacy('pharmacy', 'Pharmacy App', 'Credit Building', Msp.manufacturerMSP, true),
  manufacturer('manufacturer', 'Manufacturer Portal', 'Receivable Management', Msp.manufacturerMSP, false),
  bank('bank', 'Bank Portal', 'Financing Management', Msp.meghnaMSP, false),
  regulator('regulator', 'Regulator Dashboard', 'Compliance Oversight', Msp.regulatorMSP, false);

  final String id;
  final String title;
  final String subtitle;
  final Msp defaultMsp;
  final bool isFieldApp;

  const PersonaId(this.id, this.title, this.subtitle, this.defaultMsp, this.isFieldApp);
}

class LaMPState extends ChangeNotifier {
  final LocalLedger ledger = LocalLedger();
  final DemoClock clock = DemoClock();

  PersonaId _currentPersona = PersonaId.mpo;
  PersonaId get currentPersona => _currentPersona;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  List<Invoice> invoices = [];
  List<Delivery> deliveries = [];
  CreditHistory? creditHistory;
  String demoTokenId = 'tok-00235';
  String demoInvoiceId = 'INV-00235';

  int get blockHeight => ledger.height;
  List<Block> get blocks => ledger.blocks;
  List<ChainTx> get txs => ledger.txs;
  int get now => clock.now;

  LaMPState() {
    initWorld();
  }

  Future<void> initWorld() async {
    final seedResult = await SeedData.buildWorld(ledger, clock);
    invoices = List<Invoice>.from(seedResult['invoices'] as List);
    deliveries = List<Delivery>.from(seedResult['deliveries'] as List);
    creditHistory = seedResult['creditHistory'] as CreditHistory;
    demoTokenId = seedResult['demoTokenId'] as String;
    demoInvoiceId = seedResult['demoInvoiceId'] as String;
    _initialized = true;
    notifyListeners();
  }

  void setPersona(PersonaId persona) {
    _currentPersona = persona;
    notifyListeners();
  }

  Future<void> resetWorld() async {
    await initWorld();
  }

  void advanceClock(int ms) {
    clock.advance(ms);
    notifyListeners();
  }

  void advanceHours(int hours) => advanceClock(hours * 3600 * 1000);
  void advanceDays(int days) => advanceClock(days * 86400 * 1000);

  ReceivableToken? getToken(String tokenId) {
    return null;
  }

  Future<ReceivableToken?> fetchToken(String tokenId) async {
    final raw = await ledger.readWorld('token:$tokenId');
    if (raw == null) return null;
    return ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<ReceivableToken>> fetchAllTokens() async {
    final tokenKeys = await ledger.listKeys('token:');
    final out = <ReceivableToken>[];
    for (final k in tokenKeys) {
      final raw = await ledger.readWorld(k);
      if (raw != null) {
        out.add(ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map)));
      }
    }
    return out;
  }

  Future<CreditHistory?> fetchCredit(String did) async {
    final raw = await ledger.readWorld('credit:$did');
    if (raw == null) return creditHistory;
    return CreditHistory.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Delivery? getDelivery(String tokenId) {
    try {
      return deliveries.firstWhere((d) => d.tokenId == tokenId);
    } catch (_) {
      return null;
    }
  }

  // Action: Scan Carton
  Future<SubmitResult> scanCarton(String tokenId, String gs1, String deviceId) async {
    final cartonHash = LaMPCrypto.sha256Hex(gs1);
    final res = await ledger.submit(
      fn: 'recordPoD',
      args: {
        'tokenId': tokenId,
        'cartonHash': cartonHash,
        'mpoSignature': 'sig:$deviceId',
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: clock.now,
    );

    // Update off-chain delivery model
    final delivery = getDelivery(tokenId);
    if (delivery != null) {
      final carton = delivery.cartons.firstWhere(
        (c) => c.hash == cartonHash,
        orElse: () => Carton(
          cartonId: 'UNKNOWN',
          gs1: gs1,
          hash: cartonHash,
          sku: 'UNKNOWN',
          batch: 'UNKNOWN',
          expiry: 'UNKNOWN',
        ),
      );
      if (res.ok) {
        carton.scannedAt = clock.now;
        carton.rejected = false;
        if (delivery.cartons.every((c) => c.scannedAt != null)) {
          delivery.status = DeliveryStatus.awaitingConfirmation;
        } else {
          delivery.status = DeliveryStatus.scanning;
        }
      } else {
        carton.rejected = true;
        carton.rejectReason = res.error;
      }
    }

    notifyListeners();
    return res;
  }

  // Action: Drain Scan Queue (offline)
  Future<SubmitResult> drainScanQueue(String tokenId, List<String> gs1List, String deviceId) async {
    final hashes = gs1List.map(LaMPCrypto.sha256Hex).toList();
    final res = await ledger.submit(
      fn: 'recordPoDBatch',
      args: {
        'tokenId': tokenId,
        'cartonHashes': hashes,
        'mpoSignature': 'sig:$deviceId',
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: clock.now,
    );

    final delivery = getDelivery(tokenId);
    if (delivery != null) {
      for (final h in hashes) {
        final c = delivery.cartons.where((item) => item.hash == h);
        for (final item in c) {
          item.scannedAt = clock.now;
          item.rejected = false;
        }
      }
      if (delivery.cartons.every((c) => c.scannedAt != null)) {
        delivery.status = DeliveryStatus.awaitingConfirmation;
      }
    }

    notifyListeners();
    return res;
  }

  // Action: Pharmacy Sign & Confirm Delivery
  Future<void> confirmDelivery(String tokenId, String signatureBase64) async {
    final delivery = getDelivery(tokenId);
    if (delivery != null) {
      delivery.signatureRef = 'sig:${LaMPCrypto.sha256Hex(signatureBase64).substring(0, 16)}';
      delivery.completedAt = clock.now;
      delivery.status = DeliveryStatus.completed;
    }
    notifyListeners();
  }

  // Action: Bank Finance Receivable
  Future<SubmitResult> financeReceivable(String tokenId, Msp asMsp) async {
    final res = await ledger.submit(
      fn: 'matchAndAdvance',
      args: {'tokenId': tokenId},
      asMsp: asMsp,
      nowTimestamp: clock.now,
    );
    notifyListeners();
    return res;
  }

  // Action: Settle Receivable
  Future<SubmitResult> settleReceivable(String tokenId, double amount, String method) async {
    final ref = '${method.toUpperCase().replaceAll(' ', '')}-${Random().nextInt(899999) + 100000}';
    final res = await ledger.submit(
      fn: 'settle',
      args: {
        'tokenId': tokenId,
        'amount': amount,
        'method': method,
        'paymentRef': ref,
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: clock.now,
    );

    // Refresh credit history cache
    final updated = await fetchCredit(SeedData.pharmacies[0].did);
    if (updated != null) {
      creditHistory = updated;
    }

    notifyListeners();
    return res;
  }

  // Action: Raise Dispute
  Future<SubmitResult> raiseDispute(String tokenId, String reason) async {
    final res = await ledger.submit(
      fn: 'raiseDispute',
      args: {'tokenId': tokenId, 'reason': reason},
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: clock.now,
    );

    final delivery = getDelivery(tokenId);
    if (delivery != null) {
      delivery.status = DeliveryStatus.disputed;
    }

    notifyListeners();
    return res;
  }

  // Action: Resolve Dispute
  Future<SubmitResult> resolveDispute(String tokenId, String resolution) async {
    final res = await ledger.submit(
      fn: 'resolveDispute',
      args: {
        'tokenId': tokenId,
        'resolution': resolution,
        'restoreTo': TokenState.delivered.id,
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: clock.now,
    );

    final delivery = getDelivery(tokenId);
    if (delivery != null) {
      delivery.status = DeliveryStatus.completed;
    }

    notifyListeners();
    return res;
  }

  // Action: Mint New Invoice
  Future<SubmitResult> mintInvoice({
    required String pharmacyDid,
    required int termsDays,
    required List<LineItem> lineItems,
  }) async {
    final invoiceNum = Random().nextInt(800) + 300;
    final invoiceId = 'INV-00$invoiceNum';
    final tokenId = 'tok-00$invoiceNum';

    final totalCartons = lineItems.fold<int>(0, (s, l) => s + l.cartons);
    final declaredValue = lineItems.fold<double>(0.0, (s, l) => s + l.lineValue);

    final cartonHashes = <String>[];
    final cartons = <Carton>[];

    for (int i = 1; i <= totalCartons; i++) {
      final gtin = GS1Barcode.makeGtin('890123400101');
      final gs1 = GS1Barcode.encodeGs1(
        gtin: gtin,
        expiry: '280824',
        batch: 'BCH-2026-MINT',
        serial: 'SN-${i.toString().padLeft(4, '0')}',
      );
      final chash = LaMPCrypto.sha256Hex(gs1);
      cartonHashes.add(chash);
      cartons.add(Carton(
        cartonId: 'CTN-$i',
        gs1: gs1,
        hash: chash,
        sku: lineItems.first.sku,
        batch: 'BCH-2026-MINT',
        expiry: '2028-08-24',
      ));
    }

    final res = await ledger.submit(
      fn: 'mintReceivable',
      args: {
        'tokenId': tokenId,
        'invoiceId': invoiceId,
        'manufacturerId': SeedData.manufacturer.id,
        'buyerDid': pharmacyDid,
        'declaredValue': declaredValue,
        'termsDays': termsDays,
        'issuedAt': clock.now,
        'dueDate': clock.now + termsDays * 86400 * 1000,
        'cartonHashes': cartonHashes,
        'lineItems': lineItems.map((l) => l.toJson()).toList(),
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: clock.now,
    );

    if (res.ok) {
      final newInvoice = Invoice(
        invoiceId: invoiceId,
        tokenId: tokenId,
        manufacturerId: SeedData.manufacturer.id,
        pharmacyDid: pharmacyDid,
        lineItems: lineItems,
        value: declaredValue,
        termsDays: termsDays,
        issuedAt: clock.now,
        dueDate: clock.now + termsDays * 86400 * 1000,
        cartonCount: totalCartons,
      );
      invoices.insert(0, newInvoice);

      final newDelivery = Delivery(
        id: 'del-00$invoiceNum',
        invoiceId: invoiceId,
        tokenId: tokenId,
        mpoId: SeedData.mpos[0].id,
        pharmacyDid: pharmacyDid,
        status: DeliveryStatus.pending,
        sequence: deliveries.length + 1,
        cartons: cartons,
        startedAt: clock.now,
      );
      deliveries.insert(0, newDelivery);
    }

    notifyListeners();
    return res;
  }
}
