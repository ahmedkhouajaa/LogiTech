import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../models/receiving_voucher.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';
import '../widgets/dashboard_card.dart';

enum ReceivingVoucherStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Validé', AppColors.success),
  partial('Réception partielle', AppColors.warning),
  canceled('Annulé', AppColors.error);

  final String label;
  final Color color;
  const ReceivingVoucherStatus(this.label, this.color);
}

class CreateReceivingVoucherScreen extends StatefulWidget {
  final ReceivingVoucher? existing;
  final bool isReadOnly;
  const CreateReceivingVoucherScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<CreateReceivingVoucherScreen> createState() => _CreateReceivingVoucherScreenState();
}

class _CreateReceivingVoucherScreenState extends State<CreateReceivingVoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  String? _selectedSupplierId;
  DateTime _date = DateTime.now();
  ReceivingVoucherStatus _status = ReceivingVoucherStatus.draft;
  List<ReceivingVoucherItem> _items = [];

  bool get _isEditing => widget.existing != null;
  bool get _isReadOnly => _status == ReceivingVoucherStatus.validated || _status == ReceivingVoucherStatus.canceled;

  @override
  void initState() {
    super.initState();
    context.read<SuppliersBloc>().add(LoadSuppliers());
    context.read<ProductsBloc>().add(LoadProducts());

    if (widget.existing != null) {
      final v = widget.existing!;
      _date = v.date;
      _selectedSupplierId = v.supplierId;
      _status = ReceivingVoucherStatus.values.firstWhere(
        (e) => e.name == v.status,
        orElse: () => ReceivingVoucherStatus.draft,
      );
      _items = v.items.map((i) => i.copyWith()).toList();
    }
  }

  Future<void> _save() async {
    if (_isReadOnly) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un fournisseur'), backgroundColor: AppColors.error));
      return;
    }

    final bloc = context.read<ReceivingVouchersBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

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
      status: _status.name,
      items: _items.map((item) => item.copyWith(voucherId: voucherId)).toList(),
    );

    if (_isEditing) {
      // bloc.add(UpdateReceivingVoucher(voucher)); // Not implemented yet
    } else {
      bloc.add(AddReceivingVoucher(voucher));
    }

    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing ? 'Bon de réception $number mis à jour' : 'Bon de réception $number créé avec succès'),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _buildFormCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildArticlesSection(),
                    if (!widget.isReadOnly) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildArticleActions(),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            _isEditing
                ? (widget.isReadOnly ? 'Détails du bon de réception' : 'Modifier le bon de réception')
                : 'Ajouter un bon de réception',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(_status.label, style: TextStyle(color: _status.color, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const Spacer(),
          _buildHeaderButton(Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          if (!widget.isReadOnly) ...[
            const SizedBox(width: 8),
            _buildHeaderButton(Icons.description_rounded, 'Brouillon', () {
              setState(() => _status = ReceivingVoucherStatus.draft);
            }),
            const SizedBox(width: 8),
            _buildHeaderButton(Icons.check_circle_rounded, 'Valider', () {
              setState(() => _status = ReceivingVoucherStatus.validated);
            }, color: AppColors.success),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
      label: Text(label, style: TextStyle(color: color ?? AppColors.textSecondary)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fournisseur
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fournisseur *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                BlocBuilder<SuppliersBloc, SuppliersState>(
                  builder: (context, state) {
                    List<Supplier> suppliers = [];
                    if (state is SuppliersLoaded) suppliers = state.suppliers;
                    
                    return DropdownButtonFormField<String>(
                      value: _selectedSupplierId,
                      decoration: const InputDecoration(hintText: 'Sélectionner un fournisseur...'),
                      items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: _isReadOnly ? null : (val) => setState(() => _selectedSupplierId = val),
                      validator: (v) => v == null ? 'Veuillez sélectionner un fournisseur' : null,
                      disabledHint: Text(
                        suppliers.firstWhere((s) => s.id == _selectedSupplierId, orElse: () => Supplier(name: 'Inconnu', code: '', id: '')).name,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isReadOnly ? null : () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      color: _isReadOnly ? AppColors.background : AppColors.surfaceAlt,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDateLong(_date), style: TextStyle(color: _isReadOnly ? AppColors.textSecondary : AppColors.textPrimary)),
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
              color: AppColors.background,
            ),
            child: Row(
              children: [
                if (!_isReadOnly) const SizedBox(width: 32),
                const Expanded(flex: 3, child: Text('Article', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                const Expanded(child: Text('Qté Attendue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                const Expanded(child: Text('Qté Reçue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                if (!_isReadOnly) const SizedBox(width: 48), // Actions
              ],
            ),
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Aucun article ajouté. Cliquez sur "Ajouter un article".', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _buildArticleRow(item, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArticleRow(ReceivingVoucherItem item, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isReadOnly)
            const SizedBox(
              width: 32,
              height: 40,
              child: Icon(Icons.drag_indicator, color: AppColors.textTertiary, size: 20),
            ),
          // Product
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: BlocBuilder<ProductsBloc, ProductsState>(
                builder: (context, state) {
                  List<Product> products = [];
                  if (state is ProductsLoaded) products = state.products;
                  
                  return DropdownButtonFormField<String>(
                    value: item.productId.isEmpty ? null : item.productId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      hintText: 'Sélectionner un article...',
                    ),
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _isReadOnly ? null : (val) {
                      if (val != null) setState(() => _items[index] = item.copyWith(productId: val));
                    },
                    disabledHint: Text(
                      products.firstWhere((p) => p.id == item.productId, orElse: () => Product(id: '', name: 'Inconnu', code: '', purchasePrice: 0, sellingPrice: 0)).name,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Expected Qty
          Expanded(
            child: TextFormField(
              initialValue: item.quantityExpected.toString(),
              keyboardType: TextInputType.number,
              readOnly: _isReadOnly,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0;
                setState(() => _items[index] = item.copyWith(quantityExpected: v));
              },
            ),
          ),
          const SizedBox(width: 8),
          // Received Qty
          Expanded(
            child: TextFormField(
              initialValue: item.quantityReceived.toString(),
              keyboardType: TextInputType.number,
              readOnly: _isReadOnly,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0;
                setState(() => _items[index] = item.copyWith(quantityReceived: v));
              },
            ),
          ),
          if (!_isReadOnly) ...[
            const SizedBox(width: 8),
            // Actions
            SizedBox(
              width: 48,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => setState(() => _items.removeAt(index)),
                tooltip: 'Supprimer',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArticleActions() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _items.add(ReceivingVoucherItem(voucherId: widget.existing?.id ?? '', productId: ''));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Ajouter un article'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            elevation: 0,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
