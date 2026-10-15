import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/attendance/attendance_bloc.dart';
import '../blocs/attendance/attendance_event.dart';
import '../blocs/attendance/attendance_state.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_event.dart';
import '../blocs/employees/employees_state.dart';
import '../blocs/leaves/leaves_bloc.dart';
import '../blocs/leaves/leaves_event.dart';
import '../blocs/leaves/leaves_state.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../models/leave_request.dart';
import '../services/attendance_tolerance_service.dart';
import '../services/overtime_rate_service.dart';
import '../widgets/attendance_form_dialog.dart';
import '../widgets/employee_form_dialog.dart';
import '../widgets/leave_request_form_dialog.dart';
import '../widgets/public_holidays_view.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

/// Écran principal des Présences / Pointages (Screenshot 1)
/// Groupement par employé, calcul des totaux d'heures de travail & heures supplémentaires,
/// et liaison intelligente avec les fiches employés et les congés.
class HrAttendanceScreen extends StatefulWidget {
  const HrAttendanceScreen({super.key});

  @override
  State<HrAttendanceScreen> createState() => _HrAttendanceScreenState();
}

class _HrAttendanceScreenState extends State<HrAttendanceScreen> {
  bool _isFirstLoad = true;
  static const Color _odooPurple = Color(0xFF1A56DB);

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _groupByEmployee = true; // Mode groupé par défaut (Screenshot 1)
  final Set<String> _collapsedGroups = {}; // IDs des employés repliés
  final Set<String> _selectedAttendanceIds = {};

  String _timeFilter = 'all'; // all, today, this_week, this_month, leave_conflicts

  @override
  void initState() {
    super.initState();
    context.read<AttendanceBloc>().add(const LoadAttendances());
    context.read<EmployeesBloc>().add(const LoadEmployees());
    context.read<LeavesBloc>().add(const LoadLeaves());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isDateInFilter(DateTime date) {
    final now = DateTime.now();
    switch (_timeFilter) {
      case 'today':
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case 'this_week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
        return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            date.isBefore(endOfWeek);
      case 'this_month':
        return date.year == now.year && date.month == now.month;
      default:
        return true;
    }
  }

  LeaveRequest? _findLeaveForAttendance(Attendance att, List<LeaveRequest> allLeaves) {
    final checkDate = DateTime(att.checkIn.year, att.checkIn.month, att.checkIn.day);
    for (final l in allLeaves) {
      if (l.employeeId == att.employeeId && !l.isDeleted) {
        final start = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
        final end = DateTime(l.endDate.year, l.endDate.month, l.endDate.day, 23, 59, 59);
        if (!checkDate.isBefore(start) && !checkDate.isAfter(end)) {
          return l;
        }
      }
    }
    return null;
  }

  void _openQuickCheckInModal(BuildContext context, List<Employee> activeEmployees) {
    if (activeEmployees.isEmpty) return;
    String selectedEmpId = activeEmployees.first.id;

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final emp = activeEmployees.firstWhere((e) => e.id == selectedEmpId);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: const Row(
                children: [
                  Icon(Icons.login_rounded, color: _odooPurple, size: 22),
                  SizedBox(width: 8),
                  Text('Pointer l\'arrivée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sélectionner l\'employé pour le pointage immédiat :', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 3, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedEmpId,
                        isExpanded: true,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                        borderRadius: BorderRadius.circular(8),
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        items: activeEmployees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName))).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedEmpId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Heure d\'arrivée : ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _odooPurple),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _odooPurple, foregroundColor: Colors.white),
                  onPressed: isSubmitting
                      ? null
                      : () {
                          setDlgState(() => isSubmitting = true);
                          final isOnline = ConnectivityService.instance.isOnline;
                          context.read<AttendanceBloc>().add(
                                QuickCheckIn(
                                  employeeId: emp.id,
                                  employeeName: emp.fullName,
                                  employeeAvatar: emp.photoUrl,
                                ),
                              );
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: isOnline ? AppColors.success : AppColors.warning,
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
                                        ? 'Arrivée pointée pour ${emp.fullName}'
                                        : 'Pointage enregistré hors ligne pour ${emp.fullName} (en attente de sync)',
                                  ),
                                ],
                              ),
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
                      : const Text('Confirmer le pointage'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];
        final activeEmployees = employees.where((e) => e.isActive).toList();

        return BlocBuilder<LeavesBloc, LeavesState>(
          builder: (context, leavesState) {
            final allLeaves = leavesState is LeavesLoaded ? leavesState.leaves : <LeaveRequest>[];

            return BlocConsumer<AttendanceBloc, AttendanceState>(
              listener: (context, state) {
                if (_isFirstLoad && (state is AttendanceLoaded || state is AttendanceError)) {
                  setState(() {
                    _isFirstLoad = false;
                  });
                }
              },
              builder: (context, state) {
                if (_isFirstLoad || state is AttendanceLoading || state is AttendanceInitial) {
                  return Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final allAttendances = state is AttendanceLoaded ? state.attendances : <Attendance>[];

                // Filtering
                final filtered = allAttendances.where((a) {
                  if (!_isDateInFilter(a.checkIn)) return false;

                  if (_timeFilter == 'leave_conflicts') {
                    final hasLeave = _findLeaveForAttendance(a, allLeaves) != null;
                    if (!hasLeave) return false;
                  }

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchName = a.employeeName.toLowerCase().contains(q);
                    final matchMode = a.mode.toLowerCase().contains(q);
                    if (!matchName && !matchMode) return false;
                  }
                  return true;
                }).toList();

                // Group by employee if requested
                final Map<String, List<Attendance>> grouped = {};
                for (final a in filtered) {
                  grouped.putIfAbsent(a.employeeName, () => []).add(a);
                }

                // Global metrics
                double totalWorked = 0.0;
                double totalOvertime = 0.0;
                for (final a in filtered) {
                  totalWorked += a.workedHours;
                  totalOvertime += a.overtimeHours;
                }

                return Scaffold(
                  backgroundColor: const Color(0xFFF8FAFC),
                  body: Column(
                    children: [
                      // Top Odoo Action Bar (Screenshot 1)
                      _buildTopBar(context, grouped.length, activeEmployees),

                      // Filter and Quick metrics ribbon
                      _buildFilterAndMetricsRibbon(filtered.length, totalWorked, totalOvertime, allLeaves),

                      // Main Table / Groups View
                      Expanded(
                        child: state is AttendanceLoading && allAttendances.isEmpty
                            ? const Center(child: CircularProgressIndicator(color: _odooPurple))
                            : filtered.isEmpty
                                ? _buildEmptyState(context, activeEmployees)
                                : _groupByEmployee
                                    ? _buildGroupedTableView(grouped, allLeaves, employees)
                                    : _buildFlatTableView(filtered, allLeaves, employees),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, int groupCount, List<Employee> activeEmployees) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isWide = w >= 1180;
        final isMedium = w >= 940 && w < 1180;
        final isCompact = w < 940;
        final isVeryCompact = w < 760;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              // Left: [Nouveau] button + Title "Présences ⚙"
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _odooPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 36),
                      padding: EdgeInsets.symmetric(horizontal: isVeryCompact ? 8 : 12, vertical: 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: isVeryCompact
                        ? const SizedBox.shrink()
                        : const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => AttendanceFormDialog.show(context),
                  ),
                  if (!isVeryCompact) ...[
                    const SizedBox(width: 10),
                    const Text(
                      'Présences',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF1E293B)),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Tolérances de pointage (Odoo)',
                    icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      AttendanceToleranceService.showToleranceSettingsDialog(
                        context,
                        onSaved: () => setState(() {}),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Options',
                    icon: const Icon(Icons.settings_outlined, size: 17, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (val) {
                      if (val == 'quick_check_in') {
                        _openQuickCheckInModal(context, activeEmployees);
                      } else if (val == 'toggle_group') {
                        setState(() => _groupByEmployee = !_groupByEmployee);
                      } else if (val == 'tolerance_settings') {
                        AttendanceToleranceService.showToleranceSettingsDialog(
                          context,
                          onSaved: () => setState(() {}),
                        );
                      } else if (val == 'overtime_rates_settings') {
                        _showOvertimeRatesManagerDialog(context);
                      } else if (val == 'public_holidays_settings') {
                        PublicHolidaysView.showAsDialog(context);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'quick_check_in',
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app_outlined, size: 16, color: _odooPurple),
                            SizedBox(width: 8),
                            Text('Pointer l\'arrivée rapide', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_group',
                        child: Row(
                          children: [
                            Icon(_groupByEmployee ? Icons.view_list : Icons.table_rows, size: 16, color: _odooPurple),
                            SizedBox(width: 8),
                            Text(_groupByEmployee ? 'Vue liste plate' : 'Grouper par Employé', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'tolerance_settings',
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 16, color: _odooPurple),
                            SizedBox(width: 8),
                            Text('Tolérance d\'entrée et sortie', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'overtime_rates_settings',
                        child: Row(
                          children: [
                            Icon(Icons.more_time_rounded, size: 16, color: _odooPurple),
                            SizedBox(width: 8),
                            Text('Taux Heures Supplémentaires', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'public_holidays_settings',
                        child: Row(
                          children: [
                            Icon(Icons.celebration_rounded, size: 16, color: _odooPurple),
                            SizedBox(width: 8),
                            Text('Jours fériés (Calendrier)', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(width: 8),

              // Center: Clean modern Search Bar & Filter Dropdown & Group Button
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. Search Bar (flexible, 100% white background, no inner grey fill)
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: isWide ? 260 : 200, minWidth: isCompact ? 60 : 90),
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1)),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  inputDecorationTheme: const InputDecorationTheme(
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                child: TextField(
                                  controller: _searchCtrl,
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                  decoration: InputDecoration(
                                    hintText: isCompact ? 'Rechercher...' : 'Rechercher un pointage...',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    isDense: true,
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 2. Dropdown Filter for Period
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _timeFilter,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          borderRadius: BorderRadius.circular(8),
                          dropdownColor: Colors.white,
                          focusColor: Colors.transparent,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Toutes les dates')),
                            DropdownMenuItem(value: 'today', child: Text('Aujourd\'hui')),
                            DropdownMenuItem(value: 'this_week', child: Text('Cette semaine')),
                            DropdownMenuItem(value: 'this_month', child: Text('Ce mois-ci')),
                            DropdownMenuItem(
                              value: 'leave_conflicts',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.beach_access_rounded, size: 13, color: Color(0xFFD97706)),
                                  SizedBox(width: 4),
                                  Text('Conflits congés', style: TextStyle(color: Color(0xFFD97706))),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _timeFilter = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 3. Group by employee toggle button
                    Tooltip(
                      message: _groupByEmployee ? 'Vue groupe par employé' : 'Vue liste plate',
                      child: InkWell(
                        onTap: () => setState(() => _groupByEmployee = !_groupByEmployee),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 36,
                          padding: EdgeInsets.symmetric(horizontal: isWide || isMedium ? 8 : 6),
                          decoration: BoxDecoration(
                            color: _groupByEmployee ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _groupByEmployee ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _groupByEmployee ? Icons.group_rounded : Icons.view_list_rounded,
                                size: 15,
                                color: _groupByEmployee ? _odooPurple : const Color(0xFF64748B),
                              ),
                              if (isWide || isMedium) ...[
                                const SizedBox(width: 5),
                                Text(
                                  _groupByEmployee
                                      ? (isWide ? 'Groupé par employé' : 'Groupé')
                                      : (isWide ? 'Liste plate' : 'Liste'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: _groupByEmployee ? FontWeight.bold : FontWeight.w500,
                                    color: _groupByEmployee ? _odooPurple : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right: Quick Check-in Button + Pagination
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Pointer l\'arrivée rapide',
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _odooPurple,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        backgroundColor: Colors.white,
                        minimumSize: const Size(0, 36),
                        padding: EdgeInsets.symmetric(horizontal: isWide || isMedium ? 10 : 8, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.touch_app_rounded, size: 15, color: _odooPurple),
                      label: isWide || isMedium
                          ? Text(isWide ? 'Pointer rapide' : 'Pointer',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _odooPurple))
                          : const SizedBox.shrink(),
                      onPressed: () => _openQuickCheckInModal(context, activeEmployees),
                    ),
                  ),
                  if (!isVeryCompact) ...[
                    const SizedBox(width: 8),
                    Text(
                      '1-$groupCount / $groupCount',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(icon: const Icon(Icons.chevron_left, size: 17), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  IconButton(icon: const Icon(Icons.chevron_right, size: 17), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterAndMetricsRibbon(int count, double totalWorked, double totalOvertime, List<LeaveRequest> allLeaves) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF8FAFC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildFilterPill('Toutes', 'all'),
                      const SizedBox(width: 6),
                      _buildFilterPill('Aujourd\'hui', 'today'),
                      const SizedBox(width: 6),
                      _buildFilterPill('Cette semaine', 'this_week'),
                      const SizedBox(width: 6),
                      _buildFilterPill('Ce mois', 'this_month'),
                      const SizedBox(width: 6),
                      _buildFilterPill('Conflits congés', 'leave_conflicts', isAlert: true),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Text(
                        'Total: $count pointage(s)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Text('Heures: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            Text(Attendance.formatDuration(totalWorked), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _odooPurple)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Text('Heures sup: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            Text(Attendance.formatDuration(totalOvertime), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPill(String label, String filterKey, {bool isAlert = false}) {
    final isSel = _timeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _timeFilter = filterKey),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSel
              ? (isAlert ? const Color(0xFFF59E0B) : _odooPurple)
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSel ? Colors.transparent : const Color(0xFFCBD5E1),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel ? Colors.white : (isAlert ? const Color(0xFFD97706) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedTableView(Map<String, List<Attendance>> grouped, List<LeaveRequest> allLeaves, List<Employee> allEmployees) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: grouped.keys.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTableHeader();
        }

        final empName = grouped.keys.elementAt(index - 1);
        final attendances = grouped[empName]!;
        final isCollapsed = _collapsedGroups.contains(empName);

        // Group metrics
        double groupWorked = 0;
        double groupOvertime = 0;
        for (final a in attendances) {
          groupWorked += a.workedHours;
          groupOvertime += a.overtimeHours;
        }

        final emp = allEmployees.firstWhere(
          (e) => e.fullName == empName,
          orElse: () => Employee(id: '', code: '', firstName: '', lastName: '', department: '', jobTitle: '', hireDate: DateTime.now()),
        );

        return Column(
          children: [
            // Accordion Header Row (e.g. ▶ Administrator (1) or ▼ Mohamed (5))
            InkWell(
              onTap: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedGroups.remove(empName);
                  } else {
                    _collapsedGroups.add(empName);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCollapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                      size: 20,
                      color: const Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$empName (${attendances.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                    if (emp.id.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Ouvrir fiche employé',
                        child: InkWell(
                          onTap: () => EmployeeFormDialog.show(context, employee: emp),
                          child: const Icon(Icons.open_in_new, size: 14, color: _odooPurple),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Total Heures de travail for this group (Screenshot 1: 08:38 or 44:52)
                    SizedBox(
                      width: 140,
                      child: Text(
                        Attendance.formatDuration(groupWorked),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Total Heures supplémentaires for this group (Screenshot 1: 00:00 or 05:29)
                    SizedBox(
                      width: 150,
                      child: Text(
                        Attendance.formatDuration(groupOvertime),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),

            // Children Rows if expanded
            if (!isCollapsed)
              for (final att in attendances)
                _buildAttendanceRow(att, allLeaves, emp),
          ],
        );
      },
    );
  }

  Widget _buildFlatTableView(List<Attendance> attendances, List<LeaveRequest> allLeaves, List<Employee> allEmployees) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: attendances.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTableHeader();
        }
        final att = attendances[index - 1];
        final emp = allEmployees.firstWhere(
          (e) => e.id == att.employeeId,
          orElse: () => Employee(id: '', code: '', firstName: '', lastName: '', department: '', jobTitle: '', hireDate: DateTime.now()),
        );
        return _buildAttendanceRow(att, allLeaves, emp);
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 24), // Checkbox placeholder
          Expanded(
            flex: 3,
            child: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
          ),
          Expanded(
            flex: 3,
            child: Text('Arrivée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
          ),
          Expanded(
            flex: 3,
            child: Text('Départ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
          ),
          SizedBox(
            width: 140,
            child: Text('Heures de travail', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
          ),
          SizedBox(width: 24),
          SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Heures supplémentaires', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                SizedBox(width: 4),
                Icon(Icons.swap_horiz, size: 15, color: Color(0xFF64748B)),
              ],
            ),
          ),
          SizedBox(width: 48), // Action icon spacer
        ],
      ),
    );
  }

  Widget _buildAttendanceRow(Attendance att, List<LeaveRequest> allLeaves, Employee emp) {
    final isSelected = _selectedAttendanceIds.contains(att.id);
    final leaveConflict = _findLeaveForAttendance(att, allLeaves);

    return InkWell(
      onTap: () => AttendanceFormDialog.show(context, attendance: att),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: _odooPurple,
              visualDensity: VisualDensity.compact,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedAttendanceIds.add(att.id);
                  } else {
                    _selectedAttendanceIds.remove(att.id);
                  }
                });
              },
            ),

            // Employé (Badge with Green [M] avatar as in Screenshot 1)
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF65A30D), // Green box avatar in Screenshot 1
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      att.employeeName.isNotEmpty ? att.employeeName[0].toUpperCase() : 'E',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      att.employeeName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Leave badge if conflict
                  if (leaveConflict != null)
                    Tooltip(
                      message: 'En ${leaveConflict.leaveType} (${leaveConflict.status})',
                      child: InkWell(
                        onTap: () => LeaveRequestFormDialog.show(context, leave: leaveConflict),
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.beach_access_rounded, size: 11, color: Color(0xFFD97706)),
                              SizedBox(width: 3),
                              Text('Congé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Arrivée: 07/11/2024 08:02:59
            Expanded(
              flex: 3,
              child: Text(
                att.formattedCheckIn,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
              ),
            ),

            // Départ: 07/11/2024 17:00:00
            Expanded(
              flex: 3,
              child: Text(
                att.checkOut != null ? att.formattedCheckOut : 'En cours...',
                style: TextStyle(
                  fontSize: 12.5,
                  color: att.checkOut != null ? const Color(0xFF334155) : const Color(0xFFD97706),
                  fontStyle: att.checkOut != null ? FontStyle.normal : FontStyle.italic,
                  fontWeight: att.checkOut == null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),

            // Heures de travail: 07:57
            SizedBox(
              width: 140,
              child: Text(
                att.formattedWorkedHours,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(width: 24),

            // Heures supplémentaires: 00:00 or 03:29 (with rate badge if present)
            SizedBox(
              width: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    att.formattedOvertimeHours,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: att.overtimeHours > 0 ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                    ),
                  ),
                  if (att.overtimeHours > 0 && att.overtimeRateName != null && att.overtimeRateName!.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Tooltip(
                      message: 'Taux : ${att.overtimeRateName} (x${att.overtimeRateMultiplier ?? 1.0})\nPondéré : ${att.weightedOvertimeHours.toStringAsFixed(2)}h',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Text(
                          att.overtimeRateName!,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _odooPurple),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions: Edit & Delete
            SizedBox(
              width: 48,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: _odooPurple),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => AttendanceFormDialog.show(context, attendance: att),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      OfflineActionHelper.executeAction(
                        context: context,
                        action: 'delete',
                        customActionLabel: 'le pointage',
                        onConfirmed: () {
                          context.read<AttendanceBloc>().add(DeleteAttendance(att.id));
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, List<Employee> activeEmployees) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _odooPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_rounded, size: 36, color: _odooPurple),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun pointage de présence trouvé',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enregistrez les arrivées et départs manuellement ou par pointage rapide.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouveau pointage manuel', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => AttendanceFormDialog.show(context),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _odooPurple,
                    side: const BorderSide(color: _odooPurple),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Pointer arrivée rapide', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _openQuickCheckInModal(context, activeEmployees),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOvertimeRatesManagerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final rates = OvertimeRateService.instance.rates;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.more_time_rounded, color: _odooPurple, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Taux d\'Heures Supplémentaires',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Définissez les taux multiplicateurs applicables aux heures supplémentaires travaillées.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: rates.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (c, idx) {
                          final rate = rates[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            title: Text(rate.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text('Multiplicateur : x ${rate.formattedRate} • ${rate.company}', style: const TextStyle(fontSize: 11.5)),
                            trailing: IconButton(
                              tooltip: 'Lien interne / Détails',
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: _odooPurple),
                              onPressed: () async {
                                await OvertimeRateService.showRateDetailsDialog(
                                  context,
                                  rate,
                                  onUpdated: () => setDialogState(() {}),
                                );
                                setDialogState(() {});
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouveau Taux', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  onPressed: () async {
                    final created = await OvertimeRateService.showCreateRateDialog(context);
                    if (created != null) {
                      setDialogState(() {});
                      setState(() {});
                    }
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
