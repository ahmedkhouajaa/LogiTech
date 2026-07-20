import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/credit_notes/credit_notes_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../models/credit_note.dart';
import '../models/customer.dart';
import '../models/document_wrapper.dart';
import '../services/pdf_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import 'document_preview_screen.dart';

class CreditNotesScreen extends StatefulWidget {
  const CreditNotesScreen({super.key});

  @override
  State<CreditNotesScreen> createState() => _CreditNotesScreenState();
}

class _CreditNotesScreenState extends State<CreditNotesScreen> {
  // Filter state
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  CreditNoteStatus? _statusFilter;

  // Pagination state
  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<CreditNotesBloc>().add(LoadCreditNotes());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
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
                        'Avoirs Client',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Gerer vos avoirs', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              AppButton(
                label: 'Nouvel Avoir',
                icon: Icons.add_rounded,
                onPressed: () {
                  // TODO: Navigate to create credit note screen
                },
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
        const SizedBox(height: AppSpacing.lg),
        // Table
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
          // Client
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: BlocBuilder<CustomersBloc, CustomersState>(
                    builder: (context, state) {
                      List<Customer> customers = [];
                      if (state is CustomersLoaded) {
                        customers = state.customers;
                      }
                      return Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClientId,
                            hint: const Text('Selectionner un client...', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('Tous les clients', style: TextStyle(color: AppColors.textSecondary))),
                              ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.companyName ?? c.responsibleName ?? 'Inconnu'))),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedClientId = val);
                              _applyFilters();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Date From
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Date de debut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateFrom ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (date != null) {
                      setState(() => _dateFrom = date);
                      _applyFilters();
                    }
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
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateFrom != null ? formatDateLong(_dateFrom!) : 'Selectionner une date',
                            style: TextStyle(fontSize: 13, color: _dateFrom != null ? AppColors.textPrimary : AppColors.textTertiary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Date To
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Date de fin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateTo ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (date != null) {
                      setState(() => _dateTo = date);
                      _applyFilters();
                    }
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
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateTo != null ? formatDateLong(_dateTo!) : 'Selectionner une date',
                            style: TextStyle(fontSize: 13, color: _dateTo != null ? AppColors.textPrimary : AppColors.textTertiary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Status
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CreditNoteStatus?>(
                        value: _statusFilter,
                        hint: const Text('Tous', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(color: AppColors.textPrimary))),
                          ...CreditNoteStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                        ],
                        onChanged: (val) {
                          setState(() => _statusFilter = val);
                          _applyFilters();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Reset Button
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
    );
  }

  Widget _buildTable() {
    return BlocBuilder<CreditNotesBloc, CreditNotesState>(
      builder: (context, state) {
        if (state is CreditNotesLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is CreditNotesError) {
          return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
        }
        if (state is CreditNotesLoaded) {
          List<CreditNote> filteredNotes = state.creditNotes;
          
          if (_selectedClientId != null && _selectedClientId != 'all') {
            filteredNotes = filteredNotes.where((n) => n.customerId == _selectedClientId).toList();
          }
          if (_dateFrom != null) {
            filteredNotes = filteredNotes.where((n) => n.date.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
          }
          if (_dateTo != null) {
            filteredNotes = filteredNotes.where((n) => n.date.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
          }
          if (_statusFilter != null) {
            filteredNotes = filteredNotes.where((n) => n.status == _statusFilter).toList();
          }

          final notes = filteredNotes;

          // Pagination logic
          final totalItems = notes.length;
          final totalPages = (totalItems / _rowsPerPage).ceil() == 0 ? 1 : (totalItems / _rowsPerPage).ceil();
          if (_currentPage >= totalPages) _currentPage = totalPages - 1;
          if (_currentPage < 0) _currentPage = 0;

          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage > totalItems) ? totalItems : startIndex + _rowsPerPage;
          final paginatedNotes = notes.sublist(startIndex, endIndex);

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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                            color: AppColors.background,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 32), // Checkbox space
                              const Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              const Expanded(flex: 3, child: Text('Client', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Container(alignment: Alignment.centerLeft, child: const Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)))),
                              const Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              const SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                        // Table body
                        Expanded(
                          child: paginatedNotes.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.border),
                                      SizedBox(height: 16),
                                      Text("Aucun avoir trouve", style: TextStyle(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: paginatedNotes.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                                  itemBuilder: (context, index) {
                                    final note = paginatedNotes[index];
                                    final statusEnum = note.status;

                                    Color statusColor;
                                    switch (statusEnum) {
                                      case CreditNoteStatus.unused:
                                        statusColor = AppColors.primary;
                                        break;
                                      case CreditNoteStatus.partiallyUsed:
                                        statusColor = AppColors.warning;
                                        break;
                                      case CreditNoteStatus.used:
                                        statusColor = AppColors.success;
                                        break;
                                      case CreditNoteStatus.cancelled:
                                        statusColor = AppColors.error;
                                        break;
                                    }

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withOpacity(0.3),
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
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(note.number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                                const SizedBox(height: 4),
                                                Text(formatDateTimeLong(note.date), style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        note.customerName ?? 'Client Inconnu',
                                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  statusEnum.label,
                                                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              formatCurrencyDT(note.totalTTC),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 80,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                color: AppColors.surface,
                                                onSelected: (val) {
                                                  if (val == 'delete') {
                                                    context.read<CreditNotesBloc>().add(DeleteCreditNote(note.id));
                                                  } else if (val == 'pdf') {
                                                    final doc = DocumentWrapper.fromCreditNote(note);
                                                    PdfService.instance.downloadDocument(context, doc);
                                                  } else if (val == 'print') {
                                                    final doc = DocumentWrapper.fromCreditNote(note);
                                                    Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
                                                  }
                                                },
                                                itemBuilder: (_) => [
                                                  _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
                                                  const PopupMenuDivider(height: 1),
                                                  _buildMenuItem('print', Icons.print_outlined, AppColors.primary, 'Imprimer'),
                                                  const PopupMenuDivider(height: 1),
                                                  _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Telecharger PDF'),
                                                  const PopupMenuDivider(height: 1),
                                                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                                                  const PopupMenuDivider(height: 1),
                                                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // Pagination footer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border)),
                            color: AppColors.background,
                          ),
                          child: Row(
                            children: [
                              const Text('Lignes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                  items: [10, 20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text(v.toString()))).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() {
                                      _rowsPerPage = v;
                                      _currentPage = 0;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Text('Page ${_currentPage + 1} sur $totalPages', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                totalItems == 0 ? 'Affichage de 0 a 0 sur 0 resultats' : 'Affichage de ${startIndex + 1} a $endIndex sur $totalItems resultats',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_left, size: 20, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage < totalPages - 1 ? AppColors.border : AppColors.border.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_right, size: 20, color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                ],
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
}
