import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/sidebar_menu.dart';
import 'mobile_search_bar.dart';
import 'mobile_filter_chips.dart';
import 'mobile_empty_state.dart';
import '../../services/sync_service.dart';

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
  });

  @override
  Widget build(BuildContext context) {
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
                      '$itemCount résultat${itemCount! > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
          ],
          
          // Content Area
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await SyncService.instance.triggerSync();
                      onRefresh();
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
      floatingActionButton: customFab ?? (onFabPressed != null && fabText != null ? FloatingActionButton.extended(
        onPressed: onFabPressed,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(fabText!, style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
      ) : null),
    );
  }
}
