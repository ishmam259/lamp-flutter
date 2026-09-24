// LaMP Domain Models
// Mirroring whitepaper §4.2, §4.4, §4.6

enum Msp {
  manufacturerMSP('ManufacturerMSP', 'Shomota Pharmaceuticals Ltd', 'Shomota', 'manufacturer', true),
  meghnaMSP('MeghnaMSP', 'Meghna Commercial Bank', 'Meghna', 'bank', true),
  padmaMSP('PadmaMSP', 'Padma Bank Ltd', 'Padma', 'bank', true),
  regulatorMSP('RegulatorMSP', 'Bangladesh Bank / DGDA', 'Regulator', 'regulator', false);

  final String id;
  final String fullName;
  final String shortName;
  final String kind;
  final bool isEndorsing;

  const Msp(this.id, this.fullName, this.shortName, this.kind, this.isEndorsing);

  static Msp fromId(String id) {
    return Msp.values.firstWhere(
      (m) => m.id == id,
      orElse: () => Msp.manufacturerMSP,
    );
  }
}

enum TokenState {
  created('CREATED', 'Created'),
  partiallyFulfilled('PARTIALLY_FULFILLED', 'Partially Fulfilled'),
  delivered('DELIVERED', 'Delivered'),
  disputed('DISPUTED', 'Disputed'),
  financed('FINANCED', 'Financed'),
  settled('SETTLED', 'Settled'),
  defaulted('DEFAULTED', 'Defaulted');

  final String id;
  final String label;

  const TokenState(this.id, this.label);

  static TokenState fromId(String id) {
    return TokenState.values.firstWhere(
      (s) => s.id == id,
      orElse: () => TokenState.created,
    );
  }
}

enum RecourseTier {
  newTier('NEW', 'New', 0, 3, 'No on-chain history. Full manufacturer recourse, conservative advance.'),
  building('BUILDING', 'Building', 3, 8, 'History accumulating. Recourse begins shifting toward the bank.'),
  established('ESTABLISHED', 'Established', 8, 16, 'Demonstrated repayment. Bank carries most of the exposure.'),
  prime('PRIME', 'Prime', 16, null, 'Fully bankable counterparty. No manufacturer recourse.');

  final String id;
  final String label;
  final int minCycles;
  final int? cyclesToNext;
  final String blurb;

  const RecourseTier(this.id, this.label, this.minCycles, this.cyclesToNext, this.blurb);

  static RecourseTier fromId(String id) {
    return RecourseTier.values.firstWhere(
      (t) => t.id == id,
      orElse: () => RecourseTier.building,
    );
  }
}

class Product {
  final String sku;
  final String gtin;
  final String name;
  final String strength;
  final String form;
  final double unitPrice;
  final int unitsPerCarton;

  const Product({
    required this.sku,
    required this.gtin,
    required this.name,
    required this.strength,
    required this.form,
    required this.unitPrice,
    required this.unitsPerCarton,
  });

  Map<String, dynamic> toJson() => {
    'sku': sku,
    'gtin': gtin,
    'name': name,
    'strength': strength,
    'form': form,
    'unitPrice': unitPrice,
    'unitsPerCarton': unitsPerCarton,
  };
}

class Pharmacy {
  final String did;
  final String name;
  final String ownerName;
  final String nameBn;
  final String phone;
  final String territory;
  final String address;
  final String licenceNo;
  final int since;

  const Pharmacy({
    required this.did,
    required this.name,
    required this.ownerName,
    required this.nameBn,
    required this.phone,
    required this.territory,
    required this.address,
    required this.licenceNo,
    required this.since,
  });

  Map<String, dynamic> toJson() => {
    'did': did,
    'name': name,
    'ownerName': ownerName,
    'nameBn': nameBn,
    'phone': phone,
    'territory': territory,
    'address': address,
    'licenceNo': licenceNo,
    'since': since,
  };
}

class Mpo {
  final String id;
  final String name;
  final String phone;
  final String territory;
  final String deviceId;
  final String manufacturerId;

  const Mpo({
    required this.id,
    required this.name,
    required this.phone,
    required this.territory,
    required this.deviceId,
    required this.manufacturerId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'territory': territory,
    'deviceId': deviceId,
    'manufacturerId': manufacturerId,
  };
}

class Manufacturer {
  final String id;
  final Msp msp;
  final String name;
  final String category;
  final String depot;

  const Manufacturer({
    required this.id,
    required this.msp,
    required this.name,
    required this.category,
    required this.depot,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'msp': msp.id,
    'name': name,
    'category': category,
    'depot': depot,
  };
}

class LineItem {
  final String sku;
  final String name;
  final String strength;
  final int quantity;
  final int cartons;
  final double unitPrice;
  final double lineValue;

  const LineItem({
    required this.sku,
    required this.name,
    required this.strength,
    required this.quantity,
    required this.cartons,
    required this.unitPrice,
    required this.lineValue,
  });

  Map<String, dynamic> toJson() => {
    'sku': sku,
    'name': name,
    'strength': strength,
    'quantity': quantity,
    'cartons': cartons,
    'unitPrice': unitPrice,
    'lineValue': lineValue,
  };

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    sku: json['sku'] as String,
    name: json['name'] as String,
    strength: json['strength'] as String,
    quantity: (json['quantity'] as num).toInt(),
    cartons: (json['cartons'] as num).toInt(),
    unitPrice: (json['unitPrice'] as num).toDouble(),
    lineValue: (json['lineValue'] as num).toDouble(),
  );
}

class Carton {
  final String cartonId;
  final String gs1;
  final String hash;
  final String sku;
  final String batch;
  final String expiry;
  int? scannedAt;
  bool? rejected;
  String? rejectReason;

  Carton({
    required this.cartonId,
    required this.gs1,
    required this.hash,
    required this.sku,
    required this.batch,
    required this.expiry,
    this.scannedAt,
    this.rejected,
    this.rejectReason,
  });

  Map<String, dynamic> toJson() => {
    'cartonId': cartonId,
    'gs1': gs1,
    'hash': hash,
    'sku': sku,
    'batch': batch,
    'expiry': expiry,
    if (scannedAt != null) 'scannedAt': scannedAt,
    if (rejected != null) 'rejected': rejected,
    if (rejectReason != null) 'rejectReason': rejectReason,
  };

  factory Carton.fromJson(Map<String, dynamic> json) => Carton(
    cartonId: json['cartonId'] as String,
    gs1: json['gs1'] as String,
    hash: json['hash'] as String,
    sku: json['sku'] as String,
    batch: json['batch'] as String,
    expiry: json['expiry'] as String,
    scannedAt: json['scannedAt'] as int?,
    rejected: json['rejected'] as bool?,
    rejectReason: json['rejectReason'] as String?,
  );
}

enum DeliveryStatus {
  pending('PENDING'),
  inTransit('IN_TRANSIT'),
  scanning('SCANNING'),
  awaitingConfirmation('AWAITING_CONFIRMATION'),
  completed('COMPLETED'),
  disputed('DISPUTED');

  final String id;
  const DeliveryStatus(this.id);

  static DeliveryStatus fromId(String id) =>
      DeliveryStatus.values.firstWhere(
        (s) => s.id == id,
        orElse: () => DeliveryStatus.pending,
      );
}

class Delivery {
  final String id;
  final String invoiceId;
  final String tokenId;
  final String mpoId;
  final String pharmacyDid;
  DeliveryStatus status;
  final int sequence;
  final List<Carton> cartons;
  String? signatureRef;
  List<String>? photoRefs;
  int? startedAt;
  int? completedAt;

  Delivery({
    required this.id,
    required this.invoiceId,
    required this.tokenId,
    required this.mpoId,
    required this.pharmacyDid,
    required this.status,
    required this.sequence,
    required this.cartons,
    this.signatureRef,
    this.photoRefs,
    this.startedAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceId': invoiceId,
    'tokenId': tokenId,
    'mpoId': mpoId,
    'pharmacyDid': pharmacyDid,
    'status': status.id,
    'sequence': sequence,
    'cartons': cartons.map((c) => c.toJson()).toList(),
    if (signatureRef != null) 'signatureRef': signatureRef,
    if (photoRefs != null) 'photoRefs': photoRefs,
    if (startedAt != null) 'startedAt': startedAt,
    if (completedAt != null) 'completedAt': completedAt,
  };

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    id: json['id'] as String,
    invoiceId: json['invoiceId'] as String,
    tokenId: json['tokenId'] as String,
    mpoId: json['mpoId'] as String,
    pharmacyDid: json['pharmacyDid'] as String,
    status: DeliveryStatus.fromId(json['status'] as String),
    sequence: (json['sequence'] as num).toInt(),
    cartons: ((json['cartons'] as List<dynamic>?) ?? [])
        .map((c) => Carton.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList(),
    signatureRef: json['signatureRef'] as String?,
    photoRefs: (json['photoRefs'] as List<dynamic>?)?.cast<String>(),
    startedAt: (json['startedAt'] as num?)?.toInt(),
    completedAt: (json['completedAt'] as num?)?.toInt(),
  );
}

class Financing {
  final Msp bankMsp;
  final String curveId;
  final double advanceRatePct;
  final double feePct;
  final double advancedAmount;
  final int financedAt;
  final double manufacturerRecoursePct;

  const Financing({
    required this.bankMsp,
    required this.curveId,
    required this.advanceRatePct,
    required this.feePct,
    required this.advancedAmount,
    required this.financedAt,
    required this.manufacturerRecoursePct,
  });

  Map<String, dynamic> toJson() => {
    'bankMsp': bankMsp.id,
    'curveId': curveId,
    'advanceRatePct': advanceRatePct,
    'feePct': feePct,
    'advancedAmount': advancedAmount,
    'financedAt': financedAt,
    'manufacturerRecoursePct': manufacturerRecoursePct,
  };

  factory Financing.fromJson(Map<String, dynamic> json) => Financing(
    bankMsp: Msp.fromId(json['bankMsp'] as String),
    curveId: json['curveId'] as String,
    advanceRatePct: (json['advanceRatePct'] as num).toDouble(),
    feePct: (json['feePct'] as num).toDouble(),
    advancedAmount: (json['advancedAmount'] as num).toDouble(),
    financedAt: json['financedAt'] as int,
    manufacturerRecoursePct: (json['manufacturerRecoursePct'] as num).toDouble(),
  );
}

class Settlement {
  final int settledAt;
  final double amount;
  final String method; // bKash, Nagad, Bank Transfer
  final String paymentRef;
  final bool onTime;

  const Settlement({
    required this.settledAt,
    required this.amount,
    required this.method,
    required this.paymentRef,
    required this.onTime,
  });

  Map<String, dynamic> toJson() => {
    'settledAt': settledAt,
    'amount': amount,
    'method': method,
    'paymentRef': paymentRef,
    'onTime': onTime,
  };

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
    settledAt: json['settledAt'] as int,
    amount: (json['amount'] as num).toDouble(),
    method: json['method'] as String,
    paymentRef: json['paymentRef'] as String,
    onTime: json['onTime'] as bool,
  );
}

class DisputeRecord {
  final String reason;
  final int raisedAt;
  String? resolution;
  int? resolvedAt;
  TokenState? restoredTo;

  DisputeRecord({
    required this.reason,
    required this.raisedAt,
    this.resolution,
    this.resolvedAt,
    this.restoredTo,
  });

  Map<String, dynamic> toJson() => {
    'reason': reason,
    'raisedAt': raisedAt,
    if (resolution != null) 'resolution': resolution,
    if (resolvedAt != null) 'resolvedAt': resolvedAt,
    if (restoredTo != null) 'restoredTo': restoredTo?.id,
  };

  factory DisputeRecord.fromJson(Map<String, dynamic> json) => DisputeRecord(
    reason: json['reason'] as String,
    raisedAt: json['raisedAt'] as int,
    resolution: json['resolution'] as String?,
    resolvedAt: json['resolvedAt'] as int?,
    restoredTo: json['restoredTo'] != null ? TokenState.fromId(json['restoredTo'] as String) : null,
  );
}

class ReceivableToken {
  final String tokenId;
  final String invoiceId;
  final Msp manufacturerMsp;
  final String manufacturerId;
  final String buyerDid;
  final double declaredValue;
  final String currency;
  final int termsDays;
  final int issuedAt;
  final int observedAt;
  final bool datesAsserted;
  final int dueDate;
  final List<String> cartonHashes;
  List<String> scannedHashes;
  double deliveryRatio;
  TokenState state;
  final int disputeWindowMs;
  int? podAt;
  int? disputeWindowClosesAt;
  String? disputeReason;
  TokenState? preDisputeState;
  List<DisputeRecord> disputes;
  Financing? financing;
  Settlement? settlement;
  String? pharmacySignature;
  int? receivedAt;
  final String lineItemsHash;
  String? documentHash;
  int? documentAnchoredAt;
  String? documentAnchoredBy;
  int? documentByteLength;
  String? documentFilename;

  ReceivableToken({
    required this.tokenId,
    required this.invoiceId,
    required this.manufacturerMsp,
    required this.manufacturerId,
    required this.buyerDid,
    required this.declaredValue,
    this.currency = 'BDT',
    required this.termsDays,
    required this.issuedAt,
    required this.observedAt,
    this.datesAsserted = false,
    required this.dueDate,
    required this.cartonHashes,
    required this.scannedHashes,
    required this.deliveryRatio,
    required this.state,
    this.disputeWindowMs = 24 * 3600 * 1000,
    this.podAt,
    this.disputeWindowClosesAt,
    this.disputeReason,
    this.preDisputeState,
    List<DisputeRecord>? disputes,
    this.financing,
    this.settlement,
    this.pharmacySignature,
    this.receivedAt,
    required this.lineItemsHash,
    this.documentHash,
    this.documentAnchoredAt,
    this.documentAnchoredBy,
    this.documentByteLength,
    this.documentFilename,
  }) : disputes = disputes ?? [];

  Map<String, dynamic> toJson() => {
    'tokenId': tokenId,
    'invoiceId': invoiceId,
    'manufacturerMsp': manufacturerMsp.id,
    'manufacturerId': manufacturerId,
    'buyerDid': buyerDid,
    'declaredValue': declaredValue,
    'currency': currency,
    'termsDays': termsDays,
    'issuedAt': issuedAt,
    'observedAt': observedAt,
    'datesAsserted': datesAsserted,
    'dueDate': dueDate,
    'cartonHashes': cartonHashes,
    'scannedHashes': scannedHashes,
    'deliveryRatio': deliveryRatio,
    'state': state.id,
    'disputeWindowMs': disputeWindowMs,
    if (podAt != null) 'podAt': podAt,
    if (disputeWindowClosesAt != null) 'disputeWindowClosesAt': disputeWindowClosesAt,
    if (disputeReason != null) 'disputeReason': disputeReason,
    if (preDisputeState != null) 'preDisputeState': preDisputeState?.id,
    'disputes': disputes.map((d) => d.toJson()).toList(),
    if (financing != null) 'financing': financing!.toJson(),
    if (settlement != null) 'settlement': settlement!.toJson(),
    if (pharmacySignature != null) 'pharmacySignature': pharmacySignature,
    if (receivedAt != null) 'receivedAt': receivedAt,
    'lineItemsHash': lineItemsHash,
    if (documentHash != null) 'documentHash': documentHash,
    if (documentAnchoredAt != null) 'documentAnchoredAt': documentAnchoredAt,
    if (documentAnchoredBy != null) 'documentAnchoredBy': documentAnchoredBy,
    if (documentByteLength != null) 'documentByteLength': documentByteLength,
    if (documentFilename != null) 'documentFilename': documentFilename,
  };

  factory ReceivableToken.fromJson(Map<String, dynamic> json) => ReceivableToken(
    tokenId: json['tokenId'] as String,
    invoiceId: json['invoiceId'] as String,
    manufacturerMsp: Msp.fromId(json['manufacturerMsp'] as String),
    manufacturerId: json['manufacturerId'] as String,
    buyerDid: json['buyerDid'] as String,
    declaredValue: (json['declaredValue'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'BDT',
    termsDays: (json['termsDays'] as num).toInt(),
    issuedAt: json['issuedAt'] as int,
    observedAt: json['observedAt'] as int,
    datesAsserted: json['datesAsserted'] as bool? ?? false,
    dueDate: json['dueDate'] as int,
    cartonHashes: (json['cartonHashes'] as List<dynamic>).cast<String>(),
    scannedHashes: (json['scannedHashes'] as List<dynamic>).cast<String>(),
    deliveryRatio: (json['deliveryRatio'] as num).toDouble(),
    state: TokenState.fromId(json['state'] as String),
    disputeWindowMs: json['disputeWindowMs'] as int? ?? 24 * 3600 * 1000,
    podAt: json['podAt'] as int?,
    disputeWindowClosesAt: json['disputeWindowClosesAt'] as int?,
    disputeReason: json['disputeReason'] as String?,
    preDisputeState: json['preDisputeState'] != null ? TokenState.fromId(json['preDisputeState'] as String) : null,
    disputes: (json['disputes'] as List<dynamic>?)?.map((e) => DisputeRecord.fromJson(e as Map<String, dynamic>)).toList(),
    financing: json['financing'] != null ? Financing.fromJson(json['financing'] as Map<String, dynamic>) : null,
    settlement: json['settlement'] != null ? Settlement.fromJson(json['settlement'] as Map<String, dynamic>) : null,
    pharmacySignature: json['pharmacySignature'] as String?,
    receivedAt: json['receivedAt'] as int?,
    lineItemsHash: json['lineItemsHash'] as String,
    documentHash: json['documentHash'] as String?,
    documentAnchoredAt: json['documentAnchoredAt'] as int?,
    documentAnchoredBy: json['documentAnchoredBy'] as String?,
    documentByteLength: json['documentByteLength'] as int?,
    documentFilename: json['documentFilename'] as String?,
  );
}

class RateCurveBand {
  final RecourseTier tier;
  final double advanceRatePct;
  final double feePct;
  final double manufacturerRecoursePct;
  final double maxInvoiceValue;

  const RateCurveBand({
    required this.tier,
    required this.advanceRatePct,
    required this.feePct,
    required this.manufacturerRecoursePct,
    required this.maxInvoiceValue,
  });

  Map<String, dynamic> toJson() => {
    'tier': tier.id,
    'advanceRatePct': advanceRatePct,
    'feePct': feePct,
    'manufacturerRecoursePct': manufacturerRecoursePct,
    'maxInvoiceValue': maxInvoiceValue,
  };

  factory RateCurveBand.fromJson(Map<String, dynamic> json) => RateCurveBand(
    tier: RecourseTier.fromId(json['tier'] as String),
    advanceRatePct: (json['advanceRatePct'] as num).toDouble(),
    feePct: (json['feePct'] as num).toDouble(),
    manufacturerRecoursePct: (json['manufacturerRecoursePct'] as num).toDouble(),
    maxInvoiceValue: (json['maxInvoiceValue'] as num).toDouble(),
  );
}

class RateCurve {
  final String curveId;
  final Msp bankMsp;
  final int registeredAt;
  final List<RateCurveBand> bands;

  const RateCurve({
    required this.curveId,
    required this.bankMsp,
    required this.registeredAt,
    required this.bands,
  });

  Map<String, dynamic> toJson() => {
    'curveId': curveId,
    'bankMsp': bankMsp.id,
    'registeredAt': registeredAt,
    'bands': bands.map((b) => b.toJson()).toList(),
  };

  factory RateCurve.fromJson(Map<String, dynamic> json) => RateCurve(
    curveId: json['curveId'] as String,
    bankMsp: Msp.fromId(json['bankMsp'] as String),
    registeredAt: json['registeredAt'] as int,
    bands: (json['bands'] as List<dynamic>).map((e) => RateCurveBand.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class CreditCycle {
  final String tokenId;
  final String invoiceId;
  final double value;
  final int dueDate;
  final int settledAt;
  final int observedAt;
  final bool onTime;
  final int daysLate;

  const CreditCycle({
    required this.tokenId,
    required this.invoiceId,
    required this.value,
    required this.dueDate,
    required this.settledAt,
    required this.observedAt,
    required this.onTime,
    required this.daysLate,
  });

  Map<String, dynamic> toJson() => {
    'tokenId': tokenId,
    'invoiceId': invoiceId,
    'value': value,
    'dueDate': dueDate,
    'settledAt': settledAt,
    'observedAt': observedAt,
    'onTime': onTime,
    'daysLate': daysLate,
  };

  factory CreditCycle.fromJson(Map<String, dynamic> json) => CreditCycle(
    tokenId: json['tokenId'] as String,
    invoiceId: json['invoiceId'] as String,
    value: (json['value'] as num).toDouble(),
    dueDate: json['dueDate'] as int,
    settledAt: json['settledAt'] as int,
    observedAt: json['observedAt'] as int,
    onTime: json['onTime'] as bool,
    daysLate: (json['daysLate'] as num).toInt(),
  );
}

class CreditHistory {
  final String pharmacyDid;
  final List<CreditCycle> cycles;
  RecourseTier tier;
  int onTimeCount;
  int lateCount;
  int defaultCount;

  CreditHistory({
    required this.pharmacyDid,
    required this.cycles,
    required this.tier,
    required this.onTimeCount,
    required this.lateCount,
    required this.defaultCount,
  });

  Map<String, dynamic> toJson() => {
    'pharmacyDid': pharmacyDid,
    'cycles': cycles.map((c) => c.toJson()).toList(),
    'tier': tier.id,
    'onTimeCount': onTimeCount,
    'lateCount': lateCount,
    'defaultCount': defaultCount,
  };

  factory CreditHistory.fromJson(Map<String, dynamic> json) => CreditHistory(
    pharmacyDid: json['pharmacyDid'] as String,
    cycles: (json['cycles'] as List<dynamic>).map((e) => CreditCycle.fromJson(e as Map<String, dynamic>)).toList(),
    tier: RecourseTier.fromId(json['tier'] as String),
    onTimeCount: (json['onTimeCount'] as num).toInt(),
    lateCount: (json['lateCount'] as num).toInt(),
    defaultCount: (json['defaultCount'] as num).toInt(),
  );
}

class Invoice {
  final String invoiceId;
  final String tokenId;
  final String manufacturerId;
  final String pharmacyDid;
  final List<LineItem> lineItems;
  final double value;
  final int termsDays;
  final int issuedAt;
  final int dueDate;
  final int cartonCount;

  const Invoice({
    required this.invoiceId,
    required this.tokenId,
    required this.manufacturerId,
    required this.pharmacyDid,
    required this.lineItems,
    required this.value,
    required this.termsDays,
    required this.issuedAt,
    required this.dueDate,
    required this.cartonCount,
  });

  Map<String, dynamic> toJson() => {
    'invoiceId': invoiceId,
    'tokenId': tokenId,
    'manufacturerId': manufacturerId,
    'pharmacyDid': pharmacyDid,
    'lineItems': lineItems.map((l) => l.toJson()).toList(),
    'value': value,
    'termsDays': termsDays,
    'issuedAt': issuedAt,
    'dueDate': dueDate,
    'cartonCount': cartonCount,
  };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    invoiceId: json['invoiceId'] as String,
    tokenId: json['tokenId'] as String,
    manufacturerId: json['manufacturerId'] as String,
    pharmacyDid: json['pharmacyDid'] as String,
    lineItems: ((json['lineItems'] as List<dynamic>?) ?? [])
        .map((l) => LineItem.fromJson(Map<String, dynamic>.from(l as Map)))
        .toList(),
    value: (json['value'] as num).toDouble(),
    termsDays: (json['termsDays'] as num).toInt(),
    issuedAt: (json['issuedAt'] as num).toInt(),
    dueDate: (json['dueDate'] as num).toInt(),
    cartonCount: (json['cartonCount'] as num).toInt(),
  );
}

/// The bytes the manufacturer stored off-chain for an anchored invoice document.
///
/// The chaincode anchor only carries the SHA-256 digest — to actually serve
/// "what was anchored" later (verify download, PDF share-sheet), the bytes
/// themselves live off-chain. Storing them verbatim (rather than regenerating
/// from a template on download) is deliberate: a future PDF library upgrade
/// must not be able to silently invalidate a financier's earlier verification.
///
/// `base64` keeps the JSON snapshot self-contained, since Dart's `jsonEncode`
/// has no native bytes. Bytes are usually 4–20 KB, so the overhead is fine.
class StoredDocument {
  final String filename;
  final String sha256;
  final int byteLength;
  final String base64;
  final int at;

  const StoredDocument({
    required this.filename,
    required this.sha256,
    required this.byteLength,
    required this.base64,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'sha256': sha256,
    'byteLength': byteLength,
    'base64': base64,
    'at': at,
  };

  factory StoredDocument.fromJson(Map<String, dynamic> json) => StoredDocument(
    filename: json['filename'] as String,
    sha256: json['sha256'] as String,
    byteLength: (json['byteLength'] as num).toInt(),
    base64: json['base64'] as String,
    at: (json['at'] as num).toInt(),
  );
}
