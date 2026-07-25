import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';
import '../blocs/reports/reports_bloc.dart';
import '../models/report_data.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedDateRange = 'Cette Année';
  String _selectedWarehouse = 'Tous les entrepôts';
  String _selectedCategory = 'Toutes les catégories';

  void _exportReport(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export $format en cours...'),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export $format terminé !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _applyFilters() {
    context.read<ReportsBloc>().add(ReportsRefreshRequested(
          dateRange: _selectedDateRange,
          warehouse: _selectedWarehouse,
          category: _selectedCategory,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (context, state) {
          if (state is ReportsLoading) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          } else if (state is ReportsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  SizedBox(height: 16),
                  Text('Erreur: ${state.message}', style: TextStyle(color: AppColors.error)),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: _applyFilters, child: Text('Réessayer'))
                ],
              ),
            );
          } else if (state is ReportsLoaded) {
            return _buildContent(state);
          }
          return SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(ReportsLoaded state) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          SizedBox(height: AppSpacing.lg),
          _buildKPIsRow(state),
          SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildMonthlySalesChart(state.monthlySales)),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildWarehouseStockChart(state.warehouseStock)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCategoryPieChart(state.categorySales)),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildTopClientsTable(state.topClients)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _buildSupplierPerformanceChart(state.supplierPerformance),
          SizedBox(height: AppSpacing.xl),
          _buildExportSection(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _selectedDateRange,
                items: ['Ce Mois', 'Ce Trimestre', 'Cette Année', 'Personnalisé'],
                onChanged: (val) => setState(() => _selectedDateRange = val!),
                icon: Icons.calendar_today_rounded,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildDropdown(
                value: _selectedWarehouse,
                items: ['Tous les entrepôts', 'Entrepôt A', 'Entrepôt B', 'Entrepôt C'],
                onChanged: (val) => setState(() => _selectedWarehouse = val!),
                icon: Icons.warehouse_rounded,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildDropdown(
                value: _selectedCategory,
                items: ['Toutes les catégories', 'Électronique', 'Mobilier', 'Vêtements'],
                onChanged: (val) => setState(() => _selectedCategory = val!),
                icon: Icons.category_rounded,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _applyFilters,
              icon: Icon(Icons.filter_list_rounded, size: 18),
              label: Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          items: items.map((e) => DropdownMenuItem(value: e, child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(e, overflow: TextOverflow.ellipsis)),
            ],
          ))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildKPIsRow(ReportsLoaded state) {
    return Row(
      children: [
        Expanded(child: _buildKPICard('Rotation des stocks', '${state.turnoverRate}x', Icons.sync_rounded, AppColors.primary)),
        SizedBox(width: AppSpacing.md),
        Expanded(child: _buildKPICard('Taux de remplissage', '${state.fulfillmentRate}%', Icons.inventory_2_rounded, AppColors.primary)),
        SizedBox(width: AppSpacing.md),
        Expanded(child: _buildKPICard('Délai moyen', '${state.avgDeliveryTime}j', Icons.timer_rounded, AppColors.primary)),
        SizedBox(width: AppSpacing.md),
        Expanded(child: _buildKPICard('Rupture de stock', '${state.stockoutRate}%', Icons.warning_rounded, AppColors.primary)),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(icon, color: color, size: 24),
                ),
                Spacer(),
                Icon(Icons.more_horiz_rounded, color: AppColors.textTertiary),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: AppSpacing.xs),
            Text(title, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySalesChart(List<MonthlySales> data) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Évolution des ventes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < data.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(data[value.toInt()].month, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.sales)).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseStockChart(List<WarehouseStock> data) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock par entrepôt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < data.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(data[value.toInt()].warehouseName, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  barGroups: data.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.stockValue,
                          color: AppColors.primary,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        )
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart(List<CategorySales> data) {
    final colors = [
      AppColors.primary,
      AppColors.primary.withOpacity(0.8),
      AppColors.primary.withOpacity(0.6),
      AppColors.primary.withOpacity(0.4),
      AppColors.primary.withOpacity(0.2),
    ];
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ventes par catégorie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: data.asMap().entries.map((e) {
                          return PieChartSectionData(
                            color: colors[e.key % colors.length],
                            value: e.value.percentage,
                            title: '${e.value.percentage}%',
                            radius: 60,
                            titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.asMap().entries.map((e) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, color: colors[e.key % colors.length]),
                              SizedBox(width: 8),
                              Expanded(child: Text(e.value.categoryName, style: TextStyle(color: AppColors.textSecondary))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopClientsTable(List<TopClient> clients) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Clients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 300,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 40,
                  columns: [
                    DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                    DataColumn(label: Text('CA (TND)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                    DataColumn(label: Text('Commandes', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                  ],
                  rows: clients.map((c) {
                    return DataRow(cells: [
                      DataCell(Text(c.name, style: TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(c.revenue.toStringAsFixed(0))),
                      DataCell(Text(c.orders.toString())),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierPerformanceChart(List<SupplierPerformance> data) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Fournisseurs - Délais de livraison (Jours)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < data.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(data[value.toInt()].name, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  barGroups: data.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.deliveryDays,
                          color: AppColors.primary.withOpacity(0.8),
                          width: 30,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        )
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Text('Rapports :', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(width: AppSpacing.md),
            TextButton(onPressed: () {}, child: Text('Ventes')),
            TextButton(onPressed: () {}, child: Text('Stock')),
            TextButton(onPressed: () {}, child: Text('Clients')),
            TextButton(onPressed: () {}, child: Text('Fournisseurs')),
            Spacer(),
            ElevatedButton.icon(onPressed: () => _exportReport('PDF'), icon: Icon(Icons.picture_as_pdf_rounded, size: 18), label: Text('PDF'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error)),
            SizedBox(width: AppSpacing.sm),
            ElevatedButton.icon(onPressed: () => _exportReport('Excel'), icon: Icon(Icons.table_chart_rounded, size: 18), label: Text('Excel'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success)),
            SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(onPressed: () => _exportReport('Email'), icon: Icon(Icons.email_rounded, size: 18), label: Text('Email')),
          ],
        ),
      ),
    );
  }
}
