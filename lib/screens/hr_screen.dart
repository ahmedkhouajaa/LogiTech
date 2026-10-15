import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_event.dart';
import '../blocs/employees/employees_state.dart';
import '../blocs/leaves/leaves_bloc.dart';
import '../blocs/leaves/leaves_event.dart';
import '../blocs/leaves/leaves_state.dart';
import '../blocs/payroll/payroll_bloc.dart';
import '../blocs/payroll/payroll_event.dart';
import '../blocs/payroll/payroll_state.dart';
import '../models/employee.dart';
import '../models/leave_request.dart';
import '../models/payslip.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';
import '../services/permission_service.dart';
import '../services/enterprise_service.dart';
import '../widgets/contract_form_dialog.dart';

class HrScreen extends StatefulWidget {
  final int initialTab;
  const HrScreen({super.key, this.initialTab = 0});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedDepartment = 'Tous';
  String _selectedLeaveStatus = 'all';
  int _selectedPayrollMonth = DateTime.now().month;
  int _selectedPayrollYear = DateTime.now().year;

  final List<String> _departments = [
    'Tous', 'Direction', 'Commercial', 'Technique', 'Finance & Comptabilité',
    'Ressources Humaines', 'Production', 'Logistique', 'Marketing'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
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
      body: BlocBuilder<EmployeesBloc, EmployeesState>(
        builder: (context, empState) {
          final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];
          final activeEmployees = employees.where((e) => e.isActive).toList();

          return BlocBuilder<LeavesBloc, LeavesState>(
            builder: (context, leaveState) {
              final leaves = leaveState is LeavesLoaded ? leaveState.leaves : <LeaveRequest>[];
              final pendingLeaves = leaves.where((l) => l.status == 'pending').toList();

              return BlocBuilder<PayrollBloc, PayrollState>(
                builder: (context, payState) {
                  final payslips = payState is PayrollLoaded ? payState.payslips : <Payslip>[];

                  // Calculate KPIs
                  double totalMonthlyBasePayroll = 0;
                  for (final emp in activeEmployees) {
                    totalMonthlyBasePayroll += emp.baseSalary;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Top Header
                      _buildHeader(context, activeEmployees),

                      // 2. Metrics Bar
                      _buildMetricsBanner(
                        totalEmployees: employees.length,
                        activeEmployees: activeEmployees.length,
                        totalPayroll: totalMonthlyBasePayroll,
                        pendingLeaves: pendingLeaves.length,
                      ),

                      // 3. Tab Bar & Actions
                      _buildTabBar(),

                      // 4. Tab Views
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildEmployeesTab(employees),
                            _buildLeavesTab(leaves, employees),
                            _buildPayrollTab(payslips, activeEmployees),
                          ],
                        ),
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

  Widget _buildHeader(BuildContext context, List<Employee> activeEmployees) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.badge_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.tr('Ressources Humaines & Paie'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'RH Pro',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                context.tr('Gestion du personnel, suivi des congés et édition des fiches de paie'),
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          // Refresh Button
          IconButton(
            tooltip: context.tr('Actualiser'),
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: () {
              context.read<EmployeesBloc>().add(const LoadEmployees());
              context.read<LeavesBloc>().add(const LoadLeaves());
              context.read<PayrollBloc>().add(const LoadPayslips());
            },
          ),
          const SizedBox(width: 10),
          // Dynamic Action Button based on Tab
          _buildPrimaryActionButton(activeEmployees),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(List<Employee> activeEmployees) {
    if (_tabController.index == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined, size: 17, color: Color(0xFF1A56DB)),
            label: Text(
              context.tr('Nouveau contrat'),
              style: const TextStyle(
                color: Color(0xFF1A56DB),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              side: const BorderSide(color: Color(0xFF1A56DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => ContractFormDialog.show(context),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(context.tr('Nouvel employé')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => _showEmployeeDialog(),
          ),
        ],
      );
    } else if (_tabController.index == 1) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.add_task_rounded, size: 18),
        label: Text(context.tr('Demande de congé')),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: () => _showLeaveRequestDialog(activeEmployees),
      );
    } else {
      return ElevatedButton.icon(
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(context.tr('Générer la paie du mois')),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: () => _confirmGenerateMonthlyPayroll(activeEmployees),
      );
    }
  }

  Widget _buildMetricsBanner({
    required int totalEmployees,
    required int activeEmployees,
    required double totalPayroll,
    required int pendingLeaves,
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
              title: context.tr('Masse Salariale Mensuelle'),
              value: _formatCurrency(totalPayroll),
              subtitle: 'Base brute des actifs',
              icon: Icons.payments_rounded,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: _metricCard(
              title: context.tr('Effectif Actif'),
              value: '$activeEmployees / $totalEmployees',
              subtitle: 'Collaborateurs en poste',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: _metricCard(
              title: context.tr('Congés en Attente'),
              value: '$pendingLeaves',
              subtitle: pendingLeaves > 0 ? 'Demandes à valider' : 'Aucune demande en attente',
              icon: Icons.event_note_rounded,
              color: pendingLeaves > 0 ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
              bgColor: pendingLeaves > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF7C3AED),
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: const Color(0xFF7C3AED),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        tabs: [
          Tab(
            icon: const Icon(Icons.people_outline_rounded, size: 18),
            text: context.tr('Personnel (Employés)'),
          ),
          Tab(
            icon: const Icon(Icons.event_available_outlined, size: 18),
            text: context.tr('Congés & Absences'),
          ),
          Tab(
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            text: context.tr('Fiches de Paie'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: PERSONNEL (EMPLOYÉS)
  // ==========================================
  Widget _buildEmployeesTab(List<Employee> employees) {
    final filtered = employees.where((e) {
      if (_selectedDepartment != 'Tous' && e.department != _selectedDepartment) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = e.fullName.toLowerCase().contains(q);
        final matchCode = e.code.toLowerCase().contains(q);
        final matchJob = e.jobTitle.toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchJob) return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Filter Bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.tr('Rechercher un employé par nom, matricule ou poste...'),
                      hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
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
              const SizedBox(width: 12),
              // Department Filter
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDepartment,
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDepartment = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Employee Grid / Cards
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined, size: 54, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('Aucun employé trouvé'),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('Ajoutez vos collaborateurs pour gérer leurs contrats, congés et salaires.'),
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      mainAxisExtent: 220,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final emp = filtered[idx];
                      return _buildEmployeeCard(emp);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Employee emp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                child: Text(
                  emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.fullName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      emp.jobTitle,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondary),
                onSelected: (val) {
                  if (val == 'contract') {
                    ContractFormDialog.show(context, employee: emp);
                  } else if (val == 'edit') {
                    _showEmployeeDialog(employee: emp);
                  } else if (val == 'toggle') {
                    context.read<EmployeesBloc>().add(UpdateEmployee(emp.copyWith(isActive: !emp.isActive)));
                  } else if (val == 'delete') {
                    _confirmDeleteEmployee(emp);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'contract',
                    child: Row(children: const [
                      Icon(Icons.description_outlined, size: 16, color: Color(0xFF1A56DB)),
                      SizedBox(width: 8),
                      Text('Gérer Contrat'),
                    ]),
                  ),
                  PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 16), const SizedBox(width: 8), Text(context.tr('Modifier'))])),
                  PopupMenuItem(value: 'toggle', child: Row(children: [Icon(emp.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 16), const SizedBox(width: 8), Text(emp.isActive ? 'Désactiver' : 'Activer')])),
                  PopupMenuItem(value: 'delete', child: Row(children: const [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Chips Row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF1A56DB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(emp.department, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1A56DB))),
              ),
              InkWell(
                onTap: () => ContractFormDialog.show(context, employee: emp),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 10, color: Color(0xFF1A56DB)),
                      const SizedBox(width: 3),
                      Text(emp.contractType, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: emp.isActive ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  emp.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: emp.isActive ? const Color(0xFF10B981) : Colors.red),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 16),
          // Bottom Info
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Salaire de base', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
                  Text(_formatCurrency(emp.baseSalary), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Gérer contrat',
                icon: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF1A56DB)),
                onPressed: () => ContractFormDialog.show(context, employee: emp),
              ),
              if (emp.phone != null && emp.phone!.isNotEmpty)
                IconButton(
                  tooltip: 'Appeler ${emp.phone}',
                  icon: const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF2563EB)),
                  onPressed: () => launchUrl(Uri.parse('tel:${emp.phone}')),
                ),
              if (emp.email != null && emp.email!.isNotEmpty)
                IconButton(
                  tooltip: 'Email ${emp.email}',
                  icon: const Icon(Icons.email_outlined, size: 16, color: Color(0xFF1A56DB)),
                  onPressed: () => launchUrl(Uri.parse('mailto:${emp.email}')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: CONGÉS & ABSENCES
  // ==========================================
  Widget _buildLeavesTab(List<LeaveRequest> leaves, List<Employee> employees) {
    final filtered = leaves.where((l) {
      if (_selectedLeaveStatus != 'all' && l.status != _selectedLeaveStatus) return false;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Filter Row
          Row(
            children: [
              Text(context.tr('Statut :'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              _leaveStatusFilterChip('Toutes', 'all'),
              const SizedBox(width: 6),
              _leaveStatusFilterChip('En attente', 'pending'),
              const SizedBox(width: 6),
              _leaveStatusFilterChip('Approuvés', 'approved'),
              const SizedBox(width: 6),
              _leaveStatusFilterChip('Rejetés', 'rejected'),
            ],
          ),
          const SizedBox(height: 12),

          // Leave requests table
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available_outlined, size: 54, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(context.tr('Aucune demande de congé'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, idx) {
                        final leave = filtered[idx];
                        Color statusColor;
                        String statusLabel;
                        switch (leave.status) {
                          case 'approved':
                            statusColor = const Color(0xFF10B981);
                            statusLabel = 'Approuvé';
                            break;
                          case 'rejected':
                            statusColor = const Color(0xFFEF4444);
                            statusLabel = 'Rejeté';
                            break;
                          default:
                            statusColor = const Color(0xFFF59E0B);
                            statusLabel = 'En attente';
                        }

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.date_range_rounded, color: statusColor, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(leave.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
                                  Text(leave.leaveType, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_formatDate(leave.startDate)} → ${_formatDate(leave.endDate)}',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  Text('${leave.daysCount} jour(s)', style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                                ],
                              ),
                            ),
                            if (leave.reason != null && leave.reason!.isNotEmpty)
                              Expanded(
                                flex: 2,
                                child: Text(
                                  leave.reason!,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text(statusLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: statusColor)),
                            ),
                            const SizedBox(width: 12),
                            if (leave.status == 'pending') ...[
                              IconButton(
                                tooltip: 'Approuver',
                                icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                                onPressed: () {
                                  context.read<LeavesBloc>().add(UpdateLeaveStatus(
                                    id: leave.id,
                                    newStatus: 'approved',
                                    approvedBy: PermissionService.instance.userName,
                                  ));
                                },
                              ),
                              IconButton(
                                tooltip: 'Rejeter',
                                icon: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444)),
                                onPressed: () {
                                  context.read<LeavesBloc>().add(UpdateLeaveStatus(
                                    id: leave.id,
                                    newStatus: 'rejected',
                                    approvedBy: PermissionService.instance.userName,
                                  ));
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _leaveStatusFilterChip(String label, String value) {
    final isSelected = _selectedLeaveStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedLeaveStatus = value),
      selectedColor: const Color(0xFF7C3AED),
      labelStyle: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? Colors.transparent : AppColors.border)),
    );
  }

  // ==========================================
  // TAB 3: FICHES DE PAIE & RÉMUNÉRATION
  // ==========================================
  Widget _buildPayrollTab(List<Payslip> payslips, List<Employee> activeEmployees) {
    final filtered = payslips.where((p) => p.periodMonth == _selectedPayrollMonth && p.periodYear == _selectedPayrollYear).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Period Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('Période de paie :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPayrollMonth,
                    items: List.generate(12, (i) {
                      const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
                      return DropdownMenuItem(value: i + 1, child: Text(months[i], style: const TextStyle(fontSize: 13)));
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPayrollMonth = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPayrollYear,
                    items: [2025, 2026, 2027, 2028].map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPayrollYear = val);
                    },
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} bulletins générés',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Payslips List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun bulletin généré pour cette période',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: const Text('Générer la paie maintenant'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                          onPressed: () => _confirmGenerateMonthlyPayroll(activeEmployees),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 14),
                      itemBuilder: (context, idx) {
                        final p = filtered[idx];
                        return _buildPayslipRow(p);
                      },
                    ),
                  ),
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
          tooltip: 'Aperçu du bulletin',
          icon: const Icon(Icons.visibility_outlined, size: 18),
          onPressed: () => _showPayslipDetailModal(p),
        ),
        if (!isPaid)
          IconButton(
            tooltip: 'Marquer comme payé',
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
            onPressed: () {
              context.read<PayrollBloc>().add(UpdatePayslipStatus(id: p.id, newStatus: 'paid'));
            },
          ),
      ],
    );
  }

  // ==========================================
  // DIALOGS & ACTIONS
  // ==========================================
  void _showEmployeeDialog({Employee? employee}) {
    final formKey = GlobalKey<FormState>();
    final fnCtrl = TextEditingController(text: employee?.firstName ?? '');
    final lnCtrl = TextEditingController(text: employee?.lastName ?? '');
    final cinCtrl = TextEditingController(text: employee?.cin ?? '');
    final cnssCtrl = TextEditingController(text: employee?.cnssNumber ?? '');
    final phoneCtrl = TextEditingController(text: employee?.phone ?? '');
    final emailCtrl = TextEditingController(text: employee?.email ?? '');
    final jobCtrl = TextEditingController(text: employee?.jobTitle ?? '');
    final salaryCtrl = TextEditingController(text: employee != null ? '${employee.baseSalary}' : '850.000');
    final ribCtrl = TextEditingController(text: employee?.rib ?? '');
    String dept = employee?.department ?? 'Commercial';
    String contract = employee?.contractType ?? 'CDI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.badge_rounded, color: Color(0xFF7C3AED), size: 24),
              const SizedBox(width: 10),
              Text(employee != null ? context.tr('Modifier l\'employé') : context.tr('Nouvel Employé')),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: fnCtrl,
                            decoration: InputDecoration(labelText: 'Prénom *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: lnCtrl,
                            decoration: InputDecoration(labelText: 'Nom *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cinCtrl,
                            decoration: InputDecoration(labelText: 'N° CIN', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: cnssCtrl,
                            decoration: InputDecoration(labelText: 'N° CNSS', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(labelText: 'Email professionnel', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: jobCtrl,
                            decoration: InputDecoration(labelText: 'Poste / Fonction *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: dept,
                            decoration: InputDecoration(labelText: 'Département', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            items: _departments.where((d) => d != 'Tous').map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
                            onChanged: (v) => setDState(() => dept = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: contract,
                            decoration: InputDecoration(labelText: 'Type de contrat', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            items: ['CDI', 'CDD', 'SIVP', 'Stage', 'Freelance'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setDState(() => contract = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: salaryCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'Salaire de base (TND) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            validator: (v) => (v == null || double.tryParse(v) == null) ? 'Nombre valide' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ribCtrl,
                      decoration: InputDecoration(labelText: 'RIB Bancaire (20 chiffres)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  final s = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
                  if (employee != null) {
                    final updated = employee.copyWith(
                      firstName: fnCtrl.text.trim(),
                      lastName: lnCtrl.text.trim(),
                      cin: cinCtrl.text.trim().isNotEmpty ? cinCtrl.text.trim() : null,
                      cnssNumber: cnssCtrl.text.trim().isNotEmpty ? cnssCtrl.text.trim() : null,
                      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      jobTitle: jobCtrl.text.trim(),
                      department: dept,
                      contractType: contract,
                      baseSalary: s,
                      rib: ribCtrl.text.trim().isNotEmpty ? ribCtrl.text.trim() : null,
                      updatedAt: DateTime.now(),
                    );
                    context.read<EmployeesBloc>().add(UpdateEmployee(updated));
                  } else {
                    final newEmp = Employee(
                      id: const Uuid().v4(),
                      code: 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      firstName: fnCtrl.text.trim(),
                      lastName: lnCtrl.text.trim(),
                      cin: cinCtrl.text.trim().isNotEmpty ? cinCtrl.text.trim() : null,
                      cnssNumber: cnssCtrl.text.trim().isNotEmpty ? cnssCtrl.text.trim() : null,
                      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      jobTitle: jobCtrl.text.trim(),
                      department: dept,
                      contractType: contract,
                      baseSalary: s,
                      rib: ribCtrl.text.trim().isNotEmpty ? ribCtrl.text.trim() : null,
                      enterpriseId: EnterpriseService.instance.currentEnterpriseId,
                    );
                    context.read<EmployeesBloc>().add(AddEmployee(newEmp));
                  }
                  Navigator.pop(ctx);
                }
              },
              child: Text(context.tr('Enregistrer')),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveRequestDialog(List<Employee> employees) {
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter au moins un employé actif d\'abord.')));
      return;
    }

    String selectedEmpId = employees.first.id;
    String leaveType = 'Congé payé';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.event_available_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Demande de congé'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedEmpId,
                  decoration: InputDecoration(labelText: 'Employé', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  items: employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName))).toList(),
                  onChanged: (v) => setDState(() => selectedEmpId = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: leaveType,
                  decoration: InputDecoration(labelText: 'Type de congé', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  items: ['Congé payé', 'Maladie', 'Maternité / Paternité', 'Sans solde', 'Événement familial'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDState(() => leaveType = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: ctx, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (picked != null) setDState(() => startDate = picked);
                        },
                        child: Text('Du : ${_formatDate(startDate)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: ctx, initialDate: endDate, firstDate: startDate, lastDate: DateTime(2030));
                          if (picked != null) setDState(() => endDate = picked);
                        },
                        child: Text('Au : ${_formatDate(endDate)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(labelText: 'Motif / Justification', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () {
                final emp = employees.firstWhere((e) => e.id == selectedEmpId);
                final days = (endDate.difference(startDate).inDays + 1).toDouble();
                final req = LeaveRequest(
                  id: const Uuid().v4(),
                  employeeId: emp.id,
                  employeeName: emp.fullName,
                  leaveType: leaveType,
                  startDate: startDate,
                  endDate: endDate,
                  daysCount: days > 0 ? days : 1.0,
                  reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
                  enterpriseId: EnterpriseService.instance.currentEnterpriseId,
                );
                context.read<LeavesBloc>().add(AddLeaveRequest(req));
                Navigator.pop(ctx);
              },
              child: Text(context.tr('Soumettre la demande')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmGenerateMonthlyPayroll(List<Employee> activeEmployees) {
    if (activeEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun employé actif disponible pour générer la paie.')));
      return;
    }

    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    final mName = months[_selectedPayrollMonth - 1];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Génération automatique'),
          ],
        ),
        content: Text(
          'Voulez-vous générer les fiches de paie pour $mName $_selectedPayrollYear pour les ${activeEmployees.length} employé(s) actif(s) ?\n\nLes montants (salaire de base, indemnité de transport, cotisations CNSS de 9.18% et net à payer) seront calculés automatiquement.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PayrollBloc>().add(GenerateMonthlyPayslips(
                month: _selectedPayrollMonth,
                year: _selectedPayrollYear,
                activeEmployees: activeEmployees,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fiches de paie de $mName $_selectedPayrollYear générées avec succès !')),
              );
            },
            child: const Text('Confirmer la génération'),
          ),
        ],
      ),
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
              if (p.otherDeductions > 0) _payslipItemRow('Autres retenues / Avances', '- ${_formatCurrency(p.otherDeductions)}', color: Colors.red),
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

  void _confirmDeleteEmployee(Employee emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous supprimer l\'employé "${emp.fullName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<EmployeesBloc>().add(DeleteEmployee(emp.id));
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
