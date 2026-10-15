import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';

import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_event.dart';
import '../blocs/contracts/contracts_bloc.dart';
import '../blocs/contracts/contracts_state.dart';
import '../blocs/payroll/payroll_bloc.dart';
import '../blocs/payroll/payroll_state.dart';
import '../blocs/loans/loans_bloc.dart';
import '../blocs/loans/loans_state.dart';
import '../models/employee.dart';
import '../models/employee_contract.dart';
import '../models/employee_loan.dart';
import '../models/payslip.dart';
import 'contract_form_dialog.dart';
import 'payslip_form_dialog.dart';
import 'employee_loan_dialog.dart';
import 'leave_allocation_dialog.dart';
import '../services/enterprise_service.dart';
import '../blocs/leaves/leaves_bloc.dart';
import '../blocs/leaves/leaves_state.dart';
import '../models/leave_request.dart';
import '../blocs/attendance/attendance_bloc.dart';
import '../blocs/attendance/attendance_state.dart';
import '../models/attendance.dart';
import 'attendance_form_dialog.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class EmployeeFormDialog extends StatefulWidget {
  final Employee? employee;

  const EmployeeFormDialog({super.key, this.employee});

  static Future<void> show(BuildContext context, {Employee? employee}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmployeeFormDialog(employee: employee),
    );
  }

  @override
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Header / Basic info
  late TextEditingController _fnCtrl;
  late TextEditingController _lnCtrl;
  late TextEditingController _jobCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _workMobileCtrl;
  late TextEditingController _workPhoneCtrl;
  late TextEditingController _workEmailCtrl;
  late TextEditingController _managerCtrl;
  late TextEditingController _mentorCtrl;
  String _department = 'Administration';

  // Professional Tab
  late TextEditingController _salaryCtrl;
  late TextEditingController _ribCtrl;
  late TextEditingController _notesCtrl;
  DateTime _hireDate = DateTime.now();
  String _contractType = 'CDI';
  String _paymentMethod = 'Virement bancaire';

  // Private Tab: Coordonnées
  late TextEditingController _privStreetCtrl;
  late TextEditingController _privStreet2Ctrl;
  late TextEditingController _privCityCtrl;
  late TextEditingController _privStateCtrl;
  late TextEditingController _privZipCtrl;
  late TextEditingController _privCountryCtrl;
  late TextEditingController _privEmailCtrl;
  late TextEditingController _privPhoneCtrl;
  late TextEditingController _languageCtrl;
  late TextEditingController _distanceKmCtrl;
  late TextEditingController _carPlateCtrl;

  // Private Tab: Situation familiale
  String _maritalStatus = 'Célibataire';
  bool _isHeadOfFamily = false;
  late TextEditingController _spouseNameCtrl;
  DateTime? _spouseBirthDate;
  late TextEditingController _spouseJobCtrl;
  List<EmployeeChild> _children = [];

  // Citizenship Tab
  late TextEditingController _nationalityCtrl;
  late TextEditingController _cinCtrl;
  late TextEditingController _cnssCtrl;
  late TextEditingController _employerCodeCtrl;
  late TextEditingController _socialSecCtrl;
  late TextEditingController _passportCtrl;
  String _gender = 'Homme';
  DateTime? _birthDate;
  late TextEditingController _birthPlaceCtrl;
  late TextEditingController _birthCountryCtrl;
  late TextEditingController _visaTypeCtrl;
  DateTime? _workPermitExpiration;
  late TextEditingController _workPermitNumberCtrl;

  // Emergency & Education Tab
  late TextEditingController _emergNameCtrl;
  late TextEditingController _emergPhoneCtrl;
  late TextEditingController _educationCtrl;
  late TextEditingController _fieldOfStudyCtrl;

  final List<String> _departments = [
    'Administration',
    'Direction',
    'Commercial',
    'Technique',
    'Finance & Comptabilité',
    'Ressources Humaines',
    'Production',
    'Logistique',
    'Marketing',
    'Général',
  ];

  final List<String> _maritalStatuses = [
    'Célibataire',
    'Marié(e)',
    'Divorcé(e)',
    'Veuf/Veuve',
    'Autre',
  ];

  final List<String> _contracts = ['CDI', 'CDD', 'SIVP', 'Stage', 'Freelance'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final emp = widget.employee;

    _fnCtrl = TextEditingController(text: emp?.firstName ?? '');
    _lnCtrl = TextEditingController(text: emp?.lastName ?? '');
    _jobCtrl = TextEditingController(text: emp?.jobTitle ?? 'Poste');
    _tagsCtrl = TextEditingController(text: emp?.tags.join(', ') ?? '');
    _workMobileCtrl = TextEditingController(text: emp?.workMobile ?? emp?.phone ?? '');
    _workPhoneCtrl = TextEditingController(text: emp?.workPhone ?? '');
    _workEmailCtrl = TextEditingController(text: emp?.workEmail ?? emp?.email ?? '');
    _managerCtrl = TextEditingController(text: emp?.manager ?? '');
    _mentorCtrl = TextEditingController(text: emp?.mentor ?? '');
    _department = (emp != null && _departments.contains(emp.department))
        ? emp.department
        : 'Administration';

    _salaryCtrl = TextEditingController(text: emp != null ? '${emp.baseSalary}' : '850.000');
    _ribCtrl = TextEditingController(text: emp?.rib ?? '');
    _notesCtrl = TextEditingController(text: emp?.notes ?? '');
    _hireDate = emp?.hireDate ?? DateTime.now();
    _contractType = emp?.contractType ?? 'CDI';
    _paymentMethod = emp?.paymentMethod ?? 'Virement bancaire';

    _privStreetCtrl = TextEditingController(text: emp?.address ?? '');
    _privStreet2Ctrl = TextEditingController(text: emp?.privateAddressStreet2 ?? '');
    _privCityCtrl = TextEditingController(text: emp?.city ?? '');
    _privStateCtrl = TextEditingController(text: emp?.privateAddressState ?? '');
    _privZipCtrl = TextEditingController(text: emp?.privateAddressZip ?? '');
    _privCountryCtrl = TextEditingController(text: emp?.privateAddressCountry ?? 'Tunisie');
    _privEmailCtrl = TextEditingController(text: emp?.personalEmail ?? '');
    _privPhoneCtrl = TextEditingController(text: emp?.personalPhone ?? '');
    _languageCtrl = TextEditingController(text: emp?.preferredLanguage ?? 'Français');
    _distanceKmCtrl = TextEditingController(text: emp?.homeWorkDistanceKm != null ? '${emp!.homeWorkDistanceKm}' : '0');
    _carPlateCtrl = TextEditingController(text: emp?.carPlate ?? '');

    _maritalStatus = emp?.maritalStatus ?? 'Célibataire';
    _isHeadOfFamily = emp?.isHeadOfFamily ?? false;
    _spouseNameCtrl = TextEditingController(text: emp?.spouseName ?? '');
    _spouseBirthDate = emp?.spouseBirthDate;
    _spouseJobCtrl = TextEditingController(text: emp?.spouseJob ?? '');
    _children = emp != null ? List<EmployeeChild>.from(emp.children) : [];

    _nationalityCtrl = TextEditingController(text: emp?.nationality ?? 'Tunisienne');
    _cinCtrl = TextEditingController(text: emp?.cin ?? '');
    _cnssCtrl = TextEditingController(text: emp?.cnssNumber ?? '');
    _employerCodeCtrl = TextEditingController(text: emp?.employerCode ?? emp?.code ?? '');
    _socialSecCtrl = TextEditingController(text: emp?.socialSecurityNumber ?? '');
    _passportCtrl = TextEditingController(text: emp?.passportNumber ?? '');
    _gender = emp?.gender ?? 'Homme';
    _birthDate = emp?.birthDate;
    _birthPlaceCtrl = TextEditingController(text: emp?.birthPlace ?? '');
    _birthCountryCtrl = TextEditingController(text: emp?.birthCountry ?? 'Tunisie');
    _visaTypeCtrl = TextEditingController(text: emp?.visaType ?? '');
    _workPermitExpiration = emp?.workPermitExpiration;
    _workPermitNumberCtrl = TextEditingController(text: emp?.workPermitNumber ?? '');

    _emergNameCtrl = TextEditingController(text: emp?.emergencyContactName ?? '');
    _emergPhoneCtrl = TextEditingController(text: emp?.emergencyContactPhone ?? '');
    _educationCtrl = TextEditingController(text: emp?.educationLevel ?? '');
    _fieldOfStudyCtrl = TextEditingController(text: emp?.fieldOfStudy ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fnCtrl.dispose();
    _lnCtrl.dispose();
    _jobCtrl.dispose();
    _tagsCtrl.dispose();
    _workMobileCtrl.dispose();
    _workPhoneCtrl.dispose();
    _workEmailCtrl.dispose();
    _managerCtrl.dispose();
    _mentorCtrl.dispose();
    _salaryCtrl.dispose();
    _ribCtrl.dispose();
    _notesCtrl.dispose();
    _privStreetCtrl.dispose();
    _privStreet2Ctrl.dispose();
    _privCityCtrl.dispose();
    _privStateCtrl.dispose();
    _privZipCtrl.dispose();
    _privCountryCtrl.dispose();
    _privEmailCtrl.dispose();
    _privPhoneCtrl.dispose();
    _languageCtrl.dispose();
    _distanceKmCtrl.dispose();
    _carPlateCtrl.dispose();
    _spouseNameCtrl.dispose();
    _spouseJobCtrl.dispose();
    _nationalityCtrl.dispose();
    _cinCtrl.dispose();
    _cnssCtrl.dispose();
    _employerCodeCtrl.dispose();
    _socialSecCtrl.dispose();
    _passportCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _birthCountryCtrl.dispose();
    _visaTypeCtrl.dispose();
    _workPermitNumberCtrl.dispose();
    _emergNameCtrl.dispose();
    _emergPhoneCtrl.dispose();
    _educationCtrl.dispose();
    _fieldOfStudyCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--/--/----';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  int get _dependentCount => _children.where((c) => c.isDependent).length;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1080,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Action Toolbar (Odoo style)
              _buildTopBar(context),

              const Divider(height: 1),

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 28,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Profile Card Header
                      _buildProfileHeader(isMobile),

                      const SizedBox(height: 20),

                      // 3. Tab Bar
                      _buildTabBar(),

                      const SizedBox(height: 16),

                      // 4. Tab Views
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          switch (_tabController.index) {
                            case 0:
                              return _buildTabProfessional(isMobile);
                            case 1:
                              return _buildTabPrivateAndFamily(isMobile);
                            case 2:
                              return _buildTabCitizenship(isMobile);
                            case 3:
                              return _buildTabEmergencyAndEducation(isMobile);
                            default:
                              return const SizedBox();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              const Divider(height: 1),
              _buildBottomFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  static const Color _primaryBlue = Color(0xFF1A56DB);

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.08),
              border: Border.all(color: _primaryBlue),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.employee == null ? 'Nouveau' : 'Modifier',
              style: const TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.employee != null
                ? 'Employés / ${widget.employee!.fullName}'
                : 'Employés / Nouveau',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const Spacer(),
          // Stat Badges (Contrats, Organigramme, Feuilles de paye, Congé 20/20 Jours, Prêts)
          BlocBuilder<ContractsBloc, ContractsState>(
            builder: (context, cState) {
              final contracts = cState is ContractsLoaded
                  ? cState.contracts
                      .where((c) =>
                          c.employeeId.isNotEmpty &&
                          c.employeeId == widget.employee?.id)
                      .toList()
                  : <EmployeeContract>[];
              final count = contracts.length;
              final contractLabel = contracts.isNotEmpty
                  ? 'Sous contrat depuis le ${DateFormat('dd/MM/yyyy').format(contracts.first.startDate)}'
                  : 'Contrats';
              return _buildStatBadge(
                Icons.menu_book_rounded,
                contractLabel,
                contracts.isNotEmpty ? '' : '$count',
                onTap: () {
                  final emp = widget.employee;
                  if (contracts.isNotEmpty) {
                    ContractFormDialog.show(context,
                        employee: emp, contract: contracts.first);
                  } else {
                    ContractFormDialog.show(context, employee: emp);
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
          _buildStatBadge(
            Icons.account_tree_outlined,
            'Organigramme',
            '',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          BlocBuilder<PayrollBloc, PayrollState>(
            builder: (context, pState) {
              final payslips = pState is PayrollLoaded
                  ? pState.payslips
                      .where((p) =>
                          p.employeeId.isNotEmpty &&
                          p.employeeId == widget.employee?.id)
                      .toList()
                  : <Payslip>[];
              final count = payslips.length;
              return _buildStatBadge(
                Icons.payments_outlined,
                'Feuilles de paye',
                '$count',
                onTap: () {
                  final emp = widget.employee;
                  if (payslips.isNotEmpty) {
                    _showEmployeePayslipsModal(context, payslips);
                  } else {
                    PayslipFormDialog.show(context, employee: emp);
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
          BlocBuilder<LeavesBloc, LeavesState>(
            builder: (context, lState) {
              final leaves = lState is LeavesLoaded
                  ? lState.leaves
                      .where((l) =>
                          l.employeeId.isNotEmpty &&
                          l.employeeId == widget.employee?.id)
                      .toList()
                  : <LeaveRequest>[];

              double allocated = 0;
              for (final l in leaves) {
                if (l.isApproved) {
                  allocated += l.daysCount;
                }
              }
              final displayDays = allocated > 0
                  ? allocated.toStringAsFixed(allocated.truncateToDouble() == allocated ? 0 : 1)
                  : '20';

              return _buildStatBadge(
                Icons.calendar_month_outlined,
                'Congé',
                '$displayDays/$displayDays Jours',
                onTap: () {
                  final emp = widget.employee;
                  if (leaves.isNotEmpty) {
                    LeaveAllocationDialog.show(context, leave: leaves.first, employee: emp);
                  } else {
                    LeaveAllocationDialog.show(context, employee: emp);
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
          BlocBuilder<LoansBloc, LoansState>(
            builder: (context, lState) {
              final loans = lState is LoansLoaded
                  ? lState.loans
                      .where((l) =>
                          l.employeeId.isNotEmpty &&
                          l.employeeId == widget.employee?.id)
                      .toList()
                  : <EmployeeLoan>[];
              final count = loans.length;
              return _buildStatBadge(
                Icons.account_balance_wallet_outlined,
                'Prêts',
                '$count',
                onTap: () {
                  final emp = widget.employee;
                  if (loans.isNotEmpty) {
                    _showEmployeeLoansModal(context, loans);
                  } else {
                    EmployeeLoanDialog.show(context, employee: emp);
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
          BlocBuilder<AttendanceBloc, AttendanceState>(
            builder: (context, aState) {
              final attendances = aState is AttendanceLoaded
                  ? aState.attendances
                      .where((a) =>
                          a.employeeId.isNotEmpty &&
                          a.employeeId == widget.employee?.id)
                      .toList()
                  : <Attendance>[];
              final count = attendances.length;
              double totalHours = 0;
              for (final a in attendances) {
                totalHours += a.workedHours;
              }
              final display = totalHours > 0 ? Attendance.formatDuration(totalHours) : '$count';
              return _buildStatBadge(
                Icons.access_time_rounded,
                'Présences',
                display,
                onTap: () {
                  final emp = widget.employee;
                  if (attendances.isNotEmpty) {
                    _showEmployeeAttendancesModal(context, attendances);
                  } else if (emp != null) {
                    AttendanceFormDialog.show(
                      context,
                      attendance: Attendance(
                        id: const Uuid().v4(),
                        employeeId: emp.id,
                        employeeName: emp.fullName,
                        employeeAvatar: emp.photoUrl,
                        checkIn: DateTime.now(),
                      ),
                    );
                  }
                },
              );
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _primaryBlue),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Identity Row: Photo on right, Inputs on left
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prénom & Nom row with clear labels and sleek input styling
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Prénom *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _fnCtrl,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: _headerInputDecoration('Ex: Mohamed'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nom *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _lnCtrl,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: _headerInputDecoration('Ex: Ben Ali'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Poste / Fonction
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Poste / Fonction *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _jobCtrl,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                          decoration: _headerInputDecoration(
                            'Ex: Responsable Commercial, Développeur Senior...',
                            icon: Icons.work_outline_rounded,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Étiquettes
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Étiquettes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _tagsCtrl,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: _headerInputDecoration(
                            'Ex: Cadre, Commercial, Temps plein (séparées par une virgule)',
                            icon: Icons.label_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Photo Avatar Box
              _buildAvatarBox(),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 18),

          // Two-column Pro Contact
          if (isMobile) ...[
            _inputLine('Téléphone portable professionnel', _workMobileCtrl, icon: Icons.phone_android_rounded),
            const SizedBox(height: 8),
            _inputLine('Téléphone professionnel', _workPhoneCtrl, icon: Icons.phone_rounded),
            const SizedBox(height: 8),
            _inputLine('Adresse email professionnelle', _workEmailCtrl, icon: Icons.email_outlined),
            const SizedBox(height: 8),
            _dropdownLine('Département', _department, _departments, (v) => setState(() => _department = v!)),
            const SizedBox(height: 8),
            _inputLine('Manager / Responsable', _managerCtrl, icon: Icons.person_outline_rounded),
            const SizedBox(height: 8),
            _inputLine('Mentor', _mentorCtrl, icon: Icons.school_outlined),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _inputLine('Téléphone portable pro', _workMobileCtrl, icon: Icons.phone_android_rounded),
                      const SizedBox(height: 10),
                      _inputLine('Téléphone professionnel', _workPhoneCtrl, icon: Icons.phone_rounded),
                      const SizedBox(height: 10),
                      _inputLine('Adresse email pro', _workEmailCtrl, icon: Icons.email_outlined),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _dropdownLine('Département', _department, _departments, (v) => setState(() => _department = v!)),
                      const SizedBox(height: 10),
                      _inputLine('Manager / Responsable', _managerCtrl, icon: Icons.person_outline_rounded),
                      const SizedBox(height: 10),
                      _inputLine('Mentor', _mentorCtrl, icon: Icons.school_outlined),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarBox() {
    final initials = '${_fnCtrl.text.isNotEmpty ? _fnCtrl.text[0].toUpperCase() : ''}${_lnCtrl.text.isNotEmpty ? _lnCtrl.text[0].toUpperCase() : ''}';

    return Container(
      width: 100,
      height: 106,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _primaryBlue.withValues(alpha: 0.1),
            child: initials.isNotEmpty
                ? Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  )
                : const Icon(
                    Icons.add_a_photo_outlined,
                    size: 24,
                    color: _primaryBlue,
                  ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Photo',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _headerInputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
      prefixIcon: icon != null ? Icon(icon, size: 17, color: _primaryBlue) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: _primaryBlue,
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: _primaryBlue,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'Informations professionnelles'),
          Tab(text: 'Informations privées'),
          Tab(text: 'Citoyenneté & Identification'),
          Tab(text: 'Urgence & Éducation'),
        ],
      ),
    );
  }

  // TAB 1: INFORMATIONS PROFESSIONNELLES
  Widget _buildTabProfessional(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('CONTRAT & RÉMUNÉRATION'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: _primaryBlue, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contrat officiel & Conditions d\'emploi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Structure salariale, compte bancaire, heures, taux & conventions',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final emp = widget.employee;
                  ContractFormDialog.show(context, employee: emp);
                },
                icon: const Icon(Icons.edit_document, size: 14, color: Colors.white),
                label: const Text(
                  'Gérer Contrat',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final emp = widget.employee;
                  PayslipFormDialog.show(context, employee: emp);
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white),
                label: const Text(
                  'Feuille de paye',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _dropdownLine('Type de contrat', _contractType, _contracts, (v) => setState(() => _contractType = v!)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _inputLine('Salaire de base (TND) *', _salaryCtrl, isNumber: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _datePickerLine('Date d\'embauche', _hireDate, (d) => setState(() => _hireDate = d)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _dropdownLine(
                'Mode de paiement',
                _paymentMethod,
                ['Virement bancaire', 'Chèque', 'Espèces'],
                (v) => setState(() => _paymentMethod = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _inputLine('Numéro de compte bancaire / RIB (20 chiffres)', _ribCtrl, icon: Icons.account_balance_outlined),
        const SizedBox(height: 16),
        _sectionTitle('NOTES & COMMENTAIRES INTERNES'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: _inputDecoration('Notes RH, observations sur l\'employé...'),
        ),
      ],
    );
  }

  // TAB 2: INFORMATIONS PRIVÉES & SITUATION FAMILIALE (Matches Image 2, 3, 4)
  Widget _buildTabPrivateAndFamily(bool isMobile) {
    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrivateCoordinates(),
              const SizedBox(height: 24),
              _buildFamilySituation(),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPrivateCoordinates()),
              const SizedBox(width: 24),
              Expanded(child: _buildFamilySituation()),
            ],
          );
  }

  Widget _buildPrivateCoordinates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('COORDONNÉES PRIVÉES'),
        const SizedBox(height: 12),
        _inputLine('Adresse personnelle (Rue)', _privStreetCtrl, icon: Icons.home_outlined),
        const SizedBox(height: 8),
        _inputLine('Adresse (Rue 2)', _privStreet2Ctrl),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _inputLine('Ville', _privCityCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _inputLine('Gouvernorat / Statut', _privStateCtrl)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _inputLine('Code postal', _privZipCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _inputLine('Pays', _privCountryCtrl)),
          ],
        ),
        const SizedBox(height: 12),
        _inputLine('Email personnel', _privEmailCtrl, icon: Icons.alternate_email_rounded),
        const SizedBox(height: 8),
        _inputLine('Téléphone personnel', _privPhoneCtrl, icon: Icons.phone_iphone_rounded),
        const SizedBox(height: 8),
        _inputLine('Langue préférée', _languageCtrl),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _inputLine('Distance Domicile-Travail (Km)', _distanceKmCtrl, isNumber: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _inputLine('Plaque d\'immatriculation', _carPlateCtrl, icon: Icons.directions_car_outlined),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFamilySituation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('SITUATION FAMILIALE'),
        const SizedBox(height: 12),
        _dropdownLine(
          'État civil',
          _maritalStatus,
          _maritalStatuses,
          (v) => setState(() => _maritalStatus = v!),
        ),
        const SizedBox(height: 8),
        // Checkbox: Chef de Famille
        Row(
          children: [
            Checkbox(
              value: _isHeadOfFamily,
              activeColor: _primaryBlue,
              onChanged: (v) => setState(() => _isHeadOfFamily = v ?? false),
            ),
            const Text(
              'Chef de Famille',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _inputLine('Profession des parents / conjoint', _spouseJobCtrl),
        const SizedBox(height: 8),
        _inputLine('Nom complet du conjoint', _spouseNameCtrl),
        const SizedBox(height: 8),
        _datePickerLine(
          'Date de naissance du conjoint',
          _spouseBirthDate,
          (d) => setState(() => _spouseBirthDate = d),
        ),
        const SizedBox(height: 12),
        // Dependent Children Count Indicator
        Row(
          children: [
            const Text(
              'Nombre d\'Enfants en Charge',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_dependentCount',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryBlue, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Interactive Children Table (Image 2, 3, 4)
        const Text(
          'Enfants',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        _buildChildrenTable(),
      ],
    );
  }

  Widget _buildChildrenTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Nom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Date de naiss.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Center(child: Text('En charge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                Expanded(flex: 2, child: Center(child: Text('Handicapé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                Expanded(flex: 2, child: Center(child: Text('Étudiant', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                SizedBox(width: 28),
              ],
            ),
          ),
          // Children rows
          if (_children.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text('Aucun enfant enregistré', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ..._children.asMap().entries.map((entry) {
              final idx = entry.key;
              final child = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(child.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(_formatDate(child.birthDate), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Checkbox(
                          value: child.isDependent,
                          activeColor: _primaryBlue,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) {
                            setState(() {
                              _children[idx] = child.copyWith(isDependent: v ?? false);
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Checkbox(
                          value: child.isDisabled,
                          activeColor: _primaryBlue,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) {
                            setState(() {
                              _children[idx] = child.copyWith(isDisabled: v ?? false);
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Checkbox(
                          value: child.isStudent,
                          activeColor: _primaryBlue,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) {
                            setState(() {
                              _children[idx] = child.copyWith(isStudent: v ?? false);
                            });
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() => _children.removeAt(idx));
                      },
                    ),
                  ],
                ),
              );
            }),
          // Add Line Button (Image 2 & 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter une ligne', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddChildDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  // POPUP "CRÉER ENFANTS" (Matches Image 3)
  void _showAddChildDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    DateTime birthDate = DateTime.now();
    bool isDep = true;
    bool isDis = false;
    bool isStud = false;
    bool hasSchol = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setChildState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Créer Enfants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _inputLine('Nom de l\'enfant *', nameCtrl),
                  const SizedBox(height: 12),
                  _datePickerLine('Date de Naissance', birthDate, (d) => setChildState(() => birthDate = d)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('En charge', style: TextStyle(fontSize: 12.5)),
                          value: isDep,
                          activeColor: _primaryBlue,
                          onChanged: (v) => setChildState(() => isDep = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Estropié / Handicap', style: TextStyle(fontSize: 12.5)),
                          value: isDis,
                          activeColor: _primaryBlue,
                          onChanged: (v) => setChildState(() => isDis = v ?? false),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Étudiant', style: TextStyle(fontSize: 12.5)),
                          value: isStud,
                          activeColor: _primaryBlue,
                          onChanged: (v) => setChildState(() => isStud = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Bourse', style: TextStyle(fontSize: 12.5)),
                          value: hasSchol,
                          activeColor: _primaryBlue,
                          onChanged: (v) => setChildState(() => hasSchol = v ?? false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ignorer / Annuler', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _children.add(
                    EmployeeChild(
                      id: const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      birthDate: birthDate,
                      isDependent: isDep,
                      isDisabled: isDis,
                      isStudent: isStud,
                      hasScholarship: hasSchol,
                    ),
                  );
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Enregistrer & Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 3: CITOYENNETÉ & IDENTIFICATION (Matches Image 5)
  Widget _buildTabCitizenship(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('CITOYENNETÉ'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputLine('Nationalité (pays)', _nationalityCtrl)),
            const SizedBox(width: 16),
            Expanded(child: _inputLine('CIN (Carte d\'Identité)', _cinCtrl, icon: Icons.badge_outlined)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputLine('Numéro CNSS', _cnssCtrl, icon: Icons.numbers_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _inputLine('Numéro chez l\'employeur (Matricule)', _employerCodeCtrl)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputLine('Numéro de sécurité sociale', _socialSecCtrl)),
            const SizedBox(width: 16),
            Expanded(child: _inputLine('N° de passeport', _passportCtrl)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _dropdownLine('Genre', _gender, ['Homme', 'Femme', 'Autre'], (v) => setState(() => _gender = v!)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _datePickerLine('Date de naissance', _birthDate, (d) => setState(() => _birthDate = d)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputLine('Lieu de naissance', _birthPlaceCtrl)),
            const SizedBox(width: 16),
            Expanded(child: _inputLine('Pays de naissance', _birthCountryCtrl)),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('VISA & PERMIS DE TRAVAIL'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputLine('Type de visa', _visaTypeCtrl)),
            const SizedBox(width: 16),
            Expanded(
              child: _datePickerLine(
                'Date d\'expiration du permis',
                _workPermitExpiration,
                (d) => setState(() => _workPermitExpiration = d),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputLine('Permis de travail (Numéro/Réf)', _workPermitNumberCtrl)),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                icon: const Icon(Icons.attach_file_rounded, size: 18, color: _primaryBlue),
                label: const Text('Charger votre fichier', style: TextStyle(color: Color(0xFF334155), fontSize: 12.5)),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await FilePicker.platform.pickFiles();
                  if (result != null && result.files.isNotEmpty) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Fichier sélectionné : ${result.files.first.name}')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // TAB 4: URGENCE & ÉDUCATION
  Widget _buildTabEmergencyAndEducation(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('CONTACT D\'URGENCE'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputLine('Nom du contact d\'urgence', _emergNameCtrl, icon: Icons.contact_emergency_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _inputLine('Téléphone d\'urgence', _emergPhoneCtrl, icon: Icons.phone_outlined)),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle('ÉDUCATION & QUALIFICATIONS'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _inputLine('Niveau d\'études (ex: Master, Licence, Ingénieur)', _educationCtrl, icon: Icons.school_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _inputLine('Spécialité / Filière', _fieldOfStudyCtrl)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ignorer / Annuler', style: TextStyle(color: Color(0xFF475569))),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.check, size: 18),
            label: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enregistrer'),
            onPressed: _isSaving ? null : _saveEmployee,
          ),
        ],
      ),
    );
  }

  void _saveEmployee() async {
    if (_formKey.currentState?.validate() != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner les champs obligatoires (Prénom, Nom, Poste).')),
      );
      return;
    }

    final emp = widget.employee;
    if (emp != null) {
      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!isOnline) return;
    }

    setState(() => _isSaving = true);
    final isOnline = ConnectivityService.instance.isOnline;

    final s = double.tryParse(_salaryCtrl.text.trim()) ?? 0.0;
    final dist = double.tryParse(_distanceKmCtrl.text.trim());
    final tagsList = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (emp != null) {
      final updated = emp.copyWith(
        firstName: _fnCtrl.text.trim(),
        lastName: _lnCtrl.text.trim(),
        jobTitle: _jobCtrl.text.trim(),
        department: _department,
        tags: tagsList,
        workMobile: _workMobileCtrl.text.trim(),
        workPhone: _workPhoneCtrl.text.trim(),
        workEmail: _workEmailCtrl.text.trim(),
        manager: _managerCtrl.text.trim(),
        mentor: _mentorCtrl.text.trim(),
        contractType: _contractType,
        baseSalary: s,
        hireDate: _hireDate,
        paymentMethod: _paymentMethod,
        rib: _ribCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        address: _privStreetCtrl.text.trim(),
        privateAddressStreet2: _privStreet2Ctrl.text.trim(),
        city: _privCityCtrl.text.trim(),
        privateAddressState: _privStateCtrl.text.trim(),
        privateAddressZip: _privZipCtrl.text.trim(),
        privateAddressCountry: _privCountryCtrl.text.trim(),
        personalEmail: _privEmailCtrl.text.trim(),
        personalPhone: _privPhoneCtrl.text.trim(),
        preferredLanguage: _languageCtrl.text.trim(),
        homeWorkDistanceKm: dist,
        carPlate: _carPlateCtrl.text.trim(),
        maritalStatus: _maritalStatus,
        isHeadOfFamily: _isHeadOfFamily,
        spouseName: _spouseNameCtrl.text.trim(),
        spouseBirthDate: _spouseBirthDate,
        spouseJob: _spouseJobCtrl.text.trim(),
        children: _children,
        childrenCount: _children.length,
        nationality: _nationalityCtrl.text.trim(),
        cin: _cinCtrl.text.trim(),
        cnssNumber: _cnssCtrl.text.trim(),
        employerCode: _employerCodeCtrl.text.trim(),
        socialSecurityNumber: _socialSecCtrl.text.trim(),
        passportNumber: _passportCtrl.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        birthPlace: _birthPlaceCtrl.text.trim(),
        birthCountry: _birthCountryCtrl.text.trim(),
        visaType: _visaTypeCtrl.text.trim(),
        workPermitExpiration: _workPermitExpiration,
        workPermitNumber: _workPermitNumberCtrl.text.trim(),
        emergencyContactName: _emergNameCtrl.text.trim(),
        emergencyContactPhone: _emergPhoneCtrl.text.trim(),
        educationLevel: _educationCtrl.text.trim(),
        fieldOfStudy: _fieldOfStudyCtrl.text.trim(),
        updatedAt: DateTime.now(),
      );
      context.read<EmployeesBloc>().add(UpdateEmployee(updated));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employé "${updated.firstName} ${updated.lastName}" mis à jour avec succès !'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final code = _employerCodeCtrl.text.trim().isNotEmpty
          ? _employerCodeCtrl.text.trim()
          : 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final newEmp = Employee(
        id: const Uuid().v4(),
        code: code,
        firstName: _fnCtrl.text.trim(),
        lastName: _lnCtrl.text.trim(),
        jobTitle: _jobCtrl.text.trim(),
        department: _department,
        tags: tagsList,
        workMobile: _workMobileCtrl.text.trim(),
        workPhone: _workPhoneCtrl.text.trim(),
        workEmail: _workEmailCtrl.text.trim(),
        manager: _managerCtrl.text.trim(),
        mentor: _mentorCtrl.text.trim(),
        contractType: _contractType,
        baseSalary: s,
        hireDate: _hireDate,
        paymentMethod: _paymentMethod,
        rib: _ribCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        address: _privStreetCtrl.text.trim(),
        privateAddressStreet2: _privStreet2Ctrl.text.trim(),
        city: _privCityCtrl.text.trim(),
        privateAddressState: _privStateCtrl.text.trim(),
        privateAddressZip: _privZipCtrl.text.trim(),
        privateAddressCountry: _privCountryCtrl.text.trim(),
        personalEmail: _privEmailCtrl.text.trim(),
        personalPhone: _privPhoneCtrl.text.trim(),
        preferredLanguage: _languageCtrl.text.trim(),
        homeWorkDistanceKm: dist,
        carPlate: _carPlateCtrl.text.trim(),
        maritalStatus: _maritalStatus,
        isHeadOfFamily: _isHeadOfFamily,
        spouseName: _spouseNameCtrl.text.trim(),
        spouseBirthDate: _spouseBirthDate,
        spouseJob: _spouseJobCtrl.text.trim(),
        children: _children,
        childrenCount: _children.length,
        nationality: _nationalityCtrl.text.trim(),
        cin: _cinCtrl.text.trim(),
        cnssNumber: _cnssCtrl.text.trim(),
        employerCode: code,
        socialSecurityNumber: _socialSecCtrl.text.trim(),
        passportNumber: _passportCtrl.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        birthPlace: _birthPlaceCtrl.text.trim(),
        birthCountry: _birthCountryCtrl.text.trim(),
        visaType: _visaTypeCtrl.text.trim(),
        workPermitExpiration: _workPermitExpiration,
        workPermitNumber: _workPermitNumberCtrl.text.trim(),
        emergencyContactName: _emergNameCtrl.text.trim(),
        emergencyContactPhone: _emergPhoneCtrl.text.trim(),
        educationLevel: _educationCtrl.text.trim(),
        fieldOfStudy: _fieldOfStudyCtrl.text.trim(),
        enterpriseId: EnterpriseService.instance.currentEnterpriseId,
      );
      context.read<EmployeesBloc>().add(AddEmployee(newEmp));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isOnline ? Icons.check_circle_rounded : Icons.cloud_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Employé "${newEmp.firstName} ${newEmp.lastName}" enregistré avec succès !'
                      : 'Employé "${newEmp.firstName} ${newEmp.lastName}" enregistré (hors ligne - en attente de synchronisation)',
                ),
              ),
            ],
          ),
          backgroundColor: isOnline ? AppColors.success : AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Helpers
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _inputLine(String label, TextEditingController ctrl,
      {IconData? icon, bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDecoration(label, icon: icon),
    );
  }

  Widget _dropdownLine(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: _inputDecoration(label),
      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _datePickerLine(String label, DateTime? date, ValueChanged<DateTime> onSelected) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(1940),
          lastDate: DateTime(2040),
        );
        if (picked != null) onSelected(picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration(label, icon: Icons.calendar_today_outlined),
        child: Text(
          _formatDate(date),
          style: TextStyle(
            fontSize: 13,
            color: date != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      prefixIcon: icon != null ? Icon(icon, size: 16, color: const Color(0xFF94A3B8)) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
    );
  }

  void _showEmployeePayslipsModal(BuildContext context, List<Payslip> payslips) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: _primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bulletins de paie - ${widget.employee?.fullName ?? ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${payslips.length} bulletin(s) enregistré(s)',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      PayslipFormDialog.show(context, employee: widget.employee);
                    },
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Nouveau bulletin', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: payslips.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (c, idx) {
                    final p = payslips[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(Icons.receipt_rounded, size: 16, color: _primaryBlue),
                      ),
                      title: Text(
                        p.reference.isNotEmpty ? p.reference : 'SLIP - ${p.periodLabel}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${p.periodLabel}  •  Net: ${p.netSalary.toStringAsFixed(3)} DT',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.paymentStatus == 'paid'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              p.paymentStatus == 'paid' ? 'Payé' : 'Brouillon',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: p.paymentStatus == 'paid' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.open_in_new, size: 16, color: _primaryBlue),
                            onPressed: () {
                              Navigator.pop(ctx);
                              PayslipFormDialog.show(context, employee: widget.employee, payslip: p);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmployeeLoansModal(BuildContext context, List<EmployeeLoan> loans) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: _primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Prêts accordés - ${widget.employee?.fullName ?? ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${loans.length} prêt(s) enregistré(s)',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      EmployeeLoanDialog.show(context, employee: widget.employee);
                    },
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Nouveau prêt', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: loans.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (c, idx) {
                    final loan = loans[idx];
                    final isPaid = loan.status == 'paid';
                    final isConfirmed = loan.status == 'confirmed';

                    Color statusColor = Colors.orange;
                    if (isPaid) statusColor = Colors.green;
                    if (isConfirmed) statusColor = _primaryBlue;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: _primaryBlue),
                      ),
                      title: Text(
                        loan.name.isNotEmpty ? loan.name : loan.reference,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Total: ${loan.amount.toStringAsFixed(2)} DT  •  Reste: ${loan.remainingAmount.toStringAsFixed(2)} DT  •  ${loan.monthsCount} mois',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              loan.statusDisplay,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.open_in_new, size: 16, color: _primaryBlue),
                            onPressed: () {
                              Navigator.pop(ctx);
                              EmployeeLoanDialog.show(context, employee: widget.employee, loan: loan);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmployeeAttendancesModal(BuildContext context, List<Attendance> attendances) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: Color(0xFF1A56DB), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Pointages de ${widget.employee?.fullName ?? "l'employé"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Nouveau pointage', style: TextStyle(fontSize: 11.5)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final emp = widget.employee;
                          AttendanceFormDialog.show(
                            context,
                            attendance: emp != null
                                ? Attendance(
                                    id: const Uuid().v4(),
                                    employeeId: emp.id,
                                    employeeName: emp.fullName,
                                    employeeAvatar: emp.photoUrl,
                                    checkIn: DateTime.now(),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: attendances.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (c, idx) {
                    final att = attendances[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                        child: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF1A56DB)),
                      ),
                      title: Text(
                        'Arrivée: ${att.formattedCheckIn}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      subtitle: Text(
                        'Départ: ${att.checkOut != null ? att.formattedCheckOut : "En cours"}  •  Durée: ${att.formattedWorkedHours}${att.overtimeHours > 0 ? " (+${att.formattedOvertimeHours} sup)" : ""}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1A56DB)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          AttendanceFormDialog.show(context, attendance: att);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
