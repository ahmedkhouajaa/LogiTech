import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/production_order.dart';
import '../services/production_service.dart';
import '../l10n/app_localizations.dart';

class ProductionReportsScreen extends StatefulWidget {
  const ProductionReportsScreen({super.key});

  @override
  State<ProductionReportsScreen> createState() =>
      _ProductionReportsScreenState();
}

class _ProductionReportsScreenState extends State<ProductionReportsScreen> {
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

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
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
                          context.tr('Rapports de Rendement & Performance GPAO'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Indicateurs TRS / OEE, taux de rebuts, respect des délais et analyse des défauts',
                          style:
                              TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _exportProductionReportPdf(
                        oee: oee,
                        scrapRate: scrapRate,
                        onTimeRate: onTimeRate,
                        completedOrders: completedOrders,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Exporter Rapport PDF',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4 Top Indicator Cards
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
                          child: _buildReportCard(
                            title: 'Taux de Rendement OEE / TRS',
                            value: '${oee.toStringAsFixed(1)} %',
                            subtitle: 'Disponibilité × Efficacité',
                            color: const Color(0xFF2563EB),
                            isDark: isDark,
                          ),
                        ),
                        SizedBox(
                          width: isNarrow
                              ? (constraints.maxWidth - 16) / 2
                              : (constraints.maxWidth - 48) / 4,
                          child: _buildReportCard(
                            title: 'Taux de Rebuts & Pertes',
                            value: '${scrapRate.toStringAsFixed(1)} %',
                            subtitle: scrapRate <= 3 ? 'Excellente maîtrise' : 'Pertes à auditer',
                            color: scrapRate <= 3
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            isDark: isDark,
                          ),
                        ),
                        SizedBox(
                          width: isNarrow
                              ? (constraints.maxWidth - 16) / 2
                              : (constraints.maxWidth - 48) / 4,
                          child: _buildReportCard(
                            title: 'Respect des Délais (OTD)',
                            value: '${onTimeRate.toStringAsFixed(1)} %',
                            subtitle: '$onTimeCount / ${completedOrders.length} OF livrés à temps',
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                        ),
                        SizedBox(
                          width: isNarrow
                              ? (constraints.maxWidth - 16) / 2
                              : (constraints.maxWidth - 48) / 4,
                          child: _buildReportCard(
                            title: 'Non-Conformités Totales',
                            value: '${ncs.length}',
                            subtitle: '${ncs.where((n) => n.status == "resolue").length} résolues',
                            color: const Color(0xFFF59E0B),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Top Products Produced Breakdown
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Volume de Fabrication par Produit Fini',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (orders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('Aucune donnée de production.',
                                style: TextStyle(color: Color(0xFF94A3B8))),
                          ),
                        )
                      else ...[
                        ..._groupOrdersByProduct(orders).entries.map((entry) {
                          final prodName = entry.key;
                          final qty = entry.value;
                          final maxQty = orders.fold(
                              0.0, (acc, o) => acc + o.qtyProduced);
                          final pct = maxQty > 0 ? (qty / maxQty) : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(prodName,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text('${qty.toInt()} unités (${(pct * 100).toStringAsFixed(1)}%)',
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
                                    value: pct.clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9),
                                    valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFF2563EB)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
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

  Map<String, double> _groupOrdersByProduct(List<ProductionOrder> orders) {
    final Map<String, double> map = {};
    for (final o in orders) {
      map[o.productName] = (map[o.productName] ?? 0.0) + o.qtyProduced;
    }
    return map;
  }

  Widget _buildReportCard({
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
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle,
              style:
                  const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Future<void> _exportProductionReportPdf({
    required double oee,
    required double scrapRate,
    required double onTimeRate,
    required List<ProductionOrder> completedOrders,
  }) async {
    final doc = pw.Document();

    doc.addPage(
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
                    pw.Text('RAPPORT DE RENDEMENT & PERFORMANCE GPAO',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('INDICATEURS CLÉS :',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Bullet(text: 'Taux de rendement OEE / TRS : ${oee.toStringAsFixed(1)} %'),
              pw.Bullet(text: 'Taux de rebuts & pertes : ${scrapRate.toStringAsFixed(1)} %'),
              pw.Bullet(text: 'Respect des délais (OTD) : ${onTimeRate.toStringAsFixed(1)} %'),
              pw.Bullet(text: 'Total OF terminés : ${completedOrders.length}'),
              pw.SizedBox(height: 16),
              pw.Text('HISTORIQUE DES OF TERMINÉS :',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['N° OF', 'Article', 'Qté Produite', 'Coût Réel'],
                data: completedOrders
                    .map((o) => [
                          o.number,
                          o.productName,
                          '${o.qtyProduced.toInt()} ${o.unit}',
                          '${o.actualTotalCost.toStringAsFixed(2)} TND'
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
