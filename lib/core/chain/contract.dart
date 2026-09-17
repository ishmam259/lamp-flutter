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

    if (!token.scannedHashes.contains(cartonHash)) {
      token.scannedHashes.add(cartonHash);
      token.deliveryRatio = token.cartonHashes.isNotEmpty
          ? token.scannedHashes.length / token.cartonHashes.length
          : 1.0;

      if (token.deliveryRatio >= 1.0) {
        token.state = TokenState.delivered;
        token.podAt ??= ctx.now;
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
    }

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
      if (token.cartonHashes.contains(h) && !token.scannedHashes.contains(h)) {
        token.scannedHashes.add(h);
      }
    }

    token.deliveryRatio = token.cartonHashes.isNotEmpty
        ? token.scannedHashes.length / token.cartonHashes.length
        : 1.0;

    if (token.deliveryRatio >= 1.0) {
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

    // Delivery confirmation check (>= 90%)
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

    // Determine counterparty recourse tier
    final rawCredit = await ctx.get(ChainKeys.credit(token.buyerDid));
    RecourseTier tier = RecourseTier.building;
    if (rawCredit != null) {
      final credit = CreditHistory.fromJson(Map<String, dynamic>.from(rawCredit as Map));
      tier = credit.tier;
    }

    // Default curve pricing parameters based on tier
    double advanceRate;
    double feeRate;
    double mfrRecourse;

    switch (tier) {
      case RecourseTier.newTier:
        advanceRate = 70.0;
        feeRate = 10.5;
        mfrRecourse = 60.0;
        break;
      case RecourseTier.building:
        advanceRate = 80.0;
        feeRate = 8.8;
        mfrRecourse = 30.0;
        break;
      case RecourseTier.established:
        advanceRate = 85.0;
        feeRate = 7.5;
        mfrRecourse = 10.0;
        break;
      case RecourseTier.prime:
        advanceRate = 90.0;
        feeRate = 6.2;
        mfrRecourse = 0.0;
        break;
    }

    final advancedAmount = (token.declaredValue * (advanceRate / 100.0)).roundToDouble();

    token.financing = Financing(
      bankMsp: Msp.fromId(ctx.submitter),
      curveId: 'curve-${ctx.submitter.toLowerCase()}',
      advanceRatePct: advanceRate,
      feePct: feeRate,
      advancedAmount: advancedAmount,
      financedAt: ctx.now,
      manufacturerRecoursePct: mfrRecourse,
    );

    token.state = TokenState.financed;
    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    await ctx.put(ChainKeys.financedIndex(token.invoiceId), tokenId);

    ctx.emit('ReceivableFinanced', {
      'tokenId': tokenId,
      'bank': ctx.submitter,
      'advancedAmount': advancedAmount,
      'advanceRate': advanceRate,
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

    // Recalculate Recourse Tier based on settled cycles
    final totalSettled = credit.cycles.length;
    if (totalSettled >= 16 && credit.defaultCount == 0) {
      credit.tier = RecourseTier.prime;
    } else if (totalSettled >= 8) {
      credit.tier = RecourseTier.established;
    } else if (totalSettled >= 3) {
      credit.tier = RecourseTier.building;
    } else {
      credit.tier = RecourseTier.newTier;
    }

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

    final activeDispute = token.disputes.lastWhere(
      (d) => d.resolvedAt == null,
      orElse: () => DisputeRecord(reason: 'General dispute', raisedAt: ctx.now),
    );
    activeDispute.resolution = resolution;
    activeDispute.resolvedAt = ctx.now;
    activeDispute.restoredTo = restoreTo ?? token.preDisputeState ?? TokenState.delivered;

    token.state = activeDispute.restoredTo!;
    token.disputeReason = null;
    token.preDisputeState = null;

    await ctx.put(ChainKeys.token(tokenId), token.toJson());
    ctx.emit('DisputeResolved', {'tokenId': tokenId, 'restoredTo': token.state.id});
    return token;
  }
}
