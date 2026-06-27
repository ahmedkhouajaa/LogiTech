import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/return_notes/return_notes_bloc.dart';
import '../../../../blocs/return_notes/return_notes_event.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/return_note.dart';
import '../../../../models/customer.dart';
import '../../../../models/project.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../../../database/database_helper.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';
import '../../widgets/forms/mobile_article_card.dart';
import '../../widgets/forms/mobile_article_form.dart';
import '../../widgets/forms/mobile_totals_card.dart';

class MobileReturnVoucherFormScreen extends StatefulWidget {
  final ReturnNote? existing;
  final bool isReadOnly;
  const MobileReturnVoucherFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileReturnVoucherFormScreen> createState() => _MobileReturnVoucherFormScreenState();
}

class _MobileReturnVoucherFormScreenState extends State<MobileReturnVoucherFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedCustomerId;
  String? _selectedProjectId;
  List<ReturnNoteItem> _items = [];
  DateTime _date = DateTime.now();
  String _notes = '';
  String _conditions = '';
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  String _status = 'draft';

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

  double get _timbreFiscal => _withTimbreFiscal ? 1.000 : 0;
  double get _totalTTC => _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<ProjectsBloc>().add(LoadProjects());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.dateEmission;
      _selectedCustomerId = n.customerId;
      _status = n.status;
      _notes = n.notes ?? '';
      _conditions = n.conditions ?? '';
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

  Future<void> _save() async {
    if (widget.isReadOnly) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<ReturnNotesBloc>();
      
      String number = widget.existing?.returnNumber ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextReturnNoteSequence();
        number = generateDocNumber('BR', seq);
      }

      final noteId = widget.existing?.id ?? _uuid.v4();
      final note = ReturnNote(
        id: noteId,
        returnNumber: number,
        customerId: _selectedCustomerId!,
        dateEmission: _date,
        status: _status,
        notes: _notes.isNotEmpty ? _notes : null,
        conditions: _conditions.isNotEmpty ? _conditions : null,
        items: _items.map((item) => ReturnNoteItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Bon de retour mis à jour' : 'Bon de retour créé avec succès'),
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

  void _showArticleForm([int? index]) async {
    if (widget.isReadOnly) return;
    
    MobileArticleFormResult? initialData;
    if (index != null) {
      final item = _items[index];
      initialData = MobileArticleFormResult(
        productId: item.productId ?? '',
        productName: item.designation,
        description: item.designation,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: 0, 
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: false);

    if (result != null) {
      setState(() {
        final newItem = ReturnNoteItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          returnNoteId: widget.existing?.id ?? '',
          productId: result.productId,
          designation: result.description.isNotEmpty ? result.description : result.productName,
          quantity: result.quantity,
          unitPrice: result.unitPrice,
          tvaRate: result.tvaRate,
          totalHT: result.quantity * result.unitPrice,
        );

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
      title: widget.isReadOnly ? 'Détails du bon de retour' : (_isEditing ? 'Modifier le bon' : 'Nouveau bon de retour'),
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
                  label: 'Date d\'émission',
                  value: _date,
                  onChanged: (v) { if (!widget.isReadOnly) setState(() => _date = v); },
                ),
                const SizedBox(height: 16),
                BlocBuilder<CustomersBloc, CustomersState>(
                  builder: (context, state) {
                    final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                    return SmartDropdown<String>(
                      label: 'Client',
                      value: _selectedCustomerId,
                      items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 16)))).toList(),
                      onChanged: (v) { if (!widget.isReadOnly) setState(() => _selectedCustomerId = v); },
                      hint: 'Rechercher des clients...',
                    );
                  },
                ),
                const SizedBox(height: 16),
                BlocBuilder<ProjectsBloc, ProjectsState>(
                  builder: (context, state) {
                    final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                    return SmartDropdown<String>(
                      label: 'Projet',
                      value: _selectedProjectId,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Projet par défaut', style: TextStyle(fontSize: 16))),
                        ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 16)))),
                      ],
                      onChanged: (v) { if (!widget.isReadOnly) setState(() => _selectedProjectId = v); },
                      hint: 'Projet par défaut',
                    );
                  },
                ),
                const SizedBox(height: 24),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartToggleChips<bool>(
                    label: 'Les prix des articles sont en:',
                    value: _pricingModeHT,
                    options: const [true, false],
                    labelBuilder: (v) => v ? 'Hors taxes' : 'Taxe incluse',
                    onChanged: (v) => setState(() => _pricingModeHT = v),
                  ),
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
                  ..._items.asMap().entries.map((e) => MobileArticleCard(
                    index: e.key,
                    designation: e.value.designation ?? 'Article',
                    quantity: e.value.quantity,
                    unitPrice: e.value.unitPrice,
                    tvaRate: e.value.tvaRate,
                    discountPercent: 0,
                    totalHT: e.value.totalHT,
                    onEdit: () { if (!widget.isReadOnly) _showArticleForm(e.key); },
                    onDelete: () { if (!widget.isReadOnly) setState(() => _items.removeAt(e.key)); },
                  )),
                if (!widget.isReadOnly) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showArticleForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter une ligne'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SmartCheckbox(
                    label: 'Ajouter une remise globale',
                    value: _withGlobalDiscount,
                    onChanged: (v) => setState(() => _withGlobalDiscount = v ?? false),
                  ),
                  if (_withGlobalDiscount) ...[
                    const SizedBox(height: 8),
                    SmartTextInput(
                      label: 'Remise globale (%)',
                      initialValue: _globalDiscountPercent > 0 ? _globalDiscountPercent.toStringAsFixed(0) : '',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => setState(() => _globalDiscountPercent = double.tryParse(v) ?? 0),
                    ),
                  ]
                ]
              ],
            ),
          ),
        ),
        
        MobileFormSection(
          title: 'Totaux',
          icon: Icons.calculate_outlined,
          child: MobileTotalsCard(
            subTotalHT: _totalHTAfterDiscount,
            tvaBreakdown: _tvaBreakdown,
            totalTva: _totalTvaAfterDiscount,
            timbreFiscal: 1.000,
            applyTimbreFiscal: _withTimbreFiscal,
            onTimbreFiscalChanged: (v) { if (!widget.isReadOnly) setState(() => _withTimbreFiscal = v ?? false); },
            totalTTC: _totalTTC,
          ),
        ),
        
        MobileFormSection(
          title: 'Notes & Conditions',
          icon: Icons.notes_rounded,
          isInitiallyExpanded: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SmartTextInput(
                  label: 'Raison / Notes',
                  initialValue: _notes,
                  maxLines: 3,
                  onChanged: widget.isReadOnly ? null : (v) => setState(() => _notes = v),
                ),
                const SizedBox(height: 16),
                SmartTextInput(
                  label: 'Conditions Générales',
                  initialValue: _conditions,
                  maxLines: 3,
                  onChanged: widget.isReadOnly ? null : (v) => setState(() => _conditions = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
