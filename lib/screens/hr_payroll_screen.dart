import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/payroll/payroll_bloc.dart';
import '../blocs/payroll/payroll_event.dart';
import '../blocs/payroll/payroll_state.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_event.dart';
import '../blocs/employees/employees_state.dart';
import '../blocs/loans/loans_bloc.dart';
import '../blocs/loans/loans_event.dart';
import '../blocs/loans/loans_state.dart';
import '../models/payslip.dart';
import '../models/employee.dart';
import '../models/employee_loan.dart';
import '../models/payslip_batch.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';
import '../widgets/payslip_form_dialog.dart';
import '../widgets/payslip_batch_dialog.dart';
import '../widgets/employee_loan_dialog.dart';
import '../services/payslip_pdf_service.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class HrPayrollScreen extends StatefulWidget {
  const HrPayrollScreen({super.key});

  @override
  State<HrPayrollScreen> createState() => _HrPayrollScreenState();
}

class _HrPayrollScreenState extends State<HrPayrollScreen> {
  bool _isFirstLoad = true;
  // Navigation / Tab: 0 = Fiches de Paie des Employés, 1 = Prêts des employés
  int _currentTab = 0;
  bool _isTableView = true; // Image 1 Table View or Cards View

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _selectedStatus = 'all'; // all, draft, paid, confirmed

  // Selected row IDs for bulk actions
  final Set<String> _selectedRowIds = {};

  static const Color _primaryBlue = Color(0xFF1A56DB);

  final List<String> _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  @override
  void initState() {
    super.initState();
    context.read<PayrollBloc>().add(const LoadPayslips());
    context.read<EmployeesBloc>().add(const LoadEmployees());
    context.read<LoansBloc>().add(const LoadLoans());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final fmt = NumberFormat('#,##0.000', 'fr_FR');
    return '${fmt.format(amount)} TND';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<EmployeesBloc, EmployeesState>(
        builder: (context, empState) {
          final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];
          final activeEmployees = employees.where((e) => e.isActive).toList();

          return BlocConsumer<PayrollBloc, PayrollState>(
            listener: (context, state) {
              if (_isFirstLoad && (state is PayrollLoaded || state is PayrollError)) {
                setState(() {
                  _isFirstLoad = false;
                });
              }
            },
            builder: (context, pState) {
              if (_isFirstLoad || pState is PayrollLoading || pState is PayrollInitial) {
                return Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final allPayslips = pState is PayrollLoaded ? pState.payslips : <Payslip>[];
              final allBatches = pState is PayrollLoaded ? pState.batches : <PayslipBatch>[];

              return BlocBuilder<LoansBloc, LoansState>(
                builder: (context, lState) {
                  final allLoans = lState is LoansLoaded ? lState.loans : <EmployeeLoan>[];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Top Navigation & Action Header (Matching Image 1 & Image 2)
                      _buildHeader(context, activeEmployees, allPayslips, allLoans, allBatches),

                      // 2. Tab Navigation Switch (Fiches de Paie vs Prêts vs Lots de bulletins)
                      _buildTabSwitcher(allPayslips.length, allLoans.length, allBatches.length),

                      // 3. Tab Body
                      Expanded(
                        child: _currentTab == 0
                            ? _buildPayslipsSection(pState, allPayslips, activeEmployees)
                            : (_currentTab == 1
                                ? _buildLoansSection(lState, allLoans, activeEmployees)
                                : _buildBatchesSection(pState, allPayslips, activeEmployees)),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER (Matching Image 1 Odoo ERP Header)
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context,
    List<Employee> activeEmployees,
    List<Payslip> payslips,
    List<EmployeeLoan> loans,
    [List<PayslipBatch>? batches]
  ) {
    final count = _currentTab == 0
        ? payslips.length
        : (_currentTab == 1 ? loans.length : (batches?.length ?? 0));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // "Nouveau" Button (Image 1 style in Royal Blue / Odoo Purple)
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              _currentTab == 0
                  ? 'Nouveau'
                  : (_currentTab == 1 ? 'Nouveau prêt' : 'Nouveau lot'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentTab == 2 ? const Color(0xFF1A56DB) : _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {
              if (_currentTab == 0) {
                PayslipFormDialog.show(context);
              } else if (_currentTab == 1) {
                EmployeeLoanDialog.show(context);
              } else {
                PayslipBatchDialog.show(context);
              }
            },
          ),
          const SizedBox(width: 14),

          // Title & Settings Icon (Image 1: "Fiches de Paie des Employés" / "Lots de bulletins de paie")
          Text(
            _currentTab == 0
                ? 'Fiches de Paie des Employés'
                : (_currentTab == 1 ? 'Prêts des employés' : 'Lots de bulletins de paie'),
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF64748B)),

          // Selection Bar matching Image 1: [4 sélectionné(s) ✕] [🖨 Imprimer ▾] [⚙ Actions ▾]
          if (_currentTab == 0 && _selectedRowIds.isNotEmpty) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedRowIds.length} sélectionné(s)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8)),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() => _selectedRowIds.clear()),
                    child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF6B21A8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // "Imprimer ▾" Button (Image 1)
            PopupMenuButton<String>(
              tooltip: 'Imprimer les bulletins sélectionnés',
              offset: const Offset(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (val) => _handleBatchPrint(val, payslips),
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                      SizedBox(width: 10),
                      Text('Payslip Report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'standard',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF1A56DB)),
                      SizedBox(width: 10),
                      Text('Standard Payslip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.print_outlined, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 6),
                    Text('Imprimer', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // "Actions ▾" Button (Image 1)
            PopupMenuButton<String>(
              tooltip: 'Actions groupées',
              offset: const Offset(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (val) => _handleBatchAction(val, payslips),
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'paid',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                      SizedBox(width: 10),
                      Text('Marquer comme payé', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'validated',
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined, size: 16, color: Color(0xFF06B6D4)),
                      SizedBox(width: 10),
                      Text('Marquer comme validé', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Supprimer la sélection', style: TextStyle(fontSize: 13, color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings_outlined, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 6),
                    Text('Actions', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(width: 16),

          // Search Bar (Image 1)
          Expanded(
            child: Container(
              height: 38,
              constraints: const BoxConstraints(maxWidth: 380),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: _currentTab == 0 ? 'Rechercher un bulletin...' : 'Rechercher un prêt...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),

          const Spacer(),

          // Actions on Right: Generate monthly batch, Imprimer (if none selected), Refresh, View Switch, Pagination
          if (_currentTab == 0) ...[
            if (_selectedRowIds.isEmpty) ...[
              PopupMenuButton<String>(
                tooltip: 'Imprimer les bulletins',
                offset: const Offset(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (val) => _handleBatchPrint(val, payslips),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                        SizedBox(width: 10),
                        Text('Payslip Report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'standard',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF1A56DB)),
                        SizedBox(width: 10),
                        Text('Standard Payslip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.print_outlined, size: 16, color: Color(0xFF475569)),
                      SizedBox(width: 6),
                      Text('Imprimer', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            PopupMenuButton<String>(
              tooltip: 'Générer la paie',
              offset: const Offset(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (val) {
                if (val == 'wizard') {
                  PayslipBatchDialog.show(context);
                } else {
                  _confirmGenerateMonthlyPayroll(activeEmployees);
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'wizard',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF1A56DB)),
                      SizedBox(width: 8),
                      Text('Génération par lot (Assistant Odoo)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'auto',
                  child: Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text('Génération rapide automatique', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Générer la paie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
            onPressed: () {
              context.read<PayrollBloc>().add(const LoadPayslips());
              context.read<LoansBloc>().add(const LoadLoans());
            },
          ),
          const SizedBox(width: 8),

          // Pagination indicator (Image 1: 1-5/5 < >)
          Text(
            count > 0 ? '1-$count/$count' : '0-0/0',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF94A3B8)),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),

          // View Toggle: Table View vs Cards View (Image 1 Top Right)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _isTableView = true),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isTableView ? _primaryBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      Icons.table_rows_rounded,
                      size: 16,
                      color: _isTableView ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isTableView = false),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: !_isTableView ? _primaryBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 16,
                      color: !_isTableView ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BATCH PRINT & BATCH ACTIONS (Image 1: Payslip Report & Standard Payslip)
  // ---------------------------------------------------------------------------
  void _handleBatchPrint(String printType, List<Payslip> allPayslips) {
    final selected = _selectedRowIds.isNotEmpty
        ? allPayslips.where((p) => _selectedRowIds.contains(p.id)).toList()
        : allPayslips;

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun bulletin de paie disponible pour l\'impression.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    PayslipPdfService.instance.printBatchPayslips(
      context,
      selected,
      type: printType, // 'report' or 'standard'
    );
  }

  Future<void> _handleBatchAction(String action, List<Payslip> allPayslips) async {
    final selected = allPayslips.where((p) => _selectedRowIds.contains(p.id)).toList();
    if (selected.isEmpty) return;

    if (action == 'paid') {
      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!isOnline) return;
      for (final p in selected) {
        context.read<PayrollBloc>().add(UpdatePayslipStatus(id: p.id, newStatus: 'paid', paymentDate: DateTime.now()));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length} bulletin(s) marqué(s) comme payé(s).'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else if (action == 'validated') {
      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!isOnline) return;
      for (final p in selected) {
        context.read<PayrollBloc>().add(UpdatePayslipStatus(id: p.id, newStatus: 'validated'));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length} bulletin(s) validé(s).'),
          backgroundColor: const Color(0xFF06B6D4),
        ),
      );
    } else if (action == 'delete') {
      OfflineActionHelper.executeAction(
        context: context,
        action: 'delete',
        customActionLabel: 'les ${selected.length} bulletins sélectionnés',
        onConfirmed: () {
          for (final p in selected) {
            context.read<PayrollBloc>().add(DeletePayslip(p.id));
          }
          setState(() => _selectedRowIds.clear());
        },
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 2. TAB SWITCHER (Fiches de Paie vs Prêts vs Lots de bulletins)
  // ---------------------------------------------------------------------------
  Widget _buildTabSwitcher(int payslipsCount, int loansCount, int batchesCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _tabPill(
            index: 0,
            icon: Icons.payments_rounded,
            label: 'Fiches de Paie des Employés',
            badge: '$payslipsCount',
          ),
          const SizedBox(width: 8),
          _tabPill(
            index: 1,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Prêts des employés',
            badge: '$loansCount',
          ),
          const SizedBox(width: 8),
          _tabPill(
            index: 2,
            icon: Icons.folder_special_rounded,
            label: 'Lots de bulletins de paie',
            badge: '$batchesCount',
          ),
        ],
      ),
    );
  }

  Widget _tabPill({required int index, required IconData icon, required String label, required String badge}) {
    final isSelected = _currentTab == index;
    return InkWell(
      onTap: () => setState(() {
        _currentTab = index;
        _selectedRowIds.clear();
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? _primaryBlue : const Color(0xFFCBD5E1)),
          boxShadow: isSelected
              ? [BoxShadow(color: _primaryBlue.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : _primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TAB 1: FICHES DE PAIE DES EMPLOYÉS (Image 1 Odoo ERP)
  // ---------------------------------------------------------------------------
  Widget _buildPayslipsSection(PayrollState state, List<Payslip> allPayslips, List<Employee> activeEmployees) {
    // Filter by month & year
    final periodPayslips = allPayslips.where((p) => p.periodMonth == _selectedMonth && p.periodYear == _selectedYear).toList();

    // Calculate Metrics for selected period
    double totalGross = 0;
    double totalCnss = 0;
    double totalNet = 0;
    int paidCount = 0;

    for (final p in periodPayslips) {
      totalGross += p.grossSalary;
      totalCnss += p.cnssDeduction;
      totalNet += p.netSalary;
      if (p.paymentStatus == 'paid') paidCount++;
    }

    // Search & status filter
    final filtered = periodPayslips.where((p) {
      if (_selectedStatus != 'all' && p.paymentStatus != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = p.employeeName.toLowerCase().contains(q);
        final matchJob = (p.employeeJobTitle ?? '').toLowerCase().contains(q);
        final matchRef = p.reference.toLowerCase().contains(q);
        if (!matchName && !matchJob && !matchRef) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Metrics Banner
        _buildMetricsBanner(
          totalNet: totalNet,
          totalGross: totalGross,
          totalCnss: totalCnss,
          totalCount: periodPayslips.length,
          paidCount: paidCount,
        ),

        // Filter Bar (Period & Status)
        _buildFilterBar(),

        // Table or Cards View
        Expanded(
          child: state is PayrollLoading && allPayslips.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
              : filtered.isEmpty
                  ? _buildEmptyState(activeEmployees)
                  : _isTableView
                      ? _buildPayslipsOdooTable(filtered)
                      : _buildPayslipsCardList(filtered),
        ),
      ],
    );
  }

  // Odoo Table matching Image 1
  Widget _buildPayslipsOdooTable(List<Payslip> payslips) {
    final allSelected = payslips.isNotEmpty && payslips.every((p) => _selectedRowIds.contains(p.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 52,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: [
                  DataColumn(
                    label: Checkbox(
                      value: allSelected,
                      activeColor: _primaryBlue,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedRowIds.addAll(payslips.map((p) => p.id));
                          } else {
                            _selectedRowIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const DataColumn(label: Text('Référence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Nom de bulletin de paie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Date début', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Date de fin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Lots de bulletins de paie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Net Wage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                ],
                rows: payslips.map((p) {
                  final isSelected = _selectedRowIds.contains(p.id);
                  final isPaid = p.paymentStatus == 'paid';
                  final isValidated = p.paymentStatus == 'validated';

                  // Period format (Image 1: octobre-2024)
                  final periodStr = '${_months[p.periodMonth - 1].toLowerCase()}-${p.periodYear}';
                  final lastDay = DateTime(p.periodYear, p.periodMonth + 1, 0).day;
                  final startDateStr = '01/${p.periodMonth.toString().padLeft(2, '0')}/${p.periodYear}';
                  final endDateStr = '$lastDay/${p.periodMonth.toString().padLeft(2, '0')}/${p.periodYear}';

                  // Status pill (Image 1: Fait [teal/cyan], Paid [green], Brouillon [orange])
                  Widget statusBadge;
                  if (isPaid) {
                    statusBadge = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Paid', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    );
                  } else if (isValidated) {
                    statusBadge = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Fait', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    );
                  } else {
                    statusBadge = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Brouillon', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    );
                  }

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedRowIds.add(p.id);
                        } else {
                          _selectedRowIds.remove(p.id);
                        }
                      });
                    },
                    cells: [
                      DataCell(
                        Checkbox(
                          value: isSelected,
                          activeColor: _primaryBlue,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedRowIds.add(p.id);
                              } else {
                                _selectedRowIds.remove(p.id);
                              }
                            });
                          },
                        ),
                      ),

                      // Référence (Image 1: SLIP/001)
                      DataCell(
                        InkWell(
                          onTap: () => PayslipFormDialog.show(context, payslip: p),
                          child: Text(
                            p.reference.isNotEmpty ? p.reference : 'SLIP/001',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryBlue),
                          ),
                        ),
                      ),

                      // Employé (Image 1: Mohamed, Alex)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                              child: Text(
                                p.employeeName.isNotEmpty ? p.employeeName[0].toUpperCase() : 'E',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(p.employeeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),

                      // Nom de bulletin de paie (Image 1)
                      DataCell(
                        Text(
                          p.payslipName?.isNotEmpty == true
                              ? p.payslipName!
                              : 'Bulletin de paie de ${p.employeeName} pour $periodStr',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                        ),
                      ),

                      // Period (Image 1: octobre-2024)
                      DataCell(Text(periodStr, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))),

                      // Date début (Image 1: 01/10/2024)
                      DataCell(Text(startDateStr, style: const TextStyle(fontSize: 12.5))),

                      // Date de fin (Image 1: 31/10/2024)
                      DataCell(Text(endDateStr, style: const TextStyle(fontSize: 12.5))),

                      // Statut (Image 1: Fait, Paid, Brouillon)
                      DataCell(statusBadge),

                      // Lots de bulletins de paie (Image 1)
                      DataCell(Text(p.batchNumber ?? '—', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),

                      // Net Wage
                      DataCell(
                        Text(
                          '${_formatCurrency(p.netSalary)} DT',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                        ),
                      ),

                      // Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Imprimer ce bulletin',
                              icon: const Icon(Icons.print_outlined, size: 17, color: Color(0xFF1A56DB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onSelected: (val) {
                                PayslipPdfService.instance.printPayslip(
                                  context,
                                  p,
                                  type: val,
                                );
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                  value: 'standard',
                                  child: Row(
                                    children: [
                                      Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF1A56DB)),
                                      SizedBox(width: 8),
                                      Text('Standard Payslip', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'report',
                                  child: Row(
                                    children: [
                                      Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                                      SizedBox(width: 8),
                                      Text('Payslip Report', style: TextStyle(fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Éditer',
                              icon: const Icon(Icons.edit_outlined, size: 17, color: _primaryBlue),
                              onPressed: () => PayslipFormDialog.show(context, payslip: p),
                            ),
                            IconButton(
                              tooltip: 'Aperçu',
                              icon: const Icon(Icons.visibility_outlined, size: 17, color: Color(0xFF64748B)),
                              onPressed: () => _showPayslipDetailModal(p),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline, size: 17, color: Colors.redAccent),
                              onPressed: () {
                                OfflineActionHelper.executeAction(
                                  context: context,
                                  action: 'delete',
                                  customActionLabel: 'le bulletin de paie',
                                  onConfirmed: () => context.read<PayrollBloc>().add(DeletePayslip(p.id)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Cards List view fallback
  Widget _buildPayslipsCardList(List<Payslip> payslips) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: payslips.length,
          separatorBuilder: (_, __) => const Divider(height: 14),
          itemBuilder: (context, idx) {
            final p = payslips[idx];
            return _buildPayslipRow(p);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. TAB 2: PRÊTS DES EMPLOYÉS (Matching Images 2 & 3)
  // ---------------------------------------------------------------------------
  Widget _buildLoansSection(LoansState state, List<EmployeeLoan> allLoans, List<Employee> activeEmployees) {
    final filtered = allLoans.where((l) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = l.name.toLowerCase().contains(q);
        final matchEmp = l.employeeName.toLowerCase().contains(q);
        final matchRef = l.reference.toLowerCase().contains(q);
        if (!matchName && !matchEmp && !matchRef) return false;
      }
      return true;
    }).toList();

    double totalLoansAmount = 0.0;
    double totalRemainingAmount = 0.0;
    int paidLoansCount = 0;

    for (final l in allLoans) {
      totalLoansAmount += l.amount;
      totalRemainingAmount += l.remainingAmount;
      if (l.status == 'paid') paidLoansCount++;
    }

    return Column(
      children: [
        // Metrics Banner for Loans
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Total Prêts Accordés',
                  value: '${_formatCurrency(totalLoansAmount)} DT',
                  subtitle: '${allLoans.length} prêt(s) au total',
                  icon: Icons.account_balance_wallet_rounded,
                  color: _primaryBlue,
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _metricCard(
                  title: 'Reste Total à Rembourser',
                  value: '${_formatCurrency(totalRemainingAmount)} DT',
                  subtitle: 'Échéances en cours',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _metricCard(
                  title: 'Prêts Entièrement Soldés',
                  value: '$paidLoansCount / ${allLoans.length}',
                  subtitle: 'Prêts soldés',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
            ],
          ),
        ),

        // Loans Table (Matching Images 2 & 3)
        Expanded(
          child: state is LoansLoading && allLoans.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
              : filtered.isEmpty
                  ? _buildLoansEmptyState()
                  : _buildLoansTable(filtered),
        ),
      ],
    );
  }

  Widget _buildLoansTable(List<EmployeeLoan> loans) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 52,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Intitulé du prêt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Montant accordé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Mensualité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Mois', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Reste à rembourser', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Date de début', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Company Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                ],
                rows: loans.map((l) {
                  final isPaid = l.status == 'paid';
                  final isConfirmed = l.status == 'confirmed';

                  Color statusColor = Colors.orange;
                  if (isPaid) statusColor = Colors.green;
                  if (isConfirmed) statusColor = _primaryBlue;

                  return DataRow(
                    cells: [
                      // Intitulé (Image 2: prêt aid kbir, pret de test)
                      DataCell(
                        InkWell(
                          onTap: () => EmployeeLoanDialog.show(context, loan: l),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: _primaryBlue),
                              const SizedBox(width: 8),
                              Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryBlue)),
                            ],
                          ),
                        ),
                      ),

                      // Employé
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                              child: Text(
                                l.employeeName.isNotEmpty ? l.employeeName[0].toUpperCase() : 'E',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(l.employeeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),

                      // Montant accordé (Image 2: 1 500,00)
                      DataCell(Text('${_formatCurrency(l.amount)} DT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),

                      // Mensualité (Image 2: 150,00)
                      DataCell(Text('${_formatCurrency(l.monthlyAmount)} DT', style: const TextStyle(fontSize: 12.5))),

                      // Mois (Image 2: 10)
                      DataCell(Text('${l.monthsCount}', style: const TextStyle(fontSize: 12.5))),

                      // Reste à rembourser (Image 2: 1 500,00)
                      DataCell(
                        Text(
                          '${_formatCurrency(l.remainingAmount)} DT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: l.remainingAmount == 0 ? Colors.green : Colors.red.shade700,
                          ),
                        ),
                      ),

                      // Date (Image 2: 04/11/2024)
                      DataCell(Text(DateFormat('dd/MM/yyyy').format(l.date), style: const TextStyle(fontSize: 12.5))),

                      // Statut (Image 2 stepper: Brouillon, Confirmé, Payé, Annulé)
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l.statusDisplay,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                      ),

                      // Company Credit
                      DataCell(
                        Icon(
                          l.isCompanyCredit ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: l.isCompanyCredit ? _primaryBlue : const Color(0xFFCBD5E1),
                        ),
                      ),

                      // Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Consulter / Modifier',
                              icon: const Icon(Icons.edit_outlined, size: 17, color: _primaryBlue),
                              onPressed: () => EmployeeLoanDialog.show(context, loan: l),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline, size: 17, color: Colors.redAccent),
                              onPressed: () {
                                context.read<LoansBloc>().add(DeleteLoan(l.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Prêt supprimé avec succès.')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoansEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 54, color: AppColors.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text(
            'Aucun prêt accordé aux employés pour le moment',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Créez des prêts avec échéancier mensuel déduit automatiquement des bulletins de paie.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => EmployeeLoanDialog.show(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Accorder un prêt'),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. LOTS DE BULLETINS DE PAIE (Images 1, 2, 3, 4, 5)
  // ---------------------------------------------------------------------------
  Widget _buildBatchesSection(
    PayrollState pState,
    List<Payslip> allPayslips,
    List<Employee> activeEmployees,
  ) {
    final batches = pState is PayrollLoaded ? pState.batches : <PayslipBatch>[];

    // Filter by search query if any
    final filteredBatches = batches.where((b) {
      if (_searchQuery.isNotEmpty) {
        return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            b.salaryJournal.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    if (pState is PayrollLoading && batches.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primaryBlue));
    }

    if (filteredBatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEDE9FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_special_rounded, size: 48, color: Color(0xFF1A56DB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun lot de bulletins de paie',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Créez un lot pour générer automatiquement les fiches de paie de vos salariés.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer un lot de bulletins'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => PayslipBatchDialog.show(context),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 54,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Nom du lot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Période', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Date début', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Date de fin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Bulletins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Journal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                ],
                rows: filteredBatches.map((b) {
                  final periodStr = '${_months[b.periodMonth - 1].toLowerCase()}-${b.periodYear}';
                  final lastDay = DateTime(b.periodYear, b.periodMonth + 1, 0).day;
                  final startStr = '01/${b.periodMonth.toString().padLeft(2, '0')}/${b.periodYear}';
                  final endStr = '$lastDay/${b.periodMonth.toString().padLeft(2, '0')}/${b.periodYear}';

                  final batchSlips = allPayslips.where((p) => p.batchNumber == b.name || b.payslipIds.contains(p.id)).toList();
                  final isClosed = b.status == 'closed';

                  return DataRow(
                    onSelectChanged: (_) => PayslipBatchDialog.show(context, batch: b),
                    cells: [
                      // Nom du lot (e.g. 12-2024)
                      DataCell(
                        Row(
                          children: [
                            const Icon(Icons.folder_outlined, size: 18, color: Color(0xFF1A56DB)),
                            const SizedBox(width: 8),
                            Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A56DB))),
                          ],
                        ),
                      ),

                      // Période
                      DataCell(Text(periodStr, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))),

                      // Date début
                      DataCell(Text(startStr, style: const TextStyle(fontSize: 12.5))),

                      // Date fin
                      DataCell(Text(endStr, style: const TextStyle(fontSize: 12.5))),

                      // Bulletins count
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${batchSlips.length} bulletin(s)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB)),
                          ),
                        ),
                      ),

                      // Journal
                      DataCell(Text(b.salaryJournal, style: const TextStyle(fontSize: 12.5))),

                      // Statut
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isClosed ? const Color(0xFF64748B) : const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isClosed ? 'Fermer' : 'Brouillon',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ouvrir le lot',
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1A56DB)),
                              onPressed: () => PayslipBatchDialog.show(context, batch: b),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Imprimer ce lot',
                              icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF1A56DB)),
                              onSelected: (val) {
                                if (batchSlips.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Aucun bulletin dans ce lot pour l\'impression.')),
                                  );
                                  return;
                                }
                                PayslipPdfService.instance.printBatchPayslips(context, batchSlips, type: val);
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(value: 'standard', child: Text('Bulletins Standards (Lot)')),
                                PopupMenuItem(value: 'report', child: Text('Rapport Récapitulatif (PDF)')),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Supprimer ce lot',
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () {
                                OfflineActionHelper.executeAction(
                                  context: context,
                                  action: 'delete',
                                  customActionLabel: 'le lot "${b.name}"',
                                  onConfirmed: () {
                                    context.read<PayrollBloc>().add(DeletePayslipBatch(b.id));
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER BAR & METRICS
  // ---------------------------------------------------------------------------
  Widget _buildMetricsBanner({
    required double totalNet,
    required double totalGross,
    required double totalCnss,
    required int totalCount,
    required int paidCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _metricCard(
              title: context.tr('Net Total à Décaisser'),
              value: _formatCurrency(totalNet),
              subtitle: 'Salaires nets du mois',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _metricCard(
              title: context.tr('Masse Salariale Brute'),
              value: _formatCurrency(totalGross),
              subtitle: 'Total brut mensuel',
              icon: Icons.trending_up_rounded,
              color: _primaryBlue,
              bgColor: const Color(0xFFEFF6FF),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _metricCard(
              title: context.tr('Charges Sociales (CNSS)'),
              value: _formatCurrency(totalCnss),
              subtitle: 'Cotisations à déclarer',
              icon: Icons.account_balance_rounded,
              color: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFEF3C7),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _metricCard(
              title: context.tr('Salariés Payés'),
              value: '$paidCount / $totalCount',
              subtitle: '${totalCount - paidCount} en attente',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF8B5CF6),
              bgColor: const Color(0xFFF5F3FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          // Month Selector
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth,
                items: List.generate(12, (i) {
                  return DropdownMenuItem(value: i + 1, child: Text(_months[i], style: const TextStyle(fontSize: 12.5)));
                }),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMonth = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Year Selector
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                items: [2024, 2025, 2026, 2027, 2028].map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedYear = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Status Chips
          Row(
            children: [
              _filterChip('Tous', 'all'),
              const SizedBox(width: 6),
              _filterChip('Brouillons', 'draft'),
              const SizedBox(width: 6),
              _filterChip('Payés', 'paid'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatus = value),
      selectedColor: _primaryBlue,
      labelStyle: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? Colors.transparent : AppColors.border)),
    );
  }

  Widget _buildEmptyState(List<Employee> activeEmployees) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Aucun bulletin généré pour ${_months[_selectedMonth - 1]} $_selectedYear',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Générez automatiquement les fiches de paie pour vos collaborateurs en un clic.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Générer la paie du mois maintenant'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () => _confirmGenerateMonthlyPayroll(activeEmployees),
          ),
        ],
      ),
    );
  }

  Widget _buildPayslipRow(Payslip p) {
    final isPaid = p.paymentStatus == 'paid';

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
          child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
              Text(p.employeeJobTitle ?? 'Employé', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Salaire Brut', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
              Text(_formatCurrency(p.grossSalary), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CNSS (9.18%)', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
              Text('- ${_formatCurrency(p.cnssDeduction)}', style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Net à Payer', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
              Text(_formatCurrency(p.netSalary), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isPaid ? 'Payé' : 'Brouillon',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Éditer la fiche de paie',
          icon: const Icon(Icons.edit_document, size: 18, color: _primaryBlue),
          onPressed: () => PayslipFormDialog.show(context, payslip: p),
        ),
        PopupMenuButton<String>(
          tooltip: 'Imprimer ce bulletin',
          icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF1A56DB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (val) {
            PayslipPdfService.instance.printPayslip(
              context,
              p,
              type: val,
            );
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'standard',
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF1A56DB)),
                  SizedBox(width: 8),
                  Text('Standard Payslip', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                  SizedBox(width: 8),
                  Text('Payslip Report', style: TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Aperçu du bulletin',
          icon: const Icon(Icons.visibility_outlined, size: 18),
          onPressed: () => _showPayslipDetailModal(p),
        ),
        if (!isPaid)
          IconButton(
            tooltip: 'Marquer comme payé',
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
            onPressed: () async {
              final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
              if (!isOnline) return;
              context.read<PayrollBloc>().add(UpdatePayslipStatus(id: p.id, newStatus: 'paid'));
            },
          ),
        IconButton(
          tooltip: 'Supprimer',
          icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.textTertiary),
          onPressed: () {
            OfflineActionHelper.executeAction(
              context: context,
              action: 'delete',
              customActionLabel: 'le bulletin de paie',
              onConfirmed: () => context.read<PayrollBloc>().add(DeletePayslip(p.id)),
            );
          },
        ),
      ],
    );
  }

  void _confirmGenerateMonthlyPayroll(List<Employee> activeEmployees) {
    if (activeEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun collaborateur actif disponible pour générer la paie.')));
      return;
    }

    final mName = _months[_selectedMonth - 1];

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: const [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Génération automatique'),
                ],
              ),
              content: Text(
                'Voulez-vous générer les fiches de paie pour $mName $_selectedYear pour les ${activeEmployees.length} collaborateur(s) actif(s) ?\n\nLes montants (salaire de base, indemnités, cotisations CNSS de 9.18% et net à payer) seront calculés automatiquement.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  onPressed: isSubmitting
                      ? null
                      : () {
                          setDlgState(() => isSubmitting = true);
                          final isOnline = ConnectivityService.instance.isOnline;
                          context.read<PayrollBloc>().add(GenerateMonthlyPayslips(
                            month: _selectedMonth,
                            year: _selectedYear,
                            activeEmployees: activeEmployees,
                          ));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    isOnline ? Icons.check_circle_outline_rounded : Icons.cloud_off_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isOnline
                                        ? 'Fiches de paie de $mName $_selectedYear générées avec succès !'
                                        : 'Fiches de paie de $mName $_selectedYear générées hors ligne (en attente de sync)',
                                  ),
                                ],
                              ),
                              backgroundColor: isOnline ? const Color(0xFF10B981) : AppColors.warning,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirmer la génération'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPayslipDetailModal(Payslip p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Text('Bulletin de paie - ${p.periodLabel}'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.employeeName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('${p.employeeJobTitle ?? "Employé"} | CIN: ${p.employeeCin ?? "N/A"} | CNSS: ${p.employeeCnss ?? "N/A"}', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _payslipItemRow('Salaire de base brut', _formatCurrency(p.baseSalary)),
              _payslipItemRow('Indemnité de transport', _formatCurrency(p.transportAllowance)),
              if (p.primes > 0) _payslipItemRow('Primes & Gratifications', _formatCurrency(p.primes)),
              const Divider(),
              _payslipItemRow('Salaire Brut Total', _formatCurrency(p.grossSalary), isBold: true),
              const SizedBox(height: 6),
              _payslipItemRow('Cotisation CNSS Salariale (9.18%)', '- ${_formatCurrency(p.cnssDeduction)}', color: Colors.red),
              if (p.taxDeduction > 0) _payslipItemRow('Retenue IRPP', '- ${_formatCurrency(p.taxDeduction)}', color: Colors.red),
              if (p.advanceSalary > 0) _payslipItemRow('Avances sur salaire (déduites)', '- ${_formatCurrency(p.advanceSalary)}', color: Colors.red),
              if (p.loanDeduction > 0) _payslipItemRow('Remboursements de prêts (déduits)', '- ${_formatCurrency(p.loanDeduction)}', color: Colors.red),
              if (p.otherDeductions > 0) _payslipItemRow('Autres retenues', '- ${_formatCurrency(p.otherDeductions)}', color: Colors.red),
              const Divider(thickness: 2),
              _payslipItemRow('NET À PAYER', _formatCurrency(p.netSalary), isBold: true, color: const Color(0xFF10B981), fontSize: 16),
              const SizedBox(height: 8),
              Text('Mode de règlement : ${p.paymentMethod}', style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Fermer'))),
        ],
      ),
    );
  }

  Widget _payslipItemRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.textPrimary)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}
