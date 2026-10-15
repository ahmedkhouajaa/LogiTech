import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/leaves/leaves_bloc.dart';
import '../blocs/leaves/leaves_event.dart';
import '../blocs/leaves/leaves_state.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_event.dart';
import '../blocs/employees/employees_state.dart';
import '../models/leave_request.dart';
import '../models/employee.dart';
import '../utils/constants.dart';
import '../utils/platform_utils.dart';
import '../l10n/app_localizations.dart';
import '../services/permission_service.dart';
import '../utils/offline_action_helper.dart';
import '../widgets/leave_allocation_dialog.dart';
import '../widgets/leave_request_form_dialog.dart';
import '../widgets/leave_dashboard_calendar_view.dart';
import '../widgets/public_holidays_view.dart';

/// Écran des Congés & Absences conforme à la charte et au design de LogiTech (Image 2)
/// Offre une vue épurée, responsive (Desktop, Web, Mobile) et moderne :
/// - En-tête avec bouton d'actualisation, allocation de solde et nouvelle demande
/// - Bannière de 3 indicateurs KPI (En attente, Volume jours, Taux de validation)
/// - Barre de recherche & filtres segmentés (Tous, À approuver, Validés, Refusés)
/// - Vue Tableau spacieuse et vue Cartes réactive
/// - Onglets : Demandes, Calendrier & Planning, Allocations, Jours fériés
class HrLeavesScreen extends StatefulWidget {
  const HrLeavesScreen({super.key});

  @override
  State<HrLeavesScreen> createState() => _HrLeavesScreenState();
}

class _HrLeavesScreenState extends State<HrLeavesScreen> with SingleTickerProviderStateMixin {
  bool _isFirstLoad = true;
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all'; // all, pending, approved, rejected
  String _selectedDepartment = 'Tous';
  String _selectedLeaveType = 'Tous';
  bool _isTableView = true;

  final List<String> _departments = [
    'Tous',
    'Direction',
    'Commercial',
    'Technique',
    'Finance & Comptabilité',
    'Ressources Humaines',
    'Production',
    'Logistique',
    'Marketing'
  ];

  final List<String> _leaveTypes = [
    'Tous',
    'Congés payés',
    'Congé de maladie',
    'Congé de maternité / paternité',
    'Congé sans solde',
    'Événement familial',
    'Récupération',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<LeavesBloc>().add(const LoadLeaves());
    context.read<EmployeesBloc>().add(const LoadEmployees());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<EmployeesBloc, EmployeesState>(
        builder: (context, empState) {
          final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];
          final activeEmployees = employees.where((e) => e.isActive).toList();

          return BlocConsumer<LeavesBloc, LeavesState>(
            listener: (context, state) {
              if (_isFirstLoad && (state is LeavesLoaded || state is LeavesError)) {
                setState(() {
                  _isFirstLoad = false;
                });
              }
            },
            builder: (context, state) {
              if (_isFirstLoad || state is LeavesLoading || state is LeavesInitial) {
                return Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final allLeaves = state is LeavesLoaded ? state.leaves : <LeaveRequest>[];

              final requests = allLeaves.where((l) => !l.isAllocation).toList();
              final allocations = allLeaves.where((l) => l.isAllocation).toList();

              int pendingCount = 0;
              int secondApprovalCount = 0;
              int approvedCount = 0;
              int rejectedCount = 0;
              double totalRequestDays = 0;

              for (final l in requests) {
                totalRequestDays += l.daysCount;
                if (l.isPending) pendingCount++;
                if (l.isSecondApproval) secondApprovalCount++;
                if (l.isApproved) approvedCount++;
                if (l.isRejected) rejectedCount++;
              }

              final totalToValidate = pendingCount + secondApprovalCount;

              // Filter Requests by status, department, leave type, and search
              final filteredRequests = requests.where((l) {
                if (_selectedStatus != 'all') {
                  if (_selectedStatus == 'pending' && !(l.isPending || l.isSecondApproval)) return false;
                  if (_selectedStatus == 'approved' && !l.isApproved) return false;
                  if (_selectedStatus == 'rejected' && !l.isRejected) return false;
                }

                if (_selectedDepartment != 'Tous') {
                  final emp = employees.where((e) => e.id == l.employeeId).firstOrNull;
                  final dept = emp != null && emp.department.isNotEmpty ? emp.department : (l.department ?? '');
                  if (dept != _selectedDepartment) return false;
                }

                if (_selectedLeaveType != 'Tous' && l.leaveType != _selectedLeaveType) return false;

                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final matchName = l.employeeName.toLowerCase().contains(q);
                  final matchType = l.leaveType.toLowerCase().contains(q);
                  final matchDesc = (l.description ?? '').toLowerCase().contains(q);
                  if (!matchName && !matchType && !matchDesc) return false;
                }
                return true;
              }).toList();

              // Filter Allocations
              final filteredAllocations = allocations.where((l) {
                if (_selectedStatus != 'all') {
                  if (_selectedStatus == 'pending' && !l.isPending) return false;
                  if (_selectedStatus == 'approved' && !l.isApproved) return false;
                  if (_selectedStatus == 'rejected' && !l.isRejected) return false;
                }
                if (_selectedLeaveType != 'Tous' && l.leaveType != _selectedLeaveType) return false;
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final matchName = l.employeeName.toLowerCase().contains(q);
                  final matchType = l.leaveType.toLowerCase().contains(q);
                  if (!matchName && !matchType) return false;
                }
                return true;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Toolbar matching Image 2
                  _buildHeader(context, totalToValidate),

                  // 2. Metrics Bar matching Image 2 (3 columns, 14px radius, soft icons)
                  _buildMetricsBanner(
                    pending: pendingCount,
                    secondApproval: secondApprovalCount,
                    approved: approvedCount,
                    totalDays: totalRequestDays,
                    totalRequests: requests.length,
                    activeEmployeesCount: activeEmployees.length,
                  ),

                  // 3. Tab Views Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: Demandes de congés
                        _buildRequestsTab(filteredRequests, requests, employees, pendingCount, approvedCount, rejectedCount),

                        // TAB 2: Tableau de bord & Calendrier
                        LeaveDashboardCalendarView(
                          initialEmployee: activeEmployees.isNotEmpty ? activeEmployees.first : null,
                        ),

                        // TAB 3: Allocations de congés
                        _buildAllocationsTab(filteredAllocations, employees),

                        // TAB 4: Jours fériés
                        const PublicHolidaysView(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ─── 1. HEADER TOOLBAR (IMAGE 2 STYLE) ──────────────────────────────────────
  Widget _buildHeader(BuildContext context, int totalToValidate) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Blue Squircle Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A56DB),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A56DB).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.beach_access_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),

              // Title, Pill Badge & Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.tr('Congés & Absences'),
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
                          color: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Équipe & Plannings',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A56DB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    context.tr('Gérez les demandes de congés, soldes et plannings d\'absences'),
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),

              // Activity Clock Alert Button
              _buildActivityClockButton(totalToValidate),
              const SizedBox(width: 8),

              // Refresh Button
              IconButton(
                tooltip: context.tr('Actualiser'),
                icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                onPressed: () => context.read<LeavesBloc>().add(const LoadLeaves()),
              ),
              const SizedBox(width: 10),

              // Secondary Outlined Button: "Allouer un solde"
              OutlinedButton.icon(
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 17, color: Color(0xFF1A56DB)),
                label: Text(
                  context.tr('Allouer un solde'),
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
                onPressed: () => LeaveAllocationDialog.show(context),
              ),
              const SizedBox(width: 10),

              // Primary Button: "+ Demande de congé"
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('Demande de congé')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => LeaveRequestFormDialog.show(context, isQuickMode: true),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tabs with LogiTech Primary Blue Indicator
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF1A56DB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF1A56DB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.rule_folder_rounded, size: 16), text: 'Demandes de congés'),
                Tab(icon: Icon(Icons.calendar_month_rounded, size: 16), text: 'Tableau de bord & Calendrier'),
                Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 16), text: 'Allocations de congés'),
                Tab(icon: Icon(Icons.celebration_rounded, size: 16), text: 'Jours fériés'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityClockButton(int pendingCount) {
    return PopupMenuButton<String>(
      tooltip: 'Activités en attente de validation',
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: pendingCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: pendingCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: pendingCount > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B)),
            if (pendingCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle),
                child: Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 260,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A56DB).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.beach_access_rounded, color: Color(0xFF1A56DB), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Validation des congés', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 2),
                      Text('$pendingCount demande(s) en attente', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'filter_pending',
          child: Row(
            children: const [
              Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF1A56DB)),
              SizedBox(width: 8),
              Text('Filtrer: En attente d\'approbation', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB))),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'filter_pending') {
          setState(() => _selectedStatus = 'pending');
        }
      },
    );
  }

  // ─── 2. METRICS BANNER (IMAGE 2 STYLE) ──────────────────────────────────────
  Widget _buildMetricsBanner({
    required int pending,
    required int secondApproval,
    required int approved,
    required double totalDays,
    required int totalRequests,
    required int activeEmployeesCount,
  }) {
    final validationRate = totalRequests > 0 ? ((approved / totalRequests) * 100).toStringAsFixed(0) : '100';

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
          // 1. Demandes en attente (Green)
          Expanded(
            child: _metricCard(
              title: context.tr('Demandes en Attente'),
              value: '$pending demande(s)',
              subtitle: secondApproval > 0 ? '$secondApproval en 2ème approbation' : (pending > 0 ? 'Validation requise' : 'Toutes les demandes traitées'),
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),

          // 2. Volume de jours demandés (Purple)
          Expanded(
            child: _metricCard(
              title: context.tr('Volume d\'Absences'),
              value: '${totalDays.toStringAsFixed(totalDays.truncateToDouble() == totalDays ? 0 : 1)} jours',
              subtitle: '$activeEmployeesCount collaborateurs actifs',
              icon: Icons.beach_access_rounded,
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),

          // 3. Statut des Demandes (Blue)
          Expanded(
            child: _metricCard(
              title: context.tr('Statut des Demandes'),
              value: '$approved Validée(s)',
              subtitle: '$validationRate% de taux de validation',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
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

  // ─── 3. TAB 1: DEMANDES DE CONGÉS ──────────────────────────────────────────
  Widget _buildRequestsTab(
    List<LeaveRequest> filteredRequests,
    List<LeaveRequest> allRequests,
    List<Employee> employees,
    int pendingCount,
    int approvedCount,
    int rejectedCount,
  ) {
    return Column(
      children: [
        // Filter & Search bar matching Image 2
        _buildFilterBar(),

        // Table or Cards view
        Expanded(
          child: filteredRequests.isEmpty
              ? _buildEmptyState(
                  'Aucune demande de congé trouvée',
                  'Modifiez vos critères de recherche ou enregistrez une nouvelle demande.',
                  () => LeaveRequestFormDialog.show(context, isQuickMode: true),
                )
              : (_isTableView
                  ? _buildRequestsTable(filteredRequests, employees, pendingCount, approvedCount, rejectedCount)
                  : _buildRequestsCards(filteredRequests, employees)),
        ),
      ],
    );
  }

  // ─── FILTER BAR MATCHING IMAGE 2 ───────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          // 1. Search Field
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: context.tr('Rechercher par employé, type ou motif...'),
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
          const SizedBox(width: 10),

          // 2. Department Dropdown
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
          const SizedBox(width: 8),

          // 3. Leave Type Dropdown
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
                value: _selectedLeaveType,
                items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLeaveType = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Status Segmented Buttons matching Image 2
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusBtn('Tous', 'all'),
                _statusBtn('À approuver', 'pending'),
                _statusBtn('Validés', 'approved'),
                _statusBtn('Refusés', 'rejected'),
              ],
            ),
          ),

          // 5. View Switcher (Table / Cards)
          if (PlatformUtils.isDesktop || PlatformUtils.isWeb) ...[
            const SizedBox(width: 8),
            Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Affichage Tableau',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _isTableView = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isTableView ? const Color(0xFF1A56DB) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.table_chart_outlined,
                          size: 16,
                          color: _isTableView ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Tooltip(
                    message: 'Affichage Cartes',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _isTableView = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isTableView ? const Color(0xFF1A56DB) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: !_isTableView ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBtn(String label, String value) {
    final isSelected = _selectedStatus == value;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _selectedStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A56DB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── 4. MAIN REQUESTS TABLE (IMAGE 2 DATATABLE STYLE) ──────────────────────
  Widget _buildRequestsTable(
    List<LeaveRequest> requests,
    List<Employee> employees,
    int pendingCount,
    int approvedCount,
    int rejectedCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          headingRowHeight: 46,
                          dataRowMinHeight: 54,
                          dataRowMaxHeight: 64,
                          columnSpacing: 22,
                          horizontalMargin: 16,
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Type de congé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Département', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Date début', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Date fin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Durée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Motif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                          ],
                          rows: requests.map((req) {
                            final emp = employees.where((e) => e.id == req.employeeId).firstOrNull;
                            final dept = emp != null && emp.department.isNotEmpty ? emp.department : (req.department ?? 'Général');
                            final initial = req.employeeName.trim().isNotEmpty ? req.employeeName.trim()[0].toUpperCase() : 'E';

                            return DataRow(
                              onSelectChanged: (_) => LeaveRequestFormDialog.show(context, leave: req),
                              cells: [
                                // 1. Employé (Avatar + Name + Matricule)
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.12),
                                        child: Text(
                                          initial,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB), fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req.employeeName,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                                          ),
                                          if (emp != null && emp.code.isNotEmpty)
                                            Text(
                                              emp.code,
                                              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // 2. Type de congé (Pill avec icône)
                                DataCell(
                                  _buildLeaveTypeBadge(req.leaveType),
                                ),

                                // 3. Département (Soft badge style Image 2)
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      dept,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1A56DB)),
                                    ),
                                  ),
                                ),

                                // 4. Date début
                                DataCell(
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(req.startDate),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ),

                                // 5. Date fin
                                DataCell(
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(req.endDate),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ),

                                // 6. Durée
                                DataCell(
                                  Text(
                                    req.formatDuration(),
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                ),

                                // 7. Motif
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 160),
                                    child: Text(
                                      (req.description != null && req.description!.isNotEmpty) ? req.description! : '—',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),

                                // 8. Statut (Badge avec point coloré matching Image 2 "● Actif")
                                DataCell(
                                  _buildStatusBadge(req),
                                ),

                                // 9. Actions
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (req.isSecondApproval) ...[
                                        IconButton(
                                          tooltip: 'Valider définitivement',
                                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
                                          onPressed: () {
                                            OfflineActionHelper.executeAction(
                                              context: context,
                                              action: 'validate',
                                              customActionLabel: 'la validation finale du congé',
                                              onConfirmed: () {
                                                context.read<LeavesBloc>().add(UpdateLeaveStatus(
                                                  id: req.id,
                                                  newStatus: 'approved',
                                                  approvedBy: PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Direction',
                                                ));
                                              },
                                            );
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(5),
                                        ),
                                        const SizedBox(width: 2),
                                        IconButton(
                                          tooltip: 'Refuser',
                                          icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                                          onPressed: () {
                                            OfflineActionHelper.executeAction(
                                              context: context,
                                              action: 'reject',
                                              customActionLabel: 'le refus du congé',
                                              onConfirmed: () {
                                                context.read<LeavesBloc>().add(UpdateLeaveStatus(
                                                  id: req.id,
                                                  newStatus: 'rejected',
                                                  approvedBy: PermissionService.instance.userName,
                                                ));
                                              },
                                            );
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(5),
                                        ),
                                      ] else if (req.isPending) ...[
                                        IconButton(
                                          tooltip: 'Approuver (Niv 1)',
                                          icon: const Icon(Icons.thumb_up_alt_outlined, size: 17, color: Color(0xFF1A56DB)),
                                          onPressed: () {
                                            OfflineActionHelper.executeAction(
                                              context: context,
                                              action: 'validate',
                                              customActionLabel: "l'approbation de niveau 1",
                                              onConfirmed: () {
                                                context.read<LeavesBloc>().add(UpdateLeaveStatus(
                                                  id: req.id,
                                                  newStatus: 'second_approval',
                                                  approvedBy: PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Manager',
                                                ));
                                              },
                                            );
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(5),
                                        ),
                                        const SizedBox(width: 2),
                                        IconButton(
                                          tooltip: 'Refuser',
                                          icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                                          onPressed: () {
                                            OfflineActionHelper.executeAction(
                                              context: context,
                                              action: 'reject',
                                              customActionLabel: 'le refus du congé',
                                              onConfirmed: () {
                                                context.read<LeavesBloc>().add(UpdateLeaveStatus(
                                                  id: req.id,
                                                  newStatus: 'rejected',
                                                  approvedBy: PermissionService.instance.userName,
                                                ));
                                              },
                                            );
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(5),
                                        ),
                                      ],
                                      const SizedBox(width: 2),
                                      IconButton(
                                        tooltip: 'Modifier',
                                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                                        onPressed: () => LeaveRequestFormDialog.show(context, leave: req),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(5),
                                      ),
                                      const SizedBox(width: 2),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(5),
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            LeaveRequestFormDialog.show(context, leave: req);
                                          } else if (val == 'approve_direct') {
                                            OfflineActionHelper.executeAction(
                                              context: context,
                                              action: 'validate',
                                              customActionLabel: 'la validation immédiate du congé',
                                              onConfirmed: () {
                                                context.read<LeavesBloc>().add(UpdateLeaveStatus(
                                                  id: req.id,
                                                  newStatus: 'approved',
                                                  approvedBy: PermissionService.instance.userName,
                                                ));
                                              },
                                            );
                                          } else if (val == 'delete') {
                                            OfflineActionHelper.executeAction(
                                              context: context,
                                              action: 'delete',
                                              customActionLabel: 'la demande de congé',
                                              onConfirmed: () {
                                                context.read<LeavesBloc>().add(DeleteLeaveRequest(req.id));
                                              },
                                            );
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(children: [
                                              Icon(Icons.edit_outlined, size: 16),
                                              SizedBox(width: 8),
                                              Text('Modifier la demande'),
                                            ]),
                                          ),
                                          if (!req.isApproved)
                                            const PopupMenuItem(
                                              value: 'approve_direct',
                                              child: Row(children: [
                                                Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                                                SizedBox(width: 8),
                                                Text('Valider immédiatement'),
                                              ]),
                                            ),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(children: [
                                              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Supprimer', style: TextStyle(color: Colors.red)),
                                            ]),
                                          ),
                                        ],
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
                  );
                },
              ),
            ),

            // Footer summary matching Image 2
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Text(
                    'Total : ${requests.length} demande(s)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  Text(
                    '$pendingCount en attente • $approvedCount Validée(s) • $rejectedCount Refusée(s)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 5. CARD VIEW (IMAGE 2 EMPLOYEE CARD STYLE) ────────────────────────────
  Widget _buildRequestsCards(List<LeaveRequest> requests, List<Employee> employees) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.6,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final emp = employees.where((e) => e.id == req.employeeId).firstOrNull;
            final dept = emp != null && emp.department.isNotEmpty ? emp.department : (req.department ?? 'Général');
            final initial = req.employeeName.trim().isNotEmpty ? req.employeeName.trim()[0].toUpperCase() : 'E';

            return InkWell(
              onTap: () => LeaveRequestFormDialog.show(context, leave: req),
              borderRadius: BorderRadius.circular(12),
              child: Container(
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
                          backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.12),
                          child: Text(
                            initial,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB), fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.employeeName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                dept,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(req),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        _buildLeaveTypeBadge(req.leaveType),
                        const Spacer(),
                        Text(
                          req.formatDuration(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.date_range_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(req.startDate)} ➔ ${DateFormat('dd/MM/yyyy').format(req.endDate)}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    if (req.description != null && req.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        req.description!,
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── 6. TAB 3: ALLOCATIONS DE CONGÉS ───────────────────────────────────────
  Widget _buildAllocationsTab(List<LeaveRequest> allocations, List<Employee> employees) {
    return Column(
      children: [
        // Allocations Filter Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.tr('Rechercher une allocation par collaborateur ou type...'),
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
              const SizedBox(width: 10),
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
                    value: _selectedLeaveType,
                    items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLeaveType = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Allocations Table
        Expanded(
          child: allocations.isEmpty
              ? _buildEmptyState(
                  'Aucune allocation enregistrée',
                  'Allouez des soldes de congés réguliers aux collaborateurs pour alimenter leur compte.',
                  () => LeaveAllocationDialog.show(context),
                )
              : _buildAllocationsTable(allocations, employees),
        ),
      ],
    );
  }

  Widget _buildAllocationsTable(List<LeaveRequest> allocations, List<Employee> employees) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          headingRowHeight: 46,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 60,
                          columnSpacing: 22,
                          horizontalMargin: 16,
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Type de congé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Solde alloué', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Type d\'allocation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)))),
                          ],
                          rows: allocations.map((alloc) {
                            final initial = alloc.employeeName.trim().isNotEmpty ? alloc.employeeName.trim()[0].toUpperCase() : 'E';
                            final daysStr = '${alloc.daysCount.toStringAsFixed(alloc.daysCount.truncateToDouble() == alloc.daysCount ? 0 : 1)} ${alloc.unit.toLowerCase()}';

                            return DataRow(
                              onSelectChanged: (_) => LeaveAllocationDialog.show(context, leave: alloc),
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.12),
                                        child: Text(
                                          initial,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56DB), fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(alloc.employeeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                                    ],
                                  ),
                                ),
                                DataCell(_buildLeaveTypeBadge(alloc.leaveType)),
                                DataCell(Text(daysStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)))),
                                DataCell(Text(alloc.allocationType, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                DataCell(Text(alloc.displayDescription, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                DataCell(_buildStatusBadge(alloc)),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                                    onPressed: () => LeaveAllocationDialog.show(context, leave: alloc),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Text(
                    'Total : ${allocations.length} allocation(s)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPER BADGES ─────────────────────────────────────────────────────────
  Widget _buildStatusBadge(LeaveRequest req) {
    Color dotColor;
    Color bgColor;
    Color textColor;
    String label;

    if (req.isApproved) {
      dotColor = const Color(0xFF10B981);
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
      textColor = const Color(0xFF10B981);
      label = 'Validé';
    } else if (req.isSecondApproval) {
      dotColor = const Color(0xFFEA580C);
      bgColor = const Color(0xFFEA580C).withValues(alpha: 0.1);
      textColor = const Color(0xFFEA580C);
      label = '2ème approbation';
    } else if (req.isPending) {
      dotColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFD97706).withValues(alpha: 0.1);
      textColor = const Color(0xFFD97706);
      label = 'À approuver';
    } else {
      dotColor = Colors.red;
      bgColor = Colors.red.withValues(alpha: 0.1);
      textColor = Colors.red;
      label = 'Refusé';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTypeBadge(String type) {
    Color color = const Color(0xFF1A56DB);
    IconData icon = Icons.beach_access_rounded;

    if (type.contains('maladie') || type.contains('Maladie')) {
      color = const Color(0xFFDC2626);
      icon = Icons.local_hospital_outlined;
    } else if (type.contains('maternité') || type.contains('paternité')) {
      color = const Color(0xFF7C3AED);
      icon = Icons.child_care_rounded;
    } else if (type.contains('Sans solde') || type.contains('sans solde')) {
      color = const Color(0xFF64748B);
      icon = Icons.money_off_rounded;
    } else if (type.contains('Récupération')) {
      color = const Color(0xFFD97706);
      icon = Icons.restore_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            type,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, VoidCallback onAction) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined, size: 54, color: AppColors.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Créer un enregistrement'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A56DB), foregroundColor: Colors.white),
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
