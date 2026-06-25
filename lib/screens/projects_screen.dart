import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

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

  void _editProject(Project p) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProjectsBloc>(),
        child: CreateProjectDialog(project: p),
      ),
    );
  }

  void _deleteProject(Project p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Confirmer la suppression', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer le projet "${p.name}" ?\nCette action est irréversible.', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
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
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppSearchBar(onChanged: (v) {}),
              const Spacer(),
              AppButton(label: 'Ajouter un Projet', icon: Icons.add_rounded, onPressed: _showCreateDialog),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              if (state is ProjectsLoading) return const Center(child: CircularProgressIndicator());
              if (state is ProjectsLoaded) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Project>(
                      columns: const ['Nom', 'Statut', 'Date de Création', 'Actions'],
                      rows: state.projects,
                      emptyMessage: 'Aucun projet',
                      cellBuilder: (p) => [
                        DataCell(
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                    if (p.description != null && p.description!.isNotEmpty)
                                      Text(p.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(StatusBadge(label: p.status.label, color: AppColors.primary)),
                        DataCell(Text(formatDateTime(p.createdAt), style: const TextStyle(color: AppColors.textSecondary))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.textSecondary),
                                onPressed: () => _editProject(p),
                                splashRadius: 20,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, size: 20, color: AppColors.error),
                                onPressed: () => _deleteProject(p),
                                splashRadius: 20,
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
