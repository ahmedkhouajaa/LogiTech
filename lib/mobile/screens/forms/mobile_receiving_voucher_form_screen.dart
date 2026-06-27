import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../blocs/products/products_bloc.dart';
import '../../../../models/receiving_voucher.dart';
import '../../../../models/supplier.dart';
import '../../../../models/product.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

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
  DateTime _date = DateTime.now();
  String _status = 'draft';
  List<ReceivingVoucherItem> _items = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<SuppliersBloc>().add(LoadSuppliers());
    context.read<ProductsBloc>().add(LoadProducts());

    if (widget.existing != null) {
      final v = widget.existing!;
      _date = v.date;
      _selectedSupplierId = v.supplierId;
      _status = v.status;
      _items = v.items.map((i) => i.copyWith()).toList();
    }
  }

  Future<void> _save() async {
    if (widget.isReadOnly) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un fournisseur'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<ReceivingVouchersBloc>();

      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        number = 'BR-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      }

      final voucherId = widget.existing?.id ?? _uuid.v4();
      final voucher = ReceivingVoucher(
        id: voucherId,
        number: number,
        supplierId: _selectedSupplierId!,
        orderId: widget.existing?.orderId,
        date: _date,
        status: _status,
        items: _items.map((item) => item.copyWith(voucherId: voucherId)).toList(),
      );

      if (_isEditing) {
        // bloc.add(UpdateReceivingVoucher(voucher)); // Ensure this exists or use Add if backend handles upsert
        bloc.add(AddReceivingVoucher(voucher)); // For now relying on this based on original code
      } else {
        bloc.add(AddReceivingVoucher(voucher));
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

  void _showAddArticleDialog() {
    if (widget.isReadOnly) return;
    String? selectedProductId;
    double expected = 1;
    double received = 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ajouter un article'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BlocBuilder<ProductsBloc, ProductsState>(
                    builder: (context, state) {
                      final products = state is ProductsLoaded ? state.products : <Product>[];
                      return DropdownButtonFormField<String>(
                        value: selectedProductId,
                        decoration: const InputDecoration(labelText: 'Article'),
                        items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                        onChanged: (v) => setDialogState(() => selectedProductId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: '1',
                    decoration: const InputDecoration(labelText: 'Quantité attendue'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => expected = double.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: '1',
                    decoration: const InputDecoration(labelText: 'Quantité reçue'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => received = double.tryParse(v) ?? 0,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedProductId != null) {
                      setState(() {
                        _items.add(ReceivingVoucherItem(
                          voucherId: widget.existing?.id ?? '',
                          productId: selectedProductId!,
                          quantityExpected: expected,
                          quantityReceived: received,
                        ));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: widget.isReadOnly ? 'Détails du bon' : (_isEditing ? 'Modifier le bon' : 'Nouveau bon'),
      statusLabel: _status == 'draft' ? 'Brouillon' : (_status == 'validated' ? 'Validé' : 'Annulé'),
      statusColor: _status == 'draft' ? AppColors.textSecondary : (_status == 'validated' ? AppColors.success : AppColors.error),
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
                  label: 'Date',
                  value: _date,
                  onChanged: (v) { if (!widget.isReadOnly) setState(() => _date = v); },
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
                  ..._items.asMap().entries.map((e) => _buildArticleItem(e.key, e.value)),
                if (!widget.isReadOnly) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _showAddArticleDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter une ligne'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArticleItem(int index, ReceivingVoucherItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                final products = state is ProductsLoaded ? state.products : <Product>[];
                final p = products.firstWhere((p) => p.id == item.productId, orElse: () => Product(id: '', name: 'Inconnu', code: '', purchasePrice: 0, sellingPrice: 0));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Attendue: ${item.quantityExpected.toStringAsFixed(0)} | Reçue: ${item.quantityReceived.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                );
              },
            ),
          ),
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => setState(() => _items.removeAt(index)),
            ),
        ],
      ),
    );
  }
}
