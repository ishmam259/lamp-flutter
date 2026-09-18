import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/ledger_models.dart';
import '../../core/state/lamp_state.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lamp_mark.dart';
import '../../core/constants/typography.dart';

class RegulatorScreen extends StatelessWidget {
  final VoidCallback onBackToLauncher;

  const RegulatorScreen({super.key, required this.onBackToLauncher});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LaMPState>();
    final txs = state.txs;

    // Filter duplicate financing attempts
    final duplicateAttempts = txs.where((t) =>
        t.fn == 'matchAndAdvance' &&
        t.status == TxStatus.chaincodeError &&
        (t.message?.contains('already financed') ?? false)).toList();

    // Filter carton scan rejections
    final cartonFailures = txs.where((t) =>
        t.fn == 'recordPoD' &&
        t.status == TxStatus.chaincodeError).toList();

    // Policy failures
    final policyFailures = txs.where((t) => t.status == TxStatus.endorsementPolicyFailure).toList();

    return Theme(
      data: LaMPTheme.of(context, LampWorld.portal),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF131B17),
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: LaMPColors.portalInk),
            onPressed: onBackToLauncher,
            tooltip: 'All Personas',
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LampMark(size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Regulator Compliance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.portalInk),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.verified_user, size: 16, color: LaMPColors.verified),
                ],
              ),
              Text(
                'Bangladesh Bank · DGDA — Read-Only Observer Node (RegulatorMSP)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: LaMPColors.portalInk3),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Ledger Inspector',
              icon: const Icon(Icons.account_tree_outlined, color: LaMPColors.verified),
              onPressed: () => LedgerInspectorSheet.show(context),
            ),
            IconButton(
              tooltip: 'Demo Director',
              icon: const Icon(Icons.movie_filter_outlined, color: LaMPColors.brand),
              onPressed: () => DemoDirectorSheet.show(context),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          // Android draws its gesture bar over the bottom of the window.
          // Without this the last row of every list sits underneath it.
          // Top is already handled by the AppBar.
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final card1 = _buildMetric(
                          'DUPLICATE FINANCING',
                          '${duplicateAttempts.length} refused',
                          duplicateAttempts.isEmpty ? 'Zero fraud detected' : 'Immediate alert triggered',
                          duplicateAttempts.isEmpty ? LaMPColors.verified : LaMPColors.dispute,
                        );
                        final card2 = _buildMetric(
                          'TRACEABILITY FAILURES',
                          '${cartonFailures.length} rejected',
                          'Mismatched carton scans',
                          cartonFailures.isEmpty ? LaMPColors.verified : LaMPColors.pending,
                        );
                        final card3 = _buildMetric(
                          'POLICY VIOLATIONS',
                          '${policyFailures.length}',
                          'Quorum signature check',
                          policyFailures.isEmpty ? LaMPColors.verified : LaMPColors.dispute,
                        );
  
                        if (constraints.maxWidth < 600) {
                          return Column(
                            children: [
                              card1,
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: card2),
                                  const SizedBox(width: 10),
                                  Expanded(child: card3),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: card1),
                            const SizedBox(width: 12),
                            Expanded(child: card2),
                            const SizedBox(width: 12),
                            Expanded(child: card3),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
  
                    // Duplicate Financing Audit Section (The Money Shot)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B17),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: duplicateAttempts.isNotEmpty ? LaMPColors.dispute : LaMPColors.portalLine,
                          width: duplicateAttempts.isNotEmpty ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_outlined, color: LaMPColors.dispute, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Duplicate Financing Audit Trail',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.portalInk),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: duplicateAttempts.isNotEmpty
                                      ? LaMPColors.dispute.withValues(alpha: 0.15)
                                      : LaMPColors.verified.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  duplicateAttempts.isNotEmpty ? 'ATTEMPTS REFUSED' : 'CLEAN LEDGER',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: duplicateAttempts.isNotEmpty ? LaMPColors.dispute : LaMPColors.verified,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'When a rival bank attempts to finance a receivable that is already financed, the chaincode refuses the advance and records the refusal in an immutable block.',
                            style: TextStyle(fontSize: 12, color: LaMPColors.portalInk2),
                          ),
                          const SizedBox(height: 14),
  
                          if (duplicateAttempts.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: LaMPColors.verified, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'No duplicate financing attempts registered yet. Try submitting an advance from Padma Bank.',
                                    style: TextStyle(fontSize: 12, color: LaMPColors.portalInk3),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: duplicateAttempts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final att = duplicateAttempts[i];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: LaMPColors.dispute.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: LaMPColors.dispute.withValues(alpha: 0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Attempted by: ${att.submitter}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LaMPColors.dispute),
                                          ),
                                          Text('Block #${att.blockNumber}',
                                              style: const TextStyle(fontSize: 11, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: LaMPColors.portalInk3)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        att.message ?? 'Duplicate advance refused',
                                        style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'TxHash: ${att.txId}',
                                        style: const TextStyle(fontSize: 10, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: LaMPColors.hashInk),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
  
                    // Supply Chain Traceability Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B17),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: LaMPColors.portalLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DGDA Medicine Traceability & Serial Authenticity',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LaMPColors.portalInk),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Every scanned carton is cryptographically matched against manufacturer dispatch hashes before release.',
                            style: TextStyle(fontSize: 12, color: LaMPColors.portalInk2),
                          ),
                          const SizedBox(height: 12),
                          for (final cf in cartonFailures)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: LaMPColors.pending, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cf.message ?? 'Carton hash mismatch',
                                      style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk2),
                                    ),
                                  ),
                                  Text(
                                    LaMPFormatters.formatTime(cf.timestamp),
                                    style: const TextStyle(fontSize: 10, fontFamily: LaMPType.mono, fontFamilyFallback: LaMPType.fallback, color: LaMPColors.portalInk3),
                                  ),
                                ],
                              ),
                            ),
                          if (cartonFailures.isEmpty)
                            const Text('All presented medicine cartons authentic and matched to authorized invoices.',
                                style: TextStyle(fontSize: 12, color: LaMPColors.verified)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B17),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LaMPColors.portalLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: LaMPColors.portalInk3)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: LaMPColors.portalInk3)),
        ],
      ),
    );
  }
}
