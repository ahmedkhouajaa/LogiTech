import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/receiving_voucher.dart';
import '../../../../models/supplier.dart';
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
import '../../../../screens/suppliers_screen.dart';
import '../../../../widgets/searchable_dropdown_field.dart';
import '../../widgets/forms/mobile_article_card.dart';
import '../../widgets/forms/mobile_article_form.dart';
import 'mobile_product_form_screen.dart';
import '../../widgets/forms/mobile_totals_card.dart';

class MobileReceivingVoucherFormScreen extends StatefulWidget {
  final ReceivingVoucher? existing;
  final bool isReadOnly;
  const MobileReceivingVoucherFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileReceivingVoucherFormScreen> createState() => _MobileReceivingVoucherFormScreenState();
}

class _MobileReceivingVoucherFormScreenState extends State<MobileReceivingVoucherFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedSupplierId;
  String? _selectedSupplierName;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
  List<ReceivingVoucherItem> _items = [];
  DateTime _date = DateTime.now();
  String _notes = '';
  String _conditions = '';
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  String _status = 'draft';

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
      final n = widget.existing!;
      _date = n.date;
      _selectedSupplierId = n.supplierId;
      _selectedSupplierName = n.supplierName;
      _pricingModeHT = n.pricingMode == 'ht';
      _withGlobalDiscount = n.globalDiscountPercent > 0;
      _globalDiscountPercent = n.globalDiscountPercent;
      _withTimbreFiscal = n.timbreFiscal > 0;
      _status = n.status;
      _notes = n.notes ?? '';
      _conditions = n.conditionsGenerales ?? '';
      _items = n.items.map((i) => ReceivingVoucherItem(
        id: i.id,
        voucherId: i.voucherId,
        productId: i.productId,
        productName: i.productName,
        quantityExpected: i.quantityExpected,
        quantityReceived: i.quantityReceived,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
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
      final bloc = context.read<ReceivingVouchersBloc>();
      
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextReceivingVoucherSequence();
        number = generateDocNumber(DocPrefix.receivingVoucher, seq);
      }

      final suppState = context.read<SuppliersBloc>().state;
      String? suppName;
      if (suppState is SuppliersLoaded) {
        final found = suppState.suppliers.firstWhere(
          (s) => s.id == _selectedSupplierId,
          orElse: () => Supplier(id: '', code: '', name: 'Fournisseur Inconnu'),
        );
        suppName = found.companyName?.isNotEmpty == true
            ? found.companyName
            : (found.responsibleName?.isNotEmpty == true ? found.responsibleName : found.name);
      }

      final voucherId = widget.existing?.id ?? _uuid.v4();
      final order = ReceivingVoucher(
        id: voucherId,
        number: number,
        supplierId: _selectedSupplierId!,
        supplierName: suppName ?? _selectedSupplierName,
        orderId: widget.existing?.orderId,
        date: _date,
        status: _status,
        pricingMode: _pricingModeHT ? 'ht' : 'ttc',
        globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
        globalDiscountAmount: _globalDiscountAmount,
        timbreFiscal: _timbreFiscal,
        notes: _notes.isNotEmpty ? _notes : null,
        conditionsGenerales: _conditions.isNotEmpty ? _conditions : null,
        items: _items.map((item) => ReceivingVoucherItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          voucherId: voucherId,
          productId: item.productId,
          productName: item.productName,
          quantityExpected: item.quantityExpected,
          quantityReceived: item.quantityReceived,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          discountPercent: item.discountPercent,
        )).toList(),
      );

      if (_isEditing) {
        bloc.add(UpdateReceivingVoucher(order));
      } else {
        bloc.add(AddReceivingVoucher(order));
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
        description: item.productName ?? '',
        quantity: item.quantityReceived,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: true, warehouseId: _selectedWarehouseId);

    if (result != null) {
      setState(() {
        final newItem = ReceivingVoucherItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          voucherId: widget.existing?.id ?? '',
          productId: result.productId,
          productName: result.description,
          quantityExpected: result.quantity,
          quantityReceived: result.quantity,
          unitPrice: result.unitPrice,
          tvaRate: result.tvaRate,
          discountPercent: result.discountPercent,
        );

        if (index != null) {
          _items[index] = newItem;
        } else {
          _items.add(newItem);
        }
      });
    }
  }

  String _getStatusLabel(String status) {
    if (status == 'draft') return 'Brouillon';
    if (status == 'validated') return 'Validé';
    if (status == 'cancelled' || status == 'annule') return 'Annulé';
    if (status == 'payee' || status == 'paid') return 'Payée';
    if (status == 'unpaid') return 'Non payée';
    if (status == 'partiallyPaid' || status == 'partial') return 'Partiellement payée';
    return translateStatus(status);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
      case 'brouillon':
        return AppColors.warning;
      case 'validated':
      case 'validé':
      case 'paid':
      case 'payee':
      case 'payée':
        return AppColors.success;
      case 'cancelled':
      case 'annulé':
      case 'annule':
      case 'rejected':
      case 'rejeté':
        return AppColors.error;
      case 'unpaid':
      case 'non payée':
      case 'partiallypaid':
      case 'partial':
        return AppColors.info;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: widget.isReadOnly ? 'Détails du bon' : (_isEditing ? 'Modifier le bon' : 'Nouveau bon'),
      statusLabel: _getStatusLabel(_status),
      statusColor: _getStatusColor(_status),
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
                    designation: e.value.productName ?? 'Article',
                    quantity: e.value.quantityReceived,
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
                              _items.add(ReceivingVoucherItem(
                                id: _uuid.v4(),
                                voucherId: widget.existing?.id ?? '',
                                productId: newProd.id,
                                productName: newProd.name,
                                quantityExpected: 1,
                                quantityReceived: 1,
                                unitPrice: newProd.purchasePrice > 0 ? newProd.purchasePrice : newProd.sellingPrice,
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

