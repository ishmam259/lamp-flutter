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

/// Every record on the ledger, newest first, in plain words — filterable to
/// what was recorded, what was refused, and what carries private data.
class LedgerInspectorSheet extends StatefulWidget {
  const LedgerInspectorSheet({super.key});

  static void show(BuildContext context) {
    LumaSheet.showOwnShell<void>(
      context: context,
      builder: (_) => const LedgerInspectorSheet(),
    );
  }

  @override
  State<LedgerInspectorSheet> createState() => _LedgerInspectorSheetState();
}

/// Which records the list shows.
enum _Filter {
  all('All'),
  recorded('Recorded'),
  refused('Refused'),
  private('Private');

  final String label;
  const _Filter(this.label);

  bool matches(ChainTx tx) => switch (this) {
        _Filter.all => true,
        _Filter.recorded => tx.status == TxStatus.valid,
        _Filter.refused => tx.status != TxStatus.valid,
        // Records whose details are withheld from everyone but the parties —
        // an invoice's line items, for instance.
        _Filter.private => tx.privateWrites.isNotEmpty,
      };
}

class _LedgerInspectorSheetState extends State<LedgerInspectorSheet> {
  _Filter _filter = _Filter.all;

  /// Which invoice a record is about, when it names one.
  static String? _invoiceFor(LaMPState state, ChainTx tx) {
    final tokenId = tx.args['tokenId'];
    if (tokenId is! String) return null;
    return state.viewFor(tokenId)?.token.invoiceId;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LaMPState>();
    final all = state.txs.reversed.toList();
    final refused = all.where((t) => t.status != TxStatus.valid).length;
    final txs = all.where(_filter.matches).toList();

    return LumaSheetShell(
      title: 'Ledger',
      subtitle: refused == 0
          ? '${all.length} records'
          : '${all.length} records · $refused refused',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Filter>(
                segments: [
                  for (final f in _Filter.values)
                    ButtonSegment(
                      value: f,
                      // Counts are in the subtitle; in the segments they made
                      // one label shrink to fit and the row read unevenly.
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text(f.label)),
                    ),
                ],
                selected: {_filter},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
          Expanded(
            child: txs.isEmpty
                ? LampEmpty(
                    icon: Icons.receipt_long_outlined,
                    title: all.isEmpty ? 'Nothing recorded yet' : 'Nothing here',
                    message: all.isEmpty
                        ? 'Records appear here as soon as anything is written.'
                        : switch (_filter) {
                            _Filter.refused => 'The ledger has refused nothing.',
                            _Filter.private => 'No record carries private details.',
                            _ => 'No records match.',
                          },
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
