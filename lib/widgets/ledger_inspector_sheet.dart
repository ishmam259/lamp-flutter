import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/formatters.dart';
import '../core/constants/ledger_labels.dart';
import '../core/constants/palette.dart';
import '../core/design/luma_sheet.dart';
import '../core/models/ledger_models.dart';
import '../core/state/lamp_state.dart';
import '../core/constants/typography.dart';
import 'ui/lamp_ledger_ui.dart';
import 'ui/lamp_ui.dart';

class LedgerInspectorSheet extends StatelessWidget {
  const LedgerInspectorSheet({super.key});

  static void show(BuildContext context) {
    LumaSheet.showOwnShell<void>(
      context: context,
      builder: (_) => const LedgerInspectorSheet(),
    );
  }

  /// Which invoice a record is about, when it names one.
  static String? _invoiceFor(LaMPState state, ChainTx tx) {
    final tokenId = tx.args['tokenId'];
    if (tokenId is! String) return null;
    return state.viewFor(tokenId)?.token.invoiceId;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LaMPState>();
    final txs = state.txs.reversed.toList();
    final refused = txs.where((t) => t.status != TxStatus.valid).length;

    return LumaSheetShell(
      title: 'Ledger',
      subtitle: refused == 0
          ? '${txs.length} records'
          : '${txs.length} records · $refused refused',
      child: Column(
        children: [
          Expanded(
            child: txs.isEmpty
                ? const LampEmpty(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nothing recorded yet',
                    message: 'Records appear here as soon as anything is written.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(Gap.lg),
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
                    itemBuilder: (ctx, i) => _buildTxTile(context, state, txs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxTile(BuildContext context, LaMPState state, ChainTx tx) {
    final c = context.lamp;
    final ok = tx.status == TxStatus.valid;
    final invoice = _invoiceFor(state, tx);

    return InkWell(
      onTap: () => _showTxDetail(context, state, tx),
      borderRadius: BorderRadius.circular(LaMPRadius.card),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(LaMPRadius.card),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LedgerLabels.event(tx.fn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LaMPType.sub.copyWith(color: c.ink),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                LampStateChip(
                  ok ? LampState.confirmed : LampState.refused,
                  LedgerLabels.status(tx.status),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(
              [
                if (invoice != null) invoice,
                LedgerLabels.org(tx.submitter),
                '${LaMPFormatters.formatDateShort(tx.timestamp)}, '
                    '${LaMPFormatters.formatClock(tx.timestamp)}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LaMPType.caption.copyWith(color: c.inkFaint),
            ),
            if (!ok) ...[
              const SizedBox(height: Gap.xs),
              Text(
                LedgerLabels.reason(tx.message),
                style: LaMPType.caption.copyWith(color: c.dispute),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The full record. Plain facts first; the ledger references an auditor
  /// quotes — block and record id — at the foot, where they belong.
  void _showTxDetail(BuildContext context, LaMPState state, ChainTx tx) {
    final c = context.lamp;
    final invoice = _invoiceFor(state, tx);
    final approvers = tx.endorsements.map((e) => LedgerLabels.org(e.msp)).toSet();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaMPRadius.surface),
        ),
        title: Text(
          LedgerLabels.event(tx.fn),
          style: LaMPType.head.copyWith(color: c.ink),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                LampKeyValue(label: 'Status', value: LedgerLabels.status(tx.status)),
                if (tx.status != TxStatus.valid)
                  LampKeyValue(label: 'Why', value: LedgerLabels.reason(tx.message)),
                if (invoice != null) LampKeyValue(label: 'Invoice', value: invoice, mono: true),
                LampKeyValue(label: 'By', value: LedgerLabels.org(tx.submitter)),
                LampKeyValue(
                  label: 'When',
                  value: '${LaMPFormatters.formatDate(tx.timestamp)}, '
                      '${LaMPFormatters.formatClock(tx.timestamp)}',
                ),
                if (approvers.isNotEmpty)
                  LampKeyValue(label: 'Approved by', value: approvers.join(', ')),
                Divider(height: Gap.xl, thickness: 1, color: c.line),
                const LampEyebrow('Reference'),
                const SizedBox(height: Gap.xs),
                Text(
                  'Block ${tx.blockNumber} · ${tx.txId}',
                  style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
