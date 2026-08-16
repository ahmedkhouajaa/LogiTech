import 'package:flutter/material.dart';
import '../models/user_management_model.dart';
import '../utils/constants.dart';

class PermissionsMatrixWidget extends StatelessWidget {
  final Map<String, UserResourcePermission> permissions;
  final ValueChanged<Map<String, UserResourcePermission>> onChanged;
  final bool isReadOnly;

  const PermissionsMatrixWidget({
    super.key,
    required this.permissions,
    required this.onChanged,
    this.isReadOnly = false,
  });

  bool get _isAllSelected {
    for (final res in UserPermissionResources.allResources) {
      final key = res['key'] as String;
      final perm = permissions[key] ?? const UserResourcePermission();
      if (!perm.all) return false;
    }
    return true;
  }

  int get _activeResourcesCount {
    int count = 0;
    for (final res in UserPermissionResources.allResources) {
      final key = res['key'] as String;
      final perm = permissions[key] ?? const UserResourcePermission();
      if (perm.read || perm.create || perm.update || perm.delete) {
        count++;
      }
    }
    return count;
  }

  void _toggleSelectAll() {
    if (isReadOnly) return;
    final selectAll = !_isAllSelected;
    final updated = <String, UserResourcePermission>{};
    for (final res in UserPermissionResources.allResources) {
      final key = res['key'] as String;
      updated[key] = selectAll ? UserResourcePermission.full : UserResourcePermission.empty;
    }
    onChanged(updated);
  }

  void _toggleRowAll(String key) {
    if (isReadOnly) return;
    final current = permissions[key] ?? const UserResourcePermission();
    final setAll = !current.all;
    final updated = Map<String, UserResourcePermission>.from(permissions);
    updated[key] = setAll ? UserResourcePermission.full : UserResourcePermission.empty;
    onChanged(updated);
  }

  void _toggleSingle(String key, String type) {
    if (isReadOnly) return;
    final current = permissions[key] ?? const UserResourcePermission();
    final updated = Map<String, UserResourcePermission>.from(permissions);

    switch (type) {
      case 'read':
        updated[key] = current.copyWith(read: !current.read);
        break;
      case 'create':
        updated[key] = current.copyWith(create: !current.create);
        break;
      case 'update':
        updated[key] = current.copyWith(update: !current.update);
        break;
      case 'delete':
        updated[key] = current.copyWith(delete: !current.delete);
        break;
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        if (isMobile) {
          return _buildMobileLayout(context);
        }
        return _buildDesktopLayout(context);
      },
    );
  }

  // ─── MOBILE VERTICAL CARD-BASED LAYOUT ───────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Permissions',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_activeResourcesCount/${UserPermissionResources.allResources.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Configurez l\'accès par ressource',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isReadOnly)
                ElevatedButton.icon(
                  onPressed: _toggleSelectAll,
                  icon: Icon(
                    _isAllSelected ? Icons.check_box_outlined : Icons.select_all_rounded,
                    size: 15,
                  ),
                  label: Text(
                    _isAllSelected ? 'Décocher' : 'Tout Sélectionner',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAllSelected ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Stacked Vertical Cards for Each Resource (Devis Card Pattern)
        ...UserPermissionResources.allResources.map((res) {
          final key = res['key'] as String;
          final label = res['label'] as String;
          final icon = res['icon'] as IconData;
          final perm = permissions[key] ?? const UserResourcePermission();
          final isAnyActive = perm.read || perm.create || perm.update || perm.delete;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isAnyActive
                    ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                    : AppColors.border,
                width: isAnyActive ? 1.2 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header: Icon + Resource Name + "Tous" Toggle Chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isAnyActive
                            ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                            : (AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: isAnyActive ? const Color(0xFF2563EB) : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // "Tous" Toggle Button
                    if (!isReadOnly)
                      InkWell(
                        onTap: () => _toggleRowAll(key),
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: perm.all
                                ? const Color(0xFF2563EB)
                                : (AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: perm.all ? const Color(0xFF2563EB) : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                perm.all ? Icons.check_rounded : Icons.checklist_rounded,
                                size: 13,
                                color: perm.all ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tous',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: perm.all ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                const SizedBox(height: 10),

                // 4 Horizontal Touch-Friendly Toggle Action Chips (No Horizontal Scrolling)
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileActionChip(
                        label: 'Lire',
                        icon: Icons.visibility_outlined,
                        isActive: perm.read,
                        activeColor: const Color(0xFF10B981),
                        activeBg: const Color(0xFFECFDF5),
                        onTap: () => _toggleSingle(key, 'read'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMobileActionChip(
                        label: 'Créer',
                        icon: Icons.add_circle_outline_rounded,
                        isActive: perm.create,
                        activeColor: const Color(0xFF2563EB),
                        activeBg: const Color(0xFFEFF6FF),
                        onTap: () => _toggleSingle(key, 'create'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMobileActionChip(
                        label: 'Modifier',
                        icon: Icons.edit_outlined,
                        isActive: perm.update,
                        activeColor: const Color(0xFFF59E0B),
                        activeBg: const Color(0xFFFEF3C7),
                        onTap: () => _toggleSingle(key, 'update'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMobileActionChip(
                        label: 'Suppr.',
                        icon: Icons.delete_outline_rounded,
                        isActive: perm.delete,
                        activeColor: const Color(0xFFEF4444),
                        activeBg: const Color(0xFFFEE2E2),
                        onTap: () => _toggleSingle(key, 'delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMobileActionChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color activeBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isReadOnly ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44, // Minimum touch target height
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? (AppColors.isDarkMode ? activeColor.withValues(alpha: 0.2) : activeBg)
              : (AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : AppColors.border,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? icon : icon,
              size: 16,
              color: isActive ? activeColor : AppColors.textTertiary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── DESKTOP TABLE LAYOUT ───────────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title and "Tout Sélectionner" button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Permissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_activeResourcesCount/${UserPermissionResources.allResources.length} ressources configurées',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isReadOnly)
                  OutlinedButton.icon(
                    onPressed: _toggleSelectAll,
                    icon: Icon(
                      _isAllSelected ? Icons.check_box_outlined : Icons.checklist_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      _isAllSelected ? 'Tout Désélectionner' : 'Tout Sélectionner',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),

          // Scrollable permissions table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 700),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                dividerThickness: 0.5,
                dataRowMaxHeight: 52,
                dataRowMinHeight: 48,
                horizontalMargin: 20,
                columnSpacing: 24,
                columns: [
                  DataColumn(
                    label: Text(
                      'Ressource',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  _buildHeaderPillColumn('Lire', const Color(0xFF10B981), const Color(0xFFECFDF5)),
                  _buildHeaderPillColumn('Créer', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                  _buildHeaderPillColumn('Modifier', const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
                  _buildHeaderPillColumn('Supprimer', const Color(0xFFEF4444), const Color(0xFFFEE2E2)),
                  _buildHeaderPillColumn('Tous', AppColors.textSecondary, AppColors.surfaceAlt),
                ],
                rows: UserPermissionResources.allResources.map((res) {
                  final key = res['key'] as String;
                  final label = res['label'] as String;
                  final icon = res['icon'] as IconData;
                  final perm = permissions[key] ?? const UserResourcePermission();

                  return DataRow(
                    cells: [
                      // Resource label + icon
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Lire
                      DataCell(
                        Center(
                          child: _buildCheckbox(
                            value: perm.read,
                            onTap: () => _toggleSingle(key, 'read'),
                          ),
                        ),
                      ),
                      // Créer
                      DataCell(
                        Center(
                          child: _buildCheckbox(
                            value: perm.create,
                            onTap: () => _toggleSingle(key, 'create'),
                          ),
                        ),
                      ),
                      // Modifier
                      DataCell(
                        Center(
                          child: _buildCheckbox(
                            value: perm.update,
                            onTap: () => _toggleSingle(key, 'update'),
                          ),
                        ),
                      ),
                      // Supprimer
                      DataCell(
                        Center(
                          child: _buildCheckbox(
                            value: perm.delete,
                            onTap: () => _toggleSingle(key, 'delete'),
                          ),
                        ),
                      ),
                      // Tous
                      DataCell(
                        Center(
                          child: _buildCheckbox(
                            value: perm.all,
                            onTap: () => _toggleRowAll(key),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildHeaderPillColumn(String label, Color textColor, Color bgColor) {
    return DataColumn(
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox({required bool value, required VoidCallback onTap}) {
    return InkWell(
      onTap: isReadOnly ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value ? const Color(0xFF2563EB) : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            value ? Icons.check_rounded : Icons.close_rounded,
            size: 16,
            color: value ? Colors.white : AppColors.textTertiary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
