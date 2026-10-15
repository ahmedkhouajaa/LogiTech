import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/stock_notification_service.dart';
import '../services/app_navigation_service.dart';
import '../widgets/sidebar_menu.dart';
import '../screens/article_detail_screen.dart';
import '../screens/create_supplier_order_screen.dart';
import '../mobile/screens/forms/mobile_supplier_order_form_screen.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../l10n/app_localizations.dart';

class StockNotificationBell extends StatefulWidget {
  const StockNotificationBell({super.key});

  @override
  State<StockNotificationBell> createState() => _StockNotificationBellState();
}

class _StockNotificationBellState extends State<StockNotificationBell> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _StockNotificationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: StockNotificationService.instance.alertCountNotifier,
      builder: (context, count, _) {
        final hasAlerts = count > 0;

        if (hasAlerts && !_animController.isAnimating) {
          _animController.repeat(reverse: true);
        } else if (!hasAlerts && _animController.isAnimating) {
          _animController.stop();
          _animController.reset();
        }

        return Tooltip(
          message: hasAlerts
              ? '$count alertes de stock'
              : 'Notifications de stock',
          child: InkWell(
            onTap: () => _openNotificationDialog(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasAlerts ? AppColors.error.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: hasAlerts ? _scaleAnimation.value : 1.0,
                        child: child,
                      );
                    },
                    child: Icon(
                      hasAlerts ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                      size: 22,
                      color: hasAlerts ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                  if (hasAlerts)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StockNotificationDialog extends StatefulWidget {
  const _StockNotificationDialog();

  @override
  State<_StockNotificationDialog> createState() => _StockNotificationDialogState();
}

class _StockNotificationDialogState extends State<_StockNotificationDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final dialogWidth = isMobile ? mediaQuery.size.width * 0.95 : 540.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: mediaQuery.size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications_active_rounded, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Centre des Alertes Stock'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          context.tr('Surveillance automatique des seuils de stock'),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: StockNotificationService.instance.isCheckingNotifier,
                    builder: (context, isChecking, _) {
                      return IconButton(
                        icon: isChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        tooltip: 'Actualiser les stocks',
                        onPressed: isChecking
                            ? null
                            : () => StockNotificationService.instance.checkStockAlerts(notifyOnNew: false),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab bar
            ValueListenableBuilder<Set<String>>(
              valueListenable: StockNotificationService.instance.dismissedIdsNotifier,
              builder: (context, dismissedIds, _) {
                return ValueListenableBuilder<List<Product>>(
                  valueListenable: StockNotificationService.instance.lowStockNotifier,
                  builder: (context, lowItems, _) {
                    return ValueListenableBuilder<List<Product>>(
                      valueListenable: StockNotificationService.instance.highStockNotifier,
                      builder: (context, highItems, _) {
                        final unreadLow = lowItems.where((p) => !dismissedIds.contains(p.id)).length;
                        final unreadHigh = highItems.where((p) => !dismissedIds.contains(p.id)).length;

                        return Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textSecondary,
                            indicatorColor: AppColors.primary,
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                                    const SizedBox(width: 6),
                                    Text('Ruptures (${lowItems.length})'),
                                    if (unreadLow > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$unreadLow',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.warning),
                                    const SizedBox(width: 6),
                                    Text('Surstockage (${highItems.length})'),
                                    if (unreadHigh > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$unreadHigh',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            // Tab View
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProductList(isLowStockList: true),
                  _buildProductList(isLowStockList: false),
                ],
              ),
            ),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: StockNotificationService.instance.dismissedIdsNotifier,
                    builder: (context, dismissedIds, _) {
                      return ValueListenableBuilder<List<Product>>(
                        valueListenable: StockNotificationService.instance.lowStockNotifier,
                        builder: (context, lowItems, _) {
                          return ValueListenableBuilder<List<Product>>(
                            valueListenable: StockNotificationService.instance.highStockNotifier,
                            builder: (context, highItems, _) {
                              final allItems = [...lowItems, ...highItems];
                              final allDismissed = allItems.isEmpty ||
                                  allItems.every((p) => dismissedIds.contains(p.id));

                              return TextButton.icon(
                                onPressed: allDismissed
                                    ? null
                                    : () {
                                        StockNotificationService.instance.dismissAll();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(context.tr('Toutes les alertes sont marquées comme vues')),
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                icon: Icon(
                                  Icons.done_all_rounded,
                                  size: 16,
                                  color: allDismissed ? AppColors.success : AppColors.primary,
                                ),
                                label: Text(
                                  allDismissed
                                      ? context.tr('Toutes les alertes sont vues')
                                      : context.tr('Tout marquer comme vu'),
                                  style: TextStyle(
                                    color: allDismissed ? AppColors.textSecondary : AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      AppNavigationService.instance.navigateToModule(context, AppModule.products);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(context.tr('Gérer tous les articles')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList({required bool isLowStockList}) {
    final notifier = isLowStockList
        ? StockNotificationService.instance.lowStockNotifier
        : StockNotificationService.instance.highStockNotifier;

    return ValueListenableBuilder<List<Product>>(
      valueListenable: notifier,
      builder: (context, products, _) {
        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: AppColors.success.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLowStockList
                        ? context.tr('Aucune rupture de stock')
                        : context.tr('Aucun surstockage détecté'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Tous vos stocks respectent les seuils configurés.'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ValueListenableBuilder<Set<String>>(
          valueListenable: StockNotificationService.instance.dismissedIdsNotifier,
          builder: (context, dismissedIds, _) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final p = products[index];
                final isCritical = p.stockQty <= 0;
                final isDismissed = dismissedIds.contains(p.id);
                final badgeColor = isLowStockList
                    ? (isCritical ? AppColors.error : Colors.deepOrange)
                    : AppColors.warning;
                final alertTime = StockNotificationService.instance.getAlertTimestamp(p);
                final qtyExact = formatQuantity(p.stockQty);
                final seuilExact = isLowStockList ? formatQuantity(p.lowStockThreshold) : formatQuantity(p.highStockThreshold);
                final badgeText = isLowStockList
                    ? (isCritical
                        ? 'ÉPUISÉ ($qtyExact ${p.unit})'
                        : 'Stock: $qtyExact ${p.unit} / Min: $seuilExact')
                    : 'Stock: $qtyExact ${p.unit} / Max: $seuilExact';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    border: Border.all(
                      color: isDismissed
                          ? AppColors.border.withValues(alpha: 0.4)
                          : badgeColor.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDismissed
                              ? AppColors.textSecondary.withValues(alpha: 0.08)
                              : badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            isDismissed
                                ? Icons.done_all_rounded
                                : (isLowStockList
                                    ? (isCritical ? Icons.error_outline_rounded : Icons.trending_down_rounded)
                                    : Icons.trending_up_rounded),
                            color: isDismissed ? AppColors.textSecondary : badgeColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  p.code,
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                if (isDismissed) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_rounded, size: 10, color: AppColors.success),
                                        const SizedBox(width: 3),
                                        Text(
                                          context.tr('Vu'),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 11, color: AppColors.textTertiary),
                                const SizedBox(width: 4),
                                Text(
                                  '${formatDateTime(alertTime)} (${formatDateRelative(alertTime)})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          isDismissed ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        color: isDismissed ? AppColors.success : AppColors.textSecondary,
                        tooltip: isDismissed ? context.tr('Marqué comme vu (cliquer pour réactiver)') : context.tr('Marquer comme vu'),
                        onPressed: () {
                          StockNotificationService.instance.toggleDismiss(p.id);
                        },
                      ),
                      if (isLowStockList)
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                          color: AppColors.primary,
                          tooltip: 'Créer commande fournisseur',
                          onPressed: () {
                            Navigator.of(context).pop();
                            final isMobile = MediaQuery.of(context).size.width < 768;
                            if (isMobile) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MobileSupplierOrderFormScreen(initialProduct: p),
                                ),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CreateSupplierOrderScreen(initialProduct: p),
                                ),
                              );
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        color: AppColors.textSecondary,
                        tooltip: 'Détails article',
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArticleDetailScreen(product: p),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
