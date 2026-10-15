import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../blocs/leaves/leaves_bloc.dart';
import '../blocs/leaves/leaves_event.dart';
import '../blocs/leaves/leaves_state.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../models/leave_request.dart';
import '../models/employee.dart';
import '../services/permission_service.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

/// Modal de Prise / Demande / Validation de congés (Images 2, 3 & 4)
/// Supporte le mode modal rapide (Image 2) et le mode détail complet avec validation multi-niveaux (Images 2 & 3 de la nouvelle demande)
class LeaveRequestFormDialog extends StatefulWidget {
  final LeaveRequest? leave;
  final Employee? employee;
  final bool isQuickMode;
  final Function(LeaveRequest)? onSave;

  const LeaveRequestFormDialog({
    super.key,
    this.leave,
    this.employee,
    this.isQuickMode = false,
    this.onSave,
  });

  static Future<LeaveRequest?> show(
    BuildContext context, {
    LeaveRequest? leave,
    Employee? employee,
    bool isQuickMode = false,
    Function(LeaveRequest)? onSave,
  }) {
    return showDialog<LeaveRequest>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LeaveRequestFormDialog(
        leave: leave,
        employee: employee,
        isQuickMode: isQuickMode,
        onSave: onSave,
      ),
    );
  }

  @override
  State<LeaveRequestFormDialog> createState() => _LeaveRequestFormDialogState();
}

class _LeaveRequestFormDialogState extends State<LeaveRequestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Odoo Accent Colors
  static const Color _odooPurple = Color(0xFF1A56DB);
  static const Color _odooPurpleLight = Color(0xFFEFF6FF);
  static const Color _odooGreen = Color(0xFF10B981);
  static const Color _odooRed = Color(0xFFEF4444);
  static const Color _odooGrayBg = Color(0xFFF8FAFC);

  late bool _isDetailedView;

  // Controllers
  late TextEditingController _descriptionCtrl;
  late TextEditingController _daysCountCtrl;
  late TextEditingController _chatterCtrl;

  // Form State
  late String _leaveType;
  late String _mode;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _unit;
  late String _status; // 'to_approve', 'second_approval', 'approved', 'draft', 'rejected'

  String? _selectedEmployeeId;
  String? _selectedEmployeeName;

  // Internal Chatter logs
  final List<Map<String, dynamic>> _chatterLogs = [];

  final List<String> _leaveTypes = [
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
    _isDetailedView = !widget.isQuickMode || widget.leave != null;

    final l = widget.leave;
    final emp = widget.employee;

    _descriptionCtrl = TextEditingController(text: l?.description ?? '');
    _startDate = l?.startDate ?? DateTime.now();
    _endDate = l?.endDate ?? DateTime.now();
    _daysCountCtrl = TextEditingController(
      text: l != null
          ? l.daysCount.toStringAsFixed(l.daysCount.truncateToDouble() == l.daysCount ? 0 : 1)
          : '${_calculateDuration(_startDate, _endDate)}',
    );
    _chatterCtrl = TextEditingController();

    _leaveType = l?.leaveType ?? 'Congés payés';
    _mode = l?.mode ?? 'Par employé';
    _unit = l?.unit ?? 'Jours';
    _status = l?.status ?? 'to_approve';

    _selectedEmployeeId = l?.employeeId ?? emp?.id;
    _selectedEmployeeName = l?.employeeName ?? emp?.fullName;

    if (l != null) {
      if (l.isApproved) {
        _chatterLogs.add({
          'author': l.approvedBy ?? 'Administrator',
          'time': 'maintenant',
          'message': 'Votre ${l.leaveType} planifié le ${_formatDate(l.startDate)} 08:00:00 a été accepté',
        });
        _chatterLogs.add({
          'author': l.approvedBy ?? 'Administrator',
          'time': 'maintenant',
          'message': 'Deuxième approbation des Congés terminée',
        });
        _chatterLogs.add({
          'author': l.approvedBy ?? 'Administrator',
          'time': 'maintenant',
          'message': 'Demande de congés\n• Deuxième approbation ➔ Approuvé (Statut)',
        });
      } else if (l.isSecondApproval) {
        _chatterLogs.add({
          'author': l.approvedBy ?? 'Administrator',
          'time': 'il y a 7 heures',
          'message': 'À approuver ➔ Deuxième approbation (Statut)',
        });
        _chatterLogs.add({
          'author': l.approvedBy ?? 'Administrator',
          'time': 'il y a 7 heures',
          'message': 'Approbation des congés terminée. Note originale: Nouvelle demande ${l.leaveType} créée par Administrator',
        });
      }
      _chatterLogs.add({
        'author': l.approvedBy ?? 'Administrator',
        'time': DateFormat('dd/MM/yyyy HH:mm').format(l.createdAt),
        'message': 'Congés créé',
      });
    } else {
      _chatterLogs.add({
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'Aujourd\'hui',
        'message': 'Congés créé',
      });
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _daysCountCtrl.dispose();
    _chatterCtrl.dispose();
    super.dispose();
  }

  double _calculateDuration(DateTime start, DateTime end) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final diff = endDay.difference(startDay).inDays;
    return diff >= 0 ? (diff + 1).toDouble() : 1.0;
  }

  void _updateDates(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end.isBefore(start) ? start : end;
      final dur = _calculateDuration(_startDate, _endDate);
      _daysCountCtrl.text = dur.toStringAsFixed(dur.truncateToDouble() == dur ? 0 : 1);
    });
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _getTitle() {
    final emp = _selectedEmployeeName ?? 'Employé';
    final dur = double.tryParse(_daysCountCtrl.text.replaceAll(',', '.')) ?? 1.0;
    final durStr = '${dur.toStringAsFixed(dur.truncateToDouble() == dur ? 0 : 2)} jours';
    final dateRangeStr = _startDate == _endDate ? _formatDate(_startDate) : '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';
    return '$emp en $_leaveType: $durStr ($dateRangeStr)';
  }

  String _getBalanceSummary(List<LeaveRequest> allLeaves, String empId, String type) {
    double totalAllocated = 0;
    double totalTaken = 0;

    for (final l in allLeaves) {
      if (l.employeeId == empId && l.leaveType == type && !l.isDeleted) {
        if (l.isAllocation && l.isApproved) {
          totalAllocated += l.daysCount;
        } else if (!l.isAllocation && l.isApproved) {
          totalTaken += l.daysCount;
        }
      }
    }

    if (totalAllocated <= 0) totalAllocated = 20.0;
    final remaining = totalAllocated - totalTaken;
    final remStr = remaining.toStringAsFixed(remaining.truncateToDouble() == remaining ? 0 : 1);
    final totStr = totalAllocated.toStringAsFixed(totalAllocated.truncateToDouble() == totalAllocated ? 0 : 1);

    return '$type ($remStr restant sur ${totStr}jours)';
  }

  // Transitions for multi-level approval
  void _transitionToSecondApproval() {
    setState(() {
      _status = 'second_approval';
      _chatterLogs.insert(0, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'maintenant',
        'message': 'Demande de congés\n• À approuver ➔ Deuxième approbation (Statut)',
      });
      _chatterLogs.insert(1, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'maintenant',
        'message': 'Approbation des congés terminée',
      });
    });
  }

  void _transitionToApproved() {
    setState(() {
      _status = 'approved';
      _chatterLogs.insert(0, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'maintenant',
        'message': 'Demande de congés\n• Deuxième approbation ➔ Approuvé (Statut)',
      });
      _chatterLogs.insert(1, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'maintenant',
        'message': 'Deuxième approbation des Congés terminée',
      });
      _chatterLogs.insert(2, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'maintenant',
        'message': 'Votre $_leaveType planifié le ${_formatDate(_startDate)} 08:00:00 a été accepté',
      });
    });
  }

  void _transitionToRefused() {
    setState(() {
      _status = 'rejected';
      _chatterLogs.insert(0, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'maintenant',
        'message': 'Demande de congé refusée',
      });
    });
  }

  void _transitionToDraft() {
    setState(() {
      _status = 'draft';
      _chatterLogs.insert(0, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'maintenant',
        'message': 'Marqué comme en brouillon',
      });
    });
  }

  Future<void> _saveLeaveRequest() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (widget.leave != null) {
      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!isOnline) return;
    }

    setState(() => _isSaving = true);
    if (!mounted) return;

    try {
      final duration = double.tryParse(_daysCountCtrl.text.replaceAll(',', '.')) ?? 1.0;
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      final empState = context.read<EmployeesBloc>().state;
      final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];

      String empId = _selectedEmployeeId ?? (employees.isNotEmpty ? employees.first.id : '');
      String empName = _selectedEmployeeName ?? (employees.isNotEmpty ? employees.first.fullName : 'Collaborateur');

      final found = employees.where((e) => e.id == empId).toList();
      if (found.isNotEmpty) {
        empName = found.first.fullName;
      }

      final req = LeaveRequest(
        id: widget.leave?.id ?? const Uuid().v4(),
        employeeId: empId,
        employeeName: empName,
        description: _descriptionCtrl.text.trim().isNotEmpty ? _descriptionCtrl.text.trim() : null,
        leaveType: _leaveType,
        mode: _mode,
        startDate: _startDate,
        endDate: _endDate,
        daysCount: duration,
        unit: _unit,
        status: _status,
        isAllocation: false,
        approvedBy: _status == 'approved' ? (PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator') : null,
        enterpriseId: currentEntId,
        createdAt: widget.leave?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final isOnline = ConnectivityService.instance.isOnline;
      if (widget.leave == null) {
        context.read<LeavesBloc>().add(AddLeaveRequest(req));
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
                        ? 'Demande de congé enregistrée avec succès'
                        : 'Demande enregistrée hors ligne (en attente de synchronisation)',
                  ),
                ],
              ),
              backgroundColor: isOnline ? AppColors.success : AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        context.read<LeavesBloc>().add(UpdateLeaveRequest(req));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Demande de congé mise à jour avec succès'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      widget.onSave?.call(req);
      if (mounted) {
        Navigator.of(context).pop(req);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addChatterMessage() {
    final text = _chatterCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _chatterLogs.insert(0, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'À l\'instant',
        'message': text,
      });
      _chatterCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return BlocBuilder<LeavesBloc, LeavesState>(
      builder: (context, leavesState) {
        final allLeaves = leavesState is LeavesLoaded ? leavesState.leaves : <LeaveRequest>[];

        return BlocBuilder<EmployeesBloc, EmployeesState>(
          builder: (context, empState) {
            final employees = empState is EmployeesLoaded ? empState.employees.where((e) => e.isActive).toList() : <Employee>[];

            if (_selectedEmployeeId == null && employees.isNotEmpty) {
              _selectedEmployeeId = employees.first.id;
              _selectedEmployeeName = employees.first.fullName;
            }

            final currentEmp = employees.where((e) => e.id == _selectedEmployeeId).isNotEmpty
                ? employees.firstWhere((e) => e.id == _selectedEmployeeId)
                : (employees.isNotEmpty ? employees.first : null);

            return Dialog(
              insetPadding: isMobile
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
                  : const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _isDetailedView ? 1180 : 540,
                  maxHeight: size.height * 0.94,
                ),
                child: Form(
                  key: _formKey,
                  child: _isDetailedView
                      ? _buildDetailedScreen(isMobile, employees, currentEmp)
                      : _buildQuickModal(context, employees, allLeaves),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // IMAGE 2: QUICK MODAL ("Demande de congés")
  // ==========================================
  Widget _buildQuickModal(BuildContext context, List<Employee> employees, List<LeaveRequest> allLeaves) {
    final balanceSummary = _getBalanceSummary(allLeaves, _selectedEmployeeId ?? '', _leaveType);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modal Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Row(
            children: [
              const Text(
                'Demande de congés',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Vue détaillée',
                icon: const Icon(Icons.open_in_full_rounded, size: 16, color: Color(0xFF64748B)),
                onPressed: () => setState(() => _isDetailedView = true),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Modal Body
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (employees.length > 1) ...[
                _buildQuickRow(
                  label: 'Employé',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedEmployeeId,
                    decoration: _inputDecoration(),
                    items: employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final emp = employees.firstWhere((e) => e.id == val);
                        setState(() {
                          _selectedEmployeeId = emp.id;
                          _selectedEmployeeName = emp.fullName;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Row 1: Type de congés with dynamic remaining badge
              _buildQuickRow(
                label: 'Type de congés',
                child: DropdownButtonFormField<String>(
                  initialValue: _leaveTypes.contains(_leaveType) ? _leaveType : _leaveTypes.first,
                  decoration: _inputDecoration(),
                  items: _leaveTypes.map((t) {
                    final display = t == _leaveType ? balanceSummary : t;
                    return DropdownMenuItem(
                      value: t,
                      child: Text(
                        display,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: t == _leaveType ? FontWeight.bold : FontWeight.normal,
                          color: t == _leaveType ? _odooPurple : const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _leaveType = val);
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Row 2: Dates (11/11/2024 ➔ 11/11/2024)
              _buildQuickRow(
                label: 'Dates',
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateRange(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(_formatDate(_startDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF64748B)),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateRange(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(_formatDate(_endDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Row 3: Durée ? (1,00 Jours)
              _buildQuickRow(
                label: 'Durée ?',
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _daysCountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        decoration: _inputDecoration(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Jours', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Row 4: Description (Ajouter une description...)
              _buildQuickRow(
                label: 'Description',
                child: TextFormField(
                  controller: _descriptionCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _inputDecoration(hint: 'Ajouter une description...'),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Modal Footer (Enregistrer | Ignorer)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _odooPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _saveLeaveRequest,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ignorer', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  // ========================================================
  // IMAGES 2 & 3: DETAILED VALIDATION SCREEN
  // ========================================================
  Widget _buildDetailedScreen(bool isMobile, List<Employee> employees, Employee? currentEmp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Header Toolbar matching Images 2 & 3
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: _odooGrayBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _odooPurple,
                  side: const BorderSide(color: _odooPurple, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  setState(() {
                    _descriptionCtrl.clear();
                    _startDate = DateTime.now();
                    _endDate = DateTime.now();
                    _daysCountCtrl.text = '1,0';
                    _status = 'to_approve';
                  });
                },
                child: const Text('Nouveau', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tous les congés', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Text(
                      _getTitle(),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Fermer',
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // 2. Action Sub-Bar: Dynamic buttons matching Image 2 vs Image 3 + 3-step Stepper
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              if (_status == 'second_approval') ...[
                // Image 2: Valider | Refuser
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  onPressed: _transitionToApproved,
                  child: const Text('Valider', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _transitionToRefused,
                  child: const Text('Refuser', style: TextStyle(fontSize: 13)),
                ),
              ] else if (_status == 'approved') ...[
                // Image 3: Only Refuser remains!
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _transitionToRefused,
                  child: const Text('Refuser', style: TextStyle(fontSize: 13)),
                ),
              ] else ...[
                // Default / to_approve: Approuver | Refuser | Marqué comme en brouillon
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _odooPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  onPressed: _transitionToSecondApproval,
                  child: const Text('Approuver', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _transitionToRefused,
                  child: const Text('Refuser', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _transitionToDraft,
                  child: const Text('Marqué comme en brouillon', style: TextStyle(fontSize: 12.5)),
                ),
              ],

              const Spacer(),

              // Status Stepper: [ À approuver | Deuxième approbation | Approuvé ]
              _buildDetailedStepper(),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // 3. Body: Left Form + Middle Summary Card (Images 2 & 3) + Right Chatter
        Expanded(
          child: isMobile
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailedFormContent(employees),
                      const SizedBox(height: 16),
                      _buildMiddleEmployeeCard(currentEmp),
                      const Divider(height: 32, color: Color(0xFFE2E8F0)),
                      _buildChatterPanel(),
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Form
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildDetailedFormContent(employees),
                      ),
                    ),
                    // Middle Card (Images 2 & 3: "Alex in 2024")
                    _buildMiddleEmployeeCard(currentEmp),
                    Container(width: 1, color: const Color(0xFFE2E8F0)),
                    // Right Chatter
                    Expanded(
                      flex: 4,
                      child: _buildChatterPanel(),
                    ),
                  ],
                ),
        ),

        // 4. Footer
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (widget.leave != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: _odooRed),
                  label: const Text('Supprimer', style: TextStyle(color: _odooRed)),
                  onPressed: _isSaving
                      ? null
                      : () {
                          OfflineActionHelper.executeAction(
                            context: context,
                            action: 'delete',
                            customActionLabel: 'la demande de congé',
                            onConfirmed: () {
                              context.read<LeavesBloc>().add(DeleteLeaveRequest(widget.leave!.id));
                              Navigator.of(context).pop();
                            },
                          );
                        },
                ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _odooPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _isSaving ? null : _saveLeaveRequest,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Enregistrer le congé'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3-step Odoo Stepper: À approuver ➔ Deuxième approbation ➔ Approuvé
  Widget _buildDetailedStepper() {
    final isApproved = _status == 'approved';
    final isPending = _status == 'to_approve' || _status == 'pending';
    final isSecond = _status == 'second_approval';
    final isRejected = _status == 'rejected' || _status == 'refused';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step 1: À approuver
          InkWell(
            onTap: () => setState(() => _status = 'to_approve'),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: isPending ? _odooPurpleLight : Colors.transparent,
              child: Text(
                'À approuver',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isPending ? FontWeight.bold : FontWeight.w500,
                  color: isPending ? _odooPurple : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 26, color: const Color(0xFFCBD5E1)),

          // Step 2: Deuxième approbation (Image 2)
          InkWell(
            onTap: () => setState(() => _status = 'second_approval'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: isSecond ? const Color(0xFFFEF3C7) : Colors.transparent,
              child: Text(
                'Deuxième approbation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSecond ? FontWeight.bold : FontWeight.w500,
                  color: isSecond ? const Color(0xFFD97706) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 26, color: const Color(0xFFCBD5E1)),

          // Step 3: Approuvé (Image 3)
          InkWell(
            onTap: () => setState(() => _status = 'approved'),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: isApproved ? const Color(0xFFD1FAE5) : (isRejected ? const Color(0xFFFEE2E2) : Colors.transparent),
              child: Text(
                isRejected ? 'Refusé' : 'Approuvé',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: (isApproved || isRejected) ? FontWeight.bold : FontWeight.w500,
                  color: isApproved ? _odooGreen : (isRejected ? _odooRed : const Color(0xFF64748B)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedFormContent(List<Employee> employees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTitle(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 20),

        _buildQuickRow(
          label: 'Mode ?',
          child: DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: _inputDecoration(),
            items: ['Par employé', 'Par département', 'Par catégorie d\'employé']
                .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _mode = val);
            },
          ),
        ),
        const SizedBox(height: 14),

        _buildQuickRow(
          label: 'Employés',
          child: Row(
            children: [
              _buildAvatarBox(_selectedEmployeeName ?? 'A'),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: employees.any((e) => e.id == _selectedEmployeeId)
                      ? _selectedEmployeeId
                      : (employees.isNotEmpty ? employees.first.id : null),
                  decoration: _inputDecoration(),
                  items: employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final emp = employees.firstWhere((e) => e.id == val);
                      setState(() {
                        _selectedEmployeeId = emp.id;
                        _selectedEmployeeName = emp.fullName;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _buildQuickRow(
          label: 'Type de congés',
          child: DropdownButtonFormField<String>(
            initialValue: _leaveTypes.contains(_leaveType) ? _leaveType : _leaveTypes.first,
            decoration: _inputDecoration(),
            items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _leaveType = val);
            },
          ),
        ),
        const SizedBox(height: 14),

        _buildQuickRow(
          label: 'Dates',
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDateRange(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_formatDate(_startDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF64748B)),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDateRange(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_formatDate(_endDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _buildQuickRow(
          label: 'Durée ?',
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: _daysCountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  decoration: _inputDecoration(),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Jours', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _buildQuickRow(
          label: 'Description',
          child: TextFormField(
            controller: _descriptionCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDecoration(hint: 'Ajouter un motif ou une description...'),
          ),
        ),
      ],
    );
  }

  // Middle employee summary card matching Images 2 & 3 ("Alex in 2024")
  Widget _buildMiddleEmployeeCard(Employee? emp) {
    final empName = _selectedEmployeeName ?? 'Employé';
    final dept = emp?.department.isNotEmpty == true ? emp!.department : 'IT';
    final dur = double.tryParse(_daysCountCtrl.text.replaceAll(',', '.')) ?? 1.0;
    final durStr = '${dur.toStringAsFixed(dur.truncateToDouble() == dur ? 0 : 1)} jour(s)';

    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$empName in ${DateTime.now().year}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Text(
            _status == 'approved' ? _leaveType : 'Aucun',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          if (_status == 'approved') ...[
            Text(durStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
          const SizedBox(height: 12),
          Text(
            dept,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Text(
            _status == 'approved' ? '$empName: $durStr' : 'Aucun',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          if (_status == 'approved') ...[
            Text('${_formatDate(_startDate)} - ${_formatDate(_endDate)}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ],
      ),
    );
  }

  // Chatter panel with planned activity box matching Image 2
  Widget _buildChatterPanel() {
    return Container(
      color: const Color(0xFFFAFBFD),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _odooPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _addChatterMessage,
                child: const Text('Envoyer un message', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _addChatterMessage,
                child: const Text('Note', style: TextStyle(fontSize: 11.5)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {},
                child: const Text('Activités', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Planned activity box matching Image 2
          if (_status == 'second_approval') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF16A34A)),
                      SizedBox(width: 6),
                      Text('Activités planifiées', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatarBox('Administrator'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dû dans 7 jours : Deuxième approbation des Congés pour Administrator',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                            const SizedBox(height: 2),
                            Text('Deuxième demande d\'approbation pour $_leaveType', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                InkWell(
                                  onTap: _transitionToApproved,
                                  child: Row(
                                    children: const [
                                      Icon(Icons.check_rounded, size: 14, color: Color(0xFF16A34A)),
                                      SizedBox(width: 3),
                                      Text('Fait', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () {},
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                                      SizedBox(width: 3),
                                      Text('Modifier', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () {},
                                  child: Row(
                                    children: const [
                                      Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                                      SizedBox(width: 3),
                                      Text('Annuler', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatterCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: _inputDecoration(hint: 'Écrire un message...'),
                  onSubmitted: (_) => _addChatterMessage(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 18, color: _odooPurple),
                onPressed: _addChatterMessage,
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          Expanded(
            child: ListView.separated(
              itemCount: _chatterLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final log = _chatterLogs[idx];
                final author = log['author']?.toString() ?? 'Administrator';
                final time = log['time']?.toString() ?? '';
                final msg = log['message']?.toString() ?? '';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarBox(author),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(author, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              Text('• $time', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(msg, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarBox(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _odooPurple, width: 1.5)),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _odooPurple,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _updateDates(picked.start, picked.end);
    }
  }
}
