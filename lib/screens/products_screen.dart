import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:excel/excel.dart' hide Border;
import '../utils/file_download_helper.dart';
import '../blocs/products/products_bloc.dart';
import '../models/product.dart';
import '../blocs/stock/stock_bloc.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import 'create_article_screen.dart';
import 'article_detail_screen.dart';
import '../utils/offline_action_helper.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_effect.dart';
import '../services/article_import_export_service.dart';
import '../widgets/import_export/article_import_dialog.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final Set<String> _selectedProductIds = {};
  String _search = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<ProductsBloc>().add(const LoadFirstProducts(pageSize: 10));
    context.read<StockBloc>().add(LoadStock());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      final state = context.read<ProductsBloc>().state;
      if (state is ProductsLoaded && state.hasMore && !state.isLoadingMore) {
        context.read<ProductsBloc>().add(
          const LoadNextProducts(pageSize: 10),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Action Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              BlocBuilder<ProductsBloc, ProductsState>(
                buildWhen: (prev, curr) => curr is ProductsLoaded || curr is ProductsLoading || curr is ProductsInitial,
                builder: (context, state) {
                  final totalCount = state is ProductsLoaded
                      ? (state.totalCount > state.products.length ? state.totalCount : state.products.length)
                      : null;
                  final matchingCount = (state is ProductsLoaded && _search.isNotEmpty)
                      ? state.products.where((p) =>
                          p.name.toLowerCase().contains(_search) ||
                          p.code.toLowerCase().contains(_search) ||
                          (p.reference?.toLowerCase().contains(_search) ?? false)).length
                      : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Articles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          if (totalCount != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                matchingCount != null ? '$matchingCount / $totalCount' : '$totalCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalCount != null
                            ? (matchingCount != null
                                ? '$matchingCount article${matchingCount > 1 ? 's' : ''} trouvé${matchingCount > 1 ? 's' : ''} sur $totalCount au total'
                                : '$totalCount article${totalCount > 1 ? 's' : ''} au total')
                            : 'Gérer vos articles',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              if (_selectedProductIds.isNotEmpty) ...[
                _buildBulkActionsDropdown(),
                const SizedBox(width: 10),
              ],
              SizedBox(
                width: 250,
                height: 32,
                child: AppSearchBar(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              // ... Actions Button Popup
              PopupMenuButton<String>(
                tooltip: 'Actions Import / Export Articles',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                color: AppColors.surface,
                elevation: 4,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Actions',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (ctx) {
                  final canExport = PermissionService.instance.canCreate(UserPermissionResources.importExport);
                  final canImport = PermissionService.instance.canUpdate(UserPermissionResources.importExport);
                  final items = <PopupMenuEntry<String>>[];
                  if (canExport) {
                    items.addAll([
                      const PopupMenuItem(
                        value: 'export_excel',
                        child: Text('Exporter Excel', style: TextStyle(fontSize: 13)),
                      ),
                      const PopupMenuItem(
                        value: 'export_csv',
                        child: Text('Exporter CSV', style: TextStyle(fontSize: 13)),
                      ),
                      const PopupMenuItem(
                        value: 'export_json',
                        child: Text('Exporter JSON', style: TextStyle(fontSize: 13)),
                      ),
                    ]);
                  }
                  if (canExport && canImport) {
                    items.add(const PopupMenuDivider());
                  }
                  if (canImport) {
                    items.add(
                      const PopupMenuItem(
                        value: 'import_excel',
                        child: Text(
                          'Importer depuis Excel',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    );
                  }
                  return items;
                },
                onSelected: (val) async {
                  final state = context.read<ProductsBloc>().state;
                  final products = state is ProductsLoaded ? state.products : <Product>[];

                  if (val == 'export_excel') {
                    if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
                    await ArticleImportExportService.instance.exportArticlesToExcel(
                      context: context,
                      products: products,
                    );
                  } else if (val == 'export_csv') {
                    if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
                    await ArticleImportExportService.instance.exportArticlesToCsv(
                      context: context,
                      products: products,
                    );
                  } else if (val == 'export_json') {
                    if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
                    await ArticleImportExportService.instance.exportArticlesToJson(
                      context: context,
                      products: products,
                    );
                  } else if (val == 'import_excel') {
                    if (!PermissionService.instance.canUpdate(UserPermissionResources.importExport)) return;
                    ArticleImportDialog.show(
                      context,
                      onImportSuccess: () {
                        context.read<ProductsBloc>().add(const LoadFirstProducts(pageSize: 10));
                        context.read<StockBloc>().add(LoadStock());
                      },
                    );
                  }
                },
              ),
              if (PermissionService.instance.canCreate(UserPermissionResources.productsList)) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _navigateToCreate(context, null),
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: const Text('Nouvel Article', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        
        // Data List
        Expanded(
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
                  if (state is ProductsLoading || state is ProductsInitial) {
                    return AppShimmer(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
                        itemCount: 10,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, index) => Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: Checkbox(
                                  value: false,
                                  onChanged: null,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  side: BorderSide(color: AppColors.border, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ShimmerBox(width: 36, height: 36, borderRadius: 10),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    ShimmerBox(width: 160, height: 12, borderRadius: 4),
                                    SizedBox(height: 6),
                                    ShimmerBox(width: 110, height: 10, borderRadius: 4),
                                  ],
                                ),
                              ),
                              ShimmerBox(width: 70, height: 20, borderRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  if (state is ProductsError) return AppErrorWidget(message: state.message);
                  if (state is ProductsLoaded) {
                final filtered = _search.isEmpty ? state.products
                    : state.products.where((p) => 
                        p.name.toLowerCase().contains(_search) || 
                        p.code.toLowerCase().contains(_search) || 
                        (p.reference?.toLowerCase().contains(_search) ?? false)
                      ).toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Aucun article trouvé', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                final hasMore = state.hasMore;
                final isLoadingMore = state.isLoadingMore;
                final hasFooter = hasMore || isLoadingMore;

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 20),
                  itemCount: filtered.length + (hasFooter ? 1 : 0),
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: isLoadingMore
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : OutlinedButton.icon(
                                  onPressed: () {
                                    context.read<ProductsBloc>().add(
                                      const LoadNextProducts(pageSize: 10),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide(color: AppColors.border),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                                  label: Text(
                                    'Charger plus d\'articles (${state.products.length} affichés sur ${state.totalCount})',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                        ),
                      );
                    }

                    final p = filtered[index];
                    final tvaMultiplier = 1 + (p.tvaRate / 100);
                    final sellTtc = p.sellingPrice * tvaMultiplier;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => _navigateToDetail(context, p),
                          hoverColor: AppColors.primary.withValues(alpha: 0.02),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Checkbox(
                                    value: _selectedProductIds.contains(p.id),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedProductIds.add(p.id);
                                        } else {
                                          _selectedProductIds.remove(p.id);
                                        }
                                      });
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Icon
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.inventory_2_rounded, color: AppColors.textSecondary, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Info
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            p.name,
                                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              p.productType.capitalize(),
                                              style: TextStyle(fontSize: 9.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.tag_rounded, size: 12, color: AppColors.textTertiary),
                                          const SizedBox(width: 3),
                                          Text(p.code, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                          if (p.reference != null && p.reference!.isNotEmpty) ...[
                                            const SizedBox(width: 10),
                                            Icon(Icons.qr_code_2_rounded, size: 12, color: AppColors.textTertiary),
                                            const SizedBox(width: 3),
                                            Text(p.reference!, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                          ],
                                          const SizedBox(width: 10),
                                          Icon(Icons.straighten_rounded, size: 12, color: AppColors.textTertiary),
                                          const SizedBox(width: 3),
                                          Text(p.unit, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Prix Achat
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Prix Achat (HT)', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceAlt,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text(
                                          formatCurrency(p.purchasePrice),
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Prix Vente
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Prix Vente (TTC)', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successLight.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          formatCurrency(sellTtc),
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Actions
                                const SizedBox(width: 12),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textTertiary),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 4,
                                  onSelected: (val) {
                                    OfflineActionHelper.executeAction(
                                      context: context,
                                      action: val,
                                      onConfirmed: () {
                                        if (val == 'view') _navigateToDetail(context, p);
                                        if (val == 'edit') _navigateToCreate(context, p);
                                        if (val == 'delete') context.read<ProductsBloc>().add(DeleteProduct(p.id));
                                      },
                                    );
                                  },
                                  itemBuilder: (context) {
                                    final canRead = PermissionService.instance.canRead(UserPermissionResources.productsList);
                                    final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.productsList);
                                    final canDelete = PermissionService.instance.canDelete(UserPermissionResources.productsList);

                                    final entries = <PopupMenuEntry<String>>[];

                                    if (canRead) {
                                      entries.add(
                                        PopupMenuItem(
                                          value: 'view',
                                          height: 36,
                                          child: Row(
                                            children: [
                                              Icon(Icons.visibility_outlined, size: 16, color: AppColors.info),
                                              const SizedBox(width: 8),
                                              const Text('Voir', style: TextStyle(fontSize: 13)),
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
                                          height: 36,
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              const Text('Modifier', style: TextStyle(fontSize: 13)),
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
                                          height: 36,
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                              const SizedBox(width: 8),
                                              Text('Supprimer', style: TextStyle(color: AppColors.error, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return entries;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }

  void _navigateToDetail(BuildContext context, Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProductsBloc>(),
          child: ArticleDetailScreen(product: product),
        ),
      ),
    );
  }

  void _navigateToCreate(BuildContext context, Product? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProductsBloc>(),
          child: CreateArticleScreen(existing: existing),
        ),
      ),
    );
  }

  // ── Bulk Actions ──────────────────────────────────────────────────
  Widget _buildBulkActionsDropdown() {
    return PopupMenuButton<String>(
      onSelected: (action) => _handleBulkAction(action),
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'excel',
          child: Text('Exporter Excel', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text('Supprimer la sélection', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Plus d\'actions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _handleBulkAction(String action) {
    final state = context.read<ProductsBloc>().state;
    if (state is! ProductsLoaded) return;

    final selectedProducts = state.products.where((p) => _selectedProductIds.contains(p.id)).toList();
    if (selectedProducts.isEmpty) return;

    switch (action) {
      case 'excel':
        _bulkExportExcel(selectedProducts);
        break;
      case 'delete':
        _bulkDeleteSelected(selectedProducts);
        break;
    }
  }

  Future<void> _bulkExportExcel(List<Product> selectedProducts) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Articles'];
      excel.setDefaultSheet('Articles');

      final headers = ['Code', 'Désignation', 'Catégorie', 'Prix Achat (HT)', 'Prix Vente (HT)', 'Taux TVA (%)', 'Prix Vente (TTC)', 'Stock'];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true, fontFamily: getFontFamily(FontFamily.Arial));
      }

      for (var i = 0; i < selectedProducts.length; i++) {
        final p = selectedProducts[i];
        final rowIndex = i + 1;
        final tvaMultiplier = 1 + (p.tvaRate / 100);
        final sellTtc = p.sellingPrice * tvaMultiplier;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(p.code);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(p.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(p.category ?? '—');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(p.purchasePrice);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(p.sellingPrice);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(p.tvaRate);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(sellTtc);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(p.stockQty);
      }

      final fileBytes = excel.encode();
      if (fileBytes != null && mounted) {
        final fileName = 'Articles_Selectionnes_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await FileDownloadHelper.saveAndOpenFile(
          Uint8List.fromList(fileBytes),
          fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          context: context,
        );
        setState(() => _selectedProductIds.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export Excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _bulkDeleteSelected(List<Product> selectedProducts) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Suppression groupée'),
          ],
        ),
        content: Text('Voulez-vous vraiment supprimer ${selectedProducts.length} article(s) sélectionné(s) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final idsToDelete = selectedProducts.map((p) => p.id).toList();
              context.read<ProductsBloc>().add(BulkDeleteProducts(idsToDelete));
              setState(() => _selectedProductIds.clear());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${selectedProducts.length} article(s) supprimé(s)'),
                backgroundColor: AppColors.success,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
