import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../chain/crypto.dart';
import '../chain/ledger.dart';
import '../invoice/invoice_artifacts.dart';
import '../models/domain_models.dart';
import '../models/ledger_models.dart';
import '../remote/lamp_api.dart';
import '../store/lamp_store.dart';
import '../world/clock.dart';
import '../world/gs1.dart';
import '../world/queries.dart';
import '../world/seed.dart';

/// What the app is doing before the first screen appears.
enum WorldLoad {
  /// Nothing decided yet — the store has not answered.
  opening,

  /// A stored world was found and is being parsed. Fast.
  restoring,

  /// No stored world. Replaying the seed through the chaincode. Slower.
  seeding,

  /// Ready.
  ready,
}

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

  WorldLoad _loadPhase = WorldLoad.opening;

  /// What the app is doing before the first screen.
  ///
  /// Seeding a fresh world and restoring a stored one are different amounts of
  /// work — the first replays two rate curves, seven settled cycles and the
  /// hero consignment through the chaincode; the second parses one JSON
  /// document. The splash says which, rather than showing the same word for
  /// both and being wrong half the time.
  WorldLoad get loadPhase => _loadPhase;

  List<Invoice> invoices = [];
  List<Delivery> deliveries = [];
  CreditHistory? creditHistory;

  /// The receivable the demo director's scenes point at.
  ///
  /// It used to be the spine of the whole app — every screen read exactly this
  /// one token, which is why nothing could be filtered and a minted invoice
  /// appeared nowhere. Screens read [tokenViews] now; this is only a bookmark.
  String demoTokenId = 'RCV-00235';
  String demoInvoiceId = 'INV-00235';

  /// Joined views over every token on the ledger, rebuilt on demand.
  ///
  /// Invalidated by [notifyListeners], so it cannot go stale behind a screen:
  /// every mutation already funnels through there.
  List<TokenView>? _views;

  List<TokenView> get tokenViews =>
      _views ??= LaMPQueries.listTokenViews(ledger, invoices, deliveries);

  TokenView? viewFor(String tokenId) {
    for (final v in tokenViews) {
      if (v.tokenId == tokenId) return v;
    }
    return null;
  }

  /// What one pharmacy owes, nearest due date first.
  List<TokenView> openForPharmacy(String did) {
    final out = tokenViews
        .where((v) => v.token.buyerDid == did && v.token.isOpen)
        .toList();
    out.sort((a, b) => a.token.dueDate.compareTo(b.token.dueDate));
    return out;
  }

  List<TokenView> forPharmacy(String did) =>
      tokenViews.where((v) => v.token.buyerDid == did).toList();

  /// Today's route for one officer.
  ///
  /// A stop drops off once the delivery is complete *and* the ledger has every
  /// carton — the same two conditions as `app/mpo/page.tsx:28-36`. Checking
  /// only the off-chain status would leave a signed-but-partial stop hidden.
  List<TokenView> routeFor(String mpoId) {
    final out = tokenViews.where((v) {
      final d = v.delivery;
      if (d == null || d.mpoId != mpoId) return false;
      return d.status != DeliveryStatus.completed || !v.token.isFullyScanned;
    }).toList();
    out.sort((a, b) =>
        (a.delivery?.sequence ?? 99).compareTo(b.delivery?.sequence ?? 99));
    return out;
  }

  CreditHistory? creditFor(String did) => LaMPQueries.getCredit(ledger, did);

  int get blockHeight => ledger.height;
  List<Block> get blocks => ledger.blocks;
  List<ChainTx> get txs => ledger.txs;

  /// The most recent accepted write that names [tokenId] — what a receipt
  /// footer cites. Null for a token nothing has been written about yet.
  ChainTx? lastTxFor(String tokenId) {
    final all = ledger.txs;
    for (var i = all.length - 1; i >= 0; i--) {
      final tx = all[i];
      if (tx.status == TxStatus.valid && tx.args['tokenId'] == tokenId) return tx;
    }
    return null;
  }
  int get now => clock.now;

  Timer? _saveTimer;

  /* ------------------------------------------------------------------------ */
  /* The shared ledger                                                        */
  /* ------------------------------------------------------------------------ */

  /// The server this build talks to, or null to run the on-phone ledger.
  ///
  /// With a server, every phone reads and writes one ledger: a scan on the
  /// officer's phone is on the bank's screen at its next poll. The phone keeps
  /// a mirror of the server's state in [ledger] and reads it exactly as it
  /// reads its own, so no screen knows the difference.
  final LampApi? api;
  bool get isRemote => api != null;

  /// Why the last read from the server failed, or null when it is reachable.
  String? remoteError;

  Timer? _pollTimer;
  bool _pulling = false;
  /// How often to ask whether the ledger moved. Someone else's write shows up
  /// within this long; the phone's own writes show at once, since each one is
  /// followed by a read.
  static const Duration _pollEvery = Duration(seconds: 10);

  LaMPState({LampApi? api}) : api = api ?? LampApi.configured() {
    initWorld();
  }

  /// Restore the stored world, or seed a fresh one.
  ///
  /// A stored world that will not load is not an error worth stopping for —
  /// on a demo device a refusal to start is indistinguishable from the app
  /// being broken — so anything unreadable falls through to a reseed.
  Future<void> initWorld() async {
    if (isRemote) {
      await _startRemote();
      return;
    }
    final stored = await LaMPStore.load();

    if (stored != null) {
      _loadPhase = WorldLoad.restoring;
      notifyListeners();
      if (_restoreFrom(stored)) {
        _loadPhase = WorldLoad.ready;
        _initialized = true;
        notifyListeners();
        // Flush immediately. `notifyListeners` only schedules a debounced
        // save 400 ms out, which is enough time for a user to background the
        // app and the OS to evict it before the write completes — leaving
        // the restored world lost. saveNow() cancels the pending timer and
        // writes synchronously (well, awaits a single Future).
        await saveNow();
        return;
      }
    }
    await _seedWorld();
  }

  Future<void> _seedWorld() async {
    _loadPhase = WorldLoad.seeding;
    notifyListeners();

    final seedResult = await SeedData.buildWorld(ledger, clock);
    invoices = List<Invoice>.from(seedResult['invoices'] as List);
    deliveries = List<Delivery>.from(seedResult['deliveries'] as List);
    creditHistory = seedResult['creditHistory'] as CreditHistory;
    demoTokenId = seedResult['demoTokenId'] as String;
    demoInvoiceId = seedResult['demoInvoiceId'] as String;
    _loadPhase = WorldLoad.ready;
    _initialized = true;
    notifyListeners();
    await saveNow();
  }

  bool _restoreFrom(Map<String, dynamic> json) {
    try {
      ledger.restore(Map<String, dynamic>.from(json['ledger'] as Map));
      clock.restore(Map<String, dynamic>.from(json['clock'] as Map));

      invoices = ((json['invoices'] as List<dynamic>?) ?? [])
          .map((i) => Invoice.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList();
      deliveries = ((json['deliveries'] as List<dynamic>?) ?? [])
          .map((d) => Delivery.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList();

      final credit = json['creditHistory'];
      creditHistory = credit == null
          ? null
          : CreditHistory.fromJson(Map<String, dynamic>.from(credit as Map));

      demoTokenId = json['demoTokenId'] as String? ?? demoTokenId;
      demoInvoiceId = json['demoInvoiceId'] as String? ?? demoInvoiceId;

      // An empty ledger is a store that was written mid-seed. Reseed instead.
      return ledger.height > 0;
    } catch (e) {
      debugPrint('LaMPState: stored world did not load ($e), reseeding');
      return false;
    }
  }

  Map<String, dynamic> _snapshot() => {
    'ledger': ledger.snapshot(),
    'clock': clock.toJson(),
    'invoices': invoices.map((i) => i.toJson()).toList(),
    'deliveries': deliveries.map((d) => d.toJson()).toList(),
    if (creditHistory != null) 'creditHistory': creditHistory!.toJson(),
    'demoTokenId': demoTokenId,
    'demoInvoiceId': demoInvoiceId,
  };

  /// First read from the server. Retries until it answers, holding the
  /// splash meanwhile — there is nothing honest to show before it does.
  Future<void> _startRemote() async {
    _loadPhase = WorldLoad.restoring;
    notifyListeners();
    while (true) {
      try {
        await _pull();
        break;
      } catch (e) {
        remoteError = "Couldn't reach the server. Retrying…";
        debugPrint('LaMPState: server unreachable ($e)');
        await Future<void>.delayed(_pollEvery);
      }
    }
    _loadPhase = WorldLoad.ready;
    _initialized = true;
    notifyListeners();
    _pollTimer = Timer.periodic(_pollEvery, (_) => _poll());
  }

  /// Re-read when the server's ledger has moved — someone else's write.
  Future<void> _poll() async {
    if (_pulling) return;
    try {
      final height = await api!.height();
      if (height != ledger.height) await _pull();
      if (remoteError != null) {
        remoteError = null;
        notifyListeners();
      }
    } catch (e) {
      if (remoteError == null) {
        remoteError = "Can't reach the server. Showing the last known state.";
        notifyListeners();
      }
    }
  }

  /// Replace the mirror with the server's current state.
  Future<void> _pull() async {
    _pulling = true;
    try {
      final s = await api!.state();
      ledger.mirror(world: s.world, txs: s.txs, height: s.height);
      clock.syncTo(s.now);
      invoices = s.invoices;
      deliveries = s.deliveries;
      final first = SeedData.pharmacies.first.did;
      creditHistory = creditFor(first) ?? creditHistory;
      remoteError = null;
      notifyListeners();
    } finally {
      _pulling = false;
    }
  }

  /// One write on the server, then a fresh read so every screen sees it.
  Future<SubmitResult> _remote(
    String fn,
    String action,
    Map<String, dynamic> args, {
    bool demoControl = false,
  }) async {
    RemoteResult r;
    try {
      r = await api!.act(action, args, demoControl: demoControl);
    } catch (e) {
      r = const RemoteResult(ok: false, error: "Couldn't reach the server.");
    }
    try {
      await _pull();
    } catch (_) {
      // The write's outcome stands; the next poll catches up.
    }
    return SubmitResult(
      ok: r.ok,
      error: r.error,
      tx: r.tx ??
          ChainTx(
            txId: '',
            blockNumber: ledger.height,
            timestamp: clock.now,
            submitter: Msp.manufacturerMSP.id,
            fn: fn,
            args: args,
            status: r.ok ? TxStatus.valid : TxStatus.chaincodeError,
            message: r.error,
            policy: '',
            endorsements: const [],
            writes: const [],
          ),
    );
  }

  /// Write the world immediately, cancelling any pending debounced save.
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    // The server is the record; the phone keeps no copy of its own.
    if (!_initialized || isRemote) return;
    await LaMPStore.save(_snapshot());
  }

  /// Every mutation funnels through notifyListeners, so persistence hangs off
  /// it rather than off ten individual call sites — a new action cannot then
  /// be added that silently fails to persist.
  ///
  /// Debounced because the scan cascade fires a notification per carton, and
  /// serialising the whole ledger twenty-five times in as many seconds would
  /// be felt on a mid-range phone.
  @override
  void notifyListeners() {
    // Drop the joined views before anyone can read them again. Every mutation
    // already funnels through here, so a new action cannot be added that
    // silently leaves a screen rendering the pre-transaction world.
    _views = null;
    super.notifyListeners();
    if (!_initialized || isRemote) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 400),
      () => LaMPStore.save(_snapshot()),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  void setPersona(PersonaId persona) {
    _currentPersona = persona;
    notifyListeners();
  }

  /// Discard the stored world and rebuild the seeded one.
  Future<void> resetWorld() async {
    if (isRemote) {
      await _remote('reset', 'reset', const {}, demoControl: true);
      return;
    }
    _saveTimer?.cancel();
    _initialized = false;
    await LaMPStore.clear();
    await _seedWorld();
  }

  void advanceClock(int ms) {
    if (isRemote) {
      _remote('advanceClock', 'advanceClock', {'ms': ms}, demoControl: true);
      return;
    }
    clock.advance(ms);
    notifyListeners();
  }

  void advanceHours(int hours) => advanceClock(hours * 3600 * 1000);
  void advanceDays(int days) => advanceClock(days * 86400 * 1000);

  ReceivableToken? getToken(String tokenId) {
    // Synchronous read of the cached token. Returns null if the ledger hasn't
    // seen it; callers that need a guaranteed-fresh copy should use fetchToken.
    final raw = ledger.readWorldSync('token:$tokenId');
    if (raw == null) return null;
    return ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));
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

  /// The delivery officer for a pharmacy: whoever covers its territory.
  String _officerFor(String pharmacyDid) {
    String? territory;
    for (final p in SeedData.pharmacies) {
      if (p.did == pharmacyDid) territory = p.territory;
    }
    for (final m in SeedData.mpos) {
      if (m.territory == territory) return m.id;
    }
    return SeedData.mpos.first.id;
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
    if (isRemote) {
      return _remote('recordPoD', 'scan',
          {'tokenId': tokenId, 'gs1': gs1, 'deviceId': deviceId});
    }
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

    // Update the off-chain delivery model against the *real* row, not a
    // synthetic placeholder. A previously-orphaned `orElse` would mutate a
    // local copy and discard it, so a misrouted scan (e.g. the planted
    // carton #14 in INV-00235) showed nothing in the per-carton list.
    final delivery = getDelivery(tokenId);
    if (delivery != null) {
      if (res.ok) {
        // Find the actual row and clear any prior rejection — the chaincode
        // accepted this scan, so any earlier refusal is moot.
        for (final c in delivery.cartons) {
          if (c.hash == cartonHash) {
            c.scannedAt = clock.now;
            c.rejected = false;
            c.rejectReason = null;
          }
        }
        delivery.status = delivery.cartons.every((c) => c.scannedAt != null)
            ? DeliveryStatus.awaitingConfirmation
            : DeliveryStatus.scanning;
      } else {
        // Refusal: only mark a row if it exists. If a foreign carton is
        // scanned, the chaincode refused and the UI banner already explains
        // why — there is no row to mark, and inventing one would drift from
        // the seeded manifest.
        for (final c in delivery.cartons) {
          if (c.hash == cartonHash) {
            c.rejected = true;
            c.rejectReason = res.error;
          }
        }
      }
    }

    notifyListeners();
    return res;
  }

  /// Flag a carton the officer set aside after a refusal.
  ///
  /// The misrouted-carton beat submits a payload that belongs to no
  /// consignment, so [scanCarton] finds no row to mark — the hash matches
  /// nothing in this manifest. The MPO screen used to write the flag straight
  /// onto the model from inside its own `setState`, which mutated an object
  /// this class owns without telling anything else that listens to it.
  void markCartonRejected(String tokenId, String cartonId, String reason) {
    if (isRemote) {
      _remote('', 'rejectCarton',
          {'tokenId': tokenId, 'cartonId': cartonId, 'reason': reason});
    }
    final delivery = getDelivery(tokenId);
    if (delivery == null) return;
    for (final carton in delivery.cartons) {
      if (carton.cartonId == cartonId) {
        carton.rejected = true;
        carton.rejectReason = reason;
      }
    }
    notifyListeners();
  }

  // Action: Drain Scan Queue (offline)
  Future<SubmitResult> drainScanQueue(String tokenId, List<String> gs1List, String deviceId) async {
    if (isRemote) {
      return _remote('recordPoDBatch', 'drain',
          {'tokenId': tokenId, 'gs1s': gs1List, 'deviceId': deviceId});
    }
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

    // Off-chain mutation must be gated on res.ok. Otherwise a chaincode
    // refusal — unknown carton, duplicate — leaves the row in a state that
    // says "scanned" when the ledger said "no".
    final delivery = getDelivery(tokenId);
    if (delivery != null && res.ok) {
      for (final h in hashes) {
        for (final c in delivery.cartons) {
          if (c.hash == h) {
            c.scannedAt = clock.now;
            c.rejected = false;
            c.rejectReason = null;
          }
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
  Future<SubmitResult> confirmDelivery(String tokenId, String signatureBase64) async {
    // The signature must reach the ledger. The chaincode's `confirmReceipt`
    // function persists `pharmacySignature` and `receivedAt` on the token,
    // which is the demo's central claim — that the ledger, not the UI, is
    // the system of record. Until this fired, the receipt lived only on
    // the off-chain `Delivery` model.
    final signatureRef =
        'sig:${LaMPCrypto.sha256Hex(signatureBase64).substring(0, 16)}';
    if (isRemote) {
      return _remote('confirmReceipt', 'confirm',
          {'tokenId': tokenId, 'signatureRef': signatureRef});
    }
    final res = await ledger.submit(
      fn: 'confirmReceipt',
      args: {
        'tokenId': tokenId,
        'pharmacySignature': signatureRef,
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: clock.now,
    );

    final delivery = getDelivery(tokenId);
    if (delivery != null && res.ok) {
      delivery.signatureRef = signatureRef;
      delivery.completedAt = clock.now;
      delivery.status = DeliveryStatus.completed;
      // The scan flags stay. They were cleared here once, "so a re-run of the
      // demo starts clean", which left the off-chain rows contradicting the
      // ledger the instant a delivery was signed for — and the bank, which
      // read those rows, saw 0/25 cartons on a consignment it had just been
      // told was complete. Re-running the demo is what `resetWorld` is for.
    }

    // Force the on-ledger token to be re-read so downstream screens (e.g.
    // the manufacturer lifecycle rail) reflect the new state without a
    // restart.
    await fetchToken(tokenId);

    notifyListeners();
    return res;
  }

  // Action: Bank Finance Receivable
  Future<SubmitResult> financeReceivable(String tokenId, Msp asMsp) async {
    if (isRemote) {
      return _remote('matchAndAdvance', 'finance', {'tokenId': tokenId, 'bank': asMsp.id});
    }
    final res = await ledger.submit(
      fn: 'matchAndAdvance',
      args: {'tokenId': tokenId},
      asMsp: asMsp,
      nowTimestamp: clock.now,
    );
    // Refresh the cached token so the manufacturer lifecycle rail (and any
    // other listener) sees the new `financing` field on next rebuild.
    await fetchToken(tokenId);
    notifyListeners();
    return res;
  }

  // Action: Settle Receivable
  Future<SubmitResult> settleReceivable(String tokenId, double amount, String method) async {
    if (isRemote) {
      return _remote('settle', 'settle',
          {'tokenId': tokenId, 'amount': amount, 'method': method});
    }
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

    // Refresh the cached history only when it is this buyer's. Screens read
    // each pharmacy's own record through `creditFor`; the cache is the first
    // pharmacy's, and overwriting it with another buyer's would mix the two.
    final buyer = viewFor(tokenId)?.token.buyerDid;
    if (buyer != null && buyer == creditHistory?.pharmacyDid) {
      final updated = await fetchCredit(buyer);
      if (updated != null) creditHistory = updated;
    }

    // Re-read the token so screens that filter on state (pharmacy "Due now",
    // bank financing list) see the SETTLED state without a restart.
    await fetchToken(tokenId);

    notifyListeners();
    return res;
  }

  // Action: Bank Anchor Invoice Document
  Future<SubmitResult> anchorInvoiceDocument(
    String tokenId,
    Msp asMsp, {
    required String sha256,
    required int byteLength,
    required String filename,
  }) async {
    final res = await ledger.submit(
      fn: 'anchorInvoiceDocument',
      args: {
        'tokenId': tokenId,
        'sha256': sha256,
        'byteLength': byteLength,
        'filename': filename,
      },
      asMsp: asMsp,
      nowTimestamp: clock.now,
    );
    // Refresh the cached token so screens reading `documentHash` (bank check
    // items, lifecycle rail) see the new field on next rebuild.
    await fetchToken(tokenId);
    notifyListeners();
    return res;
  }

  // Manufacturer: QR-codes ZIP --------------------------------------------

  /// Build the QR-codes ZIP for [tokenId] and stage it under `_qrZip` cache.
  ///
  /// Returns the ZIP bytes — the caller hands them to the share sheet. The
  /// hero demo uses this on the Manufacturer → Receivables card; the MPO
  /// then unzips on a second device and scans the cartons one by one.
  Future<Uint8List> generateQrZip(String tokenId) async {
    final view = viewFor(tokenId);
    final invoice = _invoiceFor(tokenId);
    final delivery = view?.delivery;
    if (invoice == null || delivery == null) {
      throw StateError(
        'No invoice/delivery available for $tokenId; cannot build a QR ZIP.',
      );
    }
    return InvoiceArtifacts.buildQrZip(
      invoice: invoice,
      cartons: delivery.cartons,
    );
  }

  /// The invoice PDF for [tokenId]: the same bytes the ledger's
  /// `issuedDocumentHash` was taken over at mint, on any phone.
  Future<({Uint8List bytes, String sha256, String filename})>
      generateInvoicePdf(String tokenId) async {
    final invoice = _invoiceFor(tokenId);
    if (invoice == null) {
      throw StateError('No invoice available for $tokenId.');
    }
    final bytes = await InvoiceArtifacts.renderInvoicePdf(invoice: invoice);
    return (
      bytes: bytes,
      sha256: InvoiceArtifacts.hashBytes(bytes),
      filename: InvoiceArtifacts.pdfFilename(invoice.invoiceId),
    );
  }

  // Internal: shared helper to look up the Invoice for a token via the
  // tokenId field already stored on every Invoice. Falls back to null when
  // none has been minted for the supplied tokenId — the only caller that
  // hits that branch is the bank "verify" sheet, which renders an empty
  // state instead of an exception.
  Invoice? _invoiceFor(String tokenId) {
    for (final inv in invoices) {
      if (inv.tokenId == tokenId) return inv;
    }
    return null;
  }

  // Action: Raise Dispute
  Future<SubmitResult> raiseDispute(String tokenId, String reason) async {
    if (isRemote) {
      return _remote('raiseDispute', 'dispute', {'tokenId': tokenId, 'reason': reason});
    }
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

    await fetchToken(tokenId);
    notifyListeners();
    return res;
  }

  // Action: Resolve Dispute
  Future<SubmitResult> resolveDispute(String tokenId, String resolution) async {
    if (isRemote) {
      return _remote('resolveDispute', 'resolve', {
        'tokenId': tokenId,
        'resolution': resolution,
        'restoreTo': TokenState.delivered.id,
      });
    }
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

    await fetchToken(tokenId);
    notifyListeners();
    return res;
  }

  /// Next free invoice number, so ids stay monotonic across a session.
  ///
  /// Ported from `LaMP/lib/world/mint.ts:45-51`. The previous
  /// `Random().nextInt(800) + 300` produced variable-width ids
  /// (`INV-00300`…`INV-001099`) that broke the mono column alignment and could
  /// land on the seeded `INV-00235`.
  int _nextInvoiceNumber() {
    var highest = 0;
    for (final inv in invoices) {
      final digits = inv.invoiceId.replaceAll(RegExp(r'\D'), '');
      final n = int.tryParse(digits);
      if (n != null && n > highest) highest = n;
    }
    return highest + 1;
  }

  // Action: Mint New Invoice
  Future<SubmitResult> mintInvoice({
    required String pharmacyDid,
    required int termsDays,
    required List<LineItem> lineItems,
  }) async {
    if (isRemote) {
      // The server numbers the invoice, makes the cartons and assigns the
      // round; the phone says what and for whom.
      return _remote('mintReceivable', 'mint', {
        'pharmacyDid': pharmacyDid,
        'termsDays': termsDays,
        'lines': [
          for (final l in lineItems) {'sku': l.sku, 'cartons': l.cartons},
        ],
        'mpoId': _officerFor(pharmacyDid),
      });
    }
    final invoiceNum = _nextInvoiceNumber();
    final numeric = invoiceNum.toString().padLeft(5, '0');
    final invoiceId = 'INV-$numeric';
    final tokenId = 'RCV-$numeric';

    final totalCartons = lineItems.fold<int>(0, (s, l) => s + l.cartons);
    final declaredValue = lineItems.fold<double>(0.0, (s, l) => s + l.lineValue);

    final cartonHashes = <String>[];
    final cartons = <Carton>[];

    // One carton per carton, on the line item it actually belongs to — every
    // minted carton used to be stamped with `lineItems.first.sku` regardless.
    //
    // Serials carry the invoice number because the carton hash is taken over
    // the GS1 payload: two invoices minting an identical payload would let a
    // carton from one satisfy the other's membership test, which is exactly
    // the check the misrouted-carton beat exists to demonstrate.
    int serial = 1;
    for (final line in lineItems) {
      final gtin = SeedData.products
          .firstWhere(
            (p) => p.sku == line.sku,
            orElse: () => SeedData.products.first,
          )
          .gtin;
      for (int c = 0; c < line.cartons; c++) {
        final ser = '$numeric${serial.toString().padLeft(4, '0')}';
        final gs1 = GS1Barcode.encodeGs1(
          gtin: gtin,
          expiry: '280824',
          batch: 'BCH-2026-MINT',
          serial: ser,
        );
        final chash = LaMPCrypto.sha256Hex(gs1);
        cartonHashes.add(chash);
        cartons.add(Carton(
          cartonId: '$invoiceId-${line.sku}-$ser',
          gs1: gs1,
          hash: chash,
          sku: line.sku,
          batch: 'BCH-2026-MINT',
          expiry: '2028-08-24',
        ));
        serial++;
      }
    }

    // One timestamp for the ledger and the off-chain invoice. Reading the
    // clock four times gave the two records issue dates milliseconds apart.
    final issuedAt = clock.now;
    final newInvoice = Invoice(
      invoiceId: invoiceId,
      tokenId: tokenId,
      manufacturerId: SeedData.manufacturer.id,
      pharmacyDid: pharmacyDid,
      lineItems: lineItems,
      value: declaredValue,
      termsDays: termsDays,
      issuedAt: issuedAt,
      dueDate: issuedAt + termsDays * 86400 * 1000,
      cartonCount: totalCartons,
    );

    final res = await ledger.submit(
      fn: 'mintReceivable',
      args: {
        'tokenId': tokenId,
        'invoiceId': invoiceId,
        'manufacturerId': SeedData.manufacturer.id,
        'buyerDid': pharmacyDid,
        'declaredValue': declaredValue,
        'termsDays': termsDays,
        'issuedAt': issuedAt,
        'dueDate': newInvoice.dueDate,
        'cartonHashes': cartonHashes,
        'lineItems': lineItems.map((l) => l.toJson()).toList(),
        'documentSha256': await InvoiceArtifacts.issuedHash(newInvoice),
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: issuedAt,
    );

    if (res.ok) {
      invoices.insert(0, newInvoice);

      final newDelivery = Delivery(
        id: 'del-00$invoiceNum',
        invoiceId: invoiceId,
        tokenId: tokenId,
        // The officer who covers the pharmacy's territory, so a new invoice
        // lands on the right round. The first officer covers anywhere else.
        mpoId: _officerFor(pharmacyDid),
        pharmacyDid: pharmacyDid,
        status: DeliveryStatus.pending,
        sequence: deliveries.length + 1,
        cartons: cartons,
        startedAt: issuedAt,
      );
      deliveries.insert(0, newDelivery);
    }

    notifyListeners();
    return res;
  }
}
