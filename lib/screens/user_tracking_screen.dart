import 'package:flutter/material.dart';
import '../models/user_activity_log.dart';
import '../models/user_management_model.dart';
import '../services/user_tracking_service.dart';
import '../services/permission_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class UserTrackingScreen extends StatefulWidget {
  const UserTrackingScreen({super.key});

  @override
  State<UserTrackingScreen> createState() => _UserTrackingScreenState();
}

class _UserTrackingScreenState extends State<UserTrackingScreen> {
  String? _selectedUserId;
  String _selectedAction = 'all';
  String _selectedModule = 'all';
  String _selectedDatePeriod = 'all'; // all, today, 7days, 30days
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<EnterpriseUserModel> _enterpriseUsers = [];

  final List<Map<String, dynamic>> _actionFilters = [
    {'id': 'all', 'label': 'Toutes', 'icon': Icons.tune_rounded, 'color': AppColors.textSecondary},
    {'id': 'create', 'label': 'Créations', 'icon': Icons.add_circle_outline_rounded, 'color': const Color(0xFF16A34A)},
    {'id': 'update', 'label': 'Modifications', 'icon': Icons.edit_outlined, 'color': const Color(0xFF2563EB)},
    {'id': 'delete', 'label': 'Corbeille', 'icon': Icons.delete_outline_rounded, 'color': const Color(0xFFEA580C)},
    {'id': 'delete_permanent', 'label': 'Suppressions déf.', 'icon': Icons.delete_forever_rounded, 'color': const Color(0xFFDC2626)},
    {'id': 'restore', 'label': 'Restaurations', 'icon': Icons.settings_backup_restore_rounded, 'color': const Color(0xFF0D9488)},
  ];

  final List<String> _moduleFilters = [
    'all',
    'Ventes',
    'Achats',
    'Articles',
    'Clients',
    'Fournisseurs',
    'Stock',
    'Trésorerie',
    'Paiements',
    'Corbeille',
    'Paramètres',
  ];

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

  Future<void> _loadUsers() async {
    try {
      final users = await UserTrackingService.instance.getEnterpriseUsers();
      if (mounted) {
        setState(() {
          _enterpriseUsers = users;
        });
      }
    } catch (_) {}
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'create':
        return const Color(0xFF16A34A); // Emerald green
      case 'update':
        return const Color(0xFF2563EB); // Royal Blue
      case 'delete':
        return const Color(0xFFEA580C); // Warm Orange (Corbeille)
      case 'delete_permanent':
        return const Color(0xFFDC2626); // Crimson Red
      case 'restore':
      case 'restore_all':
        return const Color(0xFF0D9488); // Teal
      case 'empty_trash':
        return const Color(0xFFB91C1C); // Deep Red
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline_rounded;
      case 'update':
        return Icons.edit_note_rounded;
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'delete_permanent':
        return Icons.delete_forever_rounded;
      case 'restore':
      case 'restore_all':
        return Icons.settings_backup_restore_rounded;
      case 'empty_trash':
        return Icons.auto_delete_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'create':
        return 'Création';
      case 'update':
        return 'Modification';
      case 'delete':
        return 'Mise en corbeille';
      case 'delete_permanent':
        return 'Suppression définitive';
      case 'restore':
        return 'Restauration';
      case 'restore_all':
        return 'Restauration totale';
      case 'empty_trash':
        return 'Corbeille vidée';
      default:
        return action;
    }
  }

  Color _getModuleColor(String module) {
    switch (module) {
      case 'Ventes':
        return const Color(0xFF2563EB);
      case 'Achats':
        return const Color(0xFFEA580C);
      case 'Articles':
        return const Color(0xFF0D9488);
      case 'Clients':
        return const Color(0xFF7C3AED);
      case 'Fournisseurs':
        return const Color(0xFF0891B2);
      case 'Stock':
        return const Color(0xFFD97706);
      case 'Trésorerie':
        return const Color(0xFF059669);
      case 'Paiements':
      case 'Retenue à la source':
        return const Color(0xFF0284C7);
      case 'Corbeille':
        return const Color(0xFFDC2626);
      case 'Paramètres':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Aujourd\'hui à $h:$m';
    } else if (diff.inDays < 2) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Hier à $h:$m';
    } else {
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$d/$mo/$y à $h:$m';
    }
  }

  bool _matchesDateFilter(DateTime dt) {
    if (_selectedDatePeriod == 'all') return true;
    final now = DateTime.now();
    if (_selectedDatePeriod == 'today') {
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } else if (_selectedDatePeriod == '7days') {
      return now.difference(dt).inDays <= 7;
    } else if (_selectedDatePeriod == '30days') {
      return now.difference(dt).inDays <= 30;
    }
    return true;
  }

  void _showActivityDetails(UserActivityLog log) {
    final actionColor = _getActionColor(log.action);
    final moduleColor = _getModuleColor(log.module);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_getActionIcon(log.action), color: actionColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getActionLabel(log.action),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.module,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: moduleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Description', log.description, isBold: true),
                const Divider(height: 20),
                _buildDetailRow('Utilisateur', '${log.userName} (${log.userEmail.isNotEmpty ? log.userEmail : 'N/A'})'),
                _buildDetailRow('Rôle', log.userRole.toUpperCase()),
                _buildDetailRow('Date & Heure', _formatTimestamp(log.timestamp)),
                _buildDetailRow('Horodatage exact', log.timestamp.toIso8601String()),
                if (log.documentReference.isNotEmpty)
                  _buildDetailRow('Référence document', log.documentReference),
                if (log.collection.isNotEmpty)
                  _buildDetailRow('Collection Firestore', log.collection),
                if (log.documentId.isNotEmpty)
                  _buildDetailRow('ID Document', log.documentId),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Données détaillées',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: log.details!.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${e.key}: ${e.value}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('Fermer'), style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAccess = PermissionService.instance.isAdmin ||
        PermissionService.instance.canRead(UserPermissionResources.userTracking);

    if (!canAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline_rounded, size: 52, color: AppColors.error),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('Accès Restreint'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr("Vous n'avez pas l'autorisation d'accéder à la traçabilité des utilisateurs.\nContactez votre administrateur dans la gestion des utilisateurs."),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(isMobile),

          // Filters Card
          _buildFiltersSection(isMobile),

          // Streamed Activity List
          Expanded(
            child: StreamBuilder<List<UserActivityLog>>(
              stream: UserTrackingService.instance.getActivitiesStream(
                userId: _selectedUserId,
                module: _selectedModule == 'all' ? null : _selectedModule,
                action: _selectedAction == 'all' ? null : _selectedAction,
                limit: 250,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Erreur lors du chargement des activités',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final rawList = snapshot.data ?? [];

                // Apply client-side filters (search query & date period)
                final filtered = rawList.where((log) {
                  if (!_matchesDateFilter(log.timestamp)) return false;

                  if (_searchQuery.trim().isNotEmpty) {
                    final q = _searchQuery.toLowerCase().trim();
                    final matchName = log.userName.toLowerCase().contains(q);
                    final matchEmail = log.userEmail.toLowerCase().contains(q);
                    final matchDesc = log.description.toLowerCase().contains(q);
                    final matchRef = log.documentReference.toLowerCase().contains(q);
                    final matchModule = log.module.toLowerCase().contains(q);
                    final matchAction = log.action.toLowerCase().contains(q);
                    if (!matchName && !matchEmail && !matchDesc && !matchRef && !matchModule && !matchAction) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(rawList.isNotEmpty);
                }

                return _buildActivityList(filtered, isMobile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.manage_history_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Traçabilité Utilisateurs'),
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('Journal d\'audit et suivi des actions des utilisateurs en temps réel'),
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: User Dropdown & Search & Period
          if (isMobile) ...[
            _buildUserDropdown(),
            const SizedBox(height: 10),
            _buildSearchField(),
            const SizedBox(height: 10),
            _buildPeriodDropdown(),
          ] else ...[
            Row(
              children: [
                Expanded(flex: 3, child: _buildUserDropdown()),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: _buildSearchField()),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildPeriodDropdown()),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Row 2: Action Filters Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _actionFilters.map((af) {
                final isSelected = _selectedAction == af['id'];
                final color = af['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAction = isSelected && af['id'] != 'all' ? 'all' : (af['id'] as String);
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? color : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              af['icon'] as IconData,
                              size: 15,
                              color: isSelected ? color : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              af['label'] as String,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? color : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Module Filters Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _moduleFilters.map((mod) {
                final isSelected = _selectedModule == mod;
                final label = mod == 'all' ? 'Tous les modules' : mod;
                final color = mod == 'all' ? AppColors.primary : _getModuleColor(mod);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedModule = mod);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? color : AppColors.border.withValues(alpha: 0.6),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.14),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? color : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedUserId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          hint: Row(
            children: [
              Icon(Icons.people_outline_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tous les utilisateurs',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.all_inclusive_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Tous les utilisateurs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ..._enterpriseUsers.map((u) {
              final uid = u.uid;
              final name = u.name.isNotEmpty ? u.name : (u.email.isNotEmpty ? u.email : 'Utilisateur');
              final role = u.role;
              return DropdownMenuItem<String?>(
                value: uid,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$name ($role)',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (val) {
            setState(() => _selectedUserId = val);
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher par mot-clé, référence...',
          hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
        onChanged: (val) {
          setState(() => _searchQuery = val);
        },
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDatePeriod,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Toutes les dates', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'today', child: Text('Aujourd\'hui', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: '7days', child: Text('7 derniers jours', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: '30days', child: Text('30 derniers jours', style: TextStyle(fontSize: 13))),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedDatePeriod = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildActivityList(List<UserActivityLog> logs, bool isMobile) {
    return ListView.separated(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = logs[index];
        final actionColor = _getActionColor(log.action);
        final moduleColor = _getModuleColor(log.module);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showActivityDetails(log),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Action Icon Badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: isMobile ? 18 : 22,
                          backgroundColor: moduleColor.withValues(alpha: 0.12),
                          child: Text(
                            log.userName.isNotEmpty ? log.userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: moduleColor,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: actionColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 1.5),
                            ),
                            child: Icon(_getActionIcon(log.action), color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Main Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: User name, role badge, timestamp
                          Row(
                            children: [
                              Text(
                                log.userName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  log.userRole.toLowerCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimestamp(log.timestamp),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Description
                          Text(
                            log.description,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Bottom Badges: Module & Action & Document Reference
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Module badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: moduleColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.module,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: moduleColor,
                                  ),
                                ),
                              ),

                              // Action badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: actionColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_getActionIcon(log.action), size: 12, color: actionColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getActionLabel(log.action),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: actionColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Reference badge
                              if (log.documentReference.isNotEmpty &&
                                  log.documentReference != log.description)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    log.documentReference,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool hasOtherRecords) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasOtherRecords
                  ? 'Aucune activité ne correspond à vos filtres'
                  : 'Aucune activité enregistrée pour le moment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasOtherRecords
                  ? 'Essayez d\'élargir vos critères de recherche ou de réinitialiser les filtres.'
                  : 'Les actions effectuées par les utilisateurs (ajouts, modifications, suppressions) apparaîtront ici automatiquement.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasOtherRecords) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedUserId = null;
                    _selectedAction = 'all';
                    _selectedModule = 'all';
                    _selectedDatePeriod = 'all';
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Réinitialiser les filtres'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
