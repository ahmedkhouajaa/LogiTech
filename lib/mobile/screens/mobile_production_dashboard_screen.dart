import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/production_service.dart';

class MobileProductionDashboardScreen extends StatelessWidget {
  const MobileProductionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('dd/MM/yyyy');

    return ListenableBuilder(
      listenable: ProductionService.instance.ordersNotifier,
      builder: (context, _) {
        final orders = ProductionService.instance.ordersNotifier.value;
        final activeCount = ProductionService.instance.getActiveOrdersCount();
        final delayedCount = ProductionService.instance.getDelayedOrdersCount();
        final monthlyQty =
            ProductionService.instance.getMonthlyProducedUnits();
        final oee = ProductionService.instance.getGlobalOeeRate();

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Gradient Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Production & Ateliers (GPAO)',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$activeCount Ordres Actifs',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBannerStat(
                            'Retards',
                            '$delayedCount OF',
                            delayedCount > 0
                                ? const Color(0xFFFCA5A5)
                                : Colors.white70,
                          ),
                          _buildBannerStat(
                            'Produits (Mois)',
                            '${monthlyQty.toInt()} u',
                            Colors.white,
                          ),
                          _buildBannerStat(
                            'Rendement OEE',
                            '${oee.toStringAsFixed(0)} %',
                            const Color(0xFF86EFAC),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),



                // Active Orders List
                Text(
                  'Ordres de fabrication récents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                if (orders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Aucun ordre de fabrication enregistré.',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                else
                  ...orders.take(5).map((o) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(o.number,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: o.status.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(o.status.label,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: o.status.color)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(o.productName,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${o.qtyProduced.toInt()} / ${o.qtyPlanned.toInt()} ${o.unit}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                o.plannedEnd != null
                                    ? dateFmt.format(o.plannedEnd!)
                                    : '-',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (o.progressPercentage / 100.0)
                                  .clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation(o.status.color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerStat(String title, String val, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(val,
            style: TextStyle(
                color: valColor, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

}
