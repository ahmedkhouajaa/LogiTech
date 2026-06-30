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
  final VoidCallback onFabPressed;
  final String fabText;

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
    required this.onFabPressed,
    required this.fabText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Sticky Search Bar
          MobileSearchBar(onChanged: onSearchChanged),
          
          // Horizontal Filter Chips
          if (filterOptions.isNotEmpty)
            MobileFilterChips(
              options: filterOptions,
              selectedOption: selectedFilter,
              onSelected: onFilterChanged,
            ),
          
          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await SyncService.instance.triggerSync();
                      onRefresh();
                    },
                    child: isEmpty
                        ? Stack(
                            children: [
                              ListView(), // Needed for RefreshIndicator to work on empty
                              MobileEmptyState(message: emptyMessage),
                            ],
                          )
                        : child,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onFabPressed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(fabText, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
