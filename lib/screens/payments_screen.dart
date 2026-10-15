import '../widgets/traite_editor_dialog.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:excel/excel.dart' hide Border;
import '../utils/file_download_helper.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../blocs/payments/payments_bloc.dart';
import '../widgets/shimmer_table_row.dart';
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
import '../services/permission_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_document_service.dart';
import '../models/user_management_model.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/searchable_dropdown_field.dart';
import '../l10n/app_localizations.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final Set<String> _selectedPaymentIds = {};
  bool _isFirstLoad = true;
  String _searchQuery = '';
  String _contactSearch = '';
  String _methodFilter = 'tous';
  String _statusFilter = 'tous';
  String _directionFilter = 'tous';
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
    return BlocConsumer<PaymentsBloc, PaymentsState>(
      listener: (context, state) {
        if (_isFirstLoad && (state is PaymentsLoaded || state is PaymentsError)) {
          setState(() {
            _isFirstLoad = false;
          });
        }
      },
      builder: (context, state) {
        List<Payment> payments = [];

        if (!_isFirstLoad && state is PaymentsLoaded) {
          payments = state.payments;
        }

        // Apply filters
        final filtered = payments.where((p) {
          final matchesSearch = _searchQuery.isEmpty ||
              p.paymentNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (p.reference ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (p.notes ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesContact = _contactSearch.isEmpty ||
              (p.contactName ?? '').toLowerCase().contains(_contactSearch.toLowerCase());
          final matchesMethod = _methodFilter == 'tous' || p.method.toLowerCase() == _methodFilter.toLowerCase();
          final matchesStatus = _statusFilter == 'tous' || p.status.toLowerCase() == _statusFilter.toLowerCase();
          final matchesDirection = _directionFilter == 'tous' || p.direction.toLowerCase() == _directionFilter.toLowerCase();
          return matchesSearch && matchesContact && matchesMethod && matchesStatus && matchesDirection;
        }).toList();

        final totalPages = (_rowsPerPage > 0 && filtered.isNotEmpty)
            ? (filtered.length / _rowsPerPage).ceil()
            : 1;
        final start = _page * _rowsPerPage;
        final end = (start + _rowsPerPage).clamp(0, filtered.length);
        final pageRows = start < filtered.length ? filtered.sublist(start, end) : <Payment>[];

        final isAllSelected = filtered.isNotEmpty && filtered.every((p) => _selectedPaymentIds.contains(p.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Toolbar ───────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;
                  final titleWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Paiements'),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(context.tr('Gérer vos paiements'), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  );

                  final actionsDropdown = PopupMenuButton<String>(
                    offset: const Offset(0, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.tr('Actions'),
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(width: 6),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'export',
                        child: Row(children: [
                          Icon(Icons.file_download_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(context.tr('Exporter CSV')),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'print',
                        child: Row(children: [
                          Icon(Icons.print_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Text(context.tr('Imprimer')),
                        ]),
                      ),
                    ],
                    onSelected: (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${val == 'export' ? context.tr('Export') : context.tr('Impression')} ${context.tr('bientôt disponible')}')),
                      );
                    },
                  );

                  final newBtn = PermissionService.instance.canCreate(UserPermissionResources.payments)
                      ? ElevatedButton.icon(
                          onPressed: () => _showCreateDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                          label: Text(context.tr('Nouveau paiement'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        )
                      : const SizedBox.shrink();

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (_selectedPaymentIds.isNotEmpty) ...[
                              _buildBulkActionsDropdown(),
                              const SizedBox(width: 10),
                            ],
                            actionsDropdown,
                            if (PermissionService.instance.canCreate(UserPermissionResources.payments)) ...[
                              const SizedBox(width: 10),
                              newBtn,
                            ],
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      titleWidget,
                      const Spacer(),
                      if (_selectedPaymentIds.isNotEmpty) ...[
                        _buildBulkActionsDropdown(),
                        const SizedBox(width: 10),
                      ],
                      actionsDropdown,
                      if (PermissionService.instance.canCreate(UserPermissionResources.payments)) ...[
                        const SizedBox(width: 10),
                        newBtn,
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Reference search
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.tr('Référence'),
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: _SearchField(
                              hint: context.tr('Recherche référence...'),
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
                    const SizedBox(width: 10),
                    // Contact search
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.tr('Contact'),
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: _SearchField(
                              hint: context.tr('Rechercher contact...'),
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
                    const SizedBox(width: 10),
                    // Method filter
                    Expanded(
                      flex: 2,
                      child: _FilterDropdown(
                        label: context.tr('Méthode'),
                        value: _methodFilter,
                        items: {
                          'tous': context.tr('Tous'),
                          'especes': context.tr('Espèces'),
                          'cheque': context.tr('Chèque'),
                          'virement': context.tr('Virement'),
                          'carte': context.tr('Carte'),
                          'traite': context.tr('Traite'),
                          'retenue_source': context.tr('Retenue à la source'),
                        },
                        onChanged: (v) => setState(() {
                          _methodFilter = v!;
                          _page = 0;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Status filter
                    Expanded(
                      flex: 2,
                      child: _FilterDropdown(
                        label: context.tr('Statut'),
                        value: _statusFilter,
                        items: {
                          'tous': context.tr('Tous'),
                          'paid': context.tr('Payé'),
                          'pending': context.tr('En attente'),
                          'cancelled': context.tr('Annulé'),
                        },
                        onChanged: (v) => setState(() {
                          _statusFilter = v!;
                          _page = 0;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Direction filter
                    Expanded(
                      flex: 2,
                      child: _FilterDropdown(
                        label: context.tr('Type'),
                        value: _directionFilter,
                        items: {
                          'tous': context.tr('Tous'),
                          'encaissement': context.tr('Encaissement'),
                          'decaissement': context.tr('Décaissement'),
                        },
                        onChanged: (v) => setState(() {
                          _directionFilter = v!;
                          _page = 0;
                        }),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty ||
                        _contactSearch.isNotEmpty ||
                        _methodFilter != 'tous' ||
                        _statusFilter != 'tous' ||
                        _directionFilter != 'tous') ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _contactSearch = '';
                              _methodFilter = 'tous';
                              _statusFilter = 'tous';
                              _directionFilter = 'tous';
                              _page = 0;
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          tooltip: context.tr('Réinitialiser les filtres'),
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.error,
                            backgroundColor: AppColors.error.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ─── Table ─────────────────────────────────────────────
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: _isFirstLoad || state is PaymentsLoading || state is PaymentsInitial
                      ? ShimmerTable(
                          headerColumns: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: Checkbox(
                                value: false,
                                onChanged: null,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                side: BorderSide(color: AppColors.border, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(flex: 3, child: Text(context.tr('Référence'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            Expanded(flex: 3, child: Text(context.tr('Contact'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text(context.tr('Montant'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            Expanded(flex: 3, child: Text(context.tr('Méthode'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text(context.tr('Statut'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            SizedBox(width: 60, child: Text(context.tr('Actions'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                          ],
                        )
                      : filtered.isEmpty
                          ? _buildEmpty()
                          : Column(
                              children: [
                                _buildTableHeader(isAllSelected, filtered),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: pageRows.length,
                                    separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: AppColors.border),
                                    itemBuilder: (context, index) =>
                                        _buildRow(context, pageRows[index], index),
                                  ),
                                ),
                                _buildPagination(
                                    filtered.length, totalPages),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 10),
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payment_rounded,
                size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(context.tr('Aucun paiement trouvé'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(context.tr('Créez votre premier paiement en cliquant sur le bouton ci-dessus.'),
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isAllSelected, List<Payment> filtered) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: isAllSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedPaymentIds.addAll(filtered.map((p) => p.id));
                  } else {
                    _selectedPaymentIds.clear();
                  }
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: AppColors.textPrimary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: Text(context.tr('Référence'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary))),
          Expanded(
              flex: 3,
              child: Text(context.tr('Contact'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary))),
          Expanded(
              flex: 2,
              child: Text(context.tr('Montant'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary))),
          Expanded(
              flex: 3,
              child: Text(context.tr('Méthode'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary))),
          Expanded(
              flex: 2,
              child: Text(context.tr('Statut'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary))),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, Payment p, int index) {
    final isEncaissement = p.direction.toLowerCase() == 'encaissement';
    final amountColor =
        isEncaissement ? AppColors.success : AppColors.error;
    final amountPrefix = isEncaissement ? '+' : '-';

    Color statusColor;
    String statusLabel;
    switch (p.status.toLowerCase()) {
      case 'paid':
        statusColor = AppColors.success;
        statusLabel = context.tr('Payé');
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusLabel = context.tr('En attente');
        break;
      case 'cancelled':
      case 'rejected':
        statusColor = AppColors.error;
        statusLabel = context.tr('Annulé');
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        statusLabel = context.tr('Confirmé');
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusLabel = context.tr(p.status);
    }

    String methodLabel;
    IconData methodIcon;
    switch (p.method.toLowerCase()) {
      case 'especes':
      case 'cash':
        methodLabel = context.tr('Espèces');
        methodIcon = Icons.money_rounded;
        break;
      case 'cheque':
      case 'check':
        methodLabel = context.tr('Chèque');
        methodIcon = Icons.account_balance_wallet_rounded;
        break;
      case 'virement':
      case 'bank_transfer':
        methodLabel = context.tr('Virement');
        methodIcon = Icons.account_balance_rounded;
        break;
      case 'carte':
      case 'card':
        methodLabel = context.tr('Carte');
        methodIcon = Icons.credit_card_rounded;
        break;
      case 'traite':
        methodLabel = context.tr('Traite');
        methodIcon = Icons.description_rounded;
        break;
      case 'retenue_source':
        methodLabel = context.tr('Retenue à la source');
        methodIcon = Icons.receipt_long_rounded;
        break;
      default:
        methodLabel = context.tr(p.method);
        methodIcon = Icons.payment_rounded;
    }

    final isSelected = _selectedPaymentIds.contains(p.id);

    return Container(
      color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : (index % 2 == 0 ? AppColors.surface : AppColors.background.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedPaymentIds.add(p.id);
                  } else {
                    _selectedPaymentIds.remove(p.id);
                  }
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: AppColors.textPrimary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(width: 8),
          // Reference + date + document link badge
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.paymentNumber,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatDateTime(p.paymentDate),
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                    if (p.reference != null && p.reference!.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            p.reference!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
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
                  radius: 12,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    (p.contactName ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(p.contactName ?? '—',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
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
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Method badge
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      methodIcon,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        methodLabel,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (PermissionService.instance.canDelete(UserPermissionResources.payments))
                  _TableAction(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.error,
                    tooltip: context.tr('Supprimer'),
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
    final start = total == 0 ? 0 : _page * _rowsPerPage + 1;
    final end = ((_page + 1) * _rowsPerPage).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Rows per page
          Text(context.tr('Lignes'),
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Container(
            height: 28,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
              color: AppColors.surface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textPrimary),
                icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                items: [20, 50, 100].map((n) {
                  return DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(fontSize: 12)));
                }).toList(),
                onChanged: (v) => setState(() {
                  _rowsPerPage = v!;
                  _page = 0;
                }),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Text('${context.tr('Page')} ${_page + 1} ${context.tr('sur')} $totalPages',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text(total == 0 ? '${context.tr('Affichage de')} 0 ${context.tr('à')} 0 ${context.tr('sur')} 0 ${context.tr('résultats')}' : '${context.tr('Affichage de')} $start ${context.tr('à')} $end ${context.tr('sur')} $total ${context.tr('résultats')}',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
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

  // ── Bulk Actions ──────────────────────────────────────────────────
  Widget _buildBulkActionsDropdown() {
    final count = _selectedPaymentIds.length;
    final pdfLabel = count > 1
        ? '${context.tr('Télécharger')} $count documents ( pdf )'
        : context.tr('Télécharger PDF');

    return PopupMenuButton<String>(
      onSelected: (action) => _handleBulkAction(action),
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'pdf',
          child: Text(pdfLabel, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Text(context.tr('Exporter Excel'), style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(context.tr('Supprimer la sélection'), style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('Plus d\'actions'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _handleBulkAction(String action) {
    final state = context.read<PaymentsBloc>().state;
    if (state is! PaymentsLoaded) return;

    final selectedPayments = state.payments.where((p) => _selectedPaymentIds.contains(p.id)).toList();
    if (selectedPayments.isEmpty) return;

    switch (action) {
      case 'pdf':
        _bulkDownloadPdf(selectedPayments);
        break;
      case 'excel':
        _bulkExportExcel(selectedPayments);
        break;
      case 'delete':
        _bulkDeleteSelected(selectedPayments);
        break;
    }
  }

  Future<void> _bulkDownloadPdf(List<Payment> selectedPayments) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Téléchargement de ${selectedPayments.length} document(s) PDF...'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  Future<void> _bulkExportExcel(List<Payment> selectedPayments) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Paiements'];
      excel.setDefaultSheet('Paiements');

      final headers = ['Référence', 'Date', 'Contact', 'Sens', 'Montant', 'Méthode', 'Statut'];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true, fontFamily: getFontFamily(FontFamily.Arial));
      }

      for (var i = 0; i < selectedPayments.length; i++) {
        final p = selectedPayments[i];
        final rowIndex = i + 1;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(p.paymentNumber);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(formatDateTime(p.paymentDate));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(p.contactName ?? '—');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(p.direction == 'encaissement' ? 'Encaissement' : 'Décaissement');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(p.amount);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(p.method);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(p.status);
      }

      final fileBytes = excel.encode();
      if (fileBytes != null && mounted) {
        final fileName = 'Paiements_Selectionnes_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await FileDownloadHelper.saveAndOpenFile(
          Uint8List.fromList(fileBytes),
          fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          context: context,
        );
        setState(() => _selectedPaymentIds.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export Excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _bulkDeleteSelected(List<Payment> selectedPayments) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(context.tr('Suppression groupée')),
          ],
        ),
        content: Text('${context.tr('Voulez-vous vraiment supprimer')} ${selectedPayments.length} ${context.tr('paiement(s) sélectionné(s)')} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.tr('Annuler')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              for (final p in selectedPayments) {
                context.read<PaymentsBloc>().add(DeletePayment(p.id));
              }
              setState(() => _selectedPaymentIds.clear());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${selectedPayments.length} ${context.tr('paiement(s) supprimé(s)')}'),
                backgroundColor: AppColors.success,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('Supprimer')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Payment p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Supprimer le paiement')),
        content: Text(
            '${context.tr('Voulez-vous vraiment supprimer le paiement')} ${p.paymentNumber} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Annuler'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PaymentsBloc>().add(DeletePayment(p.id));
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Supprimer'),
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
  bool _isSaving = false;

  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _contactSearchCtrl = TextEditingController();
  final _issuerCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  late DateTime _paymentDate;
  DateTime? _maturityDate;

  @override
  void initState() {
    super.initState();
    _paymentDate = DateTime.now();

    // Trigger load of treasury accounts
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
  }



  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _contactSearchCtrl.dispose();
    _issuerCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  void _openTraiteEditor() {
    TraiteEditorDialog.show(
      context,
      initialAmount: double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0,
      initialNumber: _referenceCtrl.text,
      initialIssuer: _issuerCtrl.text,
      initialRecipient: 'Notre Société',
      initialCreationDate: _paymentDate,
      initialMaturityDate: _maturityDate,
      onApply: (data) {
        setState(() {
          if (data.documentNumber.isNotEmpty) _referenceCtrl.text = data.documentNumber;
          if (data.amount > 0) _amountCtrl.text = data.amount.toStringAsFixed(3).replaceAll('.', ',');
          if (data.issuerName.isNotEmpty) _issuerCtrl.text = data.issuerName;
          _paymentDate = data.creationDate;
          _maturityDate = data.maturityDate;
        });
      },
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Veuillez sélectionner un contact')),
            backgroundColor: AppColors.error),
      );
      return;
    }

    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Veuillez sélectionner un compte de trésorerie')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = context.read<PaymentsBloc>();
      final now = DateTime.now();

      final isOnline = ConnectivityService.instance.isOnline;
      String paymentNumber;
      bool isDraft = false;

      if (isOnline) {
        try {
          final seq = await DatabaseHelper.instance.getNextPaymentSequence()
              .timeout(const Duration(seconds: 4));
          paymentNumber = _direction == 'encaissement'
              ? generateDocNumber(DocPrefix.paymentIn, seq)
              : generateDocNumber(DocPrefix.paymentOut, seq);
        } catch (_) {
          paymentNumber = OfflineDocumentService.generateDraftNumber();
          isDraft = true;
        }
      } else {
        paymentNumber = OfflineDocumentService.generateDraftNumber();
        isDraft = true;
      }

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
        bankName: _method == 'cheque' && _bankCtrl.text.isNotEmpty ? _bankCtrl.text.trim() : null,
        maturityDate: _maturityDate,
        issuerName: _method == 'traite' && _issuerCtrl.text.isNotEmpty ? _issuerCtrl.text.trim() : null,
        paymentDate: _paymentDate,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
        status: isDraft ? 'pending' : _status,
        createdAt: now,
        updatedAt: now,
      );

      if (isDraft) {
        await OfflineDocumentService.instance.savePendingDocument('payments', payment.toMap());
        db.add(LoadFirstPayments());
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Paiement')} $paymentNumber ${context.tr('enregistré en Brouillon (en attente de sync)')}'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

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
        if (mounted) {
          context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(tx));
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('Paiement')} $paymentNumber ${context.tr('créé avec succès')}'),
          backgroundColor: AppColors.success,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              Text(context.tr('Nouveau paiement'),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text(context.tr('Enregistrer un encaissement ou décaissement'),
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          Spacer(),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded,
                size: 16, color: AppColors.textSecondary),
            label: Text(context.tr('Annuler'),
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.textPrimary, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
            label: Text(
              _isSaving ? context.tr('Enregistrement...') : context.tr('Enregistrer'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        Text(context.tr('Direction du paiement'),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DirectionButton(
                label: context.tr('Encaissement'),
                subtitle: context.tr('Argent entrant'),
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
                label: context.tr('Décaissement'),
                subtitle: context.tr('Argent sortant'),
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
        Text(context.tr('Type de contact'),
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
              items: [
                DropdownMenuItem(value: 'customer', child: Text(context.tr('Client'))),
                DropdownMenuItem(value: 'supplier', child: Text(context.tr('Fournisseur'))),
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
        Text(_selectedContactType == 'supplier' ? '${context.tr('Fournisseur')} *' : '${context.tr('Client')} *',
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
                hint: context.tr('Rechercher un fournisseur...'),
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
                      _issuerCtrl.text = _selectedContactName ?? '';
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
                hint: context.tr('Rechercher un client...'),
                selectedText: displayName,
                onTap: () async {
                  final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedContactId);
                  if (res != null) {
                    final found = customers.firstWhere((c) => c.id == res, orElse: () => Customer(id: '', code: '', name: ''));
                    setState(() {
                      _selectedContactId = res;
                      _selectedContactName = found.companyName?.isNotEmpty == true ? found.companyName! : found.name;
                      _selectedContactType = 'customer';
                      _issuerCtrl.text = _selectedContactName ?? '';
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
        Text('${context.tr('Montant')} *',
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
            if (v == null || v.trim().isEmpty) return context.tr('Montant requis');
            final val =
                double.tryParse(v.replaceAll(',', '.'));
            if (val == null || val <= 0) return context.tr('Veuillez entrer un montant valide');
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
        Text('${context.tr('Méthode')} *',
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
              items: [
                DropdownMenuItem(
                    value: 'especes', child: Text(context.tr('Espèces'))),
                DropdownMenuItem(
                    value: 'cheque', child: Text(context.tr('Chèque'))),
                DropdownMenuItem(
                    value: 'traite', child: Text(context.tr('Traite'))),
                DropdownMenuItem(
                    value: 'virement', child: Text(context.tr('Virement'))),
                DropdownMenuItem(value: 'carte', child: Text(context.tr('Carte'))),
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
        Text(context.tr('Statut'),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        SizedBox(height: 8),
        Row(
          children: [
            _StatusChip(
              label: context.tr('Payé'),
              value: 'paid',
              selected: _status == 'paid',
              color: AppColors.success,
              bg: AppColors.successLight,
              onTap: () => setState(() => _status = 'paid'),
            ),
            SizedBox(width: 8),
            _StatusChip(
              label: context.tr('En attente'),
              value: 'pending',
              selected: _status == 'pending',
              color: AppColors.warning,
              bg: AppColors.warningLight,
              onTap: () => setState(() => _status = 'pending'),
            ),
            SizedBox(width: 8),
            _StatusChip(
              label: context.tr('Annulé'),
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
                    child: Text(context.tr('Détails de la méthode de paiement'),
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
                      Text('${context.tr('Compte de trésorerie')} *',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      SizedBox(height: 6),
                      BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                           builder: (context, tState) {
                          final tAccounts = tState is TreasuryAccountsLoaded
                              ? tState.accounts
                              : <TreasuryAccount>[];

                          final selectedAccount = tAccounts.cast<TreasuryAccount?>().firstWhere(
                            (a) => a?.id == _selectedAccountId,
                            orElse: () => null,
                          );

                          return SearchableSelectorField(
                            hint: context.tr('Sélectionner un compte'),
                            selectedText: selectedAccount != null
                                ? '${selectedAccount.name} (${context.tr('Solde')}: ${formatCurrencyDT(selectedAccount.balance)})'
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
                  if (_method == 'traite') ...[
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Émetteur / Propriétaire de la traite'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        TextFormField(
                          controller: _issuerCtrl,
                          style: TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _selectedContactType == 'supplier' ? 'Fournisseur passager' : 'Client passager',
                            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Numéro de traite'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        TextFormField(
                          controller: _referenceCtrl,
                          style: TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Saisir le numéro de traite',
                            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Date de création de traite'),
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
                            if (picked != null) setState(() => _paymentDate = picked);
                          },
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('d MMMM yyyy', 'fr_FR').format(_paymentDate),
                                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Échéance (facultatif)'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _maturityDate ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _maturityDate = picked);
                          },
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _maturityDate != null
                                        ? DateFormat('d MMMM yyyy', 'fr_FR').format(_maturityDate!)
                                        : 'Sélectionner la date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _maturityDate != null ? AppColors.textPrimary : AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                                if (_maturityDate != null)
                                  GestureDetector(
                                    onTap: () => setState(() => _maturityDate = null),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(Icons.clear, size: 16, color: AppColors.textTertiary),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_method == 'cheque') ...[
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Banque émettrice'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        Autocomplete<String>(
                          initialValue: TextEditingValue(text: _bankCtrl.text),
                          optionsBuilder: (TextEditingValue val) {
                            if (val.text.isEmpty) return AppColors.tunisianBanks;
                            return AppColors.tunisianBanks.where((b) => b.toLowerCase().contains(val.text.toLowerCase()));
                          },
                          onSelected: (String sel) => _bankCtrl.text = sel,
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            controller.addListener(() => _bankCtrl.text = controller.text);
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Saisir la banque émettrice',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                suffixIcon: Icon(Icons.unfold_more, size: 18),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Numéro de chèque'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        TextFormField(
                          controller: _referenceCtrl,
                          style: TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Saisir le numéro de chèque',
                            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Date de paiement'),
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
                            if (picked != null) setState(() => _paymentDate = picked);
                          },
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('d MMMM yyyy', 'fr_FR').format(_paymentDate),
                                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    if (_method != 'especes') ...[
                      SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Référence externe (optionnel)'),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                          SizedBox(height: 6),
                          TextFormField(
                            controller: _referenceCtrl,
                            style: TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: context.tr('Référence de virement, carte...'),
                              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              prefixIcon: Icon(Icons.tag_rounded, size: 18, color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Date de paiement'),
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
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
                                const SizedBox(width: 10),
                                Text(
                                  formatDate(_paymentDate),
                                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
        Text(context.tr('Notes'),
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
            hintText: context.tr('Ajouter des notes sur ce paiement...'),
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
      height: 32,
      child: TextField(
        style: const TextStyle(fontSize: 12),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: AppColors.textTertiary, fontSize: 12),
          prefixIcon:
              Icon(icon, size: 16, color: AppColors.textTertiary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          fillColor: AppColors.surfaceAlt,
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: AppColors.primary, width: 1.5)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: value != 'tous' ? AppColors.primary : AppColors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.containsKey(value) ? value : null,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              items: items.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
