import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/formatters.dart';
import '../core/constants/palette.dart';
import '../core/constants/typography.dart';
import '../core/design/luma_press.dart';
import '../core/design/luma_toast.dart';
import '../core/design/luma_sheet.dart';
import '../core/state/lamp_state.dart';

/// The controls that drive a demo: move the clock, jump to a seat, start over.
///
/// The content is scrollable. It was a plain Column inside a sheet capped at
/// 85% of the window, and on a 360x800 phone it ran 333 pixels past the bottom
/// — the reset button, the last thing anyone reaches for between takes, was
/// simply not on screen. A sheet whose height is capped has to assume its
/// content will exceed the cap.
class DemoDirectorSheet extends StatelessWidget {
  const DemoDirectorSheet({super.key});

  static void show(BuildContext context) {
    LumaSheet.showOwnShell<void>(
      context: context,
      builder: (_) => const DemoDirectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LaMPState>();
    final c = context.lamp;

    // Grabber, header and height ceiling all come from the shell now. What
    // this sheet had instead: its own 36x4 handle, its own title Row, and its
    // own `0.85 * size.height` cap — which measured the *window* rather than
    // the visible area, so the reset button went under the keyboard the
    // moment anything in here took focus.
    return LumaSheetShell(
      title: 'Demo controls',
      subtitle: LaMPFormatters.formatDateTime(state.now),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.xl),
        children: [
          Text(
            'Move the clock',
            style: LaMPType.caption.copyWith(
              color: c.inkFaint,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _advance(context, state, hours: 24),
                  child: const Text('+24 hours'),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _advance(context, state, days: 30),
                  child: const Text('+30 days'),
                ),
              ),
            ],
          ),

          const SizedBox(height: Gap.xl),
          Text(
            'Jump to a seat',
            style: LaMPType.caption.copyWith(
              color: c.inkFaint,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Gap.sm),

          // The subtitles used to narrate the whole beat — "Execute
          // Meghna financing & reject Padma duplicate attempt" was
          // fifty-six characters. The person reading this wrote the
          // shot list.
          _Scene(n: '1', title: 'Manufacturer', note: 'Mint', persona: PersonaId.manufacturer),
          _Scene(n: '2', title: 'Delivery officer', note: 'Scan', persona: PersonaId.mpo),
          _Scene(n: '3', title: 'Bank', note: 'Finance', persona: PersonaId.bank),
          _Scene(n: '4', title: 'Pharmacy', note: 'Settle', persona: PersonaId.pharmacy),
          _Scene(n: '5', title: 'Regulator', note: 'Audit', persona: PersonaId.regulator),

          const SizedBox(height: Gap.lg),
          Divider(color: c.line, height: 1),
          const SizedBox(height: Gap.sm),

          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: c.dispute),
              onPressed: () async {
                await state.resetWorld();
                if (!context.mounted) return;
                Navigator.pop(context);
                LumaHaptics.confirm();
                LumaToast.show(
                  context,
                  'World reset',
                  icon: Icons.restart_alt,
                );
              },
              icon: const Icon(Icons.refresh, size: IconSize.sm),
              label: const Text('Reset world'),
            ),
          ),
        ],
      ),
    );
  }

  void _advance(BuildContext context, LaMPState state, {int hours = 0, int days = 0}) {
    if (hours > 0) state.advanceHours(hours);
    if (days > 0) state.advanceDays(days);
    Navigator.pop(context);
    LumaHaptics.select();
    LumaToast.show(
      context,
      days > 0 ? 'Clock +${days}d' : 'Clock +${hours}h',
      icon: Icons.schedule,
      tone: LumaToastTone.pending,
    );
  }
}

class _Scene extends StatelessWidget {
  final String n;
  final String title;
  final String note;
  final PersonaId persona;

  const _Scene({
    required this.n,
    required this.title,
    required this.note,
    required this.persona,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<LaMPState>(context, listen: false);
    final c = context.lamp;
    final selected = state.currentPersona == persona;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Material(
        color: selected ? c.brandSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(LaMPRadius.control),
        child: InkWell(
          onTap: () {
            state.setPersona(persona);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(LaMPRadius.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.brand : c.surfaceAlt,
                    borderRadius: BorderRadius.circular(LaMPRadius.control),
                  ),
                  child: Text(
                    n,
                    style: LaMPType.monoCaption.copyWith(
                      color: selected ? c.onBrand : c.inkFaint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    title,
                    style: LaMPType.sub.copyWith(
                      color: selected ? c.brand : c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  note,
                  style: LaMPType.caption.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
