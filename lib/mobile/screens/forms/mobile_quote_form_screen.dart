import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/quotes/quotes_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../models/quote.dart';
import '../../../../models/customer.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../../../database/database_helper.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';
import '../../widgets/forms/mobile_article_card.dart';
import '../../widgets/forms/mobile_article_form.dart';
import '../../widgets/forms/mobile_totals_card.dart';
import '../../../../screens/customers_screen.dart';

class MobileQuoteFormScreen extends StatefulWidget {
  final Quote? existing;
  const MobileQuoteFormScreen({super.key, this.existing});

  @override
  State<MobileQuoteFormScreen> createState() => _MobileQuoteFormScreenState();
}

class _MobileQuoteFormScreenState extends State<MobileQuoteFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String? _selectedCustomerId;
  List<QuoteItem> _items = [];
  DateTime _date = DateTime.now();
  DateTime _validityDate = DateTime.now().add(const Duration(days: 30));
  String _notes = '';
  DocumentStatus _status = DocumentStatus.draft;
  bool _withTimbreFiscal = true;

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.computedTotalHT);

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      final tvaAmount = item.computedTotalHT * (rate / 100);
      map[rate] = (map[rate] ?? 0) + tvaAmount;
    }
    return map;
  }

  double get _totalTva {
    double total = 0;
    _tvaBreakdown.forEach((rate, amount) => total += amount);
    return total;
  }

  double get _timbreFiscal => _withTimbreFiscal ? 1.0 : 0.0;

  double get _totalTTC => _totalHT + _totalTva + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _validityDate = n.validityDate;
      _selectedCustomerId = n.customerId;
      _status = n.status;
      _notes = n.notes ?? '';
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

  Future<void> _save() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<QuotesBloc>();
      
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
        date: _date,
        validityDate: _validityDate,
        status: _status,
        totalHT: _totalHT,
        totalTva: _totalTva,
        totalTTC: _totalTTC,
        notes: _notes.isNotEmpty ? _notes : null,
        items: _items.map((item) => QuoteItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Devis mis à jour' : 'Devis créé avec succès'),
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
        productName: item.productName ?? '',
        description: item.description ?? item.productName ?? '',
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
      );
    }

    final result = await MobileArticleForm.show(context, initialData: initialData, isPurchase: false);

    if (result != null) {
      setState(() {
        final newItem = QuoteItem(
          id: index != null ? _items[index].id : _uuid.v4(),
          quoteId: widget.existing?.id ?? '',
          productId: result.productId,
          productName: result.productName,
          description: result.description,
          quantity: result.quantity,
          unitPrice: result.unitPrice,
          tvaRate: result.tvaRate,
          discountPercent: result.discountPercent,
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
      title: _isEditing ? 'Modifier le devis' : 'Nouveau devis',
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
                SmartDatePicker(
                  label: 'Date de validité',
                  value: _validityDate,
                  onChanged: (v) => setState(() => _validityDate = v),
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
                    designation: e.value.description ?? e.value.productName ?? '',
                    quantity: e.value.quantity,
                    unitPrice: e.value.unitPrice,
                    tvaRate: e.value.tvaRate,
                    discountPercent: e.value.discountPercent,
                    totalHT: e.value.computedTotalHT,
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
              ],
            ),
          ),
        ),
        
        MobileFormSection(
          title: 'Totaux',
          icon: Icons.calculate_outlined,
          child: MobileTotalsCard(
            subTotalHT: _totalHT,
            tvaBreakdown: _tvaBreakdown,
            totalTva: _totalTva,
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
            child: SmartTextInput(
              label: 'Notes internes, instructions de livraison...',
              initialValue: _notes,
              maxLines: 4,
              onChanged: (v) => setState(() => _notes = v),
            ),
          ),
        ),
      ],
    );
  }
}
