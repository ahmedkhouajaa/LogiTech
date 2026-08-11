import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../blocs/payments/payments_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../models/payment_model.dart';
import '../models/treasury_transaction.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/treasury_account.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/searchable_dropdown_field.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _searchQuery = '';
  String _contactSearch = '';
  String _methodFilter = 'tous';
  String _statusFilter = 'tous';
  final String _directionFilter = 'tous';
  int _rowsPerPage = 20;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    context.read<PaymentsBloc>().add(const LoadFirstPayments());
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<SuppliersBloc>().add(LoadSuppliers());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentsBloc, PaymentsState>(
      builder: (context, state) {
        List<Payment> payments = [];
        List<PaymentAccount> accounts = [];

        if (state is PaymentsLoaded) {
          payments = state.payments;
          accounts = state.accounts;
        }

        // Apply filters
        final filtered = payments.where((p) {
          final matchesSearch = _searchQuery.isEmpty ||
              p.paymentNumber.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesContact = _contactSearch.isEmpty ||
              (p.contactName ?? '').toLowerCase().contains(_contactSearch.toLowerCase());
          final matchesMethod = _methodFilter == 'tous' || p.method == _methodFilter;
          final matchesStatus = _statusFilter == 'tous' || p.status == _statusFilter;
          final matchesDirection = _directionFilter == 'tous' || p.direction == _directionFilter;
          return matchesSearch && matchesContact && matchesMethod && matchesStatus && matchesDirection;
        }).toList();

        final totalPages = (_rowsPerPage > 0 && filtered.isNotEmpty)
            ? (filtered.length / _rowsPerPage).ceil()
            : 1;
        final start = _page * _rowsPerPage;
        final end = (start + _rowsPerPage).clamp(0, filtered.length);
        final pageRows = start < filtered.length ? filtered.sublist(start, end) : <Payment>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Toolbar ───────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paiements',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text('Gerer vos paiements', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  // Actions button
                  PopupMenuButton<String>(
                    offset: Offset(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Container(
                      height: 40,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Actions',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          SizedBox(width: 6),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'export',
                        child: Row(children: [
                          Icon(Icons.file_download_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text('Exporter CSV'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'print',
                        child: Row(children: [
                          Icon(Icons.print_rounded, size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 10),
                          Text('Imprimer'),
                        ]),
                      ),
                    ],
                    onSelected: (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${val == 'export' ? 'Export' : 'Impression'} bientot disponible')),
                      );
                    },
                  ),
                  SizedBox(width: AppSpacing.md),
                  // New payment button
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    label: Text('Nouveau paiement',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Reference search
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Référence',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: _SearchField(
                                  hint: 'Recherche des paiements...',
                                  icon: Icons.search_rounded,
                                  value: _searchQuery,
                                  onChanged: (v) => setState(() {
                                    _searchQuery = v;
                                    _page = 0;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        // Contact search
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Contact',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: _SearchField(
                                  hint: 'Rechercher un contact...',
                                  icon: Icons.person_search_rounded,
                                  value: _contactSearch,
                                  onChanged: (v) => setState(() {
                                    _contactSearch = v;
                                    _page = 0;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        // Method filter
                        Expanded(
                          flex: 2,
                          child: _FilterDropdown(
                            label: 'Methode',
                            value: _methodFilter,
                            items: const {
                              'tous': 'Tous',
                              'especes': 'Especes',
                              'cheque': 'Cheque',
                              'virement': 'Virement',
                              'carte': 'Carte',
                            },
                            onChanged: (v) => setState(() {
                              _methodFilter = v!;
                              _page = 0;
                            }),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        // Status filter
                        Expanded(
                          flex: 2,
                          child: _FilterDropdown(
                            label: 'Statut',
                            value: _statusFilter,
                            items: const {
                              'tous': 'Tous',
                              'paid': 'Paye',
                              'pending': 'En attente',
                              'cancelled': 'Annule',
                            },
                            onChanged: (v) => setState(() {
                              _statusFilter = v!;
                              _page = 0;
                            }),
                          ),
                        ),
                      ],
                    ),
                    if (_searchQuery.isNotEmpty || _contactSearch.isNotEmpty || _methodFilter != 'tous' || _statusFilter != 'tous')
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${filtered.length} résultat${filtered.length > 1 ? 's' : ''}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _contactSearch = '';
                                  _methodFilter = 'tous';
                                  _statusFilter = 'tous';
                                  _page = 0;
                                });
                              },
                              icon: Icon(Icons.refresh_rounded, size: 16),
                              label: Text('Réinitialiser les filtres'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // ─── Table ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: state is PaymentsLoading
                      ? Center(
                          child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? _buildEmpty()
                          : Column(
                              children: [
                                _buildTableHeader(),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: pageRows.length,
                                    separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: AppColors.border),
                                    itemBuilder: (context, index) =>
                                        _buildRow(context, pageRows[index]),
                                  ),
                                ),
                                _buildPagination(
                                    filtered.length, totalPages),
                              ],
                            ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payment_rounded,
                size: 40, color: AppColors.primary),
          ),
          SizedBox(height: 16),
          Text('Aucun paiement trouve',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          SizedBox(height: 6),
          Text('Creez votre premier paiement en cliquant sur le bouton ci-dessus.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text('Reference',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))),
          Expanded(
              flex: 3,
              child: Text('Contact',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))),
          Expanded(
              flex: 2,
              child: Text('Montant',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))),
          Expanded(
              flex: 2,
              child: Text('Methode',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))),
          Expanded(
              flex: 2,
              child: Text('Statut',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))),
          SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, Payment p) {
    final isEncaissement = p.direction == 'encaissement';
    final amountColor =
        isEncaissement ? AppColors.success : AppColors.error;
    final amountPrefix = isEncaissement ? '+' : '-';

    Color statusColor;
    Color statusBg;
    String statusLabel;
    switch (p.status) {
      case 'paid':
        statusColor = AppColors.success;
        statusBg = AppColors.successLight;
        statusLabel = 'Paye';
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusBg = AppColors.warningLight;
        statusLabel = 'En attente';
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusBg = AppColors.errorLight;
        statusLabel = 'Annule';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusBg = AppColors.surfaceAlt;
        statusLabel = p.status;
    }

    String methodLabel;
    switch (p.method) {
      case 'especes':
        methodLabel = 'Especes';
        break;
      case 'cheque':
        methodLabel = 'Cheque';
        break;
      case 'virement':
        methodLabel = 'Virement';
        break;
      case 'carte':
        methodLabel = 'Carte';
        break;
      default:
        methodLabel = p.method;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.transparent,
      child: Row(
        children: [
          // Reference + date
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.paymentNumber,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                SizedBox(height: 3),
                Text(
                  formatDateTime(p.paymentDate),
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          // Contact
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    (p.contactName ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(p.contactName ?? '—',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          // Amount
          Expanded(
            flex: 2,
            child: Text(
              '$amountPrefix ${formatCurrency(p.amount, symbol: 'DT')}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ),
          // Method badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      p.method == 'especes' ? Icons.money_rounded
                          : p.method == 'cheque' ? Icons.account_balance_wallet_rounded
                          : p.method == 'virement' ? Icons.account_balance_rounded
                          : p.method == 'carte' ? Icons.credit_card_rounded
                          : Icons.payment_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      methodLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Status badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                label: statusLabel,
                color: statusColor,
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TableAction(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.error,
                  tooltip: 'Supprimer',
                  onTap: () => _confirmDelete(context, p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int total, int totalPages) {
    final start = _page * _rowsPerPage + 1;
    final end = ((_page + 1) * _rowsPerPage).clamp(0, total);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Rows per page
          Text('Lignes:',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(width: 8),
          Container(
            height: 30,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textPrimary),
                items: [10, 20, 50, 100].map((n) {
                  return DropdownMenuItem(value: n, child: Text('$n'));
                }).toList(),
                onChanged: (v) => setState(() {
                  _rowsPerPage = v!;
                  _page = 0;
                }),
              ),
            ),
          ),
          SizedBox(width: 16),
          Text('Page ${_page + 1} sur $totalPages',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Spacer(),
          Text('Affichage de $start a $end sur $total resultats',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(width: 16),
          _PaginationButton(
            icon: Icons.chevron_left_rounded,
            enabled: _page > 0,
            onTap: () => setState(() => _page--),
          ),
          SizedBox(width: 4),
          _PaginationButton(
            icon: Icons.chevron_right_rounded,
            enabled: _page < totalPages - 1,
            onTap: () => setState(() => _page++),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Payment p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer le paiement'),
        content: Text(
            'Etes-vous sur de vouloir supprimer le paiement ${p.paymentNumber} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PaymentsBloc>().add(DeletePayment(p.id));
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<PaymentsBloc>()),
          BlocProvider.value(value: context.read<CustomersBloc>()),
          BlocProvider.value(value: context.read<SuppliersBloc>()),
          // Read TreasuryAccountsBloc from parent
          BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
        ],
        child: const _CreatePaymentDialog(),
      ),
    );
  }
}

// ─── Create Payment Dialog ──────────────────────────────────────────────────
class _CreatePaymentDialog extends StatefulWidget {
  const _CreatePaymentDialog();

  @override
  State<_CreatePaymentDialog> createState() => _CreatePaymentDialogState();
}

class _CreatePaymentDialogState extends State<_CreatePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  String _direction = 'encaissement';
  String _method = 'especes';
  String _status = 'paid';
  String? _selectedAccountId;
  String? _selectedContactId;
  String? _selectedContactType;
  String? _selectedContactName;
  bool _detailsExpanded = true;

  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _contactSearchCtrl = TextEditingController();
  late DateTime _paymentDate;

  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  List<Map<String, dynamic>> _contactResults = [];
  bool _showContactDropdown = false;
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    _paymentDate = DateTime.now();

    // Trigger load of treasury accounts
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());

    // Load contacts directly from database (avoids BLoC timing issues)
    _loadContactsFromDB();
  }

  Future<void> _loadContactsFromDB() async {
    final customers = await DatabaseHelper.instance.getCustomers();
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    if (mounted) {
      setState(() {
        _customers = customers;
        _suppliers = suppliers;
        _contactsLoaded = true;
      });
    }
  }

  void _filterContacts(String query) {
    if (query.isEmpty) {
      setState(() {
        _contactResults = [];
        _showContactDropdown = false;
      });
      return;
    }
    final q = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    for (final c in _customers) {
      if (c.name.toLowerCase().contains(q)) {
        results.add({'id': c.id, 'name': c.name, 'type': 'customer'});
      }
    }
    for (final s in _suppliers) {
      if (s.name.toLowerCase().contains(q)) {
        results.add({'id': s.id, 'name': s.name, 'type': 'supplier'});
      }
    }
    setState(() {
      _contactResults = results.take(8).toList();
      _showContactDropdown = results.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _contactSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Veuillez selectionner un contact'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final db = context.read<PaymentsBloc>();
    final now = DateTime.now();
    final year = now.year;
    final prefix =
        _direction == 'encaissement' ? 'PAI' : 'DEB';

    // Generate a unique payment number
    final seq = await DatabaseHelper.instance.getNextPaymentSequence();
    final paymentNumber = _direction == 'encaissement'
        ? generateDocNumber(DocPrefix.paymentIn, seq)
        : generateDocNumber(DocPrefix.paymentOut, seq);

    final payment = Payment(
      id: const Uuid().v4(),
      paymentNumber: paymentNumber,
      direction: _direction,
      contactId: _selectedContactId!,
      contactType: _selectedContactType!,
      contactName: _selectedContactName,
      amount: double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0,
      method: _method,
      accountId: _selectedAccountId,
      reference: _referenceCtrl.text.isNotEmpty ? _referenceCtrl.text : null,
      paymentDate: _paymentDate,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      status: _status,
      createdAt: now,
      updatedAt: now,
    );

    db.add(AddPayment(payment));
    
    // Create TreasuryTransaction if an account is selected
    if (_selectedAccountId != null) {
      final tx = TreasuryTransaction(
        id: const Uuid().v4(),
        transactionNumber: 'TR-TEMP', // Will be regenerated by bloc
        accountId: _selectedAccountId!,
        dateTransaction: _paymentDate,
        type: _direction == 'encaissement' ? 'income' : 'expense',
        amount: payment.amount,
        description: 'Paiement ${payment.paymentNumber}${payment.contactName != null ? ' - ${payment.contactName}' : ''}',
        paymentId: payment.id,
      );
      context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(tx));
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Paiement $paymentNumber cree avec succes'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Container(
        width: 700,
        constraints: BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Direction toggle
                      _buildDirectionSection(),
                      SizedBox(height: 20),
                      // Contact field
                      _buildContactField(),
                      SizedBox(height: 16),
                      // Amount + Method row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount
                          Expanded(child: _buildAmountField()),
                          SizedBox(width: 16),
                          // Method
                          Expanded(child: _buildMethodField()),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Status
                      _buildStatusField(),
                      SizedBox(height: 20),
                      // Payment details (expandable)
                      _buildDetailsSection(),
                      SizedBox(height: 20),
                      // Notes
                      _buildNotesField(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.payment_rounded,
                color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nouveau Paiement',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text('Enregistrer un encaissement ou decaissement',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          Spacer(),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded,
                size: 16, color: AppColors.textSecondary),
            label: Text('Annuler',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _save,
            icon: Icon(Icons.save_rounded,
                size: 16, color: Colors.white),
            label: Text('Enregistrer',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Direction du paiement',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DirectionButton(
                label: 'Encaissement',
                subtitle: 'Argent entrant',
                icon: Icons.arrow_downward_rounded,
                color: AppColors.success,
                isSelected: _direction == 'encaissement',
                onTap: () => setState(() {
                  _direction = 'encaissement';
                  _selectedContactType = 'customer';
                  _selectedContactId = null;
                  _selectedContactName = null;
                }),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _DirectionButton(
                label: 'Decaissement',
                subtitle: 'Argent sortant',
                icon: Icons.arrow_upward_rounded,
                color: AppColors.error,
                isSelected: _direction == 'decaissement',
                onTap: () => setState(() {
                  _direction = 'decaissement';
                  _selectedContactType = 'supplier';
                  _selectedContactId = null;
                  _selectedContactName = null;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type de contact',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedContactType ?? 'customer',
              isExpanded: true,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('Client')),
                DropdownMenuItem(value: 'supplier', child: Text('Fournisseur')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedContactType = v;
                    _selectedContactId = null;
                    _selectedContactName = null;
                  });
                }
              },
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(_selectedContactType == 'supplier' ? 'Fournisseur *' : 'Client *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        SizedBox(height: 6),
        if (_selectedContactType == 'supplier')
          BlocBuilder<SuppliersBloc, SuppliersState>(
            builder: (context, state) {
              final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
              final selectedSupplier = suppliers.cast<Supplier?>().firstWhere(
                (s) => s?.id == _selectedContactId,
                orElse: () => null,
              );
              final displayName = selectedSupplier != null
                  ? (selectedSupplier.companyName?.isNotEmpty == true
                      ? selectedSupplier.companyName!
                      : (selectedSupplier.responsibleName?.isNotEmpty == true ? selectedSupplier.responsibleName! : selectedSupplier.name))
                  : _selectedContactName;

              return SearchableSelectorField(
                hint: 'Rechercher un fournisseur...',
                selectedText: displayName,
                onTap: () async {
                  final res = await showSupplierSelectDialog(context, suppliers, selectedSupplierId: _selectedContactId);
                  if (res != null) {
                    final found = suppliers.firstWhere((s) => s.id == res, orElse: () => Supplier(id: '', code: '', name: ''));
                    setState(() {
                      _selectedContactId = res;
                      _selectedContactName = found.companyName?.isNotEmpty == true
                          ? found.companyName!
                          : (found.responsibleName?.isNotEmpty == true ? found.responsibleName! : found.name);
                      _selectedContactType = 'supplier';
                    });
                  }
                },
              );
            },
          )
        else
          BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              final customers = state is CustomersLoaded ? state.customers : <Customer>[];
              final selectedCustomer = customers.cast<Customer?>().firstWhere(
                (c) => c?.id == _selectedContactId,
                orElse: () => null,
              );
              final displayName = selectedCustomer != null
                  ? (selectedCustomer.companyName?.isNotEmpty == true ? selectedCustomer.companyName! : selectedCustomer.name)
                  : _selectedContactName;

              return SearchableSelectorField(
                hint: 'Rechercher un client...',
                selectedText: displayName,
                onTap: () async {
                  final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedContactId);
                  if (res != null) {
                    final found = customers.firstWhere((c) => c.id == res, orElse: () => Customer(id: '', code: '', name: ''));
                    setState(() {
                      _selectedContactId = res;
                      _selectedContactName = found.companyName?.isNotEmpty == true ? found.companyName! : found.name;
                      _selectedContactType = 'customer';
                    });
                  }
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Montant *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        SizedBox(height: 6),
        TextFormField(
          controller: _amountCtrl,
          keyboardType:
              TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '0,00',
            hintStyle: TextStyle(
                color: AppColors.textTertiary, fontSize: 13),
            suffixText: 'DT',
            suffixStyle: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Montant requis';
            final val =
                double.tryParse(v.replaceAll(',', '.'));
            if (val == null || val <= 0) return 'Montant invalide';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMethodField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Methode *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _method,
              isExpanded: true,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
              items: const [
                DropdownMenuItem(
                    value: 'especes', child: Text('Especes')),
                DropdownMenuItem(
                    value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(
                    value: 'virement', child: Text('Virement')),
                DropdownMenuItem(value: 'carte', child: Text('Carte')),
              ],
              onChanged: (v) => setState(() => _method = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Statut',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        SizedBox(height: 8),
        Row(
          children: [
            _StatusChip(
              label: 'Paye',
              value: 'paid',
              selected: _status == 'paid',
              color: AppColors.success,
              bg: AppColors.successLight,
              onTap: () => setState(() => _status = 'paid'),
            ),
            SizedBox(width: 8),
            _StatusChip(
              label: 'En attente',
              value: 'pending',
              selected: _status == 'pending',
              color: AppColors.warning,
              bg: AppColors.warningLight,
              onTap: () => setState(() => _status = 'pending'),
            ),
            SizedBox(width: 8),
            _StatusChip(
              label: 'Annule',
              value: 'cancelled',
              selected: _status == 'cancelled',
              color: AppColors.error,
              bg: AppColors.errorLight,
              onTap: () => setState(() => _status = 'cancelled'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppColors.surface,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _detailsExpanded = !_detailsExpanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 16, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Details de la methode de paiement',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  Icon(
                    _detailsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_detailsExpanded) ...[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Account
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Compte de tresorerie',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      SizedBox(height: 6),
                      BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                        builder: (context, state) {
                          List<TreasuryAccount> tAccounts = [];
                          if (state is TreasuryAccountsLoaded) {
                            tAccounts = state.accounts;
                            if (_selectedAccountId == null && tAccounts.isNotEmpty) {
                              _selectedAccountId = tAccounts.first.id;
                            }
                          }
                          final selectedAccount = tAccounts.cast<TreasuryAccount?>().firstWhere(
                            (a) => a?.id == _selectedAccountId,
                            orElse: () => null,
                          );

                          return SearchableSelectorField(
                            hint: 'Selectionner un compte',
                            selectedText: selectedAccount != null
                                ? '${selectedAccount.name} (Solde: ${formatCurrencyDT(selectedAccount.balance)})'
                                : null,
                            onTap: () async {
                              final res = await showTreasuryAccountSelectDialog(
                                context,
                                tAccounts,
                                selectedAccountId: _selectedAccountId,
                              );
                              if (res != null) {
                                setState(() => _selectedAccountId = res);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Reference externe
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reference externe (optionnel)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      SizedBox(height: 6),
                      TextFormField(
                        controller: _referenceCtrl,
                        style: TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'N° de cheque, reference de virement...',
                          hintStyle: TextStyle(
                              color: AppColors.textTertiary, fontSize: 13),
                          prefixIcon: Icon(Icons.tag_rounded,
                              size: 18,
                              color: AppColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date de paiement',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _paymentDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _paymentDate = picked);
                          }
                        },
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 14),
                          child: Row(
                            children: [
                              Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: AppColors.textTertiary),
                              SizedBox(width: 10),
                              Text(
                                formatDate(_paymentDate),
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        SizedBox(height: 6),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          style: TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ajouter des notes sur ce paiement...',
            hintStyle:
                TextStyle(color: AppColors.textTertiary, fontSize: 13),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

// ─── Small Widgets ──────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.hint,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        style: TextStyle(fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: AppColors.textTertiary, fontSize: 13),
          prefixIcon:
              Icon(icon, size: 18, color: AppColors.textTertiary),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          fillColor: AppColors.surfaceAlt,
          filled: true,
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
                  color: AppColors.primary, width: 2)),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          style: TextStyle(
              fontSize: 13, color: AppColors.textPrimary),
          items: items.entries
              .map((e) => DropdownMenuItem(
                  value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TableAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _TableAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: enabled ? null : AppColors.surfaceAlt,
        ),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? AppColors.textPrimary
                : AppColors.textTertiary),
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DirectionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : AppColors.surface,
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 18,
                  color: isSelected ? color : AppColors.textSecondary),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? color
                            : AppColors.textPrimary)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(Icons.check_circle_rounded, color: color, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding:
            EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? bg : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: selected ? color : AppColors.border, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? color : AppColors.textSecondary)),
      ),
    );
  }
}
