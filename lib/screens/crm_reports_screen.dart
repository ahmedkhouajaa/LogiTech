import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/crm_opportunity.dart';
import '../services/crm_service.dart';
import '../l10n/app_localizations.dart';

class CrmReportsScreen extends StatefulWidget {
  const CrmReportsScreen({super.key});

  @override
  State<CrmReportsScreen> createState() => _CrmReportsScreenState();
}

class _CrmReportsScreenState extends State<CrmReportsScreen> {
  final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        final avgDealSize = wonOpps.isNotEmpty ? totalWon / wonOpps.length : 0.0;

        // Group by Source
        final Map<String, int> sourceCounts = {};
        for (final o in opps) {
          sourceCounts[o.source] = (sourceCounts[o.source] ?? 0) + 1;
        }

        // Group lost reasons
        final Map<String, int> lostReasons = {};
        for (final o in lostOpps) {
          final r = o.lostReason ?? 'Sans suite';
          lostReasons[r] = (lostReasons[r] ?? 0) + 1;
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                _buildHeader(context, isDark, opps, totalWon, winRate),
                const SizedBox(height: 20),

                // 4 KPI Summary Cards
                _buildSummaryKpis(isDark, totalWon, winRate, avgDealSize, opps.length),
                const SizedBox(height: 24),

                // Charts / Breakdown Grids
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 850;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildFunnelReportCard(isDark, opps, stages),
                                const SizedBox(height: 20),
                                _buildSourcesCard(isDark, sourceCounts, opps.length),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                _buildWinLossCard(isDark, wonOpps.length, lostOpps.length, opps.length - wonOpps.length - lostOpps.length),
                                const SizedBox(height: 20),
                                _buildLostReasonsCard(isDark, lostReasons, lostOpps.length),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _buildFunnelReportCard(isDark, opps, stages),
                        const SizedBox(height: 20),
                        _buildWinLossCard(isDark, wonOpps.length, lostOpps.length, opps.length - wonOpps.length - lostOpps.length),
                        const SizedBox(height: 20),
                        _buildSourcesCard(isDark, sourceCounts, opps.length),
                        const SizedBox(height: 20),
                        _buildLostReasonsCard(isDark, lostReasons, lostOpps.length),
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

  Widget _buildHeader(BuildContext context, bool isDark, List<CrmOpportunity> opps, double won, double rate) {
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Rapports de Performance CRM'),
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
              'Statistiques de conversion, prévisions et efficacité de votre équipe commerciale',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _exportPdfReport(opps, won, rate),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
          label: const Text('Exporter PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryKpis(bool isDark, double totalWon, double winRate, double avgDealSize, int totalDeals) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = constraints.maxWidth > 800 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildKpiBox('CA Signé Total', currencyFmt.format(totalWon), Icons.monetization_on_rounded, const Color(0xFF10B981), isDark),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildKpiBox('Taux de Clôture', '${winRate.toStringAsFixed(1)} %', Icons.pie_chart_rounded, const Color(0xFF2563EB), isDark),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildKpiBox('Panier Moyen Gagné', currencyFmt.format(avgDealSize), Icons.shopping_bag_outlined, const Color(0xFF8B5CF6), isDark),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildKpiBox('Volume d\'affaires', '$totalDeals opportunités', Icons.stacked_bar_chart_rounded, const Color(0xFFF59E0B), isDark),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiBox(String title, String val, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelReportCard(bool isDark, List<CrmOpportunity> opps, List<CrmStage> stages) {
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
            children: const [
              Icon(Icons.filter_list_rounded, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Text('Progression dans les Étapes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...stages.map((stage) {
            final count = opps.where((o) => o.stageId == stage.id).length;
            final pct = opps.isEmpty ? 0.0 : count / opps.length;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(stage.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      Text('$count (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stage.color)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(stage.color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWinLossCard(bool isDark, int won, int lost, int active) {
    final total = won + lost + active;

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
            children: const [
              Icon(Icons.donut_large_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text('Répartition Gagné / Perdu / En cours', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildBarShare('Gagné (Signé)', won, total, const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _buildBarShare('En négociation / Actif', active, total, const Color(0xFF2563EB)),
          const SizedBox(height: 10),
          _buildBarShare('Perdu / Annulé', lost, total, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildBarShare(String title, int count, int total, Color color) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            Text('$count (${(pct * 100).toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          minHeight: 6,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildSourcesCard(bool isDark, Map<String, int> sources, int total) {
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
            children: const [
              Icon(Icons.share_location_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 8),
              Text('Origine des Affaires (Canaux)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (sources.isEmpty)
            const Text('Aucune donnée')
          else
            ...sources.entries.map((e) {
              final pct = total > 0 ? (e.value / total) * 100 : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 12.5)),
                    Text('${e.value} (${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLostReasonsCard(bool isDark, Map<String, int> reasons, int totalLost) {
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
            children: const [
              Icon(Icons.highlight_off_rounded, color: Color(0xFFEF4444), size: 18),
              SizedBox(width: 8),
              Text('Motifs des Affaires Perdues', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (reasons.isEmpty)
            const Text('Aucune affaire perdue déclarée !')
          else
            ...reasons.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 12.5)),
                    Text('${e.value} affaire(s)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _exportPdfReport(List<CrmOpportunity> opps, double won, double rate) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Rapport Commercial CRM - LogiTech', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Synthèse Générale :', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Bullet(text: 'Total CA Gagné : ${currencyFmt.format(won)}'),
              pw.Bullet(text: 'Taux de conversion global : ${rate.toStringAsFixed(1)} %'),
              pw.Bullet(text: 'Nombre total d\'opportunités gérées : ${opps.length}'),
              pw.SizedBox(height: 20),
              pw.Text('Liste des Opportunités Récentes :', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Titre', 'Client', 'Étape', 'Montant', 'Proba.'],
                data: opps.take(15).map((o) => [
                  o.title,
                  o.customerName,
                  o.stageName,
                  currencyFmt.format(o.expectedRevenue),
                  '${o.probability}%',
                ]).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_CRM_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
