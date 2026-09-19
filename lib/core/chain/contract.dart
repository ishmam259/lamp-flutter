import '../models/domain_models.dart';
import 'crypto.dart';

class ChaincodeException implements Exception {
  final String message;
  const ChaincodeException(this.message);

  @override
  String toString() => message;
}

abstract class ChainCtx {
  String get submitter;
  int get now;

  Future<dynamic> get(String key);
  Future<void> put(String key, dynamic value);
  Future<List<String>> keys(String prefix);

  Future<dynamic> getPrivate(String collection, String key);
  Future<List<String>> privateKeys(String collection);
  Future<void> putPrivate(String collection, String key, List<String> members, dynamic value);

  void emit(String eventName, Map<String, dynamic> payload);
}

class ChainKeys {
  static String token(String tokenId) => 'token:$tokenId';
  static String invoiceIndex(String invoiceId) => 'invoice:$invoiceId';
  static String credit(String did) => 'credit:$did';
  static String curveHash(String curveId) => 'curvehash:$curveId';
  static String financedIndex(String invoiceId) => 'financed:$invoiceId';
}

class LaMPContract {
  static const double confirmationThreshold = 0.90;
  static const int defaultDisputeWindowMs = 24 * 3600 * 1000;

  // 1. Mint Receivable
  static Future<ReceivableToken> mintReceivable(
    ChainCtx ctx, {
    required String tokenId,
    required String invoiceId,
    required String manufacturerId,
    required String buyerDid,
    required double declaredValue,
    required int termsDays,
    required int issuedAt,
    required int dueDate,
    required List<String> cartonHashes,
    required List<LineItem> lineItems,
  }) async {
    // Data-level guards. The endorsement policy already restricts the submitter
    // to ManufacturerMSP's peer; these checks make the body of the transaction
    // refuse to mint nonsense on top of that.
    if (cartonHashes.isEmpty) {
      throw ChaincodeException(
        'Mint $tokenId refused: a receivable must anchor at least one carton.',
      );
    }
    if (declaredValue <= 0) {
      throw ChaincodeException(
        'Mint $tokenId refused: declaredValue must be positive (got $declaredValue).',
      );
    }
    if (dueDate <= issuedAt) {
      throw ChaincodeException(
        'Mint $tokenId refused: dueDate ($dueDate) must be after issuedAt ($issuedAt).',
      );
    }

    final existingTokenId = await ctx.get(ChainKeys.invoiceIndex(invoiceId));
    if (existingTokenId != null) {
      throw ChaincodeException(
        'Invoice $invoiceId already has an active receivable token ($existingTokenId). Double-minting is prohibited.',
      );
    }

    final lineItemsHash = LaMPCrypto.hashOf(lineItems.map((l) => l.toJson()).toList());

    // Private line items collection
    await ctx.putPrivate(
      'invoiceLineItems',
      tokenId,
      ['ManufacturerMSP', 'MeghnaMSP', 'PadmaMSP'],
      lineItems.map((l) => l.toJson()).toList(),
    );

    final token = ReceivableToken(
      tokenId: tokenId,
      invoiceId: invoiceId,
      manufacturerMsp: Msp.fromId(ctx.submitter),
      manufacturerId: manufacturerId,
      buyerDid: buyerDid,
      declaredValue: declaredValue,
      termsDays: termsDays,
      issuedAt: issuedAt,
      observedAt: ctx.now,
      dueDate: dueDate,
      cartonHashes: cartonHashes,
      scannedHashes: [],
      deliveryRatio: 0.0,
      state: TokenState.created,
      lineItemsHash: lineItemsHash,
    );

    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    await ctx.put(ChainKeys.invoiceIndex(invoiceId), tokenId);

    ctx.emit('ReceivableMinted', {'tokenId': tokenId, 'invoiceId': invoiceId});
    return token;
  }

  // 2. Record Proof of Delivery Scan (single carton)
  static Future<ReceivableToken> recordPoD(
    ChainCtx ctx, {
    required String tokenId,
    required String cartonHash,
    required String mpoSignature,
  }) async {
    final raw = await ctx.get(ChainKeys.token(tokenId));
    if (raw == null) {
      throw ChaincodeException('Receivable token $tokenId not found.');
    }
    final token = ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));

    if (token.state == TokenState.settled || token.state == TokenState.defaulted) {
      throw ChaincodeException('Token $tokenId is already settled or closed.');
    }

    // Membership test
    if (!token.cartonHashes.contains(cartonHash)) {
      throw ChaincodeException(
        'Carton with hash ${cartonHash.substring(0, 10)}… does not belong to invoice ${token.invoiceId}.',
      );
    }

    // Reject double-scans. The Fabric TS port throws here; the Dart version
    // used to silently no-op, which let a buggy scanner pad the deliveryRatio.
    if (token.scannedHashes.contains(cartonHash)) {
      throw ChaincodeException(
        'Carton has already been scanned for invoice ${token.invoiceId}.',
      );
    }

    token.scannedHashes.add(cartonHash);
    token.deliveryRatio = token.cartonHashes.isNotEmpty
        ? token.scannedHashes.length / token.cartonHashes.length
        : 1.0;

    // Whitepaper 4.2: a consignment is delivered at 90% of its manifest, not
    // at every last carton. Requiring 1.0 here made `confirmationThreshold`
    // dead on this path, and put the chaincode at odds with the number the
    // bank's eligibility checklist prints.
    if (token.deliveryRatio >= confirmationThreshold) {
      token.state = TokenState.delivered;
      token.podAt ??= ctx.now;
      // Anchored to ctx.now (block time) rather than scan time, mirroring the
      // TS Fabric port's `businessTime()` default. A live deployment that
      // wants scan-time would thread it through as an asserted business time.
      token.disputeWindowClosesAt ??= ctx.now + token.disputeWindowMs;
    } else {
      token.state = TokenState.partiallyFulfilled;
    }

    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    ctx.emit('PoDRecorded', {
      'tokenId': tokenId,
      'scanned': token.scannedHashes.length,
      'total': token.cartonHashes.length,
      'ratio': token.deliveryRatio,
    });

    return token;
  }

  // 3. Record PoD Batch (offline scan drain)
  static Future<ReceivableToken> recordPoDBatch(
    ChainCtx ctx, {
    required String tokenId,
    required List<String> cartonHashes,
    required String mpoSignature,
  }) async {
    final raw = await ctx.get(ChainKeys.token(tokenId));
    if (raw == null) {
      throw ChaincodeException('Receivable token $tokenId not found.');
    }
    final token = ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));

    for (final h in cartonHashes) {
      // Membership test per hash — the TS port throws here rather than
      // silently dropping unknowns, which would let a misrouted scanner slip
      // a partial count past the chaincode.
      if (!token.cartonHashes.contains(h)) {
        throw ChaincodeException(
          'Carton with hash ${h.substring(0, h.length < 10 ? h.length : 10)}… does not belong to invoice ${token.invoiceId}.',
        );
      }
      // Reject duplicates inside the batch too, so a scanner retrying after a
      // crash cannot re-count a carton it already wrote to the ledger.
      if (token.scannedHashes.contains(h)) {
        throw ChaincodeException(
          'Carton has already been scanned for invoice ${token.invoiceId}.',
        );
      }
      token.scannedHashes.add(h);
    }

    token.deliveryRatio = token.cartonHashes.isNotEmpty
        ? token.scannedHashes.length / token.cartonHashes.length
        : 1.0;

    if (token.deliveryRatio >= confirmationThreshold) {
      token.state = TokenState.delivered;
      token.podAt ??= ctx.now;
      token.disputeWindowClosesAt ??= ctx.now + token.disputeWindowMs;
    } else if (token.scannedHashes.isNotEmpty) {
      token.state = TokenState.partiallyFulfilled;
    }

    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    ctx.emit('PoDBatchRecorded', {
      'tokenId': tokenId,
      'scanned': token.scannedHashes.length,
      'ratio': token.deliveryRatio,
    });
    return token;
  }

  // 4. Register Rate Curve (Bank)
  static Future<void> registerRateCurve(
    ChainCtx ctx, {
    required RateCurve curve,
  }) async {
    final curveJson = curve.toJson();
    final curveHash = LaMPCrypto.hashOf(curveJson);

    await ctx.putPrivate('rateCurves', curve.curveId, [curve.bankMsp.id], curveJson);
    await ctx.put(ChainKeys.curveHash(curve.curveId), {
      'curveId': curve.curveId,
      'bankMsp': curve.bankMsp.id,
      'hash': curveHash,
      'registeredAt': ctx.now,
    });
  }

  // 5. Match and Advance (Smart Contract Financing)
  static Future<ReceivableToken> matchAndAdvance(
    ChainCtx ctx, {
    required String tokenId,
  }) async {
    final raw = await ctx.get(ChainKeys.token(tokenId));
    if (raw == null) {
      throw ChaincodeException('Token $tokenId not found.');
    }
    final token = ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));

    // Double-financing check
    if (token.financing != null || token.state == TokenState.financed) {
      throw ChaincodeException(
        'Receivable $tokenId (Invoice ${token.invoiceId}) is already financed by ${token.financing?.bankMsp.shortName ?? "another bank"}. Duplicate financing refused.',
      );
    }

    final financedIndex = await ctx.get(ChainKeys.financedIndex(token.invoiceId));
    if (financedIndex != null) {
      throw ChaincodeException(
        'Invoice ${token.invoiceId} was already financed on token $financedIndex. Duplicate advance rejected.',
      );
    }

    // An advance fires only against a fully delivered receivable. Checked
    // first so a CREATED or PARTIALLY_FULFILLED token surfaces the lifecycle
    // reason for the rejection — a token with no scans yet would also fail
    // the ratio check, but the chaincode's caller is better served by the
    // exact state mismatch. Mirrors the ordering in the TS Fabric port.
    if (token.state != TokenState.delivered) {
      throw ChaincodeException(
        'Receivable $tokenId is in state ${token.state.id}; financing requires DELIVERED.',
      );
    }

    // Delivery confirmation check (>= 90%). Belongs after the state guard so
    // it does not out-shout the lifecycle reason on a freshly-minted token.
    if (token.deliveryRatio < confirmationThreshold) {
      throw ChaincodeException(
        'Delivery ratio ${(token.deliveryRatio * 100).toStringAsFixed(1)}% is below the required 90% threshold.',
      );
    }

    // Dispute window check
    final windowCloses = token.disputeWindowClosesAt ?? (token.podAt ?? 0) + token.disputeWindowMs;
    if (ctx.now < windowCloses) {
      final remainingMs = windowCloses - ctx.now;
      final remainingH = (remainingMs / 3600000).toStringAsFixed(1);
      throw ChaincodeException(
        'Dispute window is still open (${remainingH}h remaining). Financing opens after window closes.',
      );
    }

    if (token.state == TokenState.disputed) {
      throw ChaincodeException(
        'Receivable is currently under active dispute: ${token.disputeReason ?? "reason unstated"}.',
      );
    }

    // Counterparty recourse tier comes from the credit history. A buyer with
    // no on-chain history is treated as NEW for matching purposes.
    final rawCredit = await ctx.get(ChainKeys.credit(token.buyerDid));
    RecourseTier tier = RecourseTier.newTier;
    if (rawCredit != null) {
      final credit = CreditHistory.fromJson(Map<String, dynamic>.from(rawCredit as Map));
      tier = credit.tier;
    }

    // Deterministic selection across every registered curve. The bank's own
    // curve is read through `getPrivate`, which enforces membership; outsiders
    // see nothing and the endorsement policy refuses them at submit time, so
    // there is no chance of leaking a competitor's pricing.
    RateCurveBand? bestBand;
    RateCurve? bestCurve;
    for (final curveId in await ctx.privateKeys('rateCurves')) {
      final curveRaw = await ctx.getPrivate('rateCurves', curveId);
      if (curveRaw == null) continue;
      final curve = RateCurve.fromJson(Map<String, dynamic>.from(curveRaw as Map));

      final band = curve.bands.firstWhere(
        (b) => b.tier == tier && token.declaredValue <= b.maxInvoiceValue,
        orElse: () => const RateCurveBand(
          tier: RecourseTier.newTier,
          advanceRatePct: 0,
          feePct: 0,
          manufacturerRecoursePct: 0,
          maxInvoiceValue: 0,
        ),
      );
      if (band.maxInvoiceValue <= 0) continue;

      if (bestBand == null ||
          band.advanceRatePct > bestBand.advanceRatePct ||
          (band.advanceRatePct == bestBand.advanceRatePct &&
              band.feePct < bestBand.feePct)) {
        bestBand = band;
        bestCurve = curve;
      }
    }

    if (bestBand == null || bestCurve == null) {
      throw ChaincodeException(
        'No registered rate curve covers a ${tier.label} counterparty at BDT ${token.declaredValue.toStringAsFixed(2)}.',
      );
    }

    final advancedAmount =
        (token.declaredValue * (bestBand.advanceRatePct / 100.0)).roundToDouble();

    token.financing = Financing(
      bankMsp: bestCurve.bankMsp,
      curveId: bestCurve.curveId,
      advanceRatePct: bestBand.advanceRatePct,
      feePct: bestBand.feePct,
      advancedAmount: advancedAmount,
      financedAt: ctx.now,
      manufacturerRecoursePct: bestBand.manufacturerRecoursePct,
    );

    token.state = TokenState.financed;
    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    await ctx.put(ChainKeys.financedIndex(token.invoiceId), tokenId);

    ctx.emit('ReceivableFinanced', {
      'tokenId': tokenId,
      'bank': bestCurve.bankMsp.id,
      'advancedAmount': advancedAmount,
      'advanceRate': bestBand.advanceRatePct,
    });

    return token;
  }

  // 6. Settle (Repayment & Credit History Update)
  static Future<Map<String, dynamic>> settle(
    ChainCtx ctx, {
    required String tokenId,
    required String paymentRef,
    required String method,
    required double amount,
  }) async {
    final raw = await ctx.get(ChainKeys.token(tokenId));
    if (raw == null) {
      throw ChaincodeException('Token $tokenId not found.');
    }
    final token = ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));

    // State guard. A receivable must have been financed (or, in the rare
    // self-settle path, fully delivered) before the chaincode accepts the
    // repayment. Settling a CREATED token silently short-circuits the
    // chaincode's "did this advance?" logic in the demo.
    if (token.state != TokenState.financed && token.state != TokenState.delivered) {
      throw ChaincodeException(
        'Receivable $tokenId is in state ${token.state.id}; settlement requires FINANCED or DELIVERED.',
      );
    }

    final isOnTime = ctx.now <= token.dueDate;
    final daysLate = isOnTime ? 0 : ((ctx.now - token.dueDate) / 86400000).ceil();

    token.settlement = Settlement(
      settledAt: ctx.now,
      amount: amount,
      method: method,
      paymentRef: paymentRef,
      onTime: isOnTime,
    );
    token.state = TokenState.settled;
    await ctx.put(ChainKeys.token(tokenId), token.toJson());

    // Update Credit History
    final rawCredit = await ctx.get(ChainKeys.credit(token.buyerDid));
    CreditHistory credit;
    if (rawCredit != null) {
      credit = CreditHistory.fromJson(Map<String, dynamic>.from(rawCredit as Map));
    } else {
      credit = CreditHistory(
        pharmacyDid: token.buyerDid,
        cycles: [],
        tier: RecourseTier.newTier,
        onTimeCount: 0,
        lateCount: 0,
        defaultCount: 0,
      );
    }

    final tierBefore = credit.tier;

    credit.cycles.add(CreditCycle(
      tokenId: tokenId,
      invoiceId: token.invoiceId,
      value: token.declaredValue,
      dueDate: token.dueDate,
      settledAt: ctx.now,
      observedAt: ctx.now,
      onTime: isOnTime,
      daysLate: daysLate,
    ));

    if (isOnTime) {
      credit.onTimeCount++;
    } else {
      credit.lateCount++;
    }

    // Recalculate Recourse Tier based on settled cycles, then apply the
    // late-cycle penalty. A counterparty with >= 2 late settlements drops one
    // tier from what its cycle count alone would have earned; mirrors the
    // TS Fabric port's `tierFor()` and means a chronically-late buyer never
    // gets the cheaper prime-tier advance.
    final totalSettled = credit.cycles.length;
    final earnedTier = _earnedTier(totalSettled, credit.defaultCount);
    final penalized = credit.lateCount >= 2;
    credit.tier = penalized ? _dropOneTier(earnedTier) : earnedTier;

    await ctx.put(ChainKeys.credit(token.buyerDid), credit.toJson());

    ctx.emit('ReceivableSettled', {
      'tokenId': tokenId,
      'onTime': isOnTime,
      'tierBefore': tierBefore.id,
      'tierAfter': credit.tier.id,
    });

    return {
      'token': token,
      'tierBefore': tierBefore,
      'tierAfter': credit.tier,
      'onTime': isOnTime,
    };
  }

  // 7. Raise Dispute
  static Future<ReceivableToken> raiseDispute(
    ChainCtx ctx, {
    required String tokenId,
    required String reason,
  }) async {
    final raw = await ctx.get(ChainKeys.token(tokenId));
    if (raw == null) {
      throw ChaincodeException('Token $tokenId not found.');
    }
    final token = ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));

    // Disputes are only valid against a receivable that has not yet been
    // financed, settled, or written off. Once a bank has advanced against the
    // invoice, recourse follows the rate curve and the financing contract —
    // not a dispute record.
    const disputable = <TokenState>{
      TokenState.created,
      TokenState.partiallyFulfilled,
      TokenState.delivered,
    };
    if (!disputable.contains(token.state)) {
      throw ChaincodeException(
        'Receivable $tokenId is in state ${token.state.id}; disputes are only valid in CREATED, PARTIALLY_FULFILLED, or DELIVERED.',
      );
    }

    token.preDisputeState = token.state;
    token.state = TokenState.disputed;
    token.disputeReason = reason;
    token.disputes.add(DisputeRecord(reason: reason, raisedAt: ctx.now));

    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    ctx.emit('DisputeRaised', {'tokenId': tokenId, 'reason': reason});
    return token;
  }

  // 8. Resolve Dispute
  static Future<ReceivableToken> resolveDispute(
    ChainCtx ctx, {
    required String tokenId,
    required String resolution,
    TokenState? restoreTo,
  }) async {
    final raw = await ctx.get(ChainKeys.token(tokenId));
    if (raw == null) {
      throw ChaincodeException('Token $tokenId not found.');
    }
    final token = ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));

    // Refuse to resolve nothing. The old `lastWhere + orElse` fabricated a
    // synthetic dispute record, mutated the local copy, and then never wrote
    // it back — so subsequent calls would invent another synthetic one. Throw
    // instead.
    final activeDispute = token.disputes.firstWhere(
      (d) => d.resolvedAt == null,
      orElse: () => throw ChaincodeException(
        'Token $tokenId has no active dispute to resolve.',
      ),
    );

    // The restore target is one of the pre-dispute lifecycle states. The TS
    // port refuses to restore straight to FINANCED/SETTLED — those have their
    // own dedicated transactions and a dispute should never land on them.
    final validRestores = <TokenState>{
      TokenState.created,
      TokenState.partiallyFulfilled,
      TokenState.delivered,
    };
    final target = restoreTo ?? token.preDisputeState ?? TokenState.delivered;
    if (!validRestores.contains(target)) {
      throw ChaincodeException(
        'resolveDispute $tokenId: restoreTo must be one of CREATED, PARTIALLY_FULFILLED, DELIVERED (got ${target.id}).',
      );
    }

    activeDispute.resolution = resolution;
    activeDispute.resolvedAt = ctx.now;
    activeDispute.restoredTo = target;

    token.state = target;
    token.disputeReason = null;
    token.preDisputeState = null;

    // Re-arm the dispute window only when returning to DELIVERED. Anything
    // less than DELIVERED has no live PoD to anchor a window against, and a
    // resolved dispute must not be re-financeable on the same day it was
    // raised.
    if (target == TokenState.delivered) {
      token.disputeWindowClosesAt = ctx.now + token.disputeWindowMs;
      token.podAt ??= ctx.now;
    } else {
      token.disputeWindowClosesAt = null;
    }

    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    ctx.emit('DisputeResolved', {'tokenId': tokenId, 'restoredTo': token.state.id});
    return token;
  }

  /* ---------------------------------------------------------------------- */
  /* Tier helpers                                                            */
  /* ---------------------------------------------------------------------- */

  /// The tier a clean settlement history would earn. Lates are handled
  /// separately by [_dropOneTier] so the two rules read independently.
  static RecourseTier _earnedTier(int totalSettled, int defaultCount) {
    if (totalSettled >= 16 && defaultCount == 0) return RecourseTier.prime;
    if (totalSettled >= 8) return RecourseTier.established;
    if (totalSettled >= 3) return RecourseTier.building;
    return RecourseTier.newTier;
  }

  /// Demote one tier — the penalty for two or more late settlements.
  static RecourseTier _dropOneTier(RecourseTier t) {
    switch (t) {
      case RecourseTier.prime:
        return RecourseTier.established;
      case RecourseTier.established:
        return RecourseTier.building;
      case RecourseTier.building:
        return RecourseTier.newTier;
      case RecourseTier.newTier:
        return RecourseTier.newTier;
    }
  }

  /* ---------------------------------------------------------------------- */
  /* 9. confirmReceipt (pharmacy signs to acknowledge delivery)              */
  /* ---------------------------------------------------------------------- */

  /// The pharmacy's signature on a delivered consignment.
  ///
  /// Distinct from `recordPoD` because the actor is different: the chaincode
  /// endorsement policy for `confirmReceipt` is manufacturer-only (the MPO
  /// device has already committed the scans; this transaction only persists
  /// the pharmacy's ink against the ledger). Until this fires, the receipt
  /// exists only on the off-chain `Delivery` model.
  static Future<ReceivableToken> confirmReceipt(
    ChainCtx ctx, {
    required String tokenId,
    required String pharmacySignature,
  }) async {
    final raw = await ctx.get(ChainKeys.token(tokenId));
    if (raw == null) {
      throw ChaincodeException('Token $tokenId not found.');
    }
    final token = ReceivableToken.fromJson(Map<String, dynamic>.from(raw as Map));

    if (token.state == TokenState.settled || token.state == TokenState.defaulted) {
      throw ChaincodeException(
        'Token $tokenId is already settled or closed; a receipt cannot be confirmed.',
      );
    }

    // Receipt only makes sense once every carton on the manifest has been
    // scanned. The threshold guard here matches `matchAndAdvance`'s 90% bar.
    if (token.deliveryRatio < confirmationThreshold) {
      throw ChaincodeException(
        'Receipt $tokenId refused: only ${(token.deliveryRatio * 100).toStringAsFixed(1)}% of cartons delivered (need 90%+).',
      );
    }

    token.pharmacySignature = pharmacySignature;
    token.receivedAt = ctx.now;

    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    ctx.emit('ReceiptConfirmed', {
      'tokenId': tokenId,
      'receivedAt': ctx.now,
    });
    return token;
  }
}
