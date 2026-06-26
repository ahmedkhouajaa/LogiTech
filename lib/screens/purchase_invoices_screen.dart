import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/purchase_invoice.dart';
import '../models/supplier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/purchase_invoice_payment_dialog.dart';
import '../blocs/payments/payments_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import '../models/supplier_credit_note.dart';
import 'create_purchase_invoice_screen.dart';
import '../services/pdf_service.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';

class PurchaseInvoicesScreen extends StatefulWidget {
  const PurchaseInvoicesScreen({super.key});
  @override
  State<PurchaseInvoicesScreen> createState() => _PurchaseInvoicesScreenState();
}

class _PurchaseInvoicesScreenState extends State<PurchaseInvoicesScreen> {
  // Filter state
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  InvoiceStatus? _statusFilter;

  // Pagination state
  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
    context.read<SuppliersBloc>().add(LoadSuppliers());
  }

  void _applyFilters() {
    context.read<PurchaseInvoicesBloc>().add(FilterPurchaseInvoices(
      clientId: _selectedClientId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and button
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Text('Gerer vos factures', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const Spacer(),
              AppButton(
                label: 'Nouvelle facture',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: context.read<PurchaseInvoicesBloc>()),
                        BlocProvider.value(value: context.read<SuppliersBloc>()),
                        BlocProvider.value(value: context.read<ProductsBloc>()),
                        BlocProvider.value(value: context.read<ProjectsBloc>()),
                      ],
                      child: const CreatePurchaseInvoiceScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _buildFilterBar(),
        ),
        const SizedBox(height: AppSpacing.md),
        // Data table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildPurchaseInvoiceTable(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          // Supplier filter
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: 'Fournisseur',
              child: BlocBuilder<SuppliersBloc, SuppliersState>(
                builder: (context, state) {
                  final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                  return DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    isExpanded: true,
                    hint: const Text('Selectionner un fournisseur...', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Tous les fournisseurs', style: TextStyle(fontSize: 13))),
                      ...suppliers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedClientId = v);
                      _applyFilters();
                    },
                    decoration: _filterInputDecoration(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date de debut
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: 'Date de debut',
              child: _buildDateFilterField(
                value: _dateFrom,
                hint: 'Selectionner une date',
                onChanged: (d) {
                  setState(() => _dateFrom = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date de fin
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: 'Date de fin',
              child: _buildDateFilterField(
                value: _dateTo,
                hint: 'Selectionner une date',
                onChanged: (d) {
                  setState(() => _dateTo = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Status filter
          SizedBox(
            width: 150,
            child: _buildFilterField(
              label: 'Statut',
              child: DropdownButtonFormField<InvoiceStatus?>(
                value: _statusFilter,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<InvoiceStatus?>(value: null, child: Text('Tous', style: TextStyle(fontSize: 13))),
                  ...InvoiceStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 13)))),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _applyFilters();
                },
                decoration: _filterInputDecoration(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter icon button
          Container(
            margin: const EdgeInsets.only(top: 18),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
              onPressed: () {
                setState(() {
                  _selectedClientId = null;
                  _dateFrom = null;
                  _dateTo = null;
                  _statusFilter = null;
                  _currentPage = 0;
                });
                context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
              },
              tooltip: 'Reinitialiser les filtres',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDateFilterField({
    DateTime? value,
    required String hint,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('fr', 'FR'),
        );
        onChanged(picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: value != null ? formatDateLong(value) : ''),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  InputDecoration _filterInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  Widget _buildPurchaseInvoiceTable() {
    return BlocBuilder<PurchaseInvoicesBloc, PurchaseInvoicesState>(
      builder: (context, state) {
        if (state is PurchaseInvoicesLoading) return const Center(child: CircularProgressIndicator());
        if (state is PurchaseInvoicesError) return Center(child: Text('Erreur: ${state.message}'));
        if (state is PurchaseInvoicesLoaded) {
          final purchaseInvoices = state.filteredPurchaseInvoices;
          final totalRows = purchaseInvoices.length;
          final int totalPages = (totalRows / _rowsPerPage).ceil().clamp(1, 9999).toInt();
          _currentPage = _currentPage.clamp(0, totalPages - 1);
          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
          final pagePurchaseInvoices = totalRows > 0 ? purchaseInvoices.sublist(startIndex, endIndex) : <PurchaseInvoice>[];

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              children: [
                // Table
                Expanded(
                  child: pagePurchaseInvoices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              const Text('Aucune facture trouvee', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.resolveWith((_) => const Color(0xFFF8FAFC)),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                              dataTextStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              dividerThickness: 0.5,
                              columnSpacing: 24,
                              horizontalMargin: 16,
                              columns: const [
                                DataColumn(label: SizedBox(width: 20)),
                                DataColumn(label: Text('Reference')),
                                DataColumn(label: Text('Client')),
                                DataColumn(label: Text('Statut')),
                                DataColumn(label: Text('Montant')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: pagePurchaseInvoices.map((inv) => _buildPurchaseInvoiceRow(inv)).toList(),
                            ),
                          ),
                        ),
                ),
                // Pagination
                _buildPaginationBar(totalRows, totalPages),
              ],
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  DataRow _buildPurchaseInvoiceRow(PurchaseInvoice inv) {
    return DataRow(
      cells: [
        // Checkbox
        DataCell(
          Checkbox(
            value: false,
            onChanged: (_) {},
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
        ),
        // Reference (number + date)
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                formatDateTimeLong(inv.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        // Client (icon + name + company)
        DataCell(
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(inv.supplierName ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
                    Text(inv.supplierName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Statut badge
        DataCell(StatusBadge(label: inv.status.label, color: inv.status.color)),
        // Montant
        DataCell(
          Text(
            formatCurrencyDT(inv.totalTTC + inv.timbreFiscal),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: inv.status == InvoiceStatus.unpaid || inv.status == InvoiceStatus.overdue
                  ? AppColors.warning
                  : AppColors.textPrimary,
            ),
          ),
        ),
        // Actions (three dots menu)
        DataCell(
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            offset: const Offset(0, 30),
            onSelected: (val) => _handleAction(context, val, inv),
            itemBuilder: (_) => [
              _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
              const PopupMenuDivider(height: 1),
              _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
              const PopupMenuDivider(height: 1),
              _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
              const PopupMenuDivider(height: 1),
              _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
              const PopupMenuDivider(height: 1),
              if (inv.status != InvoiceStatus.paid) ...[
                _buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'),
                const PopupMenuDivider(height: 1),
              ],
              if (inv.creditNoteId != null && inv.creditNoteId!.isNotEmpty)
                _buildMenuItem('view_credit_note', Icons.receipt_long_outlined, AppColors.primary, 'Voir l\'avoir')
              else
                _buildMenuItem('to_credit_note', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Avoir'),
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
      ],
    );
  }

  Widget _buildPaginationBar(int totalRows, int totalPages) {
    final startRow = totalRows > 0 ? (_currentPage * _rowsPerPage) + 1 : 0;
    final endRow = ((_currentPage + 1) * _rowsPerPage).clamp(0, totalRows);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Rows per page
          const Text('Lignes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: DropdownButton<int>(
              value: _rowsPerPage,
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              items: [10, 20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
              onChanged: (v) => setState(() {
                _rowsPerPage = v ?? 20;
                _currentPage = 0;
              }),
            ),
          ),
          const SizedBox(width: 24),
          // Page info
          Text('Page ${_currentPage + 1} sur $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: 24),
          // Display info
          Text(
            'Affichage de $startRow a $endRow sur $totalRows resultats',
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const Spacer(),
          // Navigation buttons
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  void _confirmDelete(PurchaseInvoice inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer la facture ${inv.number} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PurchaseInvoicesBloc>().add(DeletePurchaseInvoice(inv.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _createCreditNoteFromPurchaseInvoice(BuildContext context, PurchaseInvoice inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            const Text('Voulez-vous transformer cette facture en avoir ?'),
            const SizedBox(height: 16),
            Text('Facture: ${inv.number}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Client: ${inv.supplierName}'),
            Text('Montant: ${formatCurrencyDT(inv.totalTTC + inv.timbreFiscal)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog

              final now = DateTime.now();
              final String cnId = Uuid().v4();

              final String cnNumber = 'AVF-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0');
              
              final creditNote = SupplierCreditNote(
                id: cnId,
                number: cnNumber,
                supplierId: inv.supplierId,
                date: now,
                status: 'Brouillon',
                items: inv.items.map((i) => SupplierCreditNoteItem(
                  id: const Uuid().v4(),
                  supplierCreditNoteId: cnId,
                  productId: i.productId,
                  
                  quantity: i.quantity,
                  unitPrice: i.unitPrice,
                  tvaRate: i.tvaRate,
                  totalHT: i.totalHT,
                )).toList(),
                createdAt: now,
                updatedAt: now,
              );

              // Create the credit note
              context.read<SupplierCreditNotesBloc>().add(AddSupplierCreditNote(creditNote));
              
              // Update the purchaseInvoice to link it
              final updatedPurchaseInvoice = inv.copyWith(creditNoteId: cnId);
              context.read<PurchaseInvoicesBloc>().add(UpdatePurchaseInvoice(updatedPurchaseInvoice));
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Avoir fournisseur $cnNumber créé avec succès'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value, IconData icon, Color iconColor, String text) {
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

  void _handleAction(BuildContext context, String action, PurchaseInvoice inv) {
    switch (action) {
      case 'view':
        // TODO: View details
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<PurchaseInvoicesBloc>()),
                BlocProvider.value(value: context.read<SuppliersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
                BlocProvider.value(value: context.read<ProjectsBloc>()),
              ],
              child: CreatePurchaseInvoiceScreen(existing: inv),
            ),
          ),
        );
        break;
            case 'print':
        final doc = DocumentWrapper.fromPurchaseInvoice(inv);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;
      case 'add_payment':
        showDialog(
          context: context,
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<PaymentsBloc>()),
              BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
              BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
              BlocProvider.value(value: context.read<PurchaseInvoicesBloc>()),
            ],
              child: PurchaseInvoicePaymentDialog(purchaseInvoice: inv),
          ),
        ).then((created) {
          if (created == true && context.mounted) {
            context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
          }
        });
        break;
      case 'to_credit_note':
        _createCreditNoteFromPurchaseInvoice(context, inv);
        break;
      case 'view_credit_note':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Affichage de l\'avoir non implementé')));
        break;
      case 'delete':
        _confirmDelete(inv);
        break;
      case 'status':
        _showChangeStatusDialog(context, inv);
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromPurchaseInvoice(inv);
        PdfService.instance.generateAndOpenDocument(doc);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implementee')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, PurchaseInvoice inv) {
    InvoiceStatus selectedStatus = inv.status;
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
                  DropdownButtonFormField<InvoiceStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: InvoiceStatus.values.map((s) => DropdownMenuItem(
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
                  context.read<PurchaseInvoicesBloc>().add(
                    UpdatePurchaseInvoice(inv.copyWith(status: selectedStatus))
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
}
