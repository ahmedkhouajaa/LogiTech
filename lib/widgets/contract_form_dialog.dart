import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../blocs/contracts/contracts_bloc.dart';
import '../blocs/contracts/contracts_event.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../models/employee.dart';
import '../models/employee_contract.dart';
import 'salary_structure_dialog.dart';

class ContractFormDialog extends StatefulWidget {
  final Employee? employee;
  final EmployeeContract? contract;

  const ContractFormDialog({
    super.key,
    this.employee,
    this.contract,
  });

  static Future<void> show(
    BuildContext context, {
    Employee? employee,
    EmployeeContract? contract,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ContractFormDialog(
        employee: employee,
        contract: contract,
      ),
    );
  }

  @override
  State<ContractFormDialog> createState() => _ContractFormDialogState();
}

class _ContractFormDialogState extends State<ContractFormDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Styling
  static const Color _primaryBlue = Color(0xFF1A56DB);
  static const Color _surfaceLight = Color(0xFFF8FAFC);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _labelColor = Color(0xFF475569);

  // General fields
  late TextEditingController _refCtrl;
  Employee? _selectedEmployee;
  DateTime _hiringDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String _workingHoursType = 'Mensuel';
  String _workingHoursStandard = 'Standard 40 h';
  late TextEditingController _overtimeHourlyRateCtrl;
  late TextEditingController _dailyRateCtrl;

  // Right column fields
  String _salaryStructureType = 'Employee';
  late TextEditingController _deptCtrl;
  late TextEditingController _jobTitleCtrl;
  String _contractType = 'CDI';
  String _paymentMethod = 'Virement';

  // Bank fields
  String _bankAccountNumber = '';
  String _bankName = '';
  String _bankAccountHolder = '';
  String _bankCurrency = 'TND';
  bool _sendMoney = false;

  // Accounting fields
  late TextEditingController _analyticAccountCtrl;
  late TextEditingController _salaryJournalCtrl;

  // Tab 1: Informations sur le salaire
  late TextEditingController _wageCtrl;
  late TextEditingController _monthsCtrl;
  late TextEditingController _wageStructureCtrl;
  late TextEditingController _wageScaleCategoryCtrl;
  late TextEditingController _salaryScaleCtrl;
  late TextEditingController _hierarchicalLevelCtrl;
  DateTime? _affectationDate;
  final List<String> _salaryStructures = const [
    'Contrat de travail à durée indéterminée',
    'Contrat de travail à durée déterminée',
    'Stage d\'initiation à la vie professionnelle (SIVP)',
    'Contrat de travail temporaire / Freelance',
    'Cadre & Direction',
  ];

  // Tab 2: Détails du contrat
  late TextEditingController _trialPeriodMonthsCtrl;
  late TextEditingController _notesCtrl;
  String _status = 'active';

  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final c = widget.contract;
    final emp = widget.employee;

    _selectedEmployee = emp;

    final initialRef = c?.reference ??
        'CTR/${DateTime.now().year}/${(1000 + DateTime.now().millisecond).toString()}';
    _refCtrl = TextEditingController(text: initialRef);

    if (c != null) {
      _hiringDate = c.hiringDate;
      _startDate = c.startDate;
      _endDate = c.endDate;
      _workingHoursType = c.workingHoursType;
      _workingHoursStandard = c.workingHoursStandard;
      _overtimeHourlyRateCtrl = TextEditingController(
          text: c.overtimeHourlyRate.toStringAsFixed(2).replaceAll('.', ','));
      _dailyRateCtrl = TextEditingController(
          text: c.dailyRate.toStringAsFixed(2).replaceAll('.', ','));
      _salaryStructureType = c.salaryStructureType;
      _deptCtrl = TextEditingController(text: c.department);
      _jobTitleCtrl = TextEditingController(text: c.jobTitle);
      _contractType = c.contractType;
      _paymentMethod = c.paymentMethod;
      _bankAccountNumber = c.bankAccountNumber ?? '';
      _bankName = c.bankName ?? '';
      _bankAccountHolder = c.bankAccountHolder ?? c.employeeName;
      _analyticAccountCtrl = TextEditingController(text: c.analyticAccount ?? '');
      _salaryJournalCtrl = TextEditingController(text: c.salaryJournal ?? '');
      _wageCtrl = TextEditingController(
          text: c.wage > 0
              ? c.wage.toStringAsFixed(3).replaceAll('.', ',')
              : '1250,000');
      _monthsCtrl = TextEditingController(
          text: c.wageMonths.toStringAsFixed(2).replaceAll('.', ','));
      _wageStructureCtrl = TextEditingController(text: c.wageStructure);
      _wageScaleCategoryCtrl =
          TextEditingController(text: c.wageScaleCategory ?? 'Grille salariale');
      _salaryScaleCtrl = TextEditingController(text: c.salaryScale ?? '0');
      _hierarchicalLevelCtrl =
          TextEditingController(text: c.hierarchicalLevel ?? '0');
      _affectationDate = c.affectationDate;
      _trialPeriodMonthsCtrl =
          TextEditingController(text: c.trialPeriodMonths.toString());
      _notesCtrl = TextEditingController(text: c.notes ?? '');
      _status = c.status;
    } else {
      _hiringDate = emp?.hireDate ?? DateTime.now();
      _startDate = DateTime.now();
      _endDate = null;
      _workingHoursType = 'Mensuel';
      _workingHoursStandard = 'Standard 40 h';
      _overtimeHourlyRateCtrl = TextEditingController(text: '0,00');
      _dailyRateCtrl = TextEditingController(text: '0,00');
      _salaryStructureType = 'Employee';
      _deptCtrl = TextEditingController(text: emp?.department ?? 'IT');
      _jobTitleCtrl = TextEditingController(text: emp?.jobTitle ?? 'developer');
      _contractType = emp?.contractType ?? 'CDI';
      _paymentMethod = 'Virement';
      _bankAccountNumber = emp?.rib ?? '';
      _bankName = '';
      _bankAccountHolder = emp?.fullName ?? '';
      _analyticAccountCtrl = TextEditingController();
      _salaryJournalCtrl = TextEditingController();
      final baseSalary = emp?.baseSalary ?? 1250.0;
      _wageCtrl = TextEditingController(
          text: baseSalary.toStringAsFixed(3).replaceAll('.', ','));
      _monthsCtrl = TextEditingController(text: '13,50');
      _wageStructureCtrl = TextEditingController(
          text: 'Contrat de travail à durée indéterminée');
      _wageScaleCategoryCtrl = TextEditingController(text: 'Grille salariale');
      _salaryScaleCtrl = TextEditingController(text: '0');
      _hierarchicalLevelCtrl = TextEditingController(text: '0');
      _affectationDate = null;
      _trialPeriodMonthsCtrl = TextEditingController(text: '3');
      _notesCtrl = TextEditingController();
      _status = 'active';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refCtrl.dispose();
    _overtimeHourlyRateCtrl.dispose();
    _dailyRateCtrl.dispose();
    _deptCtrl.dispose();
    _jobTitleCtrl.dispose();
    _analyticAccountCtrl.dispose();
    _salaryJournalCtrl.dispose();
    _wageCtrl.dispose();
    _monthsCtrl.dispose();
    _wageStructureCtrl.dispose();
    _wageScaleCategoryCtrl.dispose();
    _salaryScaleCtrl.dispose();
    _hierarchicalLevelCtrl.dispose();
    _trialPeriodMonthsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _parseFrenchDouble(String val, [double def = 0.0]) {
    final clean = val.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? def;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 800;
    final dialogWidth = isMobile ? media.size.width * 0.96 : 960.0;
    final dialogHeight = isMobile ? media.size.height * 0.95 : 820.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ERP Top App Bar / Actions Header
              _buildTopBar(isMobile),
              const Divider(height: 1, color: _borderLight),

              // Main Form Content Scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 14 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large Contract Reference Field (Clean ERP style without background tint)
                      _buildReferenceField(),
                      const SizedBox(height: 24),

                      // Two-Column Grid for main contract fields (Image 1 & 2)
                      if (isMobile) ...[
                        _buildLeftColumn(isMobile),
                        const SizedBox(height: 20),
                        _buildRightColumn(isMobile),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildLeftColumn(isMobile)),
                            const SizedBox(width: 32),
                            Expanded(child: _buildRightColumn(isMobile)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ACCOUNTING Section (Image 1 & 2)
                      _buildAccountingSection(isMobile),

                      const SizedBox(height: 24),

                      // Bottom Tabs: Informations sur le salaire / Détails du contrat (Image 2 & 5)
                      _buildTabsBar(),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: isMobile ? 380 : 310,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildSalaryTab(isMobile),
                            _buildContractDetailsTab(isMobile),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, color: _borderLight),
              // Bottom Action Bar
              _buildBottomBar(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // TOP BAR (Breadcrumbs, Save, Cloud, Undo)
  // -------------------------------------------------------------------------
  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // "Nouveau" Button (Odoo-like ERP)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _primaryBlue.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(6),
              color: _primaryBlue.withValues(alpha: 0.08),
            ),
            child: const Text(
              'Nouveau',
              style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Breadcrumb: Contrats / Nouveau (or Reference)
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Contrats / ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Flexible(
                  child: Text(
                    _refCtrl.text.isNotEmpty ? _refCtrl.text : 'Nouveau',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Action Icons (Cloud sync, Undo, Settings)
          IconButton(
            icon: const Icon(Icons.cloud_done_outlined,
                size: 20, color: Color(0xFF64748B)),
            tooltip: 'Sauvegarde Cloud synchronisée',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.undo_rounded,
                size: 20, color: Color(0xFF64748B)),
            tooltip: 'Réinitialiser',
            onPressed: () {
              setState(() {
                _overtimeHourlyRateCtrl.text = '0,00';
                _dailyRateCtrl.text = '0,00';
              });
            },
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CONTRACT REFERENCE (Hero Title Input - Clean ERP without shaded box)
  // -------------------------------------------------------------------------
  Widget _buildReferenceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              filled: false,
              fillColor: Colors.transparent,
            ),
          ),
          child: TextFormField(
            controller: _refCtrl,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            decoration: const InputDecoration(
              hintText: 'Référence du contrat',
              hintStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Color(0xFF94A3B8),
              ),
              filled: false,
              fillColor: Colors.transparent,
              hoverColor: Colors.transparent,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _primaryBlue, width: 2.0),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Référence requise' : null,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // LEFT COLUMN: Employé, Hiring Date, Dates, Heures de travail, Taux
  // -------------------------------------------------------------------------
  Widget _buildLeftColumn(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Employé Selector / Badge (Image 1 & 2)
        _buildEmployeeSelector(),
        const SizedBox(height: 16),

        // Hiring Date
        _buildDatePickerField(
          label: 'Hiring Date',
          value: _hiringDate,
          onSelect: (dt) => setState(() => _hiringDate = dt),
        ),
        const SizedBox(height: 14),

        // Date de début du contrat
        _buildDatePickerField(
          label: 'Date de début du contrat',
          value: _startDate,
          onSelect: (dt) => setState(() => _startDate = dt),
        ),
        const SizedBox(height: 14),

        // Date de fin du contrat ? (optional)
        _buildDatePickerField(
          label: 'Date de fin du contrat ?',
          value: _endDate,
          isOptional: true,
          onSelect: (dt) => setState(() => _endDate = dt),
          onClear: () => setState(() => _endDate = null),
        ),
        const SizedBox(height: 14),

        // Heures de travail ? (Row: Mensuel dropdown + Standard 40 h dropdown)
        _buildWorkingHoursRow(),
        const SizedBox(height: 14),

        // Taux Horaire des Heures Supplémentaires
        _buildLabelledInput(
          label: 'Taux Horaire des Heures Supplémentaires',
          controller: _overtimeHourlyRateCtrl,
          suffix: 'DT',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 14),

        // Taux par Jour
        _buildLabelledInput(
          label: 'Taux par Jour',
          controller: _dailyRateCtrl,
          suffix: 'DT',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // RIGHT COLUMN: Structure, Département, Poste, Type contrat, Méthode payment, Bank Account
  // -------------------------------------------------------------------------
  Widget _buildRightColumn(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type de structure salariale
        _buildDropdownField(
          label: 'Type de structure salariale',
          value: _salaryStructureType,
          items: const ['Employee', 'Cadre', 'Ouvrier', 'Stagiaire'],
          onChanged: (val) => setState(() => _salaryStructureType = val ?? 'Employee'),
        ),
        const SizedBox(height: 14),

        // Département
        _buildLabelledInput(
          label: 'Département',
          controller: _deptCtrl,
          hint: 'IT, Commercial, RH...',
        ),
        const SizedBox(height: 14),

        // Poste
        _buildLabelledInput(
          label: 'Poste',
          controller: _jobTitleCtrl,
          hint: 'developer, designer...',
        ),
        const SizedBox(height: 14),

        // Type de contrat
        _buildDropdownField(
          label: 'Type de contrat',
          value: _contractType,
          items: const ['CDI', 'CDD', 'SIVP', 'Stage', 'Freelance'],
          onChanged: (val) => setState(() => _contractType = val ?? 'CDI'),
        ),
        const SizedBox(height: 14),

        // Méthode de Payment
        _buildDropdownField(
          label: 'Méthode de Payment',
          value: _paymentMethod,
          items: const ['Virement', 'Espèces', 'Chèque'],
          onChanged: (val) => setState(() => _paymentMethod = val ?? 'Virement'),
        ),
        const SizedBox(height: 14),

        // Bank Account 1 (Image 2, 3 & 5)
        if (_paymentMethod == 'Virement') _buildBankAccountField(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // EMPLOYEE SELECTOR (Badge / Picker)
  // -------------------------------------------------------------------------
  Widget _buildEmployeeSelector() {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees =
            empState is EmployeesLoaded ? empState.employees : <Employee>[];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 150,
              child: Text(
                'Employé',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _labelColor,
                ),
              ),
            ),
            Expanded(
              child: widget.employee != null
                  ? _buildEmployeeBadge(widget.employee!)
                  : employees.isEmpty
                      ? const Text('Aucun employé disponible')
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedEmployee?.id ??
                              (employees.isNotEmpty ? employees.first.id : null),
                          isExpanded: true,
                          decoration: _inputDecoration(null),
                          items: employees.map((emp) {
                            return DropdownMenuItem<String>(
                              value: emp.id,
                              child: _buildEmployeeBadge(emp),
                            );
                          }).toList(),
                          onChanged: (empId) {
                            final chosen = employees.firstWhere(
                                (e) => e.id == empId,
                                orElse: () => employees.first);
                            setState(() {
                              _selectedEmployee = chosen;
                              _hiringDate = chosen.hireDate;
                              _deptCtrl.text = chosen.department;
                              _jobTitleCtrl.text = chosen.jobTitle;
                              _bankAccountHolder = chosen.fullName;
                            });
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmployeeBadge(Employee emp) {
    final initial = emp.firstName.isNotEmpty
        ? emp.firstName[0].toUpperCase()
        : (emp.lastName.isNotEmpty ? emp.lastName[0].toUpperCase() : 'E');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981), // Green badge like in image 2
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            emp.fullName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // WORKING HOURS ROW (Mensuel + Standard 40 h)
  // -------------------------------------------------------------------------
  Widget _buildWorkingHoursRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 150,
          child: Row(
            children: [
              Text(
                'Heures de travail',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _labelColor,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.help_outline, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  initialValue: _workingHoursType,
                  isExpanded: true,
                  decoration: _compactInputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'Mensuel', child: Text('Mensuel')),
                    DropdownMenuItem(
                        value: 'Hebdomadaire', child: Text('Hebdomadaire')),
                  ],
                  onChanged: (val) =>
                      setState(() => _workingHoursType = val ?? 'Mensuel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  initialValue: _workingHoursStandard,
                  isExpanded: true,
                  decoration: _compactInputDecoration(),
                  items: const [
                    DropdownMenuItem(
                        value: 'Standard 40 h', child: Text('Standard 40 h', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'Standard 48 h', child: Text('Standard 48 h', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'Temps partiel 20 h',
                        child: Text('Temps partiel 20 h', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setState(
                      () => _workingHoursStandard = val ?? 'Standard 40 h'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // BANK ACCOUNT FIELD & BUTTON (Image 2 & 5)
  // -------------------------------------------------------------------------
  Widget _buildBankAccountField() {
    final hasAccount = _bankAccountNumber.trim().isNotEmpty;
    final accountDisplay = hasAccount
        ? '$_bankAccountNumber${_bankName.isNotEmpty ? ' - $_bankName' : ''}'
        : 'Bank Account 1';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 150,
          child: Text(
            'Bank Account 1',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _labelColor,
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: _openCreateBankAccountDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasAccount ? _primaryBlue : _borderLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasAccount
                        ? Icons.account_balance_rounded
                        : Icons.add_circle_outline,
                    size: 16,
                    color: hasAccount ? _primaryBlue : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasAccount ? accountDisplay : 'Créer / Configurer Compte',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            hasAccount ? FontWeight.w600 : FontWeight.w500,
                        color: hasAccount
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.edit_outlined,
                      size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ACCOUNTING SECTION (Image 1 & 2)
  // -------------------------------------------------------------------------
  Widget _buildAccountingSection(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCOUNTING',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            _buildLabelledInput(
              label: 'Analytic Account',
              controller: _analyticAccountCtrl,
              hint: 'Ex: Compte analytique...',
            ),
            const SizedBox(height: 10),
            _buildLabelledInput(
              label: 'Salary Journal',
              controller: _salaryJournalCtrl,
              hint: 'Ex: Journal des salaires...',
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildLabelledInput(
                    label: 'Analytic Account',
                    controller: _analyticAccountCtrl,
                    hint: 'Compte analytique...',
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildLabelledInput(
                    label: 'Salary Journal',
                    controller: _salaryJournalCtrl,
                    hint: 'Journal des salaires...',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // TABS: Informations sur le salaire / Détails du contrat (Image 2 & 5)
  // -------------------------------------------------------------------------
  Widget _buildTabsBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderLight, width: 1.5),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: _primaryBlue,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        indicatorColor: _primaryBlue,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Informations sur le salaire'),
          Tab(text: 'Détails du contrat'),
        ],
      ),
    );
  }

  Widget _buildSalaryTab(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSalaryLeftSection(),
                  const SizedBox(height: 20),
                  const Divider(color: _borderLight),
                  const SizedBox(height: 12),
                  _buildSalaryScaleSection(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildSalaryLeftSection()),
                  const SizedBox(width: 32),
                  Expanded(flex: 4, child: _buildSalaryScaleSection()),
                ],
              ),
      ),
    );
  }

  Widget _buildSalaryLeftSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Salaire ? (Image 2 & 5: "DT 1 250,000 / mois")
        _buildLabelledInput(
          label: 'Salaire ?',
          controller: _wageCtrl,
          prefix: 'DT ',
          suffix: '/ mois',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 14),

        // Months (e.g. 13,50)
        _buildLabelledInput(
          label: 'Months',
          controller: _monthsCtrl,
          hint: '13,50',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 14),

        // Structure salariale (Image 1: Dropdown + Arrow button ➔)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 150,
              child: Row(
                children: [
                  Text(
                    'Structure salariale',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _labelColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _salaryStructures.contains(_wageStructureCtrl.text)
                    ? _wageStructureCtrl.text
                    : _salaryStructures.first,
                isExpanded: true,
                decoration: _inputDecoration(null),
                items: _salaryStructures.map((s) {
                  return DropdownMenuItem<String>(
                    value: s,
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _wageStructureCtrl.text = val);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Image 1: Arrow button ➔ that navigates to the structure salariale
            Tooltip(
              message: 'Consulter la structure salariale',
              child: InkWell(
                onTap: () {
                  SalaryStructureDialog.show(
                    context,
                    structureName: _wageStructureCtrl.text.isNotEmpty
                        ? _wageStructureCtrl.text
                        : 'Contrat de travail à durée indéterminée',
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _borderLight),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSalaryScaleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ÉCHELLE SALARIALE',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),

        // Catégorie d'Échelle Salariale
        _buildLabelledInput(
          label: "Catégorie d'Échelle Salariale",
          controller: _wageScaleCategoryCtrl,
          hint: 'Ex: Catégorie A3...',
        ),
        const SizedBox(height: 14),

        // Échelle Salariale
        _buildLabelledInput(
          label: 'Échelle Salariale',
          controller: _salaryScaleCtrl,
          hint: '0',
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 14),

        // Niveau Hiérarchique
        _buildLabelledInput(
          label: 'Niveau Hiérarchique',
          controller: _hierarchicalLevelCtrl,
          hint: '0',
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 14),

        // Date d'Affectation
        _buildDatePickerField(
          label: "Date d'Affectation",
          value: _affectationDate,
          isOptional: true,
          onSelect: (dt) => setState(() => _affectationDate = dt),
          onClear: () => setState(() => _affectationDate = null),
        ),
      ],
    );
  }

  Widget _buildContractDetailsTab(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildLabelledInput(
                    label: "Période d'essai (mois)",
                    controller: _trialPeriodMonthsCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildDropdownField(
                    label: 'Statut du contrat',
                    value: _status,
                    items: const ['active', 'draft', 'expired', 'terminated'],
                    onChanged: (val) =>
                        setState(() => _status = val ?? 'active'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildLabelledInput(
              label: 'Notes & clauses spécifiques',
              controller: _notesCtrl,
              hint: 'Clauses de non-concurrence, télétravail, avantages...',
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // BOTTOM BAR
  // -------------------------------------------------------------------------
  Widget _buildBottomBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              side: const BorderSide(color: _borderLight),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ignorer / Annuler',
                style: TextStyle(color: Color(0xFF475569))),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saveContract,
            icon: const Icon(Icons.check, size: 18, color: Colors.white),
            label: const Text(
              'Enregistrer & Fermer',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SUB-DIALOG 1: "Créer Bank Account 1" (Image 3)
  // -------------------------------------------------------------------------
  void _openCreateBankAccountDialog() {
    final accNumCtrl = TextEditingController(text: _bankAccountNumber);
    final holderDifferentCtrl = TextEditingController();
    final holderCtrl = TextEditingController(
      text: _bankAccountHolder.isNotEmpty
          ? _bankAccountHolder
          : (_selectedEmployee?.fullName ?? ''),
    );
    String selectedBank = _bankName.isNotEmpty ? _bankName : 'zitouna';
    String currency = _bankCurrency;
    bool sendMoneyVal = _sendMoney;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 740),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Title and Close X
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Créer Bank Account 1',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Form Fields (Image 3) responsive layout
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 620;

                            final leftColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSubLabelledInput(
                                  label: 'Numéro de compte',
                                  controller: accNumCtrl,
                                  hint: '123456',
                                ),
                                const SizedBox(height: 14),

                                // Banque selector with "+ Créer Banque" button
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 140,
                                      child: Text(
                                        'Banque',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: _labelColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              initialValue: selectedBank,
                                              isExpanded: true,
                                              decoration: _inputDecoration(null),
                                              items: <String>{
                                                'zitouna',
                                                'BIAT',
                                                'Attijari',
                                                'STB',
                                                'BNA',
                                                'BH Bank',
                                                'UIB',
                                                'Amen Bank',
                                                if (selectedBank.isNotEmpty) selectedBank,
                                              }.map((b) {
                                                return DropdownMenuItem(
                                                    value: b, child: Text(b));
                                              }).toList(),
                                              onChanged: (v) {
                                                if (v != null) {
                                                  setDialogState(
                                                      () => selectedBank = v);
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Créer une nouvelle banque',
                                            icon: const Icon(
                                              Icons.add_circle,
                                              color: _primaryBlue,
                                              size: 22,
                                            ),
                                            onPressed: () {
                                              _openCreateBankDialog((newBank) {
                                                setDialogState(() {
                                                  selectedBank = newBank;
                                                });
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                _buildSubLabelledInput(
                                  label:
                                      'Nom du titulaire si différent du partenaire ?',
                                  controller: holderDifferentCtrl,
                                  hint: 'Alex',
                                ),
                                const SizedBox(height: 14),

                                _buildSubLabelledInput(
                                  label: 'Titulaire de compte',
                                  controller: holderCtrl,
                                  hint: 'Alex',
                                ),
                              ],
                            );

                            final rightColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 70,
                                      child: Text(
                                        'Devise',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: _labelColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: currency,
                                        isExpanded: true,
                                        decoration: _inputDecoration(null),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'TND', child: Text('TND')),
                                          DropdownMenuItem(
                                              value: 'EUR', child: Text('EUR')),
                                          DropdownMenuItem(
                                              value: 'USD', child: Text('USD')),
                                        ],
                                        onChanged: (v) => setDialogState(
                                            () => currency = v ?? 'TND'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Envoyer de l'argent ? switch + Non fiable with Wrap to prevent overflow
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          "Envoyer de l'argent",
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _labelColor,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.help_outline,
                                          size: 13,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: sendMoneyVal,
                                          activeThumbColor: _primaryBlue,
                                          onChanged: (v) => setDialogState(
                                              () => sendMoneyVal = v),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Non fiable',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            );

                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  leftColumn,
                                  const SizedBox(height: 16),
                                  rightColumn,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: leftColumn),
                                const SizedBox(width: 24),
                                Expanded(flex: 5, child: rightColumn),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 28),

                        // Footer Buttons (Enregistrer & Fermer / Ignorer)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _bankAccountNumber = accNumCtrl.text.trim();
                                  _bankName = selectedBank;
                                  _bankAccountHolder = holderCtrl.text.trim();
                                  _bankCurrency = currency;
                                  _sendMoney = sendMoneyVal;
                                });
                                Navigator.of(dialogCtx).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text(
                                'Enregistrer & Fermer',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                side: const BorderSide(color: _borderLight),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('Ignorer',
                                  style: TextStyle(color: Color(0xFF475569))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // SUB-DIALOG 2: "Créer Banque" (Image 4)
  // -------------------------------------------------------------------------
  void _openCreateBankDialog(ValueChanged<String> onBankCreated) {
    final nameCtrl = TextEditingController(text: 'zitouna');
    final bicCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final street2Ctrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final zipCtrl = TextEditingController();
    final countryCtrl = TextEditingController(text: 'Tunisie');
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Créer Banque',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Nom (e.g. zitouna)
                    _buildSubLabelledInput(
                      label: 'Nom',
                      controller: nameCtrl,
                      hint: 'zitouna',
                    ),
                    const SizedBox(height: 14),

                    // Banque Principale
                    _buildSubLabelledInput(
                      label: 'Banque Principale',
                      controller: TextEditingController(),
                      hint: 'Sélectionner ou saisir...',
                    ),
                    const SizedBox(height: 14),

                    // Code d'identification bancaire ?
                    _buildSubLabelledInput(
                      label: "Code d'identification bancaire ?",
                      controller: bicCtrl,
                      hint: 'Code BIC / SWIFT',
                    ),
                    const SizedBox(height: 14),

                    // Adresse bancaire
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text(
                            'Adresse bancaire',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _labelColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: streetCtrl,
                                decoration: _inputDecoration('Rue...'),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: street2Ctrl,
                                decoration: _inputDecoration('Rue 2...'),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: cityCtrl,
                                      decoration: _inputDecoration('Ville'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: stateCtrl,
                                      decoration: _inputDecoration('État'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: zipCtrl,
                                      decoration: _inputDecoration('Code postal'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: countryCtrl,
                                      decoration: _inputDecoration('Pays'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Téléphone & Email
                    Row(
                      children: [
                        const SizedBox(width: 140),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: phoneCtrl,
                                  decoration: _inputDecoration('Téléphone'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextFormField(
                                  controller: emailCtrl,
                                  decoration: _inputDecoration('Email'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Buttons (Image 4)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            final bName = nameCtrl.text.trim();
                            if (bName.isNotEmpty) {
                              onBankCreated(bName);
                            }
                            Navigator.of(dialogCtx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text(
                            'Enregistrer & Fermer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            side: const BorderSide(color: _borderLight),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Ignorer',
                              style: TextStyle(color: Color(0xFF475569))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // FORM HELPERS & WIDGETS
  // -------------------------------------------------------------------------
  Widget _buildLabelledInput({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? prefix,
    String? suffix,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment:
          maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _labelColor,
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: _inputDecoration(
              hint,
              prefixText: prefix,
              suffixText: suffix,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubLabelledInput({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _labelColor,
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: _inputDecoration(hint),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _labelColor,
            ),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: items.contains(value) ? value : items.first,
            isExpanded: true,
            decoration: _inputDecoration(null),
            items: items.map((it) {
              return DropdownMenuItem<String>(
                value: it,
                child: Text(
                  it,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onSelect,
    VoidCallback? onClear,
    bool isOptional = false,
  }) {
    final displayText = value != null ? _dateFmt.format(value) : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _labelColor,
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2040),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: _primaryBlue,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                onSelect(picked);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 15, color: _primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayText.isNotEmpty
                          ? displayText
                          : (isOptional ? 'Non définie' : 'Sélectionner...'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: displayText.isNotEmpty
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (isOptional && value != null && onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: const Icon(Icons.clear,
                          size: 16, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String? hint, {
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      suffixText: suffixText,
      prefixStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: _primaryBlue,
      ),
      suffixStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF64748B),
      ),
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: _surfaceLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
    );
  }

  InputDecoration _compactInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: _surfaceLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SAVE CONTRACT ACTION
  // -------------------------------------------------------------------------
  void _saveContract() {
    if (!_formKey.currentState!.validate()) return;

    final empId = _selectedEmployee?.id ?? widget.employee?.id ?? '';
    final empName = _selectedEmployee?.fullName ??
        widget.employee?.fullName ??
        _bankAccountHolder;

    final wageVal = _parseFrenchDouble(_wageCtrl.text.trim(), 1250.0);
    final monthsVal = _parseFrenchDouble(_monthsCtrl.text.trim(), 12.0);
    final overtimeVal =
        _parseFrenchDouble(_overtimeHourlyRateCtrl.text.trim(), 0.0);
    final dailyRateVal = _parseFrenchDouble(_dailyRateCtrl.text.trim(), 0.0);
    final trialMonths =
        int.tryParse(_trialPeriodMonthsCtrl.text.trim()) ?? 3;

    final contract = EmployeeContract(
      id: widget.contract?.id ?? const Uuid().v4(),
      reference: _refCtrl.text.trim().isNotEmpty
          ? _refCtrl.text.trim()
          : 'CTR/${DateTime.now().year}/001',
      employeeId: empId,
      employeeName: empName,
      hiringDate: _hiringDate,
      startDate: _startDate,
      endDate: _endDate,
      workingHoursType: _workingHoursType,
      workingHoursStandard: _workingHoursStandard,
      overtimeHourlyRate: overtimeVal,
      dailyRate: dailyRateVal,
      salaryStructureType: _salaryStructureType,
      department: _deptCtrl.text.trim().isNotEmpty
          ? _deptCtrl.text.trim()
          : 'Administration',
      jobTitle: _jobTitleCtrl.text.trim().isNotEmpty
          ? _jobTitleCtrl.text.trim()
          : 'Poste',
      contractType: _contractType,
      paymentMethod: _paymentMethod,
      bankAccountNumber: _bankAccountNumber.isNotEmpty ? _bankAccountNumber : null,
      bankName: _bankName.isNotEmpty ? _bankName : null,
      bankAccountHolder: _bankAccountHolder.isNotEmpty ? _bankAccountHolder : null,
      analyticAccount: _analyticAccountCtrl.text.trim().isNotEmpty
          ? _analyticAccountCtrl.text.trim()
          : null,
      salaryJournal: _salaryJournalCtrl.text.trim().isNotEmpty
          ? _salaryJournalCtrl.text.trim()
          : null,
      wage: wageVal,
      wageMonths: monthsVal,
      wageStructure: _wageStructureCtrl.text.trim().isNotEmpty
          ? _wageStructureCtrl.text.trim()
          : 'Contrat de travail à durée indéterminée',
      wageScaleCategory: _wageScaleCategoryCtrl.text.trim().isNotEmpty
          ? _wageScaleCategoryCtrl.text.trim()
          : 'Grille salariale',
      salaryScale: _salaryScaleCtrl.text.trim().isNotEmpty
          ? _salaryScaleCtrl.text.trim()
          : '0',
      hierarchicalLevel: _hierarchicalLevelCtrl.text.trim().isNotEmpty
          ? _hierarchicalLevelCtrl.text.trim()
          : '0',
      affectationDate: _affectationDate,
      trialPeriodMonths: trialMonths,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      status: _status,
      createdAt: widget.contract?.createdAt,
      updatedAt: DateTime.now(),
    );

    if (widget.contract != null) {
      context.read<ContractsBloc>().add(UpdateContract(contract));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contrat ${contract.reference} mis à jour avec succès!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      context.read<ContractsBloc>().add(AddContract(contract));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contrat ${contract.reference} créé avec succès!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    Navigator.of(context).pop();
  }
}
