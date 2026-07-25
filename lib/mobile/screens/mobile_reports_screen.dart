import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/constants.dart';
import '../../blocs/reports/reports_bloc.dart';
import '../../models/report_data.dart';

class MobileReportsScreen extends StatefulWidget {
  const MobileReportsScreen({super.key});

  @override
  State<MobileReportsScreen> createState() => _MobileReportsScreenState();
}

class _MobileReportsScreenState extends State<MobileReportsScreen> {
  String _selectedDateRange = 'Cette Année';
  String _selectedWarehouse = 'Tous les entrepôts';
  String _selectedCategory = 'Toutes les catégories';
  bool _filtersExpanded = false;

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
    setState(() {
      _filtersExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => _buildExportBottomSheet(),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
          );
        },
        icon: Icon(Icons.download_rounded, color: Colors.white),
        label: Text('Exporter', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (context, state) {
          if (state is ReportsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ReportsError) {
            return Center(child: Text('Erreur: ${state.message}', style: TextStyle(color: AppColors.error)));
          } else if (state is ReportsLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                _applyFilters();
              },
              child: _buildContent(state),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(ReportsLoaded state) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80.0), // Padding for FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCollapsibleFilters(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildKPIsGrid(state),
                const SizedBox(height: AppSpacing.lg),
                _buildMonthlySalesChart(state.monthlySales),
                const SizedBox(height: AppSpacing.lg),
                _buildWarehouseStockChart(state.warehouseStock),
                const SizedBox(height: AppSpacing.lg),
                _buildCategoryPieChart(state.categorySales),
                const SizedBox(height: AppSpacing.lg),
                _buildTopClientsTable(state.topClients),
                const SizedBox(height: AppSpacing.lg),
                _buildSupplierPerformanceChart(state.supplierPerformance),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleFilters() {
    return Container(
      color: AppColors.surface,
      child: ExpansionTile(
        initiallyExpanded: _filtersExpanded,
        onExpansionChanged: (val) => setState(() => _filtersExpanded = val),
        title: Row(
          children: [
            Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: AppSpacing.sm),
            Text('Filtres', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Text('$_selectedDateRange • ${_selectedWarehouse.split(' ').last}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDropdown(
                  value: _selectedDateRange,
                  items: ['Ce Mois', 'Ce Trimestre', 'Cette Année', 'Personnalisé'],
                  onChanged: (val) => setState(() => _selectedDateRange = val!),
                  icon: Icons.calendar_today_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildDropdown(
                  value: _selectedWarehouse,
                  items: ['Tous les entrepôts', 'Entrepôt A', 'Entrepôt B', 'Entrepôt C'],
                  onChanged: (val) => setState(() => _selectedWarehouse = val!),
                  icon: Icons.warehouse_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildDropdown(
                  value: _selectedCategory,
                  items: ['Toutes les catégories', 'Électronique', 'Mobilier', 'Vêtements'],
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                  icon: Icons.category_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: _applyFilters,
                  child: const Text('Appliquer les filtres'),
                ),
              ],
            ),
          )
        ],
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(e, overflow: TextOverflow.ellipsis)),
            ],
          ))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildKPIsGrid(ReportsLoaded state) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        _buildKPICard('Rotation', '${state.turnoverRate}x', Icons.sync_rounded, AppColors.info),
        _buildKPICard('Remplissage', '${state.fulfillmentRate}%', Icons.inventory_2_rounded, AppColors.success),
        _buildKPICard('Délai moyen', '${state.avgDeliveryTime}j', Icons.timer_rounded, AppColors.warning),
        _buildKPICard('Rupture', '${state.stockoutRate}%', Icons.warning_rounded, AppColors.error),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            Spacer(),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySalesChart(List<MonthlySales> data) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Évolution des ventes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2, // Show every other month on mobile
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < data.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(data[value.toInt()].month, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                            );
                          }
                          return const Text('');
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
                      barWidth: 2,
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock par entrepôt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
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
                              child: Text(data[value.toInt()].warehouseName.split(' ').last, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                            );
                          }
                          return const Text('');
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
                          color: AppColors.accent,
                          width: 14,
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
    final colors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.error, AppColors.info];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ventes par catégorie', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: data.asMap().entries.map((e) {
                          return PieChartSectionData(
                            color: colors[e.key % colors.length],
                            value: e.value.percentage,
                            title: '${e.value.percentage.toInt()}%',
                            radius: 40,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
                          padding: EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, color: colors[e.key % colors.length]),
                              SizedBox(width: 4),
                              Expanded(child: Text(e.value.categoryName, style: TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Clients', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 250,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 40,
                    columns: [
                      DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12))),
                      DataColumn(label: Text('CA (TND)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12))),
                      DataColumn(label: Text('Cmds', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12))),
                    ],
                    rows: clients.take(5).map((c) { // Take 5 on mobile to save space
                      return DataRow(cells: [
                        DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                        DataCell(Text(c.revenue.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(c.orders.toString(), style: const TextStyle(fontSize: 12))),
                      ]);
                    }).toList(),
                  ),
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Fournisseurs (Délais)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
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
                              child: Text(data[value.toInt()].name.replaceAll('Fournisseur', 'F.'), style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                            );
                          }
                          return const Text('');
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
                          color: AppColors.success,
                          width: 14,
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

  Widget _buildExportBottomSheet() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Exporter le rapport', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center),
          SizedBox(height: AppSpacing.lg),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
            title: const Text('Export PDF'),
            onTap: () {
              Navigator.pop(context);
              _exportReport('PDF');
            },
          ),
          ListTile(
            leading: Icon(Icons.table_chart_rounded, color: AppColors.success),
            title: const Text('Export Excel'),
            onTap: () {
              Navigator.pop(context);
              _exportReport('Excel');
            },
          ),
          ListTile(
            leading: Icon(Icons.email_rounded, color: AppColors.primary),
            title: const Text('Envoyer par Email'),
            onTap: () {
              Navigator.pop(context);
              _exportReport('Email');
            },
          ),
          SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
