import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/payroll/payroll_bloc.dart';
import '../../blocs/payroll/payroll_event.dart';
import '../../blocs/payroll/payroll_state.dart';
import '../../blocs/employees/employees_bloc.dart';
import '../../blocs/employees/employees_event.dart';
import '../../blocs/employees/employees_state.dart';
import '../../models/payslip.dart';
import '../../models/employee.dart';
import '../../models/employee_loan.dart';
import '../../blocs/loans/loans_bloc.dart';
import '../../blocs/loans/loans_event.dart';
import '../../blocs/loans/loans_state.dart';
import '../../utils/constants.dart';
import '../../models/payslip_batch.dart';
import '../../widgets/payslip_form_dialog.dart';
import '../../widgets/payslip_batch_dialog.dart';
import '../../widgets/employee_loan_dialog.dart';
import '../../services/payslip_pdf_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/offline_action_helper.dart';

class MobileHrPayrollScreen extends StatefulWidget {
  const MobileHrPayrollScreen({super.key});

  @override
  State<MobileHrPayrollScreen> createState() => _MobileHrPayrollScreenState();
}

class _MobileHrPayrollScreenState extends State<MobileHrPayrollScreen> {
  bool _isFirstLoad = true;
  int _currentTab = 0; // 0 = Fiches de Paie, 1 = Prêts
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _selectedStatus = 'all'; // all, draft, paid

  final List<String> _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
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
      appBar: AppBar(
        title: Text(
          _currentTab == 0
              ? 'Fiches de Paie'
              : (_currentTab == 1 ? 'Prêts des employés' : 'Lots de bulletins'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          if (_currentTab == 0)
            PopupMenuButton<String>(
              tooltip: 'Imprimer les bulletins',
              icon: const Icon(Icons.print_outlined, size: 22, color: Color(0xFF1A56DB)),
              onSelected: (val) {
                final state = context.read<PayrollBloc>().state;
                if (state is PayrollLoaded) {
                  final periodSlips = state.payslips
                      .where((p) => p.periodMonth == _selectedMonth && p.periodYear == _selectedYear)
                      .toList();
                  if (periodSlips.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aucun bulletin à imprimer pour cette période.')),
                    );
                    return;
                  }
                  PayslipPdfService.instance.printBatchPayslips(
                    context,
                    periodSlips,
                    type: val,
                  );
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                      SizedBox(width: 8),
                      Text('Rapport Récapitulatif (PDF)', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'standard',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF1A56DB)),
                      SizedBox(width: 8),
                      Text('Bulletins Standards (Lot)', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: _currentTab == 0
                ? 'Nouveau bulletin'
                : (_currentTab == 1 ? 'Nouveau prêt' : 'Nouveau lot'),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: Color(0xFF1A56DB)),
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () {
              context.read<PayrollBloc>().add(const LoadPayslips());
              context.read<LoansBloc>().add(const LoadLoans());
            },
          ),
        ],
      ),
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
            builder: (context, state) {
              if (_isFirstLoad || state is PayrollLoading || state is PayrollInitial) {
                return Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final allPayslips = state is PayrollLoaded ? state.payslips : <Payslip>[];
              final allBatches = state is PayrollLoaded ? state.batches : <PayslipBatch>[];

              // Filter by month & year
              final periodPayslips = allPayslips
                  .where((p) => p.periodMonth == _selectedMonth && p.periodYear == _selectedYear)
                  .toList();

              // Metrics
              double totalNet = 0;
              int paidCount = 0;
              for (final p in periodPayslips) {
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
                  if (!matchName && !matchJob) return false;
                }
                return true;
              }).toList();

              return Column(
                children: [
                  // Sub-tab switcher (Fiches, Prêts, Lots)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: AppColors.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _currentTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _currentTab == 0 ? const Color(0xFF1A56DB) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Fiches (${periodPayslips.length})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _currentTab == 0 ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: BlocBuilder<LoansBloc, LoansState>(
                            builder: (context, lState) {
                              final count = lState is LoansLoaded ? lState.loans.length : 0;
                              return InkWell(
                                onTap: () => setState(() => _currentTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _currentTab == 1 ? const Color(0xFF1A56DB) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Prêts ($count)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _currentTab == 1 ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _currentTab = 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _currentTab == 2 ? const Color(0xFF1A56DB) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Lots (${allBatches.length})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _currentTab == 2 ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_currentTab == 1)
                    Expanded(child: _buildMobileLoansList())
                  else if (_currentTab == 2)
                    Expanded(child: _buildMobileBatchesList(allBatches, allPayslips))
                  else ...[
                    // Period Selector Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: AppColors.surface,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF0D9488)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedMonth,
                              isDense: true,
                              items: List.generate(12, (i) => i + 1).map((m) {
                                return DropdownMenuItem<int>(
                                  value: m,
                                  child: Text(
                                    _months[m - 1],
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedMonth = val);
                              },
                            ),
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            isDense: true,
                            items: [2024, 2025, 2026, 2027, 2028].map((y) {
                              return DropdownMenuItem<int>(
                                value: y,
                                child: Text('$y', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedYear = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mini Metrics Card
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0D9488).withValues(alpha: 0.12),
                          const Color(0xFF2563EB).withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Net à Payer',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(totalNet),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Bulletins',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$paidCount / ${periodPayslips.length} payés',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status chips & search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      children: [
                        _statusChip('Tous', 'all'),
                        const SizedBox(width: 6),
                        _statusChip('Payés', 'paid'),
                        const SizedBox(width: 6),
                        _statusChip('Brouillons', 'draft'),
                      ],
                    ),
                  ),

                  // Payslip List
                  Expanded(
                    child: state is PayrollLoading && allPayslips.isEmpty
                        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Aucun bulletin pour cette période',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 12),
                                    if (activeEmployees.isNotEmpty)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0D9488),
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.auto_awesome, size: 16),
                                        label: const Text('Générer la paie'),
                                        onPressed: () => _generatePayroll(context, activeEmployees),
                                      ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final p = filtered[idx];
                                  final isPaid = p.paymentStatus == 'paid';
                                  final sColor = isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

                                  return InkWell(
                                    onTap: () => _showPayslipDetails(context, p),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.border),
                                        boxShadow: AppShadows.sm,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                                child: Text(
                                                  p.employeeName.isNotEmpty ? p.employeeName[0].toUpperCase() : 'E',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Color(0xFF0D9488),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      p.employeeName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                    ),
                                                    if (p.employeeJobTitle != null && p.employeeJobTitle!.isNotEmpty)
                                                      Text(
                                                        p.employeeJobTitle!,
                                                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: sColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isPaid ? 'PAYÉ' : 'BROUILLON',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: sColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Salaire brut',
                                                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                                  ),
                                                  Text(
                                                    _formatCurrency(p.grossSalary),
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Net à payer',
                                                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                                  ),
                                                  Text(
                                                    _formatCurrency(p.netSalary),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF0D9488),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 14),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  PopupMenuButton<String>(
                                                    tooltip: 'Imprimer ce bulletin',
                                                    icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF1A56DB)),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
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
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    tooltip: 'Modifier',
                                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1A56DB)),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () => PayslipFormDialog.show(context, payslip: p),
                                                  ),
                                                ],
                                              ),
                                              if (!isPaid)
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: const Color(0xFF10B981),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                  icon: const Icon(Icons.check_circle_outline, size: 15),
                                                  label: const Text('Marquer payé', style: TextStyle(fontSize: 11.5)),
                                                  onPressed: () {
                                                    context.read<PayrollBloc>().add(
                                                          UpdatePayslipStatus(
                                                            id: p.id,
                                                            newStatus: 'paid',
                                                            paymentDate: DateTime.now(),
                                                          ),
                                                        );
                                                  },
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: _currentTab == 1
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau prêt'),
              onPressed: () => EmployeeLoanDialog.show(context),
            )
          : _currentTab == 2
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('Nouveau lot'),
                  onPressed: () => PayslipBatchDialog.show(context),
                )
              : FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Générer la paie'),
                  onPressed: () {
                    final empState = context.read<EmployeesBloc>().state;
                    final emps = empState is EmployeesLoaded
                        ? empState.employees.where((e) => e.isActive).toList()
                        : <Employee>[];
                    _showGenerationSheet(context, emps);
                  },
                ),
    );
  }

  void _showGenerationSheet(BuildContext context, List<Employee> activeEmployees) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Options de génération de paie',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Choisissez une méthode de génération des bulletins',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A56DB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.playlist_add_check_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Génération par lot (Assistant Odoo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Sélectionnez les employés avec l\'assistant et créez un lot complet.', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  PayslipBatchDialog.show(context);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Génération rapide automatique', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Génère pour les ${activeEmployees.length} employés actifs pour ${_months[_selectedMonth - 1]} $_selectedYear.', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _generatePayroll(context, activeEmployees);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, String value) {
    final sel = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: sel ? Colors.white : AppColors.textPrimary)),
      selected: sel,
      selectedColor: const Color(0xFF0D9488),
      onSelected: (_) => setState(() => _selectedStatus = value),
    );
  }

  void _generatePayroll(BuildContext context, List<Employee> activeEmployees) {
    if (activeEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun employé actif trouvé pour générer la paie.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Générer la paie'),
        content: Text(
          'Voulez-vous générer les fiches de paie pour ${_months[_selectedMonth - 1]} $_selectedYear pour les ${activeEmployees.length} employé(s) actif(s) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<PayrollBloc>().add(
                    GenerateMonthlyPayslips(
                      month: _selectedMonth,
                      year: _selectedYear,
                      activeEmployees: activeEmployees,
                    ),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('Bulletins générés pour ${_months[_selectedMonth - 1]} $_selectedYear'),
                ),
              );
            },
            child: const Text('Générer'),
          ),
        ],
      ),
    );
  }

  void _showPayslipDetails(BuildContext context, Payslip p) {
    final isPaid = p.paymentStatus == 'paid';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.employeeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${_months[p.periodMonth - 1]} ${p.periodYear}', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'PAYÉ' : 'BROUILLON',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _detailRow('Salaire de base', _formatCurrency(p.baseSalary)),
            if (p.primes > 0) _detailRow('Primes & Indemnités', '+ ${_formatCurrency(p.primes)}'),
            if (p.indemnitiesTotal > 0) _detailRow('Indemnités spécifiques', '+ ${_formatCurrency(p.indemnitiesTotal)}', color: const Color(0xFF6B46C1)),
            if (p.transportAllowance > 0) _detailRow('Indemnité de transport', '+ ${_formatCurrency(p.transportAllowance)}'),
            _detailRow('Salaire Brut', _formatCurrency(p.grossSalary), isBold: true),
            const SizedBox(height: 8),
            _detailRow('CNSS Employé (9.18%)', '- ${_formatCurrency(p.cnssDeduction)}', color: Colors.red[700]),
            if (p.taxDeduction > 0) _detailRow('Impôt IRPP', '- ${_formatCurrency(p.taxDeduction)}', color: Colors.red[700]),
            if (p.advanceSalary > 0) _detailRow('Avances sur salaire (déduites)', '- ${_formatCurrency(p.advanceSalary)}', color: Colors.red[700]),
            if (p.loanDeduction > 0) _detailRow('Remboursements de prêts (déduits)', '- ${_formatCurrency(p.loanDeduction)}', color: Colors.red[700]),
            if (p.otherDeductions > 0) _detailRow('Autres retenues', '- ${_formatCurrency(p.otherDeductions)}', color: Colors.red[700]),
            const Divider(height: 20),
            _detailRow('Net à Payer', _formatCurrency(p.netSalary), isBold: true, color: const Color(0xFF0D9488), fontSize: 16),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF1A56DB)),
                    label: const Text('Standard (PDF)', style: TextStyle(color: Color(0xFF1A56DB), fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      PayslipPdfService.instance.printPayslip(context, p, type: 'standard');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                    label: const Text('Rapport (PDF)', style: TextStyle(color: Color(0xFF1A56DB), fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      PayslipPdfService.instance.printPayslip(context, p, type: 'report');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_document, size: 16, color: Color(0xFF1A56DB)),
                label: const Text('Ouvrir la fiche de paie complète', style: TextStyle(color: Color(0xFF1A56DB), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Color(0xFF1A56DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  PayslipFormDialog.show(context, payslip: p);
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isPaid)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Marquer comme payé'),
                      onPressed: () {
                        context.read<PayrollBloc>().add(
                              UpdatePayslipStatus(
                                id: p.id,
                                newStatus: 'paid',
                                paymentDate: DateTime.now(),
                              ),
                            );
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                if (!isPaid) const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Supprimer ce bulletin',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    OfflineActionHelper.executeAction(
                      context: context,
                      action: 'delete',
                      customActionLabel: 'le bulletin de paie',
                      onConfirmed: () {
                        context.read<PayrollBloc>().add(DeletePayslip(p.id));
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLoansList() {
    return BlocBuilder<LoansBloc, LoansState>(
      builder: (context, lState) {
        if (lState is LoansLoading) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
        }

        final allLoans = lState is LoansLoaded ? lState.loans : <EmployeeLoan>[];

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
        // int paidLoansCount = 0;

        for (final l in allLoans) {
          totalLoansAmount += l.amount;
          totalRemainingAmount += l.remainingAmount;
          // if (l.status == 'paid') paidLoansCount++;
        }

        return Column(
          children: [
            // Search field for loans
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppColors.surface,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rechercher un prêt ou un employé...',
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
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5)),
                ),
              ),
            ),

            // Mini Metrics
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A56DB).withValues(alpha: 0.10),
                    const Color(0xFF0D9488).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A56DB).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Prêts Accordés',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(totalLoansAmount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A56DB),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Reste à rembourser',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(totalRemainingAmount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: totalRemainingAmount == 0 ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Loans list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 48,
                            color: AppColors.textTertiary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aucun prêt pour le moment',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A56DB),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Créer un prêt employé'),
                            onPressed: () => EmployeeLoanDialog.show(context),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final loan = filtered[idx];
                        final isPaid = loan.status == 'paid';
                        final isConfirmed = loan.status == 'confirmed';
                        final Color statusColor = isPaid
                            ? const Color(0xFF10B981)
                            : isConfirmed
                                ? const Color(0xFF1A56DB)
                                : const Color(0xFFF59E0B);

                        final paidInstallments = loan.repayments.where((r) => r.isPaid).length;
                        final totalInstallments = loan.repayments.length;
                        final progress = loan.amount > 0
                            ? ((loan.amount - loan.remainingAmount) / loan.amount).clamp(0.0, 1.0)
                            : 0.0;

                        return InkWell(
                          onTap: () => EmployeeLoanDialog.show(context, loan: loan),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                              boxShadow: AppShadows.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: Name + Status Badge
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.12),
                                      child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF1A56DB)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            loan.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            'Employé: ${loan.employeeName}',
                                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        loan.statusDisplay.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const Divider(height: 16),

                                // Amounts Info
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Montant accordé', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                        Text(_formatCurrency(loan.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('Mensualité', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                        Text('${_formatCurrency(loan.monthlyAmount)} / mois', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Reste à payer', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                        Text(
                                          _formatCurrency(loan.remainingAmount),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: loan.remainingAmount == 0 ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Progress bar
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Échéances: $paidInstallments / $totalInstallments payées',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          '${(progress * 100).toStringAsFixed(0)}% remboursé',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 5,
                                        backgroundColor: const Color(0xFFE2E8F0),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          progress >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF1A56DB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Actions row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Date: ${DateFormat('dd/MM/yyyy').format(loan.date)}',
                                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                    ),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                                 visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                          icon: const Icon(Icons.table_view_rounded, size: 14),
                                          label: const Text('Échéancier', style: TextStyle(fontSize: 11.5)),
                                          onPressed: () => EmployeeLoanDialog.show(context, loan: loan),
                                        ),
                                        IconButton(
                                          tooltip: 'Supprimer',
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            context.read<LoansBloc>().add(DeleteLoan(loan.id));
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileBatchesList(List<PayslipBatch> batches, List<Payslip> allPayslips) {
    if (batches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_special_outlined,
                  size: 36,
                  color: Color(0xFF1A56DB),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun lot de bulletins de paie',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Créez des lots de bulletins pour générer les fiches de paie de plusieurs employés en un seul clic.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau lot de paie', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => PayslipBatchDialog.show(context),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      itemCount: batches.length,
      itemBuilder: (context, index) {
        final batch = batches[index];
        final isClosed = batch.status == 'closed';
        final batchSlips = allPayslips
            .where((p) => p.batchNumber == batch.name || batch.payslipIds.contains(p.id))
            .toList();
        final totalNet = batchSlips.fold<double>(0.0, (sum, p) => sum + p.netSalary);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isClosed ? const Color(0xFFCBD5E1) : const Color(0xFF1A56DB).withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => PayslipBatchDialog.show(context, batch: batch),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Name + Status badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF1A56DB)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch.name.isEmpty ? 'Sans titre' : batch.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                batch.periodName.isEmpty ? 'Période non définie' : batch.periodName,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isClosed
                                ? const Color(0xFF64748B).withValues(alpha: 0.12)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isClosed ? const Color(0xFF64748B) : const Color(0xFFF59E0B),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isClosed ? 'Fermé' : 'Brouillon',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isClosed ? const Color(0xFF475569) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Middle: Date range & metrics
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Période de paie', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('dd/MM/yyyy').format(batch.startDate)} au ${DateFormat('dd/MM/yyyy').format(batch.endDate)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Bulletins', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            const SizedBox(height: 2),
                            Text(
                              '${batchSlips.length} fiches',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (totalNet > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Masse salariale nette:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            _formatCurrency(totalNet),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    // Bottom actions: Ouvrir / Générer, Imprimer, Supprimer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56DB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.settings_suggest_outlined, size: 15),
                          label: Text(
                            batchSlips.isEmpty ? 'Générer bulletins' : 'Ouvrir le lot',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => PayslipBatchDialog.show(context, batch: batch),
                        ),
                        Row(
                          children: [
                            if (batchSlips.isNotEmpty)
                              IconButton(
                                tooltip: 'Imprimer le lot',
                                icon: const Icon(Icons.print_outlined, size: 19, color: Color(0xFF1A56DB)),
                                onPressed: () {
                                  PayslipPdfService.instance.printBatchPayslips(
                                    context,
                                    batchSlips,
                                    type: 'report',
                                  );
                                },
                              ),
                            IconButton(
                              tooltip: 'Supprimer ce lot',
                              icon: const Icon(Icons.delete_outline, size: 19, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteBatch(context, batch),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteBatch(BuildContext context, PayslipBatch batch) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'le lot "${batch.name}"',
      onConfirmed: () {
        context.read<PayrollBloc>().add(DeletePayslipBatch(batch.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lot "${batch.name}" supprimé')),
        );
      },
    );
  }
}


