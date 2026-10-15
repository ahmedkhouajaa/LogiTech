import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/crm_activity.dart';
import '../../services/crm_service.dart';

class MobileCrmDashboardScreen extends StatefulWidget {
  const MobileCrmDashboardScreen({super.key});

  @override
  State<MobileCrmDashboardScreen> createState() => _MobileCrmDashboardScreenState();
}

class _MobileCrmDashboardScreenState extends State<MobileCrmDashboardScreen> {
  final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);
  final dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        CrmService.instance.opportunitiesNotifier,
        CrmService.instance.stagesNotifier,
        CrmService.instance.activitiesNotifier,
      ]),
      builder: (context, _) {
        final opps = CrmService.instance.opportunitiesNotifier.value;
        final stages = CrmService.instance.stagesNotifier.value;
        final activities = CrmService.instance.activitiesNotifier.value;

        final totalPipeline = CrmService.instance.getTotalPipelineRevenue();
        final weightedRevenue = CrmService.instance.getWeightedPipelineRevenue();
        final wonRevenue = CrmService.instance.getWonRevenue();
        final winRate = CrmService.instance.getWinRate();
        final todayActs = activities.where((a) => !a.isDone && (a.isToday || a.isOverdue)).toList();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: RefreshIndicator(
            onRefresh: () async {
              // Refresh state
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Welcome Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tableau de bord CRM', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                            child: Text('${opps.length} affaires', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Total Pipeline Actif', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(height: 4),
                      Text(currencyFmt.format(totalPipeline), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Prévisionnel pondéré : ${currencyFmt.format(weightedRevenue)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2 Mini Metric Cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Taux de conversion', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Text('${winRate.toStringAsFixed(1)} %', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            const SizedBox(height: 2),
                            Text(currencyFmt.format(wonRevenue), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Actions à faire', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Text('${todayActs.length}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: todayActs.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
                            const SizedBox(height: 2),
                            const Text('Aujourd\'hui & retards', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),



                // Funnel Breakdown
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Entonnoir par Étape', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                                  Text(st.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                  Text('${currencyFmt.format(sum)} ($count)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: st.color)),
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
                const SizedBox(height: 16),

                // Actions of the day
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Actions Commerciales du Jour', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (todayActs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: Text('Aucune action en attente aujourd\'hui !', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                        )
                      else
                        ...todayActs.map((act) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(act.type.icon, color: act.type.color, size: 20),
                            title: Text(act.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            subtitle: Text(act.customerName ?? 'Contact', style: const TextStyle(fontSize: 11)),
                            trailing: Checkbox(
                              value: act.isDone,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (v) {
                                if (v != null) {
                                  CrmService.instance.toggleActivityDone(act.id, v);
                                }
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
