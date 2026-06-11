import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/products/products_bloc.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(children: [
            AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
            const Spacer(),
            AppButton(label: 'Nouvel article', icon: Icons.add_rounded, onPressed: () => _showDialog(context, null)),
          ]),
        ),
        Expanded(
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              if (state is ProductsLoading) return const Center(child: CircularProgressIndicator());
              if (state is ProductsError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is ProductsLoaded) {
                final filtered = _search.isEmpty ? state.products
                    : state.products.where((p) => p.name.toLowerCase().contains(_search) || p.code.toLowerCase().contains(_search)).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Product>(
                      columns: const ['Code', 'Nom', 'Catégorie', 'Unité', 'Prix Achat', 'Prix Vente', 'TVA', 'Stock', 'Statut'],
                      rows: filtered,
                      emptyMessage: 'Aucun article trouvé',
                      cellBuilder: (p) => [
                        DataCell(Text(p.code, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(p.category ?? '—')),
                        DataCell(Text(p.unit)),
                        DataCell(Text(formatCurrency(p.purchasePrice))),
                        DataCell(Text(formatCurrency(p.sellingPrice))),
                        DataCell(Text('${p.tvaRate.toInt()}%')),
                        DataCell(Text(
                          '${formatQuantity(p.stockQty)} ${p.unit}',
                          style: TextStyle(color: p.isLowStock ? AppColors.error : AppColors.textPrimary, fontWeight: p.isLowStock ? FontWeight.bold : FontWeight.normal),
                        )),
                        DataCell(p.isLowStock
                            ? const StatusBadge(label: 'Stock bas', color: AppColors.error)
                            : p.isActive
                                ? const StatusBadge(label: 'Actif', color: AppColors.success)
                                : const StatusBadge(label: 'Inactif', color: AppColors.textTertiary)),
                      ],
                      onEdit: (p) => _showDialog(context, p),
                      onDelete: (p) => context.read<ProductsBloc>().add(DeleteProduct(p.id)),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _showDialog(BuildContext context, Product? existing) {
    showDialog(context: context, builder: (_) => BlocProvider.value(
      value: context.read<ProductsBloc>(),
      child: _ProductDialog(existing: existing),
    ));
  }
}

class _ProductDialog extends StatefulWidget {
  final Product? existing;
  const _ProductDialog({this.existing});
  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl, _nameCtrl, _descCtrl, _catCtrl, _unitCtrl, _purchCtrl, _sellCtrl, _minStockCtrl, _barcodeCtrl;
  double _tvaRate = 19;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _codeCtrl = TextEditingController(text: p?.code ?? 'ART-${DateTime.now().millisecondsSinceEpoch % 10000}');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _catCtrl = TextEditingController(text: p?.category ?? '');
    _unitCtrl = TextEditingController(text: p?.unit ?? 'Unité');
    _purchCtrl = TextEditingController(text: p?.purchasePrice.toString() ?? '0');
    _sellCtrl = TextEditingController(text: p?.sellingPrice.toString() ?? '0');
    _minStockCtrl = TextEditingController(text: p?.minStockQty.toString() ?? '0');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _tvaRate = p?.tvaRate ?? 19;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    for (var c in [_codeCtrl, _nameCtrl, _descCtrl, _catCtrl, _unitCtrl, _purchCtrl, _sellCtrl, _minStockCtrl, _barcodeCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF059669), const Color(0xFF10B981)]),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.lg), topRight: Radius.circular(AppRadius.lg)),
              ),
              child: Row(children: [
                const Icon(Icons.inventory_2_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(widget.existing == null ? 'Nouvel article' : 'Modifier article', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: AppTextField(label: 'Code *', controller: _codeCtrl, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: AppTextField(label: 'Nom *', controller: _nameCtrl, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: AppTextField(label: 'Catégorie', controller: _catCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: AppTextField(label: 'Unité', controller: _unitCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: AppTextField(label: 'Code-barres', controller: _barcodeCtrl)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: AppTextField(label: 'Prix d\'achat (DA)', controller: _purchCtrl, keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: AppTextField(label: 'Prix de vente (DA)', controller: _sellCtrl, keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TVA (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<double>(
                            value: _tvaRate,
                            items: TvaRates.all.map((r) => DropdownMenuItem(value: r, child: Text('${r.toInt()}%'))).toList(),
                            onChanged: (v) => setState(() => _tvaRate = v ?? 19),
                            decoration: InputDecoration(
                              filled: true, fillColor: AppColors.surfaceAlt,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: AppTextField(label: 'Stock minimum alerte', controller: _minStockCtrl, keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeColor: AppColors.success),
                            Text(_isActive ? 'Actif' : 'Inactif'),
                          ]),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 16),
                    AppTextField(label: 'Description', controller: _descCtrl, maxLines: 2),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                const Spacer(),
                AppButton(label: 'Enregistrer', icon: Icons.save_rounded, onPressed: _save),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final product = Product(
      id: widget.existing?.id ?? const Uuid().v4(),
      code: _codeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      category: _catCtrl.text.trim().isEmpty ? null : _catCtrl.text.trim(),
      unit: _unitCtrl.text.trim().isEmpty ? 'Unité' : _unitCtrl.text.trim(),
      purchasePrice: double.tryParse(_purchCtrl.text) ?? 0,
      sellingPrice: double.tryParse(_sellCtrl.text) ?? 0,
      tvaRate: _tvaRate,
      stockQty: widget.existing?.stockQty ?? 0,
      minStockQty: double.tryParse(_minStockCtrl.text) ?? 0,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      isActive: _isActive,
      updatedAt: DateTime.now(),
    );
    if (widget.existing == null) {
      context.read<ProductsBloc>().add(AddProduct(product));
    } else {
      context.read<ProductsBloc>().add(UpdateProduct(product));
    }
    Navigator.pop(context);
  }
}
