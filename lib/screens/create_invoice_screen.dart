import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/dashboard_card.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Invoice? existing;
  const CreateInvoiceScreen({super.key, this.existing});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  Customer? _selectedCustomer;
  List<InvoiceItem> _items = [];
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final _notesCtrl = TextEditingController();
  bool _withStampTax = false;

  double get _totalHT => _items.fold(0, (s, i) => s + i.computedTotalHT);
  double get _totalTva => _items.fold(0, (s, i) => s + i.tvaAmount);
  double get _totalTTC => _totalHT + _totalTva;
  double get _stampTax => _withStampTax ? calculateStampTax(_totalTTC) : 0;
  double get _grandTotal => _totalTTC + _stampTax;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<ProductsBloc>().add(LoadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Nouvelle facture',
        actions: [
          AppButton(label: 'Enregistrer', icon: Icons.save_rounded, onPressed: _save),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main form area
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(child: _buildHeaderSection()),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(child: _buildItemsSection()),
                  ],
                ),
              ),
            ),
            // Right totals panel
            SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    AppCard(child: _buildTotalsPanel()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Informations générales', icon: Icons.info_rounded),
        const SizedBox(height: 16),
        // Customer selector
        BlocBuilder<CustomersBloc, CustomersState>(
          builder: (context, state) {
            final customers = state is CustomersLoaded ? state.customers : <Customer>[];
            return AppDropdown<String>(
              label: 'Client *',
              value: _selectedCustomer?.id,
              hint: 'Sélectionner un client',
              items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _selectedCustomer = customers.firstWhere((c) => c.id == v)),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildDatePicker('Date', _date, (d) => setState(() => _date = d))),
          const SizedBox(width: 16),
          Expanded(child: _buildDatePicker('Date d\'échéance', _dueDate, (d) => setState(() => _dueDate = d))),
        ]),
        const SizedBox(height: 16),
        AppTextField(label: 'Notes', controller: _notesCtrl, maxLines: 2, hint: 'Conditions de paiement, remarques...'),
        const SizedBox(height: 12),
        Row(children: [
          Switch(value: _withStampTax, onChanged: (v) => setState(() => _withStampTax = v), activeColor: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Appliquer le droit de timbre (1% du TTC)', style: TextStyle(fontSize: 13)),
        ]),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime date, ValueChanged<DateTime> onPicked) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (picked != null) onPicked(picked);
      },
      child: AppTextField(
        label: label,
        controller: TextEditingController(text: formatDate(date)),
        readOnly: true,
        suffix: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const SectionHeader(title: 'Articles', icon: Icons.list_rounded),
          const Spacer(),
          AppButton(label: 'Ajouter', icon: Icons.add_rounded, isSmall: true, onPressed: _addItem),
        ]),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Aucun article ajouté', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ),
          )
        else
          ..._items.asMap().entries.map((e) => _buildItemRow(e.key, e.value)),
      ],
    );
  }

  Widget _buildItemRow(int index, InvoiceItem item) {
    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        final products = state is ProductsLoaded ? state.products : <Product>[];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(children: [
                Expanded(flex: 3, child: DropdownButtonFormField<String>(
                  value: item.productId.isEmpty ? null : item.productId,
                  hint: const Text('Sélectionner article', style: TextStyle(fontSize: 13)),
                  items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) {
                    final product = products.firstWhere((p) => p.id == v);
                    setState(() {
                      _items[index] = item.copyWith(
                        productId: v,
                        productName: product.name,
                        unitPrice: product.sellingPrice,
                        tvaRate: product.tvaRate,
                      );
                    });
                  },
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  ),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextFormField(
                  initialValue: item.quantity.toString(),
                  decoration: _inputDec('Qté'),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (v) => setState(() => _items[index] = item.copyWith(quantity: double.tryParse(v) ?? 1)),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: TextFormField(
                  initialValue: item.unitPrice.toStringAsFixed(2),
                  decoration: _inputDec('Prix (DA)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _items[index] = item.copyWith(unitPrice: double.tryParse(v) ?? 0)),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: DropdownButtonFormField<double>(
                  value: item.tvaRate,
                  items: TvaRates.all.map((r) => DropdownMenuItem(value: r, child: Text('${r.toInt()}%'))).toList(),
                  onChanged: (v) => setState(() => _items[index] = item.copyWith(tvaRate: v)),
                  decoration: _inputDec('TVA'),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextFormField(
                  initialValue: item.discountPercent.toString(),
                  decoration: _inputDec('Remise%'),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (v) => setState(() => _items[index] = item.copyWith(discountPercent: double.tryParse(v) ?? 0)),
                )),
                const SizedBox(width: 16),
                SizedBox(width: 110, child: Text(formatCurrency(item.computedTotalHT), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 18), onPressed: () => setState(() => _items.removeAt(index))),
              ]),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
    );
  }

  Widget _buildTotalsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Récapitulatif'),
        const SizedBox(height: 16),
        _buildTotalRow('Total HT', formatCurrency(_totalHT)),
        const SizedBox(height: 8),
        _buildTotalRow('Total TVA', formatCurrency(_totalTva)),
        if (_withStampTax) ...[
          const SizedBox(height: 8),
          _buildTotalRow('Droit de timbre', formatCurrency(_stampTax)),
        ],
        const Divider(height: 24),
        _buildTotalRow('Total TTC', formatCurrency(_grandTotal), bold: true, size: 16),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(children: [
            Text('${_items.length} article(s)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value, {bool bold = false, double size = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: bold ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }

  void _addItem() {
    setState(() {
      _items.add(InvoiceItem(
        id: _uuid.v4(),
        invoiceId: '',
        productId: '',
        quantity: 1,
        unitPrice: 0,
        tvaRate: 19,
      ));
    });
  }

  void _save() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: AppColors.error));
      return;
    }
    final invoiceId = _uuid.v4();
    final invoice = Invoice(
      id: invoiceId,
      number: generateDocNumber(DocPrefix.invoice, DateTime.now().millisecondsSinceEpoch % 100000),
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.name,
      date: _date,
      dueDate: _dueDate,
      status: InvoiceStatus.draft,
      totalHT: _totalHT,
      totalTva: _totalTva,
      totalTTC: _totalTTC,
      stampTax: _stampTax,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      items: _items.map((item) => item.copyWith(invoiceId: invoiceId)).toList(),
    );
    context.read<InvoicesBloc>().add(AddInvoice(invoice));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Facture ${invoice.number} créée avec succès'), backgroundColor: AppColors.success),
    );
  }
}
