import 'package:flutter/material.dart';
import '../models/trash_item.dart';
import '../models/user_management_model.dart';
import '../services/permission_service.dart';
import '../services/trash_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  String _selectedCategory = 'Tous';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isSyncing = false;

  final List<String> _categories = [
    'Tous',
    'Articles',
    'Ventes',
    'Achats',
    'Clients',
    'Fournisseurs',
    'Paiements',
    'Retenues (RS)',
    'Stock',
    'Trésorerie',
    'Projets',
  ];

  @override
  void initState() {
    super.initState();
    _triggerSync();
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    await TrashService.instance.syncLegacyDeletedItems();
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Ventes':
        return const Color(0xFF2563EB); // Royal Blue
      case 'Achats':
        return const Color(0xFFEA580C); // Vibrant Orange
      case 'Clients':
        return const Color(0xFF7C3AED); // Deep Purple
      case 'Fournisseurs':
        return const Color(0xFF0891B2); // Cyan / Teal
      case 'Articles':
        return const Color(0xFF0D9488); // Teal
      case 'Paiements':
        return const Color(0xFF0284C7); // Sky Blue / Ocean
      case 'Retenues (RS)':
      case 'Retenue à la source':
      case 'Retenue à la source (RS)':
        return const Color(0xFF9333EA); // Purple
      case 'Stock':
        return const Color(0xFF059669); // Emerald Green
      case 'Trésorerie':
        return const Color(0xFFD97706); // Amber Gold
      case 'Projets':
        return const Color(0xFF4F46E5); // Indigo
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Ventes':
        return Icons.shopping_cart_outlined;
      case 'Achats':
        return Icons.local_shipping_outlined;
      case 'Clients':
        return Icons.people_alt_outlined;
      case 'Fournisseurs':
        return Icons.factory_outlined;
      case 'Articles':
        return Icons.inventory_2_outlined;
      case 'Paiements':
        return Icons.payments_outlined;
      case 'Retenues (RS)':
      case 'Retenue à la source':
      case 'Retenue à la source (RS)':
        return Icons.receipt_long_rounded;
      case 'Stock':
        return Icons.warehouse_outlined;
      case 'Trésorerie':
        return Icons.account_balance_wallet_outlined;
      case 'Projets':
        return Icons.folder_outlined;
      default:
        return Icons.delete_outline_rounded;
    }
  }

  Future<void> _confirmDeletePermanently(TrashItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('Supprimer définitivement ?'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer définitivement « ${item.title} » ?\n\nCette action est irréversible et toutes les données associées seront effacées de manière permanente.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(context.tr('Supprimer définitivement')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TrashService.instance.deletePermanently(item);
      setState(() {
        _selectedIds.remove(item.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('« ${item.title} » a été supprimé définitivement.'),
            backgroundColor: AppColors.surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _restoreItem(TrashItem item) async {
    await TrashService.instance.restoreItem(item);
    setState(() {
      _selectedIds.remove(item.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('« ${item.title} » a été restauré avec succès.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _confirmEmptyTrash(List<TrashItem> items) async {
    if (items.isEmpty) return;

    final filterLabel = _selectedCategory == 'Tous' ? 'tous les éléments de la corbeille' : 'les éléments de la catégorie « $_selectedCategory »';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('Vider la corbeille ?'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous absolument sûr de vouloir vider $filterLabel (${items.length} élément(s)) ?\n\nToutes ces données seront effacées définitivement et ne pourront plus jamais être récupérées.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: Text(context.tr('Tout supprimer définitivement')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TrashService.instance.emptyTrash(items: items);
      setState(() {
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${items.length} élément(s) supprimé(s) définitivement.'),
            backgroundColor: AppColors.surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _restoreAll(List<TrashItem> items) async {
    if (items.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings_backup_restore_rounded, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('Tout restaurer ?'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous restaurer les ${items.length} élément(s) affiché(s) ? Ils réapparaîtront dans leurs sections respectives (Vente, Achat, Client, etc.).',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.restore_from_trash_rounded, size: 18),
            label: Text(context.tr('Restaurer tout')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TrashService.instance.restoreAll(items: items);
      setState(() {
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${items.length} élément(s) restauré(s) avec succès.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _restoreSelected(List<TrashItem> allItems) async {
    final selectedItems = allItems.where((item) => _selectedIds.contains(item.id)).toList();
    if (selectedItems.isEmpty) return;

    await TrashService.instance.restoreAll(items: selectedItems);
    setState(() {
      _selectedIds.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedItems.length} élément(s) sélectionné(s) restauré(s).'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteSelectedPermanently(List<TrashItem> allItems) async {
    final selectedItems = allItems.where((item) => _selectedIds.contains(item.id)).toList();
    if (selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('Supprimer la sélection ?'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous supprimer définitivement les ${selectedItems.length} élément(s) sélectionné(s) ? Cette action est irréversible.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(context.tr('Supprimer définitivement')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TrashService.instance.emptyTrash(items: selectedItems);
      setState(() {
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedItems.length} élément(s) supprimé(s) définitivement.'),
            backgroundColor: AppColors.surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<TrashItem>>(
        stream: TrashService.instance.getTrashStream(),
        builder: (context, snapshot) {
          final allItems = snapshot.data ?? [];

          // Filter by category
          var filtered = allItems;
          if (_selectedCategory != 'Tous') {
            if (_selectedCategory == 'Retenues (RS)') {
              filtered = filtered.where((item) => item.category.contains('Retenue') || item.category.contains('RS')).toList();
            } else if (_selectedCategory == 'Paiements') {
              filtered = filtered.where((item) => item.category == 'Paiements' || (item.collection == 'paiements' && !item.category.contains('Retenue') && !item.category.contains('RS'))).toList();
            } else if (_selectedCategory == 'Trésorerie') {
              filtered = filtered.where((item) => item.category == 'Trésorerie' && item.collection != 'paiements').toList();
            } else {
              filtered = filtered.where((item) => item.category == _selectedCategory).toList();
            }
          }

          // Filter by search
          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.toLowerCase().trim();
            filtered = filtered.where((item) {
              return item.title.toLowerCase().contains(query) ||
                  item.subtitle.toLowerCase().contains(query) ||
                  item.originalId.toLowerCase().contains(query) ||
                  item.category.toLowerCase().contains(query);
            }).toList();
          }

          return Column(
            children: [
              // Top Header Bar
              _buildHeader(isMobile, allItems.length, filtered),

              // Filter Bar & Chips
              _buildFilterSection(isMobile, allItems),

              // Contextual Selection Action Bar
              if (_selectedIds.isNotEmpty)
                _buildSelectionActionBar(isMobile, allItems),

              // Content List
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? _buildEmptyState(allItems.isNotEmpty)
                        : _buildItemList(isMobile, filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRestoreButton({
    required VoidCallback onPressed,
    String? label,
    bool isCompact = false,
  }) {
    const successColor = Color(0xFF16A34A);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.settings_backup_restore_rounded, size: isCompact ? 15 : 16, color: successColor),
      label: Text(
        context.tr(label ?? 'Restaurer'),
        style: TextStyle(
          fontSize: isCompact ? 12 : 12.5,
          fontWeight: FontWeight.w600,
          color: successColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: successColor.withValues(alpha: 0.06),
        foregroundColor: successColor,
        side: BorderSide(color: successColor.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: isCompact ? 7 : 9),
        visualDensity: VisualDensity.compact,
        elevation: 0,
      ),
    );
  }

  Widget _buildPermanentDeleteButton({
    required VoidCallback onPressed,
    String? label,
    bool isCompact = false,
  }) {
    const dangerColor = Color(0xFFDC2626);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.delete_outline_rounded, size: isCompact ? 15 : 16, color: dangerColor),
      label: Text(
        context.tr(label ?? 'Supprimer définitivement'),
        style: TextStyle(
          fontSize: isCompact ? 12 : 12.5,
          fontWeight: FontWeight.w600,
          color: dangerColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: dangerColor.withValues(alpha: 0.06),
        foregroundColor: dangerColor,
        side: BorderSide(color: dangerColor.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: isCompact ? 7 : 9),
        visualDensity: VisualDensity.compact,
        elevation: 0,
      ),
    );
  }

  Widget _buildRestoreAllHeaderButton({
    required VoidCallback onPressed,
    bool isMobile = false,
  }) {
    const successColor = Color(0xFF16A34A);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.settings_backup_restore_rounded, size: isMobile ? 15 : 17, color: successColor),
      label: Text(
        context.tr('Tout restaurer'),
        style: TextStyle(
          fontSize: isMobile ? 12 : 13,
          fontWeight: FontWeight.w600,
          color: successColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: successColor.withValues(alpha: 0.06),
        foregroundColor: successColor,
        side: BorderSide(color: successColor.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 8 : 10,
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildEmptyTrashHeaderButton({
    required VoidCallback onPressed,
    bool isMobile = false,
  }) {
    const dangerColor = Color(0xFFDC2626);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.delete_sweep_outlined, size: isMobile ? 15 : 17, color: dangerColor),
      label: Text(
        context.tr('Vider la corbeille'),
        style: TextStyle(
          fontSize: isMobile ? 12 : 13,
          fontWeight: FontWeight.w600,
          color: dangerColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: dangerColor.withValues(alpha: 0.06),
        foregroundColor: dangerColor,
        side: BorderSide(color: dangerColor.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 8 : 10,
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildHeader(bool isMobile, int totalCount, List<TrashItem> filteredItems) {
    final canRestore = PermissionService.instance.canCreate(UserPermissionResources.trash) ||
        PermissionService.instance.canUpdate(UserPermissionResources.trash) ||
        PermissionService.instance.isAdmin;
    final canDelete = PermissionService.instance.canDelete(UserPermissionResources.trash) ||
        PermissionService.instance.isAdmin;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 12 : 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delete_sweep_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.tr('Corbeille'),
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: totalCount > 0
                                ? AppColors.error.withValues(alpha: 0.12)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$totalCount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: totalCount > 0 ? AppColors.error : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('Éléments supprimés de Vente, Achat, Client, Fournisseur, Stock et Trésorerie.'),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Sync / Scan button
              IconButton(
                tooltip: 'Vérifier et synchroniser les suppressions',
                onPressed: _isSyncing ? null : _triggerSync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.sync_rounded, color: AppColors.textSecondary),
              ),
              if (!isMobile && filteredItems.isNotEmpty) ...[
                if (canRestore) ...[
                  const SizedBox(width: 8),
                  _buildRestoreAllHeaderButton(
                    onPressed: () => _restoreAll(filteredItems),
                  ),
                ],
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  _buildEmptyTrashHeaderButton(
                    onPressed: () => _confirmEmptyTrash(filteredItems),
                  ),
                ],
              ],
            ],
          ),
          if (isMobile && filteredItems.isNotEmpty && (canRestore || canDelete)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canRestore)
                  Expanded(
                    child: _buildRestoreAllHeaderButton(
                      onPressed: () => _restoreAll(filteredItems),
                      isMobile: true,
                    ),
                  ),
                if (canRestore && canDelete) const SizedBox(width: 8),
                if (canDelete)
                  Expanded(
                    child: _buildEmptyTrashHeaderButton(
                      onPressed: () => _confirmEmptyTrash(filteredItems),
                      isMobile: true,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isMobile, List<TrashItem> allItems) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 8, isMobile ? 12 : 24, 12),
      child: Column(
        children: [
          // Search Input
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: context.tr('Rechercher dans la corbeille par titre, référence, catégorie...'),
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                final count = cat == 'Tous'
                    ? allItems.length
                    : (cat == 'Retenues (RS)'
                        ? allItems.where((item) => item.category.contains('Retenue') || item.category.contains('RS')).length
                        : (cat == 'Paiements'
                            ? allItems.where((item) => item.category == 'Paiements' || (item.collection == 'paiements' && !item.category.contains('Retenue') && !item.category.contains('RS'))).length
                            : (cat == 'Trésorerie'
                                ? allItems.where((item) => item.category == 'Trésorerie' && item.collection != 'paiements').length
                                : allItems.where((item) => item.category == cat).length)));
                final catColor = cat == 'Tous' ? AppColors.primary : _getCategoryColor(cat);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Icon(
                      cat == 'Tous' ? Icons.grid_view_rounded : _getCategoryIcon(cat),
                      size: 15,
                      color: isSelected ? Colors.white : catColor,
                    ),
                    label: Text('$cat ($count)'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    backgroundColor: AppColors.surfaceAlt,
                    selectedColor: catColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? catColor : AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionActionBar(bool isMobile, List<TrashItem> allItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            '${_selectedIds.length} sélectionné(s)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          if (PermissionService.instance.canCreate(UserPermissionResources.trash) ||
              PermissionService.instance.canUpdate(UserPermissionResources.trash) ||
              PermissionService.instance.isAdmin)
            _buildRestoreButton(
              onPressed: () => _restoreSelected(allItems),
              label: 'Restaurer la sélection',
              isCompact: true,
            ),
          if ((PermissionService.instance.canCreate(UserPermissionResources.trash) ||
                  PermissionService.instance.canUpdate(UserPermissionResources.trash) ||
                  PermissionService.instance.isAdmin) &&
              (PermissionService.instance.canDelete(UserPermissionResources.trash) ||
                  PermissionService.instance.isAdmin))
            const SizedBox(width: 8),
          if (PermissionService.instance.canDelete(UserPermissionResources.trash) ||
              PermissionService.instance.isAdmin)
            _buildPermanentDeleteButton(
              onPressed: () => _deleteSelectedPermanently(allItems),
              label: 'Supprimer définitivement',
              isCompact: true,
            ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: context.tr('Désélectionner tout'),
            onPressed: () => setState(() => _selectedIds.clear()),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool hasTotalItems) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                hasTotalItems ? Icons.filter_alt_off_rounded : Icons.auto_delete_outlined,
                size: 44,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasTotalItems
                  ? context.tr('Aucun élément dans cette catégorie ou recherche')
                  : context.tr('La corbeille est vide'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasTotalItems
                  ? context.tr('Essayez de changer de catégorie ou de réinitialiser le filtre.')
                  : context.tr('Tous les éléments supprimés depuis Vente, Achat, Client, Fournisseur, Stock et Trésorerie apparaîtront ici.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            if (hasTotalItems) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'Tous';
                  });
                },
                child: Text(context.tr('Réinitialiser les filtres')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemList(bool isMobile, List<TrashItem> items) {
    final canRestore = PermissionService.instance.canCreate(UserPermissionResources.trash) ||
        PermissionService.instance.canUpdate(UserPermissionResources.trash) ||
        PermissionService.instance.isAdmin;
    final canDelete = PermissionService.instance.canDelete(UserPermissionResources.trash) ||
        PermissionService.instance.isAdmin;

    return ListView.separated(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedIds.contains(item.id);
        final catColor = _getCategoryColor(item.category);
        final catIcon = _getCategoryIcon(item.category);

        final dayStr = item.deletedAt.day.toString().padLeft(2, '0');
        final monthStr = item.deletedAt.month.toString().padLeft(2, '0');
        final yearStr = item.deletedAt.year.toString();
        final hourStr = item.deletedAt.hour.toString().padLeft(2, '0');
        final minStr = item.deletedAt.minute.toString().padLeft(2, '0');
        final dateFormatted = '$dayStr/$monthStr/$yearStr $hourStr:$minStr';

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.7),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Selection Checkbox
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(item.id);
                      } else {
                        _selectedIds.remove(item.id);
                      }
                    });
                  },
                ),
                // Category Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(catIcon, color: catColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.subtitle.isNotEmpty) ...[
                            Flexible(
                              child: Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                          ],
                          Icon(Icons.access_time_rounded, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(
                            dateFormatted,
                            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Two Main Required Actions: "Restaurer" & "Supprimer définitivement"
                if (!isMobile) ...[
                  if (canRestore)
                    _buildRestoreButton(
                      onPressed: () => _restoreItem(item),
                    ),
                  if (canRestore && canDelete) const SizedBox(width: 8),
                  if (canDelete)
                    _buildPermanentDeleteButton(
                      onPressed: () => _confirmDeletePermanently(item),
                    ),
                ] else ...[
                  // Mobile icons in sleek soft circular containers
                  if (canRestore)
                    Tooltip(
                      message: context.tr('Restaurer'),
                      child: InkWell(
                        onTap: () => _restoreItem(item),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings_backup_restore_rounded,
                            color: Color(0xFF16A34A),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  if (canRestore && canDelete) const SizedBox(width: 8),
                  if (canDelete)
                    Tooltip(
                      message: context.tr('Supprimer définitivement'),
                      child: InkWell(
                        onTap: () => _confirmDeletePermanently(item),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFDC2626),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
