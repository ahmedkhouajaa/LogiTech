import 'dart:async';
import 'create_article_screen.dart';
import 'package:flutter/material.dart';
import '../widgets/searchable_dropdown_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/return_notes/return_notes_bloc.dart';
import '../blocs/return_notes/return_notes_event.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/return_note.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../models/custom_tax_rate.dart';
import '../services/custom_tax_service.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../blocs/warehouses/warehouses_event.dart';
import '../models/stock_movement.dart' show Warehouse;
import '../screens/customers_screen.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../l10n/app_localizations.dart';
import '../database/database_helper.dart';
import '../services/document_numbering_service.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/custom_fields_form_section.dart';
import '../widgets/document_tax_settings_dialog.dart';
import '../services/trial_service.dart';

class CreateReturnNoteScreen extends StatefulWidget {
  final ReturnNote? existing;
  const CreateReturnNoteScreen({super.key, this.existing});

  @override
  State<CreateReturnNoteScreen> createState() =>
      _CreateReturnNoteScreenState();
}

class _CreateReturnNoteScreenState
    extends State<CreateReturnNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _isSaving = false;
  bool _hasAttemptedSubmit = false;

  String? _selectedCustomerId;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
  List<ReturnNoteItem> _items = [];
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withFodec = false;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  Map<String, bool> _activeCustomTaxes = {};
  List<CustomTaxRate> _availableCustomTaxes = [];
  StreamSubscription<List<CustomTaxRate>>? _customTaxesSub;
  ReturnNoteStatus _status = ReturnNoteStatus.draft;

  // Custom fields
  final _vehicleCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  Map<String, dynamic> _customFields = {};

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.totalHT);

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      map[rate] = (map[rate] ?? 0) + (item.totalHT * item.tvaRate / 100);
    }
    return map;
  }

  double get _totalTva => _items.fold(0, (s, i) => s + (i.totalHT * i.tvaRate / 100));

  double get _globalDiscountAmount {
    if (!_withGlobalDiscount || _globalDiscountPercent <= 0) return 0;
    return _totalHT * _globalDiscountPercent / 100;
  }

  double get _totalHTAfterDiscount => _totalHT - _globalDiscountAmount;
  double get _totalTvaAfterDiscount {
    if (!_withGlobalDiscount || _globalDiscountPercent <= 0) return _totalTva;
    return _items.fold(0, (s, i) {
      final itemHT = i.totalHT;
      final discountedHT = itemHT - (itemHT * _globalDiscountPercent / 100);
      return s + discountedHT * (i.tvaRate / 100);
    });
  }

  double get _timbreFiscal => _withTimbreFiscal ? 1.0 : 0;
  double get _fodecAmount => _withFodec ? (_totalHTAfterDiscount * 0.01) : 0.0;

  Map<CustomTaxRate, double> get _customTaxesBreakdown {
    final map = <CustomTaxRate, double>{};
    for (final tax in _availableCustomTaxes) {
      if (_activeCustomTaxes[tax.id] == true) {
        final amount = tax.isPercentage
            ? (_totalHTAfterDiscount * (tax.value / 100))
            : tax.value;
        map[tax] = amount;
      }
    }
    return map;
  }

  double get _customTaxesTotal {
    double sum = 0;
    for (final amount in _customTaxesBreakdown.values) {
      sum += amount;
    }
    return sum;
  }

  double get _totalTTC =>
      _totalHTAfterDiscount + _totalTvaAfterDiscount + _fodecAmount + _customTaxesTotal + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  void _openSettingsDialog() {
    DocumentTaxSettingsDialog.show(
      context: context,
      withFodec: _withFodec,
      withTimbreFiscal: _withTimbreFiscal,
      onFodecChanged: (val) => setState(() => _withFodec = val),
      onTimbreFiscalChanged: (val) => setState(() => _withTimbreFiscal = val),
      activeCustomTaxes: _activeCustomTaxes,
      onCustomTaxesChanged: (taxes) => setState(() => _activeCustomTaxes = Map.from(taxes)),
      documentType: 'sale',
    );
  }

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<ProjectsBloc>().add(LoadProjects());
    context.read<WarehousesBloc>().add(LoadWarehouses());

    _availableCustomTaxes = CustomTaxService.instance.cachedTaxes;
    _customTaxesSub = CustomTaxService.instance.taxesStream.listen((taxes) {
      if (mounted) setState(() => _availableCustomTaxes = taxes);
    });

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.dateEmission;
      _selectedCustomerId = n.customerId;
      _pricingModeHT = n.customFields?['pricingMode'] != 'ttc';
      _globalDiscountPercent = (n.customFields?['globalDiscountPercent'] as num?)?.toDouble() ?? 0.0;
      _withGlobalDiscount = _globalDiscountPercent > 0 || n.customFields?['withGlobalDiscount'] == true;
      _withTimbreFiscal = n.customFields?['withTimbreFiscal'] != false;
      _withFodec = n.customFields?['withFodec'] == true || n.customFields?['with_fodec'] == true;
      if (n.customFields?['activeCustomTaxes'] is Map) {
        _activeCustomTaxes = Map<String, bool>.from(
          (n.customFields!['activeCustomTaxes'] as Map).map((k, v) => MapEntry(k.toString(), v == true)),
        );
      }
      _status = ReturnNoteStatus.values.firstWhere(
        (e) => e.name == n.status,
        orElse: () => ReturnNoteStatus.draft,
      );
      _notesCtrl.text = n.notes ?? '';
      _conditionsCtrl.text = n.conditions ?? '';
      _customFields = n.customFields != null ? Map<String, dynamic>.from(n.customFields!) : {};
      _items = n.items.map((i) => ReturnNoteItem(
        id: i.id,
        returnNoteId: i.returnNoteId,
        productId: i.productId,
        designation: i.designation,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        totalHT: i.totalHT,
      )).toList();
    }
  }

  @override
  void dispose() {
    _customTaxesSub?.cancel();
    _notesCtrl.dispose();
    _conditionsCtrl.dispose();
    _vehicleCtrl.dispose();
    _driverCtrl.dispose();
    super.dispose();
  }

  // a”€a”€ Save a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€
  Future<void> _save() async {
    if (_isSaving) return;
    if (widget.existing == null && !TrialService.instance.checkCanCreate(context)) {
      return;
    }
    setState(() {
      _hasAttemptedSubmit = true;
      _isSaving = true;
    });
    _formKey.currentState?.validate();

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Veuillez ajouter au moins un article')),
            backgroundColor: AppColors.error),
      );
      setState(() => _isSaving = false);
      return;
    }

    final hasEmptyArticle = _items.any((item) =>
        (item.designation == null || item.designation!.trim().isEmpty));

    if (hasEmptyArticle) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Veuillez sélectionner un article pour chaque ligne')),
            backgroundColor: AppColors.error),
      );
      return;
    }

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Veuillez selectionner un client')),
            backgroundColor: AppColors.error),
      );
      setState(() => _isSaving = false);
      return;
    }

    final bloc = context.read<ReturnNotesBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String number = widget.existing?.returnNumber ?? '';
    if (number.isEmpty) {
      final seq = await DocumentNumberingService.ensureNumberSequence(
        context: context,
        docCollection: 'return_notes',
        docTypeName: 'Bon de Retour',
        prefix: 'BR',
      );
      if (seq == null) {
        setState(() => _isSaving = false);
        return;
      }
      number = generateDocNumber('BR', seq, docCollection: 'return_notes');
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

    final noteId = widget.existing?.id ?? _uuid.v4();
    final note = ReturnNote(
      id: noteId,
      returnNumber: number,
      customerId: _selectedCustomerId!,
      customerName: custName,
      dateEmission: _date,
      status: _status.name,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      conditions:
          _conditionsCtrl.text.isNotEmpty ? _conditionsCtrl.text : null,
      customFields: {
        ..._customFields,
        'pricingMode': _pricingModeHT ? 'ht' : 'ttc',
        'withGlobalDiscount': _withGlobalDiscount,
        'globalDiscountPercent': _globalDiscountPercent,
        'withFodec': _withFodec,
        'fodecAmount': _fodecAmount,
        'fodecRate': 1.0,
        'withTimbreFiscal': _withTimbreFiscal,
        'activeCustomTaxes': _activeCustomTaxes,
        'customTaxesTotal': _customTaxesTotal,
      },
      items: _items.map((item) => ReturnNoteItem(
        id: item.id,
        returnNoteId: noteId,
        productId: item.productId,
        designation: item.designation,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        totalHT: item.totalHT,
      )).toList(),
    );

    if (_isEditing) {
      bloc.add(UpdateReturnNote(note));
    } else {
      bloc.add(AddReturnNote(note));
    }

    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing
          ? 'Bon ${note.returnNumber} mis Ã  jour'
          : 'Bon ${note.returnNumber} cree avec succes'),
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
                    // a”€a”€ Form Card (Date, Client, Project, Custom fields, Mode) a”€a”€
                    _buildFormCard(),
                    SizedBox(height: AppSpacing.lg),
                    CustomFieldsFormSection(
                      documentType: 'return_voucher',
                      initialValues: _customFields,
                      onChanged: (vals) => _customFields = vals,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    // a”€a”€ Articles a”€a”€
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

  // a”€a”€ Top Bar a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€
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
            _isEditing ? context.tr('Modifier le Bon de retour') : context.tr('Ajouter un Bon de retour'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          SizedBox(width: 12),
          StatusBadge(label: context.tr(_status.label), color: _status.color),
          const Spacer(),
          _buildHeaderButton(
              Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.description_rounded, 'Brouillon', () {
            setState(() => _status = ReturnNoteStatus.draft);
          }),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.visibility_rounded, 'Apercu', () {}),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.settings_rounded, 'Paramètres', _openSettingsDialog),
          SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(Icons.check_rounded, size: 16),
              label: Text(context.tr('Valider'),
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
        label: Text(context.tr(label),
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  // a”€a”€ Form Card a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€
  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Text(context.tr("Date d'emission"),
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
                locale: Localizations.localeOf(context),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: AbsorbPointer(
              child: TextFormField(
                controller:
                    TextEditingController(text: formatDateLong(_date, Localizations.localeOf(context).languageCode)),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Client & Projet
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Client'),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    BlocBuilder<CustomersBloc, CustomersState>(
                      builder: (context, state) {
                        final customers = state is CustomersLoaded
                            ? state.customers
                            : <Customer>[];
                        final selectedCustomer = customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null);

                        final displayName = selectedCustomer != null
                            ? (selectedCustomer.companyName?.isNotEmpty == true
                                ? selectedCustomer.companyName!
                                : (selectedCustomer.responsibleName?.isNotEmpty == true
                                    ? selectedCustomer.responsibleName!
                                    : selectedCustomer.name))
                            : null;

                        return Row(
                      children: [
                        Expanded(
                          child: FormField<String>(
                            initialValue: _selectedCustomerId,
                            validator: (v) => _selectedCustomerId == null ? context.tr('Requis') : null,
                            builder: (field) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SearchableSelectorField(
                                    hint: context.tr('Rechercher un client...'),
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
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: Tooltip(
                            message: context.tr('Créer un nouveau client'),
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
                                    setState(() => _selectedCustomerId = res.id);
                                  } else if (res is String) {
                                    setState(() => _selectedCustomerId = res);
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
                    );
                  },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Projet'),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        final projects = state is ProjectsLoaded
                            ? state.projects
                            : <Project>[];
                        final defaultProj = projects.cast<Project?>().firstWhere(
                          (p) => p?.isDefault == true,
                          orElse: () => projects.cast<Project?>().firstWhere(
                            (p) => p?.name.toLowerCase().contains('défaut') == true || p?.name.toLowerCase().contains('defaut') == true,
                            orElse: () => projects.isNotEmpty ? projects.first : null,
                          ),
                        );
                        if (_selectedProjectId == null && defaultProj != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _selectedProjectId == null) {
                              setState(() => _selectedProjectId = defaultProj.id);
                            }
                          });
                        }
                        final selectedProject = projects.cast<Project?>().firstWhere(
                          (p) => p?.id == (_selectedProjectId ?? defaultProj?.id),
                          orElse: () => defaultProj,
                        );

                        return SearchableSelectorField(
                          hint: context.tr('Sélectionner un projet'),
                          selectedText: selectedProject?.name ?? 'Projet par défaut',
                          onTap: () async {
                            final res = await showProjectSelectDialog(
                              context,
                              projects,
                              selectedProjectId: _selectedProjectId ?? defaultProj?.id,
                            );
                            if (res != null && mounted) {
                              setState(() => _selectedProjectId = res);
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
              Text(context.tr('Entrepôt'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                    hint: context.tr('Sélectionner un entrepôt'),
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

          // Champs Personnalises
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Champs Personnalisés'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                SizedBox(height: 4),
                Text(
                    context.tr('Informations supplémentaires spécifiques à ce document'),
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Matricule du véhicule'),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                          SizedBox(height: 4),
                          TextFormField(
                            controller: _vehicleCtrl,
                            decoration:
                                _formInputDecoration(hint: 'Entrer la valeur'),
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Nom du chauffeur'),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                          SizedBox(height: 4),
                          TextFormField(
                            controller: _driverCtrl,
                            decoration:
                                _formInputDecoration(hint: 'Entrer la valeur'),
                            style: TextStyle(fontSize: 13),
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

          // Pricing mode
          Text(context.tr('Les prix des articles sont en'),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              Text(context.tr('Hors taxes'), style: TextStyle(fontSize: 13)),
              SizedBox(width: 24),
              Radio<bool>(
                value: false,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              Text(context.tr('Taxe incluse'), style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _formInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint != null ? context.tr(hint) : null,
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

  // a”€a”€ Articles Section a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€
  Widget _buildArticlesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(context.tr('Articles'),
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
                    child: Text(context.tr('Designation'),
                        style: _tableHeaderStyle())),
                SizedBox(
                    width: 120,
                    child: Text(context.tr('Quantite'),
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 130,
                    child: Text('P.U',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 100,
                    child: Text(context.tr('TVA'),
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 140,
                    child: Text(context.tr('Total HT'),
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
              child: Text(context.tr('Aucun article'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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

  Widget _buildItemRow(int index, ReturnNoteItem item) {
    final isArticleMissing = _hasAttemptedSubmit &&
        (item.designation == null || item.designation!.trim().isEmpty);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Designation
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.designation ?? '',
                  decoration: _itemInputDecoration(
                    'Rechercher un article...',
                    hasError: isArticleMissing,
                    errorText: isArticleMissing ? context.tr('Veuillez sélectionner un article') : null,
                  ),
                  style: TextStyle(fontSize: 13),
                  onChanged: (v) => setState(() =>
                      _items[index] = item.copyWith(designation: v)),
                ),
              ),
              SizedBox(width: 8),
              // Quantite with + button
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _items[index] =
                          item.copyWith(quantity: item.quantity < -1 ? item.quantity + 1 : item.quantity)),
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
                        onChanged: (v) => setState(() =>
                            _items[index] = item.copyWith(
                                quantity: (() {
                                  final rawQty = double.tryParse(v) ?? -1;
                                  return rawQty > 0 ? -rawQty : rawQty;
                                })())),
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
                        onChanged: (v) => setState(() =>
                            _items[index] = item.copyWith(
                                unitPrice:
                                    double.tryParse(v) ?? 0)),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      _pricingModeHT ? 'DT HT' : 'DT TTC',
                      style: TextStyle(
                          fontSize: 10,
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
                  items: TvaRates.all
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('${r.toInt()}%',
                              style:
                                  TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() =>
                      _items[index] = item.copyWith(tvaRate: v)),
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
                      text: formatCurrencyDT(item.totalHT)),
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
                tooltip: context.tr('Supprimer'),
              ),
              Icon(Icons.drag_indicator_rounded,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _itemInputDecoration(String hint, {bool hasError = false, String? errorText}) {
    final borderSide = hasError
        ? BorderSide(color: AppColors.error, width: 1.5)
        : BorderSide(color: AppColors.border);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: hasError ? AppColors.error : AppColors.textTertiary, fontSize: 12),
      filled: true,
      fillColor: hasError ? AppColors.error.withValues(alpha: 0.04) : AppColors.surfaceAlt,
      contentPadding:
          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      errorText: hasError ? errorText : null,
      errorStyle: TextStyle(fontSize: 11, color: AppColors.error),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: borderSide),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: borderSide),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: hasError ? AppColors.error : AppColors.primary, width: 1.5)),
    );
  }

  // a”€a”€ Article Actions a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€
    Widget _buildArticleActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 380,
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              final allProducts = state is ProductsLoaded ? state.products : <Product>[];
              final products = allProducts.where((p) => p.isForSale).toList();
              return SearchableSelectorField(
                hint: context.tr('Sélectionner un article...'),
                isHighlighted: true,
                selectedText: null,
                onTap: () async {
                  final res = await showProductSelectDialog(context, products, warehouseId: _selectedWarehouseId, destinationFilter: 'Vente');
                  if (res != null) {
                    final product = products.firstWhere((p) => p.id == res);
                    setState(() {
                      _items.add(ReturnNoteItem(
                        id: _uuid.v4(),
                        returnNoteId: widget.existing?.id ?? '',
                        productId: product.id,
                        designation: product.name,
                        quantity: -1,
                        unitPrice: product.sellingPrice,
                        tvaRate: product.tvaRate,
                        totalHT: -1 * product.sellingPrice,
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
          tooltip: context.tr('Créer un nouvel article'),
          onPressed: () async {
            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateArticleScreen()));
            if (res != null && res is Product && mounted) {
              setState(() {
                _items.add(ReturnNoteItem(
                  id: _uuid.v4(),
                  returnNoteId: widget.existing?.id ?? '',
                  productId: res.id,
                  designation: res.name,
                  quantity: -1,
                  unitPrice: res.sellingPrice,
                  tvaRate: res.tvaRate,
                  totalHT: -1 * res.sellingPrice,
                ));
              });
            }
          },
          splashRadius: 24,
        ),
        SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _items.add(ReturnNoteItem(
                  id: _uuid.v4(),
                  returnNoteId: widget.existing?.id ?? '',
                  productId: 'custom',
                  designation: '',
                  quantity: -1,
                  unitPrice: 0,
                  tvaRate: 19,
                  totalHT: 0,
                ));
              });
            },
            icon: Icon(Icons.add_rounded, size: 16, color: AppColors.textPrimary),
            label: Text(context.tr('Ajouter une Ligne Vide'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.primary, width: 1.5),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ),
      ],
    );
  }

  // a”€a”€ Global Discount Section a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€
  Widget _buildGlobalDiscountSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _withGlobalDiscount = !_withGlobalDiscount),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _withGlobalDiscount,
                    onChanged: (v) => setState(
                        () => _withGlobalDiscount = v ?? false),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                  ),
                ),
                SizedBox(width: 8),
                Text(context.tr('Ajouter une remise globale'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
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
                    initialValue: _globalDiscountPercent > 0
                        ? _globalDiscountPercent.toString()
                        : '',
                    decoration: _itemInputDecoration('Remise %'),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() =>
                        _globalDiscountPercent =
                            double.tryParse(v) ?? 0),
                  ),
                ),
                SizedBox(width: 12),
                Text('= ${formatCurrencyDT(_globalDiscountAmount)}',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Totals Section ──────────────────────────────────────────────
  Widget _buildTotalsSection() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTotalLine('Sous-total HT:',
                formatCurrencyDT(_totalHTAfterDiscount)),
            SizedBox(height: 6),
            ..._tvaBreakdown.entries.map((entry) => Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: _buildTotalLine('TVA ${entry.key.toInt()}%:',
                      formatCurrencyDT(entry.value)),
                )),
            if (_withFodec) ...[
              _buildTotalLine('FODEC (1%):', formatCurrencyDT(_fodecAmount)),
              SizedBox(height: 6),
            ],
            ..._customTaxesBreakdown.entries.map((entry) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildTotalLine(
                  '${entry.key.label.isNotEmpty ? entry.key.label : entry.key.name} (${entry.key.isPercentage ? '${entry.key.value.toStringAsFixed(entry.key.value.truncateToDouble() == entry.key.value ? 0 : 2)}%' : '${entry.key.value.toStringAsFixed(2)} DT'}):',
                  formatCurrencyDT(entry.value),
                ),
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
                            side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(context.tr('Timbre fiscal:'), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    Text(formatCurrencyDT(_timbreFiscal), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6),
            if (_withGlobalDiscount && _globalDiscountAmount > 0) ...[
              _buildTotalLine('Remise:',
                  '- ${formatCurrencyDT(_globalDiscountAmount)}'),
              SizedBox(height: 6),
            ],
            Divider(),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('Total TTC:'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(formatCurrencyDT(_totalTTC),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
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
        Text(label,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }

  // a”€a”€ Notes Section a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€a”€
  Widget _buildNotesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Notes'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: context.tr('Visible sur le document final'),
                  hintStyle: TextStyle(
                      color: AppColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 1.5)),
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
              Text(context.tr('Conditions Generales'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: context.tr('Conditions generales pour ce document'),
                  hintStyle: TextStyle(
                      color: AppColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 1.5)),
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