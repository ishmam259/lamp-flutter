import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/formatters.dart';
import '../../core/state/lamp_state.dart';
import '../../widgets/demo_director_sheet.dart';
import '../../widgets/ledger_inspector_sheet.dart';
import '../../widgets/lamp_mark.dart';

class LauncherScreen extends StatelessWidget {
  final ValueChanged<PersonaId> onSelectPersona;

  const LauncherScreen({super.key, required this.onSelectPersona});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LaMPState>();

    return Scaffold(
      backgroundColor: LaMPColors.portalGround,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            LampMark(size: 34),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LaMP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: LaMPColors.portalInk,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Last Mile Pharmacy',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: LaMPColors.portalInk3,
                  ),
                ),
              ],
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
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        LaMPColors.brand.withValues(alpha: 0.25),
                        const Color(0xFF131B17),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LaMPColors.portalLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: LaMPColors.verified.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BCOLBD 2026 PROTOTYPE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: LaMPColors.verified,
                              ),
                            ),
                          ),
                          Text(
                            LaMPFormatters.formatDateTime(state.now),
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: LaMPColors.portalInk2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Five interfaces over one consortium ledger.',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: LaMPColors.portalInk,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Make the invoice itself trustworthy, so the money can follow the medicine.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: LaMPColors.portalInk2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: LaMPColors.portalLine),
                            ),
                            child: const LampMark(size: 56),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          _buildMiniStat('Block Height', '${state.blockHeight}', LaMPColors.verified),
                          _buildMiniStat('Active Invoices', '${state.invoices.length}', LaMPColors.portalInk),
                          _buildMiniStat(
                            'Demo Invoice',
                            state.demoInvoiceId,
                            LaMPColors.brand,
                            mono: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Section 1: Field Applications
                const Row(
                  children: [
                    Icon(Icons.smartphone, size: 16, color: LaMPColors.brand),
                    SizedBox(width: 8),
                    Text(
                      'Field Applications (Light Mode)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: LaMPColors.portalInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 640;
                    final mpoCard = _buildPersonaCard(
                      context,
                      persona: PersonaId.mpo,
                      title: 'MPO Mobile App',
                      subtitle: 'Kamrul Hasan · Bogura Sadar',
                      description: 'GS1 carton scanner with cascade, rejection of misrouted carton 14, and offline sync.',
                      badge: 'Delivery Proof',
                      badgeColor: LaMPColors.brand,
                      icon: Icons.qr_code_scanner,
                    );
                    final pharmacyCard = _buildPersonaCard(
                      context,
                      persona: PersonaId.pharmacy,
                      title: 'Pharmacy Owner App',
                      subtitle: 'Rahman Medical Hall (রহমান মেডিকেল হল)',
                      description: 'Credit cycle ring, bKash payment, and tier upgrade from Building to Established.',
                      badge: 'Credit Building',
                      badgeColor: LaMPColors.verified,
                      icon: Icons.local_pharmacy_outlined,
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          mpoCard,
                          const SizedBox(height: 12),
                          pharmacyCard,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: mpoCard),
                        const SizedBox(width: 14),
                        Expanded(child: pharmacyCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Section 2: Institutional Portals
                const Row(
                  children: [
                    Icon(Icons.laptop, size: 16, color: LaMPColors.portalInk2),
                    SizedBox(width: 8),
                    Text(
                      'Institutional Portals (Dark Mode)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: LaMPColors.portalInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 640;
                    final mfrCard = _buildPersonaCard(
                      context,
                      persona: PersonaId.manufacturer,
                      title: 'Manufacturer Portal',
                      subtitle: 'Shomota Pharmaceuticals Ltd',
                      description: 'Mint receivables with multi-MSP quorum, track carton scans, and monitor collections.',
                      badge: 'Receivables',
                      badgeColor: LaMPColors.brand,
                      icon: Icons.business_outlined,
                    );
                    final bankCard = _buildPersonaCard(
                      context,
                      persona: PersonaId.bank,
                      title: 'Bank SCF Portal',
                      subtitle: 'Meghna Commercial & Padma Bank',
                      description: 'Smart contract financing, rate curve bands, and duplicate financing rejection.',
                      badge: 'Financing',
                      badgeColor: LaMPColors.pending,
                      icon: Icons.account_balance_outlined,
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          mfrCard,
                          const SizedBox(height: 12),
                          bankCard,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: mfrCard),
                        const SizedBox(width: 14),
                        Expanded(child: bankCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _buildPersonaCard(
                  context,
                  persona: PersonaId.regulator,
                  title: 'Regulator Dashboard',
                  subtitle: 'Bangladesh Bank / DGDA — Observer Node',
                  description: 'Independent oversight, duplicate advance audit log, and medicine supply chain traceability.',
                  badge: 'Compliance & Audit',
                  badgeColor: LaMPColors.dispute,
                  icon: Icons.security_outlined,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, {bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: LaMPColors.portalInk3)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: mono ? 'monospace' : null,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonaCard(
    BuildContext context, {
    required PersonaId persona,
    required String title,
    required String subtitle,
    required String description,
    required String badge,
    required Color badgeColor,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () => onSelectPersona(persona),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131B17),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LaMPColors.portalLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: badgeColor, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: LaMPColors.portalInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: LaMPColors.portalInk3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: LaMPColors.portalInk2,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Launch Seat →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
