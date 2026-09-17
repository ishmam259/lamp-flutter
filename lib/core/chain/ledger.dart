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
  int get height => _blocks.length;

  static const String genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  static final Map<String, String> defaultPolicies = {
    'mintReceivable': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
    'recordPoD': "'ManufacturerMSP.peer'",
    'recordPoDBatch': "'ManufacturerMSP.peer'",
    'registerRateCurve': "OR('MeghnaMSP.peer', 'PadmaMSP.peer')",
    'matchAndAdvance': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
    'settle': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
    'raiseDispute': "'ManufacturerMSP.peer'",
    'resolveDispute': "AND('ManufacturerMSP.peer', OR('MeghnaMSP.peer', 'PadmaMSP.peer'))",
  };

  void clear() {
    _world.clear();
    _collections['invoiceLineItems']?.clear();
    _collections['rateCurves']?.clear();
    _blocks.clear();
    _txs.clear();
  }

  void setWorldDirect(String key, dynamic value) {
    _world[key] = value;
  }

  Future<dynamic> readWorld(String key) async => _world[key];

  Future<List<String>> listKeys(String prefix) async {
    return _world.keys.where((k) => k.startsWith(prefix)).toList();
  }

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

  @override
  Future<dynamic> get(String key) async {
    for (final w in pendingWrites.reversed) {
      if (w.key == key) return w.value;
    }
    return worldState[key];
  }

  @override
  Future<void> put(String key, dynamic value) async {
    pendingWrites.add(WriteEntry(key: key, value: value));
  }

  @override
  Future<List<String>> keys(String prefix) async {
    final allKeys = {...worldState.keys, ...pendingWrites.map((w) => w.key)};
    return allKeys.where((k) => k.startsWith(prefix)).toList();
  }

  @override
  Future<dynamic> getPrivate(String collection, String key) async {
    final entry = collections[collection]?[key];
    return entry?.value;
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
