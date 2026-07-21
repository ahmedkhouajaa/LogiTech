import 'package:flutter/material.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../widgets/delivery_note_payment_dialog.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/delivery_note.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_delivery_note_screen.dart';
import '../blocs/payments/payments_bloc.dart';
import '../models/payment_model.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../blocs/return_notes/return_notes_bloc.dart';
import '../blocs/return_notes/return_notes_event.dart';
import '../models/invoice.dart';
import '../models/return_note.dart';
import 'create_invoice_screen.dart';
import 'create_return_note_screen.dart';
import '../services/pdf_service.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';

class DeliveryNotesScreen extends StatefulWidget {
  const DeliveryNotesScreen({super.key});

  @override
  State<DeliveryNotesScreen> createState() => _DeliveryNotesScreenState();
}

class _DeliveryNotesScreenState extends State<DeliveryNotesScreen> {
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  DeliveryNoteStatus? _statusFilter;

  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<DeliveryNotesBloc>().add(LoadDeliveryNotes());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  void _applyFilters() {
    context.read<DeliveryNotesBloc>().add(FilterDeliveryNotes(
      clientId: _selectedClientId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter?.name,
    ));
    setState(() => _currentPage = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Bon de Livraison',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                     
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gerer vos bons de livraison',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _navigate(context, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Creer un Bon de Livraison'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ),

        // ── Filter Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: BlocBuilder<DeliveryNotesBloc, DeliveryNotesState>(
            builder: (context, state) {
              return _buildFilterBar(state);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Table ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildTable(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _navigate(BuildContext context, DeliveryNote? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
            BlocProvider.value(value: context.read<CustomersBloc>()),
            BlocProvider.value(value: context.read<ProductsBloc>()),
            BlocProvider.value(value: context.read<ProjectsBloc>()),
          ],
          child: CreateDeliveryNoteScreen(existing: existing),
        ),
      ),
    );
  }

  Widget _buildFilterBar(DeliveryNotesState state) {
    int totalItems = 0;
    if (state is DeliveryNotesLoaded) {
      List<DeliveryNote> filteredOrders = state.notes;
      if (_selectedClientId != null && _selectedClientId != 'all') {
        filteredOrders = filteredOrders.where((q) => q.customerId == _selectedClientId).toList();
      }
      if (_dateFrom != null) {
        filteredOrders = filteredOrders.where((q) => q.date.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
      }
      if (_dateTo != null) {
        filteredOrders = filteredOrders.where((q) => q.date.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
      }
      if (_statusFilter != null) {
        filteredOrders = filteredOrders.where((q) => q.status == _statusFilter!.name).toList();
      }
      totalItems = filteredOrders.length;
    }

    final activeFilterCount = (_selectedClientId != null && _selectedClientId != 'all' ? 1 : 0) +
        (_dateFrom != null ? 1 : 0) +
        (_dateTo != null ? 1 : 0) +
        (_statusFilter != null ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Client dropdown
          Expanded(
            flex: 3,
            child: _filterSection(
              label: 'Client',
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  List<Customer> customers = [];
                  if (state is CustomersLoaded) customers = state.customers;
                  return _dropdownField(
                    hint: 'Selectionner un client...',
                    value: _selectedClientId,
                    items: [
                      const DropdownMenuItem(
                          value: 'all',
                          child: Text('Tous les clients',
                              style: TextStyle(color: AppColors.textSecondary))),
                      ...customers.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.companyName ?? c.responsibleName ?? 'Inconnu'))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedClientId = val);
                      _applyFilters();
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Date From
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Date de debut',
              child: _datePicker(
                value: _dateFrom,
                hint: 'Selectionner une date',
                onPicked: (d) {
                  setState(() => _dateFrom = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Date To
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Date de fin',
              child: _datePicker(
                value: _dateTo,
                hint: 'Selectionner une date',
                onPicked: (d) {
                  setState(() => _dateTo = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Status
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Statut',
              child: _dropdownField(
                hint: 'Tous',
                value: _statusFilter,
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('Tous', style: TextStyle(color: AppColors.textPrimary))),
                  ...DeliveryNoteStatus.values.map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.label))),
                ],
                onChanged: (val) {
                  setState(() => _statusFilter = val);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Reset button
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _selectedClientId = null;
                  _dateFrom = null;
                  _dateTo = null;
                  _statusFilter = null;
                });
                _applyFilters();
              },
            ),
          ),
        ],
      ),
      if (activeFilterCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$totalItems résultat${totalItems > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedClientId = null;
                    _dateFrom = null;
                    _dateTo = null;
                    _statusFilter = null;
                    _currentPage = 0;
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Réinitialiser les filtres'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _filterSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        SizedBox(height: 40, child: child),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePicker({
    required DateTime? value,
    required String hint,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: const Locale('fr', 'FR'),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? formatDateLong(value) : hint,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? AppColors.textPrimary : AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    return BlocBuilder<DeliveryNotesBloc, DeliveryNotesState>(
      builder: (context, state) {
        if (state is DeliveryNotesLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DeliveryNotesError) {
          return Center(
              child: Text(state.message,
                  style: const TextStyle(color: AppColors.error)));
        }
        if (state is DeliveryNotesLoaded) {
          final notes = state.notes;
          final total = notes.length;
          final totalPages = total == 0 ? 1 : (total / _rowsPerPage).ceil();
          final page = _currentPage.clamp(0, totalPages - 1);
          final start = page * _rowsPerPage;
          final end = (start + _rowsPerPage).clamp(0, total);
          final pageNotes = notes.sublist(start, end);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Column(
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            border:
                                Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 32),
                              const Expanded(
                                  flex: 2,
                                  child: Text('Reference',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              const Expanded(
                                  flex: 3,
                                  child: Text('Client',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              const Expanded(
                                  flex: 2,
                                  child: Text('Statut',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              const Expanded(
                                  flex: 2,
                                  child: Text('Montant',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              const SizedBox(
                                  width: 80,
                                  child: Text('Actions',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                            ],
                          ),
                        ),

                        // Body
                        Expanded(
                          child: pageNotes.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.local_shipping_outlined,
                                          size: 48, color: AppColors.border),
                                      SizedBox(height: 16),
                                      Text('Aucun bon de livraison trouve',
                                          style: TextStyle(
                                              color: AppColors.textSecondary)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: pageNotes.length,
                                  separatorBuilder: (_, __) => const Divider(
                                      height: 1, color: AppColors.border),
                                  itemBuilder: (context, i) =>
                                      _buildRow(context, pageNotes[i], i),
                                ),
                        ),

                        // Pagination footer
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            border:
                                Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              const Text('Lignes',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Container(
                                height: 32,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down,
                                      size: 16),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary),
                                  items: [10, 20, 50, 100]
                                      .map((v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(v.toString())))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _rowsPerPage = v;
                                        _currentPage = 0;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Text('Page ${page + 1} sur $totalPages',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                total == 0
                                    ? 'Affichage de 0 a 0 sur 0 resultats'
                                    : 'Affichage de ${start + 1} a $end sur $total resultats',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              _pageButton(
                                icon: Icons.chevron_left,
                                enabled: page > 0,
                                onTap: () =>
                                    setState(() => _currentPage = page - 1),
                              ),
                              const SizedBox(width: 8),
                              _pageButton(
                                icon: Icons.chevron_right,
                                enabled: page < totalPages - 1,
                                onTap: () =>
                                    setState(() => _currentPage = page + 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildRow(BuildContext context, DeliveryNote note, int index) {
    final statusEnum = DeliveryNoteStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => DeliveryNoteStatus.draft,
    );
    final clientLabel =
        note.customerCompany ?? note.customerName ?? 'Client inconnu';
    final isDraft = statusEnum == DeliveryNoteStatus.draft;

    return Container(
      color: index % 2 == 0
          ? AppColors.surface
          : AppColors.background.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: false,
              onChanged: (_) {},
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
          ),

          // Reference
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.number,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(formatDateTimeLong(note.date),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),

          // Client
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(clientLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),

          // Statut badge
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusEnum.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusEnum.label,
                  style: TextStyle(
                      color: statusEnum.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),

          // Montant
          Expanded(
            flex: 2,
            child: Text(
              formatCurrencyDT(note.totalTTC),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDraft ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz,
                    color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) => _handleAction(context, val, note),
                itemBuilder: (_) {
                  final items = <PopupMenuEntry<String>>[
                    _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
                    const PopupMenuDivider(height: 1),
                  ];

                  if (note.isConvertedToInvoice) {
                    items.add(_buildMenuItem('view_invoice', Icons.receipt_long_outlined, AppColors.success, 'Voir la facture creee'));
                  } else if (note.isConvertedToReturn) {
                    items.add(_buildMenuItem('view_return', Icons.assignment_return_outlined, AppColors.success, 'Voir le bon de retour cree'));
                  } else {
                    if (note.status != 'paid') {
                      items.add(_buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'));
                      items.add(const PopupMenuDivider(height: 1));
                    }
                    items.add(_buildMenuItem('to_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Facture'));
                    items.add(const PopupMenuDivider(height: 1));
                    items.add(_buildMenuItem('to_return', Icons.assignment_return_outlined, AppColors.textSecondary, 'Transformer en Bon de Retour'));
                  }

                  items.addAll([
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Telecharger PDF'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
//                     const PopupMenuDivider(height: 1),
//                     _buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'),
//                     const PopupMenuDivider(height: 1),
//                     _buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gerer les pieces jointes'),
                  ]);
                  
                  return items;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageButton(
      {required IconData icon,
      required bool enabled,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
              color: enabled
                  ? AppColors.border
                  : AppColors.border.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
          color: AppColors.surface,
        ),
        child: Icon(icon,
            size: 20,
            color: enabled
                ? AppColors.textPrimary
                : AppColors.textTertiary),
      ),
    );
  }

  void _confirmDelete(DeliveryNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
            'Voulez-vous vraiment supprimer le bon ${note.number} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<DeliveryNotesBloc>()
                  .add(DeleteDeliveryNote(note.id));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color iconColor, String text) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, DeliveryNote note) {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(
              document: DocumentWrapper.fromDeliveryNote(note),
            ),
          ),
        );
        break;
      case 'edit':
        _navigate(context, note);
        break;
      case 'duplicate':
        // TODO: Duplicate logic
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromDeliveryNote(note);
        PdfService.instance.downloadDocument(context, doc);
        break;
            case 'print':
        final doc = DocumentWrapper.fromDeliveryNote(note);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;
      case 'to_invoice':
        _showInvoiceConversionDialog(context, note);
        break;
      case 'view_invoice':
        _openConvertedInvoice(context, note.convertedToInvoiceId);
        break;
      case 'to_return':
        _showReturnConversionDialog(context, note);
        break;
      case 'view_return':
        _openConvertedReturn(context, note.convertedToReturnId);
        break;
      case 'add_payment':
        showDialog(
          context: context,
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<PaymentsBloc>()),
              BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
              BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
              BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
            ],
            child: DeliveryNotePaymentDialog(deliveryNote: note),
          ),
        ).then((created) {
          if (created == true && context.mounted) {
            context.read<DeliveryNotesBloc>().add(LoadDeliveryNotes());
          }
        });
        break;
      case 'delete':
        _confirmDelete(note);
        break;
      case 'status':
        _showChangeStatusDialog(context, note);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implementee')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, DeliveryNote note) {
    DeliveryNoteStatus selectedStatus = DeliveryNoteStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => DeliveryNoteStatus.draft,
    );
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Changer le statut'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nouveau statut:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<DeliveryNoteStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: DeliveryNoteStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.label, style: TextStyle(color: s.color, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => selectedStatus = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Notes (optionnel):'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ajouter une note...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<DeliveryNotesBloc>().add(
                    UpdateDeliveryNote(note.copyWith(status: selectedStatus.name))
                  );
                  Navigator.pop(dialogCtx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, DeliveryNote note) {
    final amountCtrl = TextEditingController(text: note.totalTTC.toStringAsFixed(3));
    final methodNotifier = ValueNotifier<String>('especes');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter un paiement pour BL ${note.number}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Montant (DT)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: methodNotifier,
              builder: (context, val, child) => DropdownButtonFormField<String>(
                value: val,
                decoration: const InputDecoration(
                  labelText: 'Methode de paiement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'especes', child: Text('Especes')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'virement', child: Text('Virement')),
                  DropdownMenuItem(value: 'carte', child: Text('Carte')),
                ],
                onChanged: (v) {
                  if (v != null) methodNotifier.value = v;
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final amountStr = amountCtrl.text.replaceAll(',', '.');
              final amount = double.tryParse(amountStr) ?? 0.0;
              if (amount > 0) {
                final payment = Payment(
                  id: const Uuid().v4(),
                  paymentNumber: 'PAI-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 1000000}',
                  direction: 'encaissement',
                  contactId: note.customerId,
                  contactType: 'customer',
                  contactName: note.customerName ?? note.customerCompany,
                  amount: amount,
                  method: methodNotifier.value,
                  reference: note.number,
                  paymentDate: DateTime.now(),
                  status: 'paid',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                
                try {
                  context.read<PaymentsBloc>().add(AddPayment(payment));
                } catch (e) {
                  await DatabaseHelper.instance.insertPayment(payment);
                }
                
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Paiement ajoute avec succes'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Veuillez entrer un montant valide'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showInvoiceConversionDialog(BuildContext context, DeliveryNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Confirmation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voulez-vous transformer ce bon de livraison en facture ?'),
            const SizedBox(height: 16),
            Text('BL: ${note.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${note.customerName ?? note.customerCompany ?? "Inconnu"}'),
            Text('Montant: ${formatCurrencyDT(note.totalTTC)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _convertDeliveryToInvoice(context, note);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _convertDeliveryToInvoice(BuildContext context, DeliveryNote note) {
    final now = DateTime.now();
    final year = now.year;
    final seq = now.millisecondsSinceEpoch % 100000;
    final invoiceNumber = 'FAC-$year-${seq.toString().padLeft(5, '0')}';

    final invoiceItems = note.items.map((i) => InvoiceItem(
      id: const Uuid().v4(),
      invoiceId: '', // Will be set in Invoice constructor/DB
      productId: i.productId,
      description: i.description,
      quantity: i.quantity,
      unitPrice: i.unitPrice,
      tvaRate: i.tvaRate,
      discountPercent: i.discountPercent,
      totalHT: i.totalHT,
      showDescription: i.showDescription,
      showDiscount: i.showDiscount,
    )).toList();

    final newInvoice = Invoice(
      id: const Uuid().v4(),
      number: invoiceNumber,
      customerId: note.customerId,
      customerName: note.customerName,
      orderId: note.orderId,
      deliveryNoteId: note.id,
      projectId: note.projectId,
      projectName: note.projectName,
      date: now,
      dueDate: now.add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid,
      totalHT: note.totalHTAfterDiscount,
      totalTva: note.totalTVA,
      totalTTC: note.totalTTC,
      pricingMode: note.pricingMode,
      globalDiscountPercent: note.globalDiscountPercent,
      globalDiscountAmount: note.globalDiscountAmount,
      timbreFiscal: note.timbreFiscal,
      notes: note.notes,
      conditionsGenerales: note.conditionsGenerales,
      items: invoiceItems,
    );

    context.read<InvoicesBloc>().add(AddInvoice(newInvoice));

    final updatedNote = note.copyWith(
      isConvertedToInvoice: true,
      convertedToInvoiceId: newInvoice.id,
      status: DeliveryNoteStatus.invoiced.name,
    );
    context.read<DeliveryNotesBloc>().add(UpdateDeliveryNote(updatedNote));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Facture $invoiceNumber creee avec succes'),
      backgroundColor: AppColors.success,
    ));
  }

  void _showReturnConversionDialog(BuildContext context, DeliveryNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Confirmation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voulez-vous transformer ce bon de livraison en bon de retour ?'),
            const SizedBox(height: 16),
            Text('BL: ${note.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${note.customerName ?? note.customerCompany ?? "Inconnu"}'),
            Text('Montant: ${formatCurrencyDT(note.totalTTC)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _convertDeliveryToReturn(context, note);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _convertDeliveryToReturn(BuildContext context, DeliveryNote note) async {
    final now = DateTime.now();
    final year = now.year;
    
    // Get next return number sequence
    final seq = await DatabaseHelper.instance.getNextReturnNoteSequence();
    final returnNumber = 'RET-$year-${seq.toString().padLeft(5, '0')}';

    final returnItems = note.items.map((i) => ReturnNoteItem(
      id: const Uuid().v4(),
      returnNoteId: '', // Will be set in DB when saving if needed, but the model doesn't strictly enforce it for items if generated
      productId: i.productId,
      designation: i.description ?? '',
      quantity: -i.quantity, // Negative for returns
      unitPrice: i.unitPrice,
      tvaRate: i.tvaRate,
      totalHT: -i.totalHT, // Negative for returns
    )).toList();

    final newReturn = ReturnNote(
      id: const Uuid().v4(),
      returnNumber: returnNumber,
      customerId: note.customerId,
      customerName: note.customerName,
      customerCompany: note.customerCompany,
      deliveryNoteId: note.id,
      dateEmission: now,
      status: ReturnNoteStatus.validated.name,
      subtotalHT: -note.subTotalHT,
      totalTTC: -note.totalTTC,
      notes: note.notes,
      conditions: note.conditionsGenerales,
      items: returnItems,
    );

    for (var item in newReturn.items) {
      // Re-assign return note ID properly
      // Using copyWith is not possible if it doesn't exist, we can use a small hack or just re-map
    }
    
    final finalItems = returnItems.map((i) => i.copyWith(returnNoteId: newReturn.id)).toList();
    final returnWithItems = newReturn.copyWith(items: finalItems);

    if (!context.mounted) return;
    context.read<ReturnNotesBloc>().add(AddReturnNote(returnWithItems));

    final updatedNote = note.copyWith(
      isConvertedToReturn: true,
      convertedToReturnId: returnWithItems.id,
      status: DeliveryNoteStatus.returned.name,
    );
    context.read<DeliveryNotesBloc>().add(UpdateDeliveryNote(updatedNote));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Bon de retour $returnNumber cree avec succes'),
      backgroundColor: AppColors.success,
    ));
  }

  Future<void> _openConvertedReturn(BuildContext context, String? returnId) async {
    if (returnId == null) return;
    
    final returnNote = await DatabaseHelper.instance.getReturnNote(returnId);
    if (!context.mounted) return;
    if (returnNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bon de retour introuvable'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<ReturnNotesBloc>()),
              BlocProvider.value(value: context.read<CustomersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
              BlocProvider.value(value: context.read<ProjectsBloc>()),
            ],
            child: CreateReturnNoteScreen(existing: returnNote),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible d\'ouvrir le bon de retour'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _openConvertedInvoice(BuildContext context, String? invoiceId) async {
    if (invoiceId == null) return;
    
    final invoice = await DatabaseHelper.instance.getInvoice(invoiceId);
    if (!context.mounted) return;
    if (invoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Facture introuvable'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<InvoicesBloc>()),
              BlocProvider.value(value: context.read<CustomersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
              BlocProvider.value(value: context.read<ProjectsBloc>()),
            ],
            child: CreateInvoiceScreen(existing: invoice),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible d\'ouvrir la facture'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}
