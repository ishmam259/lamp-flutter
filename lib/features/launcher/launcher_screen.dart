import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/design/luma_auto_grid.dart';
import '../../core/design/luma_container.dart';
import '../../core/design/luma_frost.dart';
import '../../core/state/lamp_state.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lamp_mark.dart';
import '../../widgets/theme_toggle.dart';
import '../../widgets/ui/lamp_ui.dart';

/// Pick a seat.
///
/// This screen used to open with a headline and a line of positioning copy —
/// "Five interfaces over one consortium ledger", "Make the invoice itself
/// trustworthy, so the money can follow the medicine" — and then describe each
/// seat in a sentence of about eighty characters. That is a pitch deck. Someone
/// opening the app already knows what it is; what they need is the state of the
/// ledger and a way in. The pitch is gone and the descriptions with it: a seat
/// is named by its role and its organisation, which is what a person actually
/// scans for.
///
/// The layout is where this branch shows most plainly. The seats used to be a
/// fixed single column, which is right on a phone and absurd on a tablet,
/// where five cards each 900dp wide read as five grey bars. They are now laid
/// out the way Luma lays out an attendee list — `auto-fit` over a minimum
/// column width — so the count comes from the room available rather than from
/// a breakpoint someone guessed at.
class LauncherScreen extends StatelessWidget {
  final ValueChanged<PersonaId> onSelectPersona;

  const LauncherScreen({super.key, required this.onSelectPersona});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    return Scaffold(
      // The body runs underneath the bar, which is the whole premise of a
      // frosted one: there has to be something behind the glass.
      extendBodyBehindAppBar: true,
      appBar: LumaAppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: Gap.lg, right: Gap.sm),
          child: Center(child: LampMark(size: 28)),
        ),
        title: 'LaMP',
        subtitle: 'Last Mile Pharmacy',
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
      // No SafeArea: the list reads both insets itself, through
      // `lumaScrollPadding`. A SafeArea would apply the bottom one as padding
      // *and* remove it from the MediaQuery underneath, so it would be
      // counted twice and the list would stop a gesture bar short.
      body: Builder(
        // Under the Scaffold's body, where `MediaQuery.padding.top` has the
        // app bar's height folded into it. Read from the outer context it
        // would be the status bar alone, and the first card would sit behind
        // the glass rather than under it.
        builder: (context) => LumaContainer(
            // The query root is the content column, not the viewport: the
            // cards live inside 16dp of padding on each side and should
            // measure the width they will actually be handed.
            widthAdjustment: Gap.lg * 2,
            child: ListView(
              padding: lumaScrollPadding(context),
              children: [
                _LedgerStrip(state: context.watch<LaMPState>()),
                const SizedBox(height: Gap.xl),

                const LampSectionHeader(
                  title: 'In the field',
                  caption: 'Phone apps, built for sunlight',
                ),
                LumaAutoGrid(
                  minColumnWidth: 240,
                  gap: Gap.md,
                  children: [
                    _SeatCard(
                      icon: Icons.qr_code_scanner,
                      title: 'Delivery officer',
                      org: 'Kamrul Hasan · Bogura Sadar',
                      tone: LampTone.brand,
                      onTap: () => onSelectPersona(PersonaId.mpo),
                    ),
                    _SeatCard(
                      icon: Icons.local_pharmacy_outlined,
                      title: 'Pharmacy',
                      org: 'Rahman Medical Hall · রহমান মেডিকেল হল',
                      tone: LampTone.verified,
                      onTap: () => onSelectPersona(PersonaId.pharmacy),
                    ),
                  ],
                ),

                const SizedBox(height: Gap.xl),
                const LampSectionHeader(
                  title: 'At the desk',
                  caption: 'Institutional portals on one channel',
                ),
                LumaAutoGrid(
                  minColumnWidth: 240,
                  gap: Gap.md,
                  children: [
                    _SeatCard(
                      icon: Icons.business_outlined,
                      title: 'Manufacturer',
                      org: 'Shomota Pharmaceuticals',
                      tone: LampTone.brand,
                      onTap: () => onSelectPersona(PersonaId.manufacturer),
                    ),
                    _SeatCard(
                      icon: Icons.account_balance_outlined,
                      title: 'Bank',
                      org: 'Meghna Commercial · Padma',
                      tone: LampTone.pending,
                      onTap: () => onSelectPersona(PersonaId.bank),
                    ),
                    _SeatCard(
                      icon: Icons.verified_user_outlined,
                      title: 'Regulator',
                      org: 'Bangladesh Bank · DGDA',
                      tone: LampTone.chain,
                      onTap: () => onSelectPersona(PersonaId.regulator),
                    ),
                  ],
                ),
              ],
          ),
        ),
      ),
    );
  }
}

/// The ledger, in three figures.
///
/// What replaced the headline. A person opening the app wants to know the chain
/// is alive and which invoice the demo is on; both fit here, and neither needs
/// a sentence.
class _LedgerStrip extends StatelessWidget {
  final LaMPState state;

  const _LedgerStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;

    return LampCard(
      raised: true,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LiveDot(color: c.verified),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Consortium ledger · lamp-channel',
                  style: LaMPType.monoCaption.copyWith(color: c.inkFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Short labels and a wider share for the invoice id, which is
              // the longest value of the three. "Open invoices" did not fit its
              // column and ran into the label beside it.
              Expanded(
                flex: 2,
                child: LampStat(
                  label: 'Block',
                  value: '${state.blockHeight}',
                  valueColor: c.verified,
                ),
              ),
              Expanded(
                flex: 2,
                child: LampStat(label: 'Invoices', value: '1'),
              ),
              Expanded(
                flex: 4,
                child: LampStat(
                  label: 'Demo invoice',
                  value: state.demoInvoiceId,
                  valueColor: c.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The status dot, with the halo a live thing earns.
///
/// A flat 8dp circle says "green". A dot with a soft ring the same colour at
/// low alpha says "transmitting", and it costs one extra box — the same
/// technique as a CSS `box-shadow: 0 0 0 4px rgba(...)` ring, which is how
/// every status indicator worth looking at is built.
class _LiveDot extends StatelessWidget {
  final Color color;

  const _LiveDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 0,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// One seat. Role, organisation, and a way in — nothing else.
///
/// The container query is here, and it is worth being precise about what it
/// keys on. Not the screen: a phone gives this card about 328dp and a two-up
/// grid on a small tablet gives it about 288, so screen width would put the
/// *smaller* box on the *larger* device. It keys on the card's own measured
/// width, with a threshold this component picked for itself — below 300dp the
/// icon, two lines of text and a chevron stop fitting on one line without the
/// organisation truncating, so the card becomes a tile instead: glyph on its
/// own row, text underneath, full width for the name.
///
/// That is `@container (min-width: 300px)`, and the reason it is written
/// per-component rather than against a shared breakpoint is that 300 is a
/// fact about *this* card's contents and means nothing to any other.
class _SeatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String org;
  final LampTone tone;
  final VoidCallback onTap;

  const _SeatCard({
    required this.icon,
    required this.title,
    required this.org,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Its own box, measured. Nested inside the screen's container, so on a
    // phone this reports ~328 and in a three-up grid it reports ~290.
    return LumaContainer(
      child: Builder(
        builder: (context) {
          final stacked = context.lumaContainerWidth < 300;
          return LampCard(
            onTap: onTap,
            padding: const EdgeInsets.all(Gap.md),
            child: stacked ? _tile(context) : _row(context),
          );
        },
      ),
    );
  }

  Widget _glyph(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: tone.bg(context),
          borderRadius: BorderRadius.circular(LaMPRadius.card),
        ),
        child: Icon(icon, size: IconSize.lg, color: tone.fg(context)),
      );

  Widget _title(BuildContext context) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: LaMPType.sub.copyWith(color: c.ink, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          org,
          style: LaMPType.caption.copyWith(color: c.inkFaint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _row(BuildContext context) => Row(
        children: [
          _glyph(context),
          const SizedBox(width: Gap.md),
          Expanded(child: _title(context)),
          const SizedBox(width: Gap.sm),
          Icon(Icons.chevron_right, size: IconSize.md, color: context.lamp.inkFaint),
        ],
      );

  Widget _tile(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _glyph(context),
              const Spacer(),
              Icon(Icons.north_east, size: IconSize.sm, color: context.lamp.inkFaint),
            ],
          ),
          const SizedBox(height: Gap.md),
          _title(context),
        ],
      );
}
