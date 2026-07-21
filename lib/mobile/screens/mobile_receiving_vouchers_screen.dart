import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import 'forms/mobile_receiving_voucher_form_screen.dart';
import 'mobile_receiving_voucher_detail_screen.dart';


class MobileReceivingVouchersScreen extends StatefulWidget {
  const MobileReceivingVouchersScreen({super.key});

  @override
  State<MobileReceivingVouchersScreen> createState() => _MobileReceivingVouchersScreenState();
}

class _MobileReceivingVouchersScreenState extends State<MobileReceivingVouchersScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.receivingVouchers);
    context.read<ReceivingVouchersBloc>().add(LoadReceivingVouchers());
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
    
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReceivingVouchersBloc, ReceivingVouchersState>(
      builder: (context, state) {
        bool isLoading = state is ReceivingVouchersLoading || state is ReceivingVouchersInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is ReceivingVouchersLoaded) {
          final items = state.vouchers;
          
          final filteredItems = items.where((item) {
            bool matchesSearch = true;
            bool matchesFilter = true;

            String statusStr = 'N/A';
            try {
              final s = (item as dynamic).status;
              if (s != null) {
                statusStr = translateStatus(s.toString());
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
                status = translateStatus(s.toString());
              }
            } catch (_) {}
            
            String? name;
            try { name = (item as dynamic).customerName ?? (item as dynamic).supplierName ?? (item as dynamic).companyName ?? (item as dynamic).name; } catch (_) {}
            
            DateTime? date;
            try { date = (item as dynamic).date ?? (item as dynamic).createdAt; } catch (_) {}
            
            double amount = 0;
            try { amount = (item as dynamic).totalTTC?.toDouble() ?? (item as dynamic).totalTTC.toDouble(); } catch (_) {}
            if (amount == 0) {
              try { amount = (item as dynamic).amount?.toDouble() ?? (item as dynamic).amount.toDouble(); } catch (_) {}
            }
            if (amount == 0) {
              try { amount = (item as dynamic).price?.toDouble() ?? (item as dynamic).price.toDouble(); } catch (_) {}
            }
            
            String id = '';
            try { id = (item as dynamic).id; } catch (_) {}

            return MobileGenericCard(
              reference: reference,
              status: status,
              name: name,
              date: date,
              amount: amount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileReceivingVoucherDetailScreen(voucher: item)),
                );
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileReceivingVoucherFormScreen(existing: item)),
                ).then((_) {
                  context.read<ReceivingVouchersBloc>().add(LoadReceivingVouchers());
                });
              },
              onDelete: null,
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.receivingVouchers,
          onModuleSelected: (module) {
          },
          onRefresh: () {
            context.read<ReceivingVouchersBloc>().add(LoadReceivingVouchers());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: _config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun élément trouvé.',
          itemCount: cards.length,
          fabText: _config.fabText,
          onFabPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MobileReceivingVoucherFormScreen()),
              ).then((_) {
                context.read<ReceivingVouchersBloc>().add(LoadReceivingVouchers());
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
