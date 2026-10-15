import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/crm_service.dart';

class MobileCrmReportsScreen extends StatelessWidget {
  const MobileCrmReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);

    return ListenableBuilder(
      listenable: Listenable.merge([
        CrmService.instance.opportunitiesNotifier,
        CrmService.instance.stagesNotifier,
      ]),
      builder: (context, _) {
        final opps = CrmService.instance.opportunitiesNotifier.value;
        final stages = CrmService.instance.stagesNotifier.value;

        final wonOpps = opps.where((o) => o.isWon).toList();
        final lostOpps = opps.where((o) => o.isLost).toList();
        final totalWon = wonOpps.fold(0.0, (acc, o) => acc + o.expectedRevenue);
        final winRate = CrmService.instance.getWinRate();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text('CA Gagné : ${currencyFmt.format(totalWon)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    const SizedBox(height: 6),
                    Text('Taux de conversion : ${winRate.toStringAsFixed(1)} %', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                    const SizedBox(height: 4),
                    Text('${wonOpps.length} gagnée(s) • ${lostOpps.length} perdue(s) • ${opps.length} au total', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stages breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Entonnoir de Conversion', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...stages.map((st) {
                      final count = opps.where((o) => o.stageId == st.id).length;
                      final sum = opps.where((o) => o.stageId == st.id).fold(0.0, (acc, o) => acc + o.expectedRevenue);
                      final pct = opps.isEmpty ? 0.0 : count / opps.length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(st.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('${currencyFmt.format(sum)} ($count)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: st.color)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(st.color),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
