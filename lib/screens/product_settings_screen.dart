import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/shimmer_effect.dart';
import 'package:uuid/uuid.dart';
import '../blocs/product_settings/product_settings_bloc.dart';
import '../blocs/product_settings/product_settings_event.dart';
import '../blocs/product_settings/product_settings_state.dart';
import '../models/product_family.dart';
import '../models/product_category.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class ProductSettingsScreen extends StatefulWidget {
  const ProductSettingsScreen({super.key});

  @override
  State<ProductSettingsScreen> createState() => _ProductSettingsScreenState();
}

class _ProductSettingsScreenState extends State<ProductSettingsScreen> {
  int _selectedTab = 0; // 0: Familles & Sous-familles, 1: Catégories & Marques
  final _familyCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _familySearchCtrl = TextEditingController();
  final _categorySearchCtrl = TextEditingController();
  String _familySearchQuery = '';
  String _categorySearchQuery = '';

  final Map<String, TextEditingController> _subFamilyCtrls = {};
  final Map<String, TextEditingController> _brandCtrls = {};

  @override
  void initState() {
    super.initState();
    context.read<ProductSettingsBloc>().add(LoadFamilies());
  }

  @override
  void dispose() {
    _familyCtrl.dispose();
    _categoryCtrl.dispose();
    _familySearchCtrl.dispose();
    _categorySearchCtrl.dispose();
    for (var c in _subFamilyCtrls.values) {
      c.dispose();
    }
    for (var c in _brandCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getSubFamilyCtrl(String familyId) {
    if (!_subFamilyCtrls.containsKey(familyId)) {
      _subFamilyCtrls[familyId] = TextEditingController();
    }
    return _subFamilyCtrls[familyId]!;
  }

  TextEditingController _getBrandCtrl(String categoryId) {
    if (!_brandCtrls.containsKey(categoryId)) {
      _brandCtrls[categoryId] = TextEditingController();
    }
    return _brandCtrls[categoryId]!;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Bar
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Paramètres des articles'),
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedTab == 0
                    ? context.tr('Gérer les familles et sous-familles d\'articles')
                    : context.tr('Gérer les catégories et marques d\'articles'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ],
          ),
        ),

        // Tabs Switcher
        Container(
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabButton(
                title: context.tr('Familles & Sous-familles'),
                icon: Icons.account_tree_outlined,
                isSelected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
              const SizedBox(width: 4),
              _buildTabButton(
                title: context.tr('Catégories & Marques'),
                icon: Icons.category_outlined,
                isSelected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<ProductSettingsBloc>().add(LoadFamilies());
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              physics: const AlwaysScrollableScrollPhysics(),
              child: _selectedTab == 0
                  ? _buildFamiliesTabContent(isMobile)
                  : _buildCategoriesTabContent(isMobile),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar({
    required TextEditingController controller,
    required String hintText,
    required String query,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsFound({
    required String query,
    required String message,
    required VoidCallback onClear,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded, size: 36, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('Aucun résultat trouvé'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '$message ("$query")',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white),
            label: Text(context.tr('Effacer le filtre'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: FAMILLES & SOUS-FAMILLES ──────────────────────────────────────
  Widget _buildFamiliesTabContent(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add new family section
        if (PermissionService.instance.canCreate(UserPermissionResources.productsSettings))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Ajouter une nouvelle famille'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                isMobile
                    ? Column(
                        children: [
                          TextField(
                            controller: _familyCtrl,
                            decoration: InputDecoration(
                              hintText: context.tr('Nom de la famille (ex: Informatique, Mobilier...)'),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleAddFamily,
                              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                              label: Text(context.tr('Ajouter une famille'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _familyCtrl,
                              decoration: InputDecoration(
                                hintText: context.tr('Nom de la famille (ex: Informatique, Mobilier...)'),
                                filled: true,
                                fillColor: AppColors.surfaceAlt,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onSubmitted: (_) => _handleAddFamily(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _handleAddFamily,
                            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                            label: Text(context.tr('Ajouter une famille'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),

        // Filter / Search bar
        _buildSearchBar(
          controller: _familySearchCtrl,
          hintText: context.tr('Filtrer par famille ou sous-famille...'),
          query: _familySearchQuery,
          onChanged: (val) => setState(() => _familySearchQuery = val),
          onClear: () => setState(() {
            _familySearchCtrl.clear();
            _familySearchQuery = '';
          }),
        ),

        BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
          builder: (context, state) {
            if (state is ProductSettingsLoading || state is ProductSettingsInitial) {
              return AppShimmer(
                child: Column(
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: const [
                            ShimmerBox(width: 24, height: 24, borderRadius: 6),
                            SizedBox(width: 12),
                            ShimmerBox(width: 150, height: 14, borderRadius: 4),
                            Spacer(),
                            ShimmerBox(width: 60, height: 24, borderRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            
            if (state is ProductSettingsLoaded) {
              final rootFamilies = state.rootFamilies;

              if (rootFamilies.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.category_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('Aucune famille enregistrée'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('Saisissez un nom ci-dessus pour créer votre première famille d\'articles.'),
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final query = _familySearchQuery.trim().toLowerCase();
              final filteredFamilies = rootFamilies.where((family) {
                if (query.isEmpty) return true;
                final familyMatches = family.name.toLowerCase().contains(query);
                final subFamilies = state.getSubFamilies(family.id);
                final hasMatchingSub = subFamilies.any((sf) => sf.name.toLowerCase().contains(query));
                return familyMatches || hasMatchingSub;
              }).toList();

              if (filteredFamilies.isEmpty) {
                return _buildNoResultsFound(
                  query: _familySearchQuery,
                  message: context.tr('Aucune famille ou sous-famille ne correspond à votre recherche.'),
                  onClear: () => setState(() {
                    _familySearchCtrl.clear();
                    _familySearchQuery = '';
                  }),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${filteredFamilies.length} ${context.tr('famille(s) trouvée(s)')}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ...filteredFamilies.map((family) {
                    final subFamilies = state.getSubFamilies(family.id);
                    final isFamilyMatch = family.name.toLowerCase().contains(query);
                    final displayedSubFamilies = query.isEmpty || isFamilyMatch
                        ? subFamilies
                        : subFamilies.where((sf) => sf.name.toLowerCase().contains(query)).toList();
                    return _buildFamilyCard(context, family, displayedSubFamilies, isMobile);
                  }),
                ],
              );
            }
            
            return const SizedBox();
          },
        ),
      ],
    );
  }

  // ─── TAB 2: CATÉGORIES & MARQUES ─────────────────────────────────────────
  Widget _buildCategoriesTabContent(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add new category section
        if (PermissionService.instance.canCreate(UserPermissionResources.productsSettings))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Ajouter une nouvelle catégorie'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                isMobile
                    ? Column(
                        children: [
                          TextField(
                            controller: _categoryCtrl,
                            decoration: InputDecoration(
                              hintText: context.tr('Nom de la catégorie (ex: Téléphonie, Accessoires...)'),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleAddCategory,
                              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                              label: Text(context.tr('Ajouter une catégorie'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _categoryCtrl,
                              decoration: InputDecoration(
                                hintText: context.tr('Nom de la catégorie (ex: Téléphonie, Accessoires...)'),
                                filled: true,
                                fillColor: AppColors.surfaceAlt,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onSubmitted: (_) => _handleAddCategory(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _handleAddCategory,
                            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                            label: Text(context.tr('Ajouter une catégorie'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),

        // Filter / Search bar
        _buildSearchBar(
          controller: _categorySearchCtrl,
          hintText: context.tr('Filtrer par catégorie ou marque...'),
          query: _categorySearchQuery,
          onChanged: (val) => setState(() => _categorySearchQuery = val),
          onClear: () => setState(() {
            _categorySearchCtrl.clear();
            _categorySearchQuery = '';
          }),
        ),

        BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
          builder: (context, state) {
            if (state is ProductSettingsLoading || state is ProductSettingsInitial) {
              return AppShimmer(
                child: Column(
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: const [
                            ShimmerBox(width: 24, height: 24, borderRadius: 6),
                            SizedBox(width: 12),
                            ShimmerBox(width: 150, height: 14, borderRadius: 4),
                            Spacer(),
                            ShimmerBox(width: 60, height: 24, borderRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            
            if (state is ProductSettingsLoaded) {
              final categories = state.categories;

              if (categories.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.category_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('Aucune catégorie enregistrée'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('Saisissez un nom ci-dessus pour créer votre première catégorie d\'articles.'),
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final query = _categorySearchQuery.trim().toLowerCase();
              final filteredCategories = categories.where((cat) {
                if (query.isEmpty) return true;
                final catMatches = cat.name.toLowerCase().contains(query);
                final brands = state.getBrandsForCategory(cat.name);
                final hasMatchingBrand = brands.any((b) => b.name.toLowerCase().contains(query));
                return catMatches || hasMatchingBrand;
              }).toList();

              if (filteredCategories.isEmpty) {
                return _buildNoResultsFound(
                  query: _categorySearchQuery,
                  message: context.tr('Aucune catégorie ou marque ne correspond à votre recherche.'),
                  onClear: () => setState(() {
                    _categorySearchCtrl.clear();
                    _categorySearchQuery = '';
                  }),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${filteredCategories.length} ${context.tr('catégorie(s) trouvée(s)')}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ...filteredCategories.map((cat) {
                    final brands = state.getBrandsForCategory(cat.name);
                    final isCatMatch = cat.name.toLowerCase().contains(query);
                    final displayedBrands = query.isEmpty || isCatMatch
                        ? brands
                        : brands.where((b) => b.name.toLowerCase().contains(query)).toList();
                    return _buildCategoryCard(context, cat, displayedBrands, isMobile);
                  }),
                ],
              );
            }
            
            return const SizedBox();
          },
        ),
      ],
    );
  }

  void _handleAddFamily() {
    final name = _familyCtrl.text.trim();
    if (name.isNotEmpty) {
      final newFam = ProductFamily(
        id: const Uuid().v4(),
        name: name,
      );
      context.read<ProductSettingsBloc>().add(AddFamily(newFam));
      _familyCtrl.clear();
    }
  }

  void _handleAddCategory() {
    final name = _categoryCtrl.text.trim();
    if (name.isNotEmpty) {
      final newCat = ProductCategory(
        id: const Uuid().v4(),
        name: name,
      );
      context.read<ProductSettingsBloc>().add(AddCategory(newCat));
      _categoryCtrl.clear();
    }
  }

  Future<void> _showEditItemDialog({
    required BuildContext context,
    required String title,
    required String currentName,
    required String hintText,
    required ValueChanged<String> onSave,
  }) async {
    final controller = TextEditingController(text: currentName);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: currentName.length,
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return context.tr('Ce champ ne peut pas être vide');
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    final newName = controller.text.trim();
                    if (newName != currentName) {
                      onSave(newName);
                    }
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Annuler')),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final newName = controller.text.trim();
                if (newName != currentName) {
                  onSave(newName);
                }
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(context.tr('Enregistrer'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleEditFamily(ProductFamily family) {
    _showEditItemDialog(
      context: context,
      title: context.tr('Modifier la famille'),
      currentName: family.name,
      hintText: context.tr('Nom de la famille'),
      onSave: (newName) {
        final updated = ProductFamily(
          id: family.id,
          name: newName,
          parentId: family.parentId,
          createdAt: family.createdAt,
        );
        context.read<ProductSettingsBloc>().add(UpdateFamily(updated));
      },
    );
  }

  void _handleEditSubFamily(ProductFamily subFam) {
    _showEditItemDialog(
      context: context,
      title: context.tr('Modifier la sous-famille'),
      currentName: subFam.name,
      hintText: context.tr('Nom de la sous-famille'),
      onSave: (newName) {
        final updated = ProductFamily(
          id: subFam.id,
          name: newName,
          parentId: subFam.parentId,
          createdAt: subFam.createdAt,
        );
        context.read<ProductSettingsBloc>().add(UpdateSubFamily(updated));
      },
    );
  }

  void _handleEditCategory(ProductCategory category) {
    _showEditItemDialog(
      context: context,
      title: context.tr('Modifier la catégorie'),
      currentName: category.name,
      hintText: context.tr('Nom de la catégorie'),
      onSave: (newName) {
        final oldName = category.name;
        final updated = ProductCategory(
          id: category.id,
          name: newName,
          createdAt: category.createdAt,
        );
        context.read<ProductSettingsBloc>().add(UpdateCategory(updated, oldName: oldName));
      },
    );
  }

  void _handleEditBrand(ProductBrand brand) {
    _showEditItemDialog(
      context: context,
      title: context.tr('Modifier la marque'),
      currentName: brand.name,
      hintText: context.tr('Nom de la marque'),
      onSave: (newName) {
        final updated = ProductBrand(
          id: brand.id,
          name: newName,
          categoryId: brand.categoryId,
          createdAt: brand.createdAt,
        );
        context.read<ProductSettingsBloc>().add(UpdateBrand(updated));
      },
    );
  }

  Widget _buildFamilyCard(BuildContext context, ProductFamily family, List<ProductFamily> subFamilies, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.folder_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${subFamilies.length} ${context.tr('sous-famille(s)')}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                tooltip: context.tr('Modifier la famille'),
                onPressed: () => _handleEditFamily(family),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                tooltip: context.tr('Supprimer la famille'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(context.tr('Confirmer la suppression')),
                      content: Text('${context.tr('Voulez-vous vraiment supprimer cette famille ainsi que toutes ses sous-familles ?')} ("${family.name}")'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(context.tr('Annuler')),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ProductSettingsBloc>().add(DeleteFamily(family.id));
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: Text(context.tr('Supprimer'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          
          if (subFamilies.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(context.tr('Sous-familles'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...subFamilies.map((subFam) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(subFam.name, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                  Tooltip(
                    message: context.tr('Modifier la sous-famille'),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () => _handleEditSubFamily(subFam),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: context.tr('Supprimer la sous-famille'),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(context.tr('Confirmer la suppression')),
                          content: Text('${context.tr('Voulez-vous vraiment supprimer cette sous-famille ?')} ("${subFam.name}")'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(context.tr('Annuler')),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                context.read<ProductSettingsBloc>().add(DeleteSubFamily(subFam.id));
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: Text(context.tr('Supprimer'), style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, color: AppColors.textSecondary.withValues(alpha: 0.7), size: 16),
                    ),
                  ),
                ),
                ],
              ),
            )),
          ],
          
          const SizedBox(height: 16),
          isMobile
              ? Column(
                  children: [
                    TextField(
                      controller: _getSubFamilyCtrl(family.id),
                      decoration: InputDecoration(
                        hintText: context.tr('Nom de la nouvelle sous-famille'),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleAddSubFamily(family.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(context.tr('Ajouter la sous-famille'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _getSubFamilyCtrl(family.id),
                        decoration: InputDecoration(
                          hintText: context.tr('Nom de la nouvelle sous-famille'),
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _handleAddSubFamily(family.id),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _handleAddSubFamily(family.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: Text(context.tr('Ajouter la sous-famille'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, ProductCategory category, List<ProductBrand> brands, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${brands.length} ${context.tr('marque(s)')}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                tooltip: context.tr('Modifier la catégorie'),
                onPressed: () => _handleEditCategory(category),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                tooltip: context.tr('Supprimer la catégorie'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(context.tr('Confirmer la suppression')),
                      content: Text('${context.tr('Voulez-vous vraiment supprimer cette catégorie ainsi que toutes ses marques associées ?')} ("${category.name}")'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(context.tr('Annuler')),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ProductSettingsBloc>().add(DeleteCategory(category.id));
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: Text(context.tr('Supprimer'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          
          if (brands.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(context.tr('Marques associées'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...brands.map((b) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.branding_watermark_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b.name, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                  Tooltip(
                    message: context.tr('Modifier la marque'),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () => _handleEditBrand(b),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: context.tr('Supprimer la marque'),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(context.tr('Confirmer la suppression')),
                          content: Text('${context.tr('Voulez-vous vraiment supprimer cette marque ?')} ("${b.name}")'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(context.tr('Annuler')),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                context.read<ProductSettingsBloc>().add(DeleteBrand(b.id));
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: Text(context.tr('Supprimer'), style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, color: AppColors.textSecondary.withValues(alpha: 0.7), size: 16),
                    ),
                  ),
                ),
                ],
              ),
            )),
          ],
          
          const SizedBox(height: 16),
          isMobile
              ? Column(
                  children: [
                    TextField(
                      controller: _getBrandCtrl(category.id),
                      decoration: InputDecoration(
                        hintText: context.tr('Nom de la nouvelle marque'),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleAddBrand(category),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(context.tr('Ajouter la marque'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _getBrandCtrl(category.id),
                        decoration: InputDecoration(
                          hintText: context.tr('Nom de la nouvelle marque'),
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _handleAddBrand(category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _handleAddBrand(category),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: Text(context.tr('Ajouter la marque'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  void _handleAddSubFamily(String familyId) {
    final ctrl = _getSubFamilyCtrl(familyId);
    if (ctrl.text.trim().isNotEmpty) {
      final newSub = ProductFamily(
        id: const Uuid().v4(),
        name: ctrl.text.trim(),
        parentId: familyId,
      );
      context.read<ProductSettingsBloc>().add(AddSubFamily(newSub));
      ctrl.clear();
    }
  }

  void _handleAddBrand(ProductCategory category) {
    final ctrl = _getBrandCtrl(category.id);
    if (ctrl.text.trim().isNotEmpty) {
      final newBrand = ProductBrand(
        id: const Uuid().v4(),
        name: ctrl.text.trim(),
        categoryId: category.name,
      );
      context.read<ProductSettingsBloc>().add(AddBrand(newBrand));
      ctrl.clear();
    }
  }
}
