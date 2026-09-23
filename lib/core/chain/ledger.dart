import 'dart:async';
import 'dart:math';
import '../models/domain_models.dart';
import '../models/ledger_models.dart';
import 'contract.dart';
import 'crypto.dart';
import 'policy.dart';

class PrivateEntry {
  final List<String> members;
  final dynamic value;
  final String hash;

  PrivateEntry({
    required this.members,
    required this.value,
    required this.hash,
  });

  Map<String, dynamic> toJson() => {
    'members': members,
    'value': value,
    'hash': hash,
  };

  factory PrivateEntry.fromJson(Map<String, dynamic> json) => PrivateEntry(
    members: ((json['members'] as List<dynamic>?) ?? []).cast<String>(),
    value: json['value'],
    hash: json['hash'] as String,
  );
}

class SubmitResult {
  final bool ok;
  final String? error;
  final ChainTx tx;
  final dynamic result;

  SubmitResult({
    required this.ok,
    this.error,
    required this.tx,
    this.result,
  });
}

class LocalLedger {
  final Map<String, dynamic> _world = {};
  final Map<String, Map<String, PrivateEntry>> _collections = {
    'invoiceLineItems': {},
    'rateCurves': {},
  };
  final List<Block> _blocks = [];
  final List<ChainTx> _txs = [];
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  List<Block> get blocks => List.unmodifiable(_blocks);
  List<ChainTx> get txs => List.unmodifiable(_txs);
  int get height => _mirroredHeight ?? _blocks.length;

  /// Set while this ledger mirrors a server's (see [mirror]).
  int? _mirroredHeight;

  /// Synchronous peek at world state for callers (e.g. the UI) that cannot
  /// await. Reads the live map — no defensive clone — so the caller must not
  /// mutate what it gets back.
  dynamic readWorldSync(String key) => _world[key];

  static const String genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  static final Map<String, String> defaultPolicies = {
    'mintReceivable': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
    'recordPoD': "'ManufacturerMSP.peer'",
    'recordPoDBatch': "'ManufacturerMSP.peer'",
    'registerRateCurve': "OR('MeghnaMSP.peer', 'PadmaMSP.peer')",
    'matchAndAdvance': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
    'anchorInvoiceDocument': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
    'settle': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
    'raiseDispute': "'ManufacturerMSP.peer'",
    'resolveDispute': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
    // Pharmacy signs to acknowledge receipt. ManufacturerMSP is on the policy
    // because the MPO device's scan stream has already committed to the
    // ledger by this point — the signature only closes the loop.
    'confirmReceipt': "AND('ManufacturerMSP.peer')",
  };

  /// Become a read-only copy of a server's ledger.
  ///
  /// With a server configured the phone does not run the chaincode; it reads
  /// the world and records the server sends and renders them through the same
  /// synchronous queries as its own ledger. Private collections are not sent —
  /// their values never leave the server — and blocks are not either, so the
  /// height is taken as given.
  void mirror({
    required Map<String, dynamic> world,
    required List<ChainTx> txs,
    required int height,
  }) {
    clear();
    _world.addAll(world);
    _txs.addAll(txs);
    _mirroredHeight = height;
  }

  void clear() {
    _mirroredHeight = null;
    _world.clear();
    _collections['invoiceLineItems']?.clear();
    _collections['rateCurves']?.clear();
    _blocks.clear();
    _txs.clear();
  }

  /// The whole ledger as plain JSON, for persistence.
  ///
  /// World-state values are already plain maps — every chaincode write goes
  /// through `toJson()` — so nothing here needs a custom encoder.
  Map<String, dynamic> snapshot() => {
    'world': _world,
    'collections': {
      for (final entry in _collections.entries)
        entry.key: {
          for (final e in entry.value.entries) e.key: e.value.toJson(),
        },
    },
    'blocks': _blocks.map((b) => b.toJson()).toList(),
    'txs': _txs.map((t) => t.toJson()).toList(),
  };

  /// Rebuild from a snapshot. Replaces whatever is currently held.
  ///
  /// The hash chain is not re-derived: the stored hashes are the ones the
  /// transactions were committed with, and recomputing them would quietly
  /// paper over a corrupted store rather than surfacing it.
  void restore(Map<String, dynamic> json) {
    clear();

    final world = (json['world'] as Map?) ?? {};
    world.forEach((k, v) => _world[k as String] = v);

    final collections = (json['collections'] as Map?) ?? {};
    collections.forEach((name, entries) {
      final target = _collections[name as String] ??= {};
      (entries as Map).forEach((key, value) {
        target[key as String] =
            PrivateEntry.fromJson(Map<String, dynamic>.from(value as Map));
      });
    });

    for (final b in (json['blocks'] as List<dynamic>?) ?? []) {
      _blocks.add(Block.fromJson(Map<String, dynamic>.from(b as Map)));
    }
    for (final t in (json['txs'] as List<dynamic>?) ?? []) {
      _txs.add(ChainTx.fromJson(Map<String, dynamic>.from(t as Map)));
    }
  }

  void setWorldDirect(String key, dynamic value) {
    _world[key] = value;
  }

  Future<dynamic> readWorld(String key) async => _world[key];

  Future<List<String>> listKeys(String prefix) async => listKeysSync(prefix);

  /// Synchronous key scan, the companion to [readWorldSync].
  ///
  /// The world is an in-memory map, so there was never anything to await here.
  /// The query layer runs inside `build()`, which cannot, and a future would
  /// have forced every list on every screen through a `FutureBuilder` for no
  /// gain.
  List<String> listKeysSync(String prefix) =>
      _world.keys.where((k) => k.startsWith(prefix)).toList();

  Future<dynamic> readPrivate(String collection, String key, String readerMsp) async {
    final entry = _collections[collection]?[key];
    if (entry == null) return null;
    if (!entry.members.contains(readerMsp)) {
      return {'hash': entry.hash, 'sealed': true, 'members': entry.members};
    }
    return entry.value;
  }

  Future<SubmitResult> submit({
    required String fn,
    required Map<String, dynamic> args,
    required Msp asMsp,
    List<Msp>? endorsers,
    required int nowTimestamp,
  }) async {
    final policy = defaultPolicies[fn] ?? "'ManufacturerMSP.peer'";
    final actualEndorsers = endorsers ?? Msp.values.where((m) => m.isEndorsing).toList();
    final signerIds = actualEndorsers.map((e) => e.id).toSet();

    final blockNumber = _blocks.length + 1;
    final txId = 'tx-${LaMPCrypto.sha256Hex('$fn-$blockNumber-$nowTimestamp-${Random().nextInt(999999)}').substring(0, 32)}';

    final writes = <WriteEntry>[];
    final privateWrites = <PrivateWriteEntry>[];

    final ctx = _LedgerCtx(
      submitterId: asMsp.id,
      ledgerTime: nowTimestamp,
      worldState: _world,
      collections: _collections,
      pendingWrites: writes,
      pendingPrivateWrites: privateWrites,
      onEmit: (ev, p) => _eventController.add({'event': ev, 'payload': p}),
    );

    // 1. Verify Endorsement Policy
    final satisfiesPolicy = PolicyParser.satisfies(policy, signerIds);

    final endorsements = actualEndorsers.map((e) {
      final cert = LaMPCrypto.sha256Hex('cert:${e.id}').substring(0, 16);
      final sig = LaMPCrypto.sha256Hex('sig:${e.id}:$txId').substring(0, 24);
      return Endorsement(msp: e.id, signature: sig, certFingerprint: cert);
    }).toList();

    if (!satisfiesPolicy) {
      final tx = ChainTx(
        txId: txId,
        blockNumber: blockNumber,
        timestamp: nowTimestamp,
        submitter: asMsp.id,
        fn: fn,
        args: args,
        status: TxStatus.endorsementPolicyFailure,
        message: 'ENDORSEMENT_POLICY_FAILURE: Missing required endorsement signatures.',
        policy: policy,
        endorsements: endorsements,
        writes: [],
        privateWrites: [],
      );
      _recordBlock(tx, nowTimestamp);
      return SubmitResult(
        ok: false,
        error: tx.message,
        tx: tx,
      );
    }

    // 2. Execute Chaincode
    try {
      dynamic result;
      switch (fn) {
        case 'mintReceivable':
          result = await LaMPContract.mintReceivable(
            ctx,
            tokenId: args['tokenId'] as String,
            invoiceId: args['invoiceId'] as String,
            manufacturerId: args['manufacturerId'] as String,
            buyerDid: args['buyerDid'] as String,
            declaredValue: (args['declaredValue'] as num).toDouble(),
            termsDays: (args['termsDays'] as num).toInt(),
            issuedAt: args['issuedAt'] as int,
            dueDate: args['dueDate'] as int,
            cartonHashes: (args['cartonHashes'] as List<dynamic>).cast<String>(),
            lineItems: (args['lineItems'] as List<dynamic>)
                .map((l) => LineItem.fromJson(Map<String, dynamic>.from(l as Map)))
                .toList(),
          );
          break;

        case 'recordPoD':
          result = await LaMPContract.recordPoD(
            ctx,
            tokenId: args['tokenId'] as String,
            cartonHash: args['cartonHash'] as String,
            mpoSignature: args['mpoSignature'] as String? ?? 'sig:device',
          );
          break;

        case 'recordPoDBatch':
          result = await LaMPContract.recordPoDBatch(
            ctx,
            tokenId: args['tokenId'] as String,
            cartonHashes: (args['cartonHashes'] as List<dynamic>).cast<String>(),
            mpoSignature: args['mpoSignature'] as String? ?? 'sig:device',
          );
          break;

        case 'registerRateCurve':
          final curve = RateCurve.fromJson(Map<String, dynamic>.from(args['curve'] as Map));
          await LaMPContract.registerRateCurve(ctx, curve: curve);
          result = curve;
          break;

        case 'matchAndAdvance':
          result = await LaMPContract.matchAndAdvance(
            ctx,
            tokenId: args['tokenId'] as String,
          );
          break;

        case 'anchorInvoiceDocument':
          result = await LaMPContract.anchorInvoiceDocument(
            ctx,
            tokenId: args['tokenId'] as String,
            sha256: args['sha256'] as String,
            byteLength: (args['byteLength'] as num).toInt(),
            filename: args['filename'] as String,
          );
          break;

        case 'settle':
          result = await LaMPContract.settle(
            ctx,
            tokenId: args['tokenId'] as String,
            paymentRef: args['paymentRef'] as String,
            method: args['method'] as String,
            amount: (args['amount'] as num).toDouble(),
          );
          break;

        case 'raiseDispute':
          result = await LaMPContract.raiseDispute(
            ctx,
            tokenId: args['tokenId'] as String,
            reason: args['reason'] as String,
          );
          break;

        case 'resolveDispute':
          result = await LaMPContract.resolveDispute(
            ctx,
            tokenId: args['tokenId'] as String,
            resolution: args['resolution'] as String,
            restoreTo: args['restoreTo'] != null
                ? TokenState.fromId(args['restoreTo'] as String)
                : null,
          );
          break;

        case 'confirmReceipt':
          result = await LaMPContract.confirmReceipt(
            ctx,
            tokenId: args['tokenId'] as String,
            pharmacySignature: args['pharmacySignature'] as String,
          );
          break;

        default:
          throw ChaincodeException('Unknown chaincode function $fn');
      }

      // Apply state writes
      for (final w in writes) {
        _world[w.key] = w.value;
      }
      for (final pw in privateWrites) {
        _collections.putIfAbsent(pw.collection, () => {})[pw.key] = PrivateEntry(
          members: pw.members,
          value: pw.cleartext,
          hash: pw.hash,
        );
      }

      final tx = ChainTx(
        txId: txId,
        blockNumber: blockNumber,
        timestamp: nowTimestamp,
        submitter: asMsp.id,
        fn: fn,
        args: args,
        status: TxStatus.valid,
        policy: policy,
        endorsements: endorsements,
        writes: writes,
        privateWrites: privateWrites,
      );

      _recordBlock(tx, nowTimestamp);
      return SubmitResult(ok: true, tx: tx, result: result);
    } catch (e) {
      final msg = e.toString();
      final tx = ChainTx(
        txId: txId,
        blockNumber: blockNumber,
        timestamp: nowTimestamp,
        submitter: asMsp.id,
        fn: fn,
        args: args,
        status: TxStatus.chaincodeError,
        message: msg,
        policy: policy,
        endorsements: endorsements,
        writes: [],
        privateWrites: [],
      );

      _recordBlock(tx, nowTimestamp);
      return SubmitResult(ok: false, error: msg, tx: tx);
    }
  }

  void _recordBlock(ChainTx tx, int timestamp) {
    _txs.add(tx);
    final prevHash = _blocks.isEmpty ? genesisHash : _blocks.last.hash;
    final blockPayload =
        '$prevHash:${tx.blockNumber}:${tx.txId}:$timestamp:${tx.status.id}:${tx.fn}:${LaMPCrypto.canonicalJson(tx.writes)}';
    final blockHash = LaMPCrypto.sha256Hex(blockPayload);

    final block = Block(
      number: tx.blockNumber,
      prevHash: prevHash,
      hash: blockHash,
      timestamp: timestamp,
      txs: [tx],
    );
    _blocks.add(block);
  }
}

class _LedgerCtx implements ChainCtx {
  final String submitterId;
  final int ledgerTime;
  final Map<String, dynamic> worldState;
  final Map<String, Map<String, PrivateEntry>> collections;
  final List<WriteEntry> pendingWrites;
  final List<PrivateWriteEntry> pendingPrivateWrites;
  final void Function(String, Map<String, dynamic>) onEmit;

  _LedgerCtx({
    required this.submitterId,
    required this.ledgerTime,
    required this.worldState,
    required this.collections,
    required this.pendingWrites,
    required this.pendingPrivateWrites,
    required this.onEmit,
  });

  @override
  String get submitter => submitterId;

  @override
  int get now => ledgerTime;

  /// Defensive copy of a value read from world state.
  ///
  /// Without this, a chaincode can mutate the live world through the read
  /// reference — `final token = await ctx.get(...); token.state = ...;` would
  /// change the next read before the chaincode writes it back.
  static dynamic _clone(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is List) return List<dynamic>.from(v);
    return v;
  }

  @override
  Future<dynamic> get(String key) async {
    for (final w in pendingWrites.reversed) {
      if (w.key == key) return w.value;
    }
    return _clone(worldState[key]);
  }

  @override
  Future<void> put(String key, dynamic value) async {
    // Replace any earlier pending write for this key. `pendingWrites` is
    // scanned in reverse in `get`, so an appending put would leave a stale
    // value visible to the next read until the writes are applied.
    final existing = pendingWrites.indexWhere((w) => w.key == key);
    if (existing >= 0) {
      pendingWrites[existing] = WriteEntry(key: key, value: value);
      return;
    }
    pendingWrites.add(WriteEntry(key: key, value: value));
  }

  @override
  Future<List<String>> keys(String prefix) async {
    final allKeys = <String>{...worldState.keys, ...pendingWrites.map((w) => w.key)};
    return allKeys.where((k) => k.startsWith(prefix)).toList();
  }

  @override
  Future<List<String>> privateKeys(String collection) async {
    return (collections[collection]?.keys ?? const <String>{}).toList();
  }

  @override
  Future<dynamic> getPrivate(String collection, String key) async {
    final entry = collections[collection]?[key];
    if (entry == null) return null;
    // Membership gate. The submitter of this transaction is the one reading;
    // an outsider transaction gets nothing, even though the world state holds
    // the sealed entry. Mirrors Fabric's implicit collection ACL.
    if (!entry.members.contains(submitterId)) {
      return null;
    }
    return _clone(entry.value);
  }

  @override
  Future<void> putPrivate(
    String collection,
    String key,
    List<String> members,
    dynamic value,
  ) async {
    final hash = LaMPCrypto.hashOf(value);
    pendingPrivateWrites.add(PrivateWriteEntry(
      collection: collection,
      key: key,
      hash: hash,
      members: members,
      cleartext: value,
    ));
  }

  @override
  void emit(String eventName, Map<String, dynamic> payload) {
    onEmit(eventName, payload);
  }
}
