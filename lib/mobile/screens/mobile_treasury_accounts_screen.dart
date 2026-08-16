import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../../widgets/sidebar_menu.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_treasury_account_card.dart';
import '../../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../../models/treasury_account.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobileTreasuryAccountsScreen extends StatefulWidget {
  final Function(BuildContext context, [TreasuryAccount? existing]) showAccountDialog;
  final Function(BuildContext context) showExpenseDialog;
  final Function(BuildContext context, String action, TreasuryAccount account, List<TreasuryAccount> allAccounts) handleAction;

  const MobileTreasuryAccountsScreen({
    super.key,
    required this.showAccountDialog,
    required this.showExpenseDialog,
    required this.handleAction,
  });

  @override
  State<MobileTreasuryAccountsScreen> createState() => _MobileTreasuryAccountsScreenState();
}

class _MobileTreasuryAccountsScreenState extends State<MobileTreasuryAccountsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.accounts);
    _fetchFilteredAccounts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<TreasuryAccountsBloc>().add(LoadNextTreasuryAccounts(
        searchQuery: _searchQuery,
      ));
    }
  }

  void _fetchFilteredAccounts() {
    context.read<TreasuryAccountsBloc>().add(LoadFirstTreasuryAccounts(
      searchQuery: _searchQuery,
    ));
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredAccounts();
  }

  // Uses the existing dialogs from TreasuryAccountsScreen
  // We need to access them via a static method, or replicate them.
  // The easiest way without modifying treasury_accounts_screen heavily is to push a temporary route 
  // or extract the dialogs. However, since the dialogs are private in treasury_accounts_screen.dart,
  // we will have to make them public or duplicate.
  // Actually, we can use the same approach as clients/suppliers if they were public.
  // For now, let's just duplicate the calls if they are private, or I will replace their private names.

  // I will leave this here and handle it by making the dialogs public in treasury_accounts_screen.dart.
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
      builder: (context, state) {
        bool isLoading = state is TreasuryAccountsLoading || state is TreasuryAccountsInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        if (state is TreasuryAccountsLoaded) {
          final items = state.accounts;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((account) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final nameMatch = account.name.toLowerCase().contains(query);
              if (!nameMatch) return false;
            }
            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((account) {
            final isDefault = account.isDefault || account.name.trim().toLowerCase() == 'compte principal';
            return MobileTreasuryAccountCard(
              account: account,
              popupMenu: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                onSelected: (val) {
                  widget.handleAction(context, val, account, items);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'depot', child: Text('Dépôt')),
                  const PopupMenuItem(value: 'transfer', child: Text('Transférer')),
                  if (!isDefault) ...[
                    if (PermissionService.instance.canUpdate(UserPermissionResources.treasuryAccounts)) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    ],
                    if (PermissionService.instance.canDelete(UserPermissionResources.treasuryAccounts)) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: AppColors.error))),
                    ],
                  ],
                ],
              ),
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
                widget.handleAction(context, 'edit', account, items);
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.accounts,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<TreasuryAccountsBloc>().add(ResetTreasuryAccountsPagination(
              searchQuery: _searchQuery,
            ));
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const [],
          selectedFilter: 'Tous',
          onFilterChanged: (_) {},
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun compte trouvé.',
          itemCount: totalMatchingCount,
          customFab: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'add_expense',
                onPressed: () {
                  widget.showExpenseDialog(context);
                },
                icon: const Icon(Icons.attach_money, color: Colors.white),
                label: const Text('Ajouter Dépense', style: TextStyle(color: Colors.white)),
                backgroundColor: AppColors.warning,
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'add_account',
                onPressed: () {
                  widget.showAccountDialog(context);
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Ajouter Compte', style: TextStyle(color: Colors.white)),
                backgroundColor: AppColors.primary,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...cards,
              if (isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}
