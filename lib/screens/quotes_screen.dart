import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/quotes/quotes_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../models/quote.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});
  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  String _search = '';
  @override
  void initState() {
    super.initState();
    context.read<QuotesBloc>().add(LoadQuotes());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(children: [
            AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
            const Spacer(),
            AppButton(label: 'Nouveau devis', icon: Icons.add_rounded, onPressed: () => _showCreateDialog(context)),
          ]),
        ),
        Expanded(
          child: BlocBuilder<QuotesBloc, QuotesState>(
            builder: (context, state) {
              if (state is QuotesLoading) return const Center(child: CircularProgressIndicator());
              if (state is QuotesError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is QuotesLoaded) {
                final filtered = _search.isEmpty ? state.quotes
                    : state.quotes.where((q) => q.number.toLowerCase().contains(_search) || (q.customerName ?? '').toLowerCase().contains(_search)).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Quote>(
                      columns: const ['N°', 'Client', 'Date', 'Validité', 'Total TTC', 'Statut'],
                      rows: filtered,
                      emptyMessage: 'Aucun devis trouvé',
                      cellBuilder: (q) => [
                        DataCell(Text(q.number, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text(q.customerName ?? '—')),
                        DataCell(Text(formatDate(q.date))),
                        DataCell(Text(formatDate(q.validityDate), style: TextStyle(color: q.isExpired ? AppColors.error : AppColors.textPrimary))),
                        DataCell(Text(formatCurrency(q.totalTTC), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(StatusBadge(label: q.status.label, color: q.status.color)),
                      ],
                      onDelete: (q) => context.read<QuotesBloc>().add(DeleteQuote(q.id)),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<QuotesBloc>()),
        BlocProvider.value(value: context.read<CustomersBloc>()),
        BlocProvider.value(value: context.read<ProductsBloc>()),
      ],
      child: const _QuoteDialog(),
    ));
  }
}

class _QuoteDialog extends StatefulWidget {
  const _QuoteDialog();
  @override
  State<_QuoteDialog> createState() => _QuoteDialogState();
}class _QuoteDialogState extends State<_QuoteDialog> {
  final Uuid _uuid = const Uuid();
  Customer? _selectedCustomer;
  String? _selectedProject;
  final List<String> _projects = [];
  DateTime _date = DateTime.now();
  DateTime _validityDate = DateTime.now().add(const Duration(days: 30));
  String _priceType = 'Hors taxes';
  final List<QuoteItem> _items = [];

  @override
  void initState() {
    super.initState();
    // TODO: Load projects if needed
  }

  void _showAddArticleDialog() async {
    final ctx = context;
    final product = await showDialog<Product>(
      context: ctx,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Ajouter un article'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogCtx,
              Product(id: '1', code: 'PRD-A', name: 'Produit A', sellingPrice: 10.0, tvaRate: 19),
            ),
            child: const Text('Produit A'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogCtx,
              Product(id: '2', code: 'PRD-B', name: 'Produit B', sellingPrice: 20.0, tvaRate: 19),
            ),
            child: const Text('Produit B'),
          ),
        ],
      ),
    );
    if (product != null) {
      setState(() {
        _items.add(QuoteItem(
          id: _uuid.v4(),
          quoteId: '',
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: product.sellingPrice,
          tvaRate: product.tvaRate,
          totalHT: product.sellingPrice,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau devis'),
      content: SizedBox(
        width: 1200,
        child: SingleChildScrollView(
          child: BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              final customers = state is CustomersLoaded ? state.customers : <Customer>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: client and project
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdown<String>(
                          label: 'Client *',
                          value: _selectedCustomer?.id,
                          hint: 'Rechercher des clients...',
                          items: customers
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCustomer = customers.firstWhere((c) => c.id == v)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppDropdown<String>(
                          label: 'Projet',
                          value: _selectedProject,
                          hint: 'Projet par défaut',
                          items: _projects.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (v) => setState(() => _selectedProject = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Dates row
                  Row(
                    children: [
                      Expanded(
                        child: Text('Date d\'émission: ${formatDate(_date)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setState(() => _date = d);
                        },
                        child: const Text('Changer'),
                      ),
                      const Spacer(),
                      Expanded(
                        child: Text('Date d\'échéance: ${formatDate(_validityDate)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _validityDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setState(() => _validityDate = d);
                        },
                        child: const Text('Changer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Price type radio group
                  Row(
                    children: [
                      const Text('Les prix des articles sont en:'),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 160,
                        child: RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hors taxes'),
                          value: 'Hors taxes',
                          groupValue: _priceType,
                          onChanged: (v) => setState(() => _priceType = v!),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Taxe incluse'),
                          value: 'Taxe incluse',
                          groupValue: _priceType,
                          onChanged: (v) => setState(() => _priceType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Articles table
                  const Text('Articles', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Produit')),
                        DataColumn(label: Text('Qté')),
                        DataColumn(label: Text('Prix U')),
                        DataColumn(label: Text('TVA %')),
                        DataColumn(label: Text('Total HT')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: _items.asMap().entries.map((e) {
                        final item = e.value;
                        return DataRow(cells: [
                          DataCell(Text(item.productName ?? '—')),
                          DataCell(Text(item.quantity.toString())),
                          DataCell(Text(item.unitPrice.toStringAsFixed(2))),
                          DataCell(Text(item.tvaRate.toString())),
                          DataCell(Text(item.totalHT.toStringAsFixed(2))),
                          DataCell(IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => setState(() => _items.removeAt(e.key)),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddArticleDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un article'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        AppButton(
          label: 'Créer',
          onPressed: () {
            if (_selectedCustomer == null) return;
            final quote = Quote(
              id: _uuid.v4(),
              number: generateDocNumber(DocPrefix.quote, DateTime.now().millisecondsSinceEpoch % 100000),
              customerId: _selectedCustomer!.id,
              customerName: _selectedCustomer!.name,
              date: _date,
              validityDate: _validityDate,
              // Additional fields can be added here: project, priceType, items
            );
            context.read<QuotesBloc>().add(AddQuote(quote));
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
