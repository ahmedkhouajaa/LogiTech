import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/production_order.dart';
import '../services/production_service.dart';
import '../l10n/app_localizations.dart';

class ProductionDashboardScreen extends StatefulWidget {
  const ProductionDashboardScreen({super.key});

  @override
  State<ProductionDashboardScreen> createState() =>
      _ProductionDashboardScreenState();
}

class _ProductionDashboardScreenState extends State<ProductionDashboardScreen> {
  final currencyFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);
  final dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        ProductionService.instance.ordersNotifier,
        ProductionService.instance.bomsNotifier,
        ProductionService.instance.workcentersNotifier,
      ]),
      builder: (context, _) {
        final orders = ProductionService.instance.ordersNotifier.value;
        final activeCount = ProductionService.instance.getActiveOrdersCount();
        final delayedCount = ProductionService.instance.getDelayedOrdersCount();
        final monthlyQty =
            ProductionService.instance.getMonthlyProducedUnits();
        final monthlyCost =
            ProductionService.instance.getMonthlyProductionCost();
        final oee = ProductionService.instance.getGlobalOeeRate();
        final scrapRate = ProductionService.instance.getGlobalScrapRate();

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Tableau de bord Production (GPAO)'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                              'Pilotage des ordres de fabrication, rendements et capacités ateliers'),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4 Main KPI Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: isNarrow
                              ? (constraints.maxWidth - 16) / 2
                              : (constraints.maxWidth - 48) / 4,
                          child: _buildKpiCard(
                            title: 'OF En cours & Actifs',
                            value: '$activeCount',
                            subtitle: '$delayedCount en retard',
                            subtitleColor: delayedCount > 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            icon: Icons.precision_manufacturing_rounded,
                            iconColor: const Color(0xFF2563EB),
                            iconBg: const Color(0xFFEFF6FF),
                          ),
                        ),
                        SizedBox(
                          width: isNarrow
                              ? (constraints.maxWidth - 16) / 2
                              : (constraints.maxWidth - 48) / 4,
                          child: _buildKpiCard(
                            title: 'Unités Fabriquées (Mois)',
                            value: NumberFormat.compact().format(monthlyQty),
                            subtitle: 'Taux de rebut : ${scrapRate.toStringAsFixed(1)} %',
                            subtitleColor: const Color(0xFF64748B),
                            icon: Icons.check_box_rounded,
                            iconColor: const Color(0xFF10B981),
                            iconBg: const Color(0xFFECFDF5),
                          ),
                        ),
                        SizedBox(
                          width: isNarrow
                              ? (constraints.maxWidth - 16) / 2
                              : (constraints.maxWidth - 48) / 4,
                          child: _buildKpiCard(
                            title: 'Coût Production (Mois)',
                            value: currencyFmt.format(monthlyCost),
                            subtitle: 'Matières & Main d\'œuvre',
                            subtitleColor: const Color(0xFF64748B),
                            icon: Icons.price_check_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            iconBg: const Color(0xFFF5F3FF),
                          ),
                        ),
                        SizedBox(
                          width: isNarrow
                              ? (constraints.maxWidth - 16) / 2
                              : (constraints.maxWidth - 48) / 4,
                          child: _buildKpiCard(
                            title: 'Taux de Rendement OEE',
                            value: '${oee.toStringAsFixed(1)} %',
                            subtitle: oee >= 85 ? 'Excellente efficacité' : 'Objectif cible: 85%',
                            subtitleColor: oee >= 85
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            icon: Icons.speed_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            iconBg: const Color(0xFFFFFBEB),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Middle section: Status breakdown
                _buildStatusBreakdown(orders, isDark),
                const SizedBox(height: 24),

                // Recent / Priority Orders Table
                _buildPriorityOrdersSection(orders, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color subtitleColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildStatusBreakdown(List<ProductionOrder> orders, bool isDark) {
    final total = orders.isEmpty ? 1 : orders.length;
    final counts = {
      ProductionOrderStatus.draft:
          orders.where((o) => o.status == ProductionOrderStatus.draft).length,
      ProductionOrderStatus.confirmed:
          orders.where((o) => o.status == ProductionOrderStatus.confirmed).length,
      ProductionOrderStatus.planned:
          orders.where((o) => o.status == ProductionOrderStatus.planned).length,
      ProductionOrderStatus.inProgress:
          orders.where((o) => o.status == ProductionOrderStatus.inProgress).length,
      ProductionOrderStatus.qualityCheck: orders
          .where((o) => o.status == ProductionOrderStatus.qualityCheck)
          .length,
      ProductionOrderStatus.completed:
          orders.where((o) => o.status == ProductionOrderStatus.completed).length,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Répartition du cycle de fabrication (${orders.length} OF)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ...counts.entries.map((entry) {
            final status = entry.key;
            final count = entry.value;
            final pct = orders.isEmpty ? 0.0 : (count / total);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(status.icon, size: 14, color: status.color),
                          const SizedBox(width: 6),
                          Text(status.label,
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Text('$count (${(pct * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor:
                          isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation(status.color),
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


  Widget _buildPriorityOrdersSection(List<ProductionOrder> orders, bool isDark) {
    final recent = orders.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ordres de fabrication récents & prioritaires',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Aucun ordre de fabrication enregistré.',
                    style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final o = recent[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: o.status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(o.status.icon, color: o.status.color, size: 20),
                  ),
                  title: Row(
                    children: [
                      Text(o.number,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(o.productName,
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  subtitle: Text(
                    'Progression : ${o.qtyProduced.toInt()} / ${o.qtyPlanned.toInt()} ${o.unit} (${o.progressPercentage.toStringAsFixed(0)}%)'
                    ' • Fin : ${o.plannedEnd != null ? dateFmt.format(o.plannedEnd!) : "Non planifiée"}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: o.status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: o.status.color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      o.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: o.status.color,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
