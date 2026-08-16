import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/sidebar_menu.dart';
import 'mobile_search_bar.dart';
import 'mobile_filter_chips.dart';
import 'mobile_empty_state.dart';
import '../../services/sync_service.dart';
import '../../services/permission_service.dart';
import 'shimmer_card.dart';
import '../../widgets/shimmer_effect.dart';

class MobileGenericListScreen extends StatelessWidget {
  final String title;
  final AppModule activeModule;
  final ValueChanged<AppModule> onModuleSelected;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearchChanged;
  final List<String> filterOptions;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final bool isLoading;
  final bool isEmpty;
  final String emptyMessage;
  final Widget child; // The list of cards
  final VoidCallback? onFabPressed;
  final String? fabText;
  final int? itemCount;
  final Widget? customFilterWidget;
  final ScrollController? scrollController;
  final Widget? customFab;
  final String? subtitle;
  final Widget? loadingWidget;

  const MobileGenericListScreen({
    super.key,
    required this.title,
    required this.activeModule,
    required this.onModuleSelected,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.filterOptions,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.isLoading,
    required this.isEmpty,
    required this.emptyMessage,
    required this.child,
    this.onFabPressed,
    this.fabText,
    this.itemCount,
    this.customFilterWidget,
    this.scrollController,
    this.customFab,
    this.subtitle,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PermissionService.instance.permissionsNotifier,
      builder: (context, _, __) {
        final resKey = PermissionService.instance.getResourceKeyForModule(activeModule);
        final canRead = resKey == null || PermissionService.instance.canRead(resKey);
        final canCreate = resKey == null || PermissionService.instance.canCreate(resKey);

        if (!canRead) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const UnauthorizedView(),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 4.0),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              // Sticky Search Bar
              MobileSearchBar(onChanged: onSearchChanged),
              
              if (customFilterWidget == null) ...[
                // Horizontal Filter Chips
                if (filterOptions.isNotEmpty)
                  MobileFilterChips(
                    options: filterOptions,
                    selectedOption: selectedFilter,
                    onSelected: onFilterChanged,
                  ),
                  
                if (itemCount != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$itemCount élément${itemCount! > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              // List with Pull to Refresh
              Expanded(
                child: isLoading
                    ? (loadingWidget ?? _buildDefaultLoading())
                    : RefreshIndicator(
                        onRefresh: () async {
                          onRefresh();
                          await SyncService.instance.triggerSync();
                        },
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (customFilterWidget != null) customFilterWidget!,
                              if (isEmpty)
                                MobileEmptyState(message: emptyMessage)
                              else
                                child,
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: customFab ??
              (onFabPressed != null && fabText != null && canCreate
                  ? FloatingActionButton.extended(
                      onPressed: onFabPressed,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(fabText!, style: const TextStyle(color: Colors.white)),
                      backgroundColor: AppColors.primary,
                    )
                  : null),
        );
      },
    );
  }

  Widget _buildDefaultLoading() {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            ShimmerCard(refWidth: 130, statusWidth: 80, dateWidth: 100, clientWidth: 140, amountWidth: 85),
            ShimmerCard(refWidth: 145, statusWidth: 70, dateWidth: 95, clientWidth: 110, amountWidth: 70),
            ShimmerCard(refWidth: 120, statusWidth: 85, dateWidth: 105, clientWidth: 150, amountWidth: 90),
            ShimmerCard(refWidth: 140, statusWidth: 75, dateWidth: 90, clientWidth: 130, amountWidth: 80),
            ShimmerCard(refWidth: 125, statusWidth: 80, dateWidth: 100, clientWidth: 120, amountWidth: 75),
            ShimmerCard(refWidth: 135, statusWidth: 70, dateWidth: 95, clientWidth: 135, amountWidth: 85),
          ],
        ),
      ),
    );
  }
}
