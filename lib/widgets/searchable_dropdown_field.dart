import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/project.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../models/treasury_account.dart';
import '../models/transaction_category.dart';
import '../models/stock_movement.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/stock/stock_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../blocs/warehouses/warehouses_event.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SearchableSelectorField extends StatelessWidget {
  final String hint;
  final String? selectedText;
  final VoidCallback onTap;
  final bool hasError;

  const SearchableSelectorField({
    super.key,
    required this.hint,
    required this.selectedText,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: selectedText ?? hint),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: Icon(Icons.arrow_drop_down_rounded, size: 24, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: hasError ? AppColors.error : AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: hasError ? AppColors.error : AppColors.border),
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

Future<String?> showCustomerSelectDialog(
  BuildContext context,
  List<Customer> initialCustomers, {
  String? selectedCustomerId,
}) async {
  try {
    context.read<CustomersBloc>().add(LoadCustomers());
  } catch (_) {}

  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              final customers = state is CustomersLoaded ? state.customers : initialCustomers;
              final query = search.trim().toLowerCase();
              final filtered = customers.where((c) {
            if (query.isEmpty) return true;
            final nameMatch = c.name.toLowerCase().contains(query);
            final companyMatch = c.companyName?.toLowerCase().contains(query) ?? false;
            final respMatch = c.responsibleName?.toLowerCase().contains(query) ?? false;
            final codeMatch = c.code.toLowerCase().contains(query);
            final phoneMatch = c.phone?.toLowerCase().contains(query) ?? false;
            return nameMatch || companyMatch || respMatch || codeMatch || phoneMatch;
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 440,
              constraints: const BoxConstraints(maxHeight: 520),
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sélectionner un client',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un client...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucun client trouvé',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final customer = filtered[index];
                              final isSelected = customer.id == selectedCustomerId;
                              final displayName = customer.companyName?.isNotEmpty == true
                                  ? customer.companyName!
                                  : (customer.responsibleName?.isNotEmpty == true
                                      ? customer.responsibleName!
                                      : customer.name);

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (customer.code.isNotEmpty) 'Code: ${customer.code}',
                                    if (customer.phone?.isNotEmpty ?? false) 'Tél: ${customer.phone!}',
                                    if (customer.taxId?.isNotEmpty ?? false) 'MF: ${customer.taxId!}',
                                    if (customer.city?.isNotEmpty ?? false) customer.city!,
                                  ].join(' • '),
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(customer.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
},
);
}

Future<Map<String, dynamic>?> showContactSelectDialog(
  BuildContext context, {
  List<Customer> customers = const [],
  List<Supplier> suppliers = const [],
  String? selectedContactId,
}) async {
  return showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = search.trim().toLowerCase();
          
          final filteredCustomers = customers.where((c) {
            if (query.isEmpty) return true;
            final nameMatch = c.name.toLowerCase().contains(query);
            final companyMatch = c.companyName?.toLowerCase().contains(query) ?? false;
            final codeMatch = c.code.toLowerCase().contains(query);
            return nameMatch || companyMatch || codeMatch;
          }).toList();

          final filteredSuppliers = suppliers.where((s) {
            if (query.isEmpty) return true;
            final nameMatch = s.name.toLowerCase().contains(query);
            final companyMatch = s.companyName?.toLowerCase().contains(query) ?? false;
            final codeMatch = s.code.toLowerCase().contains(query);
            return nameMatch || companyMatch || codeMatch;
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 460,
              constraints: const BoxConstraints(maxHeight: 520),
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sélectionner un contact',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un client ou fournisseur...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  Flexible(
                    child: (filteredCustomers.isEmpty && filteredSuppliers.isEmpty)
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucun contact trouvé',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              if (filteredCustomers.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                                  child: Text('CLIENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ),
                                ...filteredCustomers.map((customer) {
                                  final isSelected = customer.id == selectedContactId;
                                  return ListTile(
                                    dense: true,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                    selected: isSelected,
                                    selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      child: Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                                    ),
                                    title: Text(
                                      customer.name,
                                      style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                                    ),
                                    subtitle: customer.phone != null ? Text('Tél: ${customer.phone}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)) : null,
                                    trailing: isSelected ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary) : null,
                                    onTap: () => Navigator.of(context).pop({'id': customer.id, 'name': customer.name, 'type': 'customer'}),
                                  );
                                }),
                              ],
                              if (filteredSuppliers.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                                  child: Text('FOURNISSEURS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning)),
                                ),
                                ...filteredSuppliers.map((supplier) {
                                  final isSelected = supplier.id == selectedContactId;
                                  return ListTile(
                                    dense: true,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                    selected: isSelected,
                                    selectedTileColor: AppColors.warning.withValues(alpha: 0.08),
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                                      child: Icon(Icons.factory_rounded, size: 14, color: AppColors.warning),
                                    ),
                                    title: Text(
                                      supplier.name,
                                      style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                                    ),
                                    subtitle: supplier.phone != null ? Text('Tél: ${supplier.phone}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)) : null,
                                    trailing: isSelected ? Icon(Icons.check_rounded, size: 18, color: AppColors.warning) : null,
                                    onTap: () => Navigator.of(context).pop({'id': supplier.id, 'name': supplier.name, 'type': 'supplier'}),
                                  );
                                }),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showProjectSelectDialog(
  BuildContext context,
  List<Project> initialProjects, {
  String? selectedProjectId,
}) async {
  try {
    context.read<ProjectsBloc>().add(LoadProjects());
  } catch (_) {}

  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              final projects = state is ProjectsLoaded ? state.projects : initialProjects;
              final query = search.trim().toLowerCase();
              final filtered = projects.where((p) {
            if (query.isEmpty) return true;
            final nameMatch = p.name.toLowerCase().contains(query);
            final descMatch = p.description?.toLowerCase().contains(query) ?? false;
            final custMatch = p.customerName?.toLowerCase().contains(query) ?? false;
            return nameMatch || descMatch || custMatch;
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 440,
              constraints: const BoxConstraints(maxHeight: 520),
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sélectionner un projet',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un projet...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    selected: selectedProjectId == null,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                    title: Text(
                      'Projet par defaut',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selectedProjectId == null ? FontWeight.bold : FontWeight.w500,
                        color: selectedProjectId == null ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    trailing: selectedProjectId == null
                        ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop('__default__');
                    },
                  ),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucun projet trouvé',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final project = filtered[index];
                              final isSelected = project.id == selectedProjectId;

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                title: Text(
                                  project.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: project.customerName != null
                                    ? Text(
                                        'Client: ${project.customerName}',
                                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                      )
                                    : null,
                                trailing: isSelected
                                    ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(project.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
},
);
}

Future<String?> showSupplierSelectDialog(
  BuildContext context,
  List<Supplier> suppliers, {
  String? selectedSupplierId,
}) async {
  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = search.trim().toLowerCase();
          final filtered = suppliers.where((s) {
            if (query.isEmpty) return true;
            final nameMatch = s.name.toLowerCase().contains(query);
            final companyMatch = s.companyName?.toLowerCase().contains(query) ?? false;
            final respMatch = s.responsibleName?.toLowerCase().contains(query) ?? false;
            final codeMatch = s.code.toLowerCase().contains(query);
            final phoneMatch = s.phone?.toLowerCase().contains(query) ?? false;
            return nameMatch || companyMatch || respMatch || codeMatch || phoneMatch;
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 440,
              constraints: const BoxConstraints(maxHeight: 520),
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sélectionner un fournisseur',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un fournisseur...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucun fournisseur trouvé',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final supplier = filtered[index];
                              final isSelected = supplier.id == selectedSupplierId;
                              final displayName = supplier.companyName?.isNotEmpty == true
                                  ? supplier.companyName!
                                  : (supplier.responsibleName?.isNotEmpty == true
                                      ? supplier.responsibleName!
                                      : supplier.name);

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (supplier.code.isNotEmpty) 'Code: ${supplier.code}',
                                    if (supplier.phone?.isNotEmpty ?? false) 'Tél: ${supplier.phone!}',
                                    if (supplier.taxId?.isNotEmpty ?? false) 'MF: ${supplier.taxId!}',
                                    if (supplier.city?.isNotEmpty ?? false) supplier.city!,
                                  ].join(' • '),
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(supplier.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showProductSelectDialog(
  BuildContext context,
  List<Product> products, {
  String? selectedProductId,
  String? warehouseId,
  Map<String, double>? warehouseStockMap,
}) async {
  Map<String, double> computedStockMap = warehouseStockMap ?? {};
  if (warehouseStockMap == null) {
    try {
      final stockState = context.read<StockBloc>().state;
      if (stockState is StockLoaded) {
        bool isWarehouseDefault = false;
        if (warehouseId != null && warehouseId.isNotEmpty) {
          try {
            isWarehouseDefault = stockState.warehouses.firstWhere((w) => w.id == warehouseId).isDefault;
          } catch (_) {}
        }
        for (var p in products) {
          double stock = 0.0;
          if (warehouseId == null || warehouseId.isEmpty) {
            stock = p.stockQty;
          } else {
            for (var m in stockState.movements) {
              if (m.productId == p.id) {
                final isWarehouseMatch = m.warehouseId == warehouseId || (m.warehouseId == 'default_warehouse' && isWarehouseDefault);
                if (isWarehouseMatch) {
                  if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
                    stock += m.quantity;
                  } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
                    stock -= m.quantity;
                  }
                }
              }
            }
          }
          computedStockMap[p.id] = stock;
        }
      }
    } catch (_) {}
  }

  try {
    context.read<ProductsBloc>().add(LoadProducts());
  } catch (_) {}

  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              final isLoaded = state is ProductsLoaded;
              final currentProducts = isLoaded ? state.products : products;

              if (!isLoaded) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  backgroundColor: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text("Chargement des articles...", style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }

              final query = search.trim().toLowerCase();
              final filtered = currentProducts.where((p) {
            if (query.isEmpty) return true;
            final nameMatch = p.name.toLowerCase().contains(query);
            final codeMatch = p.code.toLowerCase().contains(query);
            final refMatch = p.reference?.toLowerCase().contains(query) ?? false;
            final barcodeMatch = p.barcode?.toLowerCase().contains(query) ?? false;
            return nameMatch || codeMatch || refMatch || barcodeMatch;
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 560),
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sélectionner un article',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, code, référence...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucun article trouvé',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              final isSelected = product.id == selectedProductId;
                              final displayStock = computedStockMap.containsKey(product.id)
                                  ? computedStockMap[product.id]!
                                  : product.stockQty;

                              final stockBg = AppColors.textTertiary.withValues(alpha: 0.12);
                              final stockFg = AppColors.textSecondary;

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                title: Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Row(
                                    children: [
                                      if (product.code.isNotEmpty || (product.reference?.isNotEmpty ?? false))
                                        Flexible(
                                          child: Text(
                                            [
                                              if (product.code.isNotEmpty) 'Code: ${product.code}',
                                              if (product.reference?.isNotEmpty ?? false) 'Réf: ${product.reference}',
                                            ].join(' • '),
                                            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      if (product.code.isNotEmpty || (product.reference?.isNotEmpty ?? false))
                                        const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: stockBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Stock: ${displayStock.toStringAsFixed(displayStock.truncateToDouble() == displayStock ? 0 : 1)} ${product.unit}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: stockFg,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${product.sellingPrice.toStringAsFixed(3)} DT',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      SizedBox(width: 8),
                                      Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).pop(product.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
            },
          );
        },
      );
    },
  );
}

Future<String?> showTreasuryAccountSelectDialog(
  BuildContext context,
  List<TreasuryAccount> accounts, {
  String? selectedAccountId,
  bool includeAll = false,
}) async {
  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = search.trim().toLowerCase();
          final filtered = accounts.where((a) {
            if (query.isEmpty) return true;
            return a.name.toLowerCase().contains(query) ||
                (a.bankName?.toLowerCase().contains(query) ?? false) ||
                (a.iban?.toLowerCase().contains(query) ?? false);
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 480,
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sélectionner un compte',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un compte (nom, banque, IBAN)...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  if (includeAll && query.isEmpty) ...[
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      selected: selectedAccountId == 'all',
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                      leading: Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primary),
                      title: Text(
                        'Tous les Comptes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selectedAccountId == 'all' ? FontWeight.bold : FontWeight.w500,
                          color: selectedAccountId == 'all' ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: selectedAccountId == 'all'
                          ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop('all');
                      },
                    ),
                    Divider(height: 1, color: AppColors.border),
                    SizedBox(height: 4),
                  ],
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucun compte trouvé',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final account = filtered[index];
                              final isSelected = account.id == selectedAccountId;

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                leading: Icon(
                                  account.type == 'bank' ? Icons.account_balance_rounded : Icons.payments_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                title: Text(
                                  account.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (account.bankName?.isNotEmpty ?? false) account.bankName!,
                                    if (account.iban?.isNotEmpty ?? false) 'IBAN: ${account.iban!}',
                                    'Solde: ${formatCurrencyDT(account.balance)}',
                                  ].join(' • '),
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(account.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showCategorySelectDialog(
  BuildContext context,
  List<TransactionCategory> categories, {
  String? selectedCategoryId,
  bool includeAll = false,
}) async {
  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = search.trim().toLowerCase();
          final filtered = categories.where((c) {
            if (query.isEmpty) return true;
            return c.name.toLowerCase().contains(query) || c.type.toLowerCase().contains(query);
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 480,
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sélectionner une catégorie',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une catégorie...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  if (includeAll && query.isEmpty) ...[
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      selected: selectedCategoryId == 'all',
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                      leading: Icon(Icons.category_rounded, size: 18, color: AppColors.primary),
                      title: Text(
                        'Toutes les Categories',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selectedCategoryId == 'all' ? FontWeight.bold : FontWeight.w500,
                          color: selectedCategoryId == 'all' ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: selectedCategoryId == 'all'
                          ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop('all');
                      },
                    ),
                    Divider(height: 1, color: AppColors.border),
                    SizedBox(height: 4),
                  ],
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucune catégorie trouvée',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final category = filtered[index];
                              final isSelected = category.id == selectedCategoryId;

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                leading: Icon(
                                  category.type == 'income' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  size: 18,
                                  color: category.type == 'income' ? AppColors.success : AppColors.error,
                                ),
                                title: Text(
                                  category.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  category.type == 'income' ? 'Revenu / Entrée' : 'Dépense / Sortie',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: category.type == 'income' ? AppColors.success : AppColors.error,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(category.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showWarehouseSelectDialog(
  BuildContext context,
  List<Warehouse> initialWarehouses, {
  String? selectedWarehouseId,
  bool includeAll = false,
}) async {
  try {
    context.read<WarehousesBloc>().add(LoadWarehouses());
  } catch (_) {}

  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return BlocBuilder<WarehousesBloc, WarehousesState>(
            builder: (context, state) {
              final warehouses = List<Warehouse>.from(state is WarehousesLoaded ? state.warehouses : initialWarehouses)
                ..sort((a, b) => a.name.compareTo(b.name));
              final query = search.trim().toLowerCase();
              final filtered = warehouses.where((w) {
            if (query.isEmpty) return true;
            return w.name.toLowerCase().contains(query) || (w.reference?.toLowerCase().contains(query) ?? false);
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 480,
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sélectionner un entrepôt',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un entrepôt...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  if (includeAll && query.isEmpty) ...[
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      selected: selectedWarehouseId == null,
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                      title: Text(
                        'Tous les Entrepôts',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selectedWarehouseId == null ? FontWeight.bold : FontWeight.w500,
                          color: selectedWarehouseId == null ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: selectedWarehouseId == null
                          ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop('__all__');
                      },
                    ),
                    Divider(height: 1, color: AppColors.border),
                    SizedBox(height: 4),
                  ],
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucun entrepôt trouvé',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final warehouse = filtered[index];
                              final isSelected = warehouse.id == selectedWarehouseId;

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                title: Text(
                                  warehouse.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: warehouse.reference != null
                                    ? Text(
                                        warehouse.reference!,
                                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                      )
                                    : null,
                                trailing: isSelected
                                    ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(warehouse.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
},
);
}

Future<String?> showSimpleOptionSelectDialog(
  BuildContext context,
  String title,
  List<Map<String, String>> options, {
  required String selectedValue,
}) async {
  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = search.trim().toLowerCase();
          final filtered = options.where((o) {
            if (query.isEmpty) return true;
            return (o['label'] ?? '').toLowerCase().contains(query);
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            backgroundColor: AppColors.surface,
            child: Container(
              width: 420,
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => search = val),
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(height: 4),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'Aucune option trouvée',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final option = filtered[index];
                              final isSelected = option['value'] == selectedValue;

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                title: Text(
                                  option['label'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(option['value']);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}



