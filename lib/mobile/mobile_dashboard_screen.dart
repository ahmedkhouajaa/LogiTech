import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../widgets/dashboard_date_filter_dialog.dart';
import '../widgets/sidebar_menu.dart';
import '../services/app_navigation_service.dart';
import '../services/dashboard_privacy_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../models/invoice.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';

class MobileDashboardScreen extends StatelessWidget {
  const MobileDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading || state is DashboardInitial) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
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
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        context.read<DashboardBloc>().add(DashboardRefreshRequested());
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Date Filter Toolbar
          _buildFilterToolbar(context, state, isHidden),
          const SizedBox(height: 12),
          // KPI grid (2 per row)
          _buildKpiGrid(state, isHidden),
          const SizedBox(height: 20),
          // Quick Actions
          _buildQuickActions(context),
          const SizedBox(height: 20),
          // Recent invoices
          _buildRecentInvoices(state.recentInvoices, isHidden),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(BuildContext context, DashboardLoaded state, bool isHidden) {
    final dateRangeStr = _formatDateRangeDisplay(state.dateRange);

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
        const SizedBox(height: 8),
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

  Widget _buildVoirRapportsButton(BuildContext context) {
    return InkWell(
      onTap: () {
        AppNavigationService.instance.navigateToModule(context, AppModule.reports);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.call_made_rounded,
              size: 13,
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  Widget _buildWelcomeCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour ! 👋',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    // Text(
                    //   'Voici le resume de votre activite',
                    //   style: TextStyle(color: Colors.white70, fontSize: 13),
                    // ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(DashboardLoaded state, bool isHidden) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _kpiCard(
          icon: Icons.receipt_rounded,
          label: 'Chiffre d\'Affaires',
          value: isHidden ? '•••••• TND' : formatCurrency(state.totalInvoiced),
          gradient: AppGradients.primary,
        ),
        _kpiCard(
          icon: Icons.payments_rounded,
          label: 'Total Payé',
          value: isHidden ? '•••••• TND' : formatCurrency(state.totalPaid),
          gradient: AppGradients.success,
        ),
        _kpiCard(
          icon: Icons.local_shipping_rounded,
          label: 'Bons de Livraison',
          value: isHidden ? '••••' : state.totalDeliveryNotes.toInt().toString(),
          gradient: AppGradients.info,
        ),
        _kpiCard(
          icon: Icons.account_balance_rounded,
          label: 'TVA Collectée',
          value: isHidden ? '•••••• TND' : formatCurrency(state.totalTvaCollected),
          gradient: AppGradients.warning,
        ),
      ],
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickAction(Icons.receipt_rounded, 'Facture', AppColors.primary),
              SizedBox(width: 10),
              _quickAction(Icons.description_rounded, 'Devis', AppColors.info),
              SizedBox(width: 10),
              _quickAction(Icons.local_shipping_rounded, 'Bon de livraison', AppColors.success),
              SizedBox(width: 10),
              _quickAction(Icons.person_add_rounded, 'Client', AppColors.warning),
              SizedBox(width: 10),
              _quickAction(Icons.inventory_2_rounded, 'Article', AppColors.error),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, Color color) {
    return Container(
      width: 100,
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInvoices(List<Invoice> invoices, bool isHidden) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.receipt_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Factures recentes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          if (invoices.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Aucune facture', style: TextStyle(color: AppColors.textTertiary)),
              ),
            )
          else
            ...invoices.take(5).map((inv) => _invoiceRow(inv, isHidden)),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _invoiceRow(Invoice inv, bool isHidden) {
    final statusColor = _getStatusColor(inv.status);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_outlined, color: statusColor, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.number,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  inv.customerName ?? 'Client inconnu',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isHidden ? '•••••• TND' : formatCurrency(inv.totalTTC),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  inv.status.label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlerts(DashboardLoaded state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Text(
                  'Alertes stock bas',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${state.lowStockProducts.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
          ...state.lowStockProducts.take(5).map((p) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2_outlined, color: AppColors.warning, size: 16),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.name,
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${p.stockQty.toStringAsFixed(0)} unites',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                    ),
                  ],
                ),
              )),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return AppColors.textTertiary;
      case InvoiceStatus.sent:
        return AppColors.info;
      case InvoiceStatus.partial:
        return AppColors.warning;
      case InvoiceStatus.paid:
        return AppColors.success;
      case InvoiceStatus.unpaid:
        return AppColors.error;
      case InvoiceStatus.overdue:
        return AppColors.error;
      case InvoiceStatus.cancelled:
        return AppColors.textSecondary;
      case InvoiceStatus.transformed:
        return AppColors.info;
      case InvoiceStatus.pendingConfirmation:
        return const Color(0xFFF59E0B);
      case InvoiceStatus.impayee:
        return AppColors.error;
    }
  }
}
