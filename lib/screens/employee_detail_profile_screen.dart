import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../models/employee.dart';
import '../models/employee_contract.dart';
import '../models/leave_request.dart';
import '../models/attendance.dart';
import '../models/payslip.dart';
import '../utils/constants.dart';
import '../utils/platform_utils.dart';
import '../l10n/app_localizations.dart';
import '../widgets/employee_form_dialog.dart';
import '../widgets/contract_form_dialog.dart';
import '../services/enterprise_service.dart';
import '../services/payslip_pdf_service.dart';

/// Écran complet de Dossier Collaborateur / Profil Employé 360°
/// Conforme à la maquette Odoo & LogiTech (Images 2 et 3 fournies par l'utilisateur).
/// Fonctionne de façon responsive sur Desktop (Windows/macOS/Linux), Web et Android.
class EmployeeDetailProfileScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeDetailProfileScreen({
    super.key,
    required this.employee,
  });

  @override
  State<EmployeeDetailProfileScreen> createState() => _EmployeeDetailProfileScreenState();
}

class _EmployeeDetailProfileScreenState extends State<EmployeeDetailProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Employee _currentEmployee;

  // Données liées chargées dynamiquement
  List<EmployeeContract> _contracts = [];
  EmployeeContract? _activeContract;
  List<LeaveRequest> _leaves = [];
  List<Attendance> _attendances = [];
  List<Payslip> _payslips = [];

  bool _isLoadingLinkedData = true;
  double _calculatedLeaveBalance = 0.0;

  final List<String> _tabLabels = [
    'Aperçu',
    'Identité',
    'Contrat',
    'Fin de contrat',
    'Temps & absence',
    'Pointage',
    'Rémunération',
    'Aperçu bulletin',
    'Documents',
  ];

  @override
  void initState() {
    super.initState();
    _currentEmployee = widget.employee;
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _loadLinkedEmployeeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedEmployeeData() async {
    setState(() => _isLoadingLinkedData = true);
    final empId = _currentEmployee.id;

    try {
      // 1. Contrats
      Query contractQ = FirebaseFirestore.instance
          .collection('employee_contracts')
          .where('employeeId', isEqualTo: empId);
      final contractSnap = await contractQ.get();
      final contracts = <EmployeeContract>[];
      for (final doc in contractSnap.docs) {
        final d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        d['id'] = doc.id;
        if (d['is_deleted'] == true || d['isDeleted'] == true) continue;
        try {
          contracts.add(EmployeeContract.fromMap(d));
        } catch (_) {}
      }
      contracts.sort((a, b) => b.startDate.compareTo(a.startDate));

      // 2. Congés
      Query leaveQ = FirebaseFirestore.instance
          .collection('leave_requests')
          .where('employeeId', isEqualTo: empId);
      final leaveSnap = await leaveQ.get();
      final leaves = <LeaveRequest>[];
      double allocations = 0.0;
      double takenLeaves = 0.0;

      for (final doc in leaveSnap.docs) {
        final d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        d['id'] = doc.id;
        if (d['is_deleted'] == true || d['isDeleted'] == true) continue;
        try {
          final lr = LeaveRequest.fromMap(d);
          leaves.add(lr);
          if (lr.isAllocation && lr.status == 'approved') {
            allocations += lr.daysCount;
          } else if (!lr.isAllocation && lr.status == 'approved') {
            takenLeaves += lr.daysCount;
          }
        } catch (_) {}
      }
      leaves.sort((a, b) => b.startDate.compareTo(a.startDate));
      final computedBalance = allocations - takenLeaves;

      // 3. Pointages / Présences
      Query attQ = FirebaseFirestore.instance
          .collection('attendances')
          .where('employeeId', isEqualTo: empId);
      final attSnap = await attQ.get();
      final attendances = <Attendance>[];
      for (final doc in attSnap.docs) {
        final d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        d['id'] = doc.id;
        if (d['is_deleted'] == true || d['isDeleted'] == true) continue;
        try {
          attendances.add(Attendance.fromMap(d));
        } catch (_) {}
      }
      attendances.sort((a, b) => b.checkIn.compareTo(a.checkIn));

      // 4. Bulletins de paie
      Query payQ = FirebaseFirestore.instance
          .collection('payslips')
          .where('employeeId', isEqualTo: empId);
      final paySnap = await payQ.get();
      final payslips = <Payslip>[];
      for (final doc in paySnap.docs) {
        final d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        d['id'] = doc.id;
        if (d['is_deleted'] == true || d['isDeleted'] == true) continue;
        try {
          payslips.add(Payslip.fromMap(d));
        } catch (_) {}
      }
      payslips.sort((a, b) => (b.periodYear * 12 + b.periodMonth)
          .compareTo(a.periodYear * 12 + a.periodMonth));

      if (mounted) {
        setState(() {
          _contracts = contracts;
          _activeContract = contracts.isNotEmpty ? contracts.first : null;
          _leaves = leaves;
          _calculatedLeaveBalance = computedBalance;
          _attendances = attendances;
          _payslips = payslips;
          _isLoadingLinkedData = false;
        });
      }
    } catch (e) {
      debugPrint('[EmployeeDetailProfile] Error loading linked data: $e');
      if (mounted) {
        setState(() => _isLoadingLinkedData = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    final fmt = NumberFormat('#,##0.000', 'fr_FR');
    return '${fmt.format(amount)} TND';
  }

  String _calculateSeniority(DateTime hireDate) {
    final now = DateTime.now();
    final diff = now.difference(hireDate);
    if (diff.isNegative) {
      final days = diff.inDays.abs();
      return '-$days jour${days > 1 ? 's' : ''}';
    }
    final days = diff.inDays;
    if (days < 30) {
      return '$days jour${days > 1 ? 's' : ''}';
    }
    final months = (days / 30.44).floor();
    if (months < 12) {
      return '$months mois';
    }
    final years = (days / 365.25).floor();
    final remMonths = ((days % 365.25) / 30.44).floor();
    if (remMonths == 0) {
      return '$years an${years > 1 ? 's' : ''}';
    }
    return '$years an${years > 1 ? 's' : ''} $remMonths m';
  }

  void _openEditDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<EmployeesBloc>(),
        child: EmployeeFormDialog(employee: _currentEmployee),
      ),
    );
  }

  void _openNewContractDialog() {
    ContractFormDialog.show(
      context,
      employee: _currentEmployee,
    ).then((_) => _loadLinkedEmployeeData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;

    return BlocListener<EmployeesBloc, EmployeesState>(
      listener: (context, state) {
        if (state is EmployeesLoaded) {
          final updated = state.employees.where((e) => e.id == _currentEmployee.id).firstOrNull;
          if (updated != null && mounted) {
            setState(() => _currentEmployee = updated);
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // Top Profile Card & Actions Header
              _buildTopHeader(isDark, isDesktopOrWeb),

              // Tab Bar Navigation
              _buildTabBar(isDark, isDesktopOrWeb),

              if (_isLoadingLinkedData)
                const LinearProgressIndicator(minHeight: 2.5, backgroundColor: Colors.transparent),

              // Tab Views Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(isDark, isDesktopOrWeb),
                    _buildIdentityTab(isDark, isDesktopOrWeb),
                    _buildContractsTab(isDark, isDesktopOrWeb),
                    _buildEndOfContractTab(isDark, isDesktopOrWeb),
                    _buildLeavesTab(isDark, isDesktopOrWeb),
                    _buildAttendanceTab(isDark, isDesktopOrWeb),
                    _buildRemunerationTab(isDark, isDesktopOrWeb),
                    _buildPayslipsTab(isDark, isDesktopOrWeb),
                    _buildDocumentsTab(isDark, isDesktopOrWeb),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TOP HEADER ────────────────────────────────────────────────────────────
  Widget _buildTopHeader(bool isDark, bool isDesktopOrWeb) {
    final emp = _currentEmployee;
    final ent = EnterpriseService.instance.currentEnterprise;

    final contractTitle = _activeContract != null
        ? '${_activeContract!.contractType} - ${DateFormat('dd/MM/yyyy').format(_activeContract!.startDate)} - ${_activeContract!.status.toUpperCase()}'
        : '${emp.contractType} - ${DateFormat('dd/MM/yyyy').format(emp.hireDate)} - ${emp.isActive ? 'ACTIVE' : 'INACTIVE'}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktopOrWeb ? 28 : 16,
        vertical: isDesktopOrWeb ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Back Button & Badges & Action Buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: context.tr('Retour aux employés'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 14),

              // Badges: Statut, Type Contrat, Régime
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: emp.isActive
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  emp.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: emp.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  emp.contractType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _activeContract?.workingHoursType ?? 'Temps plein',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),

              const Spacer(),

              // Quick Actions
              OutlinedButton.icon(
                onPressed: _openEditDialog,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(context.tr('Modifier')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _openNewContractDialog,
                icon: const Icon(Icons.description_outlined, size: 15),
                label: Text(context.tr('Nouveau contrat')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Row 2: Avatar, Name, Job title, Matricule, Tags
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: isDesktopOrWeb ? 26 : 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: emp.photoUrl != null && emp.photoUrl!.isNotEmpty
                    ? NetworkImage(emp.photoUrl!)
                    : null,
                child: emp.photoUrl == null || emp.photoUrl!.isEmpty
                    ? Text(
                        emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                        style: TextStyle(
                          fontSize: isDesktopOrWeb ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          emp.fullName,
                          style: TextStyle(
                            fontSize: isDesktopOrWeb ? 20 : 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (emp.code.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              emp.code,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${emp.jobTitle.isNotEmpty ? emp.jobTitle : 'Employé'}  •  ${emp.department}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Row 3: Meta selector pills (Contrat, Manager, Établissement) matching Image 2 top
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              // Contrat selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Contrat'),
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                        Text(
                          contractTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ],
                ),
              ),

              // Manager info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Manager'),
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emp.manager != null && emp.manager!.isNotEmpty ? emp.manager! : 'Non assigné',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _openEditDialog,
                          child: Text(
                            context.tr('Modifier'),
                            style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Établissement
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Établissement'),
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ),
                    Text(
                      ent?.name ?? 'Siège Principal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB BAR ───────────────────────────────────────────────────────────────
  Widget _buildTabBar(bool isDark, bool isDesktopOrWeb) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF10B981), // Style vert / contrasté de l'onglet actif (Image 2)
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        indicatorColor: const Color(0xFF10B981),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: _tabLabels.map((lbl) => Tab(text: context.tr(lbl))).toList(),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1 : APERÇU (Overview - Matches Images 2 & 3)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewTab(bool isDark, bool isDesktopOrWeb) {
    final emp = _currentEmployee;
    final contract = _activeContract;
    final seniority = _calculateSeniority(contract?.startDate ?? emp.hireDate);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 KPI Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricKpiCard(
                  icon: Icons.account_balance_wallet_outlined,
                  value: _formatCurrency(emp.baseSalary),
                  label: 'Salaire brut',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricKpiCard(
                  icon: Icons.calendar_month_outlined,
                  value: '${_calculatedLeaveBalance.toStringAsFixed(_calculatedLeaveBalance.truncateToDouble() == _calculatedLeaveBalance ? 0 : 1)} j',
                  label: 'Solde congés',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricKpiCard(
                  icon: Icons.person_outline_rounded,
                  value: seniority,
                  label: 'Ancienneté',
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Two Columns Layout for Cards: "Infos rapides" & "Contrat actif"
          if (isDesktopOrWeb)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildQuickInfoCard(isDark, emp)),
                const SizedBox(width: 20),
                Expanded(child: _buildActiveContractCard(isDark, emp, contract)),
              ],
            )
          else ...[
            _buildQuickInfoCard(isDark, emp),
            const SizedBox(height: 16),
            _buildActiveContractCard(isDark, emp, contract),
          ],

          const SizedBox(height: 20),

          // Card: "Rémunération"
          _buildCompensationCard(isDark, emp, contract),
        ],
      ),
    );
  }

  Widget _buildMetricKpiCard({
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: isDark ? Colors.white70 : const Color(0xFF334155)),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            context.tr(label),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoCard(bool isDark, Employee emp) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Infos rapides'),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Email professionnel', emp.workEmail ?? emp.email ?? '—', isDark),
          _buildInfoRow('Téléphone', emp.workMobile ?? emp.phone ?? '—', isDark),
          _buildInfoRow('Date d\'embauche', DateFormat('dd/MM/yyyy').format(emp.hireDate), isDark),
          _buildInfoRow('Service', emp.department, isDark),
        ],
      ),
    );
  }

  Widget _buildActiveContractCard(bool isDark, Employee emp, EmployeeContract? contract) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Contrat actif'),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Type', contract?.contractType ?? emp.contractType, isDark),
          _buildInfoRow('Numéro', contract?.reference ?? 'CTR-${emp.code}', isDark),
          _buildInfoRow('Depuis', DateFormat('dd/MM/yyyy').format(contract?.startDate ?? emp.hireDate), isDark),
          _buildInfoRow('Heures/semaine', contract?.workingHoursStandard ?? 'Standard 40 h', isDark),
        ],
      ),
    );
  }

  Widget _buildCompensationCard(bool isDark, Employee emp, EmployeeContract? contract) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Rémunération'),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Salaire de base', '${_formatCurrency(emp.baseSalary)} / mois', isDark),
          _buildInfoRow('Indemnité de transport', '60,000 TND', isDark),
          _buildInfoRow('Ticket restaurant', '—', isDark),
          _buildInfoRow('Rémunération variable', 'Non éligible', isDark),
          _buildInfoRow('Mode de paiement', emp.paymentMethod, isDark),
          _buildInfoRow('Compte bancaire / RIB', emp.rib ?? '—', isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.tr(label),
            style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2 : IDENTITÉ (Civil status, Family, Identity docs, Private contact)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildIdentityTab(bool isDark, bool isDesktopOrWeb) {
    final emp = _currentEmployee;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionContainer(
            title: 'État civil & Nationalité',
            isDark: isDark,
            children: [
              _buildInfoRow('Genre', emp.gender ?? 'Non spécifié', isDark),
              _buildInfoRow('Nationalité', emp.nationality ?? 'Tunisienne', isDark),
              _buildInfoRow('Date de naissance', emp.birthDate != null ? DateFormat('dd/MM/yyyy').format(emp.birthDate!) : '—', isDark),
              _buildInfoRow('Lieu de naissance', emp.birthPlace ?? '—', isDark),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionContainer(
            title: 'Situation familiale',
            isDark: isDark,
            children: [
              _buildInfoRow('État matrimonial', emp.maritalStatus ?? 'Célibataire', isDark),
              _buildInfoRow('Chef de famille', emp.isHeadOfFamily ? 'Oui' : 'Non', isDark),
              _buildInfoRow('Nom du conjoint', emp.spouseName ?? '—', isDark),
              _buildInfoRow('Nombre d\'enfants à charge', emp.childrenCount.toString(), isDark),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionContainer(
            title: 'Pièces d\'identité & Sécurité sociale',
            isDark: isDark,
            children: [
              _buildInfoRow('Carte d\'Identité Nationale (CIN)', emp.cin ?? '—', isDark),
              _buildInfoRow('Numéro CNSS', emp.cnssNumber ?? '—', isDark),
              _buildInfoRow('N° de Passeport', emp.passportNumber ?? '—', isDark),
              _buildInfoRow('Permis de travail', emp.workPermitNumber ?? '—', isDark),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionContainer(
            title: 'Adresse privée & Urgence',
            isDark: isDark,
            children: [
              _buildInfoRow('Adresse personnelle', emp.address ?? '—', isDark),
              _buildInfoRow('Ville / Région', '${emp.city ?? ''} ${emp.privateAddressState ?? ''}'.trim().isNotEmpty ? '${emp.city ?? ''} ${emp.privateAddressState ?? ''}'.trim() : '—', isDark),
              _buildInfoRow('Téléphone personnel', emp.personalPhone ?? '—', isDark),
              _buildInfoRow('Email personnel', emp.personalEmail ?? '—', isDark),
              _buildInfoRow('Contact d\'urgence', '${emp.emergencyContactName ?? '—'} (${emp.emergencyContactPhone ?? '—'})', isDark),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3 : CONTRATS (Full contracts history)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildContractsTab(bool isDark, bool isDesktopOrWeb) {
    if (_contracts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 48, color: isDark ? Colors.white38 : Colors.black26),
            const SizedBox(height: 12),
            Text(context.tr('Aucun contrat enregistré pour cet employé')),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openNewContractDialog,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Créer un contrat')),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      itemCount: _contracts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, idx) {
        final c = _contracts[idx];
        final isActive = c.status == 'active';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c.reference,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive ? const Color(0xFF10B981) : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${c.contractType}  •  ${c.jobTitle}  •  ${c.department}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Text('Période : ${DateFormat('dd/MM/yyyy').format(c.startDate)} - ${c.endDate != null ? DateFormat('dd/MM/yyyy').format(c.endDate!) : 'Indéterminée'}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text('Salaire brut mensuel : ${_formatCurrency(c.wage)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 4 : FIN DE CONTRAT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEndOfContractTab(bool isDark, bool isDesktopOrWeb) {
    final contract = _activeContract;
    final endDate = contract?.endDate;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionContainer(
            title: 'Modalités de sortie & Fin de contrat',
            isDark: isDark,
            children: [
              _buildInfoRow('Date de fin contractuelle', endDate != null ? DateFormat('dd/MM/yyyy').format(endDate) : 'Contrat à durée indéterminée (Pas de terme)', isDark),
              _buildInfoRow('Période de préavis légale', '1 mois (ou selon convention collective)', isDark),
              _buildInfoRow('Solde de tout compte estimé', '${_formatCurrency(_currentEmployee.baseSalary)} (Salaire + Congés payés)', isDark),
              _buildInfoRow('Restitution matériel & badge', 'À clôturer lors du départ', isDark),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 5 : TEMPS & ABSENCE (Congés)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLeavesTab(bool isDark, bool isDesktopOrWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.beach_access_rounded, color: Color(0xFF0284C7), size: 28),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_calculatedLeaveBalance.toStringAsFixed(1)} Jours restants',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Solde actuel de congés payés disponible',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('Historique des demandes de congés'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_leaves.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(context.tr('Aucune absence enregistrée pour ce collaborateur.')),
            )
          else
            ..._leaves.map((l) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.leaveType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${DateFormat('dd/MM/yyyy').format(l.startDate)} au ${DateFormat('dd/MM/yyyy').format(l.endDate)}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    Text('${l.daysCount} j', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 6 : POINTAGE (Attendances)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAttendanceTab(bool isDark, bool isDesktopOrWeb) {
    if (_attendances.isEmpty) {
      return Center(
        child: Text(context.tr('Aucun pointage enregistré pour cet employé.')),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      itemCount: _attendances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final a = _attendances[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd/MM/yyyy').format(a.checkIn), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Entrée: ${DateFormat('HH:mm').format(a.checkIn)} - Sortie: ${a.checkOut != null ? DateFormat('HH:mm').format(a.checkOut!) : 'En cours'}', style: const TextStyle(fontSize: 11)),
                ],
              ),
              Text('${a.workedHours.toStringAsFixed(1)} h', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 7 : RÉMUNÉRATION (Détail salarial conforme Tunisie)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRemunerationTab(bool isDark, bool isDesktopOrWeb) {
    final base = _currentEmployee.baseSalary;
    final cnssEmp = base * 0.0918;
    final cnssPat = base * 0.1657;
    final transport = 60.0;
    final taxable = (base + transport) - cnssEmp;
    final css = taxable * 0.01;
    final netEstime = taxable - css;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionContainer(
            title: 'Structure Salariale & Cotisations (Simulation Tunisie)',
            isDark: isDark,
            children: [
              _buildInfoRow('Salaire de base mensuel', _formatCurrency(base), isDark),
              _buildInfoRow('Indemnité de transport légale', _formatCurrency(transport), isDark),
              const Divider(height: 16),
              _buildInfoRow('Cotisation CNSS Employé (9.18%)', '- ${_formatCurrency(cnssEmp)}', isDark),
              _buildInfoRow('Contribution Sociale de Solidarité CSS (1%)', '- ${_formatCurrency(css)}', isDark),
              _buildInfoRow('Cotisation CNSS Patronale (16.57%)', _formatCurrency(cnssPat), isDark),
              const Divider(height: 16),
              _buildInfoRow('Salaire Net Estimé (avant IRPP)', _formatCurrency(netEstime), isDark),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionContainer(
            title: 'Coordonnées Bancaires',
            isDark: isDark,
            children: [
              _buildInfoRow('Mode de règlement', _currentEmployee.paymentMethod, isDark),
              _buildInfoRow('Numéro de compte RIB', _currentEmployee.rib ?? '—', isDark),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 8 : APERÇU BULLETIN (Payslips)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPayslipsTab(bool isDark, bool isDesktopOrWeb) {
    if (_payslips.isEmpty) {
      return Center(
        child: Text(context.tr('Aucun bulletin de paie généré pour le moment.')),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      itemCount: _payslips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final p = _payslips[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Période : ${p.periodMonth}/${p.periodYear}  •  Net: ${_formatCurrency(p.netSalary)}', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Imprimer / Aperçu PDF',
                icon: const Icon(Icons.print_outlined, size: 20),
                onPressed: () {
                  PayslipPdfService.instance.printPayslip(
                    context,
                    p,
                    type: 'standard',
                    employee: _currentEmployee,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 9 : DOCUMENTS (Dossier administratif)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDocumentsTab(bool isDark, bool isDesktopOrWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktopOrWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionContainer(
            title: 'Dossier administratif & Pièces jointes',
            isDark: isDark,
            children: [
              _buildInfoRow('Contrat de travail signé', _activeContract != null ? 'Disponible (PDF)' : 'Non rattaché', isDark),
              _buildInfoRow('Copie CIN', _currentEmployee.cin != null ? 'Renseignée' : 'Non fournie', isDark),
              _buildInfoRow('Attestation CNSS', _currentEmployee.cnssNumber != null ? 'Numéro vérifié' : 'Non fournie', isDark),
              _buildInfoRow('Relevé d\'Identité Bancaire (RIB)', _currentEmployee.rib != null ? 'Enregistré' : 'Non fourni', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(title),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
