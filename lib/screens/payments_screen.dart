import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../blocs/payments/payments_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../models/payment_model.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/treasury_account.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/dashboard_card.dart';

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
    context.read<PaymentsBloc>().add(LoadPayments());
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
            // ─── Toolbar ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              color: AppColors.surface,
              child: Column(
                children: [
                  Row(
                    children: [
                      // Reference search
                      Expanded(
                        flex: 3,
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
                      const SizedBox(width: 12),
                      // Contact search
                      Expanded(
                        flex: 3,
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
                      const SizedBox(width: 12),
                      // Method filter
                      _FilterDropdown(
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
                      const SizedBox(width: 12),
                      // Status filter
                      _FilterDropdown(
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
                      const SizedBox(width: 12),
                      // Actions button
                      PopupMenuButton<String>(
                        offset: const Offset(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Actions',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              SizedBox(width: 6),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 16, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'export',
                            child: Row(children: [
                              const Icon(Icons.file_download_rounded,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 10),
                              const Text('Exporter CSV'),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'print',
                            child: Row(children: [
                              const Icon(Icons.print_rounded,
                                  size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 10),
                              const Text('Imprimer'),
                            ]),
                          ),
                        ],
                        onSelected: (val) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    '${val == 'export' ? 'Export' : 'Impression'} bientot disponible')),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      // New payment button
                      ElevatedButton.icon(
                        onPressed: () => _showCreateDialog(context),
                        icon: const Icon(Icons.add_rounded,
                            size: 18, color: Colors.white),
                        label: const Text('Nouveau paiement',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Table ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: state is PaymentsLoading
                      ? const Center(
                          child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? _buildEmpty()
                          : Column(
                              children: [
                                _buildTableHeader(),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: pageRows.length,
                                    separatorBuilder: (_, __) => const Divider(
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
            const SizedBox(height: 24),
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
            child: const Icon(Icons.payment_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Aucun paiement trouve',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Creez votre premier paiement en cliquant sur le bouton ci-dessus.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Row(
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                const SizedBox(height: 3),
                Text(
                  formatDateTime(p.paymentDate),
                  style: const TextStyle(
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
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.contactName ?? '—',
                      style: const TextStyle(
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                methodLabel,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
            ),
          ),
          // Status badge
          Expanded(
            flex: 2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Rows per page
          const Text('Lignes:',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Container(
            height: 30,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                style: const TextStyle(
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
          const SizedBox(width: 16),
          Text('Page ${_page + 1} sur $totalPages',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text('Affichage de $start a $end sur $total resultats',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          _PaginationButton(
            icon: Icons.chevron_left_rounded,
            enabled: _page > 0,
            onTap: () => setState(() => _page--),
          ),
          const SizedBox(width: 4),
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
        title: const Text('Supprimer le paiement'),
        content: Text(
            'Etes-vous sur de vouloir supprimer le paiement ${p.paymentNumber} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PaymentsBloc>().add(DeletePayment(p.id));
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer',
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
        const SnackBar(
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
    final seq = now.millisecondsSinceEpoch % 1000000;
    final paymentNumber = '$prefix-$year-${seq.toString().padLeft(6, '0')}';

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 780),
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
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Direction toggle
                      _buildDirectionSection(),
                      const SizedBox(height: 20),
                      // Contact field
                      _buildContactField(),
                      const SizedBox(height: 16),
                      // Amount + Method row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount
                          Expanded(child: _buildAmountField()),
                          const SizedBox(width: 16),
                          // Method
                          Expanded(child: _buildMethodField()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Status
                      _buildStatusField(),
                      const SizedBox(height: 20),
                      // Payment details (expandable)
                      _buildDetailsSection(),
                      const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
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
            child: const Icon(Icons.payment_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Column(
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
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded,
                size: 16, color: AppColors.textSecondary),
            label: const Text('Annuler',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded,
                size: 16, color: Colors.white),
            label: const Text('Enregistrer',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        const Text('Direction du paiement',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DirectionButton(
                label: 'Encaissement',
                subtitle: 'Argent entrant',
                icon: Icons.arrow_downward_rounded,
                color: AppColors.success,
                isSelected: _direction == 'encaissement',
                onTap: () => setState(() => _direction = 'encaissement'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DirectionButton(
                label: 'Decaissement',
                subtitle: 'Argent sortant',
                icon: Icons.arrow_upward_rounded,
                color: AppColors.error,
                isSelected: _direction == 'decaissement',
                onTap: () => setState(() => _direction = 'decaissement'),
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
        const Text('Contact *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _contactSearchCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Rechercher un client ou fournisseur...',
            hintStyle: const TextStyle(
                color: AppColors.textTertiary, fontSize: 13),
            prefixIcon: const Icon(Icons.person_rounded,
                size: 18, color: AppColors.textTertiary),
            suffixIcon: _selectedContactId != null
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        size: 16, color: AppColors.textTertiary),
                    onPressed: () => setState(() {
                      _selectedContactId = null;
                      _selectedContactName = null;
                      _selectedContactType = null;
                      _contactSearchCtrl.clear();
                      _contactResults = [];
                      _showContactDropdown = false;
                    }),
                  )
                : null,
          ),
          onChanged: (v) {
            if (_selectedContactId != null) {
              setState(() {
                _selectedContactId = null;
                _selectedContactName = null;
                _selectedContactType = null;
              });
            }
            _filterContacts(v);
          },
        ),
        // Selected contact indicator
        if (_selectedContactId != null && _selectedContactName != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(_selectedContactName!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success)),
                  Text(
                    _selectedContactType == 'customer'
                        ? '  (Client)'
                        : '  (Fournisseur)',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        // Contact search results (inline, not overlaid)
        if (_showContactDropdown && _contactResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _contactResults.length,
              itemBuilder: (context, index) {
                final c = _contactResults[index];
                final isCustomer = c['type'] == 'customer';
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedContactId = c['id'];
                      _selectedContactName = c['name'];
                      _selectedContactType = c['type'];
                      _contactSearchCtrl.text = c['name'];
                      _showContactDropdown = false;
                      _contactResults = [];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isCustomer
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.warning.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCustomer
                                ? Icons.person_rounded
                                : Icons.factory_rounded,
                            size: 14,
                            color: isCustomer
                                ? AppColors.primary
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['name'],
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              Text(
                                isCustomer ? 'Client' : 'Fournisseur',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        // Loading indicator
        if (!_contactsLoaded)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Chargement des contacts...',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textTertiary)),
          ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Montant *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _amountCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '0,00',
            hintStyle: const TextStyle(
                color: AppColors.textTertiary, fontSize: 13),
            suffixText: 'DT',
            suffixStyle: const TextStyle(
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
        const Text('Methode *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _method,
              isExpanded: true,
              style: const TextStyle(
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
        const Text('Statut',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
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
            const SizedBox(width: 8),
            _StatusChip(
              label: 'En attente',
              value: 'pending',
              selected: _status == 'pending',
              color: AppColors.warning,
              bg: AppColors.warningLight,
              onTap: () => setState(() => _status = 'pending'),
            ),
            const SizedBox(width: 8),
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
        color: Colors.white,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _detailsExpanded = !_detailsExpanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
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
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Account
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compte de tresorerie',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                          builder: (context, state) {
                            List<TreasuryAccount> tAccounts = [];
                            if (state is TreasuryAccountsLoaded) {
                              tAccounts = state.accounts;
                              if (_selectedAccountId == null && tAccounts.isNotEmpty) {
                                _selectedAccountId = tAccounts.first.id;
                              }
                            }
                            return DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedAccountId,
                                isExpanded: true,
                                hint: const Text('Selectionner un compte',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textTertiary)),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary),
                                items: tAccounts.map((a) {
                                  return DropdownMenuItem(
                                    value: a.id,
                                    child: Row(
                                      children: [
                                        Icon(
                                          a.type == 'bank'
                                              ? Icons.account_balance_rounded
                                              : Icons.payments_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('\${a.name} (Solde: \${formatCurrencyDT(a.balance)})'),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedAccountId = v),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Reference externe
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reference externe (optionnel)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _referenceCtrl,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
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
                  const SizedBox(height: 12),
                  // Date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de paiement',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          child: Row(
                            children: [
                              const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: AppColors.textTertiary),
                              const SizedBox(width: 10),
                              Text(
                                formatDate(_paymentDate),
                                style: const TextStyle(
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
        const Text('Notes',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
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
        style: const TextStyle(fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          prefixIcon:
              Icon(icon, size: 18, color: AppColors.textTertiary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          fillColor: AppColors.surfaceAlt,
          filled: true,
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          style: const TextStyle(
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
          padding: const EdgeInsets.all(6),
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : Colors.white,
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
            const SizedBox(width: 12),
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
                    style: const TextStyle(
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
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
