import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/attendance/attendance_bloc.dart';
import '../../blocs/attendance/attendance_event.dart';
import '../../blocs/attendance/attendance_state.dart';
import '../../blocs/employees/employees_bloc.dart';
import '../../blocs/employees/employees_event.dart';
import '../../blocs/employees/employees_state.dart';
import '../../blocs/leaves/leaves_bloc.dart';
import '../../blocs/leaves/leaves_event.dart';
import '../../blocs/leaves/leaves_state.dart';
import '../../models/attendance.dart';
import '../../models/employee.dart';
import '../../models/leave_request.dart';
import '../../services/attendance_tolerance_service.dart';
import '../../services/overtime_rate_service.dart';
import '../../services/public_holiday_service.dart';
import '../../utils/constants.dart';
import '../../services/connectivity_service.dart';
import '../../utils/offline_action_helper.dart';
import '../../widgets/attendance_form_dialog.dart';
import '../../widgets/employee_form_dialog.dart';
import '../../widgets/leave_request_form_dialog.dart';
import '../../widgets/public_holidays_view.dart';

/// Écran des Présences et Pointages pour Mobile / Android
/// Optimisé pour écrans tactiles avec groupement par employé,
/// pointage rapide arrivée/départ et détection des congés.
class MobileHrAttendanceScreen extends StatefulWidget {
  const MobileHrAttendanceScreen({super.key});

  @override
  State<MobileHrAttendanceScreen> createState() => _MobileHrAttendanceScreenState();
}

class _MobileHrAttendanceScreenState extends State<MobileHrAttendanceScreen> {
  bool _isFirstLoad = true;
  static const Color _odooPurple = Color(0xFF1A56DB);

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, today, this_month, leave_conflicts
  final Set<String> _expandedEmployees = {};

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
    switch (_selectedFilter) {
      case 'today':
        return date.year == now.year && date.month == now.month && date.day == now.day;
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

  void _showQuickClockSheet(BuildContext context, List<Employee> activeEmployees, List<Attendance> allAttendances) {
    if (activeEmployees.isEmpty) return;
    String selectedEmpId = activeEmployees.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
          final emp = activeEmployees.firstWhere((e) => e.id == selectedEmpId);
          // Check if employee has an open attendance today
          final now = DateTime.now();
          final openAtt = allAttendances.firstWhere(
            (a) => a.employeeId == emp.id && a.checkOut == null && a.checkIn.day == now.day && a.checkIn.month == now.month && a.checkIn.year == now.year,
            orElse: () => Attendance(id: '', employeeId: '', employeeName: '', checkIn: now),
          );
          final hasOpenAttendance = openAtt.id.isNotEmpty;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _odooPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.touch_app_rounded, color: _odooPurple, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pointage Rapide',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Sélectionner l\'employé :', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
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
                        borderRadius: BorderRadius.circular(8),
                        dropdownColor: Colors.white,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        items: activeEmployees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName))).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedEmpId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Heure actuelle :', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _odooPurple),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasOpenAttendance ? Colors.grey.shade400 : const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: (hasOpenAttendance || isSubmitting)
                              ? null
                              : () {
                                  setSheetState(() => isSubmitting = true);
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
                                                : 'Arrivée pointée hors ligne pour ${emp.fullName} (en attente de sync)',
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Pointer Arrivée', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasOpenAttendance ? const Color(0xFFF59E0B) : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: (!hasOpenAttendance || isSubmitting)
                              ? null
                              : () {
                                  setSheetState(() => isSubmitting = true);
                                  final isOnline = ConnectivityService.instance.isOnline;
                                  context.read<AttendanceBloc>().add(
                                        QuickCheckOut(attendanceId: openAtt.id),
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
                                                ? 'Départ pointé pour ${emp.fullName}'
                                                : 'Départ pointé hors ligne pour ${emp.fullName} (en attente de sync)',
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Pointer Départ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

                final filtered = allAttendances.where((a) {
                  if (!_isDateInFilter(a.checkIn)) return false;
                  if (_selectedFilter == 'leave_conflicts') {
                    if (_findLeaveForAttendance(a, allLeaves) == null) return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    if (!a.employeeName.toLowerCase().contains(q)) return false;
                  }
                  return true;
                }).toList();

                final Map<String, List<Attendance>> grouped = {};
                for (final a in filtered) {
                  grouped.putIfAbsent(a.employeeName, () => []).add(a);
                }

                // Global metrics
                double totalWorked = 0;
                double totalOvertime = 0;
                int presentToday = 0;
                final now = DateTime.now();

                for (final a in allAttendances) {
                  if (a.checkIn.day == now.day && a.checkIn.month == now.month && a.checkIn.year == now.year) {
                    presentToday++;
                  }
                  if (a.checkIn.month == now.month && a.checkIn.year == now.year) {
                    totalWorked += a.workedHours;
                    totalOvertime += a.overtimeHours;
                  }
                }

                return Scaffold(
                  backgroundColor: AppColors.background,
                  appBar: AppBar(
                    title: const Text('Présences & Pointages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
                    actions: [
                      IconButton(
                        tooltip: 'Tolérances de pointage',
                        icon: const Icon(Icons.tune_rounded, color: _odooPurple),
                        onPressed: () {
                          AttendanceToleranceService.showToleranceSettingsDialog(
                            context,
                            onSaved: () => setState(() {}),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Taux Heures Sup',
                        icon: const Icon(Icons.more_time_rounded, color: _odooPurple),
                        onPressed: () async {
                          await OvertimeRateService.showCreateRateDialog(context);
                          setState(() {});
                        },
                      ),
                      IconButton(
                        tooltip: 'Jours fériés',
                        icon: const Icon(Icons.celebration_rounded, color: _odooPurple),
                        onPressed: () => PublicHolidaysView.showAsDialog(context),
                      ),
                      IconButton(
                        tooltip: 'Pointer rapide',
                        icon: const Icon(Icons.touch_app_rounded, color: _odooPurple),
                        onPressed: () => _showQuickClockSheet(context, activeEmployees, allAttendances),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () {
                          context.read<AttendanceBloc>().add(const LoadAttendances());
                          context.read<EmployeesBloc>().add(const LoadEmployees());
                          context.read<LeavesBloc>().add(const LoadLeaves());
                        },
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      // Top KPI cards
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        color: AppColors.surface,
                        child: Row(
                          children: [
                            _buildKpiCard('Présents', '$presentToday emp.', const Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            _buildKpiCard('Heures (Mois)', Attendance.formatDuration(totalWorked), _odooPurple),
                            const SizedBox(width: 8),
                            _buildKpiCard('Heures Sup', Attendance.formatDuration(totalOvertime), const Color(0xFF0D9488)),
                          ],
                        ),
                      ),

                      // Search & filter chips
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        color: AppColors.surface,
                        child: Column(
                          children: [
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
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
                                        decoration: const InputDecoration(
                                          hintText: 'Rechercher un employé...',
                                          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          isDense: true,
                                          filled: false,
                                          fillColor: Colors.transparent,
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
                                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('Tous', 'all'),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('Aujourd\'hui', 'today'),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('Ce mois', 'this_month'),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('Conflits congés', 'leave_conflicts', isAlert: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // List of employees with attendances
                      Expanded(
                        child: state is AttendanceLoading && allAttendances.isEmpty
                            ? const Center(child: CircularProgressIndicator(color: _odooPurple))
                            : grouped.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 48, color: Color(0xFF94A3B8)),
                                        const SizedBox(height: 10),
                                        const Text('Aucun pointage trouvé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: _odooPurple, foregroundColor: Colors.white),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('Nouveau pointage'),
                                          onPressed: () => AttendanceFormDialog.show(context),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                                    itemCount: grouped.keys.length,
                                    itemBuilder: (context, index) {
                                      final empName = grouped.keys.elementAt(index);
                                      final attList = grouped[empName]!;
                                      final isExpanded = _expandedEmployees.contains(empName);

                                      double groupWorked = 0;
                                      double groupOvertime = 0;
                                      for (final a in attList) {
                                        groupWorked += a.workedHours;
                                        groupOvertime += a.overtimeHours;
                                      }

                                      final emp = employees.firstWhere(
                                        (e) => e.fullName == empName,
                                        orElse: () => Employee(id: '', code: '', firstName: '', lastName: '', department: '', jobTitle: '', hireDate: DateTime.now()),
                                      );

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.border),
                                          boxShadow: AppShadows.sm,
                                        ),
                                        child: Column(
                                          children: [
                                            // Card Header
                                            InkWell(
                                              borderRadius: BorderRadius.circular(10),
                                              onTap: () {
                                                setState(() {
                                                  if (isExpanded) {
                                                    _expandedEmployees.remove(empName);
                                                  } else {
                                                    _expandedEmployees.add(empName);
                                                  }
                                                });
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF65A30D),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      alignment: Alignment.center,
                                                      child: Text(
                                                        empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                              if (emp.id.isNotEmpty) ...[
                                                                const SizedBox(width: 4),
                                                                InkWell(
                                                                  onTap: () => EmployeeFormDialog.show(context, employee: emp),
                                                                  child: const Icon(Icons.open_in_new, size: 14, color: _odooPurple),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            '${attList.length} pointage(s) • Total: ${Attendance.formatDuration(groupWorked)}',
                                                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        if (groupOvertime > 0)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              '+${Attendance.formatDuration(groupOvertime)} sup',
                                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                                                            ),
                                                          ),
                                                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: const Color(0xFF64748B)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Expanded list of attendance rows
                                            if (isExpanded) ...[
                                              const Divider(height: 1),
                                              for (final att in attList) ...[
                                                _buildMobileAttendanceItem(att, allLeaves),
                                                const Divider(height: 1, indent: 16),
                                              ],
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                  floatingActionButton: FloatingActionButton.extended(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pointage manuel'),
                    onPressed: () => AttendanceFormDialog.show(context),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, {bool isAlert = false}) {
    final sel = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel
              ? (isAlert ? const Color(0xFFF59E0B) : _odooPurple)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel ? Colors.transparent : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
            color: sel ? Colors.white : (isAlert ? const Color(0xFFD97706) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAttendanceItem(Attendance att, List<LeaveRequest> allLeaves) {
    final leaveConflict = _findLeaveForAttendance(att, allLeaves);
    final holiday = PublicHolidayService.instance.getHolidayForDate(att.checkIn);

    return InkWell(
      onTap: () => AttendanceFormDialog.show(context, attendance: att),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm:ss').format(att.checkIn),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  att.formattedWorkedHours,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _odooPurple),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      att.checkOut != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(att.checkOut!) : 'En cours...',
                      style: TextStyle(
                        fontSize: 12,
                        color: att.checkOut != null ? const Color(0xFF475569) : const Color(0xFFD97706),
                        fontStyle: att.checkOut != null ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                if (att.overtimeHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD8B4FE)),
                    ),
                    child: Text(
                      '+${att.formattedOvertimeHours} sup${att.overtimeRateName != null && att.overtimeRateName!.isNotEmpty ? ' (${att.overtimeRateName})' : ''}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _odooPurple),
                    ),
                  ),
              ],
            ),
            if (holiday != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration_rounded, size: 12, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 4),
                    Text(
                      'Férié : ${holiday.name} (Théorique: 00:00)',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                    ),
                  ],
                ),
              ),
            ],
            if (leaveConflict != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => LeaveRequestFormDialog.show(context, leave: leaveConflict),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.beach_access_rounded, size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        'En ${leaveConflict.leaveType} (${leaveConflict.status})',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
