import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import 'forms/mobile_supplier_form_screen.dart';


class MobileSuppliersScreen extends StatefulWidget {
  const MobileSuppliersScreen({super.key});

  @override
  State<MobileSuppliersScreen> createState() => _MobileSuppliersScreenState();
}

class _MobileSuppliersScreenState extends State<MobileSuppliersScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.suppliers);
    context.read<SuppliersBloc>().add(LoadSuppliers());
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
              context.read<SuppliersBloc>().add(DeleteSupplier(id));
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
    return BlocBuilder<SuppliersBloc, SuppliersState>(
      builder: (context, state) {
        bool isLoading = state is SuppliersLoading || state is SuppliersInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is SuppliersLoaded) {
          final items = state.suppliers;
          
          final filteredItems = items.where((supplier) {
            bool matchesSearch = true;
            bool matchesFilter = true;

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final name = supplier.name.toLowerCase();
              final code = supplier.code.toLowerCase();
              final phone = (supplier.phone ?? '').toLowerCase();
              final email = (supplier.email ?? '').toLowerCase();
              if (!name.contains(query) && !code.contains(query) && !phone.contains(query) && !email.contains(query)) {
                matchesSearch = false;
              }
            }

            // No specific filter needed for 'Tous' since we removed 'Actif'/'Inactif'

            return matchesSearch && matchesFilter;
          }).toList();
          
          isEmpty = filteredItems.isEmpty;
          
          cards = filteredItems.map((supplier) {
            final avatarInitial = supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // Detail screen if needed
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            avatarInitial,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tag, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(supplier.code, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  ],
                                ),
                                if (supplier.email != null && supplier.email!.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(supplier.email!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                if (supplier.phone != null && supplier.phone!.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(supplier.phone!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Balance & Actions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Dette', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: supplier.balance >= 0 ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${supplier.balance.toStringAsFixed(2)} TND',
                              style: TextStyle(
                                color: supplier.balance >= 0 ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                        onSelected: (val) {
                          if (val == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MobileSupplierFormScreen(existing: supplier)),
                            ).then((_) {
                              context.read<SuppliersBloc>().add(LoadSuppliers());
                            });
                          } else if (val == 'delete') {
                            _handleDelete(supplier.id);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20, color: AppColors.primary), SizedBox(width: 8), Text('Modifier')])),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 20, color: AppColors.error), SizedBox(width: 8), Text('Supprimer')])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.suppliers,
          onModuleSelected: (module) {},
          onRefresh: () {
            context.read<SuppliersBloc>().add(LoadSuppliers());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const [], // Supplier does not have active/inactive status in model
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun fournisseur trouvé.',
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileSupplierFormScreen()),
            ).then((_) {
              context.read<SuppliersBloc>().add(LoadSuppliers());
            });
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: 80),
            children: cards,
          ),
        );
      },
    );
  }
}
