import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/shimmer_table_row.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/dashboard_card.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import '../widgets/create_project_dialog.dart';
import '../l10n/app_localizations.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  int _currentPage = 0;
  int _rowsPerPage = 20;
  String _searchQuery = '';
  bool _sortAscending = true;
  String _sortColumn = 'name';

  @override
  void initState() {
    super.initState();
    context.read<ProjectsBloc>().add(LoadProjects());
  }

  void _editProject(Project? p) {
    if (p != null) {
      final isDefault = p.isDefault || p.name.trim().toLowerCase() == 'projet par défaut' || p.name.trim().toLowerCase() == 'projet principal par défaut';
      if (isDefault) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Cet élément est un élément par défaut et ne peut pas être modifié.')),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ProjectsBloc>(),
        child: CreateProjectDialog(project: p),
      ),
    );
  }

  void _deleteProject(Project p) {
    final isDefault = p.isDefault || p.name.trim().toLowerCase() == 'projet par défaut' || p.name.trim().toLowerCase() == 'projet principal par défaut';
    if (isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Cet élément est un élément par défaut et ne peut pas être supprimé.')),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(context.tr('Confirmer la suppression'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${context.tr('Voulez-vous vraiment supprimer le projet')} "${isDefault ? context.tr('Projet par défaut') : p.name}" ?\n${context.tr('Cette action est irréversible.')}', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ProjectsBloc>().add(DeleteProject(p.id));
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('Supprimer')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Projets'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(context.tr('Gérez vos projets et suivez leur avancement'), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              const Spacer(),
              if (PermissionService.instance.canCreate(UserPermissionResources.projects))
                ElevatedButton.icon(
                  onPressed: () => _editProject(null),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.tr('Nouveau Projet'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: SizedBox(
              height: 32,
              child: AppSearchBar(
                onChanged: (v) {
                  setState(() {
                    _searchQuery = v.trim();
                    _currentPage = 0;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              if (state is ProjectsLoading || state is ProjectsInitial) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ShimmerTable(
                    headerColumns: [
                      Expanded(flex: 4, child: Text(context.tr('Nom'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text(context.tr('Statut'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text(context.tr('Date de Création'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      SizedBox(width: 60, child: Text(context.tr('Actions'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                    ],
                  ),
                );
              }
              if (state is ProjectsLoaded) {
                var filteredProjects = state.projects.where((p) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  final nameMatch = p.name.toLowerCase().contains(q);
                  final descMatch = p.description?.toLowerCase().contains(q) ?? false;
                  final statusMatch = p.status.label.toLowerCase().contains(q);
                  return nameMatch || descMatch || statusMatch;
                }).toList();

                filteredProjects.sort((a, b) {
                  int cmp;
                  if (_sortColumn == 'status') {
                    cmp = a.status.label.compareTo(b.status.label);
                  } else if (_sortColumn == 'createdAt') {
                    cmp = a.createdAt.compareTo(b.createdAt);
                  } else {
                    cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  }
                  return _sortAscending ? cmp : -cmp;
                });

                final totalItems = filteredProjects.length;
                final totalPages = (totalItems / _rowsPerPage).ceil() == 0 ? 1 : (totalItems / _rowsPerPage).ceil();
                final startIndex = _currentPage * _rowsPerPage;
                final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                final paginatedProjects = startIndex >= totalItems ? <Project>[] : filteredProjects.sublist(startIndex, endIndex);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                            color: AppColors.surfaceAlt,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortColumn == 'name') {
                                        _sortAscending = !_sortAscending;
                                      } else {
                                        _sortColumn = 'name';
                                        _sortAscending = true;
                                      }
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        context.tr('Nom'),
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _sortColumn == 'name'
                                            ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                            : Icons.unfold_more_rounded,
                                        size: 14,
                                        color: _sortColumn == 'name' ? AppColors.primary : AppColors.textTertiary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortColumn == 'status') {
                                        _sortAscending = !_sortAscending;
                                      } else {
                                        _sortColumn = 'status';
                                        _sortAscending = true;
                                      }
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        context.tr('Statut'),
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _sortColumn == 'status'
                                            ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                            : Icons.unfold_more_rounded,
                                        size: 14,
                                        color: _sortColumn == 'status' ? AppColors.primary : AppColors.textTertiary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_sortColumn == 'createdAt') {
                                        _sortAscending = !_sortAscending;
                                      } else {
                                        _sortColumn = 'createdAt';
                                        _sortAscending = true;
                                      }
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        context.tr('Date de Création'),
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _sortColumn == 'createdAt'
                                            ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                            : Icons.unfold_more_rounded,
                                        size: 14,
                                        color: _sortColumn == 'createdAt' ? AppColors.primary : AppColors.textTertiary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  context.tr('Actions'),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table body
                        Expanded(
                          child: paginatedProjects.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.folder_open_outlined, size: 40, color: AppColors.border),
                                      const SizedBox(height: 12),
                                      Text(
                                        context.tr('Aucun projet'),
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: paginatedProjects.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border),
                                  itemBuilder: (context, index) {
                                    final p = paginatedProjects[index];
                                    final isDefault = p.isDefault || p.name.trim().toLowerCase() == 'projet par défaut' || p.name.trim().toLowerCase() == 'projet principal par défaut';
                                    final displayName = isDefault && (p.name.trim().toLowerCase() == 'projet par défaut' || p.name.trim().toLowerCase() == 'projet principal par défaut')
                                        ? context.tr('Projet par défaut')
                                        : p.name;
                                    final displayDesc = isDefault && p.description != null && (p.description!.trim().toLowerCase() == 'projet principal par défaut' || p.description!.trim().toLowerCase() == 'projet par défaut')
                                        ? context.tr('Projet principal par défaut')
                                        : p.description;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withValues(alpha: 0.3),
                                      child: Row(
                                        children: [
                                          // Column 1: Nom & Description (flex: 4)
                                          Expanded(
                                            flex: 4,
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 20),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              displayName,
                                                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (isDefault) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(Icons.lock_rounded, size: 10, color: AppColors.primary),
                                                                  const SizedBox(width: 2),
                                                                  Text(
                                                                    context.tr('Par défaut'),
                                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      if (displayDesc != null && displayDesc.isNotEmpty)
                                                        Text(
                                                          displayDesc,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Column 2: Statut (flex: 2)
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: StatusBadge(label: p.status.label, color: AppColors.primary),
                                            ),
                                          ),

                                          // Column 3: Date de Création (flex: 2)
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              formatDateTime(p.createdAt),
                                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                            ),
                                          ),

                                          // Column 4: Actions (SizedBox 60)
                                          SizedBox(
                                            width: 60,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: PopupMenuButton<String>(
                                                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                color: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                onSelected: (value) {
                                                  if (value == 'voir' || value == 'modifier') {
                                                    _editProject(p);
                                                  } else if (value == 'supprimer') {
                                                    _deleteProject(p);
                                                  }
                                                },
                                                itemBuilder: (context) {
                                                  final canRead = PermissionService.instance.canRead(UserPermissionResources.projects);
                                                  final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.projects);
                                                  final canDelete = PermissionService.instance.canDelete(UserPermissionResources.projects);

                                                  final entries = <PopupMenuEntry<String>>[];

                                                  if (canRead) {
                                                    entries.add(
                                                      PopupMenuItem(
                                                        value: 'voir',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.visibility_outlined, size: 18, color: AppColors.textSecondary),
                                                            const SizedBox(width: 8),
                                                            Text(context.tr('Voir')),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  if (!isDefault) {
                                                    if (canUpdate) {
                                                      entries.add(
                                                        PopupMenuItem(
                                                          value: 'modifier',
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                                              const SizedBox(width: 8),
                                                              Text(context.tr('Modifier')),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    if (canDelete) {
                                                      entries.add(
                                                        PopupMenuItem(
                                                          value: 'supprimer',
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                                              const SizedBox(width: 8),
                                                              Text(context.tr('Supprimer'), style: TextStyle(color: AppColors.error)),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  } else {
                                                    entries.add(
                                                      PopupMenuItem(
                                                        enabled: false,
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.lock_rounded, size: 16, color: AppColors.textTertiary),
                                                            const SizedBox(width: 8),
                                                            Text(context.tr('Élément protégé'), style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  return entries;
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // Bottom Pagination Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border)),
                            color: AppColors.surfaceAlt,
                          ),
                          child: Row(
                            children: [
                              Text(context.tr('Lignes'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: const SizedBox(),
                                  icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                  items: [20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text(v.toString()))).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _rowsPerPage = v;
                                        _currentPage = 0;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 20),
                              Text(
                                '${context.tr('Page')} ${_currentPage + 1} ${context.tr('sur')} $totalPages',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const Spacer(),
                              Text(
                                totalItems == 0
                                    ? '${context.tr('Affichage de')} 0 ${context.tr('à')} 0 ${context.tr('sur')} 0 ${context.tr('résultats')}'
                                    : '${context.tr('Affichage de')} ${startIndex + 1} ${context.tr('à')} $endIndex ${context.tr('sur')} $totalItems ${context.tr('résultats')}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_left, size: 18, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage < totalPages - 1 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_right, size: 18, color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }
}
