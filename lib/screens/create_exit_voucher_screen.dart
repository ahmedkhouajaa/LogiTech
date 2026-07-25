import 'package:flutter/material.dart';
import '../widgets/searchable_dropdown_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/exit_vouchers/exit_vouchers_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/stock_withdrawal.dart';


import '../models/customer.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'customers_screen.dart';
import '../database/database_helper.dart';
import '../widgets/dashboard_card.dart';
import 'create_article_screen.dart';

class CreateExitVoucherScreen extends StatefulWidget {
  final StockWithdrawal? existing;
  const CreateExitVoucherScreen({super.key, this.existing});

  @override
  State<CreateExitVoucherScreen> createState() => _CreateExitVoucherScreenState();
}

class _CreateExitVoucherScreenState extends State<CreateExitVoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  String? _selectedCustomerId;
  String? _selectedProjectId;
  List<ExitVoucherItemUI> _items = [];
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _vehicleRegistrationCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
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
      _selectedCustomerId = n.customerId;
      _selectedProjectId = n.projectId;
      _status = DocumentStatus.values.firstWhere((e) => e.name == n.status, orElse: () => DocumentStatus.draft);
      _pricingModeHT = n.pricingMode == 'ht';
      _globalDiscountPercent = n.globalDiscountPercent;
      _withGlobalDiscount = _globalDiscountPercent > 0;
      _withTimbreFiscal = n.timbreFiscal > 0;
      _notesCtrl.text = n.notes ?? '';
      _conditionsCtrl.text = n.conditionsGenerales ?? '';
      _vehicleRegistrationCtrl.text = n.vehicleRegistration ?? '';
      _driverNameCtrl.text = n.driverName ?? '';
      _items = n.items.map((i) => ExitVoucherItemUI(
        id: i.id,
        productId: i.productId,
        productName: '',
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
    _vehicleRegistrationCtrl.dispose();
    _driverNameCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Veuillez selectionner un client'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final bloc = context.read<ExitVouchersBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String number = widget.existing?.number ?? '';
    if (number.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextStockWithdrawalSequence();
      number = generateDocNumber('BS', seq);
    }

    final withdrawalId = widget.existing?.id ?? _uuid.v4();
    final withdrawal = StockWithdrawal(
      id: withdrawalId,
      number: number,
      customerId: _selectedCustomerId!,
      projectId: _selectedProjectId,
      date: _date,
      status: _status.name,
      timbreFiscal: _timbreFiscal,
      globalDiscountPercent: _globalDiscountPercent,
      globalDiscountAmount: _globalDiscountAmount,
      pricingMode: _pricingModeHT ? 'ht' : 'ttc',
      vehicleRegistration: _vehicleRegistrationCtrl.text.trim().isEmpty ? null : _vehicleRegistrationCtrl.text.trim(),
      driverName: _driverNameCtrl.text.trim().isEmpty ? null : _driverNameCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      conditionsGenerales: _conditionsCtrl.text.trim().isEmpty ? null : _conditionsCtrl.text.trim(),
      items: _items.map((item) => StockWithdrawalItem(
        id: item.id,
        withdrawalId: withdrawalId,
        productId: item.productId,
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
      )).toList(),
      isDeleted: widget.existing?.isDeleted ?? false,
    );

    if (_isEditing) {
      bloc.add(UpdateExitVoucher(withdrawal));
    } else {
      bloc.add(AddExitVoucher(withdrawal));
    }

    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing
          ? 'Bon de Sortie ${withdrawal.number} mis a jour'
          : 'Bon de Sortie ${withdrawal.number} cree avec succes'),
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
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormCard(),
                    SizedBox(height: AppSpacing.lg),
                    _buildArticlesSection(),
                    SizedBox(height: AppSpacing.md),
                    _buildArticleActions(),
                    SizedBox(height: AppSpacing.md),
                    _buildGlobalDiscountSection(),
                    SizedBox(height: AppSpacing.lg),
                    _buildTotalsSection(),
                    SizedBox(height: AppSpacing.lg),
                    _buildNotesSection(),
                    SizedBox(height: AppSpacing.xl),
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
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.sm,
      ),
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            _isEditing ? 'Modifier le bon de sortie' : 'Nouveau bon de sortie',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          SizedBox(width: 12),
          StatusBadge(label: _status.label, color: _status.color),
          const Spacer(),
          _buildHeaderButton(
              Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.description_rounded, 'Brouillon', () {
            setState(() => _status = DocumentStatus.draft);
          }),
          SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(Icons.check_rounded, size: 16),
              label: Text('Valider',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: EdgeInsets.symmetric(horizontal: 16),
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
                TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  // ── Form Card ─────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(24),
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
                    Text("Date d'emission",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    SizedBox(height: 6),
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
                            fillColor: AppColors.surfaceAlt,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            suffixIcon: Icon(Icons.calendar_today_rounded,
                                size: 16, color: AppColors.textTertiary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide:
                                    BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide:
                                    BorderSide(color: AppColors.border)),
                          ),
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Champs Personnalisés
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Champs Personnalisés', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                SizedBox(height: 4),
                Text('Informations supplémentaires spécifiques à ce type de document', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Matricule du véhicule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          SizedBox(height: 6),
                          TextFormField(
                            controller: _vehicleRegistrationCtrl,
                            decoration: _formInputDecoration(hint: 'Entrer la valeur'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nom du chauffeur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          SizedBox(height: 6),
                          TextFormField(
                            controller: _driverNameCtrl,
                            decoration: _formInputDecoration(hint: 'Entrer la valeur'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Client & Project
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: BlocBuilder<CustomersBloc, CustomersState>(
                            builder: (context, state) {
                              final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                              final selectedCustomer = customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null);

                              final displayName = selectedCustomer != null

                                  ? (selectedCustomer.companyName?.isNotEmpty == true

                                      ? selectedCustomer.companyName!

                                      : (selectedCustomer.responsibleName?.isNotEmpty == true

                                          ? selectedCustomer.responsibleName!

                                          : selectedCustomer.name))

                                  : null;


                              return FormField<String>(

                                initialValue: _selectedCustomerId,

                                validator: (v) => _selectedCustomerId == null ? 'Requis' : null,

                                builder: (field) {

                                  return Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      SearchableSelectorField(

                                        hint: 'Rechercher des clients...',

                                        selectedText: displayName,

                                        hasError: field.hasError,

                                        onTap: () async {

                                          final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedCustomerId);

                                          if (res != null) {

                                            setState(() => _selectedCustomerId = res);

                                            field.didChange(res);

                                          }

                                        },

                                      ),

                                      if (field.hasError) ...[

                                        SizedBox(height: 4),

                                        Padding(

                                          padding: EdgeInsets.only(left: 4),

                                          child: Text(field.errorText!, style: TextStyle(color: AppColors.error, fontSize: 11)),

                                        ),

                                      ],

                                    ],

                                  );

                                },

                              );
                            },
                          ),
                        ),
                        SizedBox(width: 8),
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
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Icon(Icons.person_add_alt_1_rounded, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                        final selectedProject = projects.cast<Project?>().firstWhere((p) => p?.id == _selectedProjectId, orElse: () => null);


                        return SearchableSelectorField(

                          hint: 'Projet par defaut',

                          selectedText: selectedProject?.name ?? 'Projet par defaut',

                          onTap: () async {

                            final res = await showProjectSelectDialog(context, projects, selectedProjectId: _selectedProjectId);

                            if (res != null) {

                              setState(() => _selectedProjectId = (res == '__default__' ? null : res));

                            }

                          },

                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          // Pricing mode radio
          Text('Les prix des articles sont en', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              Text('Hors taxes', style: TextStyle(fontSize: 13)),
              SizedBox(width: 24),
              Radio<bool>(
                value: false,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              Text('Taxe incluse', style: TextStyle(fontSize: 13)),
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
          TextStyle(color: AppColors.textTertiary, fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding:
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: AppColors.primary, width: 1.5)),
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
          Padding(
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
                EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
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
                SizedBox(width: 60),
              ],
            ),
          ),
          // Items
          if (_items.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 32),
              width: double.infinity,
              child: Text('Aucun article',
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
    return TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary);
  }

  Widget _buildItemRow(int index, ExitVoucherItemUI item) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                style: TextStyle(fontSize: 13),
                                onChanged: (v) {
                                  // Update description manually if they just type
                                  setState(() => _items[index] = ExitVoucherItemUI(
                                    id: item.id,
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
                                          title: Text(option.name, style: TextStyle(fontSize: 13)),
                                          subtitle: option.reference != null ? Text(option.reference!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)) : null,
                                          trailing: Text('${option.sellingPrice.toStringAsFixed(2)} DT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                _items[index] = ExitVoucherItemUI(
                                  id: item.id,
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
              SizedBox(width: 8),
              // Quantite with - / + buttons
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        final newQ = item.quantity > 1 ? item.quantity - 1 : 1.0;
                        _items[index] = ExitVoucherItemUI(
                          id: item.id, productId: item.productId,
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
                        child: Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(
                            'qty_${item.id}_${item.quantity}'),
                        initialValue: formatQuantity(item.quantity),
                        decoration: _itemInputDecoration(''),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = ExitVoucherItemUI(
                          id: item.id, productId: item.productId,
                          productName: item.productName, description: item.description,
                          quantity: double.tryParse(v) ?? 1, unitPrice: item.unitPrice,
                          tvaRate: item.tvaRate, discountPercent: item.discountPercent,
                        )),
                      ),
                    ),
                    SizedBox(width: 4),
                    InkWell(
                      onTap: () => setState(() => _items[index] = ExitVoucherItemUI(
                        id: item.id, productId: item.productId,
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
                        child: Icon(Icons.add,
                            size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
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
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = ExitVoucherItemUI(
                          id: item.id, productId: item.productId,
                          productName: item.productName, description: item.description,
                          quantity: item.quantity, unitPrice: double.tryParse(v) ?? 0,
                          tvaRate: item.tvaRate, discountPercent: item.discountPercent,
                        )),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'DT HT',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
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
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = ExitVoucherItemUI(
                          id: item.id, productId: item.productId,
                          productName: item.productName, description: item.description,
                          quantity: item.quantity, unitPrice: item.unitPrice,
                          tvaRate: item.tvaRate, discountPercent: double.tryParse(v) ?? 0,
                        )),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '%',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // TVA
              SizedBox(
                width: 100,
                child: DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  value: item.tvaRate,
                  items: (TvaRates.all.contains(item.tvaRate) ? TvaRates.all : [...TvaRates.all, item.tvaRate])
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('${r.toInt()}%',
                              style:
                                  TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _items[index] = ExitVoucherItemUI(
                    id: item.id, productId: item.productId,
                    productName: item.productName, description: item.description,
                    quantity: item.quantity, unitPrice: item.unitPrice,
                    tvaRate: v ?? 19, discountPercent: item.discountPercent,
                  )),
                  decoration: _itemInputDecoration(''),
                  isDense: true,
                ),
              ),
              SizedBox(width: 8),
              // Total HT (read-only)
              SizedBox(
                width: 140,
                child: TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                      text: formatCurrencyDT(item.computedTotalHT)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                            color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                            color: AppColors.border)),
                  ),
                  style: TextStyle(fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.error),
                onPressed: () =>
                    setState(() => _items.removeAt(index)),
                splashRadius: 16,
                tooltip: 'Supprimer',
              ),
              Icon(Icons.drag_indicator_rounded,
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
          TextStyle(fontSize: 12, color: AppColors.textTertiary),
      isDense: true,
      contentPadding:
          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

    Widget _buildArticleActions() {
    return Row(
      children: [
        Expanded(
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              final products = state is ProductsLoaded ? state.products : <Product>[];
              return SearchableSelectorField(
                hint: 'Sélectionner un article...',
                selectedText: null,
                onTap: () async {
                  final res = await showProductSelectDialog(context, products);
                  if (res != null) {
                    final product = products.firstWhere((p) => p.id == res);
                    setState(() {
                      _items.add(ExitVoucherItemUI(
                        id: _uuid.v4(),
                        productId: product.id,
                        productName: product.name,
                        quantity: 1,
                        unitPrice: product.sellingPrice,
                        tvaRate: product.tvaRate,
                        discountPercent: 0,
                      ));
                    });
                  }
                },
              );
            },
          ),
        ),
        SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _items.add(ExitVoucherItemUI(
                id: _uuid.v4(),
                productId: '',
                productName: '',
                quantity: 1,
                unitPrice: 0,
                tvaRate: 19,
                discountPercent: 0,
              ));
            });
          },
          icon: Icon(Icons.add_rounded, size: 16),
          label: Text('Ajouter une ligne vide', style: TextStyle(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ─── Global Discount Section ─────────────────────────────────────
  Widget _buildGlobalDiscountSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
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
                SizedBox(width: 8),
                Text('Ajouter une remise globale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_withGlobalDiscount) ...[
            SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    initialValue: _globalDiscountPercent > 0 ? _globalDiscountPercent.toString() : '',
                    decoration: _itemInputDecoration('Remise %'),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() => _globalDiscountPercent = double.tryParse(v) ?? 0),
                  ),
                ),
                SizedBox(width: 12),
                Text('= ${formatCurrencyDT(_globalDiscountAmount)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
            SizedBox(height: 6),
            // TVA breakdown
            ..._tvaBreakdown.entries.map((entry) =>
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: _buildTotalLine('TVA ${entry.key.toInt()}%:', formatCurrencyDT(entry.value)),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _withTimbreFiscal = !_withTimbreFiscal),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
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
                        SizedBox(width: 8),
                        Text('Timbre fiscal:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    Text(formatCurrencyDT(_timbreFiscal), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6),
            if (_withGlobalDiscount && _globalDiscountAmount > 0) ...[
              _buildTotalLine('Remise:', '- ${formatCurrencyDT(_globalDiscountAmount)}'),
              SizedBox(height: 6),
            ],
            Divider(),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total TTC:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(formatCurrencyDT(_totalTTC), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
              Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Visible sur le document final',
                  hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conditions Generales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Conditions generales pour ce document',
                  hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class ExitVoucherItemUI {
  final String id;
  final String productId;
  final String productName;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;

  ExitVoucherItemUI({
    required this.id,
    required this.productId,
    required this.productName,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.tvaRate,
    required this.discountPercent,
  });

  double get computedTotalHT {
    final priceAfterDiscount = unitPrice * (1 - (discountPercent / 100));
    return priceAfterDiscount * quantity;
  }

  ExitVoucherItemUI copyWith({
    String? productId,
    String? productName,
    String? description,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? discountPercent,
  }) {
    return ExitVoucherItemUI(
      id: id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      tvaRate: tvaRate ?? this.tvaRate,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}
