import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/checks_traites/checks_traites_bloc.dart';
import 'forms/mobile_check_traite_form_screen.dart';


class MobileChecksTraitesScreen extends StatefulWidget {
  const MobileChecksTraitesScreen({super.key});

  @override
  State<MobileChecksTraitesScreen> createState() => _MobileChecksTraitesScreenState();
}

class _MobileChecksTraitesScreenState extends State<MobileChecksTraitesScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.checksTraites);
    context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
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
              context.read<ChecksTraitesBloc>().add(DeleteCheckTraite(id));
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
    return BlocBuilder<ChecksTraitesBloc, ChecksTraitesState>(
      builder: (context, state) {
        bool isLoading = state is ChecksTraitesLoading || state is ChecksTraitesInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is ChecksTraitesLoaded) {
          final items = state.documents;
          
          final filteredItems = items.where((item) {
            bool matchesSearch = true;
            bool matchesFilter = true;

            String statusStr = 'N/A';
            try {
              final s = (item as dynamic).status;
              if (s != null) {
                try { statusStr = (s as dynamic).label ?? s.toString(); } catch (_) { statusStr = s.toString(); }
              }
            } catch (_) {}

            String reference = '';
            try { reference = ((item as dynamic).number ?? (item as dynamic).reference ?? (item as dynamic).name ?? '').toString(); } catch (_) {}
            
            String name = '';
            try { name = ((item as dynamic).customerName ?? (item as dynamic).supplierName ?? (item as dynamic).companyName ?? (item as dynamic).name ?? '').toString(); } catch (_) {}

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              if (!reference.toLowerCase().contains(query) && !name.toLowerCase().contains(query)) {
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
            String reference = 'N/A';
            try { reference = ((item as dynamic).number ?? (item as dynamic).reference ?? (item as dynamic).name ?? 'N/A').toString(); } catch (_) {}
            
            String status = 'N/A';
            try {
              final s = (item as dynamic).status;
              if (s != null) {
                try { status = (s as dynamic).label ?? s.toString(); } catch (_) { status = s.toString(); }
              }
            } catch (_) {}
            
            String? name;
            try { name = (item as dynamic).customerName ?? (item as dynamic).supplierName ?? (item as dynamic).companyName ?? (item as dynamic).name; } catch (_) {}
            
            DateTime? date;
            try { date = (item as dynamic).date ?? (item as dynamic).createdAt; } catch (_) {}
            
            double amount = 0;
            try { amount = ((item as dynamic).totalTTC ?? (item as dynamic).amount ?? (item as dynamic).price ?? 0.0).toDouble(); } catch (_) {}
            
            String id = '';
            try { id = (item as dynamic).id; } catch (_) {}

            return MobileGenericCard(
              reference: reference,
              status: status,
              name: name,
              date: date,
              amount: amount,
              onTap: () {
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileCheckTraiteFormScreen(existing: item)),
                ).then((_) {
                  context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
                });
              },
              onDelete: () => _handleDelete(id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.checksTraites,
          onModuleSelected: (module) {
          },
          onRefresh: () {
            context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
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
              MaterialPageRoute(builder: (_) => const MobileCheckTraiteFormScreen()),
            ).then((_) {
              context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
            });
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: cards,
          ),
        );
      },
    );
  }
}
