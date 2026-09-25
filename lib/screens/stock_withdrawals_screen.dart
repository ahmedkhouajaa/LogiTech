import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/stock_withdrawals/stock_withdrawals_bloc.dart';
import '../models/product.dart';
import '../services/sync_service.dart';
import '../widgets/pending_sync_badge.dart';


import '../models/stock_movement.dart';
import '../widgets/custom_date_range_picker.dart';
import '../blocs/products/products_bloc.dart';

import '../models/stock_withdrawal.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_stock_withdrawal_screen.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';
import 'document_detail_screen.dart';
import '../services/pdf_service.dart';
import '../mobile/screens/mobile_stock_withdrawal_detail_screen.dart';
import '../widgets/searchable_dropdown_field.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../utils/offline_action_helper.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_table_row.dart';
import '../l10n/app_localizations.dart';

enum StockWithdrawalStatus {
  draft('Brouillon'),
  validated('Validé'),
  cancelled('Annulé');

  final String label;
  const StockWithdrawalStatus(this.label);

  String localized(BuildContext context) => context.tr(label);

  Color get color {
    switch (this) {
      case draft: return AppColors.warning;
      case validated: return AppColors.success;
      case cancelled: return AppColors.error;
    }
  }
}

class StockWithdrawalsScreen extends StatefulWidget {
  final bool isExitVoucher;
  const StockWithdrawalsScreen({super.key, this.isExitVoucher = false});

  @override
  State<StockWithdrawalsScreen> createState() => _StockWithdrawalsScreenState();
}

class _StockWithdrawalsScreenState extends State<StockWithdrawalsScreen> {
  int _rowsPerPage = 20;
  int _currentPage = 0;
  
  String _searchQuery = '';
  String _filterReference = '';
  String? _filterWarehouseId;
  DateTimeRange? _filterDateRange;
  List<Warehouse> _warehouses = [];
  bool _showMobileFilters = false;

  StreamSubscription<int>? _syncSub;

  @override
  void initState() {
    super.initState();
    context.read<StockWithdrawalsBloc>().add(LoadStockWithdrawals());
    _loadWarehouses();

    _syncSub = SyncService.instance.onDocumentSyncCompleted.listen((count) {
      if (mounted && count > 0) {
        context.read<StockWithdrawalsBloc>().add(LoadStockWithdrawals());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('$count document(s) synchronisé(s) avec succès !'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    final bloc = context.read<WarehousesBloc>();
    if (bloc.state is WarehousesLoaded) {
      if (mounted) setState(() => _warehouses = (bloc.state as WarehousesLoaded).warehouses.cast<Warehouse>());
    }
    bloc.stream.listen((state) {
      if (state is WarehousesLoaded && mounted) {
        setState(() => _warehouses = state.warehouses.cast<Warehouse>());
      }
    });
  }

  String _getWarehouseName(String? id) {
    if (id == null || id.isEmpty || id == 'default_warehouse') return context.tr('Entrepôt par défaut');
    try {
      final name = _warehouses.firstWhere((w) => w.id == id).name;
      if (name.toLowerCase() == 'entrepôt par défaut' || name.toLowerCase() == 'entrepot par defaut') {
        return context.tr('Entrepôt par défaut');
      }
      return name;
    } catch (_) {
      return context.tr('Entrepôt par défaut');
    }
  }

  Product? _getProduct(String id) {
    final state = context.read<ProductsBloc>().state;
    if (state is ProductsLoaded) {
      try {
        return state.products.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    return null;
  }

  String _getProductName(String id) {
    return _getProduct(id)?.name ?? '';
  }

  void _navigate(BuildContext context, [StockWithdrawal? entry]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateStockWithdrawalScreen(existing: entry, isExitVoucher: widget.isExitVoucher),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StockWithdrawalsBloc, StockWithdrawalsState>(
      builder: (context, state) {
        List<StockWithdrawal> entries = [];
        if (state is StockWithdrawalsLoaded) {
          entries = state.withdrawals.where((e) {
            final matchesRef = _filterReference.isEmpty || e.number.toLowerCase().contains(_filterReference.toLowerCase());
            final matchesWarehouse = _filterWarehouseId == null || e.warehouseId == _filterWarehouseId || (e.warehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault));
            final matchesArticle = _searchQuery.isEmpty || e.items.any((item) => _getProductName(item.productId).toLowerCase().contains(_searchQuery.toLowerCase()));
            final matchesDate = _filterDateRange == null || (e.date.isAfter(_filterDateRange!.start.subtract(const Duration(days: 1))) && e.date.isBefore(_filterDateRange!.end.add(const Duration(days: 1))));
            return matchesRef && matchesWarehouse && matchesArticle && matchesDate;
          }).toList();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            return isMobile ? _buildMobileLayout(context, state, entries) : _buildDesktopLayout(context, state, entries);
          },
        );
      },
    );
  }

  // ─── Mobile Layout ─────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, StockWithdrawalsState state, List<StockWithdrawal> entries) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mobile header
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isExitVoucher ? context.tr("Bons de sortie") : context.tr("Bons de prélèvement"),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter toggle button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showMobileFilters = !_showMobileFilters),
                    icon: Icon(_showMobileFilters ? Icons.filter_list_off : Icons.filter_list, size: 18),
                    label: Text(_showMobileFilters ? context.tr('Masquer filtres') : context.tr('Filtres')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            
            // Collapsible filters
            AnimatedCrossFade(
              firstChild: SizedBox(height: 0, width: double.infinity),
              secondChild: Container(
                margin: EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: context.tr('Rechercher un article...'),
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                      ),
                      style: TextStyle(fontSize: 13),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  
                            initialValue: _filterWarehouseId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                            ),
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            items: [
                              DropdownMenuItem<String?>(value: null, child: Text(context.tr('Entrepôt'), style: const TextStyle(fontSize: 12))),
                              ..._warehouses.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text(w.name, style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _filterWarehouseId = v),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: context.tr('Référence'),
                              hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              prefixIcon: Icon(Icons.numbers, size: 16, color: AppColors.textSecondary),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                            ),
                            style: TextStyle(fontSize: 12),
                            onChanged: (v) => setState(() => _filterReference = v),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () async {
                          final range = await CustomDateRangePicker.show(
                            context,
                            initialRange: _filterDateRange,
                          );
                          if (range != null) setState(() => _filterDateRange = range);
                        },
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: AppColors.surface,
                          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _filterDateRange != null
                                    ? '${formatDate(_filterDateRange!.start)} - ${formatDate(_filterDateRange!.end)}'
                                    : context.tr('Toutes les dates'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _filterDateRange != null ? AppColors.textPrimary : AppColors.textTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_filterDateRange != null)
                              InkWell(
                                onTap: () => setState(() => _filterDateRange = null),
                                child: Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _showMobileFilters ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),

            // Active filters indicator + reset
            if (_filterWarehouseId != null || _searchQuery.isNotEmpty || _filterReference.isNotEmpty || _filterDateRange != null)
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 12),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${entries.length} ${entries.length > 1 ? context.tr('résultats') : context.tr('résultat')}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _filterWarehouseId = null;
                        _searchQuery = '';
                        _filterReference = '';
                        _filterDateRange = null;
                        _currentPage = 0;
                      }),
                      icon: Icon(Icons.clear_all, size: 16),
                      label: Text('Réinitialiser', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    ),
                  ],
                ),
              ),

            // Cards list
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state is StockWithdrawalsLoading) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (state is StockWithdrawalsError) {
            return AppErrorWidget(message: state.message);
          }
                  if (state is StockWithdrawalsLoaded) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                            SizedBox(height: 12),
                            Text(widget.isExitVoucher ? context.tr("Aucun bon de sortie") : context.tr("Aucun bon de prélèvement"), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                            SizedBox(height: 4),
                            Text(context.tr("Appuyez sur + pour en créer un"), style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 80),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _buildMobileCard(context, entries[index]);
                      },
                    );
                  }
                  return SizedBox();
                },
              ),
            ),
          ],
        ),
        // Floating Action Button
        if (PermissionService.instance.canCreate(UserPermissionResources.stockWithdrawalVouchers))
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () => _navigate(context),
              backgroundColor: AppColors.primary,
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  DocumentWrapper _createDocumentWrapper(StockWithdrawal entry) {
    final String resolvedWarehouse = _getWarehouseName(entry.warehouseId);
    final String? reason = (entry.conditionsGenerales != null && entry.conditionsGenerales!.trim().isNotEmpty)
        ? entry.conditionsGenerales!.trim()
        : ((entry.notes != null && entry.notes!.trim().isNotEmpty) ? entry.notes!.trim() : null);

    return DocumentWrapper(
      id: entry.id,
      number: entry.number,
      documentTitle: widget.isExitVoucher ? "BON DE SORTIE" : "BON DE PRÉLÈVEMENT",
      documentType: widget.isExitVoucher ? "exit_voucher" : "stock_withdrawal",
      customerName: widget.isExitVoucher ? (entry.customerCompany ?? entry.customerName) : null,
      customerId: widget.isExitVoucher ? entry.customerId : null,
      date: entry.date,
      totalHT: entry.totalHTAfterDiscount,
      totalTva: entry.totalTVA,
      stampTax: entry.timbreFiscal,
      totalTTC: entry.totalTTC,
      notes: entry.notes,
      conditionsGenerales: widget.isExitVoucher ? entry.conditionsGenerales : null,
      items: entry.items.map((item) {
        final product = _getProduct(item.productId);
        final refCode = (product?.reference != null && product!.reference!.trim().isNotEmpty)
            ? product.reference!.trim()
            : (product?.code ?? '');
        return DocumentItemWrapper(
          productId: item.productId,
          reference: refCode,
          productName: product?.name ?? context.tr('Article Inconnu'),
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          discountPercent: item.discountPercent,
          totalHT: item.totalHT,
          customFields: {
            'code': refCode,
            'unit': product?.unit ?? 'pièce',
            'purchasePrice': product?.purchasePrice ?? 0,
          },
        );
      }).toList(),
      customFields: entry.customFields,
      customData: {
        'warehouseId': entry.warehouseId,
        'warehouseName': resolvedWarehouse,
        'reason': reason,
        'createdBy': entry.createdBy ?? 'Admin',
        'status': entry.status,
        'projectName': entry.projectName,
        'driverName': entry.driverName,
        'vehicleRegistration': entry.vehicleRegistration,
        'customFields': entry.customFields,
      },
    );
  }

  void _previewDocument(StockWithdrawal entry) {
    final wrapper = _createDocumentWrapper(entry);

    final StockWithdrawalStatus entryStatus;
    switch (entry.status) {
      case 'validated':
        entryStatus = StockWithdrawalStatus.validated;
        break;
      case 'cancelled':
        entryStatus = StockWithdrawalStatus.cancelled;
        break;
      default:
        entryStatus = StockWithdrawalStatus.draft;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          document: wrapper,
          status: entryStatus.label,
          statusColor: entryStatus.color,
        ),
      ),
    );
  }

  Widget _buildArticlesDisplay(List<StockWithdrawalItem> items) {
    if (items.isEmpty) return Text('0 article', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
    
    final summaryText = items.map((item) {
      final pName = item.description ?? 'Produit Inconnu';
      return '${item.quantity.toInt()}x $pName';
    }).join(', ');

    return Tooltip(
      message: summaryText,
      preferBelow: false,
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 20),
      showDuration: Duration(seconds: 3),
      decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
      child: Text('${items.length} article${items.length > 1 ? 's' : ''}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }

  Widget _buildMobileCard(BuildContext context, StockWithdrawal entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: context.read<StockWithdrawalsBloc>()),
                    BlocProvider.value(value: context.read<ProductsBloc>()),
                  ],
                  child: MobileStockWithdrawalDetailScreen(
                    withdrawal: entry,
                    isExitVoucher: widget.isExitVoucher,
                  ),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Ref Badge + Status Chip + Actions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.number,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(entry.status),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Row 1: Date & Time
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      formatDateTimeLong(entry.date),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 2: Warehouse + Article Count on the right
                Row(
                  children: [
                    Icon(Icons.store_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _getWarehouseName(entry.warehouseId),
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.items.length} ${entry.items.length > 1 ? context.tr('articles') : context.tr('article')}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (entry.createdBy != null && entry.createdBy!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        entry.createdBy!,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final StockWithdrawalStatus entryStatus;
    switch (status) {
      case 'validated':
        entryStatus = StockWithdrawalStatus.validated;
        break;
      case 'cancelled':
        entryStatus = StockWithdrawalStatus.cancelled;
        break;
      default:
        entryStatus = StockWithdrawalStatus.draft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: entryStatus.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: entryStatus.color.withValues(alpha: 0.2)),
      ),
      child: Text(
        entryStatus.localized(context),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: entryStatus.color,
        ),
      ),
    );
  }

  // ─── Desktop Layout ────────────────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context, StockWithdrawalsState state, List<StockWithdrawal> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isExitVoucher ? context.tr("Bons de sortie") : context.tr("Bons de prélèvement"),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(widget.isExitVoucher ? context.tr("Gérer vos bons de sortie de stock") : context.tr("Gérer vos bons de prélèvement de stock"), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              if (PermissionService.instance.canCreate(UserPermissionResources.stockWithdrawalVouchers))
                ElevatedButton.icon(
                  onPressed: () => _navigate(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.tr('Créer')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Filters Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Warehouse
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.tr('Entrepôt'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: Builder(
                          builder: (context) {
                            final selectedWh = _warehouses.cast<Warehouse?>().firstWhere(
                              (w) => w?.id == _filterWarehouseId,
                              orElse: () => null,
                            );
                            final isSelected = _filterWarehouseId != null;
                            return InkWell(
                              onTap: () async {
                                final res = await showWarehouseSelectDialog(
                                  context,
                                  _warehouses,
                                  selectedWarehouseId: _filterWarehouseId,
                                  includeAll: true,
                                );
                                if (res != null) {
                                  setState(() => _filterWarehouseId = (res == '__all__' ? null : res));
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isSelected
                                            ? (selectedWh?.name ?? context.tr('Tous les Entrepôts'))
                                            : context.tr('Tous les Entrepôts'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                
                // Article
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.tr('Article'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: context.tr('Rechercher un produit...'),
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: (v) => setState(() {
                            _searchQuery = v;
                            _currentPage = 0;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Date range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.tr('Date'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: InkWell(
                          onTap: () async {
                            final range = await CustomDateRangePicker.show(
                              context,
                              initialRange: _filterDateRange,
                            );
                            if (range != null) {
                              setState(() => _filterDateRange = range);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _filterDateRange != null
                                        ? '${formatDate(_filterDateRange!.start)} - ${formatDate(_filterDateRange!.end)}'
                                        : context.tr('Toutes les dates'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _filterDateRange != null ? AppColors.textPrimary : AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_filterDateRange != null)
                                  InkWell(
                                    onTap: () => setState(() => _filterDateRange = null),
                                    child: Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_filterWarehouseId != null || _searchQuery.isNotEmpty || _filterReference.isNotEmpty || _filterDateRange != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: IconButton(
                      onPressed: () => setState(() {
                        _filterWarehouseId = null;
                        _searchQuery = '';
                        _filterReference = '';
                        _filterDateRange = null;
                        _currentPage = 0;
                      }),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: context.tr('Réinitialiser les filtres'),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.error,
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // List
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Builder(
                builder: (context) {
                  if (state is StockWithdrawalsLoading || state is StockWithdrawalsInitial) {
                    return ShimmerTable(
                      headerColumns: [
                        Expanded(flex: 2, child: Text(context.tr('Référence'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text(context.tr('Date'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text(context.tr('Entrepôt'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text(context.tr('Articles'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text(context.tr('Créé par'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        SizedBox(width: 60, child: Text(context.tr('Actions'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      ],
                    );
                  }
                  if (state is StockWithdrawalsError) {
                    return AppErrorWidget(message: state.message);
                  }
                  if (state is StockWithdrawalsLoaded) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Text(widget.isExitVoucher ? context.tr("Aucun bon de sortie trouvé") : context.tr("Aucun bon de prélèvement trouvé"), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      );
                    }

                    final totalItems = entries.length;
                    final totalPages = (totalItems / _rowsPerPage).ceil() == 0 ? 1 : (totalItems / _rowsPerPage).ceil();
                    final startIndex = _currentPage * _rowsPerPage;
                    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                    final currentPageItems = entries.sublist(startIndex, endIndex);

                    return Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(context.tr('Référence'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text(context.tr('Date'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text(context.tr('Entrepôt'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text(context.tr('Articles'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text(context.tr('Créé par'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              SizedBox(width: 60, child: Text(context.tr('Actions'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                        
                        // Table body
                        Expanded(
                          child: ListView.separated(
                            itemCount: currentPageItems.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              return _buildRow(context, currentPageItems[index], index);
                            },
                          ),
                        ),

                        // Pagination
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Text(context.tr('Lignes'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: const SizedBox(),
                                  icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                                  items: [20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v', style: const TextStyle(fontSize: 12)))).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _rowsPerPage = v;
                                        _currentPage = 0;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 20),
                              Text('${context.tr('Page')} ${_currentPage + 1} ${context.tr('sur')} $totalPages', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                totalItems == 0 ? '${context.tr('Affichage de')} 0 ${context.tr('sur')} 0 ${context.tr('résultats')}' : '${context.tr('Affichage de')} ${startIndex + 1} à $endIndex ${context.tr('sur')} $totalItems ${context.tr('résultats')}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_left, size: 18, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage < totalPages - 1 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_right, size: 18, color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildRow(BuildContext context, StockWithdrawal entry, int index) {
    return Material(
      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => _previewDocument(entry),
        hoverColor: AppColors.primary.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(entry.number, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (!entry.isSynced || entry.number.startsWith('BROUILLON-')) ...[
                  const SizedBox(width: 6),
                  const PendingSyncBadge(),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(formatDateTimeLong(entry.date), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(_getWarehouseName(entry.warehouseId), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 1,
            child: _buildArticlesDisplay(entry.items),
          ),
          Expanded(
            flex: 2,
            child: Text('Admin', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, size: 18, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) {
                  OfflineActionHelper.executeAction(
                    context: context,
                    action: val,
                    onConfirmed: () {
                      if (val == 'voir') _previewDocument(entry);
                      if (val == 'print') {
                        final doc = _createDocumentWrapper(entry);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
                      }
                      if (val == 'pdf') {
                        final doc = _createDocumentWrapper(entry);
                        PdfService.instance.downloadDocument(context, doc);
                      }
                      if (val == 'edit') _navigate(context, entry);
                      if (val == 'delete') context.read<StockWithdrawalsBloc>().add(DeleteStockWithdrawal(entry.id));
                    },
                  );
                },
                itemBuilder: (_) {
                  final canRead = PermissionService.instance.canRead(UserPermissionResources.stockWithdrawalVouchers);
                  final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.stockWithdrawalVouchers);
                  final canDelete = PermissionService.instance.canDelete(UserPermissionResources.stockWithdrawalVouchers);

                  final entries = <PopupMenuEntry<String>>[];

                  if (canRead) {
                    entries.add(
                      PopupMenuItem(
                        value: 'voir',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(context.tr('Voir')),
                          ],
                        ),
                      ),
                    );
                    entries.add(
                      PopupMenuItem(
                        value: 'print',
                        child: Row(
                          children: [
                            Icon(Icons.print_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(context.tr('Imprimer')),
                          ],
                        ),
                      ),
                    );
                    entries.add(
                      PopupMenuItem(
                        value: 'pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text(context.tr('Télécharger PDF')),
                          ],
                        ),
                      ),
                    );
                  }
                  if (canUpdate) {
                    if (entries.isNotEmpty) entries.add(const PopupMenuDivider(height: 1));
                    entries.add(
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(context.tr('Modifier')),
                          ],
                        ),
                      ),
                    );
                  }
                  if (canDelete) {
                    if (entries.isNotEmpty) entries.add(const PopupMenuDivider(height: 1));
                    entries.add(
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text(context.tr('Supprimer'), style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    );
                  }
                  return entries;
                },
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
}
}

