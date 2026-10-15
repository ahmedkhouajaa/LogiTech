import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../blocs/attendance/attendance_bloc.dart';
import '../blocs/attendance/attendance_event.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../blocs/leaves/leaves_bloc.dart';
import '../blocs/leaves/leaves_state.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../models/leave_request.dart';
import '../models/overtime_rate.dart';
import '../services/attendance_tolerance_service.dart';
import '../services/overtime_rate_service.dart';
import '../services/public_holiday_service.dart';
import '../services/enterprise_service.dart';
import 'odoo_datetime_picker_dialog.dart';
import 'employee_form_dialog.dart';
import 'leave_request_form_dialog.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

/// Formulaire de Pointage Manuel des Présences (Screenshots 1, 2 & 3)
/// Liaison avec Employé (navigation directe) et Congés (détection conflits & consultation)
/// Prise en compte rigoureuse des Intervalles de Tolérance d'entrée et de sortie Odoo ERP.
class AttendanceFormDialog extends StatefulWidget {
  final Attendance? attendance;

  const AttendanceFormDialog({super.key, this.attendance});

  static Future<void> show(BuildContext context, {Attendance? attendance}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AttendanceFormDialog(attendance: attendance),
    );
  }

  @override
  State<AttendanceFormDialog> createState() => _AttendanceFormDialogState();
}

class _AttendanceFormDialogState extends State<AttendanceFormDialog> {
  static const Color _odooPurple = Color(0xFF1A56DB);
  bool _isSaving = false;

  String? _selectedEmployeeId;
  String _employeeName = '';
  String? _employeeAvatar;

  late DateTime _checkIn;
  DateTime? _checkOut;

  bool _hasOvertimeApproval = false;
  late DateTime _theoreticalStart;
  DateTime? _theoreticalEnd;

  String _mode = 'Manuel';
  String _exitMode = 'Manuel';
  final List<String> _modes = ['Manuel', 'Badge', 'Kiosque', 'Application Mobile'];

  // Heures supplémentaires & Taux (Screenshots 1 à 5)
  String? _selectedRateId;
  String? _selectedRateName;
  double? _selectedRateMultiplier;
  double? _customOvertimeHours;
  bool _showingRateDetailView = false;
  OvertimeRate? _editingRate;
  final TextEditingController _rateDetailNameCtrl = TextEditingController();
  final TextEditingController _rateDetailRateCtrl = TextEditingController();

  // Chatter
  final TextEditingController _noteCtrl = TextEditingController();
  bool _showNoteInput = false;
  List<Map<String, dynamic>> _chatterMessages = [];

  @override
  void initState() {
    super.initState();
    final att = widget.attendance;
    final now = DateTime.now();
    final tolService = AttendanceToleranceService.instance;
    final rateService = OvertimeRateService.instance;

    final defaultRate = rateService.rates.firstWhere(
      (r) => r.name.toLowerCase().contains('1.5'),
      orElse: () => rateService.rates.isNotEmpty
          ? rateService.rates.first
          : OvertimeRate(id: 'rate_1_5', name: 'x 1.5', rate: 1.50, company: 'My Company'),
    );

    if (att != null) {
      _selectedEmployeeId = att.employeeId;
      _employeeName = att.employeeName;
      _employeeAvatar = att.employeeAvatar;
      _checkIn = att.checkIn;
      _checkOut = att.checkOut;
      _hasOvertimeApproval = att.hasOvertimeApproval;
      _selectedRateId = att.overtimeRateId ?? defaultRate.id;
      _selectedRateName = att.overtimeRateName ?? defaultRate.name;
      _selectedRateMultiplier = att.overtimeRateMultiplier ?? defaultRate.rate;
      if (att.overtimeHours > 0) {
        _customOvertimeHours = att.overtimeHours;
      }
      _theoreticalStart = att.theoreticalStart ?? tolService.computeTheoreticalStart(att.checkIn);
      _theoreticalEnd = att.theoreticalEnd ?? tolService.computeTheoreticalEnd(att.checkOut, fallbackDate: att.checkIn);
      _mode = att.mode;
      _exitMode = att.exitMode;
      _chatterMessages = List<Map<String, dynamic>>.from(att.chatterMessages);
    } else {
      // Configuration par défaut conforme Capture 1: 08:00:00 à 17:00:00
      _checkIn = DateTime(now.year, now.month, now.day, tolService.standardStartHour, tolService.standardStartMinute, 0);
      _checkOut = DateTime(now.year, now.month, now.day, tolService.standardEndHour, tolService.standardEndMinute, 0);
      _theoreticalStart = tolService.computeTheoreticalStart(_checkIn);
      _theoreticalEnd = tolService.computeTheoreticalEnd(_checkOut, fallbackDate: _checkIn);
      _mode = 'Manuel';
      _exitMode = 'Manuel';
      _selectedRateId = defaultRate.id;
      _selectedRateName = defaultRate.name;
      _selectedRateMultiplier = defaultRate.rate;
      _chatterMessages = [
        {
          'authorName': 'Administrator',
          'date': now.subtract(const Duration(minutes: 8)).toIso8601String(),
          'message': 'Présences créé',
        }
      ];
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _rateDetailNameCtrl.dispose();
    _rateDetailRateCtrl.dispose();
    super.dispose();
  }

  double get _calculatedWorkedHours {
    return AttendanceToleranceService.instance.computeWorkedHours(_checkIn, _checkOut);
  }

  double get _calculatedTheoreticalHours {
    return AttendanceToleranceService.instance.computeTheoreticalHours(
      _theoreticalStart,
      _theoreticalEnd,
      checkDate: _checkIn,
    );
  }

  double get _calculatedOvertimeHours {
    final worked = _calculatedWorkedHours;
    final theo = _calculatedTheoreticalHours;
    if (worked > theo) return worked - theo;
    return 0.0;
  }

  double get effectiveOvertimeHours {
    if (_customOvertimeHours != null) return _customOvertimeHours!;
    return _calculatedOvertimeHours;
  }

  void _onCheckInChanged(DateTime picked) {
    setState(() {
      _checkIn = picked;
      _theoreticalStart = AttendanceToleranceService.instance.computeTheoreticalStart(_checkIn);
      if (_checkOut != null) {
        _theoreticalEnd = AttendanceToleranceService.instance.computeTheoreticalEnd(_checkOut, fallbackDate: _checkIn);
      }
    });
  }

  void _onCheckOutChanged(DateTime? picked) {
    setState(() {
      _checkOut = picked;
      _theoreticalEnd = AttendanceToleranceService.instance.computeTheoreticalEnd(_checkOut, fallbackDate: _checkIn);
    });
  }

  void _recomputeTheoreticalTimes() {
    setState(() {
      _theoreticalStart = AttendanceToleranceService.instance.computeTheoreticalStart(_checkIn);
      _theoreticalEnd = AttendanceToleranceService.instance.computeTheoreticalEnd(_checkOut, fallbackDate: _checkIn);
    });
  }

  LeaveRequest? _findConflictingLeave(List<LeaveRequest> allLeaves) {
    if (_selectedEmployeeId == null) return null;
    final checkDate = DateTime(_checkIn.year, _checkIn.month, _checkIn.day);

    for (final l in allLeaves) {
      if (l.employeeId == _selectedEmployeeId && !l.isDeleted) {
        final start = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
        final end = DateTime(l.endDate.year, l.endDate.month, l.endDate.day, 23, 59, 59);

        if (!checkDate.isBefore(start) && !checkDate.isAfter(end)) {
          return l;
        }
      }
    }
    return null;
  }

  Future<void> _saveAttendance() async {
    if (_isSaving) return;
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un employé')),
      );
      return;
    }

    if (widget.attendance != null) {
      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!isOnline) return;
    }

    setState(() => _isSaving = true);

    try {
      final id = widget.attendance?.id ?? const Uuid().v4();
      final att = Attendance(
        id: id,
        employeeId: _selectedEmployeeId!,
        employeeName: _employeeName,
        employeeAvatar: _employeeAvatar,
        checkIn: _checkIn,
        checkOut: _checkOut,
        workedHours: _calculatedWorkedHours,
        overtimeHours: effectiveOvertimeHours,
        hasOvertimeApproval: _hasOvertimeApproval,
        overtimeRateId: _selectedRateId,
        overtimeRateName: _selectedRateName,
        overtimeRateMultiplier: _selectedRateMultiplier,
        theoreticalStart: _theoreticalStart,
        theoreticalEnd: _theoreticalEnd,
        theoreticalHours: _calculatedTheoreticalHours,
        mode: _mode,
        exitMode: _exitMode,
        chatterMessages: _chatterMessages,
        enterpriseId: widget.attendance?.enterpriseId,
        createdAt: widget.attendance?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (!mounted) return;
      final isOnline = ConnectivityService.instance.isOnline;
      if (widget.attendance == null) {
        context.read<AttendanceBloc>().add(AddAttendance(att));
        if (mounted) {
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
                        ? 'Pointage enregistré avec succès'
                        : 'Pointage enregistré hors ligne (en attente de synchronisation)',
                  ),
                ],
              ),
              backgroundColor: isOnline ? AppColors.success : AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        context.read<AttendanceBloc>().add(UpdateAttendance(att));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Pointage mis à jour avec succès'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addNote() {
    final txt = _noteCtrl.text.trim();
    if (txt.isEmpty) return;

    setState(() {
      _chatterMessages.add({
        'authorName': 'Administrator',
        'date': DateTime.now().toIso8601String(),
        'message': txt,
      });
      _noteCtrl.clear();
      _showNoteInput = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 850;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 8 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: const Color(0xFFF8FAFC),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1100,
          maxHeight: isMobile ? size.height * 0.95 : 820,
        ),
        child: Column(
          children: [
            // Top Odoo Navigation Bar
            _buildTopNavBar(context),
            const Divider(height: 1),

            // Content Area (Rate Detail View or Left Form + Right Chatter)
            Expanded(
              child: _showingRateDetailView
                  ? SingleChildScrollView(
                      child: _buildRateDetailCard(context),
                    )
                  : isMobile
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLeftForm(context),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                              _buildRightChatter(),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Form
                            Expanded(
                              flex: 6,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: _buildLeftForm(context),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            // Right Chatter
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: _buildRightChatter(),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildHeaderTitle() {
    final workedStr = Attendance.formatDuration(_calculatedWorkedHours);
    final inStr = DateFormat('HH:mm').format(_checkIn);
    final outStr = _checkOut != null ? DateFormat('HH:mm').format(_checkOut!) : '17:00';
    return '$workedStr : ($inStr-$outStr)';
  }

  Widget _buildTopNavBar(BuildContext context) {
    if (_showingRateDetailView) {
      // Navigation Bar pour Vue Détail Taux Heures Sup (Screenshot 5)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Purple [Nouveau] button (Screenshot 5)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _openCreateRateModal,
                  child: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 16),
                // Breadcrumbs: Présences / 09:58 : (08:01-19:00) / x 1.5 ⚙ (Screenshot 5)
                Text(
                  'Présences',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const Text(' / ', style: TextStyle(color: Colors.grey)),
                Tooltip(
                  message: 'Back to "${_buildHeaderTitle()}"',
                  child: InkWell(
                    onTap: () => setState(() => _showingRateDetailView = false),
                    child: Text(
                      _buildHeaderTitle(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: _odooPurple,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const Text(' / ', style: TextStyle(color: Colors.grey)),
                Text(
                  _editingRate?.name ?? (_selectedRateName ?? 'x 1.5'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
              ],
            ),
            Row(
              children: [
                const Text('1 / 1', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {},
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => setState(() => _showingRateDetailView = false),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Purple [Nouveau] button (Screenshot 1 & 3)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _odooPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  final now = DateTime.now();
                  final tolService = AttendanceToleranceService.instance;
                  setState(() {
                    _checkIn = DateTime(now.year, now.month, now.day, tolService.standardStartHour, tolService.standardStartMinute, 0);
                    _checkOut = DateTime(now.year, now.month, now.day, tolService.standardEndHour, tolService.standardEndMinute, 0);
                    _theoreticalStart = tolService.computeTheoreticalStart(_checkIn);
                    _theoreticalEnd = tolService.computeTheoreticalEnd(_checkOut, fallbackDate: _checkIn);
                    _hasOvertimeApproval = false;
                    _customOvertimeHours = null;
                  });
                },
                child: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 16),
              // Breadcrumbs: Présences / 08:00 : (08:00-17:00) ⚙ (Screenshot 1 & 3)
              Text(
                'Présences',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const Text(' / ', style: TextStyle(color: Colors.grey)),
              Text(
                _buildHeaderTitle(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(width: 6),
              // Settings gear icon ⚙ -> ouvre la boîte de configuration des tolérances
              IconButton(
                tooltip: 'Configurer les intervalles de tolérance',
                icon: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  AttendanceToleranceService.showToleranceSettingsDialog(
                    context,
                    onSaved: _recomputeTheoreticalTimes,
                  );
                },
              ),
              const SizedBox(width: 6),
              // Cloud sync icon ☁
              const Tooltip(
                message: 'Pointage synchronisé',
                child: Icon(Icons.cloud_done_outlined, size: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              // Reload icon ⟲ -> recalcule les heures théoriques avec tolérances
              IconButton(
                tooltip: 'Recalculer les heures théoriques selon la tolérance',
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _recomputeTheoreticalTimes,
              ),
            ],
          ),
          Row(
            children: [
              if (widget.attendance != null)
                IconButton(
                  tooltip: 'Supprimer ce pointage',
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  onPressed: _isSaving
                      ? null
                      : () {
                          OfflineActionHelper.executeAction(
                            context: context,
                            action: 'delete',
                            customActionLabel: 'le pointage',
                            onConfirmed: () {
                              context.read<AttendanceBloc>().add(DeleteAttendance(widget.attendance!.id));
                              Navigator.of(context).pop();
                            },
                          );
                        },
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _odooPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _isSaving ? null : _saveAttendance,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpLabel(String label, String tooltip) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        const SizedBox(width: 3),
        Tooltip(
          message: tooltip,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 11),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: const Text(
            '?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D9488), // Subtle cyan/teal question mark from Odoo
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPublicHolidayNotice() {
    final holiday = PublicHolidayService.instance.getHolidayForDate(_checkIn);
    if (holiday == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded, size: 15, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Jour Férié : ${holiday.name} • Heures théoriques dues : 00:00 (Toutes les heures effectuées sont comptabilisées en heures supplémentaires).',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToleranceNotice() {
    final s = AttendanceToleranceService.instance;
    final stdStart = DateTime(_checkIn.year, _checkIn.month, _checkIn.day, s.standardStartHour, s.standardStartMinute, 0);
    final tolLimit = stdStart.add(Duration(minutes: s.entryToleranceMinutes));

    final isLateBeyondTol = _checkIn.isAfter(tolLimit);
    final isInTol = !_checkIn.isBefore(stdStart) && !_checkIn.isAfter(tolLimit);

    if (isLateBeyondTol) {
      final lateMin = _checkIn.difference(stdStart).inMinutes;
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Arrivée à ${DateFormat('HH:mm:ss').format(_checkIn)} (retard de $lateMin min). La tolérance d\'entrée (${s.entryToleranceMinutes} min) est appliquée : début théorique fixé à ${DateFormat('HH:mm:ss').format(_theoreticalStart)}.',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      );
    } else if (isInTol && _checkIn.isAfter(stdStart)) {
      final tolDiff = _checkIn.difference(stdStart).inMinutes;
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF047857)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Arrivée dans l\'intervalle de tolérance (+$tolDiff min ≤ ${s.entryToleranceMinutes} min). Début théorique maintenu à ${DateFormat('HH:mm:ss').format(_theoreticalStart)}.',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLeftForm(BuildContext context) {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];
        final activeEmployees = employees.where((e) => e.isActive).toList();

        // Si aucun employé sélectionné et la liste est non-vide, initialiser
        if (_selectedEmployeeId == null && activeEmployees.isNotEmpty) {
          _selectedEmployeeId = activeEmployees.first.id;
          _employeeName = activeEmployees.first.fullName;
          _employeeAvatar = activeEmployees.first.photoUrl;
        }

        final currentEmployee = activeEmployees.firstWhere(
          (e) => e.id == _selectedEmployeeId,
          orElse: () => activeEmployees.isNotEmpty ? activeEmployees.first : Employee(id: '', code: '', firstName: '', lastName: '', department: '', jobTitle: '', hireDate: DateTime.now()),
        );

        return BlocBuilder<LeavesBloc, LeavesState>(
          builder: (context, leavesState) {
            final allLeaves = leavesState is LeavesLoaded ? leavesState.leaves : <LeaveRequest>[];
            final leaveConflict = _findConflictingLeave(allLeaves);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alerte Liaison Congé (si l'employé est en congé validé à cette date)
                if (leaveConflict != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.beach_access_rounded, color: Color(0xFFD97706), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alerte Congé : $_employeeName est en ${leaveConflict.leaveType}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Période du ${DateFormat('dd/MM/yyyy').format(leaveConflict.startDate)} au ${DateFormat('dd/MM/yyyy').format(leaveConflict.endDate)} (${leaveConflict.status == 'approved' ? 'Congé validé' : 'En attente'})',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: _odooPurple,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Voir le congé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => LeaveRequestFormDialog.show(context, leave: leaveConflict),
                        ),
                      ],
                    ),
                  ),

                // Formulaire Odoo (Screenshots 1, 2 & 3)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Colonne Gauche: Employé, Arrivée, Départ
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Employé row with avatar & arrow
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: _buildHelpLabel('Employé', 'Sélectionner l\'employé associé à ce pointage'),
                              ),
                              Expanded(
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                      value: activeEmployees.any((e) => e.id == _selectedEmployeeId) ? _selectedEmployeeId : null,
                                      isExpanded: true,
                                      isDense: true,
                                      borderRadius: BorderRadius.circular(8),
                                      dropdownColor: Colors.white,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                      items: activeEmployees.map((e) {
                                        return DropdownMenuItem<String>(
                                          value: e.id,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0D9488),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  e.fullName.isNotEmpty ? e.fullName[0].toUpperCase() : 'E',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  e.fullName,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          final emp = activeEmployees.firstWhere((e) => e.id == val);
                                          setState(() {
                                            _selectedEmployeeId = emp.id;
                                            _employeeName = emp.fullName;
                                            _employeeAvatar = emp.photoUrl;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              // Arrow button -> jumps to Employee file
                              IconButton(
                                tooltip: 'Consulter la fiche employé',
                                icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF475569)),
                                onPressed: () {
                                  if (currentEmployee.id.isNotEmpty) {
                                    EmployeeFormDialog.show(context, employee: currentEmployee);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Arrivée field (Screenshot 1 & 3)
                          _buildDateTimeField(
                            labelWidget: _buildHelpLabel('Arrivée', 'Date et heure réelles du pointage d\'arrivée'),
                            value: DateFormat('dd/MM/yyyy HH:mm:ss').format(_checkIn),
                            onTap: () async {
                              final picked = await OdooDateTimePickerDialog.show(
                                context,
                                initialDateTime: _checkIn,
                              );
                              if (picked != null) {
                                _onCheckInChanged(picked);
                              }
                            },
                          ),
                          _buildToleranceNotice(),
                          _buildPublicHolidayNotice(),
                          const SizedBox(height: 16),

                          // Départ field (Screenshot 1 & 3)
                          _buildDateTimeField(
                            labelWidget: _buildHelpLabel('Départ', 'Date et heure réelles du pointage de départ'),
                            value: _checkOut != null
                                ? DateFormat('dd/MM/yyyy HH:mm:ss').format(_checkOut!)
                                : 'Non renseigné (En cours)',
                            isPlaceholder: _checkOut == null,
                            showClear: _checkOut != null,
                            onClear: () => _onCheckOutChanged(null),
                            onTap: () async {
                              final picked = await OdooDateTimePickerDialog.show(
                                context,
                                initialDateTime: _checkOut ?? _checkIn.add(const Duration(hours: 9)),
                              );
                              if (picked != null) {
                                _onCheckOutChanged(picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 32),

                    // Colonne Droite: Heures travaillées, Autorisation Heures Sup, Heures supplémentaires, Taux Heures Supplémentaires (Screenshots 1, 3 & 4)
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildHelpLabel('Heures travaillées', 'Heures effectives de travail (déduction faite de la pause de 1h si journée ≥ 6h)'),
                              Text(
                                Attendance.formatDuration(_calculatedWorkedHours),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _odooPurple),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildHelpLabel('Autorisation Heures\nSupplémentaires', 'Cochez si les heures supplémentaires sont autorisées pour ce pointage'),
                              ),
                              Checkbox(
                                value: _hasOvertimeApproval,
                                activeColor: _odooPurple,
                                onChanged: (val) => setState(() => _hasOvertimeApproval = val ?? false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Heures supplémentaires row (Screenshot 1 & 3)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _buildHelpLabel('Heures\nsupplémentaires', 'Durée des heures supplémentaires effectuées au-delà du théorique'),
                                  if (_customOvertimeHours != null) ...[
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Valeur personnalisée (cliquez pour recalculer automatiquement)',
                                      child: InkWell(
                                        onTap: () => setState(() => _customOvertimeHours = null),
                                        child: const Icon(Icons.refresh, size: 14, color: Color(0xFFD97706)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              InkWell(
                                onTap: _editOvertimeHoursDialog,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Text(
                                        Attendance.formatDuration(effectiveOvertimeHours),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: effectiveOvertimeHours > 0 ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF94A3B8)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Taux Heures Supplémentaires (Screenshots 1, 3, 4)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 140,
                                child: _buildHelpLabel('Taux Heures\nSupplémentaires', 'Taux multiplicateur appliqué aux heures supplémentaires (ex: x 1.5, X2)'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildOvertimeRateDropdown(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Section HEURES THÉORIQUES (Screenshots 1 & 3)
                const Text(
                  'HEURES THÉORIQUES',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.8, color: Color(0xFF64748B)),
                ),
                const Divider(height: 14),
                const SizedBox(height: 6),

                Row(
                  children: [
                    // Début théorique (Screenshot 1: 08:00:00 -> Screenshot 3: 08:10:00 avec tolérance)
                    Expanded(
                      flex: 5,
                      child: _buildDateTimeField(
                        labelWidget: _buildHelpLabel('Début', 'Heure théorique de prise de poste ajustée selon l\'intervalle de tolérance'),
                        value: DateFormat('dd/MM/yyyy HH:mm:ss').format(_theoreticalStart),
                        onTap: () async {
                          final picked = await OdooDateTimePickerDialog.show(context, initialDateTime: _theoreticalStart);
                          if (picked != null) setState(() => _theoreticalStart = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Fin théorique
                    Expanded(
                      flex: 5,
                      child: _buildDateTimeField(
                        labelWidget: _buildHelpLabel('Fin', 'Heure théorique de fin de poste ajustée selon la tolérance de sortie'),
                        value: _theoreticalEnd != null
                            ? DateFormat('dd/MM/yyyy HH:mm:ss').format(_theoreticalEnd!)
                            : 'Non renseignée',
                        isPlaceholder: _theoreticalEnd == null,
                        onTap: () async {
                          final picked = await OdooDateTimePickerDialog.show(context, initialDateTime: _theoreticalEnd ?? _theoreticalStart.add(const Duration(hours: 9)));
                          if (picked != null) setState(() => _theoreticalEnd = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Heures théoriques total (Screenshot 1: 08:00, Screenshot 3: 07:50)
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          _buildHelpLabel('Heures Théoriques', 'Volume d\'heures théoriques contractuelles pour cette séance'),
                          const SizedBox(width: 8),
                          Text(
                            Attendance.formatDuration(_calculatedTheoreticalHours),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Section ARRIVÉE (Screenshots 1 & 3)
                const Text(
                  'ARRIVÉE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.8, color: Color(0xFF64748B)),
                ),
                const Divider(height: 14),
                const SizedBox(height: 6),

                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: _buildHelpLabel('Mode', 'Mode de capture de l\'arrivée'),
                    ),
                    Container(
                      width: 220,
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          value: _mode,
                          isDense: true,
                          borderRadius: BorderRadius.circular(8),
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                          items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _mode = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Section DÉPART (Screenshots 1 & 3)
                const Text(
                  'DÉPART',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.8, color: Color(0xFF64748B)),
                ),
                const Divider(height: 14),
                const SizedBox(height: 6),

                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: _buildHelpLabel('Mode', 'Mode de capture du départ'),
                    ),
                    Container(
                      width: 220,
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          value: _exitMode,
                          isDense: true,
                          borderRadius: BorderRadius.circular(8),
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                          items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _exitMode = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateTimeField({
    required Widget labelWidget,
    required String value,
    required VoidCallback onTap,
    bool isPlaceholder = false,
    bool showClear = false,
    VoidCallback? onClear,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: labelWidget,
        ),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
                      color: isPlaceholder ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showClear && onClear != null)
                        InkWell(
                          onTap: onClear,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      const Icon(Icons.calendar_today_outlined, size: 15, color: _odooPurple),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightChatter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action buttons: [Envoyer un message] [Note] 🔍 📎 Suivre
        Row(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _odooPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              onPressed: () => setState(() => _showNoteInput = !_showNoteInput),
              child: const Text('Envoyer un message', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                backgroundColor: const Color(0xFFF1F5F9),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => setState(() => _showNoteInput = !_showNoteInput),
              child: const Text('Note', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.search, size: 17, color: Color(0xFF64748B)), onPressed: () {}),
            IconButton(icon: const Icon(Icons.attach_file, size: 17, color: Color(0xFF64748B)), onPressed: () {}),
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () {},
              child: const Text('Suivre', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_showNoteInput)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Écrire un message ou une note interne...',
                    hintStyle: TextStyle(fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showNoteInput = false),
                      child: const Text('Annuler', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _odooPurple,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _addNote,
                      child: const Text('Publier', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Timeline feed (Screenshot 2)
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Aujourd\'hui', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: ListView.builder(
            itemCount: _chatterMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatterMessages[_chatterMessages.length - 1 - index];
              final author = msg['authorName'] ?? 'Administrator';
              final text = msg['message'] ?? '';
              final dateStr = msg['date'] != null ? DateFormat('HH:mm').format(DateTime.tryParse(msg['date']) ?? DateTime.now()) : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFD97706),
                      child: Text(
                        author.isNotEmpty ? author[0].toUpperCase() : 'A',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                              const SizedBox(width: 6),
                              Text(dateStr.isNotEmpty ? dateStr : 'maintenant', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                        ],
                      ),
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

  // =========================================================================
  // GESTION DES TAUX D'HEURES SUPPLÉMENTAIRES (Screenshots 1 à 5)
  // =========================================================================

  Widget _buildOvertimeRateDropdown() {
    final rates = OvertimeRateService.instance.rates;
    final currentDisplay = _selectedRateName ?? (rates.isNotEmpty ? rates.first.name : 'x 1.5');

    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<String>(
            tooltip: 'Sélectionner le taux d\'heures supplémentaires',
            offset: const Offset(0, 32),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onSelected: (val) async {
              if (val == '__create_new__') {
                await _openCreateRateModal();
              } else if (val == '__advanced_search__') {
                await _openAdvancedRateSearch();
              } else {
                final match = rates.firstWhere(
                  (r) => r.id == val,
                  orElse: () => rates.firstWhere((r) => r.name == val, orElse: () => rates.first),
                );
                setState(() {
                  _selectedRateId = match.id;
                  _selectedRateName = match.name;
                  _selectedRateMultiplier = match.rate;
                });
              }
            },
            itemBuilder: (ctx) {
              final items = <PopupMenuEntry<String>>[];
              for (final r in rates) {
                final isCurrent = r.id == _selectedRateId || r.name == _selectedRateName;
                items.add(
                  PopupMenuItem<String>(
                    value: r.id,
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          r.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? _odooPurple : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          r.formattedRate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              items.add(const PopupMenuDivider(height: 8));

              // "Recherche avancée..." (Screenshot 1)
              items.add(
                const PopupMenuItem<String>(
                  value: '__advanced_search__',
                  height: 34,
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text(
                        'Recherche avancée...',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              );

              // "Commencer à écrire..." / "Créer et modifier..." (Screenshot 1)
              items.add(
                const PopupMenuItem<String>(
                  value: '__create_new__',
                  height: 34,
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 14, color: _odooPurple),
                      SizedBox(width: 8),
                      Text(
                        'Créer et modifier...',
                        style: TextStyle(fontSize: 12.5, color: _odooPurple, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );

              return items;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentDisplay,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ),

        // "➔ Lien interne" button (Screenshot 4)
        Tooltip(
          message: 'Lien interne',
          child: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF475569)),
            padding: const EdgeInsets.only(left: 4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: _openRateDetailView,
          ),
        ),
      ],
    );
  }

  void _openRateDetailView() {
    OvertimeRate? rate;
    final rates = OvertimeRateService.instance.rates;
    if (_selectedRateId != null) {
      rate = rates.firstWhere(
        (r) => r.id == _selectedRateId,
        orElse: () => rates.firstWhere(
          (r) => r.name == _selectedRateName,
          orElse: () => OvertimeRate(
            id: _selectedRateId ?? const Uuid().v4(),
            name: _selectedRateName ?? 'x 1.5',
            rate: _selectedRateMultiplier ?? 1.50,
            company: EnterpriseService.instance.currentEnterprise?.name ?? 'My Company',
          ),
        ),
      );
    } else {
      rate = rates.firstWhere(
        (r) => r.name == _selectedRateName,
        orElse: () => OvertimeRate(
          id: 'rate_1_5',
          name: _selectedRateName ?? 'x 1.5',
          rate: _selectedRateMultiplier ?? 1.50,
          company: EnterpriseService.instance.currentEnterprise?.name ?? 'My Company',
        ),
      );
    }

    _editingRate = rate;
    _rateDetailNameCtrl.text = rate.name;
    _rateDetailRateCtrl.text = rate.formattedRate;
    setState(() {
      _showingRateDetailView = true;
    });
  }

  Future<void> _openCreateRateModal() async {
    final created = await OvertimeRateService.showCreateRateDialog(context);
    if (created != null && mounted) {
      setState(() {
        _selectedRateId = created.id;
        _selectedRateName = created.name;
        _selectedRateMultiplier = created.rate;
        if (_showingRateDetailView) {
          _editingRate = created;
          _rateDetailNameCtrl.text = created.name;
          _rateDetailRateCtrl.text = created.formattedRate;
        }
      });
    }
  }

  Future<void> _openAdvancedRateSearch() async {
    final rates = OvertimeRateService.instance.rates;
    await showDialog(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final filtered = rates.where((r) => r.name.toLowerCase().contains(filter.toLowerCase())).toList();
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recherche Taux Heures Sup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un taux...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) => setDlgState(() => filter = val),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (c, idx) {
                          final r = filtered[idx];
                          return ListTile(
                            dense: true,
                            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text('Multiplicateur : ${r.formattedRate} • ${r.company}', style: const TextStyle(fontSize: 11.5)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _odooPurple,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedRateId = r.id;
                                  _selectedRateName = r.name;
                                  _selectedRateMultiplier = r.rate;
                                });
                                Navigator.of(ctx).pop();
                              },
                              child: const Text('Choisir', style: TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouveau taux'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _openCreateRateModal();
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

  void _editOvertimeHoursDialog() {
    final current = effectiveOvertimeHours;
    final ctrl = TextEditingController(text: Attendance.formatDuration(current));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Heures supplémentaires manuelles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modifier ou forcer le nombre d\'heures supplémentaires pour ce pointage (format HH:mm) :',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'ex: 08:00 ou 01:58',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _customOvertimeHours = null);
              Navigator.of(ctx).pop();
            },
            child: const Text('Réinitialiser au calcul'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _odooPurple, foregroundColor: Colors.white),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.contains(':')) {
                final parts = val.split(':');
                final h = double.tryParse(parts[0]) ?? 0.0;
                final m = double.tryParse(parts[1]) ?? 0.0;
                setState(() => _customOvertimeHours = h + (m / 60.0));
              } else {
                final d = double.tryParse(val);
                if (d != null) {
                  setState(() => _customOvertimeHours = d);
                }
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Widget _buildRateDetailCard(BuildContext context) {
    final companyName = _editingRate?.company.isNotEmpty == true
        ? _editingRate!.company
        : (EnterpriseService.instance.currentEnterprise?.name ?? 'My Company');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne Gauche: Nom & Société (Screenshot 5)
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 80,
                          child: Text(
                            'Nom',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _rateDetailNameCtrl,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const SizedBox(
                          width: 80,
                          child: Text(
                            'Société',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                            child: Text(
                              companyName,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 48),

              // Colonne Droite: Taux (Screenshot 5)
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 60,
                      child: Text(
                        'Taux',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _rateDetailRateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _odooPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Enregistrer et Revenir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _saveEditingRateAndReturn,
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  setState(() {
                    _showingRateDetailView = false;
                  });
                },
                child: const Text('Retour au pointage', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveEditingRateAndReturn() async {
    final name = _rateDetailNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du taux ne peut pas être vide')),
      );
      return;
    }

    final parsedRate = double.tryParse(_rateDetailRateCtrl.text.replaceAll(',', '.').trim()) ?? 1.5;
    final updatedRate = (_editingRate ??
            OvertimeRate(
              id: _selectedRateId ?? const Uuid().v4(),
              name: name,
              rate: parsedRate,
              company: EnterpriseService.instance.currentEnterprise?.name ?? 'My Company',
            ))
        .copyWith(
      name: name,
      rate: parsedRate,
    );

    await OvertimeRateService.instance.saveRate(updatedRate);

    setState(() {
      _selectedRateId = updatedRate.id;
      _selectedRateName = updatedRate.name;
      _selectedRateMultiplier = updatedRate.rate;
      _showingRateDetailView = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Taux "${updatedRate.name}" ($parsedRate) mis à jour avec succès'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
