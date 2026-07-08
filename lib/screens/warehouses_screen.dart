import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_event.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../models/stock_movement.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showWarehouseDialog([Warehouse? warehouse]) {
    showDialog(
      context: context,
      builder: (context) => _CreateWarehouseDialog(warehouse: warehouse),
    );
  }

  void _deleteWarehouse(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet entrepôt ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              context.read<WarehousesBloc>().add(DeleteWarehouse(id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomAppBar(
          title: 'Entrepôts',
          actions: [
            ElevatedButton.icon(
              onPressed: () => _showWarehouseDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un Entrepôt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        
        // Tabs
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Entrepôts'),
              Tab(text: 'Départements'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWarehousesTab(),
              const Center(child: Text('Les départements seront bientôt disponibles', style: TextStyle(color: AppColors.textSecondary))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarehousesTab() {
    return BlocBuilder<WarehousesBloc, WarehousesState>(
      builder: (context, state) {
        if (state is WarehousesLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is WarehousesError) {
          return Center(child: Text('Erreur: ${state.message}', style: const TextStyle(color: AppColors.error)));
        } else if (state is WarehousesLoaded) {
          final warehouses = state.warehouses;

          if (warehouses.isEmpty) {
            return const Center(child: Text('Aucun entrepôt trouvé', style: TextStyle(color: AppColors.textSecondary)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                  dataRowMaxHeight: 60,
                  dataRowMinHeight: 60,
                  columns: const [
                    DataColumn(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Référence', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Adresse', style: TextStyle(fontWeight: FontWeight.bold))),
                    // DataColumn(label: Text('Par Défaut', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: warehouses.map((w) {
                    return DataRow(
                      cells: [
                        DataCell(Text(w.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(w.reference?.isNotEmpty == true ? w.reference! : 'Aucune référence', style: const TextStyle(color: AppColors.textSecondary))),
                        DataCell(
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(w.address?.isNotEmpty == true ? w.address! : 'Adresse par défaut', style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        /* DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: w.isDefault ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  w.isDefault ? Icons.toggle_on : Icons.toggle_off,
                                  color: w.isDefault ? AppColors.primary : AppColors.textTertiary,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  w.isDefault ? 'Oui' : 'Non',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: w.isDefault ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ), */
                        DataCell(
                          PopupMenuButton(
                            icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: const Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Modifier')]),
                                onTap: () {
                                  // Use Future.delayed because we can't open a dialog during popup menu dismissal
                                  Future.delayed(Duration.zero, () {
                                    _showWarehouseDialog(w);
                                  });
                                },
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: const Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.error))]),
                                onTap: () {
                                  Future.delayed(Duration.zero, () {
                                    _deleteWarehouse(w.id);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        }
        return const SizedBox();
      },
    );
  }
}

class _CreateWarehouseDialog extends StatefulWidget {
  final Warehouse? warehouse;

  const _CreateWarehouseDialog({this.warehouse});

  @override
  State<_CreateWarehouseDialog> createState() => _CreateWarehouseDialogState();
}

class _CreateWarehouseDialogState extends State<_CreateWarehouseDialog> {
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
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.warehouse == null ? 'Ajouter un Entrepôt' : 'Modifier l\'Entrepôt',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Nom de l\'Entrepôt'),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('Saisissez le nom de l\'entrepôt'),
                        validator: (value) => value == null || value.isEmpty ? 'Ce champ est requis' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildLabel('Référence'),
                      TextFormField(
                        controller: _referenceController,
                        decoration: _inputDecoration('Saisissez la référence de l\'entrepôt'),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildLabel('Adresse'),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: _inputDecoration('Saisissez l\'adresse de l\'entrepôt'),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Code Postal'),
                                TextFormField(
                                  controller: _postalCodeController,
                                  decoration: _inputDecoration('Saisissez le code postal'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Ville'),
                                TextFormField(
                                  controller: _cityController,
                                  decoration: _inputDecoration('Saisissez la ville'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildLabel('Pays'),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                    const SizedBox(width: 8),
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
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Checkbox(
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val ?? true),
                            activeColor: AppColors.primary,
                          ),
                          const Text('Actif', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _isDefault,
                            onChanged: (val) => setState(() => _isDefault = val ?? false),
                            activeColor: AppColors.primary,
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 12.0),
                                  child: Text('Entrepôt par Défaut', style: TextStyle(fontWeight: FontWeight.w500)),
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Annuler', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: Text(widget.warehouse == null ? 'Créer' : 'Enregistrer'),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
