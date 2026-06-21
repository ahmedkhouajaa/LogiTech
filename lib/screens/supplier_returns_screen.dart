import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/supplier_returns/supplier_returns_bloc.dart';
import '../blocs/supplier_returns/supplier_returns_event.dart';
import '../blocs/supplier_returns/supplier_returns_state.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/supplier_return.dart';
import '../models/supplier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_supplier_return_screen.dart';
import '../blocs/payments/payments_bloc.dart';
import '../models/payment_model.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../models/invoice.dart';
import 'create_invoice_screen.dart';

enum SupplierReturnStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Validé', AppColors.success),
  canceled('Annulé', AppColors.error);

  final String label;
  final Color color;
  const SupplierReturnStatus(this.label, this.color);
}

class SupplierReturnsScreen extends StatefulWidget {
  const SupplierReturnsScreen({super.key});

  @override
  State<SupplierReturnsScreen> createState() => _SupplierReturnsScreenState();
}

class _SupplierReturnsScreenState extends State<SupplierReturnsScreen> {
  String? _selectedFournisseurId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  SupplierReturnStatus? _statusFilter;

  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<SupplierReturnsBloc>().add(LoadSupplierReturns());
    context.read<SuppliersBloc>().add(LoadSuppliers());
  }

  void _applyFilters() {
    context.read<SupplierReturnsBloc>().add(FilterSupplierReturns(
      FournisseurId: _selectedFournisseurId,
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
        // Ã¢a€€Ã¢a€€ Header Ã¢a€€Ã¢a€€
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
                        'Bon de retour',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.play_circle_fill, color: Colors.red[600], size: 24),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gerer vos Bons de retour fournisseur',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _navigate(context, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Creer un Bon de retour'),
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

        // Ã¢a€€Ã¢a€€ Filter Bar Ã¢a€€Ã¢a€€
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _buildFilterBar(),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Ã¢a€€Ã¢a€€ Table Ã¢a€€Ã¢a€€
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

  void _navigate(BuildContext context, SupplierReturn? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<SupplierReturnsBloc>()),
            BlocProvider.value(value: context.read<SuppliersBloc>()),
            BlocProvider.value(value: context.read<ProductsBloc>()),
            BlocProvider.value(value: context.read<ProjectsBloc>()),
          ],
          child: CreateSupplierReturnScreen(existing: existing),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Fournisseur dropdown
          Expanded(
            flex: 3,
            child: _filterSection(
              label: 'Fournisseur',
              child: BlocBuilder<SuppliersBloc, SuppliersState>(
                builder: (context, state) {
                  List<Supplier> Suppliers = [];
                  if (state is SuppliersLoaded) Suppliers = state.suppliers;
                  return _dropdownField(
                    hint: 'Selectionner un Fournisseur...',
                    value: _selectedFournisseurId,
                    items: [
                      const DropdownMenuItem(
                          value: 'all',
                          child: Text('Tous les Fournisseurs',
                              style: TextStyle(color: AppColors.textSecondary))),
                      ...Suppliers.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name ?? c.name ?? 'Inconnu'))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedFournisseurId = val);
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
                  ...SupplierReturnStatus.values.map((s) =>
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
                  _selectedFournisseurId = null;
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
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary)),
        isDense: true,
      ),
      icon: const Icon(Icons.expand_more, size: 16),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      items: items,
      onChanged: onChanged,
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
    return BlocBuilder<SupplierReturnsBloc, SupplierReturnsState>(
      builder: (context, state) {
        if (state is SupplierReturnsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is SupplierReturnsError) {
          return Center(
              child: Text(state.message,
                  style: const TextStyle(color: AppColors.error)));
        }
        if (state is SupplierReturnsLoaded) {
          final notes = state.returns;
          final total = notes.length;
          final totalPages = total == 0 ? 1 : ((total / _rowsPerPage).ceil().toInt());
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
                                  child: Text('Fournisseur',
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
                                      Text('Aucun Bon de retour trouve',
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
                                    : 'Affichage de ${start + 1} a  $end sur $total resultats',
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

  Widget _buildRow(BuildContext context, SupplierReturn note, int index) {
    final statusEnum = SupplierReturnStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => SupplierReturnStatus.draft,
    );
    final FournisseurLabel =
        note.supplierName ?? note.supplierName ?? 'Fournisseur inconnu';
    final isDraft = statusEnum == SupplierReturnStatus.draft;

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

          // Fournisseur
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(FournisseurLabel,
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
                itemBuilder: (_) => [
                  _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Telecharger PDF'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gerer les pieces jointes'),
                ],
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

  void _confirmDelete(SupplierReturn note) {
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
                  .read<SupplierReturnsBloc>()
                  .add(DeleteSupplierReturn(note.id));
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
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, SupplierReturn note) {
    switch (action) {
      case 'view':
        // TODO: View delivery note details
        break;
      case 'edit':
        _navigate(context, note);
        break;
      case 'print':
        // TODO: Print logic
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impression non implementee')));
        break;
      case 'add_payment':
        _showAddPaymentDialog(context, note);
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

  void _showChangeStatusDialog(BuildContext context, SupplierReturn note) {
    SupplierReturnStatus selectedStatus = SupplierReturnStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => SupplierReturnStatus.draft,
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
                  DropdownButtonFormField<SupplierReturnStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: SupplierReturnStatus.values.map((s) => DropdownMenuItem(
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
                  context.read<SupplierReturnsBloc>().add(
                    UpdateSupplierReturn(note.copyWith(status: selectedStatus.name))
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

  void _showAddPaymentDialog(BuildContext context, SupplierReturn note) {
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
                  contactId: note.supplierId,
                  contactType: 'Supplier',
                  contactName: note.supplierName ?? note.supplierName,
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
}

