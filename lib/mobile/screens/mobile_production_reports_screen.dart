import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/production_order.dart';
import '../../services/production_service.dart';
import '../../l10n/app_localizations.dart';

class MobileProductionReportsScreen extends StatefulWidget {
  const MobileProductionReportsScreen({super.key});

  @override
  State<MobileProductionReportsScreen> createState() =>
      _MobileProductionReportsScreenState();
}

class _MobileProductionReportsScreenState
    extends State<MobileProductionReportsScreen> {
  final currencyFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        ProductionService.instance.ordersNotifier,
        ProductionService.instance.qualityChecksNotifier,
        ProductionService.instance.nonConformitiesNotifier,
      ]),
      builder: (context, _) {
        final orders = ProductionService.instance.ordersNotifier.value;
        final ncs = ProductionService.instance.nonConformitiesNotifier.value;
        final oee = ProductionService.instance.getGlobalOeeRate();
        final scrapRate = ProductionService.instance.getGlobalScrapRate();
        final completedOrders = orders
            .where((o) => o.status == ProductionOrderStatus.completed)
            .toList();

        final onTimeCount = completedOrders.where((o) {
          if (o.actualEnd == null || o.plannedEnd == null) return true;
          return o.actualEnd!.isBefore(o.plannedEnd!) ||
              o.actualEnd!.isAtSameMomentAs(o.plannedEnd!);
        }).length;

        final onTimeRate = completedOrders.isNotEmpty
            ? (onTimeCount / completedOrders.length) * 100.0
            : 100.0;

        final monthlyQty =
            ProductionService.instance.getMonthlyProducedUnits();

        // Product Volume Map
        final Map<String, double> productVolumes = {};
        for (final o in completedOrders) {
          productVolumes[o.productName] =
              (productVolumes[o.productName] ?? 0.0) + o.qtyProduced;
        }

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF2563EB),
            onPressed: () => _exportPdf(
              context,
              oee: oee,
              scrapRate: scrapRate,
              onTimeRate: onTimeRate,
              completedCount: completedOrders.length,
              ncCount: ncs.length,
            ),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
            label: const Text('Export PDF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.4,
                  children: [
                    _buildKpiCard(
                      'Taux OEE (TRS)',
                      '${oee.toStringAsFixed(1)} %',
                      Icons.speed_rounded,
                      const Color(0xFF2563EB),
                      isDark,
                    ),
                    _buildKpiCard(
                      'Taux de Rebut',
                      '${scrapRate.toStringAsFixed(1)} %',
                      Icons.delete_sweep_outlined,
                      scrapRate > 5.0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      isDark,
                    ),
                    _buildKpiCard(
                      'Respect Délais',
                      '${onTimeRate.toStringAsFixed(1)} %',
                      Icons.timer_outlined,
                      const Color(0xFF8B5CF6),
                      isDark,
                    ),
                    _buildKpiCard(
                      'Unités Produites',
                      '${monthlyQty.toInt()} u',
                      Icons.precision_manufacturing_outlined,
                      const Color(0xFF0EA5E9),
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Production Volume breakdown by product
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('Volumes Produits Réalisés'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${productVolumes.length} articles',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (productVolumes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'Aucune fabrication clôturée pour le moment',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ...productVolumes.entries.map((entry) {
                          final maxQty = productVolumes.values
                              .fold(1.0, (acc, v) => v > acc ? v : acc);
                          final pct = (entry.value / maxQty).clamp(0.0, 1.0);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${entry.value.toStringAsFixed(0)} u',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Color(0xFF2563EB)),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Non conformities summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Qualité & Incidents',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniQualityStat(
                              'Non-conformités', '${ncs.length}', Colors.amber),
                          _buildMiniQualityStat(
                              'OF Terminés', '${completedOrders.length}', Colors.green),
                          _buildMiniQualityStat(
                              'En cours', '${orders.where((o) => o.status == ProductionOrderStatus.inProgress).length}', Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 70), // Padding for FAB
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(
      String title, String val, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniQualityStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Future<void> _exportPdf(
    BuildContext context, {
    required double oee,
    required double scrapRate,
    required double onTimeRate,
    required int completedCount,
    required int ncCount,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Rapport de Rendement Production (GPAO)',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Indicateurs de Performance Clés :',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Bullet(text: 'Taux de Rendement Synthétique (OEE) : ${oee.toStringAsFixed(1)} %'),
              pw.Bullet(text: 'Taux de Rebut Global : ${scrapRate.toStringAsFixed(1)} %'),
              pw.Bullet(text: 'Taux de Respect des Délais : ${onTimeRate.toStringAsFixed(1)} %'),
              pw.Bullet(text: 'Ordres de fabrication finalisés : $completedCount'),
              pw.Bullet(text: 'Fiches de non-conformité recensées : $ncCount'),
              pw.SizedBox(height: 20),
              pw.Paragraph(
                text:
                    'Ce document récapitule les indicateurs d\'efficacité de l\'atelier de fabrication générés automatiquement par LogiTech Pro.',
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_Production_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
