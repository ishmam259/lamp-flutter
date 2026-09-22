import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/design/luma_container.dart';
import '../../core/design/luma_frost.dart';
import '../../core/constants/typography.dart';
import '../../core/models/ledger_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/queries.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/theme_toggle.dart';
import '../../widgets/ui/lamp_ui.dart';

/// The supervisory seat. Reads the channel, writes nothing.
///
/// Rebuilt on the shared components after the layout sweep found two
/// overflows here, one of 863 pixels: hand-rolled Rows with unflexed text on
/// both sides, which fit the machine this was written on and nothing narrower.
///
/// The explanatory copy is gone with them. A regulator looking at a refused
/// duplicate advance does not need a paragraph telling them that a rival bank
/// attempting to finance an already-financed receivable will be refused — the
/// refusal is on the screen, with the block number and the transaction that
/// carries it.
class RegulatorScreen extends StatelessWidget {
  final VoidCallback onBackToLauncher;

  const RegulatorScreen({super.key, required this.onBackToLauncher});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: LaMPTheme.of(context, LampWorld.portal),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final state = context.watch<LaMPState>();
    final c = context.lamp;
    final txs = state.txs;

    final duplicateAttempts = txs
        .where((t) =>
            t.fn == 'matchAndAdvance' &&
            t.status == TxStatus.chaincodeError &&
            (t.message?.contains('already financed') ?? false))
        .toList();

    final cartonFailures = txs
        .where((t) => t.fn == 'recordPoD' && t.status == TxStatus.chaincodeError)
        .toList();

    final policyFailures =
        txs.where((t) => t.status == TxStatus.endorsementPolicyFailure).toList();

    // What the network actually holds. The three metrics below counted
    // refusals only, so a regulator opening this seat on a healthy channel saw
    // three zeros and nothing else.
    final views = state.tokenViews;
    final financed = views.where((v) => v.token.isFinanced).toList();
    final settled =
        views.where((v) => v.token.state == TokenState.settled).length;
    final financingVolume = financed.fold<double>(
      0.0,
      (sum, TokenView v) => sum + (v.token.financing?.advancedAmount ?? 0.0),
    );
    final cartonsTraced =
        views.fold<int>(0, (sum, TokenView v) => sum + v.token.scanned);
    final settlementRate =
        views.isEmpty ? 0.0 : settled / views.length * 100.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      // The per-seat bar is `LumaAppBar` now. What went with it: a hand-rolled
      // back button, a title Row wrapping a LampMark and a two-line Column,
      // and a subtitle set at a size no other seat used. The mark is gone from
      // the persona bars on purpose — the launcher establishes the product and
      // repeating its logo five rows down is branding, not navigation.
      appBar: LumaAppBar(
        title: 'Regulator',
        subtitle: 'Bangladesh Bank · DGDA',
        onBack: onBackToLauncher,
        actions: [
          const ThemeToggle(),
          IconButton(
            tooltip: 'Ledger',
            icon: Icon(Icons.account_tree_outlined, color: c.inkMuted),
            onPressed: () => LedgerInspectorSheet.show(context),
          ),
          IconButton(
            tooltip: 'Demo controls',
            icon: Icon(Icons.tune, color: c.inkMuted),
            onPressed: () => DemoDirectorSheet.show(context),
          ),
        ],
      ),
        // No SafeArea. It would apply the bottom inset as padding and remove
        // it from the MediaQuery underneath — and the scroll views below read
        // that inset themselves, through `lumaScrollPadding`, so it would be
        // counted twice and every list would stop a gesture bar short of the
        // bottom of the screen.
      body: Builder(
        builder: (context) => LumaContainer(
            widthAdjustment: Gap.lg * 2,
            child: ListView(
              padding: lumaScrollPadding(context),
              children: [
                // Observer status. The one thing that distinguishes this seat from
                // every other is that it can read everything and change nothing.
                LampCard(
                  background: c.chainSoft,
                  border: c.chain.withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(Gap.md),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: IconSize.md, color: c.chain),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          'Read-only observer. Endorses nothing.',
                          style: LaMPType.caption.copyWith(color: c.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),

                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Receivables',
                        value: '${views.length}',
                        caption: '$cartonsTraced cartons traced',
                        tone: LampTone.chain,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: _Metric(
                        label: 'Financing',
                        value: LaMPFormatters.formatBDTCompact(financingVolume),
                        caption: '${financed.length} advanced',
                        tone: LampTone.chain,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: _Metric(
                        label: 'Settled',
                        value: '${settlementRate.toStringAsFixed(0)}%',
                        caption: '$settled of ${views.length}',
                        tone: LampTone.verified,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),

                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Duplicate advances',
                        value: '${duplicateAttempts.length}',
                        caption: 'refused',
                        tone: duplicateAttempts.isEmpty
                            ? LampTone.verified
                            : LampTone.dispute,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: _Metric(
                        label: 'Carton rejects',
                        value: '${cartonFailures.length}',
                        caption: 'hash mismatch',
                        tone: cartonFailures.isEmpty
                            ? LampTone.verified
                            : LampTone.pending,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: _Metric(
                        label: 'Policy failures',
                        value: '${policyFailures.length}',
                        caption: 'quorum',
                        tone: policyFailures.isEmpty
                            ? LampTone.verified
                            : LampTone.dispute,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xl),

                LampSectionHeader(
                  title: 'Duplicate financing',
                  caption: 'Advances the chaincode refused',
                  trailing: LampChip(
                    label: duplicateAttempts.isEmpty ? 'Clean' : 'Flagged',
                    tone: duplicateAttempts.isEmpty
                        ? LampTone.verified
                        : LampTone.dispute,
                  ),
                ),
                if (duplicateAttempts.isEmpty)
                  LampCard(
                    child: Text(
                      'None recorded. Finance this receivable from Padma to raise one.',
                      style: LaMPType.caption.copyWith(color: c.inkFaint),
                    ),
                  )
                else
                  for (final att in duplicateAttempts) ...[
                    _RefusalCard(tx: att),
                    const SizedBox(height: Gap.sm),
                  ],

                const SizedBox(height: Gap.xl),

                LampSectionHeader(
                  title: 'Carton traceability',
                  caption: 'Scans matched against dispatch hashes',
                  trailing: LampChip(
                    label: cartonFailures.isEmpty ? 'All matched' : 'Mismatch',
                    tone: cartonFailures.isEmpty
                        ? LampTone.verified
                        : LampTone.pending,
                  ),
                ),
                if (cartonFailures.isEmpty)
                  LampCard(
                    child: Text(
                      'Every scanned carton matched its invoice.',
                      style: LaMPType.caption.copyWith(color: c.inkFaint),
                    ),
                  )
                else
                  for (final cf in cartonFailures) ...[
                    LampCard(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: IconSize.sm, color: c.pending),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cf.message ?? 'Carton hash mismatch',
                                  style: LaMPType.caption.copyWith(color: c.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Block ${cf.blockNumber}',
                                  style: LaMPType.monoCaption
                                      .copyWith(color: c.inkFaint),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                  ],

                const SizedBox(height: Gap.xl),

                // The third metric had a count and no section. A quorum failure is
                // the one refusal a regulator most needs to read, so it now gets
                // the same treatment as the other two.
                LampSectionHeader(
                  title: 'Endorsement policy',
                  caption: 'Transactions that failed to reach quorum',
                  trailing: LampChip(
                    label: policyFailures.isEmpty ? 'Quorum held' : 'Failed',
                    tone: policyFailures.isEmpty
                        ? LampTone.verified
                        : LampTone.dispute,
                  ),
                ),
                if (policyFailures.isEmpty)
                  LampCard(
                    child: Text(
                      'Every transaction on this channel carried the signatures '
                      'its policy requires.',
                      style: LaMPType.caption.copyWith(color: c.inkFaint),
                    ),
                  )
                else
                  for (final pf in policyFailures) ...[
                    _RefusalCard(tx: pf),
                    const SizedBox(height: Gap.sm),
                  ],
              ],
            ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final LampTone tone;

  const _Metric({
    required this.label,
    required this.value,
    required this.caption,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return LampCard(
      padding: const EdgeInsets.all(Gap.md),
      child: LampStat(
        label: label,
        value: value,
        caption: caption,
        valueColor: tone.fg(context),
      ),
    );
  }
}

/// One refused advance, with the block that carries the refusal.
class _RefusalCard extends StatelessWidget {
  final ChainTx tx;

  const _RefusalCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    return LampCard(
      background: c.disputeSoft,
      border: c.dispute.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Submitter and block flex against each other. Side by side and
          // unflexed, this pair was the 207-pixel overflow.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  tx.submitter,
                  style: LaMPType.caption.copyWith(
                    color: c.dispute,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                'Block ${tx.blockNumber}',
                style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            tx.message ?? 'Duplicate advance refused',
            style: LaMPType.caption.copyWith(color: c.ink),
          ),
          const SizedBox(height: Gap.xs),
          // A 64-character hash has no spaces to wrap at, so it is truncated
          // rather than allowed to run off the card.
          Text(
            tx.txId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}
