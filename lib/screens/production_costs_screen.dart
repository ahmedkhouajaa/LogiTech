import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/production_service.dart';
import '../l10n/app_localizations.dart';

class ProductionCostsScreen extends StatefulWidget {
  const ProductionCostsScreen({super.key});

  @override
  State<ProductionCostsScreen> createState() => _ProductionCostsScreenState();
}

class _ProductionCostsScreenState extends State<ProductionCostsScreen> {
  final currencyFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: ProductionService.instance.ordersNotifier,
      builder: (context, _) {
        final allOrders = ProductionService.instance.ordersNotifier.value;
        final ordersWithCosts = allOrders.where((o) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return o.number.toLowerCase().contains(q) ||
                o.productName.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        // Totals
        final totalPlanned = allOrders.fold(0.0, (acc, o) => acc + o.plannedTotalCost);
        final totalActual = allOrders.fold(0.0, (acc, o) => acc + o.actualTotalCost);
        final totalVariance = totalActual - totalPlanned;
        final totalMatActual = allOrders.fold(0.0, (acc, o) => acc + o.actualMaterialCost);
        final totalOpsActual = allOrders.fold(0.0, (acc, o) => acc + o.actualOperationCost);

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Suivi des Coûts de Production (Prévu vs Réel)'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Analyse des coûts matières, main-d\'œuvre et calcul des écarts de fabrication',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // KPI Cost Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
                          child: _buildKpiBox(
                            title: 'Budget Prévu Total',
                            value: currencyFmt.format(totalPlanned),
                            subtitle: 'Selon nomenclatures',
                            color: const Color(0xFF2563EB),
                            isDark: isDark,
                          ),
                        ),
                        SizedBox(
                          width: isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
                          child: _buildKpiBox(
                            title: 'Coût Réel Engagé',
                            value: currencyFmt.format(totalActual),
                            subtitle: 'Matières + Heures ateliers',
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                          ),
                        ),
                        SizedBox(
                          width: isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
                          child: _buildKpiBox(
                            title: 'Écart de Fabrication',
                            value: currencyFmt.format(totalVariance),
                            subtitle: totalVariance > 0 ? 'Dépassement de budget' : 'Économie constatée',
                            color: totalVariance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                        ),
                        SizedBox(
                          width: isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 48) / 4,
                          child: _buildKpiBox(
                            title: 'Part Matières vs Opérations',
                            value: totalActual > 0
                                ? '${((totalMatActual / totalActual) * 100).toStringAsFixed(0)}% / ${((totalOpsActual / totalActual) * 100).toStringAsFixed(0)}%'
                                : '0% / 0%',
                            subtitle: 'Matières premières / Main d\'œuvre',
                            color: const Color(0xFFF59E0B),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Search Bar (Styled to match Image 2)
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Filtrer par N° OF ou article...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                const SizedBox(height: 16),

                // Cost Comparison Table
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: ordersWithCosts.isEmpty
                        ? const Center(
                            child: Text('Aucun ordre de fabrication trouvé.',
                                style: TextStyle(color: Color(0xFF94A3B8))),
                          )
                        : ListView.separated(
                            itemCount: ordersWithCosts.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final o = ordersWithCosts[i];
                              final isOver = o.costVariance > 0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(o.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                          const SizedBox(height: 2),
                                          Text(o.productName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Budget Prévu', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          Text(currencyFmt.format(o.plannedTotalCost), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Coût Réel', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          Text(currencyFmt.format(o.actualTotalCost), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Écart', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          Text(
                                            currencyFmt.format(o.costVariance),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isOver ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Coût Unitaire Réel', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          Text(
                                            o.qtyProduced > 0 ? currencyFmt.format(o.actualUnitCost) : '-',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiBox({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
