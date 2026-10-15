import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/dashboard_date_filter_dialog.dart';
import '../widgets/sidebar_menu.dart';
import '../services/app_navigation_service.dart';
import '../services/dashboard_privacy_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../models/invoice.dart';
import '../models/check_traite.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';

import '../widgets/dashboard_shimmer_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading || state is DashboardInitial) {
          return const DashboardShimmerWidget();
        }
        if (state is DashboardError) {
          return AppErrorWidget(
            message: state.message,
            onRetry: () => context.read<DashboardBloc>().add(DashboardRefreshRequested()),
          );
        }
        if (state is DashboardLoaded) {
          return ValueListenableBuilder<bool>(
            valueListenable: DashboardPrivacyService.instance.isHidden,
            builder: (context, isHidden, _) {
              return _buildDashboard(context, state, isHidden);
            },
          );
        }
        return SizedBox();
      },
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardLoaded state, bool isHidden) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter toolbar matching the user's reference (Voir Rapports, filters, date range)
          _buildFilterToolbar(context, state, isMobile, isHidden),
          const SizedBox(height: 14),
          // KPI cards
          _buildKpiRow(state, isMobile, isHidden),
          SizedBox(height: AppSpacing.md),
          // Bottom row (Recent invoices only)
          _buildRecentInvoices(state.recentInvoices, isHidden),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(BuildContext context, DashboardLoaded state, bool isMobile, bool isHidden) {
    final dateRangeStr = _formatDateRangeDisplay(state.dateRange);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Aperçu général'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              _buildVoirRapportsButton(context),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateRangeButton(context, dateRangeStr, state.dateRange),
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.tune_rounded,
                tooltip: context.tr('Filtres rapides'),
                onTap: () => _openDateRangePicker(context, state.dateRange),
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                tooltip: isHidden ? context.tr('Afficher les chiffres') : context.tr('Masquer les chiffres'),
                isActive: isHidden,
                onTap: () => DashboardPrivacyService.instance.toggle(),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          context.tr('Aperçu général'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        // 1. Voir Rapports ↗
        _buildVoirRapportsButton(context),
        const SizedBox(width: 8),
        // 2. [ 🎛️ ]
        _buildIconButton(
          icon: Icons.tune_rounded,
          tooltip: context.tr('Filtres rapides'),
          onTap: () => _openDateRangePicker(context, state.dateRange),
        ),
        const SizedBox(width: 8),
        // 3. [ 👁️ ]
        _buildIconButton(
          icon: isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          tooltip: isHidden ? context.tr('Afficher les chiffres') : context.tr('Masquer les chiffres'),
          isActive: isHidden,
          onTap: () => DashboardPrivacyService.instance.toggle(),
        ),
        const SizedBox(width: 8),
        // 4. [ 📅 Date Range ]
        _buildDateRangeButton(context, dateRangeStr, state.dateRange),
      ],
    );
  }

  Widget _buildVoirRapportsButton(BuildContext context) {
    return InkWell(
      onTap: () {
        AppNavigationService.instance.navigateToModule(context, AppModule.reports);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('Voir Rapports'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.call_made_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2563EB).withValues(alpha: 0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF2563EB).withValues(alpha: 0.4) : AppColors.border,
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Icon(
            icon,
            size: 17,
            color: isActive ? const Color(0xFF2563EB) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeButton(BuildContext context, String label, DateTimeRange? currentRange) {
    return InkWell(
      onTap: () => _openDateRangePicker(context, currentRange),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDateRangePicker(BuildContext context, DateTimeRange? currentRange) async {
    final picked = await DashboardDateFilterDialog.show(
      context,
      initialRange: currentRange,
    );

    if (!context.mounted) return;

    context.read<DashboardBloc>().add(
      DashboardRefreshRequested(
        dateRange: picked,
        clearDateRange: picked == null,
      ),
    );
  }

  String _formatDateRangeDisplay(DateTimeRange? range) {
    if (range == null) return 'Toutes les dates';
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    final sDay = range.start.day.toString().padLeft(2, '0');
    final sMonth = months[range.start.month - 1];
    final sYear = range.start.year;

    final eDay = range.end.day.toString().padLeft(2, '0');
    final eMonth = months[range.end.month - 1];
    final eYear = range.end.year;

    if (DateUtils.isSameDay(range.start, range.end)) {
      return '$sDay $sMonth, $sYear';
    }

    return '$sDay $sMonth, $sYear - $eDay $eMonth, $eYear';
  }

  Widget _buildWelcomeHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bienvenue !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 4),
                // Text('Voici le resume de votre activite', style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white),
                  label: Text('Voir Rapports', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
                ),
              ],
            )
          : Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bienvenue !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 4),
                    // Text('Voici le resume de votre activite', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white),
                  label: Text('Voir Rapports', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiRow(DashboardLoaded state, bool isMobile, bool isHidden) {
    final totalInvoiced = state.totalInvoiced;
    final paid = state.invoiceStatusBreakdown['paid'] ?? 0;
    final partial = state.invoiceStatusBreakdown['partial'] ?? 0;
    final unpaid = state.invoiceStatusBreakdown['unpaid'] ?? 0;

    final cards = [
      DashboardCard(
        title: 'Montant Facture',
        value: isHidden ? '•••••• TND' : formatCurrencyCompact(totalInvoiced),
        subtitle: isHidden
            ? 'Paye ••% · En cours ••% · Impaye ••%'
            : 'Paye ${paid.toStringAsFixed(0)}% · En cours ${partial.toStringAsFixed(0)}% · Impaye ${unpaid.toStringAsFixed(0)}%',
        icon: Icons.receipt_long_rounded,
        gradientColors: const [Color(0xFF1a56db), Color(0xFF3B82F6)],
        compact: true,
      ),
      DashboardCard(
        title: 'Bons de Livraison',
        value: isHidden ? '••••' : state.totalDeliveryNotes.toInt().toString(),
        subtitle: 'Bons actifs ce mois',
        icon: Icons.local_shipping_rounded,
        gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
        compact: true,
      ),
      DashboardCard(
        title: 'Paiements recus',
        value: isHidden ? '•••••• TND' : formatCurrencyCompact(state.totalPaid),
        subtitle: 'Encaissements total',
        icon: Icons.payments_rounded,
        gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
        compact: true,
      ),
      DashboardCard(
        title: 'TVA Collectee',
        value: isHidden ? '•••••• TND' : formatCurrencyCompact(state.totalTvaCollected),
        subtitle: isHidden
            ? 'TVA deductible: •••••• TND'
            : 'TVA deductible: ${formatCurrencyCompact(state.totalTvaDeductible)}',
        icon: Icons.calculate_rounded,
        gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
        compact: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: c,
                    ))
                .toList(),
          );
        }
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCashFlowChart() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Prevision de Tresorerie', icon: Icons.trending_up_rounded),
          SizedBox(height: 20),
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
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: (v, _) => Text(formatCurrencyCompact(v), style: TextStyle(fontSize: 10, color: AppColors.textTertiary)))),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const months = ['Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jun'];
                      final idx = v.toInt();
                      if (idx < 0 || idx >= months.length) return SizedBox();
                      return Text(months[idx], style: TextStyle(fontSize: 10, color: AppColors.textTertiary));
                    },
                  )),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
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
                    spots: [
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
          SizedBox(height: 8),
          Row(
            children: [
              _buildLegend(AppColors.primary, 'Recettes'),
              SizedBox(width: 16),
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
        Container(width: 16, height: 3, color: color, margin: EdgeInsets.only(right: 6)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SectionHeader(title: 'Echeancier', icon: Icons.calendar_today_rounded,
              action: Text('${checks.length} a venir', style: TextStyle(fontSize: 12, color: AppColors.primary))),
          ),
          Divider(height: 1),
          if (checks.isEmpty)
            Padding(
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Icon(c.type == 'check_received' || c.type == 'traite_received'
              ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 14, color: c.type == 'check_received' || c.type == 'traite_received'
                ? AppColors.success : AppColors.error),
          SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.partyName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(formatDate(c.maturityDate), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatCurrencyCompact(c.amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(daysLeft <= 0 ? 'Echu' : 'J-$daysLeft', style: TextStyle(fontSize: 11, color: isUrgent ? AppColors.error : AppColors.textTertiary)),
          ]),
        ],
      ),
    );
  }

  Widget _buildRecentInvoices(List<Invoice> invoices, bool isHidden) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SectionHeader(title: 'Factures recentes', icon: Icons.receipt_rounded),
          ),
          Divider(height: 1),
          if (invoices.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucune facture', style: TextStyle(color: AppColors.textTertiary, fontSize: 13))),
            )
          else ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  Expanded(flex: 3, child: Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('Montant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
                ],
              ),
            ),
            ...invoices.map((inv) => _buildInvoiceRow(inv, isHidden)),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(Invoice inv, bool isHidden) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(inv.number, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary))),
          Expanded(flex: 3, child: Text(inv.customerName ?? '—', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(formatDate(inv.date), style: TextStyle(fontSize: 12, color: AppColors.textTertiary))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(label: inv.status.label, color: inv.status.color))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                isHidden ? '•••••• TND' : formatCurrencyDT(inv.totalTTC + inv.timbreFiscal),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
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
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SectionHeader(
              title: 'Alertes Stock',
              icon: Icons.warning_rounded,
              action: state.lowStockProducts.isNotEmpty
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
                      child: Text('${state.lowStockProducts.length}', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  : null,
            ),
          ),
          Divider(height: 1),
          if (state.lowStockProducts.isEmpty)
            Padding(
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
          SizedBox(width: 10),
          Expanded(child: Text(name, style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
          Text('${formatQuantity(qty)} $unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
        ],
      ),
    );
  }
}
