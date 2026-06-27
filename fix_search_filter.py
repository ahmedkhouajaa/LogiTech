import os

base_dir = "d:/LogiTech/lib/mobile/screens"
os.makedirs(base_dir, exist_ok=True)

configs = [
    # Sales
    ("quotes", "Quotes", "quote", "QuotesLoaded", "LoadQuotes", "quotes", "DeleteQuote", "AppModule.quotes", "CreateQuoteScreen()"),
    ("customer_orders", "CustomerOrders", "order", "CustomerOrdersLoaded", "LoadCustomerOrders", "orders", "DeleteCustomerOrder", "AppModule.customerOrders", "CreateCustomerOrderScreen()"),
    ("delivery_notes", "DeliveryNotes", "note", "DeliveryNotesLoaded", "LoadDeliveryNotes", "notes", "DeleteDeliveryNote", "AppModule.deliveryNotes", "CreateDeliveryNoteScreen()"),
    ("invoices", "Invoices", "invoice", "InvoicesLoaded", "LoadInvoices", "invoices", "DeleteInvoice", "AppModule.invoices", "CreateInvoiceScreen()"),
    ("stock_withdrawals", "StockWithdrawals", "withdrawal", "StockWithdrawalsLoaded", "LoadStockWithdrawals", "withdrawals", "DeleteStockWithdrawal", "AppModule.exitVouchers", "CreateStockWithdrawalScreen()"),
    ("credit_notes", "CreditNotes", "note", "CreditNotesLoaded", "LoadCreditNotes", "creditNotes", "DeleteCreditNote", "AppModule.creditNotes", "Container()"),
    ("return_notes", "ReturnNotes", "note", "ReturnNotesLoaded", "LoadReturnNotes", "notes", "DeleteReturnNote", "AppModule.returnVouchers", "CreateReturnNoteScreen()"),
    
    # Purchases
    ("supplier_orders", "SupplierOrders", "order", "SupplierOrdersLoaded", "LoadSupplierOrders", "orders", "DeleteSupplierOrder", "AppModule.supplierOrders", "CreateSupplierOrderScreen()"),
    ("receiving_vouchers", "ReceivingVouchers", "voucher", "ReceivingVouchersLoaded", "LoadReceivingVouchers", "vouchers", "LoadReceivingVouchers", "AppModule.receivingVouchers", "CreateReceivingVoucherScreen()"),
    ("purchase_invoices", "PurchaseInvoices", "invoice", "PurchaseInvoicesLoaded", "LoadPurchaseInvoices", "purchaseInvoices", "DeletePurchaseInvoice", "AppModule.purchaseInvoices", "CreatePurchaseInvoiceScreen()"),
    ("supplier_credit_notes", "SupplierCreditNotes", "note", "SupplierCreditNotesLoaded", "LoadSupplierCreditNotes", "creditNotes", "DeleteSupplierCreditNote", "AppModule.supplierCreditNotes", "CreateSupplierCreditNoteScreen()"),
    ("supplier_returns", "SupplierReturns", "returnNote", "SupplierReturnsLoaded", "LoadSupplierReturns", "returns", "DeleteSupplierReturn", "AppModule.supplierReturns", "CreateSupplierReturnScreen()"),
    
    # Others
    ("payments", "Payments", "payment", "PaymentsLoaded", "LoadPayments", "payments", "DeletePayment", "AppModule.payments", "Container()"),
    ("treasury_transactions", "TreasuryTransactions", "transaction", "TreasuryTransactionsLoaded", "LoadTreasuryTransactions", "transactions", "DeleteTreasuryTransaction", "AppModule.transactions", "Container()"),
    ("checks_traites", "ChecksTraites", "check", "ChecksTraitesLoaded", "LoadChecksTraites", "documents", "DeleteCheckTraite", "AppModule.checksTraites", "Container()"),
    ("customers", "Customers", "customer", "CustomersLoaded", "LoadCustomers", "customers", "DeleteCustomer", "AppModule.customers", "Container()"),
    ("suppliers", "Suppliers", "supplier", "SuppliersLoaded", "LoadSuppliers", "suppliers", "DeleteSupplier", "AppModule.suppliers", "Container()"),
    ("products", "Products", "product", "ProductsLoaded", "LoadProducts", "products", "DeleteProduct", "AppModule.products", "Container()"),
    ("stock", "Stock", "item", "StockLoaded", "LoadStock", "movements", "LoadStock", "AppModule.stockDashboard", "Container()"),
    ("projects", "Projects", "project", "ProjectsLoaded", "LoadProjects", "projects", "DeleteProject", "AppModule.projects", "Container()"),
]

template = '''import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/{bloc_file}/{bloc_file}_bloc.dart';
{extra_imports}

class Mobile{bloc_class}Screen extends StatefulWidget {{
  const Mobile{bloc_class}Screen({{super.key}});

  @override
  State<Mobile{bloc_class}Screen> createState() => _Mobile{bloc_class}ScreenState();
}}

class _Mobile{bloc_class}ScreenState extends State<Mobile{bloc_class}Screen> {{
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {{
    super.initState();
    _config = MobileModuleConfig.getConfig({module_enum});
    context.read<{bloc_class}Bloc>().add({event_load}());
  }}

  void _onSearchChanged(String query) {{
    setState(() {{
      _searchQuery = query;
    }});
  }}

  void _onFilterChanged(String filter) {{
    setState(() {{
      _selectedFilter = filter;
    }});
  }}

  void _handleDelete(String id) {{
    {delete_logic}
  }}

  @override
  Widget build(BuildContext context) {{
    return BlocBuilder<{bloc_class}Bloc, {bloc_class}State>(
      builder: (context, state) {{
        bool isLoading = state is {bloc_class}Loading || state is {bloc_class}Initial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is {state_loaded}) {{
          final items = state.{state_list_prop};
          
          final filteredItems = items.where((item) {{
            bool matchesSearch = true;
            bool matchesFilter = true;

            String statusStr = 'N/A';
            try {{
              final s = (item as dynamic).status;
              if (s != null) {{
                try {{ statusStr = (s as dynamic).label ?? s.toString(); }} catch (_) {{ statusStr = s.toString(); }}
              }}
            }} catch (_) {{}}

            String reference = '';
            try {{ reference = ((item as dynamic).number ?? (item as dynamic).reference ?? (item as dynamic).name ?? '').toString(); }} catch (_) {{}}
            
            String name = '';
            try {{ name = ((item as dynamic).customerName ?? (item as dynamic).supplierName ?? (item as dynamic).companyName ?? (item as dynamic).name ?? '').toString(); }} catch (_) {{}}

            if (_searchQuery.isNotEmpty) {{
              final query = _searchQuery.toLowerCase();
              if (!reference.toLowerCase().contains(query) && !name.toLowerCase().contains(query)) {{
                matchesSearch = false;
              }}
            }}

            if (_selectedFilter != 'Tous') {{
               if (statusStr.toLowerCase() != _selectedFilter.toLowerCase()) {{
                   matchesFilter = false;
               }}
            }}

            return matchesSearch && matchesFilter;
          }}).toList();
          
          isEmpty = filteredItems.isEmpty;
          
          cards = filteredItems.map((item) {{
            String reference = 'N/A';
            try {{ reference = ((item as dynamic).number ?? (item as dynamic).reference ?? (item as dynamic).name ?? 'N/A').toString(); }} catch (_) {{}}
            
            String status = 'N/A';
            try {{
              final s = (item as dynamic).status;
              if (s != null) {{
                try {{ status = (s as dynamic).label ?? s.toString(); }} catch (_) {{ status = s.toString(); }}
              }}
            }} catch (_) {{}}
            
            String? name;
            try {{ name = (item as dynamic).customerName ?? (item as dynamic).supplierName ?? (item as dynamic).companyName ?? (item as dynamic).name; }} catch (_) {{}}
            
            DateTime? date;
            try {{ date = (item as dynamic).date ?? (item as dynamic).createdAt; }} catch (_) {{}}
            
            double amount = 0;
            try {{ amount = ((item as dynamic).totalTTC ?? (item as dynamic).amount ?? (item as dynamic).price ?? 0.0).toDouble(); }} catch (_) {{}}
            
            String id = '';
            try {{ id = (item as dynamic).id; }} catch (_) {{}}

            return MobileGenericCard(
              reference: reference,
              status: status,
              name: name,
              date: date,
              amount: amount,
              onTap: () {{
              }},
              onEdit: () {{
              }},
              onDelete: {on_delete_callback},
            );
          }}).toList();
        }}

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: {module_enum},
          onModuleSelected: (module) {{
          }},
          onRefresh: () {{
            context.read<{bloc_class}Bloc>().add({event_load}());
          }},
          onSearchChanged: _onSearchChanged,
          filterOptions: _config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun élément trouvé.',
          fabText: _config.fabText,
          onFabPressed: {on_fab_pressed},
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: cards,
          ),
        );
      }},
    );
  }}
}}
'''

import re

for item in configs:
    bloc_file = item[0]
    bloc_class = item[1]
    model_name = item[2]
    state_loaded = item[3]
    event_load = item[4]
    state_list_prop = item[5]
    event_delete = item[6]
    module_enum = item[7]
    screen_create = item[8]
    
    extra_imports = ""
    state_file = f"d:/LogiTech/lib/blocs/{bloc_file}/{bloc_file}_state.dart"
    event_file = f"d:/LogiTech/lib/blocs/{bloc_file}/{bloc_file}_event.dart"
    if os.path.exists(state_file):
        extra_imports += f"import '../../blocs/{bloc_file}/{bloc_file}_state.dart';\n"
    if os.path.exists(event_file):
        extra_imports += f"import '../../blocs/{bloc_file}/{bloc_file}_event.dart';\n"
        
    on_fab_pressed = "() {}"
    if screen_create != "Container()":
        screen_class = screen_create.replace("()", "")
        import_file_snake = re.sub(r'(?<!^)(?=[A-Z])', '_', screen_class).lower()
        extra_imports += f"import '../../screens/{import_file_snake}.dart';\n"
        on_fab_pressed = f'''() {{
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const {screen_class}()),
              ).then((_) {{
                context.read<{bloc_class}Bloc>().add({event_load}());
              }});
            }}'''
        
    delete_logic = ""
    on_delete_callback = "() => _handleDelete(id)"
    if event_delete == event_load: 
        on_delete_callback = "null"
    else:
        delete_logic = f'''showDialog(
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
            onPressed: () {{
              context.read<{bloc_class}Bloc>().add({event_delete}(id));
              Navigator.pop(ctx);
            }},
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );'''
        
    file_name = f"mobile_{bloc_file}_screen.dart"
    if bloc_file == "treasury_transactions":
        file_name = "mobile_transactions_screen.dart"
    
    file_path = os.path.join(base_dir, file_name)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(template.format(
            bloc_file=bloc_file,
            bloc_class=bloc_class,
            state_loaded=state_loaded,
            state_list_prop=state_list_prop,
            event_load=event_load,
            event_delete=event_delete,
            module_enum=module_enum,
            screen_create=screen_create,
            extra_imports=extra_imports,
            delete_logic=delete_logic,
            on_delete_callback=on_delete_callback,
            on_fab_pressed=on_fab_pressed
        ))

print("Screens successfully rewritten with fix")

