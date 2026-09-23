import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/ledger_labels.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/formatters.dart';
import '../../core/models/domain_models.dart';
import '../../core/design/luma_frost.dart';
import '../../core/constants/typography.dart';
import '../../core/models/ledger_models.dart';
import '../../core/state/lamp_state.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/ui/lamp_ledger_ui.dart';
import '../../widgets/ui/lamp_ui.dart';

/// The supervisory seat: sees every record on the ledger, changes none.
///
/// Three questions, in the order a supervisor asks them: did anything get
/// through that shouldn't have (the checks), what exactly was stopped (the
/// open flags, one card each), and does what was delivered match what was
/// shipped (every carton scan, in order, as ticks).
class RegulatorScreen extends StatelessWidget {
  const RegulatorScreen({super.key});

  /// Scans shown on the traceability strip. Beyond this the ticks get too
  /// thin to read, and the most recent ones are the ones that matter.
  static const int _traceWindow = 40;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: LaMPTheme.of(context, LampWorld.portal),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final state = context.watch<LaMPState>();
    final txs = state.txs;

    final duplicates = txs
        .where((t) =>
            t.fn == 'matchAndAdvance' &&
            t.status == TxStatus.chaincodeError &&
            (t.message?.contains('already financed') ?? false))
        .toList();
    final wrongCartons = txs
        .where((t) =>
            (t.fn == 'recordPoD' || t.fn == 'recordPoDBatch') &&
            t.status == TxStatus.chaincodeError &&
            (t.message?.contains('does not belong') ?? false))
        .toList();
    final unapproved =
        txs.where((t) => t.status == TxStatus.endorsementPolicyFailure).toList();
    final flags = [...duplicates, ...wrongCartons, ...unapproved]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final views = state.tokenViews;
    final advanced = views.fold<double>(
      0,
      (s, v) => s + (v.token.financing?.advancedAmount ?? 0),
    );
    final paid = views.where((v) => v.token.state == TokenState.settled).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LumaAppBar(
        title: 'Regulator',
        subtitle: 'Bangladesh Bank · DGDA',
        actions: [
          LampBlockPip(onTap: () => LedgerInspectorSheet.show(context)),
          const LampSeatMenu(),
        ],
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: lumaScrollPadding(context, top: Gap.lg),
          children: [
            _viewOnly(context),
            const SizedBox(height: Gap.lg),
            _overview(context, views.length, advanced, paid),
            const SizedBox(height: Gap.xl),
            const LampEyebrow('Checks'),
            const SizedBox(height: Gap.md),
            _checks(context, [
              (duplicates.length, 'Duplicate financing blocked', 'one invoice, one financier'),
              (wrongCartons.length, 'Wrong cartons scanned', "didn't match what was shipped"),
              (unapproved.length, 'Missing approvals', 'records without every sign-off'),
            ]),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: Gap.xl),
              LampEyebrow(
                flags.length == 1 ? 'Open flag' : 'Open flags',
                trailing: '${flags.length}',
              ),
              const SizedBox(height: Gap.md),
              for (final t in flags) ...[
                _flagCard(context, state, t),
                const SizedBox(height: Gap.md),
              ],
            ],
            const SizedBox(height: Gap.xl),
            const LampEyebrow('Traceability'),
            const SizedBox(height: Gap.md),
            _traceability(context, state),
          ],
        ),
      ),
    );
  }

  Widget _viewOnly(BuildContext context) {
    final c = context.lamp;
    return Row(
      children: [
        Icon(Icons.visibility_outlined, size: IconSize.md, color: c.inkFaint),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(
            "View only. You can see every record on the ledger but can't "
            'approve or change any.',
            style: LaMPType.caption.copyWith(color: c.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _overview(BuildContext context, int invoices, double advanced, int paid) {
    final c = context.lamp;
    Widget figure(String label, String value, {bool end = false}) => Column(
          crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            LampEyebrow(label),
            const SizedBox(height: Gap.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: LaMPType.figure.copyWith(color: c.ink)),
            ),
          ],
        );
    return LampCard(
      child: Row(
        children: [
          Expanded(child: figure('Invoices', '$invoices')),
          Expanded(flex: 2, child: figure('Financed', LaMPFormatters.formatBDTCompact(advanced))),
          Expanded(child: figure('Paid', '$paid', end: true)),
        ],
      ),
    );
  }

  /// One row per check: the count, what it means, and clean or flagged.
  Widget _checks(BuildContext context, List<(int, String, String)> rows) {
    final c = context.lamp;
    return LampCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${rows[i].$1}',
                      style: LaMPType.figure.copyWith(
                        color: rows[i].$1 == 0 ? c.verified : c.dispute,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$2, style: LaMPType.sub.copyWith(color: c.ink)),
                        Text(rows[i].$3, style: LaMPType.caption.copyWith(color: c.inkFaint)),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  rows[i].$1 == 0
                      ? const LampStateChip(LampState.confirmed, 'Clean')
                      : LampStateChip(
                          LampState.refused,
                          rows[i].$1 == 1 ? '1 flag' : '${rows[i].$1} flags',
                        ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One refused record: what was tried, where, when, and that the ledger
  /// kept it off the books.
  Widget _flagCard(BuildContext context, LaMPState state, ChainTx tx) {
    final c = context.lamp;
    final tokenId = tx.args['tokenId'];
    final view = tokenId is String ? state.viewFor(tokenId) : null;
    final invoice = view?.token.invoiceId;
    final pharmacy = view?.pharmacy?.name;

    final what = switch (tx.fn) {
      'recordPoD' || 'recordPoDBatch' => 'Wrong carton scanned',
      'matchAndAdvance' => 'Second financing attempt',
      _ => LedgerLabels.event(tx.fn),
    };

    return LampCard(
      border: c.dispute,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice == null ? what : '$what · $invoice',
                  style: LaMPType.sub.copyWith(color: c.ink),
                ),
              ),
              Text(
                '${LaMPFormatters.formatDateShort(tx.timestamp)}, '
                '${LaMPFormatters.formatClock(tx.timestamp)}',
                style: LaMPType.caption.copyWith(color: c.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            [
              LedgerLabels.reason(tx.message),
              if (pharmacy != null) 'At $pharmacy.',
              'Submitted by ${LedgerLabels.org(tx.submitter)}.',
            ].join(' '),
            style: LaMPType.caption.copyWith(color: c.inkMuted),
          ),
          Divider(height: Gap.xl, thickness: 1, color: c.line),
          Row(
            children: [
              const LampStateDot(LampState.refused),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Not recorded — the ledger refused it',
                  style: LaMPType.caption.copyWith(color: c.inkFaint),
                ),
              ),
              InkWell(
                onTap: () => LedgerInspectorSheet.show(context),
                borderRadius: BorderRadius.circular(LaMPRadius.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                  child: Text('Details ›', style: LaMPType.meta.copyWith(color: c.inkMuted)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Every carton scan the ledger saw, in order: accepted green, refused red
  /// in its own position.
  Widget _traceability(BuildContext context, LaMPState state) {
    final c = context.lamp;
    final scans = state.txs
        .where((t) => t.fn == 'recordPoD' || t.fn == 'recordPoDBatch')
        .toList();
    final accepted = scans.where((t) => t.status == TxStatus.valid).length;
    final refused = scans.length - accepted;
    final consignments = scans.map((t) => t.args['tokenId']).toSet().length;
    final shown = scans.length > _traceWindow
        ? scans.sublist(scans.length - _traceWindow)
        : scans;

    if (scans.isEmpty) {
      return const LampEmpty(
        icon: Icons.qr_code_2,
        title: 'No carton scans yet',
        message: 'Each carton scanned at a pharmacy appears here.',
      );
    }

    return LampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Scans matched to what was shipped',
                    style: LaMPType.sub.copyWith(color: c.ink)),
              ),
              Text(
                '$accepted/${scans.length}',
                style: LaMPType.monoBody.copyWith(
                  color: refused == 0 ? c.verified : c.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          LampTickBar.of([
            for (final t in shown)
              t.status == TxStatus.valid ? LampState.confirmed : LampState.refused,
          ]),
          const SizedBox(height: Gap.sm),
          Text(
            [
              'Across $consignments ${consignments == 1 ? 'consignment' : 'consignments'}',
              if (refused > 0) '$refused refused',
              if (scans.length > _traceWindow) 'last $_traceWindow shown',
            ].join(' · '),
            style: LaMPType.caption.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}
