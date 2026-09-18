import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/colors.dart';
import '../core/constants/formatters.dart';
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
    final state = context.watch<LaMPState>();
    final txs = state.txs.reversed.toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: LaMPColors.portalLine2, width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_tree_outlined, color: LaMPColors.verified, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Ledger Inspector',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: LaMPColors.portalInk,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: LaMPColors.verified.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE BLOCKS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: LaMPColors.verified,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LaMPColors.portalSurface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: LaMPColors.portalLine),
                  ),
                  child: Text(
                    'Block Height: ${state.blockHeight}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                      fontWeight: FontWeight.bold,
                      color: LaMPColors.portalInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: LaMPColors.portalLine, height: 1),

          Expanded(
            child: txs.isEmpty
                ? const Center(
                    child: Text(
                      'No transactions yet on ledger',
                      style: TextStyle(color: LaMPColors.portalInk3),
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
    Color statusColor;
    switch (tx.status) {
      case TxStatus.valid:
        statusColor = LaMPColors.verified;
        break;
      case TxStatus.endorsementPolicyFailure:
      case TxStatus.chaincodeError:
        statusColor = LaMPColors.dispute;
        break;
      case TxStatus.mvccReadConflict:
        statusColor = LaMPColors.pending;
        break;
    }

    return InkWell(
      onTap: () => _showTxDetail(context, tx),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131B17),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: LaMPColors.portalLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'blk ${tx.blockNumber}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                          color: LaMPColors.portalInk2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tx.fn,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                        color: LaMPColors.portalInk,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TxID: ${LaMPFormatters.shortHash(tx.txId, head: 10, tail: 8)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                    color: LaMPColors.hashInk,
                  ),
                ),
                Text(
                  LaMPFormatters.formatTime(tx.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback,
                    color: LaMPColors.portalInk3,
                  ),
                ),
              ],
            ),
            if (tx.message != null) ...[
              const SizedBox(height: 4),
              Text(
                tx.message!,
                style: const TextStyle(
                  fontSize: 11,
                  color: LaMPColors.dispute,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: LaMPColors.brand, size: 20),
            const SizedBox(width: 8),
            Text(
              'Tx ${LaMPFormatters.shortHash(tx.txId, head: 8, tail: 6)}',
              style: const TextStyle(fontSize: 16, color: LaMPColors.portalInk),
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
                _detailRow('Function', tx.fn, mono: true),
                _detailRow('Block', '${tx.blockNumber}', mono: true),
                _detailRow('Status', tx.status.label),
                _detailRow('Submitter', tx.submitter, mono: true),
                _detailRow('Time', LaMPFormatters.formatDateTime(tx.timestamp)),
                const SizedBox(height: 10),
                const Text(
                  'ENDORSEMENT POLICY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: LaMPColors.portalInk3),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tx.policy,
                    style: const TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: LaMPColors.portalInk),
                  ),
                ),
                const Text(
                  'SIGNATURES & MSP ENDORSEMENTS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: LaMPColors.portalInk3),
                ),
                const SizedBox(height: 4),
                for (final e in tx.endorsements)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.msp, style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk)),
                        Text('cert: ${e.certFingerprint}',
                            style: const TextStyle(fontSize: 10, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: LaMPColors.hashInk)),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'WRITES TO LEDGER',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: LaMPColors.portalInk3),
                ),
                const SizedBox(height: 4),
                for (final w in tx.writes)
                  Text(
                    '• ${w.key}',
                    style: const TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: LaMPColors.portalInk2),
                  ),
                if (tx.writes.isEmpty)
                  const Text('No public state mutated', style: TextStyle(fontSize: 11, color: LaMPColors.portalInk3)),
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

  Widget _detailRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: LaMPColors.portalInk3)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
              color: LaMPColors.portalInk,
            ),
          ),
        ],
      ),
    );
  }
}
