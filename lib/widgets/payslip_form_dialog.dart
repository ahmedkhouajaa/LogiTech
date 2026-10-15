import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../blocs/payroll/payroll_bloc.dart';
import '../blocs/payroll/payroll_event.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../blocs/contracts/contracts_bloc.dart';
import '../blocs/contracts/contracts_state.dart';
import '../blocs/loans/loans_bloc.dart';
import '../blocs/loans/loans_event.dart';
import '../blocs/loans/loans_state.dart';
import '../models/employee.dart';
import '../models/employee_contract.dart';
import '../models/employee_loan.dart';
import '../models/salary_rule.dart';
import '../models/payslip.dart';
import 'salary_structure_dialog.dart';
import 'contract_form_dialog.dart';
import 'employee_loan_dialog.dart';
import 'salary_rule_dialog.dart';
import '../services/payslip_pdf_service.dart';
import '../services/public_holiday_service.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class PayslipFormDialog extends StatefulWidget {
  final Employee? employee;
  final Payslip? payslip;

  const PayslipFormDialog({
    super.key,
    this.employee,
    this.payslip,
  });

  static Future<void> show(
    BuildContext context, {
    Employee? employee,
    Payslip? payslip,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PayslipFormDialog(
        employee: employee,
        payslip: payslip,
      ),
    );
  }

  @override
  State<PayslipFormDialog> createState() => _PayslipFormDialogState();
}

class _PayslipFormDialogState extends State<PayslipFormDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;

  // Colors
  static const Color _primaryBlue = Color(0xFF1A56DB);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _surfaceLight = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _successGreen = Color(0xFF10B981);

  // Header State
  Employee? _selectedEmployee;
  EmployeeContract? _selectedContract;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  late TextEditingController _refCtrl;
  late TextEditingController _nameCtrl;
  String _salaryStructure = 'Standard';
  bool _isCreditNote = false; // Avoir ?
  String _paymentStatus = 'draft'; // draft, validated, paid, cancelled

  // Tab 1: Worked days & entries (Image 1: JOURS TRAVAILLÉS)
  final List<Map<String, dynamic>> _workedDaysList = [];
  final List<Map<String, dynamic>> _otherEntries = [];

  // Absence non rémunérée (ABS)
  bool _hasAbsenceRule = false;
  double _absenceDeduction = 0.0;

  double get _totalUnpaidAbsenceDays {
    double sum = 0.0;
    for (final line in _workedDaysList) {
      final code = (line['code'] as String?)?.toUpperCase() ?? '';
      final desc = (line['desc'] as String?)?.toLowerCase() ?? '';
      final isUnpaid = line['isUnpaid'] == true || code == 'ABS' || desc.contains('absence') || desc.contains('sans solde');
      if (isUnpaid) {
        sum += (line['days'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return sum;
  }

  double get _totalUnpaidAbsenceHours {
    double sum = 0.0;
    for (final line in _workedDaysList) {
      final code = (line['code'] as String?)?.toUpperCase() ?? '';
      final desc = (line['desc'] as String?)?.toLowerCase() ?? '';
      final isUnpaid = line['isUnpaid'] == true || code == 'ABS' || desc.contains('absence') || desc.contains('sans solde');
      if (isUnpaid) {
        sum += (line['hours'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return sum;
  }

  double get _totalWorkedDaysSum {
    double sum = 0.0;
    for (final line in _workedDaysList) {
      sum += (line['days'] as num?)?.toDouble() ?? 0.0;
    }
    return sum;
  }

  // Tab 2: Calculated amounts
  double _baseSalary = 1250.0;
  double _transportAllowance = 50.0;
  double _primes = 0.0;
  double _grossSalary = 1300.0;
  double _cnssDeduction = 119.340;
  double _taxDeduction = 76.500;
  double _cssDeduction = 11.800;
  double _otherDeductions = 0.0;
  double _netWage = 0.0; // 0,00 until calculated!

  // Tab 5: Avances sur salaire (Image Avances)
  final List<Map<String, dynamic>> _salaryAdvances = [];
  double get _totalAdvances {
    double sum = 0.0;
    for (final a in _salaryAdvances) {
      final amt = (a['amount'] as num?)?.toDouble() ?? 0.0;
      sum += amt;
    }
    return sum;
  }

  // Tab 6: Remboursements du prêt (Images 2 & 3)
  final List<Map<String, dynamic>> _loanRepayments = [];
  double get _totalLoanDeductions {
    double sum = 0.0;
    for (final l in _loanRepayments) {
      final amt = (l['amount'] as num?)?.toDouble() ?? 0.0;
      sum += amt;
    }
    return sum;
  }

  // Tab 7: Indemnités spécifiques & règles salariales (Images 1, 2, 3)
  final List<Map<String, dynamic>> _indemnities = [];
  double get _totalIndemnities {
    double sum = 0.0;
    for (final ind in _indemnities) {
      final amt = (ind['amount'] as num?)?.toDouble() ?? 0.0;
      sum += amt;
    }
    return sum;
  }

  // Tab 4: Accounting
  String _salaryJournal = 'Opérations diverses';
  DateTime? _accountDate;
  late TextEditingController _accountingEntryCtrl;
  late TextEditingController _batchCtrl;
  late TextEditingController _internalNoteCtrl;
  bool _establishPaymentOrder = false;

  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  final List<String> _salaryJournals = const [
    'Opérations diverses',
    'Banque',
    'Espèces',
    'Factures clients',
    'Factures fournisseurs',
    'Valorisation des stocks',
    'Différence de change',
    'TVA sur encaissements',
  ];

  final List<String> _salaryStructures = const [
    'Standard',
    'Contrat de travail à durée indéterminée',
    'Contrat de travail à durée déterminée',
    'Stage d\'initiation à la vie professionnelle (SIVP)',
    'Contrat de travail temporaire / Freelance',
    'Cadre & Direction',
  ];

  final List<String> _monthsList = const [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);

    final p = widget.payslip;
    final emp = widget.employee;

    _selectedEmployee = emp;

    if (p != null) {
      _selectedMonth = p.periodMonth;
      _selectedYear = p.periodYear;
      _refCtrl = TextEditingController(text: p.reference);
      _nameCtrl = TextEditingController(
          text: p.payslipName ??
              'Bulletin de paie de ${p.employeeName} pour ${_monthsList[p.periodMonth - 1]}-${p.periodYear}');
      _salaryStructure = p.salaryStructure.isNotEmpty ? p.salaryStructure : 'Standard';
      _isCreditNote = p.isCreditNote;
      _paymentStatus = p.paymentStatus;
      _absenceDeduction = p.unpaidAbsenceDeduction;
      if (p.unpaidAbsenceDeduction > 0 || p.unpaidAbsenceDays > 0) {
        _hasAbsenceRule = true;
      }
      _baseSalary = p.baseSalary;
      _primes = p.primes;
      _transportAllowance = p.transportAllowance;
      _grossSalary = p.grossSalary;
      _cnssDeduction = p.cnssDeduction;
      _taxDeduction = p.taxDeduction;
      _cssDeduction = p.cssDeduction;
      _otherDeductions = p.otherDeductions;
      _netWage = p.netSalary;
      _salaryJournal = p.salaryJournal ?? 'Opérations diverses';
      _accountDate = p.accountDate;
      _accountingEntryCtrl = TextEditingController(text: p.accountingEntry ?? '');
      _batchCtrl = TextEditingController(text: p.batchNumber ?? '');
      _internalNoteCtrl = TextEditingController(text: p.notes ?? '');
      _establishPaymentOrder = p.establishPaymentOrder;
    } else {
      _selectedMonth = DateTime.now().month;
      _selectedYear = DateTime.now().year;
      final empName = emp?.fullName ?? 'Alex';
      _refCtrl = TextEditingController();
      _nameCtrl = TextEditingController(
          text: 'Bulletin de paie de $empName pour ${_monthsList[_selectedMonth - 1]}-$_selectedYear');
      _baseSalary = emp?.baseSalary ?? 1250.0;
      _netWage = 0.0; // 0,00 until calculated as shown in Image 3!
      _accountingEntryCtrl = TextEditingController();
      _batchCtrl = TextEditingController();
      _internalNoteCtrl = TextEditingController();
    }

    // Initialize Worked Days matching Image 1:
    // Row 1: Normal Working Days paid at 100%, WORK100, 16.00, 125.00, C02, sequence 1
    // Row 2: Congés payés, Congés payés, 6.00, 48.00, C02, sequence 2
    final contractRef = p?.contractReference ?? _selectedContract?.reference ?? 'Contrat Mohamed';
    _workedDaysList.add({
      'id': const Uuid().v4(),
      'desc': 'Normal Working Days paid at 100%',
      'code': 'WORK100',
      'days': p != null ? p.workedDays : 25.00,
      'hours': p != null ? p.workedHours : 165.00,
      'contract': contractRef,
      'sequence': 1,
      'isUnpaid': false,
    });

    // Détection automatique des Jours Fériés (Global Leaves - Screenshot 5)
    final monthStart = DateTime(_selectedYear, _selectedMonth, 1);
    final monthEnd = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
    final monthHolidays = PublicHolidayService.instance.getHolidaysForPeriod(monthStart, monthEnd);
    if (monthHolidays.isNotEmpty) {
      _workedDaysList.add({
        'id': const Uuid().v4(),
        'desc': 'Global Leaves',
        'code': 'GLOBAL',
        'days': monthHolidays.length.toDouble(),
        'hours': monthHolidays.length * 8.0,
        'contract': contractRef,
        'sequence': 2,
        'isUnpaid': false,
      });
    } else {
      _workedDaysList.add({
        'id': const Uuid().v4(),
        'desc': 'Congés payés',
        'code': 'Congés payés',
        'days': 6.00,
        'hours': 48.00,
        'contract': contractRef,
        'sequence': 2,
        'isUnpaid': false,
      });
    }

    // Détection des heures supplémentaires sur jour férié (Overtime-X2 - Screenshot 5)
    final otHours = p?.overtimeHours ?? 0.0;
    if (otHours > 0) {
      _workedDaysList.add({
        'id': const Uuid().v4(),
        'desc': 'Overtime-X2',
        'code': 'HSX2',
        'days': double.parse((otHours / 8.0).toStringAsFixed(2)),
        'hours': otHours,
        'contract': contractRef,
        'sequence': 3,
        'isUnpaid': false,
      });
    }

    if ((p?.unpaidAbsenceDays ?? 0.0) > 0 || (p?.unpaidAbsenceDeduction ?? 0.0) > 0) {
      _hasAbsenceRule = true;
      _workedDaysList.add({
        'id': const Uuid().v4(),
        'desc': 'Absence non rémunérée',
        'code': 'ABS',
        'days': p!.unpaidAbsenceDays > 0 ? p.unpaidAbsenceDays : 2.00,
        'hours': (p.unpaidAbsenceDays > 0 ? p.unpaidAbsenceDays : 2.00) * 8.0,
        'contract': contractRef,
        'sequence': 3,
        'isUnpaid': true,
      });
    }

    // Initial Advance line matching the user's screenshot
    final initialAdvance = p?.advanceSalary ?? 0.0;
    final defaultAdvanceDate = DateTime(_selectedYear, _selectedMonth, 1);
    final empDisplayName = p?.employeeName ?? emp?.fullName ?? 'Alex';
    _salaryAdvances.add({
      'id': const Uuid().v4(),
      'date': defaultAdvanceDate,
      'employeeName': empDisplayName,
      'amount': initialAdvance,
      'controller': TextEditingController(
        text: initialAdvance > 0 ? _formatCurrency(initialAdvance) : '0,00',
      ),
    });

    // Initial Loan Repayment line if present on payslip
    final initialLoanDed = p?.loanDeduction ?? 0.0;
    if (initialLoanDed > 0) {
      _loanRepayments.add({
        'id': const Uuid().v4(),
        'loanId': '',
        'loanName': 'Remboursement de prêt',
        'date': defaultAdvanceDate,
        'amount': initialLoanDed,
        'controller': TextEditingController(text: _formatCurrency(initialLoanDed)),
        'status': 'Déduit sur ce bulletin',
      });
    }

    // Initial Indemnity line matching Image 1
    final initialIndemnity = p?.indemnitiesTotal ?? 150.0;
    final defaultStartDate = DateTime(_selectedYear, _selectedMonth, 1);
    final defaultEndDate = DateTime(_selectedYear, _selectedMonth + 1, 0);
    _indemnities.add({
      'id': const Uuid().v4(),
      'name': 'prime',
      'employeeName': empDisplayName,
      'rule': SalaryRule.defaultRules.first,
      'ruleName': 'prime',
      'startDate': defaultStartDate,
      'endDate': defaultEndDate,
      'amount': initialIndemnity > 0 ? initialIndemnity : 150.0,
      'controller': TextEditingController(
        text: _formatCurrency(initialIndemnity > 0 ? initialIndemnity : 150.0),
      ),
    });
  }

  @override
  void dispose() {
    for (final a in _salaryAdvances) {
      final ctrl = a['controller'] as TextEditingController?;
      ctrl?.dispose();
    }
    for (final l in _loanRepayments) {
      final ctrl = l['controller'] as TextEditingController?;
      ctrl?.dispose();
    }
    for (final ind in _indemnities) {
      final ctrl = ind['controller'] as TextEditingController?;
      ctrl?.dispose();
    }
    _tabController.dispose();
    _refCtrl.dispose();
    _nameCtrl.dispose();
    _accountingEntryCtrl.dispose();
    _batchCtrl.dispose();
    _internalNoteCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double val) {
    final fmt = NumberFormat('#,##0.000', 'fr_FR');
    return fmt.format(val);
  }

  String _formatTwoDecimals(double val) {
    return val.toStringAsFixed(2).replaceAll('.', ',');
  }

  String get _periodDateRange {
    final monthStr = _monthsList[_selectedMonth - 1];
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final startStr = '01/${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear';
    final endStr = '$lastDay/${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear';
    return '$monthStr-$_selectedYear  $startStr - $endStr';
  }

  void _onEmployeeChanged(Employee? emp, List<EmployeeContract> contracts) {
    if (emp == null) return;
    setState(() {
      _selectedEmployee = emp;
      _baseSalary = emp.baseSalary > 0 ? emp.baseSalary : 1250.0;

      // Find contract for this employee
      final empContracts = contracts.where((c) => c.employeeId == emp.id).toList();
      if (empContracts.isNotEmpty) {
        _selectedContract = empContracts.first;
        if (_selectedContract!.wage > 0) {
          _baseSalary = _selectedContract!.wage;
        }
        if (_selectedContract!.wageStructure.isNotEmpty) {
          _salaryStructure = _selectedContract!.wageStructure;
        }
      } else {
        _selectedContract = null;
      }

      _nameCtrl.text =
          'Bulletin de paie de ${emp.fullName} pour ${_monthsList[_selectedMonth - 1]}-$_selectedYear';
      for (final a in _salaryAdvances) {
        a['employeeName'] = emp.fullName;
      }
      for (final ind in _indemnities) {
        ind['employeeName'] = emp.fullName;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // MAIN ACTION: CALCULER LA FEUILLE (Requested by user)
  // Generates reference, validates journal, calculates Net Wage & entries!
  // Includes subtraction of unpaid absences (ABS)!
  // ---------------------------------------------------------------------------
  void _calculatePayslip() {
    // 1. Auto-generate Reference if empty
    if (_refCtrl.text.trim().isEmpty) {
      final counter = (100 + (_selectedMonth * 7) + DateTime.now().second % 90).toString();
      _refCtrl.text = 'SLIP/$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}/$counter';
    }

    // 2. Auto-generate Accounting Entry if empty
    if (_accountingEntryCtrl.text.trim().isEmpty) {
      final accCounter = (10 + (_selectedMonth * 3) + DateTime.now().second % 80).toString();
      _accountingEntryCtrl.text = 'MISC/$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}/$accCounter';
    }

    // 3. Ensure Salary Journal has value
    if (_salaryJournal.isEmpty) {
      _salaryJournal = 'Opérations diverses';
    }

    // 4. Compute Gross & Net Salary with Unpaid Absence Subtraction
    final double base = _baseSalary > 0 ? _baseSalary : 1250.0;
    final double unpaidDays = _totalUnpaidAbsenceDays;
    final double unpaidHours = _totalUnpaidAbsenceHours;

    // SOUSTRACTION DES ABSENCES NON RÉMUNÉRÉES (ABS)
    double absenceDed = 0.0;
    if (unpaidDays > 0) {
      final dailyRate = base / 22.0; // 22 jours ouvrés standard par mois
      absenceDed = unpaidDays * dailyRate;
    } else if (unpaidHours > 0) {
      final hourlyRate = base / 176.0; // 176 heures par mois
      absenceDed = unpaidHours * hourlyRate;
    }
    _absenceDeduction = absenceDed;

    // Salaire de base effectif après déduction des absences non rémunérées
    final double effectiveBase = (base - absenceDed) > 0 ? (base - absenceDed) : 0.0;
    final double transport = _transportAllowance;
    double primeTotal = 0.0;
    for (final e in _otherEntries) {
      primeTotal += (e['amount'] as num?)?.toDouble() ?? 0.0;
    }
    // Inclure les indemnités spécifiques configurées
    final double indemnitiesTotal = _totalIndemnities;
    _primes = primeTotal + indemnitiesTotal;

    final double gross = effectiveBase + transport + _primes;
    final double cnss = gross * 0.0918; // 9.18% Cotisation CNSS Salariale
    final double taxableNet = gross - cnss;

    // Progressive IRPP barème
    double irpp = 0.0;
    final annualTaxable = taxableNet * 12.0;
    if (annualTaxable <= 5000) {
      irpp = 0.0;
    } else if (annualTaxable <= 20000) {
      irpp = (annualTaxable - 5000) * 0.26;
    } else if (annualTaxable <= 30000) {
      irpp = (15000 * 0.26) + ((annualTaxable - 20000) * 0.28);
    } else if (annualTaxable <= 50000) {
      irpp = (15000 * 0.26) + (10000 * 0.28) + ((annualTaxable - 30000) * 0.32);
    } else {
      irpp = (15000 * 0.26) + (10000 * 0.28) + (20000 * 0.32) + ((annualTaxable - 50000) * 0.35);
    }
    final monthlyIrpp = irpp / 12.0;
    final double css = taxableNet * 0.01; // Contribution Sociale de Solidarité 1%
    final double advances = _totalAdvances; // SOUSTRACTION DES AVANCES SUR SALAIRE
    final double loanDeds = _totalLoanDeductions; // SOUSTRACTION DES REMBOURSEMENTS DE PRÊT
    final double net = taxableNet - monthlyIrpp - css - advances - loanDeds - _otherDeductions;

    setState(() {
      _grossSalary = gross;
      _cnssDeduction = cnss;
      _taxDeduction = monthlyIrpp;
      _cssDeduction = css;
      _netWage = net > 0 ? net : 0.0;
    });

    final details = <String>[];
    if (absenceDed > 0) details.add('-${_formatCurrency(absenceDed)} DT absence non rémunérée (${unpaidDays > 0 ? unpaidDays.toStringAsFixed(1) : (unpaidHours / 8.0).toStringAsFixed(1)} j)');
    if (indemnitiesTotal > 0) details.add('+${_formatCurrency(indemnitiesTotal)} DT indemnités');
    if (advances > 0) details.add('-${_formatCurrency(advances)} DT avances');
    if (loanDeds > 0) details.add('-${_formatCurrency(loanDeds)} DT prêt');
    final detailStr = details.isNotEmpty ? ' (${details.join(', ')})' : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Feuille de paie calculée ! Réf: ${_refCtrl.text} | Net Wage: ${_formatCurrency(_netWage)} DT$detailStr',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Recalculates Net Wage immediately when an absence, advance, indemnity or loan repayment is modified
  void _recalculateNet() {
    final double base = _baseSalary > 0 ? _baseSalary : 1250.0;
    final double unpaidDays = _totalUnpaidAbsenceDays;
    final double unpaidHours = _totalUnpaidAbsenceHours;

    // SOUSTRACTION DES ABSENCES NON RÉMUNÉRÉES (ABS)
    double absenceDed = 0.0;
    if (unpaidDays > 0) {
      final dailyRate = base / 22.0;
      absenceDed = unpaidDays * dailyRate;
    } else if (unpaidHours > 0) {
      final hourlyRate = base / 176.0;
      absenceDed = unpaidHours * hourlyRate;
    }
    _absenceDeduction = absenceDed;

    final double effectiveBase = (base - absenceDed) > 0 ? (base - absenceDed) : 0.0;
    final double transport = _transportAllowance;
    double primeTotal = 0.0;
    for (final e in _otherEntries) {
      primeTotal += (e['amount'] as num?)?.toDouble() ?? 0.0;
    }
    final double indemnitiesTotal = _totalIndemnities;
    _primes = primeTotal + indemnitiesTotal;

    final double gross = effectiveBase + transport + _primes;
    final double cnss = gross * 0.0918;
    final double taxableNet = gross - cnss;

    double irpp = 0.0;
    final annualTaxable = taxableNet * 12.0;
    if (annualTaxable <= 5000) {
      irpp = 0.0;
    } else if (annualTaxable <= 20000) {
      irpp = (annualTaxable - 5000) * 0.26;
    } else if (annualTaxable <= 30000) {
      irpp = (15000 * 0.26) + ((annualTaxable - 20000) * 0.28);
    } else if (annualTaxable <= 50000) {
      irpp = (15000 * 0.26) + (10000 * 0.28) + ((annualTaxable - 30000) * 0.32);
    } else {
      irpp = (15000 * 0.26) + (10000 * 0.28) + (20000 * 0.32) + ((annualTaxable - 50000) * 0.35);
    }
    final monthlyIrpp = irpp / 12.0;
    final double css = taxableNet * 0.01;
    final double advances = _totalAdvances;
    final double loanDeds = _totalLoanDeductions;
    final double net = taxableNet - monthlyIrpp - css - advances - loanDeds - _otherDeductions;

    setState(() {
      _grossSalary = gross;
      _cnssDeduction = cnss;
      _taxDeduction = monthlyIrpp;
      _cssDeduction = css;
      _netWage = net > 0 ? net : 0.0;
    });
  }

  // Callback when a salary rule (e.g. Absence / ABS) is added from Structure Salariale (Image 4)
  void _onSalaryRuleAdded(SalaryRule rule) {
    setState(() {
      if (rule.code == 'ABS') {
        _hasAbsenceRule = true;
        final hasAbsLine = _workedDaysList.any((w) =>
            (w['code'] as String?)?.toUpperCase() == 'ABS' ||
            (w['desc'] as String?)?.toLowerCase().contains('absence') == true);
        if (!hasAbsLine) {
          final contractRef = _selectedContract?.reference ?? 'C02';
          _workedDaysList.add({
            'id': const Uuid().v4(),
            'desc': 'Absence non rémunérée',
            'code': 'ABS',
            'days': 2.00,
            'hours': 16.00,
            'contract': contractRef,
            'sequence': _workedDaysList.length + 1,
            'isUnpaid': true,
          });
        }
      } else {
        _indemnities.add({
          'id': const Uuid().v4(),
          'name': rule.name,
          'employeeName': _selectedEmployee?.fullName ?? 'Alex',
          'rule': rule,
          'ruleName': rule.name,
          'startDate': DateTime(_selectedYear, _selectedMonth, 1),
          'endDate': DateTime(_selectedYear, _selectedMonth + 1, 0),
          'amount': rule.fixedAmount > 0 ? rule.fixedAmount : 100.0,
          'controller': TextEditingController(
            text: _formatCurrency(rule.fixedAmount > 0 ? rule.fixedAmount : 100.0),
          ),
        });
      }
      _calculatePayslip();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A56DB),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                rule.code == 'ABS'
                    ? 'Règle "Absence (ABS)" activée : les absences non rémunérées sont désormais soustraites du salaire !'
                    : 'Règle "${rule.name} (${rule.code})" appliquée sur le bulletin.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _saveAndConfirm() async {
    if (_isSaving) return;
    if (_netWage == 0.0) {
      _calculatePayslip();
    }

    final emp = _selectedEmployee;
    if (emp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un employé.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.payslip != null) {
      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!isOnline) return;
    }

    setState(() => _isSaving = true);

    try {
      final totalDays = _totalWorkedDaysSum;
      final totalHours = _workedDaysList.fold(0.0, (sum, w) => sum + ((w['hours'] as num?)?.toDouble() ?? 0.0));

      final payslip = Payslip(
        id: widget.payslip?.id ?? const Uuid().v4(),
        reference: _refCtrl.text.trim().isNotEmpty
            ? _refCtrl.text.trim()
            : 'SLIP/$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}/001',
        payslipName: _nameCtrl.text.trim(),
        employeeId: emp.id,
        employeeName: emp.fullName,
        employeeCin: emp.cin,
        employeeCnss: emp.cnssNumber,
        employeeJobTitle: emp.jobTitle,
        contractReference: _selectedContract?.reference ?? 'C02',
        salaryStructure: _salaryStructure,
        isCreditNote: _isCreditNote,
        periodMonth: _selectedMonth,
        periodYear: _selectedYear,
        workedDays: totalDays > 0 ? totalDays : 22.0,
        workedHours: totalHours > 0 ? totalHours : 176.0,
        baseSalary: _baseSalary,
        primes: _primes,
        transportAllowance: _transportAllowance,
        grossSalary: _grossSalary,
        cnssDeduction: _cnssDeduction,
        taxDeduction: _taxDeduction,
        cssDeduction: _cssDeduction,
        advanceSalary: _totalAdvances,
        loanDeduction: _totalLoanDeductions,
        indemnitiesTotal: _totalIndemnities,
        unpaidAbsenceDeduction: _absenceDeduction,
        unpaidAbsenceDays: _totalUnpaidAbsenceDays,
        otherDeductions: _otherDeductions,
        netSalary: _netWage,
        paymentStatus: 'validated',
        salaryJournal: _salaryJournal,
        accountDate: _accountDate ?? DateTime.now(),
        accountingEntry: _accountingEntryCtrl.text.trim(),
        establishPaymentOrder: _establishPaymentOrder,
        batchNumber: _batchCtrl.text.trim().isNotEmpty ? _batchCtrl.text.trim() : null,
        notes: _internalNoteCtrl.text.trim().isNotEmpty ? _internalNoteCtrl.text.trim() : null,
        createdAt: widget.payslip?.createdAt,
        updatedAt: DateTime.now(),
      );

      context.read<PayrollBloc>().add(AddPayslip(payslip));

      // Link any deducted loan repayment in LoansBloc
      for (final r in _loanRepayments) {
        final loanId = r['loanId']?.toString();
        final repId = r['id']?.toString();
        if (loanId != null && loanId.isNotEmpty && repId != null && repId.isNotEmpty) {
          context.read<LoansBloc>().add(
                PayLoanRepayment(
                  loanId: loanId,
                  repaymentId: repId,
                  payslipId: payslip.id,
                  payslipReference: payslip.reference,
                ),
              );
        }
      }

      final isOnline = ConnectivityService.instance.isOnline;
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
                      ? 'Bulletin de paie "${payslip.reference}" confirmé avec succès !'
                      : 'Bulletin "${payslip.reference}" enregistré hors ligne (en attente de synchronisation)',
                ),
              ],
            ),
            backgroundColor: isOnline ? _primaryBlue : AppColors.warning,
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _markPaid() async {
    final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
    if (!isOnline) return;
    if (_netWage == 0.0) _calculatePayslip();
    setState(() => _paymentStatus = 'paid');
    if (widget.payslip != null) {
      context.read<PayrollBloc>().add(UpdatePayslipStatus(
            id: widget.payslip!.id,
            newStatus: 'paid',
            paymentDate: DateTime.now(),
          ));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Statut du paiement mis à jour : Payé !'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _cancelPayslip() {
    setState(() {
      _paymentStatus = 'cancelled';
      _netWage = 0.0;
    });

    for (final r in _loanRepayments) {
      final loanId = r['loanId']?.toString();
      final repId = r['id']?.toString();
      if (loanId != null && loanId.isNotEmpty && repId != null && repId.isNotEmpty) {
        context.read<LoansBloc>().add(
              UnlinkLoanRepayment(
                loanId: loanId,
                repaymentId: repId,
              ),
            );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La fiche de paie a été réinitialisée en brouillon / annulée.'),
        backgroundColor: Color(0xFF64748B),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER METHODS FOR PRINTING & IMAGE 2 ACTIONS
  // ---------------------------------------------------------------------------
  Payslip _createCurrentPayslipObject({String? status}) {
    final emp = _selectedEmployee;
    final totalDays = _totalWorkedDaysSum;
    final totalHours = _workedDaysList.fold(0.0, (sum, w) => sum + ((w['hours'] as num?)?.toDouble() ?? 0.0));
    final now = DateTime.now();

    return Payslip(
      id: widget.payslip?.id ?? const Uuid().v4(),
      reference: _refCtrl.text.trim().isNotEmpty
          ? _refCtrl.text.trim()
          : 'SLIP/$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}/001',
      payslipName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
      employeeId: emp?.id ?? '',
      employeeName: emp?.fullName ?? 'Employé',
      employeeCin: emp?.cin,
      employeeCnss: emp?.cnssNumber,
      employeeJobTitle: emp?.jobTitle,
      contractReference: _selectedContract?.reference ?? 'C02',
      salaryStructure: _salaryStructure,
      isCreditNote: _isCreditNote,
      periodMonth: _selectedMonth,
      periodYear: _selectedYear,
      workedDays: totalDays > 0 ? totalDays : 22.0,
      workedHours: totalHours > 0 ? totalHours : 176.0,
      baseSalary: _baseSalary,
      primes: _primes,
      transportAllowance: _transportAllowance,
      grossSalary: _grossSalary,
      cnssDeduction: _cnssDeduction,
      taxDeduction: _taxDeduction,
      cssDeduction: _cssDeduction,
      advanceSalary: _totalAdvances,
      loanDeduction: _totalLoanDeductions,
      indemnitiesTotal: _totalIndemnities,
      unpaidAbsenceDeduction: _absenceDeduction,
      unpaidAbsenceDays: _totalUnpaidAbsenceDays,
      otherDeductions: _otherDeductions,
      netSalary: _netWage,
      paymentStatus: status ?? _paymentStatus,
      paymentDate: (status ?? _paymentStatus) == 'paid' ? (widget.payslip?.paymentDate ?? now) : null,
      salaryJournal: _salaryJournal,
      accountDate: _accountDate ?? now,
      accountingEntry: _accountingEntryCtrl.text.trim(),
      establishPaymentOrder: _establishPaymentOrder,
      batchNumber: _batchCtrl.text.trim().isNotEmpty ? _batchCtrl.text.trim() : null,
      notes: _internalNoteCtrl.text.trim().isNotEmpty ? _internalNoteCtrl.text.trim() : null,
      createdAt: widget.payslip?.createdAt ?? now,
      updatedAt: now,
    );
  }

  void _printCurrentPayslip(String type) {
    if (_netWage == 0.0) {
      _calculatePayslip();
    }
    final p = _createCurrentPayslipObject();
    PayslipPdfService.instance.printPayslip(
      context,
      p,
      type: type, // 'standard' or 'report'
      employee: _selectedEmployee,
    );
  }

  void _duplicatePayslip() {
    final now = DateTime.now();
    final newRef = 'SLIP/$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}/${now.millisecondsSinceEpoch.toString().substring(8)}';
    final emp = _selectedEmployee;
    final totalDays = _totalWorkedDaysSum;
    final totalHours = _workedDaysList.fold(0.0, (sum, w) => sum + ((w['hours'] as num?)?.toDouble() ?? 0.0));

    final duplicated = Payslip(
      id: const Uuid().v4(),
      reference: newRef,
      payslipName: _nameCtrl.text.trim().isNotEmpty ? '${_nameCtrl.text.trim()} (Copie)' : null,
      employeeId: emp?.id ?? '',
      employeeName: emp?.fullName ?? 'Employé',
      employeeCin: emp?.cin,
      employeeCnss: emp?.cnssNumber,
      employeeJobTitle: emp?.jobTitle,
      contractReference: _selectedContract?.reference ?? 'C02',
      salaryStructure: _salaryStructure,
      isCreditNote: _isCreditNote,
      periodMonth: _selectedMonth,
      periodYear: _selectedYear,
      workedDays: totalDays > 0 ? totalDays : 22.0,
      workedHours: totalHours > 0 ? totalHours : 176.0,
      baseSalary: _baseSalary,
      primes: _primes,
      transportAllowance: _transportAllowance,
      grossSalary: _grossSalary,
      cnssDeduction: _cnssDeduction,
      taxDeduction: _taxDeduction,
      cssDeduction: _cssDeduction,
      advanceSalary: _totalAdvances,
      loanDeduction: _totalLoanDeductions,
      indemnitiesTotal: _totalIndemnities,
      unpaidAbsenceDeduction: _absenceDeduction,
      unpaidAbsenceDays: _totalUnpaidAbsenceDays,
      otherDeductions: _otherDeductions,
      netSalary: _netWage,
      paymentStatus: 'draft',
      salaryJournal: _salaryJournal,
      accountDate: now,
      accountingEntry: _accountingEntryCtrl.text.trim(),
      establishPaymentOrder: _establishPaymentOrder,
      batchNumber: _batchCtrl.text.trim().isNotEmpty ? _batchCtrl.text.trim() : null,
      notes: _internalNoteCtrl.text.trim().isNotEmpty ? _internalNoteCtrl.text.trim() : null,
      createdAt: now,
      updatedAt: now,
    );
    context.read<PayrollBloc>().add(AddPayslip(duplicated));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bulletin dupliqué avec succès : $newRef'),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
    Navigator.of(context).pop();
  }

  void _deletePayslip() {
    if (widget.payslip == null) {
      Navigator.of(context).pop();
      return;
    }
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'le bulletin de paie',
      onConfirmed: () {
        context.read<PayrollBloc>().add(DeletePayslip(widget.payslip!.id));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bulletin supprimé avec succès.'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded
            ? empState.employees.where((e) => e.isActive).toList()
            : <Employee>[];

        return BlocBuilder<ContractsBloc, ContractsState>(
          builder: (context, cState) {
            final contracts = cState is ContractsLoaded
                ? cState.contracts
                : <EmployeeContract>[];

            // Auto-select first employee if not set
            if (_selectedEmployee == null && employees.isNotEmpty) {
              _selectedEmployee = employees.first;
              _nameCtrl.text =
                  'Bulletin de paie de ${_selectedEmployee!.fullName} pour ${_monthsList[_selectedMonth - 1]}-$_selectedYear';
              final c = contracts.where((c) => c.employeeId == _selectedEmployee!.id).toList();
              if (c.isNotEmpty) _selectedContract = c.first;
            }

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 24,
                vertical: isMobile ? 12 : 24,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? media.size.width * 0.96 : 1080,
                        maxHeight: isMobile ? media.size.height * 0.95 : 860,
                      ),
                      child: Column(
                        children: [
                          // Top Actions Header (Image 2 & 3)
                          _buildTopActionBar(isMobile),
                          const Divider(height: 1, color: _borderLight),

                          // Scrollable Form Body
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(isMobile ? 14 : 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Breadcrumb & Status Tracker (Image 2)
                                  _buildStatusTracker(isMobile),
                                  const SizedBox(height: 16),

                                  // Main Header Form Fields (Image 2 & 3)
                                  _buildHeaderFields(employees, contracts, isMobile),
                                  const SizedBox(height: 24),

                                  // Tabs Navigation (Images 3, 4, 5)
                                  _buildTabsHeader(isMobile),
                                  const SizedBox(height: 16),

                                  // TabBarView
                                  SizedBox(
                                    height: isMobile ? 420 : 340,
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        _buildWorkedDaysTab(isMobile),
                                        _buildSalaryCalcTab(isMobile),
                                        _buildRuleCategoriesTab(isMobile),
                                        _buildAccountingTab(isMobile),
                                        _buildAdvancesTab(isMobile),
                                        _buildLoanRepaymentsTab(isMobile),
                                        _buildIndemnitiesTab(isMobile),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Diagonal corner ribbon "PAID" (Image 2)
                    if (_paymentStatus == 'paid')
                      const _DiagonalCornerRibbon(text: 'PAID'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TOP ACTION BAR (Image 2 & 3: Nouveau | Imprimer | Confirmer | Calculer...)
  // ---------------------------------------------------------------------------
  Widget _buildTopActionBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 10,
      ),
      child: Row(
        children: [
          // "Nouveau" Button (Image 2)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              PayslipFormDialog.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB), // Signature Odoo Purple
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),

          // "🖨 Imprimer ▾" Button (Image 1 & 2)
          PopupMenuButton<String>(
            tooltip: 'Imprimer ce bulletin',
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (val) => _printCurrentPayslip(val),
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'standard',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF1A56DB)),
                    SizedBox(width: 10),
                    Text('Standard Payslip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                    SizedBox(width: 10),
                    Text('Payslip Report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_outlined, size: 16, color: Color(0xFF475569)),
                  SizedBox(width: 6),
                  Text('Imprimer', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Confirmer Button
          ElevatedButton(
            onPressed: _isSaving ? null : _saveAndConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1), // Royal purple/blue ERP accent
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),

          // Calculer la feuille Button (Highlighted in Royal Blue!)
          ElevatedButton.icon(
            onPressed: _calculatePayslip,
            icon: const Icon(Icons.calculate_outlined, size: 16, color: Colors.white),
            label: const Text(
              'Calculer la feuille',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 1,
            ),
          ),
          const SizedBox(width: 8),

          if (!isMobile) ...[
            // Annuler la fiche de paie Button
            OutlinedButton(
              onPressed: _cancelPayslip,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                side: const BorderSide(color: _borderLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Annuler la fiche de paie', style: TextStyle(color: Color(0xFF475569), fontSize: 12.5)),
            ),
            const SizedBox(width: 8),

            // Payslip Payments Button
            OutlinedButton.icon(
              onPressed: _markPaid,
              icon: const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF10B981)),
              label: const Text('Payslip Payments', style: TextStyle(color: Color(0xFF475569), fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                side: const BorderSide(color: _borderLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],

          const Spacer(),

          // Close Dialog Icon
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: _textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS TRACKER & BREADCRUMBS (Image 2: Breadcrumb / Mohamed, ⚙, Smart Buttons, Pipeline)
  // ---------------------------------------------------------------------------
  Widget _buildStatusTracker(bool isMobile) {
    final titleText = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text
        : (_selectedEmployee != null
            ? 'Bulletin de paie de ${_selectedEmployee!.fullName}'
            : 'Nouveau bulletin de paie');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb + Gear menu + Smart buttons + Status pipeline (Image 2)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            // Left: Breadcrumb + ⚙ Settings Menu
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Fiches de Paie des Employés',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A56DB),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('/', style: TextStyle(color: _textMuted, fontSize: 14)),
                ),
                Flexible(
                  child: Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ⚙ Settings Icon Popup (Image 2: Imprimer ▸, Dupliquer, Supprimer)
                PopupMenuButton<String>(
                  tooltip: 'Actions du bulletin',
                  icon: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF64748B)),
                  offset: const Offset(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) {
                    if (val == 'standard' || val == 'report') {
                      _printCurrentPayslip(val);
                    } else if (val == 'duplicate') {
                      _duplicatePayslip();
                    } else if (val == 'delete') {
                      _deletePayslip();
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'standard',
                      child: Row(
                        children: [
                          Icon(Icons.print_outlined, size: 16, color: Color(0xFF1A56DB)),
                          SizedBox(width: 10),
                          Text('Standard Payslip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.assessment_outlined, size: 16, color: Color(0xFF1A56DB)),
                          SizedBox(width: 10),
                          Text('Payslip Report', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 16, color: Color(0xFF475569)),
                          SizedBox(width: 10),
                          Text('Dupliquer', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Supprimer', style: TextStyle(fontSize: 13, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Right: Smart Buttons + Status Tracker (Image 2)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Smart Button: Feuille de paye: 18 (Image 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF1A56DB)),
                      const SizedBox(width: 6),
                      Text(
                        'Feuille de paye: $_selectedMonth',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Pipeline (Image 2: Brouillon > Paid)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPipelineStep('Brouillon', _paymentStatus == 'draft'),
                      Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
                      _buildPipelineStep('Paid', _paymentStatus == 'paid'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Large Employee Name Header (Image 2: "Mohamed")
        const Text(
          'Employé',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _selectedEmployee?.fullName ?? 'Employé',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A56DB), // Odoo signature purple
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineStep(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1A56DB) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          color: isActive ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN HEADER FIELDS (Image 3: Employé, Période, Contrat, Référence, Structure...)
  // ---------------------------------------------------------------------------
  Widget _buildHeaderFields(List<Employee> employees, List<EmployeeContract> contracts, bool isMobile) {
    final leftCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Employé (Alex ▾ ➔)
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text(
                'Employé',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<Employee>(
                initialValue: _selectedEmployee,
                isExpanded: true,
                decoration: _compactInputDecoration(),
                items: employees.map((emp) {
                  return DropdownMenuItem<Employee>(
                    value: emp,
                    child: Text(
                      emp.fullName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryBlue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (emp) => _onEmployeeChanged(emp, contracts),
              ),
            ),
            const SizedBox(width: 8),
            // Image 3: Arrow ➔ button
            Tooltip(
              message: 'Voir employé',
              child: InkWell(
                onTap: () {
                  if (_selectedEmployee != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Employé : ${_selectedEmployee!.fullName}')),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _borderLight),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 16, color: _primaryBlue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Période (octobre-2024  01/10/2024 - 31/10/2024)
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text(
                'Période',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16, color: _primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _periodDateRange,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _pickPeriodMonthYear,
                      child: const Text('Changer', style: TextStyle(fontSize: 11.5, color: _primaryBlue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Contrat (C02 or reference)
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text(
                'Contrat',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 16, color: _textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedContract?.reference ?? 'C02',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        if (_selectedEmployee != null) {
                          ContractFormDialog.show(context, employee: _selectedEmployee, contract: _selectedContract);
                        }
                      },
                      child: const Text('Ouvrir', style: TextStyle(fontSize: 11.5, color: _primaryBlue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Référence (Generated upon click Calculer: SLIP/2024/10/001)
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text(
                'Référence',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _refCtrl,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark),
                decoration: _compactInputDecoration(hint: 'Auto-généré au calcul (ex: SLIP/2024/10/001)'),
              ),
            ),
          ],
        ),
      ],
    );

    final rightCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Structure ? (Image 3: Contrat de travail à durée indéterminée + arrow ➔)
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Row(
                children: [
                  Text(
                    'Structure ?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _salaryStructures.contains(_salaryStructure) ? _salaryStructure : _salaryStructures.first,
                isExpanded: true,
                decoration: _compactInputDecoration(),
                items: _salaryStructures.map((s) {
                  return DropdownMenuItem<String>(
                    value: s,
                    child: Text(s, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _salaryStructure = val);
                },
              ),
            ),
            const SizedBox(width: 8),
            // Arrow ➔ button to view Structure Salariale (Image 2 & 3: Lien interne)
            Tooltip(
              message: 'Lien interne',
              child: InkWell(
                onTap: () => SalaryStructureDialog.show(
                  context,
                  structureName: _salaryStructure,
                  onRuleAdded: _onSalaryRuleAdded,
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF1A56DB).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF1A56DB)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Net Wage (Image 3: 0,00 or computed amount!)
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text(
                'Net Wage',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _netWage > 0 ? _successGreen.withValues(alpha: 0.08) : _surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _netWage > 0 ? _successGreen : _borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatCurrency(_netWage)} DT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _netWage > 0 ? _successGreen : const Color(0xFF334155),
                      ),
                    ),
                    if (_netWage == 0)
                      const Text(
                        '(Cliquez sur "Calculer")',
                        style: TextStyle(fontSize: 11, color: _textMuted, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Nom de bulletin de paie
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text(
                'Nom de bulletin de paie',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                decoration: _compactInputDecoration(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Avoir ? (Checkbox)
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text(
                'Avoir ?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Checkbox(
              value: _isCreditNote,
              activeColor: _primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) => setState(() => _isCreditNote = val ?? false),
            ),
            const Text('Fiche d\'avoir / Remboursement', style: TextStyle(fontSize: 12.5, color: _textMuted)),
          ],
        ),
      ],
    );

    if (isMobile) {
      return Column(
        children: [
          leftCol,
          const SizedBox(height: 16),
          const Divider(color: _borderLight),
          const SizedBox(height: 16),
          rightCol,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leftCol),
        const SizedBox(width: 32),
        Expanded(child: rightCol),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TABS HEADER (Images 3, 4, 5)
  // ---------------------------------------------------------------------------
  Widget _buildTabsHeader(bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderLight, width: 1.5)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _primaryBlue,
        unselectedLabelColor: _textMuted,
        indicatorColor: _primaryBlue,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(text: 'Jours travaillés et entrées'),
          Tab(text: 'Calcul de salaire'),
          Tab(text: 'Détails par catégorie de règle salariale'),
          Tab(text: 'Informations comptables'),
          Tab(text: 'Avances sur salaire'),
          Tab(text: 'Remboursements du prêt'),
          Tab(text: 'Indemnités'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: JOURS TRAVAILLÉS ET ENTRÉES (Image 1)
  // ---------------------------------------------------------------------------
  Widget _buildWorkedDaysTab(bool isMobile) {
    final contractRef = _selectedContract?.reference ?? 'C02';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // JOURS TRAVAILLÉS Header (Image 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'JOURS TRAVAILLÉS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                if (_totalUnpaidAbsenceDays > 0 || _hasAbsenceRule)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_circle_outline, size: 13, color: Colors.red),
                        const SizedBox(width: 5),
                        Text(
                          'Absence non rémunérée : -${_formatTwoDecimals(_totalUnpaidAbsenceDays)} j (-${_formatCurrency(_absenceDeduction)} DT)',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Table of Worked Days matching Image 1
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                    columnSpacing: isMobile ? 16 : 28,
                    columns: const [
                      DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Nombre de jours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Nombre d\'Heures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Contrat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Séquence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    rows: _workedDaysList.isEmpty
                        ? [
                            const DataRow(
                              cells: [
                                DataCell(Text('Aucune ligne de travail ou d\'absence enregistrée', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: _textMuted))),
                                DataCell(Text('-')),
                                DataCell(Text('0,00')),
                                DataCell(Text('0,00')),
                                DataCell(Text('-')),
                                DataCell(Text('-')),
                                DataCell(Text('-')),
                              ],
                            ),
                          ]
                        : _workedDaysList.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final line = entry.value;
                            final desc = (line['desc'] as String?) ?? 'Jours travaillés';
                            final code = (line['code'] as String?) ?? 'WORK100';
                            final days = (line['days'] as num?)?.toDouble() ?? 0.0;
                            final hours = (line['hours'] as num?)?.toDouble() ?? (days * 8.0);
                            final contract = (line['contract'] as String?) ?? contractRef;
                            final seq = line['sequence'] ?? (idx + 1);
                            final isUnpaid = line['isUnpaid'] == true ||
                                code.toUpperCase() == 'ABS' ||
                                desc.toLowerCase().contains('absence') ||
                                desc.toLowerCase().contains('sans solde');

                            return DataRow(
                              color: isUnpaid
                                  ? WidgetStateProperty.all(Colors.red.withValues(alpha: 0.04))
                                  : null,
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isUnpaid) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('Déduit', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                      Text(
                                        desc,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                          color: isUnpaid ? Colors.red.shade800 : _textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    code,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isUnpaid ? FontWeight.bold : FontWeight.normal,
                                      color: isUnpaid ? Colors.red : _primaryBlue,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatTwoDecimals(days),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: isUnpaid ? Colors.red : _textDark,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatTwoDecimals(hours),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12.5,
                                      color: isUnpaid ? Colors.red : _textDark,
                                    ),
                                  ),
                                ),
                                DataCell(Text(contract, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(seq.toString(), style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() {
                                        _workedDaysList.removeAt(idx);
                                      });
                                      _recalculateNet();
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // "Ajouter une ligne" Button matching Image 1
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openAddWorkedDayDialog,
                icon: const Icon(Icons.add, size: 16, color: _primaryBlue),
                label: const Text(
                  'Ajouter une ligne',
                  style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),

            // Centered Total 22,00 (Matching Image 1)
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    _formatTwoDecimals(_totalWorkedDaysSum),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                  if (_totalUnpaidAbsenceDays > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Total jours (dont ${_formatTwoDecimals(_totalUnpaidAbsenceDays)} j d\'absence déduite : -${_formatCurrency(_absenceDeduction)} DT)',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AUTRES ENTRÉES
            const Text(
              'AUTRES ENTRÉES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted, letterSpacing: 0.6),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                    columnSpacing: isMobile ? 16 : 24,
                    columns: const [
                      DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Montant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Contrat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    rows: _otherEntries.isEmpty
                        ? [
                            const DataRow(
                              cells: [
                                DataCell(Text('Aucune prime ou retenue variable ajoutée', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: _textMuted))),
                                DataCell(Text('-')),
                                DataCell(Text('0,00 DT')),
                                DataCell(Text('-')),
                                DataCell(Text('-')),
                              ],
                            ),
                          ]
                        : _otherEntries.map((e) {
                            return DataRow(
                              cells: [
                                DataCell(Text(e['desc'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                                DataCell(Text(e['code'] ?? '', style: const TextStyle(fontSize: 12, color: _primaryBlue))),
                                DataCell(Text('${_formatCurrency((e['amount'] as num?)?.toDouble() ?? 0.0)} DT', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(_selectedContract?.reference ?? 'C02')),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () => setState(() => _otherEntries.remove(e)),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openAddEntryDialog,
              icon: const Icon(Icons.add, size: 16, color: _primaryBlue),
              label: const Text('Ajouter une ligne', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: CALCUL DE SALAIRE
  // ---------------------------------------------------------------------------
  Widget _buildSalaryCalcTab(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: isMobile ? 500 : 700),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      columns: const [
                        DataColumn(label: Text('Composante salariale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DataColumn(label: Text('Base / Taux', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DataColumn(label: Text('Montant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                      ],
                      rows: [
                        _buildCalcRow('Salaire de base brut', 'Contrat', _baseSalary, Colors.black87),
                        if (_absenceDeduction > 0)
                          _buildCalcRow(
                            'Déduction Absence non rémunérée (ABS)',
                            '- ${_totalUnpaidAbsenceDays > 0 ? _formatTwoDecimals(_totalUnpaidAbsenceDays) : _formatTwoDecimals(_totalUnpaidAbsenceHours / 8.0)} j',
                            -_absenceDeduction,
                            Colors.redAccent,
                            isBold: true,
                          ),
                        _buildCalcRow('Indemnité de transport', 'Fixe mensuelle', _transportAllowance, Colors.black87),
                        if (_totalIndemnities > 0)
                          _buildCalcRow('Indemnités spécifiques (règles)', 'Allocations variables', _totalIndemnities, const Color(0xFF6B46C1), isBold: true),
                        if (_primes - _totalIndemnities > 0)
                          _buildCalcRow('Primes & Gratifications', 'Entrées variables', _primes - _totalIndemnities, Colors.black87),
                        _buildCalcRow('Salaire Brut Total', '100%', _grossSalary, _primaryBlue, isBold: true),
                        _buildCalcRow('Cotisation CNSS Salariale', '9.18%', -_cnssDeduction, Colors.redAccent),
                        _buildCalcRow('Salaire Net Imposable', 'Brut - CNSS', _grossSalary - _cnssDeduction, const Color(0xFFD97706), isBold: true),
                        _buildCalcRow('Retenue à la source IRPP', 'Barème progressif', -_taxDeduction, Colors.redAccent),
                        _buildCalcRow('Contribution Sociale de Solidarité (CSS)', '1.00%', -_cssDeduction, Colors.redAccent),
                        if (_totalAdvances > 0)
                          _buildCalcRow('Avances sur salaire (déduites)', 'Avance quinzaine / mois', -_totalAdvances, Colors.redAccent, isBold: true),
                        if (_totalLoanDeductions > 0)
                          _buildCalcRow('Remboursements du prêt (déduits)', 'Échéance de prêt', -_totalLoanDeductions, Colors.redAccent, isBold: true),
                        if (_otherDeductions > 0)
                          _buildCalcRow('Autres retenues / Déductions', 'Divers', -_otherDeductions, Colors.redAccent),
                        _buildCalcRow(
                          'NET À PAYER (Net Wage)',
                          'Montant final',
                          _netWage,
                          _successGreen,
                          isBold: true,
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildCalcRow(String title, String rate, double amount, Color color, {bool isBold = false, bool isTotal = false}) {
    final prefix = amount < 0 ? '- ' : '';
    final absAmount = amount.abs();
    return DataRow(
      color: isTotal ? WidgetStateProperty.all(const Color(0xFFECFDF5)) : null,
      cells: [
        DataCell(Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: isTotal ? 13.5 : 12.5, color: isTotal ? _successGreen : _textDark))),
        DataCell(Text(rate, style: const TextStyle(fontSize: 12, color: _textMuted))),
        DataCell(Text('$prefix${_formatCurrency(absAmount)} DT', style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: isTotal ? 14 : 12.5, color: color))),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: DÉTAILS PAR CATÉGORIE
  // ---------------------------------------------------------------------------
  Widget _buildRuleCategoriesTab(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildCategoryCard('BASIC', 'Salaire de Base', _baseSalary, Colors.blue),
            if (_absenceDeduction > 0)
              _buildCategoryCard('ABS', 'Absences Non Rémunérées', -_absenceDeduction, Colors.redAccent),
            _buildCategoryCard('ALW', 'Allocations & Indemnités', _transportAllowance + _primes, Colors.purple),
            _buildCategoryCard('GROSS', 'Salaire Brut', _grossSalary, Colors.indigo),
            _buildCategoryCard('DED', 'Total Déductions (CNSS + IRPP + CSS + Avances + Prêts)', _cnssDeduction + _taxDeduction + _cssDeduction + _totalAdvances + _totalLoanDeductions + _otherDeductions, Colors.redAccent),
            _buildCategoryCard('NET', 'Salaire Net', _netWage, _successGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String code, String name, double amount, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              Icon(Icons.pie_chart_outline, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            '${_formatCurrency(amount)} DT',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: INFORMATIONS COMPTABLES (Image 5)
  // ---------------------------------------------------------------------------
  Widget _buildAccountingTab(bool isMobile) {
    final leftDivers = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DIVERS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted, letterSpacing: 0.6),
        ),
        const SizedBox(height: 14),

        // Lots de bulletins de paie (Image 5)
        Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text(
                'Lots de bulletins de paie',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _batchCtrl,
                style: const TextStyle(fontSize: 12.5),
                decoration: _compactInputDecoration(hint: 'Ex: LOT/2024/10'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Ajouter une note interne... (Image 5)
        TextFormField(
          controller: _internalNoteCtrl,
          maxLines: 4,
          style: const TextStyle(fontSize: 12.5),
          decoration: _compactInputDecoration(hint: 'Ajouter une note interne...'),
        ),
      ],
    );

    final rightCompta = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMPTABILITÉ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted, letterSpacing: 0.6),
        ),
        const SizedBox(height: 14),

        // Établir l'ordre de paiement (Image 5)
        Row(
          children: [
            const SizedBox(
              width: 150,
              child: Text(
                'Établir l\'ordre de paiement',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Checkbox(
              value: _establishPaymentOrder,
              activeColor: _primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) => setState(() => _establishPaymentOrder = val ?? false),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Date Account ? (Image 5)
        Row(
          children: [
            const SizedBox(
              width: 150,
              child: Text(
                'Date Account ?',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: _accountDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2040),
                  );
                  if (dt != null) setState(() => _accountDate = dt);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: _primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        _accountDate != null ? _dateFmt.format(_accountDate!) : 'Non définie',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Salary Journal (Image 5: Highlighted in red/bold with options)
        Row(
          children: [
            const SizedBox(
              width: 150,
              child: Text(
                'Salary Journal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFBE123C), // Crimson/Red text matching Image 5
                ),
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _salaryJournals.contains(_salaryJournal) ? _salaryJournal : _salaryJournals.first,
                isExpanded: true,
                decoration: _compactInputDecoration(),
                items: _salaryJournals.map((j) {
                  return DropdownMenuItem<String>(
                    value: j,
                    child: Text(j, style: const TextStyle(fontSize: 12.5)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _salaryJournal = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Accounting Entry (Image 5: MISC/2024/10/004)
        Row(
          children: [
            const SizedBox(
              width: 150,
              child: Text(
                'Accounting Entry',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textMuted),
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _accountingEntryCtrl,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                decoration: _compactInputDecoration(hint: 'Généré au calcul (ex: MISC/2024/10/001)'),
              ),
            ),
          ],
        ),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            leftDivers,
            const SizedBox(height: 20),
            const Divider(color: _borderLight),
            const SizedBox(height: 20),
            rightCompta,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: leftDivers),
          const SizedBox(width: 32),
          Expanded(child: rightCompta),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 5: AVANCES SUR SALAIRE (Matching user screenshot)
  // ---------------------------------------------------------------------------
  Widget _buildAdvancesTab(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table of Salary Advances (Image: Date | Employé | Montant | Actions)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: isMobile ? 500 : 700),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 56,
                      columnSpacing: isMobile ? 16 : 28,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Date',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Employé',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Montant',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Action',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark),
                          ),
                        ),
                      ],
                      rows: _salaryAdvances.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final dt = item['date'] as DateTime? ?? DateTime.now();
                        final empName = item['employeeName']?.toString() ?? (_selectedEmployee?.fullName ?? 'Alex');
                        final ctrl = item['controller'] as TextEditingController;

                        return DataRow(
                          color: WidgetStateProperty.all(
                            idx % 2 == 0 ? const Color(0xFFF8FAFC) : Colors.white,
                          ),
                          cells: [
                            // Date with calendar picker (Image: 01/11/2024)
                            DataCell(
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: dt,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2040),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      item['date'] = picked;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _primaryBlue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 14, color: _primaryBlue),
                                      const SizedBox(width: 6),
                                      Text(
                                        _dateFmt.format(dt),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Employé Name (Image: Alex)
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                                    child: Text(
                                      empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    empName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                                  ),
                                ],
                              ),
                            ),

                            // Montant (Image: 0,00 - editable in-line with instant recalculation)
                            DataCell(
                              SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: 'DT',
                                    suffixStyle: const TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.bold),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    fillColor: Colors.white,
                                    filled: true,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(color: _borderLight),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    final clean = val.replaceAll(' ', '').replaceAll(',', '.');
                                    final parsed = double.tryParse(clean) ?? 0.0;
                                    item['amount'] = parsed;
                                    _recalculateNet();
                                  },
                                ),
                              ),
                            ),

                            // Delete Action (Image: Trash icon)
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: 'Supprimer cette avance',
                                onPressed: () {
                                  setState(() {
                                    final removed = _salaryAdvances.removeAt(idx);
                                    (removed['controller'] as TextEditingController?)?.dispose();
                                  });
                                  _recalculateNet();
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Button "Ajouter une ligne" (Matching user screenshot)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    final defaultDate = DateTime(_selectedYear, _selectedMonth, 1);
                    final ctrl = TextEditingController(text: '0,00');
                    setState(() {
                      _salaryAdvances.add({
                        'id': const Uuid().v4(),
                        'date': defaultDate,
                        'employeeName': _selectedEmployee?.fullName ?? 'Alex',
                        'amount': 0.0,
                        'controller': ctrl,
                      });
                    });
                    _recalculateNet();
                  },
                  icon: const Icon(Icons.add, size: 16, color: _primaryBlue),
                  label: const Text(
                    'Ajouter une ligne',
                    style: TextStyle(
                      color: _primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

                // Total Advances Summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _totalAdvances > 0 ? const Color(0xFFFEF2F2) : _surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _totalAdvances > 0 ? const Color(0xFFFCA5A5) : _borderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.money_off_rounded,
                        size: 16,
                        color: _totalAdvances > 0 ? Colors.redAccent : _textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total avances déduites : ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _totalAdvances > 0 ? Colors.red.shade900 : _textMuted,
                        ),
                      ),
                      Text(
                        '- ${_formatCurrency(_totalAdvances)} DT',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: _totalAdvances > 0 ? Colors.red.shade700 : _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Informative Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: _primaryBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Toute avance sur salaire saisie ici est instantanément recalculée et déduite du montant Net à Payer (Net Wage).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
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

  Widget _buildLoanRepaymentsTab(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top action button & active loans selector
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openSelectActiveLoanModal(),
                  icon: const Icon(Icons.link_rounded, size: 16, color: _primaryBlue),
                  label: const Text('Lier une échéance de prêt actif', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primaryBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    EmployeeLoanDialog.show(context, employee: _selectedEmployee);
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF10B981)),
                  label: const Text('Nouveau prêt employé', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Table with horizontal scroll & constrained minWidth to eliminate overflow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderLight),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: isMobile ? 650 : 850),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      headingRowHeight: 44,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 56,
                      columnSpacing: isMobile ? 12 : 22,
                      horizontalMargin: isMobile ? 12 : 16,
                      columns: const [
                        DataColumn(label: Text('Prêt / Intitulé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DataColumn(label: Text('Date d\'échéance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DataColumn(label: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DataColumn(label: Text('Montant à déduire (DT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                      ],
                      rows: _loanRepayments.isEmpty
                          ? [
                              DataRow(
                                cells: [
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 260),
                                      child: const Text(
                                        'Aucun remboursement de prêt déduit sur ce bulletin',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: _textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const DataCell(Text('—')),
                                  const DataCell(Text('—')),
                                  const DataCell(Text('0,000 DT')),
                                  const DataCell(Text('—')),
                                  const DataCell(SizedBox()),
                                ],
                              )
                            ]
                          : _loanRepayments.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final dt = item['date'] as DateTime? ?? DateTime.now();
                              final ctrl = item['controller'] as TextEditingController;
                              final loanName = item['loanName']?.toString() ?? 'Prêt';
                              final empName = _selectedEmployee?.fullName ?? 'Alex';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.account_balance_wallet_outlined, size: 16, color: _primaryBlue),
                                        const SizedBox(width: 8),
                                        Text(loanName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: dt,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2035),
                                        );
                                        if (picked != null) {
                                          setState(() => item['date'] = picked);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _primaryBlue.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 14, color: _primaryBlue),
                                            const SizedBox(width: 6),
                                            Text(_dateFmt.format(dt), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _primaryBlue)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                                          child: Text(empName.isNotEmpty ? empName[0].toUpperCase() : 'E', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(empName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 140,
                                      child: TextField(
                                        controller: ctrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          suffixText: 'DT',
                                          suffixStyle: const TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.bold),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          fillColor: Colors.white,
                                          filled: true,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: const BorderSide(color: _borderLight),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                            borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          final clean = val.replaceAll(' ', '').replaceAll(',', '.');
                                          final parsed = double.tryParse(clean) ?? 0.0;
                                          item['amount'] = parsed;
                                          _recalculateNet();
                                        },
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: const Text('Déduit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue)),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      tooltip: 'Supprimer ce remboursement',
                                      onPressed: () {
                                        setState(() {
                                          final removed = _loanRepayments.removeAt(idx);
                                          (removed['controller'] as TextEditingController?)?.dispose();
                                        });
                                        _recalculateNet();
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Bottom row: "Ajouter une ligne" & Live total deduction summary wrapped safely
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () {
                    final defaultDate = DateTime(_selectedYear, _selectedMonth, 1);
                    final ctrl = TextEditingController(text: '150,000');
                    setState(() {
                      _loanRepayments.add({
                        'id': const Uuid().v4(),
                        'loanId': '',
                        'loanName': 'Remboursement prêt',
                        'date': defaultDate,
                        'amount': 150.0,
                        'controller': ctrl,
                        'status': 'Déduit',
                      });
                    });
                    _recalculateNet();
                  },
                  icon: const Icon(Icons.add, size: 16, color: _primaryBlue),
                  label: const Text('Ajouter une ligne manuelle', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                ),

                // Total Loans Deductions Summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _totalLoanDeductions > 0 ? const Color(0xFFFEF2F2) : _surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _totalLoanDeductions > 0 ? const Color(0xFFFCA5A5) : _borderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.money_off_rounded,
                        size: 16,
                        color: _totalLoanDeductions > 0 ? Colors.redAccent : _textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total remboursements déduits : ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _totalLoanDeductions > 0 ? Colors.red.shade900 : _textMuted,
                        ),
                      ),
                      Text(
                        '- ${_formatCurrency(_totalLoanDeductions)} DT',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: _totalLoanDeductions > 0 ? Colors.red.shade700 : _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Informative Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: _primaryBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Toute échéance de prêt déduite ici est instantanément recalculée et soustraite du montant Net à Payer (Net Wage). Le prêt sera automatiquement mis à jour à la confirmation de la feuille.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
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

  void _openSelectActiveLoanModal() {
    final emp = _selectedEmployee;
    if (emp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner un employé.')),
      );
      return;
    }

    final loansState = context.read<LoansBloc>().state;
    final allLoans = loansState is LoansLoaded ? loansState.loans : <EmployeeLoan>[];
    final empLoans = allLoans.where((l) => l.employeeId == emp.id && l.status != 'cancelled' && l.remainingAmount > 0).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: _primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Prêts actifs de ${emp.fullName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: empLoans.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 36, color: _textMuted),
                    const SizedBox(height: 10),
                    Text(
                      'Aucun prêt actif avec solde restant trouvé pour ${emp.fullName}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: _textMuted),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        EmployeeLoanDialog.show(context, employee: emp);
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Créer un prêt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: empLoans.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, idx) {
                    final loan = empLoans[idx];
                    final unpaidRepayments = loan.repayments.where((r) => !r.isPaid).toList();
                    final nextRepayment = unpaidRepayments.isNotEmpty ? unpaidRepayments.first : null;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(Icons.money_rounded, color: _primaryBlue, size: 18),
                      ),
                      title: Text(loan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text(
                        'Montant: ${_formatCurrency(loan.amount)} DT  •  Reste: ${_formatCurrency(loan.remainingAmount)} DT  •  Mensualité: ${_formatCurrency(loan.monthlyAmount)} DT',
                        style: const TextStyle(fontSize: 11.5, color: _textMuted),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final amt = nextRepayment?.amount ?? loan.monthlyAmount;
                          final date = nextRepayment?.date ?? DateTime(_selectedYear, _selectedMonth, loan.date.day);
                          final ctrl = TextEditingController(text: _formatCurrency(amt));
                          setState(() {
                            _loanRepayments.add({
                              'id': nextRepayment?.id ?? const Uuid().v4(),
                              'loanId': loan.id,
                              'loanName': loan.name,
                              'date': date,
                              'amount': amt,
                              'controller': ctrl,
                              'status': 'Déduit sur ce bulletin',
                            });
                          });
                          _recalculateNet();
                        },
                        child: const Text('Déduire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildIndemnitiesTab(bool isMobile) {
    final empName = _selectedEmployee?.fullName ?? 'Alex';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section Title & Description matching Image 1
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'INDEMNITÉS SPÉCIFIQUES & COMPOSANTES SALARIALES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                if (_totalIndemnities > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD8B4FE)),
                    ),
                    child: Text(
                      '${_indemnities.length} ligne(s) configurée(s)',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF6B46C1)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Table matching Image 1:
            // Columns: Nom | Employé | Règle (with ➔ icon) | Date de début | Date de fin | Montant | Actions
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderLight),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columnSpacing: isMobile ? 14 : 24,
                    columns: const [
                      DataColumn(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                      DataColumn(label: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                      DataColumn(label: Text('Règle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                      DataColumn(label: Text('Date de ...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                      DataColumn(label: Text('Date de fin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                      DataColumn(label: Text('Montant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569)))),
                    ],
                    rows: _indemnities.isEmpty
                        ? [
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    'Aucune indemnité spécifique ajoutée. Cliquez sur "Ajouter une ligne" ci-dessous.',
                                    style: TextStyle(fontSize: 12, color: _textMuted, fontStyle: FontStyle.italic),
                                  ),
                                ),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                              ],
                            ),
                          ]
                        : _indemnities.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final rule = item['rule'] as SalaryRule? ?? SalaryRule.defaultRules.first;
                            final startDate = item['startDate'] as DateTime? ?? DateTime(_selectedYear, _selectedMonth, 1);
                            final endDate = item['endDate'] as DateTime? ?? DateTime(_selectedYear, _selectedMonth + 1, 0);
                            final ctrl = item['controller'] as TextEditingController;

                            return DataRow(
                              cells: [
                                // Nom (Image 1: prime, Prime de rendement)
                                DataCell(
                                  SizedBox(
                                    width: 140,
                                    child: TextFormField(
                                      initialValue: item['name'] ?? 'prime',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                        border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                      onChanged: (val) {
                                        item['name'] = val;
                                      },
                                    ),
                                  ),
                                ),

                                // Employé (Image 1: Mohamed, Alex)
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                                        child: Text(
                                          empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item['employeeName'] ?? empName,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                                      ),
                                    ],
                                  ),
                                ),

                                // Règle WITH ARROW ICON ➔ (Requested by user! Navigates to Image 2)
                                DataCell(
                                  Tooltip(
                                    message: 'Cliquez sur la flèche pour configurer la règle salariale',
                                    child: InkWell(
                                      onTap: () {
                                        SalaryRuleDialog.show(
                                          context,
                                          rule: rule,
                                          payslipName: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Bulletin de paie de $empName',
                                          onSave: (updatedRule) {
                                            setState(() {
                                              item['rule'] = updatedRule;
                                              item['ruleName'] = updatedRule.name;
                                              item['name'] = updatedRule.name;
                                              item['amount'] = updatedRule.fixedAmount;
                                              ctrl.text = _formatCurrency(updatedRule.fixedAmount);
                                            });
                                            _recalculateNet();
                                          },
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6B46C1).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFD8B4FE)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item['ruleName'] ?? rule.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: Color(0xFF6B46C1),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Arrow Icon (La flèche demandée par l'utilisateur !)
                                            Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6B46C1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Date de début (Image 1: 01/10/2024)
                                DataCell(
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: startDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          item['startDate'] = picked;
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _surfaceLight,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: _borderLight),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 13, color: _primaryBlue),
                                          const SizedBox(width: 6),
                                          Text(
                                            _dateFmt.format(startDate),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Date de fin (Image 1: 31/10/2024)
                                DataCell(
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: endDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          item['endDate'] = picked;
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _surfaceLight,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: _borderLight),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 13, color: _primaryBlue),
                                          const SizedBox(width: 6),
                                          Text(
                                            _dateFmt.format(endDate),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Montant (Image 1: 150,00 DT - editable in-line with instant recalculation)
                                DataCell(
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: ctrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        suffixText: 'DT',
                                        suffixStyle: const TextStyle(fontSize: 12, color: _textMuted, fontWeight: FontWeight.bold),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        fillColor: Colors.white,
                                        filled: true,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: _borderLight),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 1.5),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        final clean = val.replaceAll(' ', '').replaceAll(',', '.');
                                        final parsed = double.tryParse(clean) ?? 0.0;
                                        item['amount'] = parsed;
                                        _recalculateNet();
                                      },
                                    ),
                                  ),
                                ),

                                // Delete Action
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    tooltip: 'Supprimer cette indemnité',
                                    onPressed: () {
                                      setState(() {
                                        final removed = _indemnities.removeAt(idx);
                                        (removed['controller'] as TextEditingController?)?.dispose();
                                      });
                                      _recalculateNet();
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Bottom Bar: "Ajouter une ligne" (Image 1) & Total Indemnities
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    final defaultStartDate = DateTime(_selectedYear, _selectedMonth, 1);
                    final defaultEndDate = DateTime(_selectedYear, _selectedMonth + 1, 0);
                    final ctrl = TextEditingController(text: '150,000');
                    setState(() {
                      _indemnities.add({
                        'id': const Uuid().v4(),
                        'name': 'prime',
                        'employeeName': empName,
                        'rule': SalaryRule.defaultRules.first,
                        'ruleName': 'prime',
                        'startDate': defaultStartDate,
                        'endDate': defaultEndDate,
                        'amount': 150.0,
                        'controller': ctrl,
                      });
                    });
                    _recalculateNet();
                  },
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF6B46C1)),
                  label: const Text(
                    'Ajouter une ligne',
                    style: TextStyle(
                      color: Color(0xFF6B46C1),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

                // Total Indemnités Summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _totalIndemnities > 0 ? const Color(0xFFFAF5FF) : _surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _totalIndemnities > 0 ? const Color(0xFFD8B4FE) : _borderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 16,
                        color: Color(0xFF6B46C1),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Total indemnités ajoutées au brut : ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF581C87),
                        ),
                      ),
                      Text(
                        '+ ${_formatCurrency(_totalIndemnities)} DT',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B46C1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Explanatory Banner about arrow icon ➔
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF6B46C1)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cliquez sur l\'icône flèche ➔ à côté de la Règle pour configurer les conditions, le mode de calcul et les paramètres comptables de la règle salariale (Image 2 & 3).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF581C87), fontWeight: FontWeight.w500),
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


  // ---------------------------------------------------------------------------
  // DIALOG HELPERS
  // ---------------------------------------------------------------------------
  void _openAddWorkedDayDialog() {
    String selectedPreset = 'ABS';
    final descCtrl = TextEditingController(text: 'Absence non rémunérée');
    final codeCtrl = TextEditingController(text: 'ABS');
    final daysCtrl = TextEditingController(text: '2.00');
    final hoursCtrl = TextEditingController(text: '16.00');
    bool isUnpaid = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgContext, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.date_range_rounded, color: Color(0xFF1A56DB), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ajouter une ligne : Jours travaillés / Absences',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type selector
                    const Text('Type de ligne :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPreset,
                      isExpanded: true,
                      decoration: _compactInputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: 'ABS',
                          child: Text('Absence non rémunérée (Code: ABS) - Soustraire du salaire', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                        DropdownMenuItem(
                          value: 'SANS_SOLDE',
                          child: Text('Congé sans solde (Code: ABS) - Soustraire du salaire', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                        DropdownMenuItem(
                          value: 'WORK100',
                          child: Text('Normal Working Days paid at 100% (Code: WORK100)', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: 'GLOBAL',
                          child: Text('Global Leaves / Jours fériés (Code: GLOBAL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A56DB))),
                        ),
                        DropdownMenuItem(
                          value: 'HSX2',
                          child: Text('Heures supplémentaires férié (Code: HSX2 / Overtime-X2)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                        ),
                        DropdownMenuItem(
                          value: 'CP',
                          child: Text('Congés payés (Code: Congés payés)', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: 'CUSTOM',
                          child: Text('Autre / Personnalisé', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setDlgState(() {
                          selectedPreset = val;
                          if (val == 'ABS') {
                            descCtrl.text = 'Absence non rémunérée';
                            codeCtrl.text = 'ABS';
                            isUnpaid = true;
                          } else if (val == 'SANS_SOLDE') {
                            descCtrl.text = 'Congé sans solde';
                            codeCtrl.text = 'ABS';
                            isUnpaid = true;
                          } else if (val == 'WORK100') {
                            descCtrl.text = 'Normal Working Days paid at 100%';
                            codeCtrl.text = 'WORK100';
                            isUnpaid = false;
                          } else if (val == 'GLOBAL') {
                            descCtrl.text = 'Global Leaves';
                            codeCtrl.text = 'GLOBAL';
                            daysCtrl.text = '1,00';
                            hoursCtrl.text = '8,00';
                            isUnpaid = false;
                          } else if (val == 'HSX2') {
                            descCtrl.text = 'Overtime-X2';
                            codeCtrl.text = 'HSX2';
                            daysCtrl.text = '0,99';
                            hoursCtrl.text = '7,92';
                            isUnpaid = false;
                          } else if (val == 'CP') {
                            descCtrl.text = 'Congés payés';
                            codeCtrl.text = 'Congés payés';
                            isUnpaid = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Description
                    const Text('Description :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: _compactInputDecoration(hint: 'Ex: Absence non rémunérée'),
                    ),
                    const SizedBox(height: 14),

                    // Code
                    const Text('Code :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeCtrl,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: _compactInputDecoration(hint: 'Ex: ABS, WORK100'),
                    ),
                    const SizedBox(height: 14),

                    // Days & Hours
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nombre de jours :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: daysCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: _compactInputDecoration(hint: '2.00'),
                                onChanged: (val) {
                                  final d = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                  hoursCtrl.text = (d * 8.0).toStringAsFixed(2);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nombre d\'heures :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: hoursCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 12.5),
                                decoration: _compactInputDecoration(hint: '16.00'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Unpaid checkbox
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isUnpaid ? Colors.red.withValues(alpha: 0.06) : _surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isUnpaid ? Colors.red.withValues(alpha: 0.3) : _borderLight),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isUnpaid,
                            activeColor: Colors.red,
                            onChanged: (v) => setDlgState(() => isUnpaid = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              'Absence non rémunérée (soustraire automatiquement du salaire)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isUnpaid ? Colors.red.shade800 : _textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  final days = double.tryParse(daysCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  final hours = double.tryParse(hoursCtrl.text.replaceAll(',', '.')) ?? (days * 8.0);
                  final desc = descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Absence';
                  final code = codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : (isUnpaid ? 'ABS' : 'WORK100');

                  setState(() {
                    _workedDaysList.add({
                      'id': const Uuid().v4(),
                      'desc': desc,
                      'code': code,
                      'days': days,
                      'hours': hours,
                      'contract': _selectedContract?.reference ?? 'C02',
                      'sequence': _workedDaysList.length + 1,
                      'isUnpaid': isUnpaid,
                    });
                    if (isUnpaid) {
                      _hasAbsenceRule = true;
                    }
                  });

                  Navigator.pop(ctx);
                  _calculatePayslip();
                },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddEntryDialog() {
    final descCtrl = TextEditingController(text: 'Prime exceptionnelle');
    final codeCtrl = TextEditingController(text: 'BONUS');
    final amountCtrl = TextEditingController(text: '100,000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Ajouter une entrée de prime / indemnité', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code')),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant (DT)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
              setState(() {
                _otherEntries.add({
                  'desc': descCtrl.text.trim(),
                  'code': codeCtrl.text.trim(),
                  'amount': val,
                });
              });
              Navigator.pop(ctx);
              _calculatePayslip();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPeriodMonthYear() async {
    int m = _selectedMonth;
    int y = _selectedYear;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Sélectionner la période', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (dCtx, setDState) => Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: m,
                  isExpanded: true,
                  items: List.generate(12, (i) => i + 1).map((idx) {
                    return DropdownMenuItem<int>(
                      value: idx,
                      child: Text(_monthsList[idx - 1]),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDState(() => m = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  value: y,
                  isExpanded: true,
                  items: [2024, 2025, 2026, 2027].map((yr) {
                    return DropdownMenuItem<int>(
                      value: yr,
                      child: Text('$yr'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDState(() => y = val);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedMonth = m;
                _selectedYear = y;
                final empName = _selectedEmployee?.fullName ?? 'Alex';
                _nameCtrl.text = 'Bulletin de paie de $empName pour ${_monthsList[_selectedMonth - 1]}-$_selectedYear';
                if (_refCtrl.text.isNotEmpty) {
                  _refCtrl.text = 'SLIP/$_selectedYear/${_selectedMonth.toString().padLeft(2, '0')}/001';
                }
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
            child: const Text('Appliquer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  InputDecoration _compactInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: _surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
}

/// Diagonal ribbon in top right corner (Image 2: PAID)
class _DiagonalCornerRibbon extends StatelessWidget {
  final String text;

  const _DiagonalCornerRibbon({
    required this.text,
  });

  static const Color color = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 22,
      right: -32,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: 0.785398, // 45 degrees in radians
          child: Container(
            width: 140,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

