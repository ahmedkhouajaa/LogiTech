import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/supplier_credit_note.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';
import '../widgets/dashboard_card.dart';

enum SupplierCreditNoteStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Validé', AppColors.success),
  canceled('Annulé', AppColors.error);

  final String label;
  final Color color;
  const SupplierCreditNoteStatus(this.label, this.color);
}

class CreateSupplierCreditNoteScreen extends StatefulWidget {
  final SupplierCreditNote? existing;
  const CreateSupplierCreditNoteScreen({super.key, this.existing});

  @override
  State<CreateSupplierCreditNoteScreen> createState() =>
      _CreateSupplierCreditNoteScreenState();
}

class _CreateSupplierCreditNoteScreenState
    extends State<CreateSupplierCreditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  String? _selectedsupplierId;
  String? _selectedProjectId;
  List<SupplierCreditNoteItem> _items = [];
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  SupplierCreditNoteStatus _status = SupplierCreditNoteStatus.draft;

  // Custom fields
  final _vehicleCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();

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
  double get _totalTTC =>
      _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<SuppliersBloc>().add(LoadSuppliers());
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<ProjectsBloc>().add(LoadProjects());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _selectedsupplierId = n.supplierId;
      _status = SupplierCreditNoteStatus.values.firstWhere(
        (e) => e.name == n.status,
        orElse: () => SupplierCreditNoteStatus.draft,
      );
      _notesCtrl.text = n.reason ?? '';
      _conditionsCtrl.text = n.reason ?? '';
      _items = n.items.map((i) => SupplierCreditNoteItem(
        id: i.id,
        supplierCreditNoteId: i.supplierCreditNoteId,
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
    _notesCtrl.dispose();
    _conditionsCtrl.dispose();
    _vehicleCtrl.dispose();
    _driverCtrl.dispose();
    super.dispose();
  }

  // aâ€â‚¬aâ€â‚¬ Save aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬
  Future<void> _save() async {
    if (_selectedsupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez selectionner un Fournisseur'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final bloc = context.read<SupplierCreditNotesBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String number = widget.existing?.number ?? '';
    if (number.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextSupplierCreditNoteSequence();
      number = generateDocNumber('AVF', seq);
    }

    final noteId = widget.existing?.id ?? const Uuid().v4();
    final note = SupplierCreditNote(
      id: noteId,
      number: number,
      supplierId: _selectedsupplierId!,
      date: _date,
      status: _status.name,
      reason: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      items: _items.map((item) => SupplierCreditNoteItem(
        id: item.id,
        supplierCreditNoteId: noteId,
        productId: item.productId,
        designation: item.designation,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        totalHT: item.totalHT,
      )).toList(),
      isDeleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_isEditing) {
      bloc.add(UpdateSupplierCreditNote(note));
    } else {
      bloc.add(AddSupplierCreditNote(note));
    }

    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing
          ? 'Avoir ${note.number} mis à jour'
          : 'Avoir ${note.number} créé avec succès'),
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
            _isEditing ? 'Modifier le Avoir fournisseur' : 'Ajouter un Avoir fournisseur',
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
            setState(() => _status = SupplierCreditNoteStatus.draft);
          }),
          const SizedBox(width: 8),
          _buildHeaderButton(Icons.visibility_rounded, 'Apercu', () {}),
          const SizedBox(width: 8),
          _buildHeaderButton(Icons.settings_rounded, 'Parametres', () {}),
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

  // aâ€â‚¬aâ€â‚¬ Form Card aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬
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
          // Date
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
          const SizedBox(height: 20),

          // Fournisseur & Projet
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fournisseur',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    BlocBuilder<SuppliersBloc, SuppliersState>(
                      builder: (context, state) {
                        final Suppliers = state is SuppliersLoaded
                            ? state.suppliers
                            : <Supplier>[];
                        return DropdownButtonFormField<String>(
                          value: _selectedsupplierId,
                          isExpanded: true,
                          hint: const Text('Rechercher des Fournisseurs...',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary)),
                          items: Suppliers
                              .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                      c.name ?? c.name,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedsupplierId = v),
                          validator: (v) => v == null ? 'Requis' : null,
                          decoration: _formInputDecoration(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Projet',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        final projects = state is ProjectsLoaded
                            ? state.projects
                            : <Project>[];
                        return DropdownButtonFormField<String>(
                          value: _selectedProjectId,
                          isExpanded: true,
                          hint: const Text('Projet par defaut',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary)),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Projet par defaut',
                                    style: TextStyle(fontSize: 13))),
                            ...projects.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name,
                                    style:
                                        const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedProjectId = v),
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

          // Champs Personnalises
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Champs Personnalises',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                    'Informations supplementaires specifiques ÃƒÂ  ce document',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Matricule du vehicule',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _vehicleCtrl,
                            decoration:
                                _formInputDecoration(hint: 'Entrer la valeur'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nom du chauffeur',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _driverCtrl,
                            decoration:
                                _formInputDecoration(hint: 'Entrer la valeur'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pricing mode
          const Text('Les prix des articles sont en',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
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

  // aâ€â‚¬aâ€â‚¬ Articles Section aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬
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
                    width: 120,
                    child: Text('Quantite',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 130,
                    child: Text('P.U',
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

  Widget _buildItemRow(int index, SupplierCreditNoteItem item) {
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
                child: TextFormField(
                  initialValue: item.designation ?? '',
                  decoration: _itemInputDecoration(''),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => setState(() =>
                      _items[index] = item.copyWith(designation: v)),
                ),
              ),
              const SizedBox(width: 8),
              // Quantite with + button
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _items[index] =
                          item.copyWith(quantity: item.quantity + 1)),
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
                        onChanged: (v) => setState(() =>
                            _items[index] = item.copyWith(
                                quantity:
                                    double.tryParse(v) ?? 1)),
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
                        onChanged: (v) => setState(() =>
                            _items[index] = item.copyWith(
                                unitPrice:
                                    double.tryParse(v) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _pricingModeHT ? 'DT HT' : 'DT TTC',
                      style: const TextStyle(
                          fontSize: 10,
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
                  items: TvaRates.all
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('${r.toInt()}%',
                              style:
                                  const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() =>
                      _items[index] = item.copyWith(tvaRate: v)),
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
                      text: formatCurrencyDT(item.totalHT)),
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
      hintStyle: const TextStyle(
          color: AppColors.textTertiary, fontSize: 12),
      filled: true,
      fillColor: AppColors.surface,
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

  // aâ€â‚¬aâ€â‚¬ Article Actions aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬
  Widget _buildArticleActions() {
    return Row(
      children: [
        Expanded(
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              final products =
                  state is ProductsLoaded ? state.products : <Product>[];
              return Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonFormField<String>(
                  hint: const Text('Selectionner un article...',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary)),
                  isExpanded: true,
                  items: products
                      .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name,
                              style:
                                  const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final product =
                        products.firstWhere((p) => p.id == v);
                    setState(() {
                      _items.add(SupplierCreditNoteItem(
                        id: _uuid.v4(),
                        supplierCreditNoteId: widget.existing?.id ?? '',
                        productId: product.id,
                        designation: product.name,
                        quantity: -1,
                        unitPrice: product.sellingPrice,
                        tvaRate: product.tvaRate,
                        totalHT: -1 * product.sellingPrice,
                      ));
                    });
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _items.add(SupplierCreditNoteItem(
                  id: _uuid.v4(),
                  supplierCreditNoteId: widget.existing?.id ?? '',
                  productId: 'custom',
                  designation: '',
                  quantity: -1,
                  unitPrice: 0,
                  tvaRate: 19,
                  totalHT: 0,
                ));
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Ajouter une Ligne Vide',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  // aâ€â‚¬aâ€â‚¬ Global Discount Section aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬
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
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Ajouter une remise globale',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
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
                    initialValue: _globalDiscountPercent > 0
                        ? _globalDiscountPercent.toString()
                        : '',
                    decoration: _itemInputDecoration('Remise %'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() =>
                        _globalDiscountPercent =
                            double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Text('= ${formatCurrencyDT(_globalDiscountAmount)}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // aâ€â‚¬aâ€â‚¬ Totals Section aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬
  Widget _buildTotalsSection() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildTotalLine('Sous-total HT:',
                formatCurrencyDT(_totalHTAfterDiscount)),
            const SizedBox(height: 6),
            ..._tvaBreakdown.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildTotalLine('TVA ${entry.key.toInt()}%:',
                      formatCurrencyDT(entry.value)),
                )),
            if (_withTimbreFiscal) ...[
              _buildTotalLine(
                  'Timbre fiscal:', formatCurrencyDT(_timbreFiscal)),
              const SizedBox(height: 6),
            ],
            if (_withGlobalDiscount && _globalDiscountAmount > 0) ...[
              _buildTotalLine('Remise:',
                  '- ${formatCurrencyDT(_globalDiscountAmount)}'),
              const SizedBox(height: 6),
            ],
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total TTC:',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(formatCurrencyDT(_totalTTC),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            // Timbre fiscal toggle
            InkWell(
              onTap: () =>
                  setState(() => _withTimbreFiscal = !_withTimbreFiscal),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Checkbox(
                      value: _withTimbreFiscal,
                      onChanged: (v) => setState(
                          () => _withTimbreFiscal = v ?? true),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Timbre fiscal (1 DT)',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary)),
                ],
              ),
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
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }

  // aâ€â‚¬aâ€â‚¬ Notes Section aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬aâ€â‚¬
  Widget _buildNotesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notes',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Visible sur le document final',
                  hintStyle: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
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
              const Text('Conditions Generales',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Conditions generales pour ce document',
                  hintStyle: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
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

