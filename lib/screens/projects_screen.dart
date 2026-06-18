import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

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
              AppButton(label: 'Nouveau projet', icon: Icons.add_rounded, onPressed: () {}),
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
                      columns: const ['Nom', 'Client', 'Statut', 'Budget', 'Date Debut', 'Date Fin'],
                      rows: state.projects,
                      emptyMessage: 'Aucun projet',
                      cellBuilder: (p) => [
                        DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(p.customerName ?? '—')),
                        DataCell(StatusBadge(label: p.status.label, color: AppColors.primary)),
                        DataCell(Text(formatCurrency(p.budget), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(formatDate(p.startDate))),
                        DataCell(Text(p.endDate != null ? formatDate(p.endDate!) : '—')),
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
