import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/projects/projects_bloc.dart';
import 'forms/mobile_project_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';


class MobileProjectsScreen extends StatefulWidget {
  const MobileProjectsScreen({super.key});

  @override
  State<MobileProjectsScreen> createState() => _MobileProjectsScreenState();
}

class _MobileProjectsScreenState extends State<MobileProjectsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.projects);
    context.read<ProjectsBloc>().add(LoadProjects());
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _handleDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet élément ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              context.read<ProjectsBloc>().add(DeleteProject(id));
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectsBloc, ProjectsState>(
      builder: (context, state) {
        bool isLoading = state is ProjectsLoading || state is ProjectsInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is ProjectsLoaded) {
          final items = state.projects;
          
          final filteredItems = items.where((item) {
            bool matchesSearch = true;
            bool matchesFilter = true;

            String statusStr = translateStatus(item.status.name);

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final nameMatch = item.name.toLowerCase().contains(query);
              final descMatch = item.description?.toLowerCase().contains(query) ?? false;
              final custMatch = item.customerName?.toLowerCase().contains(query) ?? false;
              if (!nameMatch && !descMatch && !custMatch) {
                matchesSearch = false;
              }
            }

            if (_selectedFilter != 'Tous') {
              if (statusStr.toLowerCase() != _selectedFilter.toLowerCase()) {
                matchesFilter = false;
              }
            }

            return matchesSearch && matchesFilter;
          }).toList();
          
          isEmpty = filteredItems.isEmpty;
          
          cards = filteredItems.map((item) {
            final isDefault = item.isDefault ||
                item.name.trim().toLowerCase() == 'projet par défaut' ||
                item.name.trim().toLowerCase() == 'projet principal par défaut';
            String reference = item.name.isNotEmpty ? item.name : 'Projet sans nom';
            
            String status = item.status.name;
            String? description = item.description;
            
            DateTime date = item.startDate;
            double budget = item.budget;
            String id = item.id;

            return MobileGenericCard(
              reference: reference,
              status: status,
              badgeText: isDefault ? 'Par défaut' : null,
              name: description != null && description.isNotEmpty ? description : 'Budget: ${budget.toStringAsFixed(2)} TND',
              date: date,
              amount: budget > 0 ? budget : null,
              onTap: () {
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileProjectFormScreen(existing: item)),
                ).then((_) {
                  context.read<ProjectsBloc>().add(LoadProjects());
                });
              },
              onEdit: (!isDefault && PermissionService.instance.canUpdate(UserPermissionResources.projects))
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MobileProjectFormScreen(existing: item)),
                      ).then((_) {
                        context.read<ProjectsBloc>().add(LoadProjects());
                      });
                    }
                  : null,
              onDelete: (!isDefault && PermissionService.instance.canDelete(UserPermissionResources.projects))
                  ? () => _handleDelete(id)
                  : null,
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.projects,
          onModuleSelected: (module) {
          },
          onRefresh: () {
            context.read<ProjectsBloc>().add(LoadProjects());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: _config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun élément trouvé.',
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileProjectFormScreen()),
            ).then((_) {
              context.read<ProjectsBloc>().add(LoadProjects());
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          ),
        );
      },
    );
  }
}
