import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../widgets/dashboard_card.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../models/invoice.dart';
import '../models/check_traite.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading || state is DashboardInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DashboardError) {
          return Center(child: Text('Erreur: ${state.message}'));
        }
        if (state is DashboardLoaded) {
          print('DashboardScreen: received DashboardLoaded!');
          return _buildDashboard(context, state);
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardLoaded state) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          _buildWelcomeHeader(isMobile),
          const SizedBox(height: AppSpacing.lg),
          // KPI cards
          _buildKpiRow(state, isMobile),
          const SizedBox(height: AppSpacing.lg),
          // Charts + upcoming
          if (isMobile) ...[
            _buildCashFlowChart(),
            const SizedBox(height: AppSpacing.lg),
            _buildUpcomingChecks(state.upcomingChecks),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildCashFlowChart()),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: _buildUpcomingChecks(state.upcomingChecks)),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          // Bottom row
          if (isMobile) ...[
            _buildRecentInvoices(state.recentInvoices),
            const SizedBox(height: AppSpacing.lg),
            _buildLowStockAlerts(state),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRecentInvoices(state.recentInvoices)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: _buildLowStockAlerts(state)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bienvenue !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Voici le resume de votre activite', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white),
                  label: const Text('Voir Rapports', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
                ),
              ],
            )
          : Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bienvenue !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 4),
                    Text('Voici le resume de votre activite', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white),
                  label: const Text('Voir Rapports', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiRow(DashboardLoaded state, bool isMobile) {
    final totalInvoiced = state.totalInvoiced;
    final paid = state.invoiceStatusBreakdown['paid'] ?? 0;
    final partial = state.invoiceStatusBreakdown['partial'] ?? 0;
    final unpaid = state.invoiceStatusBreakdown['unpaid'] ?? 0;

    final cards = [
      DashboardCard(
        title: 'Montant Facture',
        value: formatCurrencyCompact(totalInvoiced),
        subtitle: 'Paye ${paid.toStringAsFixed(0)}% · En cours ${partial.toStringAsFixed(0)}% · Impaye ${unpaid.toStringAsFixed(0)}%',
        icon: Icons.receipt_long_rounded,
        gradientColors: const [Color(0xFF1a56db), Color(0xFF3B82F6)],
      ),
      DashboardCard(
        title: 'Bons de Livraison',
        value: state.totalDeliveryNotes.toInt().toString(),
        subtitle: 'Bons actifs ce mois',
        icon: Icons.local_shipping_rounded,
        gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      ),
      DashboardCard(
        title: 'Paiements recus',
        value: formatCurrencyCompact(state.totalPaid),
        subtitle: 'Encaissements total',
        icon: Icons.payments_rounded,
        gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
      ),
      DashboardCard(
        title: 'TVA Collectee',
        value: formatCurrencyCompact(state.totalTvaCollected),
        subtitle: 'TVA deductible: ${formatCurrencyCompact(state.totalTvaDeductible)}',
        icon: Icons.calculate_rounded,
        gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: c)).toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: cards[1]),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: cards[2]),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: cards[3]),
      ],
    );
  }

  Widget _buildCashFlowChart() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Prevision de Tresorerie', icon: Icons.trending_up_rounded),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
                  getDrawingVerticalLine: (_) => FlLine(color: Colors.transparent),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: (v, _) => Text(formatCurrencyCompact(v), style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)))),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const months = ['Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jun'];
                      final idx = v.toInt();
                      if (idx < 0 || idx >= months.length) return const SizedBox();
                      return Text(months[idx], style: const TextStyle(fontSize: 10, color: AppColors.textTertiary));
                    },
                  )),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 120000), FlSpot(1, 180000), FlSpot(2, 150000),
                      FlSpot(3, 220000), FlSpot(4, 195000), FlSpot(5, 260000),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.08)),
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 80000), FlSpot(1, 95000), FlSpot(2, 110000),
                      FlSpot(3, 130000), FlSpot(4, 115000), FlSpot(5, 140000),
                    ],
                    isCurved: true,
                    color: AppColors.error,
                    barWidth: 2.5,
                    dashArray: [5, 5],
                    belowBarData: BarAreaData(show: true, color: AppColors.error.withValues(alpha: 0.05)),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegend(AppColors.primary, 'Recettes'),
              const SizedBox(width: 16),
              _buildLegend(AppColors.error, 'Depenses'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 3, color: color, margin: const EdgeInsets.only(right: 6)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildUpcomingChecks(List<CheckTraite> checks) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SectionHeader(title: 'Echeancier', icon: Icons.calendar_today_rounded,
              action: Text('${checks.length} a venir', style: TextStyle(fontSize: 12, color: AppColors.primary))),
          ),
          const Divider(height: 1),
          if (checks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucun echeance prochaine', style: TextStyle(color: AppColors.textTertiary, fontSize: 13))),
            )
          else
            ...checks.take(6).map((c) => _buildCheckRow(c)),
        ],
      ),
    );
  }

  Widget _buildCheckRow(CheckTraite c) {
    final daysLeft = c.daysUntilMaturity;
    final isUrgent = daysLeft <= 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Icon(c.type == 'check_received' || c.type == 'traite_received'
              ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 14, color: c.type == 'check_received' || c.type == 'traite_received'
                ? AppColors.success : AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.partyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(formatDate(c.maturityDate), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatCurrencyCompact(c.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(daysLeft <= 0 ? 'Echu' : 'J-$daysLeft', style: TextStyle(fontSize: 11, color: isUrgent ? AppColors.error : AppColors.textTertiary)),
          ]),
        ],
      ),
    );
  }

  Widget _buildRecentInvoices(List<Invoice> invoices) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: const SectionHeader(title: 'Factures recentes', icon: Icons.receipt_rounded),
          ),
          const Divider(height: 1),
          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucune facture', style: TextStyle(color: AppColors.textTertiary, fontSize: 13))),
            )
          else
            ...invoices.map((inv) => _buildInvoiceRow(inv)),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(Invoice inv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Text(inv.number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: Text(inv.customerName ?? '—', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
          Text(formatDate(inv.date), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          const SizedBox(width: 12),
          StatusBadge(label: inv.status.label, color: inv.status.color),
          const SizedBox(width: 12),
          Text(formatCurrencyCompact(inv.totalTTC), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLowStockAlerts(DashboardLoaded state) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SectionHeader(
              title: 'Alertes Stock',
              icon: Icons.warning_rounded,
              action: state.lowStockProducts.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
                      child: Text('${state.lowStockProducts.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  : null,
            ),
          ),
          const Divider(height: 1),
          if (state.lowStockProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Column(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 32),
                  SizedBox(height: 8),
                  Text('Stock OK', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                ],
              )),
            )
          else
            ...state.lowStockProducts.take(6).map((p) => _buildStockAlertRow(p.name, p.stockQty, p.unit, p.minStockQty)),
        ],
      ),
    );
  }

  Widget _buildStockAlertRow(String name, double qty, String unit, double minQty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
          Text('${formatQuantity(qty)} $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
        ],
      ),
    );
  }
}
