import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/formatters.dart';
import '../core/constants/palette.dart';
import '../core/models/ledger_models.dart';
import '../core/state/lamp_state.dart';
import '../core/constants/typography.dart';

class LedgerInspectorSheet extends StatelessWidget {
  const LedgerInspectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LedgerInspectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final state = context.watch<LaMPState>();
    final txs = state.txs.reversed.toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: c.lineStrong, width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.lineStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Title and "live" badge. The badge was a third item on this
                // row and pushed it 124 pixels past the sheet; the block count
                // beside it already says the feed is live.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_tree_outlined, color: c.verified, size: IconSize.md),
                    const SizedBox(width: Gap.sm),
                    Text('Ledger', style: LaMPType.head.copyWith(color: c.ink)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.line),
                  ),
                  child: Text(
                    'Block Height: ${state.blockHeight}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                      fontWeight: FontWeight.bold,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: c.line, height: 1),

          Expanded(
            child: txs.isEmpty
                ? Center(
                    child: Text(
                      'No transactions yet on ledger',
                      style: TextStyle(color: c.inkFaint),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildTxTile(context, txs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxTile(BuildContext context, ChainTx tx) {
    final c = context.lamp;
    Color statusColor;
    switch (tx.status) {
      case TxStatus.valid:
        statusColor = c.verified;
        break;
      case TxStatus.endorsementPolicyFailure:
      case TxStatus.chaincodeError:
        statusColor = c.dispute;
        break;
      case TxStatus.mvccReadConflict:
        statusColor = c.pending;
        break;
    }

    return InkWell(
      onTap: () => _showTxDetail(context, tx),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // The function name flexes. `recordPoDBatch` beside a block
                // badge and a status chip is what overflowed here.
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${tx.blockNumber}',
                          style: LaMPType.monoCaption.copyWith(color: c.inkMuted),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          tx.fn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LaMPType.monoBody.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tx.status.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // The hash is the half that can afford to shorten; the timestamp
            // keeps its width. Unflexed, the pair overflowed by 69.
            Row(
              children: [
                Expanded(
                  child: Text(
                    LaMPFormatters.shortHash(tx.txId, head: 8, tail: 6),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  LaMPFormatters.formatTime(tx.timestamp),
                  style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
                ),
              ],
            ),
            if (tx.message != null) ...[
              const SizedBox(height: 4),
              Text(
                tx.message!,
                style: TextStyle(
                  fontSize: 11,
                  color: c.dispute,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTxDetail(BuildContext context, ChainTx tx) {
    final c = context.lamp;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: c.brand, size: 20),
            const SizedBox(width: 8),
            Text(
              'Tx ${LaMPFormatters.shortHash(tx.txId, head: 8, tail: 6)}',
              style: TextStyle(fontSize: 16, color: c.ink),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(context, 'Function', tx.fn, mono: true),
                _detailRow(context, 'Block', '${tx.blockNumber}', mono: true),
                _detailRow(context, 'Status', tx.status.label),
                _detailRow(context, 'Submitter', tx.submitter, mono: true),
                _detailRow(context, 'Time', LaMPFormatters.formatDateTime(tx.timestamp)),
                const SizedBox(height: 8),
                Text(
                  'ENDORSEMENT POLICY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.inkFaint),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.surfaceSunken,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tx.policy,
                    style: TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: c.ink),
                  ),
                ),
                Text(
                  'SIGNATURES & MSP ENDORSEMENTS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.inkFaint),
                ),
                const SizedBox(height: 4),
                for (final e in tx.endorsements)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.surfaceSunken,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.msp, style: TextStyle(fontSize: 11, color: c.ink)),
                        Text('cert: ${e.certFingerprint}',
                            style: TextStyle(fontSize: 10, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: c.inkFaint)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'WRITES TO LEDGER',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.inkFaint),
                ),
                const SizedBox(height: 4),
                for (final w in tx.writes)
                  Text(
                    '• ${w.key}',
                    style: TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: c.inkMuted),
                  ),
                if (tx.writes.isEmpty)
                  Text('No public state mutated', style: TextStyle(fontSize: 11, color: c.inkFaint)),
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

  Widget _detailRow(BuildContext context, String label, String value, {bool mono = false}) {
    final c = context.lamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.inkFaint)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}
