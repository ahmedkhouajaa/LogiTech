import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/purchase_invoice.dart';
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
import '../../../../services/enterprise_service.dart';
import '../../../../widgets/searchable_dropdown_field.dart';

class MobilePurchaseInvoiceFormScreen extends StatefulWidget {
  final PurchaseInvoice? existing;
  final bool isReadOnly;
  const MobilePurchaseInvoiceFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobilePurchaseInvoiceFormScreen> createState() => _MobilePurchaseInvoiceFormScreenState();
}

class _MobilePurchaseInvoiceFormScreenState extends State<MobilePurchaseInvoiceFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedSupplierId;
  String? _selectedSupplierName;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
  List<PurchaseInvoiceItem> _items = [];
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _notes = '';
  String _conditions = '';
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  InvoiceStatus _status = InvoiceStatus.unpaid;

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.computedTotalHT);

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
      final itemHT = i.computedTotalHT;
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
      final inv = widget.existing!;
      _date = inv.date;
      _dueDate = inv.dueDate;
      _selectedSupplierId = inv.supplierId;
      _selectedSupplierName = inv.supplierName;
      _selectedProjectId = inv.projectId;
      _pricingModeHT = inv.pricingMode == 'ht';
      _withGlobalDiscount = inv.globalDiscountPercent > 0;
      _globalDiscountPercent = inv.globalDiscountPercent;
      _withTimbreFiscal = inv.timbreFiscal > 0;
      _status = inv.status;
      _notes = inv.notes ?? '';
      _conditions = inv.conditionsGenerales ?? '';
      _items = inv.items.map((i) => PurchaseInvoiceItem(
        id: i.id,
        purchaseInvoiceId: i.purchaseInvoiceId,
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
    if (widget.isReadOnly) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un fournisseur'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<PurchaseInvoicesBloc>();
      
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextPurchaseInvoiceSequence();
        number = generateDocNumber(DocPrefix.purchaseInvoice, seq);
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

      String? projName;
      final projState = context.read<ProjectsBloc>().state;
      if (_selectedProjectId != null && projState is ProjectsLoaded) {
        final found = projState.projects.firstWhere(
          (p) => p.id == _selectedProjectId,
          orElse: () => Project(id: '', name: '', startDate: DateTime.now()),
        );
        projName = found.name;
      }

      final invoiceId = widget.existing?.id ?? _uuid.v4();
      final invoice = PurchaseInvoice(
        id: invoiceId,
        number: number,
        supplierId: _selectedSupplierId!,
        supplierName: suppName ?? _selectedSupplierName,
        projectId: _selectedProjectId,
        projectName: projName,
        warehouseId: _selectedWarehouseId,
        date: _date,
        dueDate: _dueDate,
        status: _status,
        pricingMode: _pricingModeHT ? 'ht' : 'ttc',
        globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
        globalDiscountAmount: _globalDiscountAmount,
        timbreFiscal: _timbreFiscal,
        totalHT: _totalHTAfterDiscount,
        totalTva: _totalTvaAfterDiscount,
        totalTTC: _totalTTC,
        notes: _notes.isNotEmpty ? _notes : null,
        conditionsGenerales: _conditions.isNotEmpty ? _conditions : null,
        items: _items.map<PurchaseInvoiceItem>((item) => PurchaseInvoiceItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          purchaseInvoiceId: invoiceId,
          productId: item.productId,
          productName: (item.description != null && item.description!.isNotEmpty) ? item.description : (item.productName ?? ''),
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
        bloc.add(UpdatePurchaseInvoice(invoice));
      } else {
        bloc.add(AddPurchaseInvoice(invoice));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Facture mise à jour' : 'Facture créée avec succès'),
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
        productName: item.productName ?? '',
        description: item.description ?? item.productName ?? '',
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: true, warehouseId: _selectedWarehouseId);

    if (result != null) {
      setState(() {
        final newItem = PurchaseInvoiceItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          purchaseInvoiceId: widget.existing?.id ?? '',
          productId: result.productId,
          productName: result.productName,
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
      title: widget.isReadOnly ? 'Détails de la facture' : (_isEditing ? 'Modifier la facture' : 'Nouvelle facture'),
      statusLabel: _status.label,
      statusColor: _status.color,
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
                SmartDatePicker(
                  label: 'Date d\'échéance',
                  value: _dueDate,
                  onChanged: (v) { if (!widget.isReadOnly) setState(() => _dueDate = v); },
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
                    designation: e.value.description ?? e.value.productName ?? 'Article',
                    quantity: e.value.quantity,
                    unitPrice: e.value.unitPrice,
                    tvaRate: e.value.tvaRate,
                    discountPercent: e.value.discountPercent,
                    totalHT: e.value.computedTotalHT,
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
                              _items.add(PurchaseInvoiceItem(
                                id: _uuid.v4(),
                                purchaseInvoiceId: widget.existing?.id ?? '',
                                productId: newProd.id,
                                productName: newProd.name,
                                description: newProd.name,
                                quantity: 1,
                                unitPrice: newProd.purchasePrice > 0 ? newProd.purchasePrice : newProd.sellingPrice,
                                tvaRate: newProd.tvaRate,
                                showDescription: true,
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
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartCheckbox(
                    label: 'Visible sur le document final',
                    value: true,
                    onChanged: (v) {},
                  ),
                ),
                SizedBox(height: 8),
                SmartTextInput(
                  label: 'Notes',
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
