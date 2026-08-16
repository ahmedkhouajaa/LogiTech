import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/user_management/user_management_bloc.dart';
import '../../blocs/user_management/user_management_event.dart';
import '../../blocs/user_management/user_management_state.dart';
import '../../models/user_management_model.dart';
import '../../services/enterprise_service.dart';
import '../../utils/constants.dart';
import '../../screens/add_edit_user_screen.dart';
import '../../services/permission_service.dart';
import '../widgets/mobile_user_card.dart';

class MobileUserManagementScreen extends StatefulWidget {
  const MobileUserManagementScreen({super.key});

  @override
  State<MobileUserManagementScreen> createState() => _MobileUserManagementScreenState();
}

class _MobileUserManagementScreenState extends State<MobileUserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'Tous';

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
    context.read<UserManagementBloc>().add(
          LoadEnterpriseUsers(
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
            searchQuery: query,
            roleFilter: _selectedRoleFilter,
          ),
        );
  }

  void _onRoleFilterChanged(String role) {
    setState(() => _selectedRoleFilter = role);
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
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const UnauthorizedView(
          message: "L'accès au module de gestion des utilisateurs est strictement réservé aux administrateurs.",
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Gestion des utilisateurs',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadUsers,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: BlocBuilder<UserManagementBloc, UserManagementState>(
        builder: (context, state) {
          bool isCurrentUserAdmin = true;
          if (state is UserManagementLoaded) {
            isCurrentUserAdmin = state.isCurrentUserAdmin;
          }
          if (!isCurrentUserAdmin) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _navigateToAddUser,
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
      body: BlocConsumer<UserManagementBloc, UserManagementState>(
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

          return RefreshIndicator(
            onRefresh: () async => _loadUsers(),
            child: Column(
              children: [
                // Top Search & Filter Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      // Search field
                      SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Rechercher par nom, email...',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Filter chips + Count badge
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['Tous', 'Administrateur', 'Collaborateur'].map((role) {
                                  final isSelected = _selectedRoleFilter == role;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(
                                        role,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                      backgroundColor: AppColors.surface,
                                      labelStyle: TextStyle(
                                        color: isSelected ? const Color(0xFF2563EB) : AppColors.textSecondary,
                                      ),
                                      side: BorderSide(
                                        color: isSelected ? const Color(0xFF2563EB) : AppColors.border,
                                      ),
                                      onSelected: (_) => _onRoleFilterChanged(role),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalCount user${totalCount > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Users list
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredUsers.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_outline_rounded, size: 56, color: AppColors.textTertiary),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aucun utilisateur',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Appuyez sur le bouton + pour inviter un collaborateur.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                return MobileUserCard(
                                  user: user,
                                  onTap: () => _navigateToEditUser(user),
                                  onEdit: () => _navigateToEditUser(user),
                                  onDelete: isCurrentUserAdmin ? () => _confirmDeleteUser(user) : null,
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
