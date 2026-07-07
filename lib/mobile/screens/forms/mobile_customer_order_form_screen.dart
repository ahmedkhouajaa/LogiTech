import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/customer_orders/customer_orders_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/customer_order.dart';
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
import 'mobile_product_form_screen.dart';
import '../../widgets/forms/mobile_totals_card.dart';
import 'mobile_product_form_screen.dart';
import '../../../../screens/customers_screen.dart';

class MobileCustomerOrderFormScreen extends StatefulWidget {
  final CustomerOrder? existing;
  const MobileCustomerOrderFormScreen({super.key, this.existing});

  @override
  State<MobileCustomerOrderFormScreen> createState() => _MobileCustomerOrderFormScreenState();
}

class _MobileCustomerOrderFormScreenState extends State<MobileCustomerOrderFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedCustomerId;
  String? _selectedProjectId;
  List<CustomerOrderItem> _items = [];
  DateTime _date = DateTime.now();
  String _notes = '';
  String _conditions = '';
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  CustomerOrderStatus _status = CustomerOrderStatus.draft;

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
      _status = CustomerOrderStatus.values.firstWhere(
        (e) => e.name == n.status,
        orElse: () => CustomerOrderStatus.draft,
      );
      _notes = n.notes ?? '';
      _conditions = n.conditionsGenerales ?? '';
      _items = n.items.map((i) => CustomerOrderItem(
        id: i.id,
        orderId: i.orderId,
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
      final bloc = context.read<CustomerOrdersBloc>();
      
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextCustomerOrderSequence();
        number = generateDocNumber('CC', seq);
      }

      final orderId = widget.existing?.id ?? _uuid.v4();
      final order = CustomerOrder(
        id: orderId,
        number: number,
        customerId: _selectedCustomerId!,
        projectId: _selectedProjectId,
        date: _date,
        status: _status.name,
        pricingMode: _pricingModeHT ? 'ht' : 'ttc',
        globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
        globalDiscountAmount: _globalDiscountAmount,
        timbreFiscal: _timbreFiscal,
        notes: _notes.isNotEmpty ? _notes : null,
        conditionsGenerales: _conditions.isNotEmpty ? _conditions : null,
        items: _items.map((item) => CustomerOrderItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          orderId: orderId,
          productId: item.productId,
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          discountPercent: item.discountPercent,
          showDescription: item.showDescription,
          showDiscount: item.showDiscount,
        )).toList(),
      );

      if (_isEditing) {
        bloc.add(UpdateCustomerOrder(order));
      } else {
        bloc.add(AddCustomerOrder(order));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Commande mise à jour' : 'Commande créée avec succès'),
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
        productId: item.productId,
        productName: item.description ?? '',
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
        final newItem = CustomerOrderItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          orderId: widget.existing?.id ?? '',
          productId: result.productId,
          description: result.description,
          quantity: result.quantity,
          unitPrice: result.unitPrice,
          tvaRate: result.tvaRate,
          discountPercent: result.discountPercent,
          showDescription: result.description != result.productName,
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
      title: _isEditing ? 'Modifier la commande' : 'Nouvelle commande',
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
              children: [
                SmartDatePicker(
                  label: 'Date d\'émission',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: BlocBuilder<CustomersBloc, CustomersState>(
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
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 56,
                      margin: const EdgeInsets.only(bottom: 2),
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
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded),
                      ),
                    ),
                  ],
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
                const SizedBox(height: 16),
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
                    designation: e.value.description ?? '',
                    quantity: e.value.quantity,
                    unitPrice: e.value.unitPrice,
                    tvaRate: e.value.tvaRate,
                    discountPercent: e.value.discountPercent,
                    totalHT: e.value.totalHT,
                    onEdit: () => _showArticleForm(e.key),
                    onDelete: () => setState(() => _items.removeAt(e.key)),
                  )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showArticleForm(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter une ligne'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                      )
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                      tooltip: 'Créer un nouvel article',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileProductFormScreen()));
                      },
                    ),
                  ],
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
