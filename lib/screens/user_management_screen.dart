import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/user_management/user_management_bloc.dart';
import '../blocs/user_management/user_management_event.dart';
import '../blocs/user_management/user_management_state.dart';
import '../models/user_management_model.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../services/permission_service.dart';
import '../widgets/shimmer_table_row.dart';
import '../widgets/shimmer_effect.dart';
import 'add_edit_user_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'Tous';
  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    context.read<UserManagementBloc>().add(
          LoadEnterpriseUsers(
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
            searchQuery: _searchController.text,
            roleFilter: _selectedRoleFilter,
          ),
        );
  }

  void _onSearchChanged(String query) {
    setState(() => _currentPage = 0);
    context.read<UserManagementBloc>().add(
          LoadEnterpriseUsers(
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
            searchQuery: query,
            roleFilter: _selectedRoleFilter,
          ),
        );
  }

  void _onRoleFilterChanged(String role) {
    setState(() {
      _selectedRoleFilter = role;
      _currentPage = 0;
    });
    context.read<UserManagementBloc>().add(
          LoadEnterpriseUsers(
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
            searchQuery: _searchController.text,
            roleFilter: role,
          ),
        );
  }

  void _navigateToAddUser() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddEditUserScreen()))
        .then((_) => _loadUsers());
  }

  void _navigateToEditUser(EnterpriseUserModel user) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => AddEditUserScreen(userToEdit: user)))
        .then((_) => _loadUsers());
  }

  void _confirmDeleteUser(EnterpriseUserModel user) {
    final currentEid = EnterpriseService.instance.currentEnterpriseId;
    if (currentEid == null) return;

    if (user.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Impossible de supprimer le propriétaire de l\'entreprise.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment retirer "${user.name}" de cette entreprise ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<UserManagementBloc>().add(
                    RemoveEnterpriseUserEvent(
                      enterpriseId: currentEid,
                      targetUid: user.uid,
                    ),
                  );
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
    if (!PermissionService.instance.isAdmin) {
      return const UnauthorizedView(
        message: "L'accès au module de gestion des utilisateurs est strictement réservé aux administrateurs.",
      );
    }
    return BlocConsumer<UserManagementBloc, UserManagementState>(
      listener: (context, state) {
        if (state is UserOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        } else if (state is UserOperationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is UserManagementLoading;
        List<EnterpriseUserModel> filteredUsers = [];
        bool isCurrentUserAdmin = true;

        if (state is UserManagementLoaded) {
          filteredUsers = state.filteredUsers;
          isCurrentUserAdmin = state.isCurrentUserAdmin;
        }

        final totalCount = filteredUsers.length;
        final totalPages = (_rowsPerPage > 0) ? (totalCount / _rowsPerPage).ceil().clamp(1, 9999) : 1;
        final startIdx = _currentPage * _rowsPerPage;
        final endIdx = (startIdx + _rowsPerPage).clamp(0, totalCount);
        final pageUsers = (startIdx < totalCount) ? filteredUsers.sublist(startIdx, endIdx) : <EnterpriseUserModel>[];

        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Gestion des Utilisateurs',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalCount utilisateur${totalCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isCurrentUserAdmin)
                    ElevatedButton.icon(
                      onPressed: _navigateToAddUser,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter un Utilisateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Filter & Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.sm,
                ),
                child: Row(
                  children: [
                    // Search Input
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un utilisateur (nom, email, téléphone)...',
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                            prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppColors.textTertiary),
                            prefixIconConstraints: const BoxConstraints(minWidth: 32),
                            filled: true,
                            fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Role Filter Chips
                    Row(
                      children: ['Tous', 'Administrateur', 'Collaborateur'].map((role) {
                        final isSelected = _selectedRoleFilter == role;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(role, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundColor: AppColors.surface,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            ),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.border,
                            ),
                            onSelected: (_) => _onRoleFilterChanged(role),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 8),

                    // Refresh Button
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _loadUsers,
                      tooltip: 'Actualiser la liste',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Full Card Table Container
              Expanded(
                child: isLoading
                    ? ShimmerTable(
                        rowCount: 12,
                        headerColumns: [
                          Expanded(flex: 3, child: Text('Nom', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                          Expanded(flex: 2, child: Container(alignment: Alignment.centerLeft, child: Text('Rôle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)))),
                          Expanded(flex: 2, child: Text('Numéro de Téléphone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                          Expanded(flex: 2, child: Text('Entreprises', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                          SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        ],
                        rowBuilder: (index) => ShimmerTableRow.custom(
                          isEven: index % 2 == 0,
                          cells: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShimmerBox(width: index % 2 == 0 ? 140 : 120, height: 12, borderRadius: 3),
                                  const SizedBox(height: 3),
                                  ShimmerBox(width: index % 2 == 0 ? 170 : 150, height: 10, borderRadius: 3),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: ShimmerBox(width: index % 2 == 0 ? 95 : 85, height: 20, borderRadius: 4),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: ShimmerBox(width: 100, height: 12, borderRadius: 3),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: ShimmerBox(width: 35, height: 12, borderRadius: 3),
                              ),
                            ),
                            const SizedBox(
                              width: 60,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: ShimmerBox(width: 18, height: 14, borderRadius: 3),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.sm,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Sticky Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: AppColors.border)),
                                  color: AppColors.background,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('Nom', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                    Expanded(flex: 2, child: Container(alignment: Alignment.centerLeft, child: Text('Rôle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)))),
                                    Expanded(flex: 2, child: Text('Numéro de Téléphone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                    Expanded(flex: 2, child: Text('Entreprises', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                    SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                                  ],
                                ),
                              ),

                              // Table Body
                              Expanded(
                                child: pageUsers.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.people_outline, size: 40, color: AppColors.border),
                                            const SizedBox(height: 12),
                                            Text('Aucun utilisateur trouvé', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                            const SizedBox(height: 4),
                                            Text('Ajoutez des collaborateurs pour leur donner accès à votre entreprise.', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: pageUsers.length,
                                        separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border),
                                        itemBuilder: (context, index) {
                                          final user = pageUsers[index];
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            color: index % 2 == 0 ? AppColors.surface : AppColors.background.withValues(alpha: 0.3),
                                            child: Row(
                                              children: [
                                                // Nom + Email + Owner Badge
                                                Expanded(
                                                  flex: 3,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              user.name,
                                                              style: TextStyle(
                                                                fontSize: 12.5,
                                                                fontWeight: FontWeight.w600,
                                                                color: AppColors.textPrimary,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (user.isOwner) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFEF3C7),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Text(
                                                                'Propriétaire',
                                                                style: TextStyle(
                                                                  fontSize: 9.5,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Color(0xFFD97706),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 1),
                                                      Text(
                                                        user.email,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Rôle
                                                Expanded(
                                                  flex: 2,
                                                  child: Container(
                                                    alignment: Alignment.centerLeft,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: user.isAdmin
                                                            ? const Color(0xFF2563EB)
                                                            : (AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFE2E8F0)),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        user.isAdmin ? 'Administrateur' : 'Collaborateur',
                                                        style: TextStyle(
                                                          color: user.isAdmin ? Colors.white : AppColors.textPrimary,
                                                          fontSize: 11,
                                                          fontWeight: user.isAdmin ? FontWeight.bold : FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // Numéro de Téléphone
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    (user.phone != null && user.phone!.isNotEmpty) ? user.phone! : '-',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: (user.phone != null && user.phone!.isNotEmpty)
                                                          ? AppColors.textPrimary
                                                          : AppColors.textTertiary,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),

                                                // Entreprises
                                                Expanded(
                                                  flex: 2,
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '${user.enterprises.isNotEmpty ? user.enterprises.length : 1}',
                                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Actions
                                                SizedBox(
                                                  width: 60,
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: PopupMenuButton<String>(
                                                      icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                      color: AppColors.surface,
                                                      onSelected: (val) {
                                                        if (val == 'edit') {
                                                          _navigateToEditUser(user);
                                                        } else if (val == 'delete') {
                                                          _confirmDeleteUser(user);
                                                        }
                                                      },
                                                      itemBuilder: (ctx) => [
                                                        const PopupMenuItem(
                                                          value: 'edit',
                                                          height: 34,
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                                                              SizedBox(width: 8),
                                                              Text('Modifier les accès', style: TextStyle(fontSize: 12)),
                                                            ],
                                                          ),
                                                        ),
                                                        if (!user.isOwner && isCurrentUserAdmin)
                                                          PopupMenuItem(
                                                            value: 'delete',
                                                            height: 34,
                                                            child: Row(
                                                              children: [
                                                                Icon(Icons.delete_outline, size: 15, color: AppColors.error),
                                                                const SizedBox(width: 8),
                                                                Text('Retirer de l\'entreprise', style: TextStyle(color: AppColors.error, fontSize: 12)),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),

                              // Sticky Pagination Footer
                              Divider(height: 1, color: AppColors.border),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                color: AppColors.background,
                                child: Row(
                                  children: [
                                    Text('Lignes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 28,
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _rowsPerPage,
                                          isDense: true,
                                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                          items: [20, 50, 100]
                                              .map((v) => DropdownMenuItem(value: v, child: Text('$v', style: const TextStyle(fontSize: 12))))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _rowsPerPage = val;
                                                _currentPage = 0;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Text('Page ${_currentPage + 1} sur $totalPages', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    const Spacer(),
                                    Text(
                                      totalCount == 0 ? '0 résultats' : 'Affichage de ${startIdx + 1} à $endIdx sur $totalCount résultats',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
