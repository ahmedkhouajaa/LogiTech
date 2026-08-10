import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../../../../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/supplier_credit_note.dart';
import '../../../../models/supplier.dart';
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
import '../../../../screens/suppliers_screen.dart';
import '../../../../widgets/searchable_dropdown_field.dart';

class MobileSupplierCreditNoteFormScreen extends StatefulWidget {
  final SupplierCreditNote? existing;
  final bool isReadOnly;
  const MobileSupplierCreditNoteFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileSupplierCreditNoteFormScreen> createState() => _MobileSupplierCreditNoteFormScreenState();
}

class _MobileSupplierCreditNoteFormScreenState extends State<MobileSupplierCreditNoteFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedSupplierId;
  String? _selectedSupplierName;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
  List<SupplierCreditNoteItem> _items = [];
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
    context.read<SuppliersBloc>().add(LoadSuppliers());
    context.read<ProjectsBloc>().add(LoadProjects());
    context.read<WarehousesBloc>().add(LoadWarehouses());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _selectedSupplierId = n.supplierId;
      _selectedSupplierName = n.supplierName;
      _status = n.status;
      _notes = n.reason ?? '';
      _conditions = n.reason ?? '';
      _items = n.items.map((i) => SupplierCreditNoteItem(
        id: i.id,
        supplierCreditNoteId: i.supplierCreditNoteId,
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
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un fournisseur'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<SupplierCreditNotesBloc>();
      
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextSupplierCreditNoteSequence();
        number = generateDocNumber(DocPrefix.supplierCreditNote, seq);
      }

      String? suppName;
      final suppState = context.read<SuppliersBloc>().state;
      if (suppState is SuppliersLoaded) {
        final found = suppState.suppliers.firstWhere(
          (s) => s.id == _selectedSupplierId,
          orElse: () => Supplier(id: '', code: '', name: 'Fournisseur Inconnu'),
        );
        suppName = found.companyName?.isNotEmpty == true
            ? found.companyName
            : (found.responsibleName?.isNotEmpty == true ? found.responsibleName : found.name);
      }

      final noteId = widget.existing?.id ?? _uuid.v4();
      final note = SupplierCreditNote(
        id: noteId,
        number: number,
        supplierId: _selectedSupplierId!,
        supplierName: suppName ?? _selectedSupplierName,
        date: _date,
        status: _status,
        reason: _notes.isNotEmpty ? _notes : null,
        items: _items.map((item) => SupplierCreditNoteItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          supplierCreditNoteId: noteId,
          productId: item.productId,
          designation: item.designation,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          totalHT: item.totalHT,
        )).toList(),
        isDeleted: false,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        bloc.add(UpdateSupplierCreditNote(note));
      } else {
        bloc.add(AddSupplierCreditNote(note));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Avoir mis à jour' : 'Avoir créé avec succès'),
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
        productId: item.productId,
        productName: item.designation ?? '',
        description: item.designation ?? '',
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: 0, // SupplierCreditNoteItem doesn't seem to store discountPercent directly
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: true, warehouseId: _selectedWarehouseId);

    if (result != null) {
      setState(() {
        final newItem = SupplierCreditNoteItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          supplierCreditNoteId: widget.existing?.id ?? '',
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
      title: widget.isReadOnly ? 'Détails de l\'avoir' : (_isEditing ? 'Modifier l\'avoir' : 'Nouvel avoir'),
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
                      child: BlocBuilder<SuppliersBloc, SuppliersState>(
                        builder: (context, state) {
                          final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                          return AbsorbPointer(
                            absorbing: widget.isReadOnly,
                            child: SmartSearchableSelector(
                              label: 'Fournisseur',
                              hint: 'Rechercher des fournisseurs...',
                              selectedText: _selectedSupplierId != null
                                  ? (suppliers.cast<Supplier?>().firstWhere((s) => s?.id == _selectedSupplierId, orElse: () => null)?.companyName?.isNotEmpty == true
                                      ? suppliers.cast<Supplier?>().firstWhere((s) => s?.id == _selectedSupplierId, orElse: () => null)!.companyName!
                                      : suppliers.cast<Supplier?>().firstWhere((s) => s?.id == _selectedSupplierId, orElse: () => null)?.name)
                                  : null,
                              onTap: () async {
                                final res = await showSupplierSelectDialog(context, suppliers, selectedSupplierId: _selectedSupplierId);
                                if (res != null && mounted && !widget.isReadOnly) {
                                  setState(() => _selectedSupplierId = res);
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
                                value: context.read<SuppliersBloc>(),
                                child: SupplierDialog(existing: null),
                              ),
                            );
                            if (res != null && mounted) {
                              if (res is Supplier) {
                                setState(() {
                                  _selectedSupplierId = res.id;
                                  _selectedSupplierName = res.companyName?.isNotEmpty == true
                                      ? res.companyName!
                                      : (res.responsibleName?.isNotEmpty == true ? res.responsibleName! : res.name);
                                });
                              } else if (res is String) {
                                setState(() => _selectedSupplierId = res);
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
                    designation: e.value.designation ?? 'Article',
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
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileProductFormScreen()));
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
