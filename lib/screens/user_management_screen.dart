import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/user_management/user_management_bloc.dart';
import '../blocs/user_management/user_management_event.dart';
import '../blocs/user_management/user_management_state.dart';
import '../models/user_management_model.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../services/permission_service.dart';
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row (Image 1 style)
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
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$totalCount utilisateur${totalCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
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
                      label: const Text('Ajouter un Utilisateur', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter & Search Bar
              Container(
                padding: const EdgeInsets.all(16),
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
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un utilisateur (nom, email, téléphone)...',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Role Filter Chips
                    Row(
                      children: ['Tous', 'Administrateur', 'Collaborateur'].map((role) {
                        final isSelected = _selectedRoleFilter == role;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(role, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundColor: AppColors.surface,
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
                    const SizedBox(width: 12),

                    // Refresh Button
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
                      onPressed: _loadUsers,
                      tooltip: 'Actualiser la liste',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Desktop Table Container (Image 1 style)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.sm,
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (filteredUsers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: AppColors.textTertiary),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Aucun utilisateur trouvé',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ajoutez des collaborateurs pour leur donner accès à votre entreprise.',
                                    style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 800),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                                  dividerThickness: 0.5,
                                  dataRowMaxHeight: 64,
                                  dataRowMinHeight: 56,
                                  horizontalMargin: 20,
                                  columnSpacing: 24,
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        'Nom',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Rôle',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Numéro de Téléphone',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Entreprises',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Actions',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                  rows: pageUsers.map((user) {
                                    return DataRow(
                                      cells: [
                                        // Nom + Email
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    user.name,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  if (user.isOwner) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFEF3C7),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'Propriétaire',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFFD97706),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                user.email,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Rôle (Image 1 style pill)
                                        DataCell(
                                          user.isAdmin
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF2563EB),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Administrateur',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppColors.border),
                                                  ),
                                                  child: Text(
                                                    'Collaborateur',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        // Numéro de Téléphone
                                        DataCell(
                                          Text(
                                            (user.phone != null && user.phone!.isNotEmpty) ? user.phone! : '-',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: (user.phone != null && user.phone!.isNotEmpty)
                                                  ? AppColors.textPrimary
                                                  : AppColors.textTertiary,
                                            ),
                                          ),
                                        ),
                                        // Entreprises
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.people_outline, size: 16, color: AppColors.textSecondary),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${user.enterprises.isNotEmpty ? user.enterprises.length : 1}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Actions (3-dots Popup Menu)
                                        DataCell(
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
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
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                                    SizedBox(width: 10),
                                                    Text('Modifier'),
                                                  ],
                                                ),
                                              ),
                                              if (!user.isOwner && isCurrentUserAdmin)
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                                      const SizedBox(width: 10),
                                                      Text('Supprimer de l\'entreprise', style: TextStyle(color: AppColors.error)),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                          // Pagination Footer (Image 1 style)
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                // Rows per page
                                Text('Lignes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _rowsPerPage,
                                      isDense: true,
                                      items: [10, 20, 50, 100]
                                          .map((v) => DropdownMenuItem(value: v, child: Text('$v', style: const TextStyle(fontSize: 13))))
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
                                const SizedBox(width: 24),

                                // Page indicator
                                Text(
                                  'Page ${_currentPage + 1} sur $totalPages',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 24),

                                // Affichage summary
                                Expanded(
                                  child: Text(
                                    totalCount == 0
                                        ? 'Aucun résultat'
                                        : 'Affichage de ${startIdx + 1} à $endIdx sur $totalCount résultats',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ),

                                // Previous and Next page buttons
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  iconSize: 20,
                                  color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary,
                                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  iconSize: 20,
                                  color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary,
                                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
