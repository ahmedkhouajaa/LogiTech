import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/delivery_note.dart';
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

class MobileDeliveryNoteFormScreen extends StatefulWidget {
  final DeliveryNote? existing;
  const MobileDeliveryNoteFormScreen({super.key, this.existing});

  @override
  State<MobileDeliveryNoteFormScreen> createState() => _MobileDeliveryNoteFormScreenState();
}

class _MobileDeliveryNoteFormScreenState extends State<MobileDeliveryNoteFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedCustomerId;
  String? _selectedProjectId;
  List<DeliveryNoteItem> _items = [];
  DateTime _date = DateTime.now();
  String _notes = '';
  String _conditions = '';
  String _vehicleRegistration = '';
  String _driverName = '';
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  DeliveryNoteStatus _status = DeliveryNoteStatus.draft;

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.totalHT);

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      map[rate] = (map[rate] ?? 0) + item.tvaAmount;
    }
    return map;
  }

  double get _totalTva => _items.fold(0, (s, i) => s + i.tvaAmount);

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
  double get _totalTTC => _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<ProjectsBloc>().add(LoadProjects());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _selectedCustomerId = n.customerId;
      _selectedProjectId = n.projectId;
      _pricingModeHT = n.pricingMode == 'ht';
      _withGlobalDiscount = n.globalDiscountPercent > 0;
      _globalDiscountPercent = n.globalDiscountPercent;
      _withTimbreFiscal = n.timbreFiscal > 0;
      _status = DeliveryNoteStatus.values.firstWhere(
        (e) => e.name == n.status,
        orElse: () => DeliveryNoteStatus.draft,
      );
      _notes = n.notes ?? '';
      _conditions = n.conditionsGenerales ?? '';
      _vehicleRegistration = n.vehicleRegistration ?? '';
      _driverName = n.driverName ?? '';
      _items = n.items.map((i) => DeliveryNoteItem(
        id: i.id,
        deliveryNoteId: i.deliveryNoteId,
        productId: i.productId,
        description: i.description,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        showDescription: i.showDescription,
        showDiscount: i.showDiscount,
      )).toList();
    }
  }

  Future<void> _save() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<DeliveryNotesBloc>();
      
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextDeliveryNoteSequence();
        number = generateDocNumber('BL', seq);
      }

      final noteId = widget.existing?.id ?? _uuid.v4();
      final note = DeliveryNote(
        id: noteId,
        number: number,
        customerId: _selectedCustomerId!,
        projectId: _selectedProjectId,
        date: _date,
        status: _status.name,
        pricingMode: _pricingModeHT ? 'ht' : 'ttc',
        globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
        timbreFiscal: _timbreFiscal,
        vehicleRegistration: _vehicleRegistration.isNotEmpty ? _vehicleRegistration : null,
        driverName: _driverName.isNotEmpty ? _driverName : null,
        notes: _notes.isNotEmpty ? _notes : null,
        conditionsGenerales: _conditions.isNotEmpty ? _conditions : null,
        items: _items.map((item) => DeliveryNoteItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          deliveryNoteId: noteId,
          productId: item.productId,
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          discountPercent: item.discountPercent,
          showDescription: item.showDescription,
          showDiscount: item.showDiscount,
        )).toList(),
        isDeleted: widget.existing?.isDeleted ?? false,
      );

      if (_isEditing) {
        bloc.add(UpdateDeliveryNote(note));
      } else {
        bloc.add(AddDeliveryNote(note));
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

  void _showArticleForm([int? index]) async {
    MobileArticleFormResult? initialData;
    if (index != null) {
      final item = _items[index];
      initialData = MobileArticleFormResult(
        productId: item.productId ?? '',
        productName: '',
        description: item.description ?? '',
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: false);

    if (result != null) {
      setState(() {
        final newItem = DeliveryNoteItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          deliveryNoteId: widget.existing?.id ?? '',
          productId: result.productId,
          description: result.description,
          quantity: result.quantity,
          unitPrice: result.unitPrice,
          tvaRate: result.tvaRate,
          discountPercent: result.discountPercent,
          showDescription: result.description.isNotEmpty,
          showDiscount: result.discountPercent > 0,
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
      title: _isEditing ? 'Modifier le BL' : 'Nouveau BL',
      statusLabel: _status.label,
      statusColor: _status.color,
      isLoading: _isLoading,
      saveLabel: 'Valider',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
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
                  onChanged: (v) => setState(() => _date = v),
                ),
                const SizedBox(height: 16),
                BlocBuilder<CustomersBloc, CustomersState>(
                  builder: (context, state) {
                    final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                    return SmartDropdown<String>(
                      label: 'Client',
                      value: _selectedCustomerId,
                      items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.companyName ?? c.name, style: const TextStyle(fontSize: 16)))).toList(),
                      onChanged: (v) => setState(() => _selectedCustomerId = v),
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
                      onChanged: (v) => setState(() => _selectedProjectId = v),
                      hint: 'Projet par défaut',
                    );
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Champs Personnalisés', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Informations supplémentaires', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Matricule du véhicule',
                        initialValue: _vehicleRegistration,
                        onChanged: (v) => setState(() => _vehicleRegistration = v),
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Nom du chauffeur',
                        initialValue: _driverName,
                        onChanged: (v) => setState(() => _driverName = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SmartToggleChips<bool>(
                  label: 'Les prix des articles sont en:',
                  value: _pricingModeHT,
                  options: const [true, false],
                  labelBuilder: (v) => v ? 'Hors taxes' : 'Taxe incluse',
                  onChanged: (v) => setState(() => _pricingModeHT = v),
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
                    designation: e.value.description ?? 'Article',
                    quantity: e.value.quantity,
                    unitPrice: e.value.unitPrice,
                    tvaRate: e.value.tvaRate,
                    discountPercent: e.value.discountPercent,
                    totalHT: e.value.totalHT,
                    onEdit: () => _showArticleForm(e.key),
                    onDelete: () => setState(() => _items.removeAt(e.key)),
                  )),
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
            timbreFiscal: 1.0,
            applyTimbreFiscal: _withTimbreFiscal,
            onTimbreFiscalChanged: (v) => setState(() => _withTimbreFiscal = v ?? false),
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
                SmartCheckbox(
                  label: 'Visible sur le document final',
                  value: true,
                  onChanged: (v) {},
                ),
                const SizedBox(height: 8),
                SmartTextInput(
                  label: 'Notes',
                  initialValue: _notes,
                  maxLines: 3,
                  onChanged: (v) => setState(() => _notes = v),
                ),
                const SizedBox(height: 16),
                SmartTextInput(
                  label: 'Conditions Générales',
                  initialValue: _conditions,
                  maxLines: 3,
                  onChanged: (v) => setState(() => _conditions = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
