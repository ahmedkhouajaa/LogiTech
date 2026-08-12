import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/credit_notes/credit_notes_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/invoices/invoices_bloc.dart';
import '../../../../models/credit_note.dart';
import '../../../../models/customer.dart';
import '../../../../models/invoice.dart';
import '../../../../models/product.dart';
import '../../../../blocs/products/products_bloc.dart';
import '../../../../blocs/warehouses/warehouses_bloc.dart';
import '../../../../blocs/warehouses/warehouses_state.dart';
import '../../../../blocs/warehouses/warehouses_event.dart';
import '../../../../models/stock_movement.dart' show Warehouse;
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../../../database/database_helper.dart';
import '../../../../screens/customers_screen.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';
import '../../widgets/forms/mobile_article_card.dart';
import '../../widgets/forms/mobile_article_form.dart';
import 'mobile_product_form_screen.dart';
import '../../widgets/forms/mobile_totals_card.dart';
import '../../../../widgets/searchable_dropdown_field.dart';

class MobileCreditNoteFormScreen extends StatefulWidget {
  final CreditNote? existing;
  final bool isReadOnly;
  const MobileCreditNoteFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileCreditNoteFormScreen> createState() => _MobileCreditNoteFormScreenState();
}

class _MobileCreditNoteFormScreenState extends State<MobileCreditNoteFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedInvoiceId;
  String? _selectedWarehouseId;
  List<CreditNoteItem> _items = [];
  DateTime _date = DateTime.now();
  String _reason = '';
  String _notes = '';
  CreditNoteStatus _status = CreditNoteStatus.unused;
  bool _withTimbreFiscal = true;

  bool get _isEditing => widget.existing != null;

  double get _totalHT => _items.fold(0, (s, i) => s + i.totalHT);

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      final tvaAmount = item.totalHT * (rate / 100);
      map[rate] = (map[rate] ?? 0) + tvaAmount;
    }
    return map;
  }

  double get _totalTva => _items.fold(0, (s, i) => s + (i.totalHT * (i.tvaRate / 100)));
  double get _timbreFiscal => _withTimbreFiscal ? 1.0 : 0.0;
  double get _totalTTC => _totalHT + _totalTva + _timbreFiscal;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<InvoicesBloc>().add(LoadInvoices());
    context.read<WarehousesBloc>().add(LoadWarehouses());

    if (widget.existing != null) {
      final cn = widget.existing!;
      _date = cn.date;
      _selectedCustomerId = cn.customerId;
      _selectedCustomerName = cn.customerName;
      _selectedInvoiceId = cn.invoiceId.isEmpty ? null : cn.invoiceId;
      _reason = cn.reason ?? '';
      _notes = cn.notes ?? '';
      _status = cn.status;
      _items = cn.items.map((i) => CreditNoteItem(
        id: i.id,
        productId: i.productId,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<CreditNotesBloc>();
      
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextCreditNoteSequence();
        number = generateDocNumber('AV', seq);
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

      final creditNoteId = widget.existing?.id ?? _uuid.v4();
      final creditNote = CreditNote(
        id: creditNoteId,
        number: number,
        invoiceId: _selectedInvoiceId ?? '',
        customerId: _selectedCustomerId!,
        customerName: custName ?? _selectedCustomerName,
        date: _date,
        reason: _reason.trim().isEmpty ? null : _reason.trim(),
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        status: _status,
        totalHT: _totalHT,
        totalTva: _totalTva,
        totalTTC: _totalTTC,
        items: _items.map((item) => CreditNoteItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          productId: item.productId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          totalHT: item.quantity * item.unitPrice,
        )).toList(),
        isDeleted: widget.existing?.isDeleted ?? false,
      );

      if (_isEditing) {
        bloc.add(UpdateCreditNote(creditNote));
      } else {
        bloc.add(AddCreditNote(creditNote));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Avoir mis à jour' : 'Avoir créé avec succès'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors de la sauvegarde: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addOrEditItem({CreditNoteItem? item, int? index}) async {
    final initialData = item != null ? MobileArticleFormResult(
      productId: item.productId,
      productName: 'Article',
      description: '',
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      tvaRate: item.tvaRate,
      discountPercent: 0,
    ) : null;

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: false, warehouseId: _selectedWarehouseId);
    if (result != null) {
      final newItem = CreditNoteItem(
        id: item?.id ?? _uuid.v4(),
        productId: result.productId,
        quantity: result.quantity,
        unitPrice: result.unitPrice,
        tvaRate: result.tvaRate,
        totalHT: result.computedTotalHT,
      );

      setState(() {
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
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: () {
        if (!widget.isReadOnly) _save();
      },
      children: [
        MobileFormSection(
          title: 'Informations Générales',
          icon: Icons.info_outline_rounded,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BlocBuilder<CustomersBloc, CustomersState>(
                        builder: (context, state) {
                          final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                          return AbsorbPointer(
                            absorbing: widget.isReadOnly,
                            child: SmartSearchableSelector(
                              label: 'Client *',
                              hint: 'Sélectionner un client',
                              selectedText: _selectedCustomerId != null
                                  ? (customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)?.companyName?.isNotEmpty == true
                                      ? customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)!.companyName!
                                      : (_selectedCustomerName ?? customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)?.name))
                                  : null,
                              onTap: () async {
                                final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedCustomerId);
                                if (res != null && mounted) {
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
                        margin: EdgeInsets.only(top: 24),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.person_add_alt_1_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16),
                BlocBuilder<InvoicesBloc, InvoicesState>(
                  builder: (context, state) {
                    final invoices = state is InvoicesLoaded ? state.invoices : <Invoice>[];
                    // Only show invoices for selected customer if possible
                    final filteredInvoices = _selectedCustomerId == null 
                        ? invoices 
                        : invoices.where((inv) => inv.customerId == _selectedCustomerId).toList();
                    
                    return AbsorbPointer(
                      absorbing: widget.isReadOnly,
                      child: SmartDropdown<String>(
                        label: 'Facture concernée (Optionnel)',
                        value: _selectedInvoiceId,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Aucune', style: TextStyle(fontSize: 16))),
                          ...filteredInvoices.map((inv) => DropdownMenuItem(value: inv.id, child: Text(inv.number, style: TextStyle(fontSize: 16)))),
                        ],
                        onChanged: (v) => setState(() => _selectedInvoiceId = v),
                        hint: 'Sélectionner une facture',
                      ),
                    );
                  },
                ),
                SizedBox(height: 16),
                BlocBuilder<WarehousesBloc, WarehousesState>(
                  builder: (context, state) {
                    final warehouses = state is WarehousesLoaded ? (List.of(state.warehouses)..sort((a,b) => a.name.compareTo(b.name))) : <Warehouse>[];
                    final selectedWh = warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _selectedWarehouseId, orElse: () => null);
                    final warehouseName = selectedWh != null ? selectedWh.name : 'Entrepôt Principal';

                    return SmartSearchableSelector(
                      label: 'Entrepôt',
                      hint: 'Sélectionner un entrepôt',
                      selectedText: warehouseName,
                      onTap: () async {
                        final res = await showWarehouseSelectDialog(context, warehouses, selectedWarehouseId: _selectedWarehouseId);
                        if (res != null && mounted) {
                          setState(() => _selectedWarehouseId = res);
                        }
                      },
                    );
                  },
                ),
                SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDatePicker(
                    label: 'Date de l\'avoir',
                    value: _date,
                    onChanged: (v) => setState(() => _date = v),
                  ),
                ),
              ],
            ),
          ),
        ),

        MobileFormSection(
          title: 'Articles de l\'avoir',
          icon: Icons.inventory_2_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_items.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Aucun article ajouté', style: TextStyle(color: AppColors.textTertiary))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return MobileArticleCard(
                      index: index,
                      designation: 'Article',
                      quantity: item.quantity,
                      unitPrice: item.unitPrice,
                      tvaRate: item.tvaRate,
                      discountPercent: 0,
                      totalHT: item.totalHT,
                      onEdit: () => _addOrEditItem(item: item, index: index),
                      onDelete: () => setState(() => _items.removeAt(index)),
                    );
                  },
                ),
              if (!widget.isReadOnly)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
   children: [
     Expanded(
       child: OutlinedButton.icon(
                          onPressed: () => _addOrEditItem(),
                          icon: Icon(Icons.add_circle_outline_rounded),
                          label: Text('Ajouter un article'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(vertical: 12),
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
              _items.add(CreditNoteItem(
                id: _uuid.v4(),
                productId: newProd.id,
                productName: newProd.name,
                quantity: 1,
                unitPrice: newProd.sellingPrice,
                tvaRate: newProd.tvaRate,
                totalHT: newProd.sellingPrice,
              ));
            });
          }
        },
      ),
   ],
 ),
                ),
            ],
          ),
        ),

        MobileTotalsCard(
          subTotalHT: _totalHT,
          tvaBreakdown: _tvaBreakdown,
          totalTva: _totalTva,
          timbreFiscal: 1.0,
          applyTimbreFiscal: _withTimbreFiscal,
          onTimbreFiscalChanged: (v) => setState(() => _withTimbreFiscal = v ?? false),
          totalTTC: _totalTTC,
        ),

        MobileFormSection(
          title: 'Notes & Motif',
          icon: Icons.notes_outlined,
          isInitiallyExpanded: false,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<CreditNoteStatus>(
                    label: 'Statut',
                    value: _status,
                    items: CreditNoteStatus.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.label, style: TextStyle(fontSize: 16)));
                    }).toList(),
                    onChanged: (v) { if (v != null) setState(() => _status = v); },
                  ),
                ),
                SizedBox(height: 16),
                SmartTextInput(
                  label: 'Motif de l\'avoir',
                  initialValue: _reason,
                  maxLines: 2,
                  onChanged: (v) { if (!widget.isReadOnly) _reason = v; },
                ),
                SizedBox(height: 16),
                SmartTextInput(
                  label: 'Notes internes',
                  initialValue: _notes,
                  maxLines: 2,
                  onChanged: (v) { if (!widget.isReadOnly) _notes = v; },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
