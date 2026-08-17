import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/delivery_note.dart';
import '../../../../models/customer.dart';
import '../../../../models/project.dart';
import '../../../../blocs/products/products_bloc.dart';
import '../../../../models/product.dart';
import '../../../../blocs/warehouses/warehouses_bloc.dart';
import '../../../../blocs/warehouses/warehouses_state.dart';
import '../../../../blocs/warehouses/warehouses_event.dart';
import '../../../../models/stock_movement.dart' show Warehouse;
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../../../database/database_helper.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';
import '../../widgets/forms/mobile_article_card.dart';
import '../../widgets/forms/mobile_article_form.dart';
import 'mobile_product_form_screen.dart';
import '../../widgets/forms/mobile_totals_card.dart';
import '../../../../screens/customers_screen.dart';
import '../../../../widgets/searchable_dropdown_field.dart';
import 'package:business_manager_pro/services/error_handler.dart';

class MobileDeliveryNoteFormScreen extends StatefulWidget {
  final DeliveryNote? existing;
  const MobileDeliveryNoteFormScreen({super.key, this.existing});

  @override
  State<MobileDeliveryNoteFormScreen> createState() => _MobileDeliveryNoteFormScreenState();
}

class _MobileDeliveryNoteFormScreenState extends State<MobileDeliveryNoteFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
  List<DeliveryNoteItem> _items = [];
  DateTime _date = DateTime.now();
  String _notes = '';
  String _conditions = '';
  String _vehicleRegistration = '';
  String _driverName = '';
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  DeliveryNoteStatus _status = DeliveryNoteStatus.draft;

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.totalHT);

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      map[rate] = (map[rate] ?? 0) + item.tvaAmount;
    }
    return map;
  }

  double get _totalTva => _items.fold(0, (s, i) => s + i.tvaAmount);

  double get _globalDiscountAmount {
    if (!_withGlobalDiscount || _globalDiscountPercent <= 0) return 0;
    return _totalHT * _globalDiscountPercent / 100;
  }

  double get _totalHTAfterDiscount => _totalHT - _globalDiscountAmount;
  
  double get _totalTvaAfterDiscount {
    if (!_withGlobalDiscount || _globalDiscountPercent <= 0) return _totalTva;
    return _items.fold(0, (s, i) {
      final itemHT = i.totalHT;
      final discountedHT = itemHT - (itemHT * _globalDiscountPercent / 100);
      return s + discountedHT * (i.tvaRate / 100);
    });
  }

  double get _timbreFiscal => _withTimbreFiscal ? 1.0 : 0;
  double get _totalTTC => _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<ProjectsBloc>().add(LoadProjects());
    context.read<WarehousesBloc>().add(LoadWarehouses());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _selectedCustomerId = n.customerId;
      _selectedCustomerName = n.customerName;
      _selectedProjectId = n.projectId;
      _selectedWarehouseId = n.warehouseId;
      _pricingModeHT = n.pricingMode == 'ht';
      _withGlobalDiscount = n.globalDiscountPercent > 0;
      _globalDiscountPercent = n.globalDiscountPercent;
      _withTimbreFiscal = n.timbreFiscal > 0;
      _status = DeliveryNoteStatus.values.firstWhere(
        (e) => e.name == n.status,
        orElse: () => DeliveryNoteStatus.draft,
      );
      _notes = n.notes ?? '';
      _conditions = n.conditionsGenerales ?? '';
      _vehicleRegistration = n.vehicleRegistration ?? '';
      _driverName = n.driverName ?? '';
      _items = n.items.map((i) => DeliveryNoteItem(
        id: i.id,
        deliveryNoteId: i.deliveryNoteId,
        productId: i.productId,
        description: i.description,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        showDescription: i.showDescription,
        showDiscount: i.showDiscount,
      )).toList();
    }
  }

  Future<void> _save() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<DeliveryNotesBloc>();
      
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextDeliveryNoteSequence();
        number = generateDocNumber('BL', seq);
      }

      final custState = context.read<CustomersBloc>().state;
      String? custName;
      if (custState is CustomersLoaded) {
        final found = custState.customers.firstWhere(
          (c) => c.id == _selectedCustomerId,
          orElse: () => Customer(id: '', code: '', name: 'Client Inconnu'),
        );
        custName = found.companyName?.isNotEmpty == true
            ? found.companyName
            : (found.responsibleName?.isNotEmpty == true ? found.responsibleName : found.name);
      }

      final noteId = widget.existing?.id ?? _uuid.v4();
      final note = DeliveryNote(
        id: noteId,
        number: number,
        customerId: _selectedCustomerId!,
        customerName: custName ?? _selectedCustomerName,
        projectId: _selectedProjectId,
        warehouseId: _selectedWarehouseId,
        date: _date,
        status: _status.name,
        pricingMode: _pricingModeHT ? 'ht' : 'ttc',
        globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
        timbreFiscal: _timbreFiscal,
        vehicleRegistration: _vehicleRegistration.isNotEmpty ? _vehicleRegistration : null,
        driverName: _driverName.isNotEmpty ? _driverName : null,
        notes: _notes.isNotEmpty ? _notes : null,
        conditionsGenerales: _conditions.isNotEmpty ? _conditions : null,
        items: _items.map((item) => DeliveryNoteItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          deliveryNoteId: noteId,
          productId: item.productId,
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          discountPercent: item.discountPercent,
          showDescription: item.showDescription,
          showDiscount: item.showDiscount,
        )).toList(),
        isDeleted: widget.existing?.isDeleted ?? false,
      );

      if (_isEditing) {
        bloc.add(UpdateDeliveryNote(note));
      } else {
        bloc.add(AddDeliveryNote(note));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Bon mis à jour' : 'Bon créé avec succès'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showArticleForm([int? index]) async {
    MobileArticleFormResult? initialData;
    if (index != null) {
      final item = _items[index];
      initialData = MobileArticleFormResult(
        productId: item.productId,
        productName: '',
        description: item.description ?? '',
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: false, warehouseId: _selectedWarehouseId);

    if (result != null) {
      setState(() {
        final newItem = DeliveryNoteItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          deliveryNoteId: widget.existing?.id ?? '',
          productId: result.productId,
          description: result.description,
          quantity: result.quantity,
          unitPrice: result.unitPrice,
          tvaRate: result.tvaRate,
          discountPercent: result.discountPercent,
          showDescription: result.description.isNotEmpty,
          showDiscount: result.discountPercent > 0,
        );

        if (index != null) {
          _items[index] = newItem;
        } else {
          _items.add(newItem);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: _isEditing ? 'Modifier le BL' : 'Nouveau BL',
      statusLabel: _status.label,
      statusColor: _status.color,
      isLoading: _isLoading,
      saveLabel: 'Valider',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      children: [
        MobileFormSection(
          title: 'Informations',
          icon: Icons.info_outline_rounded,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmartDatePicker(
                  label: 'Date d\'émission',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v),
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: BlocBuilder<CustomersBloc, CustomersState>(
                        builder: (context, state) {
                          final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                          final selectedCustomer = customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null);
                          final displayName = selectedCustomer != null
                              ? (selectedCustomer.companyName?.isNotEmpty == true
                                  ? selectedCustomer.companyName!
                                  : (selectedCustomer.responsibleName?.isNotEmpty == true
                                      ? selectedCustomer.responsibleName!
                                      : selectedCustomer.name))
                              : null;
                          return SmartSearchableSelector(
                            label: 'Client',
                            hint: 'Rechercher des clients...',
                            selectedText: displayName,
                            onTap: () async {
                              final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedCustomerId);
                              if (res != null && mounted) {
                                setState(() => _selectedCustomerId = res);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final res = await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => BlocProvider.value(
                              value: context.read<CustomersBloc>(),
                              child: const CustomerDialog(existing: null),
                            ),
                          );
                          if (res != null && mounted) {
                            if (res is Customer) {
                              setState(() {
                                _selectedCustomerId = res.id;
                                _selectedCustomerName = res.companyName?.isNotEmpty == true
                                    ? res.companyName!
                                    : (res.responsibleName?.isNotEmpty == true ? res.responsibleName! : res.name);
                              });
                            } else if (res is String) {
                              setState(() => _selectedCustomerId = res);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Icon(Icons.person_add_alt_1_rounded),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                BlocBuilder<ProjectsBloc, ProjectsState>(
                  builder: (context, state) {
                    final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                    final defaultProj = projects.cast<Project?>().firstWhere(
                      (p) => p?.isDefault == true,
                      orElse: () => projects.cast<Project?>().firstWhere(
                        (p) => p?.name.toLowerCase().contains('défaut') == true || p?.name.toLowerCase().contains('defaut') == true,
                        orElse: () => projects.isNotEmpty ? projects.first : null,
                      ),
                    );
                    if (_selectedProjectId == null && defaultProj != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _selectedProjectId == null) {
                          setState(() => _selectedProjectId = defaultProj.id);
                        }
                      });
                    }
                    final selectedProject = projects.cast<Project?>().firstWhere(
                      (p) => p?.id == (_selectedProjectId ?? defaultProj?.id),
                      orElse: () => defaultProj,
                    );
                    final displayName = selectedProject?.name ?? 'Projet par défaut';
                    return SmartSearchableSelector(
                      label: 'Projet',
                      hint: 'Sélectionner un projet',
                      selectedText: displayName,
                      onTap: () async {
                        final res = await showProjectSelectDialog(
                          context,
                          projects,
                          selectedProjectId: _selectedProjectId ?? defaultProj?.id,
                        );
                        if (res != null && mounted) {
                          setState(() => _selectedProjectId = res);
                        }
                      },
                    );
                  },
                ),
                SizedBox(height: 16),
                BlocBuilder<WarehousesBloc, WarehousesState>(
                  builder: (context, state) {
                    final warehouses = state is WarehousesLoaded ? (List.of(state.warehouses)..sort((a,b) => a.name.compareTo(b.name))) : <Warehouse>[];
                    final defaultWh = warehouses.cast<Warehouse?>().firstWhere(
                      (w) => w?.isDefault == true,
                      orElse: () => warehouses.cast<Warehouse?>().firstWhere((w) => w?.name.toLowerCase().contains('défaut') == true || w?.name.toLowerCase().contains('defaut') == true, orElse: () => warehouses.isNotEmpty ? warehouses.first : null),
                    );
                    if (_selectedWarehouseId == null && defaultWh != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _selectedWarehouseId == null) {
                          setState(() => _selectedWarehouseId = defaultWh.id);
                        }
                      });
                    }
                    final selectedWh = warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == (_selectedWarehouseId ?? defaultWh?.id), orElse: () => defaultWh);
                    final warehouseName = selectedWh?.name;

                    return SmartSearchableSelector(
                      label: 'Entrepôt',
                      hint: 'Sélectionner un entrepôt',
                      selectedText: warehouseName,
                      onTap: () async {
                        final res = await showWarehouseSelectDialog(context, warehouses, selectedWarehouseId: _selectedWarehouseId ?? defaultWh?.id);
                        if (res != null && mounted) {
                          setState(() => _selectedWarehouseId = res);
                        }
                      },
                    );
                  },
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Champs Personnalisés', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Informations supplémentaires', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Matricule du véhicule',
                        initialValue: _vehicleRegistration,
                        onChanged: (v) => setState(() => _vehicleRegistration = v),
                      ),
                      SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Nom du chauffeur',
                        initialValue: _driverName,
                        onChanged: (v) => setState(() => _driverName = v),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                SmartToggleChips<bool>(
                  label: 'Les prix des articles sont en:',
                  value: _pricingModeHT,
                  options: const [true, false],
                  labelBuilder: (v) => v ? 'Hors taxes' : 'Taxe incluse',
                  onChanged: (v) => setState(() => _pricingModeHT = v),
                ),
              ],
            ),
          ),
        ),
        
        MobileFormSection(
          title: 'Articles',
          icon: Icons.inventory_2_outlined,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_items.isEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Text('Aucun article ajouté', style: TextStyle(color: AppColors.textTertiary)),
                  )
                else
                  ..._items.asMap().entries.map((e) => MobileArticleCard(
                    index: e.key,
                    designation: e.value.description ?? 'Article',
                    quantity: e.value.quantity,
                    unitPrice: e.value.unitPrice,
                    tvaRate: e.value.tvaRate,
                    discountPercent: e.value.discountPercent,
                    totalHT: e.value.totalHT,
                    onEdit: () => _showArticleForm(e.key),
                    onDelete: () => setState(() => _items.removeAt(e.key)),
                  )),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showArticleForm(),
                        icon: Icon(Icons.add_rounded),
                        label: Text('Ajouter une ligne'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                      )
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                      tooltip: 'Créer un nouvel article',
                      onPressed: () async {
                        final newProd = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<ProductsBloc>(),
                              child: const MobileProductFormScreen(),
                            ),
                          ),
                        );
                        if (newProd != null && newProd is Product && mounted) {
                          setState(() {
                            _items.add(DeliveryNoteItem(
                              id: _uuid.v4(),
                              deliveryNoteId: widget.existing?.id ?? '',
                              productId: newProd.id,
                              description: newProd.name,
                              quantity: 1,
                              unitPrice: newProd.sellingPrice,
                              tvaRate: newProd.tvaRate,
                            ));
                          });
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16),
                SmartCheckbox(
                  label: 'Ajouter une remise globale',
                  value: _withGlobalDiscount,
                  onChanged: (v) => setState(() => _withGlobalDiscount = v ?? false),
                ),
                if (_withGlobalDiscount) ...[
                  SizedBox(height: 8),
                  SmartTextInput(
                    label: 'Remise globale (%)',
                    initialValue: _globalDiscountPercent > 0 ? _globalDiscountPercent.toStringAsFixed(0) : '',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _globalDiscountPercent = double.tryParse(v) ?? 0),
                  ),
                ]
              ],
            ),
          ),
        ),
        
        MobileFormSection(
          title: 'Totaux',
          icon: Icons.calculate_outlined,
          child: MobileTotalsCard(
            subTotalHT: _totalHTAfterDiscount,
            tvaBreakdown: _tvaBreakdown,
            totalTva: _totalTvaAfterDiscount,
            timbreFiscal: 1.0,
            applyTimbreFiscal: _withTimbreFiscal,
            onTimbreFiscalChanged: (v) => setState(() => _withTimbreFiscal = v ?? false),
            totalTTC: _totalTTC,
          ),
        ),
        
        MobileFormSection(
          title: 'Notes & Conditions',
          icon: Icons.notes_rounded,
          isInitiallyExpanded: false,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                SmartCheckbox(
                  label: 'Visible sur le document final',
                  value: true,
                  onChanged: (v) {},
                ),
                SizedBox(height: 8),
                SmartTextInput(
                  label: 'Notes',
                  initialValue: _notes,
                  maxLines: 3,
                  onChanged: (v) => setState(() => _notes = v),
                ),
                SizedBox(height: 16),
                SmartTextInput(
                  label: 'Conditions Générales',
                  initialValue: _conditions,
                  maxLines: 3,
                  onChanged: (v) => setState(() => _conditions = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
