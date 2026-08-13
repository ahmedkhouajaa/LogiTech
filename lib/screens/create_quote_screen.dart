import '../widgets/searchable_dropdown_field.dart';
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
import '../blocs/stock/stock_bloc.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../blocs/warehouses/warehouses_event.dart';
import '../models/stock_movement.dart' show Warehouse;
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'customers_screen.dart';
import '../database/database_helper.dart';
import '../widgets/dashboard_card.dart';
import 'create_article_screen.dart';
import 'package:business_manager_pro/services/error_handler.dart';

class CreateQuoteScreen extends StatefulWidget {
  final Quote? existing;
  const CreateQuoteScreen({super.key, this.existing});

  @override
  State<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends State<CreateQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _isSaving = false;

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
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
    if (context.read<StockBloc>().state is! StockLoaded) {
      context.read<StockBloc>().add(LoadStock());
    }
    context.read<WarehousesBloc>().add(LoadWarehouses());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _validityDate = n.validityDate;
      _selectedCustomerId = n.customerId;
      _selectedCustomerName = n.customerName;
      _selectedProjectId = n.projectId;
      _selectedWarehouseId = n.warehouseId;
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
        SnackBar(
          content: Text('Veuillez selectionner un client'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bloc = context.read<QuotesBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final bloc = context.read<QuotesBloc>();
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextQuoteSequence();
        number = generateDocNumber('DV', seq);
      }

      final custState = context.read<CustomersBloc>().state;
      String? custName = _selectedCustomerName;
      
      if (custName == null && custState is CustomersLoaded) {
        final found = custState.customers.cast<Customer?>().firstWhere(
          (c) => c?.id == _selectedCustomerId,
          orElse: () => null,
        );
        if (found != null) {
          custName = found.companyName?.isNotEmpty == true
              ? found.companyName
              : (found.responsibleName?.isNotEmpty == true ? found.responsibleName : found.name);
        }
      }
      custName ??= 'Client Inconnu';

      final quoteId = widget.existing?.id ?? _uuid.v4();
      final quote = Quote(
        id: quoteId,
        number: number,
        customerId: _selectedCustomerId!,
        customerName: custName,
        projectId: _selectedProjectId,
        warehouseId: _selectedWarehouseId,
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
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
            _isEditing ? 'Modifier le devis' : 'Nouveau devis',
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
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.check_rounded, size: 16),
              label: Text(_isSaving ? 'Enregistrement...' : 'Valider',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Date de validite",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    SizedBox(height: 6),
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
                              final displayName = _selectedCustomerName;

                              return FormField<String>(
                                initialValue: _selectedCustomerId,
                                validator: (v) => _selectedCustomerId == null ? 'Requis' : null,
                                builder: (field) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSearchableField(
                                        hint: 'Rechercher des clients...',
                                        selectedText: displayName,
                                        hasError: field.hasError,
                                        onTap: () async {
                                          final res = await _showCustomerSelectDialog(context, customers);
                                          if (res != null) {
                                            final displayName = res.companyName?.isNotEmpty == true
                                                ? res.companyName!
                                                : (res.responsibleName?.isNotEmpty == true
                                                    ? res.responsibleName!
                                                    : res.name);
                                            setState(() {
                                              _selectedCustomerId = res.id;
                                              _selectedCustomerName = displayName;
                                            });
                                            field.didChange(res.id);
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
                              onPressed: () async {
                                final newRes = await showDialog<dynamic>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<CustomersBloc>(),
                                    child: const CustomerDialog(existing: null),
                                  ),
                                );
                                if (newRes != null && mounted) {
                                  if (newRes is Customer) {
                                    final displayName = newRes.companyName?.isNotEmpty == true
                                        ? newRes.companyName!
                                        : (newRes.responsibleName?.isNotEmpty == true
                                            ? newRes.responsibleName!
                                            : newRes.name);
                                    setState(() {
                                      _selectedCustomerId = newRes.id;
                                      _selectedCustomerName = displayName;
                                    });
                                  } else if (newRes is String) {
                                    setState(() => _selectedCustomerId = newRes);
                                  }
                                }
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

                        return _buildSearchableField(
                          hint: 'Projet par defaut',
                          selectedText: selectedProject?.name ?? 'Projet par defaut',
                          onTap: () async {
                            final res = await _showProjectSelectDialog(context, projects);
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
          SizedBox(height: 16),
          // Entrepôt field (under Projet)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entrepôt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              SizedBox(height: 6),
              BlocBuilder<WarehousesBloc, WarehousesState>(
                builder: (context, state) {
                  final warehouses = state is WarehousesLoaded ? state.warehouses : <Warehouse>[];
                  final defaultWh = warehouses.cast<Warehouse?>().firstWhere(
                    (w) => w?.isDefault == true,
                    orElse: () => warehouses.cast<Warehouse?>().firstWhere((w) => w?.name.toLowerCase().contains('défaut') == true || w?.name.toLowerCase().contains('defaut') == true, orElse: () => warehouses.isNotEmpty ? warehouses.first : null),
                  );
                  if (_selectedWarehouseId == null && defaultWh != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _selectedWarehouseId == null) {
                        setState(() => _selectedWarehouseId = defaultWh.id);
                      }
                    });
                  }
                  final selectedWh = warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == (_selectedWarehouseId ?? defaultWh?.id), orElse: () => defaultWh);
                  final warehouseName = selectedWh?.name;

                  return SearchableSelectorField(
                    hint: 'Sélectionner un entrepôt',
                    selectedText: warehouseName,
                    onTap: () async {
                      final res = await showWarehouseSelectDialog(context, warehouses, selectedWarehouseId: _selectedWarehouseId ?? defaultWh?.id);
                      if (res != null && mounted) {
                        setState(() => _selectedWarehouseId = res);
                      }
                    },
                  );
                },
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

  Widget _buildSearchableField({
    required String hint,
    required String? selectedText,
    required VoidCallback onTap,
    bool hasError = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: selectedText ?? hint),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: Icon(Icons.arrow_drop_down_rounded, size: 24, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: hasError ? AppColors.error : AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: hasError ? AppColors.error : AppColors.border),
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<Customer?> _showCustomerSelectDialog(BuildContext context, List<Customer> initialCustomers) async {
    try {
      context.read<CustomersBloc>().add(LoadCustomers());
    } catch (_) {}

    return showDialog<Customer?>(
      context: context,
      builder: (context) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BlocBuilder<CustomersBloc, CustomersState>(
              builder: (context, state) {
                final customers = state is CustomersLoaded ? state.customers : initialCustomers;
                final query = search.trim().toLowerCase();
                final filtered = customers.where((c) {
                  if (query.isEmpty) return true;
                  final nameMatch = c.name.toLowerCase().contains(query);
                  final companyMatch = c.companyName?.toLowerCase().contains(query) ?? false;
                  final respMatch = c.responsibleName?.toLowerCase().contains(query) ?? false;
                  final codeMatch = c.code.toLowerCase().contains(query);
                  final phoneMatch = c.phone?.toLowerCase().contains(query) ?? false;
                  return nameMatch || companyMatch || respMatch || codeMatch || phoneMatch;
                }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 440,
                constraints: const BoxConstraints(maxHeight: 520),
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sélectionner un client',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        autofocus: true,
                        onChanged: (val) => setDialogState(() => search = val),
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un client...',
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Divider(height: 1, color: AppColors.border),
                    SizedBox(height: 4),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  'Aucun client trouvé',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final customer = filtered[index];
                                final isSelected = customer.id == _selectedCustomerId;
                                final displayName = customer.companyName?.isNotEmpty == true
                                    ? customer.companyName!
                                    : (customer.responsibleName?.isNotEmpty == true
                                        ? customer.responsibleName!
                                        : customer.name);

                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  selected: isSelected,
                                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                  title: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: (customer.code.isNotEmpty || (customer.phone?.isNotEmpty ?? false))
                                      ? Text(
                                          [
                                            if (customer.code.isNotEmpty) customer.code,
                                            if (customer.phone?.isNotEmpty ?? false) customer.phone!,
                                          ].join(' • '),
                                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                      : null,
                                  onTap: () {
                                    Navigator.of(context).pop(customer);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  },
);
}

  Future<String?> _showProjectSelectDialog(BuildContext context, List<Project> projects) async {
    return showDialog<String?>(
      context: context,
      builder: (context) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = search.trim().toLowerCase();
            final filtered = projects.where((p) {
              if (query.isEmpty) return true;
              final nameMatch = p.name.toLowerCase().contains(query);
              final descMatch = p.description?.toLowerCase().contains(query) ?? false;
              final custMatch = p.customerName?.toLowerCase().contains(query) ?? false;
              return nameMatch || descMatch || custMatch;
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 440,
                constraints: BoxConstraints(maxHeight: 520),
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sélectionner un projet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        autofocus: true,
                        onChanged: (val) => setDialogState(() => search = val),
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un projet...',
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Divider(height: 1, color: AppColors.border),
                    SizedBox(height: 4),
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      selected: _selectedProjectId == null,
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                      title: Text(
                        'Projet par defaut',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedProjectId == null ? FontWeight.bold : FontWeight.w500,
                          color: _selectedProjectId == null ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: _selectedProjectId == null
                          ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop('__default__');
                      },
                    ),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  'Aucun projet trouvé',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final project = filtered[index];
                                final isSelected = project.id == _selectedProjectId;

                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  selected: isSelected,
                                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                  title: Text(
                                    project.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: project.customerName != null
                                      ? Text(
                                          'Client: ${project.customerName}',
                                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                      : null,
                                  onTap: () {
                                    Navigator.of(context).pop(project.id);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  Widget _buildItemRow(int index, QuoteItem item) {
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
                          final currentDescription = (item.description != null && item.description!.isNotEmpty)
                              ? item.description!
                              : (item.productName != null && item.productName!.isNotEmpty ? item.productName! : null);
                          return SearchableSelectorField(
                            hint: 'Rechercher un article...',
                            selectedText: currentDescription,
                            onTap: () async {
                              final res = await showProductSelectDialog(context, products, warehouseId: _selectedWarehouseId);
                              if (res != null && mounted) {
                                final selection = products.firstWhere((p) => p.id == res);
                                setState(() {
                                  _items[index] = QuoteItem(
                                    id: item.id,
                                    quoteId: item.quoteId,
                                    productId: selection.id,
                                    productName: selection.name,
                                    description: selection.description ?? selection.name,
                                    unitPrice: selection.sellingPrice,
                                    tvaRate: selection.tvaRate,
                                    quantity: item.quantity,
                                    discountPercent: item.discountPercent,
                                  );
                                });
                              }
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
                        onChanged: (v) => setState(() => _items[index] = QuoteItem(
                          id: item.id, quoteId: item.quoteId, productId: item.productId,
                          productName: item.productName, description: item.description,
                          quantity: double.tryParse(v) ?? 1, unitPrice: item.unitPrice,
                          tvaRate: item.tvaRate, discountPercent: item.discountPercent,
                        )),
                      ),
                    ),
                    SizedBox(width: 4),
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
                        onChanged: (v) => setState(() => _items[index] = QuoteItem(
                          id: item.id, quoteId: item.quoteId, productId: item.productId,
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
                        onChanged: (v) => setState(() => _items[index] = QuoteItem(
                          id: item.id, quoteId: item.quoteId, productId: item.productId,
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
                  final res = await showProductSelectDialog(context, products, warehouseId: _selectedWarehouseId);
                  if (res != null) {
                    final product = products.firstWhere((p) => p.id == res);
                    setState(() {
                      _items.add(QuoteItem(
                        id: _uuid.v4(),
                        quoteId: widget.existing?.id ?? '',
                        productId: product.id,
                        productName: product.name,
                        description: product.description ?? product.name,
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
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 24),
          tooltip: 'Créer un nouvel article',
          onPressed: () async {
            final newProd = await Navigator.push<dynamic>(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ProductsBloc>(),
                  child: const CreateArticleScreen(),
                ),
              ),
            );
            if (newProd != null && newProd is Product && mounted) {
              setState(() {
                _items.add(QuoteItem(
                  id: _uuid.v4(),
                  quoteId: widget.existing?.id ?? '',
                  productId: newProd.id,
                  productName: newProd.name,
                  description: newProd.description ?? newProd.name,
                  quantity: 1,
                  unitPrice: newProd.sellingPrice,
                  tvaRate: newProd.tvaRate,
                  discountPercent: 0,
                ));
              });
            }
          },
          splashRadius: 24,
        ),
        SizedBox(width: 8),
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
