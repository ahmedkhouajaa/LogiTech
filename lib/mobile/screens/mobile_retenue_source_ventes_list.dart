import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_retenue_source_vente_card.dart';
import '../widgets/mobile_tej_export_dialog.dart';
import '../../blocs/retenue_source_vente/retenue_source_vente_bloc.dart';
import '../../database/database_helper.dart';
import '../../utils/constants.dart';
import '../../widgets/sidebar_menu.dart';
import '../../services/permission_service.dart';
import '../../models/retenue_source_vente.dart';
import '../../models/user_management_model.dart';

class MobileRetenueSourceVentesList extends StatefulWidget {
  final MobileModuleConfig config;
  final bool isSales;

  const MobileRetenueSourceVentesList({super.key, required this.config, required this.isSales});

  @override
  State<MobileRetenueSourceVentesList> createState() => _MobileRetenueSourceVentesListState();
}

class _MobileRetenueSourceVentesListState extends State<MobileRetenueSourceVentesList> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<RetenueSourceVenteBloc>().add(
      ResetRetenueSourceVentesPagination(
        searchQuery: _searchQuery,
        statusFilter: _selectedFilter,
        isSales: widget.isSales,
      )
    );
  }

  @override
  void didUpdateWidget(MobileRetenueSourceVentesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSales != widget.isSales) {
      context.read<RetenueSourceVenteBloc>().add(
        ResetRetenueSourceVentesPagination(
          searchQuery: _searchQuery,
          statusFilter: _selectedFilter,
          isSales: widget.isSales,
        )
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      final state = context.read<RetenueSourceVenteBloc>().state;
      if (state is RetenueSourceVenteLoaded && state.hasMore && !state.isLoadingMore) {
        context.read<RetenueSourceVenteBloc>().add(
          LoadNextRetenueSourceVentes(
            searchQuery: _searchQuery,
            statusFilter: _selectedFilter,
            isSales: widget.isSales,
          )
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    context.read<RetenueSourceVenteBloc>().add(
      ResetRetenueSourceVentesPagination(
        searchQuery: _searchQuery,
        statusFilter: _selectedFilter,
        isSales: widget.isSales,
      )
    );
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    context.read<RetenueSourceVenteBloc>().add(
      ResetRetenueSourceVentesPagination(
        searchQuery: _searchQuery,
        statusFilter: _selectedFilter,
        isSales: widget.isSales,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RetenueSourceVenteBloc, RetenueSourceVenteState>(
      builder: (context, state) {
        bool isLoading = state is RetenueSourceVenteLoading || state is RetenueSourceVenteInitial;
        bool isEmpty = true;
        int count = 0;
        List<Widget> cards = [];

        if (state is RetenueSourceVenteLoaded) {
          isEmpty = state.retenues.isEmpty;
          count = state.totalCount;

          final canDelete = PermissionService.instance.canDelete(widget.isSales ? UserPermissionResources.withholdingTaxSales : UserPermissionResources.withholdingTaxPurchases) ||
              PermissionService.instance.canDelete(UserPermissionResources.withholdingTax) ||
              PermissionService.instance.isAdmin;

          cards = state.retenues.map<Widget>((retenue) {
            return MobileRetenueSourceVenteCard(
              retenue: retenue,
              isSales: widget.isSales,
              onTap: () {
                // Navigation to details
              },
              onDelete: canDelete ? () => _confirmDeleteRetenue(retenue) : null,
            );
          }).toList();

          if (state.isLoadingMore) {
            cards.add(const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ));
          }
        }

        return MobileGenericListScreen(
          title: widget.config.title,
          subtitle: widget.config.subtitle,
          activeModule: widget.isSales ? AppModule.withholdingTaxSales : AppModule.withholdingTaxPurchase,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<RetenueSourceVenteBloc>().add(
              ResetRetenueSourceVentesPagination(
                searchQuery: _searchQuery,
                statusFilter: _selectedFilter,
                isSales: widget.isSales,
              )
            );
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: widget.config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucune retenue à la source trouvée.',
          itemCount: count,
          scrollController: _scrollController,
          customFab: PermissionService.instance.canCreate(UserPermissionResources.importExport)
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final payments = await DatabaseHelper.instance.getPayments();
                    if (context.mounted) {
                      MobileTejExportDialog.show(
                        context,
                        payments: payments,
                        isSales: widget.isSales,
                      );
                    }
                  },
                  icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                  label: const Text('Exporter TEJ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: AppColors.primary,
                )
              : null,
          child: Column(
            children: cards,
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteRetenue(RetenueSourceVente retenue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Supprimer la retenue ?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous supprimer cette retenue à la source (${retenue.invoiceReference}) ? Elle sera déplacée dans la corbeille.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<RetenueSourceVenteBloc>().add(
        DeleteRetenueSourceVente(retenue.id, isSales: widget.isSales),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Retenue à la source déplacée dans la corbeille.'),
          backgroundColor: AppColors.surfaceAlt,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
