import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/return_notes/return_notes_bloc.dart';
import '../../../../blocs/return_notes/return_notes_event.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/return_note.dart';
import '../../../../models/customer.dart';
import '../../../../models/project.dart';
import '../../../../models/product.dart';
import '../../../../blocs/products/products_bloc.dart';
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
import '../../widgets/forms/mobile_totals_card.dart';
import '../../../../screens/customers_screen.dart';
import '../../../../widgets/searchable_dropdown_field.dart';
import 'mobile_product_form_screen.dart';

class MobileReturnVoucherFormScreen extends StatefulWidget {
  final ReturnNote? existing;
  final bool isReadOnly;
  const MobileReturnVoucherFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileReturnVoucherFormScreen> createState() => _MobileReturnVoucherFormScreenState();
}

class _MobileReturnVoucherFormScreenState extends State<MobileReturnVoucherFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
  List<ReturnNoteItem> _items = [];
  DateTime _date = DateTime.now();
  String _notes = '';
  String _conditions = '';
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  String _status = 'draft';

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.totalHT);

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      map[rate] = (map[rate] ?? 0) + (item.totalHT * item.tvaRate / 100);
    }
    return map;
  }

  double get _totalTva => _items.fold(0, (s, i) => s + (i.totalHT * i.tvaRate / 100));

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

  double get _timbreFiscal => _withTimbreFiscal ? 1.000 : 0;
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
      _date = n.dateEmission;
      _selectedCustomerId = n.customerId;
      _selectedCustomerName = n.customerName;
      _status = n.status;
      _notes = n.notes ?? '';
      _conditions = n.conditions ?? '';
      _items = n.items.map((i) => ReturnNoteItem(
        id: i.id,
        returnNoteId: i.returnNoteId,
        productId: i.productId,
        designation: i.designation,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        totalHT: i.totalHT,
      )).toList();
    }
  }

  Future<void> _save() async {
    if (widget.isReadOnly) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<ReturnNotesBloc>();
      
      String number = widget.existing?.returnNumber ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextReturnNoteSequence();
        number = generateDocNumber('BR', seq);
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
      final note = ReturnNote(
        id: noteId,
        returnNumber: number,
        customerId: _selectedCustomerId!,
        customerName: custName ?? _selectedCustomerName,
        dateEmission: _date,
        status: _status,
        notes: _notes.isNotEmpty ? _notes : null,
        conditions: _conditions.isNotEmpty ? _conditions : null,
        items: _items.map((item) => ReturnNoteItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          returnNoteId: noteId,
          productId: item.productId,
          designation: item.designation,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          totalHT: item.totalHT,
        )).toList(),
      );

      if (_isEditing) {
        bloc.add(UpdateReturnNote(note));
      } else {
        bloc.add(AddReturnNote(note));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Bon de retour mis à jour' : 'Bon de retour créé avec succès'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showArticleForm([int? index]) async {
    if (widget.isReadOnly) return;
    
    MobileArticleFormResult? initialData;
    if (index != null) {
      final item = _items[index];
      initialData = MobileArticleFormResult(
        productId: item.productId ?? '',
        productName: item.designation,
        description: item.designation,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: 0, 
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: false, warehouseId: _selectedWarehouseId);

    if (result != null) {
      setState(() {
        final newItem = ReturnNoteItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          returnNoteId: widget.existing?.id ?? '',
          productId: result.productId,
          designation: result.description.isNotEmpty ? result.description : result.productName,
          quantity: result.quantity,
          unitPrice: result.unitPrice,
          tvaRate: result.tvaRate,
          totalHT: result.quantity * result.unitPrice,
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
      title: widget.isReadOnly ? 'Détails du bon de retour' : (_isEditing ? 'Modifier le bon' : 'Nouveau bon de retour'),
      statusLabel: _status == 'draft' ? 'Brouillon' : (_status == 'validated' ? 'Validé' : 'Annulé'),
      statusColor: _status == 'draft' ? AppColors.warning : (_status == 'validated' ? AppColors.success : AppColors.error),
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: () {
        if (!widget.isReadOnly) _save();
      },
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
                  onChanged: (v) { if (!widget.isReadOnly) setState(() => _date = v); },
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: BlocBuilder<CustomersBloc, CustomersState>(
                        builder: (context, state) {
                          final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                          return AbsorbPointer(
                            absorbing: widget.isReadOnly,
                            child: SmartSearchableSelector(
                              label: 'Client',
                              hint: 'Rechercher des clients...',
                              selectedText: _selectedCustomerId != null
                                  ? (customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)?.companyName?.isNotEmpty == true
                                      ? customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)!.companyName!
                                      : customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)?.name)
                                  : null,
                              onTap: () async {
                                final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedCustomerId);
                                if (res != null && mounted && !widget.isReadOnly) {
                                  setState(() => _selectedCustomerId = res);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    if (!widget.isReadOnly) ...[
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
                    ]
                  ],
                ),
                SizedBox(height: 16),
                BlocBuilder<ProjectsBloc, ProjectsState>(
                  builder: (context, state) {
                    final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                    final selectedProject = projects.cast<Project?>().firstWhere((p) => p?.id == _selectedProjectId, orElse: () => null);
                    final displayName = selectedProject != null ? selectedProject.name : 'Projet par défaut';
                    return SmartSearchableSelector(
                      label: 'Projet',
                      hint: 'Projet par défaut',
                      selectedText: displayName,
                      onTap: () async {
                        if (widget.isReadOnly) return;
                        final res = await showProjectSelectDialog(context, projects, selectedProjectId: _selectedProjectId);
                        if (res != null && mounted) {
                          setState(() => _selectedProjectId = res == '__default__' ? null : res);
                        }
                      },
                    );
                  },
                ),
                SizedBox(height: 16),
                BlocBuilder<WarehousesBloc, WarehousesState>(
                  builder: (context, state) {
                    final warehouses = state is WarehousesLoaded ? state.warehouses : <Warehouse>[];
                    final selectedWh = warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _selectedWarehouseId, orElse: () => null);
                    final warehouseName = selectedWh != null ? selectedWh.name : 'Entrepôt Principal';

                    return SmartSearchableSelector(
                      label: 'Entrepôt',
                      hint: 'Sélectionner un entrepôt',
                      selectedText: warehouseName,
                      onTap: () async {
                        if (widget.isReadOnly) return;
                        final res = await showWarehouseSelectDialog(context, warehouses, selectedWarehouseId: _selectedWarehouseId);
                        if (res != null && mounted) {
                          setState(() => _selectedWarehouseId = res);
                        }
                      },
                    );
                  },
                ),
                SizedBox(height: 24),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartToggleChips<bool>(
                    label: 'Les prix des articles sont en:',
                    value: _pricingModeHT,
                    options: const [true, false],
                    labelBuilder: (v) => v ? 'Hors taxes' : 'Taxe incluse',
                    onChanged: (v) => setState(() => _pricingModeHT = v),
                  ),
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
                    designation: e.value.designation,
                    quantity: e.value.quantity,
                    unitPrice: e.value.unitPrice,
                    tvaRate: e.value.tvaRate,
                    discountPercent: 0,
                    totalHT: e.value.totalHT,
                    onEdit: () { if (!widget.isReadOnly) _showArticleForm(e.key); },
                    onDelete: () { if (!widget.isReadOnly) setState(() => _items.removeAt(e.key)); },
                  )),
                if (!widget.isReadOnly) ...[
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
                              _items.add(ReturnNoteItem(
                                id: _uuid.v4(),
                                returnNoteId: widget.existing?.id ?? '',
                                productId: newProd.id,
                                designation: newProd.name,
                                quantity: -1,
                                unitPrice: newProd.sellingPrice,
                                tvaRate: newProd.tvaRate,
                                totalHT: -1 * newProd.sellingPrice,
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
            timbreFiscal: 1.000,
            applyTimbreFiscal: _withTimbreFiscal,
            onTimbreFiscalChanged: (v) { if (!widget.isReadOnly) setState(() => _withTimbreFiscal = v ?? false); },
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
                SmartTextInput(
                  label: 'Raison / Notes',
                  initialValue: _notes,
                  maxLines: 3,
                  onChanged: widget.isReadOnly ? null : (v) => setState(() => _notes = v),
                ),
                SizedBox(height: 16),
                SmartTextInput(
                  label: 'Conditions Générales',
                  initialValue: _conditions,
                  maxLines: 3,
                  onChanged: widget.isReadOnly ? null : (v) => setState(() => _conditions = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
