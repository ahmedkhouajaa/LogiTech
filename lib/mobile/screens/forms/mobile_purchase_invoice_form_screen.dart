import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/purchase_invoice.dart';
import '../../../../models/supplier.dart';
import '../../../../models/project.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../../../database/database_helper.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';
import '../../widgets/forms/mobile_article_card.dart';
import '../../widgets/forms/mobile_article_form.dart';
import '../../widgets/forms/mobile_totals_card.dart';

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
  String? _selectedProjectId;
  List<PurchaseInvoiceItem> _items = [];
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _notes = '';
  String _conditions = '';
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  InvoiceStatus _status = InvoiceStatus.draft;

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

    if (widget.existing != null) {
      final inv = widget.existing!;
      _date = inv.date;
      _dueDate = inv.dueDate;
      _selectedSupplierId = inv.supplierId;
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
        const SnackBar(content: Text('Veuillez sélectionner un fournisseur'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<PurchaseInvoicesBloc>();
      
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        number = generateDocNumber('FA', DateTime.now().millisecondsSinceEpoch % 1000000);
      }

      // Need supplier name
      String supplierName = '';
      final state = context.read<SuppliersBloc>().state;
      if (state is SuppliersLoaded) {
        final supplier = state.suppliers.firstWhere((s) => s.id == _selectedSupplierId);
        supplierName = supplier.name;
      }

      final invoiceId = widget.existing?.id ?? _uuid.v4();
      final invoice = PurchaseInvoice(
        id: invoiceId,
        number: number,
        supplierId: _selectedSupplierId!,
        supplierName: supplierName,
        projectId: _selectedProjectId,
        date: _date,
        dueDate: _dueDate,
        status: _status,
        pricingMode: _pricingModeHT ? 'ht' : 'ttc',
        globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
        timbreFiscal: _timbreFiscal,
        notes: _notes.isNotEmpty ? _notes : null,
        conditionsGenerales: _conditions.isNotEmpty ? _conditions : null,
        items: _items.map((item) => PurchaseInvoiceItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          purchaseInvoiceId: invoiceId,
          productId: item.productId,
          productName: item.productName ?? '',
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          discountPercent: item.discountPercent,
          showDescription: item.showDescription,
          showDiscount: item.showDiscount,
        )).toList(),
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
        productId: item.productId ?? '',
        productName: item.productName ?? '',
        description: item.description ?? item.productName ?? '',
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: true);

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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmartDatePicker(
                  label: 'Date d\'émission',
                  value: _date,
                  onChanged: (v) { if (!widget.isReadOnly) setState(() => _date = v); },
                ),
                const SizedBox(height: 16),
                SmartDatePicker(
                  label: 'Date d\'échéance',
                  value: _dueDate,
                  onChanged: (v) { if (!widget.isReadOnly) setState(() => _dueDate = v); },
                ),
                const SizedBox(height: 16),
                BlocBuilder<SuppliersBloc, SuppliersState>(
                  builder: (context, state) {
                    final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                    return SmartDropdown<String>(
                      label: 'Fournisseur',
                      value: _selectedSupplierId,
                      items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 16)))).toList(),
                      onChanged: (v) { if (!widget.isReadOnly) setState(() => _selectedSupplierId = v); },
                      hint: 'Rechercher des fournisseurs...',
                    );
                  },
                ),
                const SizedBox(height: 16),
                BlocBuilder<ProjectsBloc, ProjectsState>(
                  builder: (context, state) {
                    final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                    return SmartDropdown<String>(
                      label: 'Projet',
                      value: _selectedProjectId,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Projet par défaut', style: TextStyle(fontSize: 16))),
                        ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 16)))),
                      ],
                      onChanged: (v) { if (!widget.isReadOnly) setState(() => _selectedProjectId = v); },
                      hint: 'Projet par défaut',
                    );
                  },
                ),
                const SizedBox(height: 24),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: const Text('Aucun article ajouté', style: TextStyle(color: AppColors.textTertiary)),
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
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showArticleForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter une ligne'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SmartCheckbox(
                    label: 'Ajouter une remise globale',
                    value: _withGlobalDiscount,
                    onChanged: (v) => setState(() => _withGlobalDiscount = v ?? false),
                  ),
                  if (_withGlobalDiscount) ...[
                    const SizedBox(height: 8),
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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 8),
                SmartTextInput(
                  label: 'Notes',
                  initialValue: _notes,
                  maxLines: 3,
                  onChanged: widget.isReadOnly ? null : (v) => setState(() => _notes = v),
                ),
                const SizedBox(height: 16),
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
