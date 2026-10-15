import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blocs/employees/employees_bloc.dart';
import '../../blocs/employees/employees_event.dart';
import '../../blocs/employees/employees_state.dart';
import '../../blocs/leaves/leaves_bloc.dart';
import '../../blocs/leaves/leaves_event.dart';
import '../../blocs/leaves/leaves_state.dart';
import '../../blocs/payroll/payroll_bloc.dart';
import '../../blocs/payroll/payroll_event.dart';
import '../../blocs/payroll/payroll_state.dart';
import '../../models/employee.dart';
import '../../models/leave_request.dart';
import '../../models/payslip.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../services/permission_service.dart';
import '../../services/enterprise_service.dart';
import '../../widgets/contract_form_dialog.dart';
import 'mobile_hr_attendance_screen.dart';

class MobileHrScreen extends StatefulWidget {
  final int initialTab;
  const MobileHrScreen({super.key, this.initialTab = 0});

  @override
  State<MobileHrScreen> createState() => _MobileHrScreenState();
}

class _MobileHrScreenState extends State<MobileHrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedLeaveFilter = 'all';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    context.read<EmployeesBloc>().add(const LoadEmployees());
    context.read<LeavesBloc>().add(const LoadLeaves());
    context.read<PayrollBloc>().add(const LoadPayslips());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final fmt = NumberFormat('#,##0.000', 'fr_FR');
    return '${fmt.format(amount)} TND';
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.tr('RH & Paie'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 20),
            tooltip: 'Nouveau Contrat',
            onPressed: () => ContractFormDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () {
              context.read<EmployeesBloc>().add(const LoadEmployees());
              context.read<LeavesBloc>().add(const LoadLeaves());
              context.read<PayrollBloc>().add(const LoadPayslips());
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A56DB),
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: const Color(0xFF1A56DB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Personnel'),
            Tab(icon: Icon(Icons.event_available_rounded, size: 18), text: 'Congés'),
            Tab(icon: Icon(Icons.access_time_rounded, size: 18), text: 'Présences'),
            Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Paie'),
          ],
        ),
      ),
      body: BlocBuilder<EmployeesBloc, EmployeesState>(
        builder: (context, empState) {
          final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];
          final activeEmployees = employees.where((e) => e.isActive).toList();

          return BlocBuilder<LeavesBloc, LeavesState>(
            builder: (context, leaveState) {
              final leaves = leaveState is LeavesLoaded ? leaveState.leaves : <LeaveRequest>[];

              return BlocBuilder<PayrollBloc, PayrollState>(
                builder: (context, payState) {
                  final payslips = payState is PayrollLoaded ? payState.payslips : <Payslip>[];

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEmployeesTab(employees),
                      _buildLeavesTab(leaves, activeEmployees),
                      const MobileHrAttendanceScreen(),
                      _buildPayrollTab(payslips, activeEmployees),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('Employé'),
        onPressed: () => _showMobileEmployeeForm(),
      );
    } else if (_tabController.index == 1) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded, size: 18),
        label: const Text('Demande'),
        onPressed: () {
          final empState = context.read<EmployeesBloc>().state;
          final emps = empState is EmployeesLoaded ? empState.employees.where((e) => e.isActive).toList() : <Employee>[];
          _showMobileLeaveForm(emps);
        },
      );
    }
    return null;
  }

  // ==========================================
  // TAB 1: EMPLOYES
  // ==========================================
  Widget _buildEmployeesTab(List<Employee> employees) {
    final filtered = employees.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.fullName.toLowerCase().contains(q) || e.jobTitle.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un collaborateur...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.badge_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('Aucun employé trouvé', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final emp = filtered[idx];
                    return Container(
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
                                radius: 18,
                                backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.12),
                                child: Text(
                                  emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    Text('${emp.jobTitle} • ${emp.department}', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => ContractFormDialog.show(context, employee: emp),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF1A56DB).withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.description_outlined, size: 10, color: Color(0xFF1A56DB)),
                                      const SizedBox(width: 3),
                                      Text(
                                        emp.contractType,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: emp.isActive ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  emp.isActive ? 'Actif' : 'Inactif',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: emp.isActive ? const Color(0xFF10B981) : Colors.red),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Text('Salaire de base : ', style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                              Text(_formatCurrency(emp.baseSalary), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Gérer Contrat',
                                icon: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF1A56DB)),
                                onPressed: () => ContractFormDialog.show(context, employee: emp),
                              ),
                              if (emp.phone != null && emp.phone!.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF2563EB)),
                                  onPressed: () => launchUrl(Uri.parse('tel:${emp.phone}')),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _showMobileEmployeeForm(employee: emp),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: CONGES
  // ==========================================
  Widget _buildLeavesTab(List<LeaveRequest> leaves, List<Employee> activeEmployees) {
    final filtered = leaves.where((l) {
      if (_selectedLeaveFilter != 'all' && l.status != _selectedLeaveFilter) return false;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _filterChip('Tous', 'all'),
              const SizedBox(width: 6),
              _filterChip('En attente', 'pending'),
              const SizedBox(width: 6),
              _filterChip('Approuvés', 'approved'),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('Aucune demande de congé', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final l = filtered[idx];
                    final isPending = l.status == 'pending';
                    Color sColor = l.status == 'approved' ? const Color(0xFF10B981) : (l.status == 'rejected' ? Colors.red : const Color(0xFFF59E0B));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(l.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: sColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text(l.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${l.leaveType} • ${l.daysCount} jour(s)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text('${_formatDate(l.startDate)} au ${_formatDate(l.endDate)}', style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                          if (l.reason != null && l.reason!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Motif : ${l.reason}', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                          ],
                          if (isPending) ...[
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10)),
                                  onPressed: () {
                                    context.read<LeavesBloc>().add(UpdateLeaveStatus(id: l.id, newStatus: 'rejected', approvedBy: PermissionService.instance.userName));
                                  },
                                  child: const Text('Rejeter', style: TextStyle(fontSize: 11.5)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                                  onPressed: () {
                                    context.read<LeavesBloc>().add(UpdateLeaveStatus(id: l.id, newStatus: 'approved', approvedBy: PermissionService.instance.userName));
                                  },
                                  child: const Text('Approuver', style: TextStyle(fontSize: 11.5)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = _selectedLeaveFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: sel ? Colors.white : AppColors.textPrimary)),
      selected: sel,
      selectedColor: const Color(0xFF7C3AED),
      onSelected: (_) => setState(() => _selectedLeaveFilter = value),
    );
  }

  // ==========================================
  // TAB 3: PAIE
  // ==========================================
  Widget _buildPayrollTab(List<Payslip> payslips, List<Employee> activeEmployees) {
    final filtered = payslips.where((p) => p.periodMonth == _selectedMonth && p.periodYear == _selectedYear).toList();

    return Column(
      children: [
        // Month Selector Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Text('Période :', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _selectedMonth,
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('Mois ${i + 1}', style: const TextStyle(fontSize: 12.5)))),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedMonth = v);
                },
              ),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: _selectedYear,
                items: [2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedYear = v);
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('Générer', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                onPressed: () {
                  context.read<PayrollBloc>().add(GenerateMonthlyPayslips(month: _selectedMonth, year: _selectedYear, activeEmployees: activeEmployees));
                },
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('Aucun bulletin pour cette période', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final p = filtered[idx];
                    final isPaid = p.paymentStatus == 'paid';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(p.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(isPaid ? 'PAYÉ' : 'BROUILLON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Brut : ${_formatCurrency(p.grossSalary)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text('Net : ${_formatCurrency(p.netSalary)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            children: [
                              Text('CNSS : -${_formatCurrency(p.cnssDeduction)}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                              const Spacer(),
                              if (!isPaid)
                                TextButton(
                                  onPressed: () {
                                    context.read<PayrollBloc>().add(UpdatePayslipStatus(id: p.id, newStatus: 'paid'));
                                  },
                                  child: const Text('Marquer payé', style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981))),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // MOBILE FORMS
  // ==========================================
  void _showMobileEmployeeForm({Employee? employee}) {
    final formKey = GlobalKey<FormState>();
    final fnCtrl = TextEditingController(text: employee?.firstName ?? '');
    final lnCtrl = TextEditingController(text: employee?.lastName ?? '');
    final phoneCtrl = TextEditingController(text: employee?.phone ?? '');
    final jobCtrl = TextEditingController(text: employee?.jobTitle ?? '');
    final salaryCtrl = TextEditingController(text: employee != null ? '${employee.baseSalary}' : '850.000');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(employee != null ? 'Modifier collaborateur' : 'Nouveau collaborateur', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fnCtrl,
                  decoration: const InputDecoration(labelText: 'Prénom *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: lnCtrl,
                  decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: jobCtrl,
                  decoration: const InputDecoration(labelText: 'Poste *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: salaryCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Salaire de base (TND) *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || double.tryParse(v) == null) ? 'Nombre requis' : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      final s = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
                      if (employee != null) {
                        final updated = employee.copyWith(
                          firstName: fnCtrl.text.trim(),
                          lastName: lnCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                          jobTitle: jobCtrl.text.trim(),
                          baseSalary: s,
                          updatedAt: DateTime.now(),
                        );
                        context.read<EmployeesBloc>().add(UpdateEmployee(updated));
                      } else {
                        final newEmp = Employee(
                          id: const Uuid().v4(),
                          code: 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                          firstName: fnCtrl.text.trim(),
                          lastName: lnCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                          jobTitle: jobCtrl.text.trim(),
                          baseSalary: s,
                          enterpriseId: EnterpriseService.instance.currentEnterpriseId,
                        );
                        context.read<EmployeesBloc>().add(AddEmployee(newEmp));
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMobileLeaveForm(List<Employee> employees) {
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter un employé actif d\'abord.')));
      return;
    }

    String empId = employees.first.id;
    String type = 'Congé payé';
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Demande de congé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: empId,
                decoration: const InputDecoration(labelText: 'Collaborateur', border: OutlineInputBorder()),
                items: employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName))).toList(),
                onChanged: (v) => setMState(() => empId = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type de congé', border: OutlineInputBorder()),
                items: ['Congé payé', 'Maladie', 'Sans solde'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setMState(() => type = v!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (p != null) setMState(() => start = p);
                      },
                      child: Text('Du ${_formatDate(start)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(context: ctx, initialDate: end, firstDate: start, lastDate: DateTime(2030));
                        if (p != null) setMState(() => end = p);
                      },
                      child: Text('Au ${_formatDate(end)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Motif', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  final emp = employees.firstWhere((e) => e.id == empId);
                  final days = (end.difference(start).inDays + 1).toDouble();
                  final req = LeaveRequest(
                    id: const Uuid().v4(),
                    employeeId: emp.id,
                    employeeName: emp.fullName,
                    leaveType: type,
                    startDate: start,
                    endDate: end,
                    daysCount: days > 0 ? days : 1.0,
                    reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
                    enterpriseId: EnterpriseService.instance.currentEnterpriseId,
                  );
                  context.read<LeavesBloc>().add(AddLeaveRequest(req));
                  Navigator.pop(ctx);
                },
                child: const Text('Envoyer la demande'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
