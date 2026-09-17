// LaMP Ledger & Blockchain Models

enum TxStatus {
  valid('VALID', 'Valid'),
  endorsementPolicyFailure('ENDORSEMENT_POLICY_FAILURE', 'Policy failure'),
  chaincodeError('CHAINCODE_ERROR', 'Rejected'),
  mvccReadConflict('MVCC_READ_CONFLICT', 'Read conflict');

  final String id;
  final String label;

  const TxStatus(this.id, this.label);

  static TxStatus fromId(String id) {
    return TxStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => TxStatus.valid,
    );
  }
}

class Endorsement {
  final String msp;
  final String signature;
  final String certFingerprint;

  const Endorsement({
    required this.msp,
    required this.signature,
    required this.certFingerprint,
  });

  Map<String, dynamic> toJson() => {
    'msp': msp,
    'signature': signature,
    'certFingerprint': certFingerprint,
  };

  factory Endorsement.fromJson(Map<String, dynamic> json) => Endorsement(
    msp: json['msp'] as String,
    signature: json['signature'] as String,
    certFingerprint: json['certFingerprint'] as String,
  );
}

class WriteEntry {
  final String key;
  final dynamic value;

  const WriteEntry({required this.key, required this.value});

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
  };

  factory WriteEntry.fromJson(Map<String, dynamic> json) => WriteEntry(
    key: json['key'] as String,
    value: json['value'],
  );
}

class PrivateWriteEntry {
  final String collection;
  final String key;
  final String hash;
  final List<String> members;
  final dynamic cleartext;

  const PrivateWriteEntry({
    required this.collection,
    required this.key,
    required this.hash,
    required this.members,
    this.cleartext,
  });

  Map<String, dynamic> toJson() => {
    'collection': collection,
    'key': key,
    'hash': hash,
    'members': members,
  };

  factory PrivateWriteEntry.fromJson(Map<String, dynamic> json) => PrivateWriteEntry(
    collection: json['collection'] as String,
    key: json['key'] as String,
    hash: json['hash'] as String,
    members: (json['members'] as List<dynamic>).cast<String>(),
  );
}

class ChainTx {
  final String txId;
  final int blockNumber;
  final int timestamp;
  final String submitter;
  final String fn;
  final Map<String, dynamic> args;
  final TxStatus status;
  final String? message;
  final String policy;
  final List<Endorsement> endorsements;
  final List<WriteEntry> writes;
  final List<PrivateWriteEntry> privateWrites;

  const ChainTx({
    required this.txId,
    required this.blockNumber,
    required this.timestamp,
    required this.submitter,
    required this.fn,
    required this.args,
    required this.status,
    this.message,
    required this.policy,
    required this.endorsements,
    required this.writes,
    this.privateWrites = const [],
  });

  Map<String, dynamic> toJson() => {
    'txId': txId,
    'blockNumber': blockNumber,
    'timestamp': timestamp,
    'submitter': submitter,
    'fn': fn,
    'args': args,
    'status': status.id,
    if (message != null) 'message': message,
    'policy': policy,
    'endorsements': endorsements.map((e) => e.toJson()).toList(),
    'writes': writes.map((w) => w.toJson()).toList(),
    'privateWrites': privateWrites.map((p) => p.toJson()).toList(),
  };

  factory ChainTx.fromJson(Map<String, dynamic> json) => ChainTx(
    txId: json['txId'] as String,
    blockNumber: (json['blockNumber'] as num).toInt(),
    timestamp: (json['timestamp'] as num).toInt(),
    submitter: json['submitter'] as String,
    fn: json['fn'] as String,
    args: (json['args'] as Map<String, dynamic>?) ?? {},
    status: TxStatus.fromId(json['status'] as String),
    message: json['message'] as String?,
    policy: json['policy'] as String? ?? '',
    endorsements: ((json['endorsements'] as List<dynamic>?) ?? [])
        .map((e) => Endorsement.fromJson(e as Map<String, dynamic>))
        .toList(),
    writes: ((json['writes'] as List<dynamic>?) ?? [])
        .map((w) => WriteEntry.fromJson(w as Map<String, dynamic>))
        .toList(),
    privateWrites: ((json['privateWrites'] as List<dynamic>?) ?? [])
        .map((p) => PrivateWriteEntry.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}

class Block {
  final int number;
  final String prevHash;
  final String hash;
  final int timestamp;
  final List<ChainTx> txs;

  const Block({
    required this.number,
    required this.prevHash,
    required this.hash,
    required this.timestamp,
    required this.txs,
  });

  Map<String, dynamic> toJson() => {
    'number': number,
    'prevHash': prevHash,
    'hash': hash,
    'timestamp': timestamp,
    'txs': txs.map((t) => t.toJson()).toList(),
  };

  factory Block.fromJson(Map<String, dynamic> json) => Block(
    number: (json['number'] as num).toInt(),
    prevHash: json['prevHash'] as String,
    hash: json['hash'] as String,
    timestamp: (json['timestamp'] as num).toInt(),
    txs: ((json['txs'] as List<dynamic>?) ?? [])
        .map((t) => ChainTx.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
  );
}

class ChainDescriptor {
  final bool authoritative;
  final String channel;
  final String chaincode;
  final int height;
  final int peerCount;
  final bool tlsEnabled;

  const ChainDescriptor({
    required this.authoritative,
    this.channel = 'lamp-channel',
    this.chaincode = 'lamp',
    required this.height,
    this.peerCount = 4,
    this.tlsEnabled = true,
  });
}
