import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/crm_opportunity.dart';
import '../models/crm_activity.dart';
import '../services/crm_service.dart';
import '../l10n/app_localizations.dart';

class CrmDashboardScreen extends StatefulWidget {
  const CrmDashboardScreen({super.key});

  @override
  State<CrmDashboardScreen> createState() => _CrmDashboardScreenState();
}

class _CrmDashboardScreenState extends State<CrmDashboardScreen> {
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
        CrmService.instance.isLoadingNotifier,
      ]),
      builder: (context, _) {
        final opps = CrmService.instance.opportunitiesNotifier.value;
        final stages = CrmService.instance.stagesNotifier.value;
        final activities = CrmService.instance.activitiesNotifier.value;

        // KPI Computations
        final totalPipeline = CrmService.instance.getTotalPipelineRevenue();
        final weightedRevenue = CrmService.instance.getWeightedPipelineRevenue();
        final wonRevenue = CrmService.instance.getWonRevenue();
        final winRate = CrmService.instance.getWinRate();
        final pendingActivities = CrmService.instance.getPendingActivitiesCount();
        final overdueActivities = CrmService.instance.getOverdueActivitiesCount();

        final todayActivities = activities.where((a) => !a.isDone && a.isToday).toList();
        final overdueList = activities.where((a) => !a.isDone && a.isOverdue).toList();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar
                _buildHeader(context, isDark, opps.length),
                const SizedBox(height: 20),

                // 4 Main KPI Cards
                _buildKpiGrid(
                  isDark: isDark,
                  totalPipeline: totalPipeline,
                  weightedRevenue: weightedRevenue,
                  wonRevenue: wonRevenue,
                  winRate: winRate,
                  pendingActivities: pendingActivities,
                  overdueActivities: overdueActivities,
                ),
                const SizedBox(height: 24),

                // Main Dashboard Body: Pipeline Funnel & Today's Commercial Agenda
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 950;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _buildFunnelCard(isDark, opps, stages),
                                const SizedBox(height: 20),
                                _buildRecentDealsCard(isDark, opps),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                _buildTodayActivitiesCard(isDark, todayActivities, overdueList),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile / Narrow Stack
                    return Column(
                      children: [
                        _buildFunnelCard(isDark, opps, stages),
                        const SizedBox(height: 20),
                        _buildTodayActivitiesCard(isDark, todayActivities, overdueList),
                        const SizedBox(height: 20),
                        _buildRecentDealsCard(isDark, opps),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, int totalDeals) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Tableau de bord CRM'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Vue d\'ensemble de votre activité commerciale et suivi du pipeline ($totalDeals affaires)',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiGrid({
    required bool isDark,
    required double totalPipeline,
    required double weightedRevenue,
    required double wonRevenue,
    required double winRate,
    required int pendingActivities,
    required int overdueActivities,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = constraints.maxWidth > 800 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                title: 'CA Pipeline Actif',
                value: currencyFmt.format(totalPipeline),
                subtitle: 'Total des affaires en cours',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                title: 'CA Prévisionnel Pondéré',
                value: currencyFmt.format(weightedRevenue),
                subtitle: 'Pondéré par probabilité',
                icon: Icons.insights_rounded,
                iconColor: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF5F3FF),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                title: 'Taux de Conversion',
                value: '${winRate.toStringAsFixed(1)} %',
                subtitle: 'CA signé : ${currencyFmt.format(wonRevenue)}',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFD1FAE5),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                title: 'Actions Commerciales',
                value: '$pendingActivities',
                subtitle: overdueActivities > 0 ? '$overdueActivities en retard !' : 'À jour',
                subtitleColor: overdueActivities > 0 ? const Color(0xFFEF4444) : null,
                icon: Icons.calendar_today_rounded,
                iconColor: overdueActivities > 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                bgColor: overdueActivities > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    Color? subtitleColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtitleColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
        ],
      ),
    );
  }

  Widget _buildFunnelCard(bool isDark, List<CrmOpportunity> opps, List<CrmStage> stages) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text('Entonnoir du Pipeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          if (stages.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Aucune étape configurée.')))
          else
            ...stages.map((stage) {
              final stageOpps = opps.where((o) => o.stageId == stage.id).toList();
              final count = stageOpps.length;
              final sum = stageOpps.fold(0.0, (acc, o) => acc + o.expectedRevenue);
              final pct = opps.isEmpty ? 0.0 : (count / opps.length).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: stage.color, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(stage.name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                            const SizedBox(width: 6),
                            Text('($count)', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ],
                        ),
                        Text(currencyFmt.format(sum), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: stage.color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 7,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(stage.color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentDealsCard(bool isDark, List<CrmOpportunity> opps) {
    final recent = opps.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Text('Dernières Affaires Actives', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Aucune opportunité pour le moment.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ),
            )
          else
            ...recent.map((opp) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      child: Text(
                        opp.customerName.isNotEmpty ? opp.customerName[0].toUpperCase() : 'O',
                        style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opp.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('${opp.customerName} • ${opp.stageName}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(currencyFmt.format(opp.expectedRevenue), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        Text('${opp.probability}% proba.', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTodayActivitiesCard(bool isDark, List<CrmActivity> today, List<CrmActivity> overdue) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.checklist_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text('Actions du Jour', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                ],
              ),
              if (overdue.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                  child: Text('${overdue.length} retard', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (today.isEmpty && overdue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 36),
                    const SizedBox(height: 8),
                    Text('Toutes vos actions sont terminées !', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          else ...[
            ...overdue.map((act) => _buildActivityItem(act, isDark, isOverdue: true)),
            ...today.map((act) => _buildActivityItem(act, isDark, isOverdue: false)),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(CrmActivity act, bool isDark, {required bool isOverdue}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFEF2F2) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isOverdue ? const Color(0xFFFCA5A5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Checkbox(
            value: act.isDone,
            activeColor: const Color(0xFF10B981),
            onChanged: (val) {
              if (val != null) {
                CrmService.instance.toggleActivityDone(act.id, val);
              }
            },
          ),
          Icon(act.type.icon, size: 16, color: isOverdue ? const Color(0xFFEF4444) : act.type.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    decoration: act.isDone ? TextDecoration.lineThrough : null,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${act.customerName ?? 'Contact'} • ${dateFmt.format(act.dueDate)}',
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
