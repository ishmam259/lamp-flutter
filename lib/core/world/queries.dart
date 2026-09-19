/// Joins over ledger state — the Dart counterpart of `LaMP/lib/world/queries.ts`.
///
/// Every screen used to do this work itself, against a single hard-coded
/// `demoTokenId`: five copies of "find the invoice for this token", eight of
/// "how many cartons have been scanned", and no copy at all of "which of these
/// is still open". That is why a settled invoice stayed on the pharmacy's
/// dashboard and a financed one stayed in the bank's queue — there was no list
/// to drop out of.
///
/// Nothing here is async. [LocalLedger] keeps world state in a plain map, so a
/// future would only have forced every list on every screen through a
/// `FutureBuilder`.
library;

import '../chain/ledger.dart';
import '../models/domain_models.dart';
import 'seed.dart';

/// A token with the off-chain records that describe it.
///
/// Mirrors `TokenView` in `queries.ts`. The token is authoritative; the other
/// three are the paperwork around it and any of them may be missing.
class TokenView {
  final ReceivableToken token;
  final Invoice? invoice;
  final Pharmacy? pharmacy;
  final Delivery? delivery;

  const TokenView({
    required this.token,
    this.invoice,
    this.pharmacy,
    this.delivery,
  });

  String get tokenId => token.tokenId;
  String get invoiceId => token.invoiceId;

  /// The invoice value, falling back to the token's own declared value.
  ///
  /// The token is what the chaincode priced, so it wins over a stale off-chain
  /// row rather than the other way round.
  double get value => token.declaredValue;
}

/// Questions about a single token that more than one screen asks.
///
/// These are the conditions the chaincode itself enforces, written once so a
/// screen cannot offer an action the ledger is going to refuse.
extension TokenQueries on ReceivableToken {
  /// Still owed. Settled receivables leave every "what do I owe" list.
  bool get isOpen => state != TokenState.settled;

  /// `settle` accepts DELIVERED or FINANCED and nothing else.
  ///
  /// FINANCED is payable: a bank advancing against the receivable pays the
  /// *manufacturer*, and does not discharge the pharmacy's debt.
  bool get isPayable =>
      state == TokenState.delivered || state == TokenState.financed;

  bool get isFinanced => financing != null;

  int get scanned => scannedHashes.length;
  int get declaredCartons => cartonHashes.length;

  /// Cartons the ledger has accepted, as a share of those declared.
  ///
  /// Read this rather than counting `Carton.scannedAt` off-chain: the two can
  /// disagree, and only this one gates the chaincode.
  double get scannedRatio =>
      cartonHashes.isEmpty ? 0.0 : scannedHashes.length / cartonHashes.length;

  bool get isFullyScanned =>
      cartonHashes.isNotEmpty && scannedHashes.length >= cartonHashes.length;

  bool disputeWindowClosed(int now) =>
      disputeWindowClosesAt != null && now >= disputeWindowClosesAt!;

  /// What `matchAndAdvance` will accept: delivered, undisputed, window closed.
  bool isFinanceable(int now) =>
      state == TokenState.delivered && disputeWindowClosed(now);

  /// Delivered, but the 24-hour objection period has not run out yet.
  bool isAwaitingWindow(int now) =>
      state == TokenState.delivered && !disputeWindowClosed(now);

  int millisUntilWindowCloses(int now) =>
      disputeWindowClosesAt == null ? 0 : disputeWindowClosesAt! - now;
}

class LaMPQueries {
  const LaMPQueries._();

  /* ---------------------------------------------------------------- */
  /* On-chain                                                         */
  /* ---------------------------------------------------------------- */

  /// Every receivable on the ledger, newest first — `queries.ts:51-54`.
  static List<ReceivableToken> listTokens(LocalLedger ledger) {
    final out = <ReceivableToken>[];
    for (final key in ledger.listKeysSync('token:')) {
      final token = _tokenAt(ledger, key);
      if (token != null) out.add(token);
    }
    out.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return out;
  }

  static ReceivableToken? getToken(LocalLedger ledger, String tokenId) =>
      _tokenAt(ledger, 'token:$tokenId');

  static CreditHistory? getCredit(LocalLedger ledger, String pharmacyDid) {
    final raw = ledger.readWorldSync('credit:$pharmacyDid');
    if (raw is! Map) return null;
    return CreditHistory.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<CreditHistory> listCredit(LocalLedger ledger) {
    final out = <CreditHistory>[];
    for (final key in ledger.listKeysSync('credit:')) {
      final raw = ledger.readWorldSync(key);
      if (raw is Map) {
        out.add(CreditHistory.fromJson(Map<String, dynamic>.from(raw)));
      }
    }
    return out;
  }

  /* ---------------------------------------------------------------- */
  /* Off-chain                                                        */
  /* ---------------------------------------------------------------- */

  static Pharmacy? findPharmacy(String did) {
    for (final p in SeedData.pharmacies) {
      if (p.did == did) return p;
    }
    return null;
  }

  static Invoice? findInvoiceByToken(List<Invoice> invoices, String tokenId) {
    for (final i in invoices) {
      if (i.tokenId == tokenId) return i;
    }
    return null;
  }

  static Delivery? findDelivery(List<Delivery> deliveries, String tokenId) {
    for (final d in deliveries) {
      if (d.tokenId == tokenId) return d;
    }
    return null;
  }

  /* ---------------------------------------------------------------- */
  /* Joined views                                                     */
  /* ---------------------------------------------------------------- */

  /// Mirrors `listTokenViews` — `queries.ts:101-110`.
  static List<TokenView> listTokenViews(
    LocalLedger ledger,
    List<Invoice> invoices,
    List<Delivery> deliveries,
  ) {
    return listTokens(ledger)
        .map((token) => TokenView(
              token: token,
              invoice: findInvoiceByToken(invoices, token.tokenId),
              pharmacy: findPharmacy(token.buyerDid),
              delivery: findDelivery(deliveries, token.tokenId),
            ))
        .toList();
  }

  static TokenView? getTokenView(
    LocalLedger ledger,
    List<Invoice> invoices,
    List<Delivery> deliveries,
    String tokenId,
  ) {
    final token = getToken(ledger, tokenId);
    if (token == null) return null;
    return TokenView(
      token: token,
      invoice: findInvoiceByToken(invoices, tokenId),
      pharmacy: findPharmacy(token.buyerDid),
      delivery: findDelivery(deliveries, tokenId),
    );
  }

  /* ---------------------------------------------------------------- */

  static ReceivableToken? _tokenAt(LocalLedger ledger, String key) {
    final raw = ledger.readWorldSync(key);
    if (raw is! Map) return null;
    return ReceivableToken.fromJson(Map<String, dynamic>.from(raw));
  }
}
