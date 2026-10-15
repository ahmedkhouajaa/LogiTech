import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../blocs/leaves/leaves_bloc.dart';
import '../blocs/leaves/leaves_event.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../models/leave_request.dart';
import '../models/employee.dart';
import '../services/permission_service.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

/// Modal d'allocation de congé / Congé conforme à Odoo ERP (Images 1, 2 & 3)
/// Supporte Desktop, Web et Android avec mise en page responsive
class LeaveAllocationDialog extends StatefulWidget {
  final LeaveRequest? leave;
  final Employee? employee;
  final Function(LeaveRequest)? onSave;

  const LeaveAllocationDialog({
    super.key,
    this.leave,
    this.employee,
    this.onSave,
  });

  static Future<LeaveRequest?> show(
    BuildContext context, {
    LeaveRequest? leave,
    Employee? employee,
    Function(LeaveRequest)? onSave,
  }) {
    return showDialog<LeaveRequest>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LeaveAllocationDialog(
        leave: leave,
        employee: employee,
        onSave: onSave,
      ),
    );
  }

  @override
  State<LeaveAllocationDialog> createState() => _LeaveAllocationDialogState();
}

class _LeaveAllocationDialogState extends State<LeaveAllocationDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Odoo Accent Colors
  static const Color _odooPurple = Color(0xFF1A56DB);
  static const Color _odooPurpleLight = Color(0xFFEFF6FF);
  static const Color _odooGreen = Color(0xFF10B981);
  static const Color _odooRed = Color(0xFFEF4444);
  static const Color _odooGrayBg = Color(0xFFF8FAFC);

  // Form Controllers
  late TextEditingController _descriptionCtrl;
  late TextEditingController _daysCountCtrl;
  late TextEditingController _reasonCtrl;
  late TextEditingController _chatterCtrl;

  // Form State
  late String _leaveType;
  late String _allocationType; // "Allocation régulière", "Allocation du cumul de congés"
  late String _mode; // "Par employé", "Par entreprise", "Par département", "Par catégorie d'employé"
  late DateTime _validityStartDate;
  DateTime? _validityEndDate;
  late bool _isUnlimitedValidity;
  late String _unit; // "Jours", "Heures"
  late String _status; // 'pending' (À approuver), 'approved' (Approuvé), 'rejected' (Refusé)

  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  String? _selectedDepartment;
  String? _selectedCategory;

  // Internal Chatter entries
  final List<Map<String, dynamic>> _chatterLogs = [];

  final List<String> _leaveTypes = [
    'Congés payés',
    'Congé de maladie',
    'Congé de maternité / paternité',
    'Congé sans solde',
    'Événement familial',
    'Récupération',
  ];

  final List<String> _modes = [
    'Par employé',
    'Par entreprise',
    'Par département',
    'Par catégorie d\'employé',
  ];

  final List<String> _departments = [
    'Administration',
    'Ressources Humaines',
    'Technique & IT',
    'Commercial & Vente',
    'Finance & Comptabilité',
    'Logistique & Opérations',
  ];

  @override
  void initState() {
    super.initState();
    final l = widget.leave;
    final emp = widget.employee;

    _descriptionCtrl = TextEditingController(text: l?.description ?? (l == null ? '' : 'Solde annuel'));
    _daysCountCtrl = TextEditingController(
        text: l != null
            ? l.daysCount.toStringAsFixed(l.daysCount.truncateToDouble() == l.daysCount ? 0 : 2)
            : '20,00');
    _reasonCtrl = TextEditingController(text: l?.reason ?? '');
    _chatterCtrl = TextEditingController();

    _leaveType = l?.leaveType ?? 'Congés payés';
    _allocationType = l?.allocationType ?? 'Allocation régulière';
    _mode = l?.mode ?? 'Par employé';
    _validityStartDate = l?.validityStartDate ?? DateTime(DateTime.now().year, 1, 1);
    _validityEndDate = l?.validityEndDate;
    _isUnlimitedValidity = l?.isUnlimitedValidity ?? true;
    _unit = l?.unit ?? 'Jours';
    _status = l?.status ?? (l == null ? 'pending' : 'approved');

    _selectedEmployeeId = l?.employeeId ?? emp?.id;
    _selectedEmployeeName = l?.employeeName ?? emp?.fullName;
    _selectedDepartment = l?.department ?? emp?.department ?? 'Administration';
    _selectedCategory = l?.employeeCategory ?? 'Cadre';

    // Initialize Chatter log history
    if (l != null) {
      _chatterLogs.add({
        'author': l.approvedBy ?? 'Administrator',
        'time': DateFormat('dd/MM/yyyy HH:mm').format(l.createdAt),
        'message': 'Création d\'un nouvel enregistrement...',
        'isSystem': true,
      });
      if (l.isApproved) {
        _chatterLogs.add({
          'author': l.approvedBy ?? 'Administrator',
          'time': DateFormat('dd/MM/yyyy HH:mm').format(l.updatedAt),
          'message': 'Allocation validée et approuvée.',
          'isSystem': true,
        });
      } else if (l.isRejected) {
        _chatterLogs.add({
          'author': l.approvedBy ?? 'Administrator',
          'time': DateFormat('dd/MM/yyyy HH:mm').format(l.updatedAt),
          'message': 'Allocation refusée ${l.rejectionReason != null ? ": ${l.rejectionReason}" : ""}',
          'isSystem': true,
        });
      }
    } else {
      _chatterLogs.add({
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'Aujourd\'hui',
        'message': 'Création d\'un nouvel enregistrement...',
        'isSystem': true,
      });
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _daysCountCtrl.dispose();
    _reasonCtrl.dispose();
    _chatterCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _buildBreadcrumbTitle() {
    final empName = _selectedEmployeeName ?? 'Employé';
    final parsedDays = double.tryParse(_daysCountCtrl.text.replaceAll(',', '.')) ?? 20.0;
    final daysStr = '${parsedDays.toStringAsFixed(parsedDays.truncateToDouble() == parsedDays ? 0 : 2)} $_unit';
    if (widget.leave == null && _descriptionCtrl.text.trim().isEmpty) {
      return 'Nouveau';
    }
    final title = _descriptionCtrl.text.trim().isNotEmpty
        ? _descriptionCtrl.text.trim()
        : 'Allocation de $_leaveType: $daysStr au $empName';
    return title;
  }

  void _resetToNew() {
    setState(() {
      _descriptionCtrl.text = '';
      _daysCountCtrl.text = '20,00';
      _reasonCtrl.text = '';
      _leaveType = 'Congés payés';
      _allocationType = 'Allocation régulière';
      _mode = 'Par employé';
      _validityStartDate = DateTime(DateTime.now().year, 1, 1);
      _validityEndDate = null;
      _isUnlimitedValidity = true;
      _status = 'pending';
    });
  }

  void _validateAndApprove() {
    setState(() {
      _status = 'approved';
      _chatterLogs.insert(0, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'À l\'instant',
        'message': 'Allocation validée et approuvée.',
        'isSystem': true,
      });
    });
  }

  void _refuseAllocation() {
    setState(() {
      _status = 'rejected';
      _chatterLogs.insert(0, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'À l\'instant',
        'message': 'Allocation refusée.',
        'isSystem': true,
      });
    });
  }

  void _addChatterMessage() {
    final text = _chatterCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _chatterLogs.insert(0, {
        'author': PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator',
        'time': 'À l\'instant',
        'message': text,
        'isSystem': false,
      });
      _chatterCtrl.clear();
    });
  }

  Future<void> _saveAllocation() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (widget.leave != null) {
      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!isOnline) return;
    }

    setState(() => _isSaving = true);
    if (!mounted) return;

    try {
      final days = double.tryParse(_daysCountCtrl.text.replaceAll(',', '.')) ?? 20.0;
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      final empState = context.read<EmployeesBloc>().state;
      final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];

      String empId = _selectedEmployeeId ?? (employees.isNotEmpty ? employees.first.id : '');
      String empName = _selectedEmployeeName ?? (employees.isNotEmpty ? employees.first.fullName : 'Collaborateur');

      if (_mode == 'Par employé') {
        final found = employees.where((e) => e.id == empId).toList();
        if (found.isNotEmpty) {
          empName = found.first.fullName;
        }
      } else if (_mode == 'Par département') {
        empName = 'Département ${_selectedDepartment ?? ''}';
      } else if (_mode == 'Par entreprise') {
        empName = 'Toute l\'entreprise';
      } else {
        empName = 'Catégorie ${_selectedCategory ?? ''}';
      }

      final leaveReq = LeaveRequest(
        id: widget.leave?.id ?? const Uuid().v4(),
        employeeId: empId,
        employeeName: empName,
        employeeAvatar: null,
        description: _descriptionCtrl.text.trim().isNotEmpty ? _descriptionCtrl.text.trim() : 'Solde annuel',
        leaveType: _leaveType,
        allocationType: _allocationType,
        mode: _mode,
        startDate: _validityStartDate,
        endDate: _validityEndDate ?? _validityStartDate.add(const Duration(days: 365)),
        validityStartDate: _validityStartDate,
        validityEndDate: _isUnlimitedValidity ? null : _validityEndDate,
        isUnlimitedValidity: _isUnlimitedValidity,
        daysCount: days,
        unit: _unit,
        department: _selectedDepartment,
        employeeCategory: _selectedCategory,
        status: _status,
        reason: _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : null,
        approvedBy: _status == 'approved' ? (PermissionService.instance.userName.isNotEmpty ? PermissionService.instance.userName : 'Administrator') : null,
        enterpriseId: currentEntId,
        createdAt: widget.leave?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final isOnline = ConnectivityService.instance.isOnline;
      if (widget.leave == null) {
        context.read<LeavesBloc>().add(AddLeaveRequest(leaveReq));
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
                        ? 'Allocation de congé enregistrée'
                        : 'Allocation enregistrée hors ligne (en attente de synchronisation)',
                  ),
                ],
              ),
              backgroundColor: isOnline ? AppColors.success : AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        context.read<LeavesBloc>().add(UpdateLeaveRequest(leaveReq));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Allocation mise à jour avec succès'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      widget.onSave?.call(leaveReq);
      if (mounted) {
        Navigator.of(context).pop(leaveReq);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _deleteAllocation() {
    if (widget.leave == null) return;
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: "l'allocation de congé",
      onConfirmed: () {
        context.read<LeavesBloc>().add(DeleteLeaveRequest(widget.leave!.id));
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 14)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1180,
          maxHeight: size.height * 0.94,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Toolbar (Odoo Style)
              _buildTopHeaderToolbar(isMobile),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 2. Action Sub-bar with "Valider", "Refuser", and Status Stepper
              _buildActionStepperBar(isMobile),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 3. Main Body: Left Form + Right Chatter
              Expanded(
                child: isMobile ? _buildMobileBody() : _buildDesktopBody(),
              ),

              // 4. Bottom Footer (Save, Delete, Close)
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildFooterActions(),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Header Toolbar matching Image 1 top bar
  Widget _buildTopHeaderToolbar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _odooGrayBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          // "Nouveau" Button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _odooPurple,
              side: const BorderSide(color: _odooPurple, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _resetToNew,
            child: const Text('Nouveau', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),

          // Breadcrumb Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Allocations', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                Text(
                  _buildBreadcrumbTitle(),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Action Icons
          IconButton(
            tooltip: 'Paramètres',
            icon: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Synchronisé',
            icon: const Icon(Icons.cloud_done_outlined, size: 18, color: Color(0xFF10B981)),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Réinitialiser',
            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
            onPressed: _resetToNew,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // 2. Action Sub-Bar: Valider / Refuser + Stepper
  Widget _buildActionStepperBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Action Buttons
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _odooPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            onPressed: _validateAndApprove,
            child: const Text('Valider', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              backgroundColor: const Color(0xFFF1F5F9),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _refuseAllocation,
            child: const Text('Refuser', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),

          const Spacer(),

          // Odoo Stepper: [ À approuver | Approuvé ]
          _buildOdooStepper(),
        ],
      ),
    );
  }

  Widget _buildOdooStepper() {
    final isApproved = _status == 'approved';
    final isPending = _status == 'pending' || _status == 'to_approve';
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
            onTap: () => setState(() => _status = 'pending'),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPending ? _odooPurpleLight : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
              ),
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
          // Step 2: Approuvé
          InkWell(
            onTap: () => setState(() => _status = 'approved'),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isApproved ? const Color(0xFFD1FAE5) : (isRejected ? const Color(0xFFFEE2E2) : Colors.transparent),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
              ),
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

  // Desktop Body: Two Columns (Left: Form, Right: Chatter)
  Widget _buildDesktopBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Form Area
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitlePlaceholderField(),
                const SizedBox(height: 24),
                _buildFormGrid(),
              ],
            ),
          ),
        ),

        // Vertical divider between form and chatter
        Container(width: 1, color: const Color(0xFFE2E8F0)),

        // Right Chatter Area
        Expanded(
          flex: 4,
          child: _buildChatterPanel(),
        ),
      ],
    );
  }

  // Mobile Body: Stacked
  Widget _buildMobileBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitlePlaceholderField(),
          const SizedBox(height: 18),
          _buildFormGrid(),
          const Divider(height: 32, color: Color(0xFFE2E8F0)),
          _buildChatterPanel(),
        ],
      ),
    );
  }

  // Title / Subject field matching Image 1
  Widget _buildTitlePlaceholderField() {
    return TextFormField(
      controller: _descriptionCtrl,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
      decoration: const InputDecoration(
        hintText: 'par ex. Type de congé (Du début de la validité à la fin de la validité / pas de ...)',
        hintStyle: TextStyle(fontSize: 14.5, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
        border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _odooPurple, width: 2)),
        contentPadding: EdgeInsets.symmetric(vertical: 8),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // Main Form Grid
  Widget _buildFormGrid() {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded ? empState.employees.where((e) => e.isActive).toList() : <Employee>[];

        // Ensure selected employee is valid
        if (_selectedEmployeeId == null && employees.isNotEmpty) {
          _selectedEmployeeId = employees.first.id;
          _selectedEmployeeName = employees.first.fullName;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Type de congés
            _buildFieldRow(
              label: 'Type de congés',
              child: DropdownButtonFormField<String>(
                initialValue: _leaveTypes.contains(_leaveType) ? _leaveType : _leaveTypes.first,
                decoration: _fieldInputDecoration(),
                items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _leaveType = val);
                },
              ),
            ),
            const SizedBox(height: 14),

            // Row 2: Type d'allocation (Radio)
            _buildFieldRow(
              label: 'Type d\'allocation',
              child: RadioGroup<String>(
                groupValue: _allocationType,
                onChanged: (v) {
                  if (v != null) setState(() => _allocationType = v);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Allocation régulière',
                          activeColor: _odooPurple,
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text('Allocation régulière', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                      ],
                    ),
                    Row(
                      children: [
                        Radio<String>(
                          value: 'Allocation du cumul de congés',
                          activeColor: _odooPurple,
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text('Allocation du cumul de congés', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Row 3: Période de validité
            _buildFieldRow(
              label: 'Période de validité',
              child: Row(
                children: [
                  // Start Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _validityStartDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _validityStartDate = picked);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(_formatDate(_validityStartDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        ],
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF64748B)),
                  ),

                  // End Date or "Sans limites"
                  if (_isUnlimitedValidity)
                    InkWell(
                      onTap: () => setState(() => _isUnlimitedValidity = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('Sans limites', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                            SizedBox(width: 6),
                            Icon(Icons.edit_calendar_outlined, size: 14, color: _odooPurple),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _validityEndDate ?? _validityStartDate.add(const Duration(days: 365)),
                              firstDate: _validityStartDate,
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) setState(() => _validityEndDate = picked);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _validityEndDate != null ? _formatDate(_validityEndDate!) : 'Choisir date',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rendre sans limites',
                          icon: const Icon(Icons.all_inclusive_rounded, size: 16, color: _odooPurple),
                          onPressed: () => setState(() {
                            _isUnlimitedValidity = true;
                            _validityEndDate = null;
                          }),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Row 4: Allocation
            _buildFieldRow(
              label: 'Allocation ?',
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _daysCountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      decoration: _fieldInputDecoration(),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Requis';
                        final n = double.tryParse(val.replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _unit,
                        items: ['Jours', 'Heures'].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (u) {
                          if (u != null) setState(() => _unit = u);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Row 5: Mode ?
            _buildFieldRow(
              label: 'Mode ?',
              child: DropdownButtonFormField<String>(
                initialValue: _modes.contains(_mode) ? _mode : _modes.first,
                decoration: _fieldInputDecoration(),
                items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _mode = val);
                },
              ),
            ),
            const SizedBox(height: 14),

            // Row 6: Employés (or Département / Catégorie according to Mode)
            if (_mode == 'Par employé') ...[
              _buildFieldRow(
                label: 'Employés',
                child: Row(
                  children: [
                    // Avatar square with initial letter like in Image 1 ([A] Administrator)
                    _buildAvatarBox(_selectedEmployeeName ?? 'A'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: employees.any((e) => e.id == _selectedEmployeeId)
                            ? _selectedEmployeeId
                            : (employees.isNotEmpty ? employees.first.id : null),
                        decoration: _fieldInputDecoration(),
                        items: employees.map((e) {
                          return DropdownMenuItem(
                            value: e.id,
                            child: Row(
                              children: [
                                Text(e.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                if (e.department.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text('(${e.department})', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
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
            ] else if (_mode == 'Par département') ...[
              _buildFieldRow(
                label: 'Département',
                child: DropdownButtonFormField<String>(
                  initialValue: _departments.contains(_selectedDepartment) ? _selectedDepartment : _departments.first,
                  decoration: _fieldInputDecoration(),
                  items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _selectedDepartment = val),
                ),
              ),
            ] else if (_mode == 'Par catégorie d\'employé') ...[
              _buildFieldRow(
                label: 'Catégorie',
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: _fieldInputDecoration(),
                  items: ['Cadre', 'Salarié', 'Technicien', 'Ouvrier', 'Stagiaire']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Row 7: Ajouter un motif... (Multilines note)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motif / Justification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: 'Ajouter un motif pour cette allocation...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  InputDecoration _fieldInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _odooPurple, width: 1.5)),
    );
  }

  Widget _buildAvatarBox(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFC2410C), // Reddish-brown matching screenshot
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  // Right Chatter Panel matching Image 1
  Widget _buildChatterPanel() {
    return Container(
      color: const Color(0xFFFAFBFD),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons: Envoyer un message | Note | Activités
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _odooPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: () => _addChatterMessage(),
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
                onPressed: () => _addChatterMessage(),
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

          // Message input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatterCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Écrire un message ou une note...',
                    hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
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

          // "Aujourd'hui" Divider
          Row(
            children: const [
              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Aujourd\'hui', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            ],
          ),

          const SizedBox(height: 10),

          // Chatter Feed
          Expanded(
            child: ListView.separated(
              itemCount: _chatterLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                              Text(author, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              const SizedBox(width: 6),
                              Text('• $time', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            msg,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
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

  // Footer Actions
  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          if (widget.leave != null)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: _odooRed),
              label: const Text('Supprimer', style: TextStyle(color: _odooRed, fontSize: 13)),
              onPressed: _deleteAllocation,
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _odooPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            onPressed: _isSaving ? null : _saveAllocation,
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
                      Text('Enregistrer l\'allocation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
