import os

base_dir = "d:/LogiTech/lib/mobile"

# 1. Create mobile_filter_chips.dart
with open(os.path.join(base_dir, "widgets", "mobile_filter_chips.dart"), "w", encoding="utf-8") as f:
    f.write("""import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class MobileFilterChips extends StatelessWidget {
  final List<String> options;
  final String selectedOption;
  final ValueChanged<String> onSelected;

  const MobileFilterChips({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selectedOption;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onSelected(option);
                }
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
""")

# 2. Create mobile_search_bar.dart
with open(os.path.join(base_dir, "widgets", "mobile_search_bar.dart"), "w", encoding="utf-8") as f:
    f.write("""import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class MobileSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;

  const MobileSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Rechercher...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
""")

# 3. Create mobile_empty_state.dart
with open(os.path.join(base_dir, "widgets", "mobile_empty_state.dart"), "w", encoding="utf-8") as f:
    f.write("""import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class MobileEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const MobileEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
""")

# 4. Create mobile_generic_list_screen.dart
with open(os.path.join(base_dir, "widgets", "mobile_generic_list_screen.dart"), "w", encoding="utf-8") as f:
    f.write("""import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'mobile_search_bar.dart';
import 'mobile_filter_chips.dart';
import 'mobile_empty_state.dart';
import '../mobile_drawer.dart';

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
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      drawer: MobileDrawer(
        activeModule: activeModule,
        onModuleSelected: onModuleSelected,
      ),
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
""")

print("Widgets generated successfully.")
