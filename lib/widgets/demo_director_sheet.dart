import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/colors.dart';
import '../core/constants/formatters.dart';
import '../core/state/lamp_state.dart';

class DemoDirectorSheet extends StatelessWidget {
  const DemoDirectorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DemoDirectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LaMPState>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131B17),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: LaMPColors.portalLine2, width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.movie_filter_outlined, color: LaMPColors.brand, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Demo Director',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LaMPColors.portalInk,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 13, color: LaMPColors.brand),
                    const SizedBox(width: 6),
                    Text(
                      LaMPFormatters.formatDateTime(state.now),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: LaMPColors.portalInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: LaMPColors.portalLine),
          const SizedBox(height: 12),

          // Clock Jumps
          const Text(
            'FAST-FORWARD CLOCK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: LaMPColors.portalInk3,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final btn1 = OutlinedButton.icon(
                onPressed: () {
                  state.advanceHours(24);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Clock advanced +24h (Dispute window closed)')),
                  );
                },
                icon: const Icon(Icons.fast_forward, size: 16, color: LaMPColors.brand),
                label: const Text('+24 Hours (Close Window)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LaMPColors.portalInk,
                  side: const BorderSide(color: LaMPColors.portalLine2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
              final btn2 = OutlinedButton.icon(
                onPressed: () {
                  state.advanceDays(30);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Clock advanced +30d (Payment due)')),
                  );
                },
                icon: const Icon(Icons.fast_forward, size: 16, color: LaMPColors.pending),
                label: const Text('+30 Days (Settle Due)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LaMPColors.portalInk,
                  side: const BorderSide(color: LaMPColors.portalLine2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );

              if (constraints.maxWidth < 460) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: btn1),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: btn2),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: btn1),
                  const SizedBox(width: 10),
                  Expanded(child: btn2),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          const Text(
            'JUMP TO SCENE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: LaMPColors.portalInk3,
            ),
          ),
          const SizedBox(height: 8),

          _buildSceneTile(
            context,
            sceneNum: '01',
            title: 'Manufacturer Portal',
            subtitle: 'Mint receivable INV-00235 (25 cartons)',
            persona: PersonaId.manufacturer,
          ),
          _buildSceneTile(
            context,
            sceneNum: '02',
            title: 'MPO Mobile App',
            subtitle: 'Scan consignment & reject mismatched carton 14',
            persona: PersonaId.mpo,
          ),
          _buildSceneTile(
            context,
            sceneNum: '03',
            title: 'Bank SCF Portal',
            subtitle: 'Execute Meghna financing & reject Padma duplicate attempt',
            persona: PersonaId.bank,
          ),
          _buildSceneTile(
            context,
            sceneNum: '04',
            title: 'Pharmacy Owner App',
            subtitle: 'View credit ring & settle via bKash to upgrade tier',
            persona: PersonaId.pharmacy,
          ),
          _buildSceneTile(
            context,
            sceneNum: '05',
            title: 'Regulator Compliance View',
            subtitle: 'Inspect duplicate advance attempt audit trail',
            persona: PersonaId.regulator,
          ),

          const SizedBox(height: 16),
          const Divider(color: LaMPColors.portalLine),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                await state.resetWorld();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('World reset deterministically to seed state')),
                  );
                }
              },
              icon: const Icon(Icons.refresh, color: LaMPColors.dispute, size: 18),
              label: const Text(
                'Reset the World (Rebuild all blocks from seed)',
                style: TextStyle(color: LaMPColors.dispute, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneTile(
    BuildContext context, {
    required String sceneNum,
    required String title,
    required String subtitle,
    required PersonaId persona,
  }) {
    final state = Provider.of<LaMPState>(context, listen: false);
    final isSelected = state.currentPersona == persona;

    return InkWell(
      onTap: () {
        state.setPersona(persona);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? LaMPColors.brand.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? LaMPColors.brand : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? LaMPColors.brand : LaMPColors.portalSurface2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sceneNum,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: isSelected ? Colors.white : LaMPColors.portalInk3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? LaMPColors.brand : LaMPColors.portalInk,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: LaMPColors.portalInk3),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: isSelected ? LaMPColors.brand : LaMPColors.portalInk3,
            ),
          ],
        ),
      ),
    );
  }
}
