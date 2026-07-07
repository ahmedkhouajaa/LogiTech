import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/quotes/quotes_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/quote.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'customers_screen.dart';
import '../database/database_helper.dart';
import '../widgets/dashboard_card.dart';
import 'create_article_screen.dart';

class CreateQuoteScreen extends StatefulWidget {
  final Quote? existing;
  const CreateQuoteScreen({super.key, this.existing});

  @override
  State<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends State<CreateQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  String? _selectedCustomerId;
  String? _selectedProjectId;
  List<QuoteItem> _items = [];
  DateTime _date = DateTime.now();
  DateTime _validityDate = DateTime.now().add(const Duration(days: 30));
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  DocumentStatus _status = DocumentStatus.draft;
  bool _withTimbreFiscal = true;
  bool _pricingModeHT = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0.0;

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.computedTotalHT);

  double get _globalDiscountAmount => _withGlobalDiscount ? _totalHT * (_globalDiscountPercent / 100) : 0.0;

  double get _totalHTAfterDiscount => _totalHT - _globalDiscountAmount;

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      final discountFactor = _withGlobalDiscount ? (1 - (_globalDiscountPercent / 100)) : 1.0;
      final tvaAmount = item.computedTotalHT * discountFactor * (rate / 100);
      map[rate] = (map[rate] ?? 0) + tvaAmount;
    }
    return map;
  }

  double get _totalTvaAfterDiscount {
    double total = 0;
    _tvaBreakdown.forEach((rate, amount) => total += amount);
    return total;
  }

  double get _timbreFiscal => _withTimbreFiscal ? 1.0 : 0.0;

  double get _totalTTC => _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<ProjectsBloc>().add(LoadProjects());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _validityDate = n.validityDate;
      _selectedCustomerId = n.customerId;
      _selectedProjectId = n.projectId;
      _status = n.status;
      _pricingModeHT = n.pricingMode == 'ht';
      _globalDiscountPercent = n.globalDiscountPercent;
      _withGlobalDiscount = _globalDiscountPercent > 0;
      _withTimbreFiscal = n.timbreFiscal > 0;
      _notesCtrl.text = n.notes ?? '';
      _conditionsCtrl.text = n.conditionsGenerales ?? '';
      _items = n.items.map((i) => QuoteItem(
        id: i.id,
        quoteId: i.quoteId,
        productId: i.productId,
        productName: i.productName,
        description: i.description,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
      )).toList();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez selectionner un client'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final bloc = context.read<QuotesBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String number = widget.existing?.number ?? '';
    if (number.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextQuoteSequence();
      number = generateDocNumber('DV', seq);
    }

    final quoteId = widget.existing?.id ?? _uuid.v4();
    final quote = Quote(
      id: quoteId,
      number: number,
      customerId: _selectedCustomerId!,
      projectId: _selectedProjectId,
      date: _date,
      validityDate: _validityDate,
      status: _status,
      totalHT: _totalHTAfterDiscount,
      totalTva: _totalTvaAfterDiscount,
      totalTTC: _totalTTC,
      timbreFiscal: _timbreFiscal,
      globalDiscountPercent: _globalDiscountPercent,
      globalDiscountAmount: _globalDiscountAmount,
      pricingMode: _pricingModeHT ? 'ht' : 'ttc',
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      conditionsGenerales: _conditionsCtrl.text.trim().isEmpty ? null : _conditionsCtrl.text.trim(),
      items: _items.map((item) => QuoteItem(
        id: item.id,
        quoteId: quoteId,
        productId: item.productId,
        productName: item.productName,
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
        totalHT: item.computedTotalHT,
      )).toList(),
      isDeleted: widget.existing?.isDeleted ?? false,
      isConverted: widget.existing?.isConverted ?? false,
      convertedTo: widget.existing?.convertedTo,
      convertedToId: widget.existing?.convertedToId,
    );

    if (_isEditing) {
      bloc.add(UpdateQuote(quote));
    } else {
      bloc.add(AddQuote(quote));
    }

    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing
          ? 'Devis ${quote.number} mis a jour'
          : 'Devis ${quote.number} cree avec succes'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildArticlesSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildArticleActions(),
                    const SizedBox(height: AppSpacing.md),
                    _buildGlobalDiscountSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTotalsSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildNotesSection(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────
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
            _isEditing ? 'Modifier le devis' : 'Nouveau devis',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          StatusBadge(label: _status.label, color: _status.color),
          const Spacer(),
          _buildHeaderButton(
              Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          const SizedBox(width: 8),
          _buildHeaderButton(Icons.description_rounded, 'Brouillon', () {
            setState(() => _status = DocumentStatus.draft);
          }),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Valider',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(
      IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  // ── Form Card ─────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Date d'emission",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('fr', 'FR'),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller:
                              TextEditingController(text: formatDateLong(_date)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            suffixIcon: const Icon(Icons.calendar_today_rounded,
                                size: 16, color: AppColors.textTertiary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide:
                                    const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide:
                                    const BorderSide(color: AppColors.border)),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Date de validite",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _validityDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('fr', 'FR'),
                        );
                        if (picked != null) setState(() => _validityDate = picked);
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller:
                              TextEditingController(text: formatDateLong(_validityDate)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            suffixIcon: const Icon(Icons.calendar_today_rounded,
                                size: 16, color: AppColors.textTertiary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide:
                                    const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide:
                                    const BorderSide(color: AppColors.border)),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Client & Project
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: BlocBuilder<CustomersBloc, CustomersState>(
                            builder: (context, state) {
                              final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                              return DropdownButtonFormField<String>(
                                value: _selectedCustomerId,
                                isExpanded: true,
                                hint: const Text('Rechercher des clients...', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.companyName ?? c.name, style: const TextStyle(fontSize: 13, color: Colors.black87)))).toList(),
                                onChanged: (v) => setState(() => _selectedCustomerId = v),
                                validator: (v) => v == null ? 'Requis' : null,
                                decoration: _formInputDecoration(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: Tooltip(
                            message: 'Créer un nouveau client',
                            child: ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<CustomersBloc>(),
                                    child: const CustomerDialog(existing: null),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                foregroundColor: AppColors.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Projet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                        return DropdownButtonFormField<String>(
                          value: _selectedProjectId,
                          isExpanded: true,
                          hint: const Text('Projet par defaut', style: TextStyle(fontSize: 13, color: Colors.black87)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Projet par defaut', style: TextStyle(fontSize: 13))),
                            ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (v) => setState(() => _selectedProjectId = v),
                          decoration: _formInputDecoration(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Pricing mode radio
          const Text('Les prix des articles sont en', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              const Text('Hors taxes', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 24),
              Radio<bool>(
                value: false,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              const Text('Taxe incluse', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _formInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.textTertiary, fontSize: 13),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  // ── Articles Section ──────────────────────────────────────────────
  Widget _buildArticlesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text('Articles',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Designation',
                        style: _tableHeaderStyle())),
                SizedBox(
                    width: 140,
                    child: Text('Quantite',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 130,
                    child: Text('P.U HT',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 100,
                    child: Text('Remise %',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 100,
                    child: Text('TVA',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 140,
                    child: Text('Total HT',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right)),
                const SizedBox(width: 60),
              ],
            ),
          ),
          // Items
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              width: double.infinity,
              child: const Text('Aucun article',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textTertiary)),
            )
          else
            ..._items.asMap().entries.map((e) => _buildItemRow(e.key, e.value)),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary);
  }

  Widget _buildItemRow(int index, QuoteItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Designation
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: BlocBuilder<ProductsBloc, ProductsState>(
                        builder: (context, state) {
                          final products = state is ProductsLoaded ? state.products : <Product>[];
                          return Autocomplete<Product>(
                            initialValue: TextEditingValue(text: item.description ?? ''),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                              return products.where((Product p) => 
                                p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                                (p.reference?.toLowerCase().contains(textEditingValue.text.toLowerCase()) ?? false)
                              );
                            },
                            displayStringForOption: (Product option) => option.name,
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: _itemInputDecoration('Rechercher un article...'),
                                style: const TextStyle(fontSize: 13),
                                onChanged: (v) {
                                  // Update description manually if they just type
                                  setState(() => _items[index] = QuoteItem(
                                    id: item.id,
                                    quoteId: item.quoteId,
                                    productId: item.productId,
                                    productName: item.productName,
                                    description: v,
                                    quantity: item.quantity,
                                    unitPrice: item.unitPrice,
                                    tvaRate: item.tvaRate,
                                    discountPercent: item.discountPercent,
                                  ));
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, i) {
                                        final option = options.elementAt(i);
                                        return ListTile(
                                          title: Text(option.name, style: const TextStyle(fontSize: 13)),
                                          subtitle: option.reference != null ? Text(option.reference!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)) : null,
                                          trailing: Text('${option.sellingPrice.toStringAsFixed(2)} DT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          onTap: () => onSelected(option),
                                          dense: true,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            onSelected: (Product selection) {
                              setState(() {
                                _items[index] = QuoteItem(
                                  id: item.id,
                                  quoteId: item.quoteId,
                                  productId: selection.id,
                                  productName: selection.name,
                                  description: selection.name,
                                  unitPrice: selection.sellingPrice,
                                  tvaRate: selection.tvaRate,
                                  quantity: item.quantity,
                                  discountPercent: item.discountPercent,
                                );
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Quantite with - / + buttons
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        final newQ = item.quantity > 1 ? item.quantity - 1 : 1.0;
                        _items[index] = QuoteItem(
                          id: item.id, quoteId: item.quoteId, productId: item.productId,
                          productName: item.productName, description: item.description,
                          quantity: newQ, unitPrice: item.unitPrice,
                          tvaRate: item.tvaRate, discountPercent: item.discountPercent,
                        );
                      }),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(
                            'qty_${item.id}_${item.quantity}'),
                        initialValue: formatQuantity(item.quantity),
                        decoration: _itemInputDecoration(''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = QuoteItem(
                          id: item.id, quoteId: item.quoteId, productId: item.productId,
                          productName: item.productName, description: item.description,
                          quantity: double.tryParse(v) ?? 1, unitPrice: item.unitPrice,
                          tvaRate: item.tvaRate, discountPercent: item.discountPercent,
                        )),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => setState(() => _items[index] = QuoteItem(
                        id: item.id, quoteId: item.quoteId, productId: item.productId,
                        productName: item.productName, description: item.description,
                        quantity: item.quantity + 1, unitPrice: item.unitPrice,
                        tvaRate: item.tvaRate, discountPercent: item.discountPercent,
                      )),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.add,
                            size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // P.U
              SizedBox(
                width: 130,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('pu_${item.id}_${item.productId}'),
                        initialValue: item.unitPrice > 0
                            ? item.unitPrice.toStringAsFixed(0)
                            : '',
                        decoration: _itemInputDecoration(''),
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = QuoteItem(
                          id: item.id, quoteId: item.quoteId, productId: item.productId,
                          productName: item.productName, description: item.description,
                          quantity: item.quantity, unitPrice: double.tryParse(v) ?? 0,
                          tvaRate: item.tvaRate, discountPercent: item.discountPercent,
                        )),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'DT HT',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Remise
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('remise_${item.id}_init'),
                        initialValue: item.discountPercent > 0
                            ? item.discountPercent.toStringAsFixed(0)
                            : '',
                        decoration: _itemInputDecoration(''),
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = QuoteItem(
                          id: item.id, quoteId: item.quoteId, productId: item.productId,
                          productName: item.productName, description: item.description,
                          quantity: item.quantity, unitPrice: item.unitPrice,
                          tvaRate: item.tvaRate, discountPercent: double.tryParse(v) ?? 0,
                        )),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '%',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // TVA
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<double>(
                  value: item.tvaRate,
                  items: (TvaRates.all.contains(item.tvaRate) ? TvaRates.all : [...TvaRates.all, item.tvaRate])
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('${r.toInt()}%',
                              style:
                                  const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _items[index] = QuoteItem(
                    id: item.id, quoteId: item.quoteId, productId: item.productId,
                    productName: item.productName, description: item.description,
                    quantity: item.quantity, unitPrice: item.unitPrice,
                    tvaRate: v ?? 19, discountPercent: item.discountPercent,
                  )),
                  decoration: _itemInputDecoration(''),
                  isDense: true,
                ),
              ),
              const SizedBox(width: 8),
              // Total HT (read-only)
              SizedBox(
                width: 140,
                child: TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                      text: formatCurrencyDT(item.computedTotalHT)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(
                            color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(
                            color: AppColors.border)),
                  ),
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.error),
                onPressed: () =>
                    setState(() => _items.removeAt(index)),
                splashRadius: 16,
                tooltip: 'Supprimer',
              ),
              const Icon(Icons.drag_indicator_rounded,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _itemInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(fontSize: 12, color: AppColors.textTertiary),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  Widget _buildArticleActions() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _items.add(QuoteItem(
                id: _uuid.v4(),
                quoteId: '',
                productId: '',
                quantity: 1,
                unitPrice: 0,
                tvaRate: 19,
                discountPercent: 0,
              ));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Ajouter une ligne',
              style: TextStyle(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 24),
          tooltip: 'Créer un nouvel article',
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateArticleScreen()));
          },
          splashRadius: 24,
        ),
      ],
    );
  }

  // ─── Global Discount Section ─────────────────────────────────────
  Widget _buildGlobalDiscountSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _withGlobalDiscount = !_withGlobalDiscount),
            child: Row(
              children: [
                SizedBox(
                  width: 18, height: 18,
                  child: Checkbox(
                    value: _withGlobalDiscount,
                    onChanged: (v) => setState(() => _withGlobalDiscount = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: AppColors.border),
                    activeColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Ajouter une remise globale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_withGlobalDiscount) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    initialValue: _globalDiscountPercent > 0 ? _globalDiscountPercent.toString() : '',
                    decoration: _itemInputDecoration('Remise %'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() => _globalDiscountPercent = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Text('= ${formatCurrencyDT(_globalDiscountAmount)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Totals Section ────────────────────────────────────────────────
  Widget _buildTotalsSection() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildTotalLine('Sous-total HT:', formatCurrencyDT(_totalHTAfterDiscount)),
            const SizedBox(height: 6),
            // TVA breakdown
            ..._tvaBreakdown.entries.map((entry) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildTotalLine('TVA ${entry.key.toInt()}%:', formatCurrencyDT(entry.value)),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _withTimbreFiscal = !_withTimbreFiscal),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: Checkbox(
                            value: _withTimbreFiscal,
                            onChanged: (v) => setState(() => _withTimbreFiscal = v ?? false),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: AppColors.border),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Timbre fiscal:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    Text(formatCurrencyDT(_timbreFiscal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (_withGlobalDiscount && _globalDiscountAmount > 0) ...[
              _buildTotalLine('Remise:', '- ${formatCurrencyDT(_globalDiscountAmount)}'),
              const SizedBox(height: 6),
            ],
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total TTC:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(formatCurrencyDT(_totalTTC), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  // ── Notes Section ─────────────────────────────────────────────────
  Widget _buildNotesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Visible sur le document final',
                  hintStyle: const TextStyle(color: Colors.black87, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Conditions Generales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Conditions generales pour ce document',
                  hintStyle: const TextStyle(color: Colors.black87, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
