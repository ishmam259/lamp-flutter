import '../models/domain_models.dart';
import '../models/ledger_models.dart';

/// What the ledger records, in the words of the people who use the app.
///
/// The chaincode's function names (`recordPoD`, `matchAndAdvance`), its org
/// ids (`MeghnaMSP`) and its transaction statuses (`CHAINCODE_ERROR`) are the
/// system's vocabulary, not a pharmacist's or a delivery officer's. Screens
/// read them through here and never print them raw.
class LedgerLabels {
  /// The event a transaction records: "Carton scanned", "Invoice financed".
  static String event(String fn) => switch (fn) {
        'mintReceivable' => 'Invoice issued',
        'recordPoD' => 'Carton scanned',
        'recordPoDBatch' => 'Cartons recorded',
        'confirmReceipt' => 'Delivery signed for',
        'matchAndAdvance' => 'Invoice financed',
        'settle' => 'Payment received',
        'raiseDispute' => 'Dispute raised',
        'resolveDispute' => 'Dispute resolved',
        'registerRateCurve' => 'Rate card published',
        'anchorInvoiceDocument' => 'Invoice PDF checked',
        'issueInvoiceDocument' => 'Invoice PDF issued',
        _ => 'Ledger update',
      };

  /// Whether the ledger took it.
  static String status(TxStatus s) => switch (s) {
        TxStatus.valid => 'Recorded',
        TxStatus.chaincodeError => 'Refused',
        TxStatus.endorsementPolicyFailure => 'Not approved',
        TxStatus.mvccReadConflict => 'Conflict',
      };

  /// Why the ledger refused something, in a sentence a person can act on.
  ///
  /// The chaincode's messages are written for its developers — hashes, state
  /// ids, threshold arithmetic. Each known refusal maps to plain words; the
  /// original stays in the ledger view's details for anyone auditing.
  static String reason(String? message) {
    final raw = message ?? '';
    // Connection failures are already written for people.
    if (raw.startsWith("Couldn't reach")) return raw;

    // Two vocabularies reach this: the on-phone chaincode's and the server's
    // (the TypeScript original, which words the same refusals differently).
    // Matched case-insensitively on the phrases the two share or differ by.
    final m = raw.toLowerCase();
    final invoice = RegExp(r'INV-[\w-]+').firstMatch(raw)?.group(0);
    final hours = RegExp(r'\((\d+)h remaining\)').firstMatch(raw)?.group(1);
    final ofInvoice = invoice ?? 'this invoice';
    bool has(String s) => m.contains(s);

    if (has('does not belong')) return "This carton isn't part of $ofInvoice.";
    if (has('already been scanned') || has('already scanned')) {
      return 'This carton was already scanned for $ofInvoice.';
    }
    if (has('no longer accepts delivery scans')) {
      return "This invoice isn't taking scans any more.";
    }
    if (has('already financed') || has('duplicate advance') || has('duplicate financing')) {
      return 'This invoice has already been financed.';
    }
    if (has('financing requires delivered') || has('delivery is not confirmed')) {
      return "This invoice can't be financed until it's delivered.";
    }
    if (has('below the required')) return 'Fewer than 90% of the cartons are confirmed.';
    if (has('dispute window is still open') || has('dispute window has not closed')) {
      return hours == null
          ? 'The dispute window is still open.'
          : 'The dispute window is still open — $hours hours left.';
    }
    if (has('can only be disputed inside it')) {
      return 'The 24 hours to dispute this delivery have passed.';
    }
    if (has('no anchored invoice document')) {
      return 'Check the invoice PDF before financing.';
    }
    if (has('not the invoice issued')) {
      return "This PDF isn't the invoice issued for $ofInvoice.";
    }
    if (has('no invoice document was issued')) {
      return "The manufacturer hasn't issued this invoice's PDF yet.";
    }
    if (has('different document was already issued')) {
      return 'A different PDF was already issued for this invoice.';
    }
    if (has('already anchored')) {
      return 'A different PDF is already recorded for this invoice.';
    }
    if (has('sha256 must be')) return "That file couldn't be read as an invoice PDF.";
    if (has('no active dispute') || has('not under dispute')) {
      return "There's no open dispute to resolve.";
    }
    if (has('under active dispute') || has('under dispute')) {
      return 'This invoice is under dispute.';
    }
    if (has('no registered rate curve')) {
      return "No rate card covers this pharmacy's credit tier yet.";
    }
    if (has('already settled') || has('settled or closed')) {
      return 'This invoice is already closed.';
    }
    if (has('settlement requires') || has('cannot be settled')) {
      return "This invoice can't be paid yet.";
    }
    if (has('disputes are only valid') || has('dispute can only be raised')) {
      return "This invoice can't be disputed at this stage.";
    }
    if (has('cartons delivered (need')) return 'Fewer than 90% of the cartons were delivered.';
    if (has('has not recorded the delivery')) {
      return "The ledger hasn't recorded this delivery yet.";
    }
    if (has('at least one carton') || has('no cartons declared')) {
      return 'Add at least one carton.';
    }
    if (has('batch contained no cartons')) return 'There were no cartons to record.';
    if (has('declaredvalue must be positive') || has('declared value must be positive')) {
      return 'The invoice total must be more than zero.';
    }
    if (has('duedate')) return 'The due date must be after the issue date.';
    if (has('already has an active receivable') || has('already carries an unsettled')) {
      return 'This invoice has already been issued.';
    }
    if (has('needs a reason') || has('resolution note is required')) return 'Add a reason.';
    if (has('not found') || has('does not exist')) return "We couldn't find this invoice.";
    if (has('endorsement') || has('policy')) return "It didn't get every approval it needs.";
    return "The ledger didn't accept this.";
  }

  /// An organisation by the name people know it by, from its ledger id.
  static String org(String mspId) {
    for (final m in Msp.values) {
      if (m.id == mspId) return m.fullName;
    }
    return mspId;
  }
}
