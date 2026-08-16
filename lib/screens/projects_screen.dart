import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import '../widgets/create_project_dialog.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProjectsBloc>().add(LoadProjects());
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProjectsBloc>(),
        child: const CreateProjectDialog(),
      ),
    );
  }
  void _editProject(Project? p) {
    if (p != null) {
      final isDefault = p.isDefault || p.name.trim().toLowerCase() == 'projet par défaut' || p.name.trim().toLowerCase() == 'projet principal par défaut';
      if (isDefault) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cet élément est un élément par défaut et ne peut pas être modifié.'),
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
          content: const Text('Cet élément est un élément par défaut et ne peut pas être supprimé.'),
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
        title: Text('Confirmer la suppression', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer le projet "${p.name}" ?\nCette action est irréversible.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
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
            child: Text('Supprimer'),
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
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Projets', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Gérez vos projets et suivez leur avancement', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              Spacer(),
              if (PermissionService.instance.canCreate(UserPermissionResources.projects))
                ElevatedButton.icon(
                  onPressed: () => _editProject(null),
                  icon: Icon(Icons.add_rounded, size: 18),
                  label: Text('Nouveau Projet'),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: AppSearchBar(onChanged: (v) {}),
          ),
        ),
        Expanded(
          child: BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              if (state is ProjectsLoading || state is ProjectsInitial) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ShimmerTable(
                    headerColumns: [
                      const SizedBox(width: 32),
                      Expanded(flex: 3, child: Text('Nom du Projet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Date de Creation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                      SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                    ],
                  ),
                );
              }
              if (state is ProjectsLoaded) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Project>(
                      columns: const ['Nom', 'Statut', 'Date de Création', 'Actions'],
                      rows: state.projects,
                      emptyMessage: 'Aucun projet',
                      cellBuilder: (p) {
                        final isDefault = p.isDefault || p.name.trim().toLowerCase() == 'projet par défaut' || p.name.trim().toLowerCase() == 'projet principal par défaut';
                        return [
                          DataCell(
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 20),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                          if (isDefault) ...[
                                            SizedBox(width: 6),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.lock_rounded, size: 10, color: AppColors.primary),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'Par défaut',
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (p.description != null && p.description!.isNotEmpty)
                                        Text(p.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(StatusBadge(label: p.status.label, color: AppColors.primary)),
                          DataCell(Text(formatDateTime(p.createdAt), style: TextStyle(color: AppColors.textSecondary))),
                          DataCell(
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onSelected: (value) {
                                if (value == 'voir') {
                                  _editProject(p);
                                } else if (value == 'modifier') {
                                  _editProject(p);
                                } else if (value == 'supprimer') {
                                  _deleteProject(p);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'voir',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 18, color: AppColors.textSecondary),
                                      SizedBox(width: 8),
                                      Text('Voir'),
                                    ],
                                  ),
                                ),
                                if (!isDefault) ...[
                                  if (PermissionService.instance.canUpdate(UserPermissionResources.projects))
                                    PopupMenuItem(
                                      value: 'modifier',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                          SizedBox(width: 8),
                                          Text('Modifier'),
                                        ],
                                      ),
                                    ),
                                  if (PermissionService.instance.canDelete(UserPermissionResources.projects))
                                    PopupMenuItem(
                                      value: 'supprimer',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                          SizedBox(width: 8),
                                          Text('Supprimer', style: TextStyle(color: AppColors.error)),
                                        ],
                                      ),
                                    ),
                                ] else ...[
                                  PopupMenuItem(
                                    enabled: false,
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock_rounded, size: 16, color: AppColors.textTertiary),
                                        SizedBox(width: 8),
                                        Text('Élément protégé', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                );
              }
              return SizedBox();
            },
          ),
        ),
      ],
    );
  }
}
