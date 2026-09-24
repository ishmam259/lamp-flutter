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
    final m = message ?? '';
    final invoice = RegExp(r'INV-[\w-]+').firstMatch(m)?.group(0);
    final hours = RegExp(r'\((\d+)h remaining\)').firstMatch(m)?.group(1);
    final ofInvoice = invoice ?? 'this invoice';

    if (m.contains('does not belong to invoice')) {
      return "This carton isn't part of $ofInvoice.";
    }
    if (m.contains('already been scanned')) {
      return 'This carton was already scanned for $ofInvoice.';
    }
    if (m.contains('already financed') || m.contains('Duplicate advance')) {
      return 'This invoice has already been financed.';
    }
    if (m.contains('financing requires DELIVERED')) {
      return "This invoice can't be financed until it's delivered.";
    }
    if (m.contains('below the required')) {
      return 'Fewer than 90% of the cartons are confirmed.';
    }
    if (m.contains('Dispute window is still open')) {
      return hours == null
          ? 'The dispute window is still open.'
          : 'The dispute window is still open — $hours hours left.';
    }
    if (m.contains('under active dispute')) return 'This invoice is under dispute.';
    if (m.contains('No registered rate curve')) {
      return "No rate card covers this pharmacy's credit tier yet.";
    }
    if (m.contains('settlement requires')) return "This invoice can't be paid yet.";
    if (m.contains('disputes are only valid')) {
      return "This invoice can't be disputed at this stage.";
    }
    if (m.contains('no active dispute')) return "There's no open dispute to resolve.";
    if (m.contains('already settled or closed')) return 'This invoice is already closed.';
    if (m.contains('cartons delivered (need')) {
      return 'Fewer than 90% of the cartons were delivered.';
    }
    if (m.contains('at least one carton')) return 'Add at least one carton.';
    if (m.contains('declaredValue must be positive')) {
      return 'The invoice total must be more than zero.';
    }
    if (m.contains('dueDate')) return 'The due date must be after the issue date.';
    if (m.contains('already has an active receivable')) {
      return 'This invoice has already been issued.';
    }
    if (m.contains('not found')) return "We couldn't find this invoice.";
    if (m.toLowerCase().contains('endorsement') || m.toLowerCase().contains('policy')) {
      return "It didn't get every approval it needs.";
    }
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
