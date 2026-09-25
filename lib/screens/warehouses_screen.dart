import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_event.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../models/stock_movement.dart';
import '../utils/constants.dart';
import '../services/enterprise_service.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_table_row.dart';
import '../l10n/app_localizations.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentPage = 0;
  int _rowsPerPage = 20;
  String _sortColumn = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<WarehousesBloc>().add(LoadWarehouses());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showWarehouseDialog([Warehouse? warehouse]) {
    if (warehouse != null) {
      final isDefault = warehouse.isDefault ||
          warehouse.name.trim().toLowerCase() == 'entrepôt par défaut' ||
          warehouse.name.trim().toLowerCase() == 'entrepot par defaut';
      if (isDefault) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Cet élément est un élément par défaut et ne peut pas être modifié.')),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    showDialog(
      context: context,
      builder: (context) => CreateWarehouseDialog(warehouse: warehouse),
    );
  }

  void _deleteWarehouse(Warehouse warehouse) {
    final isDefault = warehouse.isDefault ||
        warehouse.name.trim().toLowerCase() == 'entrepôt par défaut' ||
        warehouse.name.trim().toLowerCase() == 'entrepot par defaut';
    if (isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Cet élément est un élément par défaut et ne peut pas être supprimé.')),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Confirmer la suppression')),
        content: Text(context.tr('Êtes-vous sûr de vouloir supprimer cet entrepôt ?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Annuler'))),
          ElevatedButton(
            onPressed: () {
              context.read<WarehousesBloc>().add(DeleteWarehouse(warehouse.id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Supprimer')),
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
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Entrepôts'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(context.tr('Gérer vos entrepôts'), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              if (PermissionService.instance.canCreate(UserPermissionResources.stockWarehouses))
                ElevatedButton.icon(
                  onPressed: () => _showWarehouseDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.tr('Ajouter un Entrepôt')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        
        // Tabs
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: context.tr('Entrepôts')),
              Tab(text: context.tr('Départements')),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWarehousesTab(),
              Center(child: Text(context.tr('Les départements seront bientôt disponibles'), style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarehousesTab() {
    return BlocBuilder<WarehousesBloc, WarehousesState>(
      builder: (context, state) {
        if (state is WarehousesLoading || state is WarehousesInitial) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ShimmerTable(
              headerColumns: [
                Expanded(flex: 3, child: Text(context.tr('Nom'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text(context.tr('Référence'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                Expanded(flex: 3, child: Text(context.tr('Adresse'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                SizedBox(width: 60, child: Text(context.tr('Actions'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
          );
        } else if (state is WarehousesError) {
            return AppErrorWidget(message: state.message);
          } else if (state is WarehousesLoaded) {
          final warehouses = List<Warehouse>.from(state.warehouses);

          // Sort
          warehouses.sort((a, b) {
            int cmp;
            switch (_sortColumn) {
              case 'reference':
                cmp = (a.reference ?? '').toLowerCase().compareTo((b.reference ?? '').toLowerCase());
                break;
              case 'address':
                cmp = (a.address ?? '').toLowerCase().compareTo((b.address ?? '').toLowerCase());
                break;
              case 'name':
              default:
                cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
            }
            return _sortAscending ? cmp : -cmp;
          });

          final totalPages = (warehouses.length / _rowsPerPage).ceil() == 0 ? 1 : (warehouses.length / _rowsPerPage).ceil();
          if (_currentPage >= totalPages) {
            _currentPage = 0;
          }
          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage).clamp(0, warehouses.length);
          final paginatedWarehouses = warehouses.isEmpty ? <Warehouse>[] : warehouses.sublist(startIndex, endIndex);
          final startItem = warehouses.isEmpty ? 0 : startIndex + 1;
          final endItem = endIndex;

          return Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (_sortColumn == 'name') {
                                  _sortAscending = !_sortAscending;
                                } else {
                                  _sortColumn = 'name';
                                  _sortAscending = true;
                                }
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.tr('Nom'),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _sortColumn == 'name'
                                      ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                      : Icons.unfold_more_rounded,
                                  size: 14,
                                  color: _sortColumn == 'name' ? AppColors.primary : AppColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (_sortColumn == 'reference') {
                                  _sortAscending = !_sortAscending;
                                } else {
                                  _sortColumn = 'reference';
                                  _sortAscending = true;
                                }
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.tr('Référence'),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _sortColumn == 'reference'
                                      ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                      : Icons.unfold_more_rounded,
                                  size: 14,
                                  color: _sortColumn == 'reference' ? AppColors.primary : AppColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (_sortColumn == 'address') {
                                  _sortAscending = !_sortAscending;
                                } else {
                                  _sortColumn = 'address';
                                  _sortAscending = true;
                                }
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.tr('Adresse'),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _sortColumn == 'address'
                                      ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                      : Icons.unfold_more_rounded,
                                  size: 14,
                                  color: _sortColumn == 'address' ? AppColors.primary : AppColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            context.tr('Actions'),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table body
                  Expanded(
                    child: paginatedWarehouses.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warehouse_outlined, size: 48, color: AppColors.textTertiary),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('Aucun entrepôt trouvé'),
                                    style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: paginatedWarehouses.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final w = paginatedWarehouses[index];
                              final isDefault = w.isDefault ||
                                  w.name.trim().toLowerCase() == 'entrepôt par défaut' ||
                                  w.name.trim().toLowerCase() == 'entrepot par defaut';

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: index % 2 == 0 ? AppColors.surface : AppColors.background.withValues(alpha: 0.3),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              w.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isDefault) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.lock_rounded, size: 10, color: AppColors.primary),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    context.tr('Par défaut'),
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        w.reference?.isNotEmpty == true ? w.reference! : context.tr('Aucune référence'),
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              w.address?.isNotEmpty == true ? w.address! : context.tr('Adresse par défaut'),
                                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: PopupMenuButton(
                                          icon: Icon(Icons.more_horiz, size: 18, color: AppColors.textSecondary),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          itemBuilder: (context) {
                                            final canRead = PermissionService.instance.canRead(UserPermissionResources.stockWarehouses);
                                            final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.stockWarehouses);
                                            final canDelete = PermissionService.instance.canDelete(UserPermissionResources.stockWarehouses);

                                            final entries = <PopupMenuEntry>[];

                                            if (canRead) {
                                              entries.add(
                                                PopupMenuItem(
                                                  value: 'view',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.visibility_outlined, size: 16, color: AppColors.info),
                                                      const SizedBox(width: 8),
                                                      Text(context.tr('Voir')),
                                                    ],
                                                  ),
                                                  onTap: () {
                                                    Future.delayed(Duration.zero, () {
                                                      _showWarehouseDialog(w);
                                                    });
                                                  },
                                                ),
                                              );
                                            }

                                            if (!isDefault) {
                                              if (canUpdate) {
                                                entries.add(
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                                        const SizedBox(width: 8),
                                                        Text(context.tr('Modifier')),
                                                      ],
                                                    ),
                                                    onTap: () {
                                                      Future.delayed(Duration.zero, () {
                                                        _showWarehouseDialog(w);
                                                      });
                                                    },
                                                  ),
                                                );
                                              }
                                              if (canDelete) {
                                                entries.add(
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                                        const SizedBox(width: 8),
                                                        Text(context.tr('Supprimer'), style: TextStyle(color: AppColors.error)),
                                                      ],
                                                    ),
                                                    onTap: () {
                                                      Future.delayed(Duration.zero, () {
                                                        _deleteWarehouse(w);
                                                      });
                                                    },
                                                  ),
                                                );
                                              }
                                            } else {
                                              entries.add(
                                                PopupMenuItem(
                                                  enabled: false,
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.lock_rounded, size: 14, color: AppColors.textTertiary),
                                                      const SizedBox(width: 8),
                                                      Text(context.tr('Élément protégé'), style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }

                                            return entries;
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Pagination footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border(top: BorderSide(color: AppColors.border)),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
                    ),
                    child: Row(
                      children: [
                        Text(context.tr('Lignes'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                            color: AppColors.surface,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _rowsPerPage,
                              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                              items: [20, 50, 100].map((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString(), style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _rowsPerPage = newValue;
                                    _currentPage = 0;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${context.tr("Page")} ${_currentPage + 1} ${context.tr("sur")} $totalPages',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        Text(
                          '${warehouses.isEmpty ? 0 : startItem} - $endItem ${context.tr("sur")} ${warehouses.length}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
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
    );
  }
}

class CreateWarehouseDialog extends StatefulWidget {
  final Warehouse? warehouse;
  const CreateWarehouseDialog({super.key, this.warehouse});

  @override
  State<CreateWarehouseDialog> createState() => _CreateWarehouseDialogState();
}

class _CreateWarehouseDialogState extends State<CreateWarehouseDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _referenceController;
  late TextEditingController _addressController;
  late TextEditingController _postalCodeController;
  late TextEditingController _cityController;
  
  String _selectedCountry = 'Tunisia';
  bool _isActive = true;
  bool _isDefault = false;

  final List<String> _countries = ['Tunisia', 'France', 'Maroc', 'Algérie', 'Canada', 'États-Unis', 'Autre'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.warehouse?.name ?? '');
    _referenceController = TextEditingController(text: widget.warehouse?.reference ?? '');
    _addressController = TextEditingController(text: widget.warehouse?.address ?? '');
    _postalCodeController = TextEditingController(text: widget.warehouse?.postalCode ?? '');
    _cityController = TextEditingController(text: widget.warehouse?.city ?? '');
    
    _isActive = widget.warehouse?.isActive ?? true;
    _isDefault = widget.warehouse?.isDefault ?? false;
    
    if (widget.warehouse?.country != null && _countries.contains(widget.warehouse!.country)) {
      _selectedCountry = widget.warehouse!.country!;
    } else if (widget.warehouse?.country != null) {
       if (!_countries.contains(widget.warehouse!.country!)) {
         _countries.add(widget.warehouse!.country!);
       }
       _selectedCountry = widget.warehouse!.country!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _referenceController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final warehouse = Warehouse(
        id: widget.warehouse?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        country: _selectedCountry,
        isActive: _isActive,
        isDefault: _isDefault,
        enterpriseId: widget.warehouse?.enterpriseId ?? EnterpriseService.instance.currentEnterpriseId,
      );

      if (widget.warehouse == null) {
        context.read<WarehousesBloc>().add(AddWarehouse(warehouse));
      } else {
        context.read<WarehousesBloc>().add(UpdateWarehouse(warehouse));
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24) : const EdgeInsets.symmetric(horizontal: 80, vertical: 48),
      child: Container(
        width: isMobile ? size.width : 600,
        constraints: BoxConstraints(maxHeight: size.height * 0.85),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                widget.warehouse == null ? 'Ajouter un Entrepôt' : 'Modifier l\'Entrepôt',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Divider(height: 1),
            
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Nom de l\'Entrepôt'),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('Saisissez le nom de l\'entrepôt'),
                        validator: (value) => value == null || value.isEmpty ? context.tr('Ce champ est requis') : null,
                      ),
                      SizedBox(height: 16),
                      
                      _buildLabel(context.tr('Référence')),
                      TextFormField(
                        controller: _referenceController,
                        decoration: _inputDecoration('Saisissez la référence de l\'entrepôt'),
                      ),
                      SizedBox(height: 16),
                      
                      _buildLabel(context.tr('Adresse')),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: _inputDecoration('Saisissez l\'adresse de l\'entrepôt'),
                      ),
                      SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('Code Postal')),
                                TextFormField(
                                  controller: _postalCodeController,
                                  decoration: _inputDecoration(context.tr('Saisissez le code postal')),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('Ville')),
                                TextFormField(
                                  controller: _cityController,
                                  decoration: _inputDecoration(context.tr('Saisissez la ville')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      _buildLabel(context.tr('Pays')),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountry,
                            isExpanded: true,
                            items: _countries.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Row(
                                  children: [
                                    Icon(Icons.public, size: 18, color: c == 'Tunisia' ? AppColors.error : AppColors.textSecondary),
                                    SizedBox(width: 8),
                                    Text(c),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCountry = val);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Checkbox(
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val ?? true),
                            activeColor: AppColors.primary,
                          ),
                          Text(context.tr('Actif'), style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      SizedBox(height: 8),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _isDefault,
                            onChanged: (val) => setState(() => _isDefault = val ?? false),
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 12.0),
                                  child: Text(context.tr('Entrepôt par Défaut'), style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                                Text(
                                  'Ce sera l\'entrepôt par défaut pour les nouveaux produits et transactions',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: Text(context.tr('Annuler'), style: TextStyle(color: AppColors.textPrimary)),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: Text(widget.warehouse == null ? context.tr('Créer') : context.tr('Enregistrer')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }
}
