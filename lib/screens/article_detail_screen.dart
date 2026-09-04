import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/product.dart';
import '../blocs/products/products_bloc.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/details/detail_components.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'create_article_screen.dart';
import '../mobile/screens/forms/mobile_product_form_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Product product;

  const ArticleDetailScreen({super.key, required this.product});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Product currentProduct;

  @override
  void initState() {
    super.initState();
    currentProduct = widget.product;
  }

  void _navigateToEdit() {
    final isMobile = AppBreakpoints.isMobile(context);

    if (isMobile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<ProductsBloc>(),
            child: MobileProductFormScreen(existing: currentProduct),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<ProductsBloc>(),
            child: CreateArticleScreen(existing: currentProduct),
          ),
        ),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Supprimer l\'article'),
          ],
        ),
        content: Text('Voulez-vous vraiment supprimer l\'article "${currentProduct.name}" (${currentProduct.code}) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<ProductsBloc>().add(DeleteProduct(currentProduct.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Article "${currentProduct.name}" supprimé'),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.productsList);
    final canDelete = PermissionService.instance.canDelete(UserPermissionResources.productsList);

    // Pricing calculations
    final tvaMultiplier = 1 + (currentProduct.tvaRate / 100);
    final sellTtc = currentProduct.sellingPrice * tvaMultiplier;
    final tvaAmount = currentProduct.sellingPrice * (currentProduct.tvaRate / 100);
    final marginAmount = currentProduct.sellingPrice - currentProduct.purchasePrice;
    final marginPercent = currentProduct.purchasePrice > 0
        ? ((currentProduct.sellingPrice - currentProduct.purchasePrice) / currentProduct.purchasePrice) * 100
        : 0.0;

    // Stock Status
    Color stockColor = AppColors.success;
    String stockLabel = 'En stock (${currentProduct.stockQty.toStringAsFixed(0)} ${currentProduct.unit})';
    IconData stockIcon = Icons.check_circle_outline_rounded;

    if (currentProduct.stockQty <= 0) {
      stockColor = AppColors.error;
      stockLabel = 'Rupture de stock (0 ${currentProduct.unit})';
      stockIcon = Icons.error_outline_rounded;
    } else if (currentProduct.isLowStock || currentProduct.stockQty <= currentProduct.lowStockThreshold) {
      stockColor = AppColors.warning;
      stockLabel = 'Stock faible (${currentProduct.stockQty.toStringAsFixed(0)} ${currentProduct.unit})';
      stockIcon = Icons.warning_amber_rounded;
    }

    // Type Color & Icon
    IconData typeIcon = Icons.inventory_2_rounded;
    Color typeColor = AppColors.primary;
    if (currentProduct.productType == 'service') {
      typeIcon = Icons.design_services_rounded;
      typeColor = const Color(0xFF8B5CF6);
    } else if (currentProduct.productType == 'consommable') {
      typeIcon = Icons.handyman_rounded;
      typeColor = const Color(0xFFF59E0B);
    }

    return BlocListener<ProductsBloc, ProductsState>(
      listener: (context, state) {
        if (state is ProductsLoaded) {
          final updated = state.products.where((p) => p.id == currentProduct.id).firstOrNull;
          if (updated != null) {
            setState(() => currentProduct = updated);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: currentProduct.name,
          subtitle: 'Article ${currentProduct.code}',
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            tooltip: 'Retour',
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (canUpdate)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton.icon(
                  onPressed: _navigateToEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
            if (canDelete)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                tooltip: 'Supprimer',
                onPressed: _confirmDelete,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 16 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Header ─────────────────────────────────────
                  DetailHeroHeader(
                    icon: typeIcon,
                    iconColor: typeColor,
                    iconBackgroundColor: typeColor.withValues(alpha: 0.12),
                    title: currentProduct.name,
                    subtitle: currentProduct.description?.isNotEmpty == true
                        ? currentProduct.description
                        : 'Article ${currentProduct.code}',
                    badges: [
                      buildDetailBadge(
                        label: currentProduct.code,
                        color: AppColors.primary,
                        icon: Icons.tag_rounded,
                        onTap: () => copyToClipboard(context, label: 'Code article', text: currentProduct.code),
                      ),
                      if (currentProduct.reference != null && currentProduct.reference!.trim().isNotEmpty)
                        buildDetailBadge(
                          label: 'Réf: ${currentProduct.reference}',
                          color: AppColors.textSecondary,
                          icon: Icons.qr_code_2_rounded,
                        ),
                      buildDetailBadge(
                        label: currentProduct.productType.toUpperCase(),
                        color: typeColor,
                        icon: typeIcon,
                      ),
                      buildDetailBadge(
                        label: stockLabel,
                        color: stockColor,
                        icon: stockIcon,
                      ),
                      buildDetailBadge(
                        label: currentProduct.isActive ? 'Actif' : 'Inactif',
                        color: currentProduct.isActive ? AppColors.success : AppColors.textTertiary,
                        icon: currentProduct.isActive ? Icons.check_circle_rounded : Icons.cancel_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── KPI Summary Row ─────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount = width > 850 ? 5 : (width > 550 ? 3 : 2);
                      double itemWidth = (width - ((crossAxisCount - 1) * 12)) / crossAxisCount;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: DetailKpiCard(
                              label: 'Prix Achat (HT)',
                              value: formatCurrency(currentProduct.purchasePrice),
                              icon: Icons.shopping_bag_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: DetailKpiCard(
                              label: 'Prix Vente (HT)',
                              value: formatCurrency(currentProduct.sellingPrice),
                              icon: Icons.sell_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: DetailKpiCard(
                              label: 'TVA',
                              value: '${currentProduct.tvaRate.toStringAsFixed(currentProduct.tvaRate.truncateToDouble() == currentProduct.tvaRate ? 0 : 2)}%',
                              subtitle: formatCurrency(tvaAmount),
                              icon: Icons.percent_rounded,
                              color: AppColors.info,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: DetailKpiCard(
                              label: 'Prix Vente (TTC)',
                              value: formatCurrency(sellTtc),
                              icon: Icons.payments_outlined,
                              color: AppColors.success,
                              isHighlight: true,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: DetailKpiCard(
                              label: 'Marge Commerciale',
                              value: formatCurrency(marginAmount),
                              subtitle: '${marginPercent.toStringAsFixed(1)}%',
                              icon: Icons.trending_up_rounded,
                              color: marginAmount >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Detail Sections ─────────────────────────────────
                  // Section 1: Tarification & Rentabilité
                  DetailSectionCard(
                    title: 'Tarification & Rentabilité',
                    icon: Icons.monetization_on_outlined,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = isWide ? 4 : 2;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Prix d\'achat unitaire HT',
                                value: formatCurrency(currentProduct.purchasePrice),
                                icon: Icons.shopping_bag_outlined,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Prix de vente unitaire HT',
                                value: formatCurrency(currentProduct.sellingPrice),
                                icon: Icons.sell_outlined,
                                valueFontWeight: FontWeight.bold,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Taux de TVA',
                                value: '${currentProduct.tvaRate}%',
                                icon: Icons.percent_rounded,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Montant de TVA unitaire',
                                value: formatCurrency(tvaAmount),
                                icon: Icons.receipt_outlined,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Prix de vente unitaire TTC',
                                value: formatCurrency(sellTtc),
                                icon: Icons.price_check_rounded,
                                valueColor: AppColors.success,
                                valueFontWeight: FontWeight.bold,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Marge bénéficiaire (DT)',
                                value: formatCurrency(marginAmount),
                                icon: Icons.show_chart_rounded,
                                valueColor: marginAmount >= 0 ? AppColors.success : AppColors.error,
                                valueFontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Taux de marge (%)',
                                value: '${marginPercent.toStringAsFixed(2)} %',
                                icon: Icons.trending_up_rounded,
                                valueColor: marginAmount >= 0 ? AppColors.success : AppColors.error,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Remise usuelle accordée',
                                value: '${currentProduct.usualDiscount}%',
                                icon: Icons.discount_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Gestion du Stock & Entrepôt
                  DetailSectionCard(
                    title: 'Gestion des Stocks & Entrepôt',
                    icon: Icons.inventory_rounded,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = isWide ? 3 : 2;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Stock physique actuel',
                                value: '${currentProduct.stockQty.toStringAsFixed(0)} ${currentProduct.unit}',
                                icon: Icons.inventory_2_outlined,
                                valueColor: stockColor,
                                valueFontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Stock minimum de sécurité',
                                value: '${currentProduct.minStockQty.toStringAsFixed(0)} ${currentProduct.unit}',
                                icon: Icons.shield_outlined,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Alerte stock faible',
                                value: currentProduct.lowStockAlert
                                    ? 'Activée (Seuil: ${currentProduct.lowStockThreshold.toStringAsFixed(0)})'
                                    : 'Désactivée',
                                icon: Icons.notification_important_outlined,
                                valueColor: currentProduct.lowStockAlert ? AppColors.warning : AppColors.textTertiary,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Alerte stock élevé',
                                value: currentProduct.highStockAlert
                                    ? 'Activée (Seuil: ${currentProduct.highStockThreshold.toStringAsFixed(0)})'
                                    : 'Désactivée',
                                icon: Icons.warning_amber_rounded,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Vente en stock négatif',
                                value: currentProduct.allowNegativeStock ? 'Autorisée' : 'Bloquée (Non autorisée)',
                                icon: Icons.rule_rounded,
                                valueColor: currentProduct.allowNegativeStock ? AppColors.warning : AppColors.success,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Entrepôt assigné par défaut',
                                value: currentProduct.defaultWarehouseId ?? 'Entrepôt Principal',
                                icon: Icons.warehouse_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Classification & Référencement
                  DetailSectionCard(
                    title: 'Classification & Références',
                    icon: Icons.category_outlined,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = isWide ? 4 : 2;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Code Article',
                                value: currentProduct.code,
                                icon: Icons.tag_rounded,
                                copyable: true,
                                valueFontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Référence Fabricant',
                                value: currentProduct.reference,
                                icon: Icons.qr_code_2_rounded,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Code-barres / EAN',
                                value: currentProduct.barcode,
                                icon: Icons.barcode_reader,
                                copyable: true,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Unité de mesure',
                                value: currentProduct.unit,
                                icon: Icons.straighten_rounded,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Catégorie',
                                value: currentProduct.category,
                                icon: Icons.folder_outlined,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Famille',
                                value: currentProduct.familyId,
                                icon: Icons.layers_outlined,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Sous-Famille',
                                value: currentProduct.subFamilyId,
                                icon: Icons.alt_route_rounded,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Marque',
                                value: currentProduct.brandId,
                                icon: Icons.branding_watermark_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 4: Descriptions & Notes
                  DetailSectionCard(
                    title: 'Descriptions & Notes',
                    icon: Icons.notes_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DetailInfoTile(
                          label: 'Description commerciale',
                          value: currentProduct.description,
                          icon: Icons.description_outlined,
                          copyable: true,
                        ),
                        const SizedBox(height: 12),
                        DetailInfoTile(
                          label: 'Notes privées / internes',
                          value: currentProduct.privateNotes,
                          icon: Icons.lock_outline_rounded,
                          copyable: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 5: Traçabilité
                  DetailSectionCard(
                    title: 'Traçabilité',
                    icon: Icons.history_rounded,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final colCount = isWide ? 2 : 1;
                        final tileWidth = (constraints.maxWidth - ((colCount - 1) * 12)) / colCount;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Date de création',
                                value: formatDateTime(currentProduct.createdAt),
                                icon: Icons.calendar_today_outlined,
                              ),
                            ),
                            SizedBox(
                              width: tileWidth,
                              child: DetailInfoTile(
                                label: 'Dernière mise à jour',
                                value: formatDateTime(currentProduct.updatedAt),
                                icon: Icons.update_rounded,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
