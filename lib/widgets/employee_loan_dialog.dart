import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../blocs/loans/loans_bloc.dart';
import '../blocs/loans/loans_event.dart';
import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../models/employee.dart';
import '../models/employee_loan.dart';

class EmployeeLoanDialog extends StatefulWidget {
  final Employee? employee;
  final EmployeeLoan? loan;

  const EmployeeLoanDialog({
    super.key,
    this.employee,
    this.loan,
  });

  static Future<void> show(BuildContext context, {Employee? employee, EmployeeLoan? loan}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmployeeLoanDialog(
        employee: employee,
        loan: loan,
      ),
    );
  }

  @override
  State<EmployeeLoanDialog> createState() => _EmployeeLoanDialogState();
}

class _EmployeeLoanDialogState extends State<EmployeeLoanDialog> {
  final _formKey = GlobalKey<FormState>();

  // Styling
  static const Color _primaryBlue = Color(0xFF1A56DB);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _surfaceLight = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  // Suggested Loan Names (Image 2)
  final List<String> _suggestedLoanNames = [
    'prêt aid kbir',
    'prêt aid sghir',
    'prêt personnel',
    'prêt rentrée scolaire',
    'prêt achat véhicule',
    'avance exceptionnelle',
  ];

  // Controllers & Form State
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _monthlyAmountCtrl;
  late TextEditingController _monthsCountCtrl;
  late TextEditingController _notesCtrl;

  Employee? _selectedEmployee;
  bool _isCompanyCredit = false;
  DateTime _loanDate = DateTime.now();
  String _status = 'draft'; // 'draft', 'confirmed', 'paid', 'cancelled'
  double _remainingAmount = 0.0;

  // Remboursements (Installment rows)
  final List<Map<String, dynamic>> _repaymentRows = [];

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;

    _nameCtrl = TextEditingController(text: loan?.name ?? 'prêt aid kbir');
    _amountCtrl = TextEditingController(
      text: loan != null ? _formatNumber(loan.amount) : '1500,00',
    );
    _monthsCountCtrl = TextEditingController(
      text: loan != null ? loan.monthsCount.toString() : '10',
    );
    _monthlyAmountCtrl = TextEditingController(
      text: loan != null ? _formatNumber(loan.monthlyAmount) : '150,00',
    );
    _notesCtrl = TextEditingController(text: loan?.notes ?? '');

    _isCompanyCredit = loan?.isCompanyCredit ?? false;
    _loanDate = loan?.date ?? DateTime.now();
    _status = loan?.status ?? 'draft';
    _remainingAmount = loan?.remainingAmount ?? (loan?.amount ?? 1500.0);

    // Initial selected employee
    _selectedEmployee = widget.employee;

    // Initialize repayment schedule
    if (loan != null && loan.repayments.isNotEmpty) {
      for (final r in loan.repayments) {
        _repaymentRows.add({
          'id': r.id,
          'date': r.date,
          'amount': r.amount,
          'amountCtrl': TextEditingController(text: _formatNumber(r.amount)),
          'payslipId': r.payslipId,
          'payslipReference': r.payslipReference,
          'status': r.status,
        });
      }
    } else {
      _generateSchedule();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _monthlyAmountCtrl.dispose();
    _monthsCountCtrl.dispose();
    _notesCtrl.dispose();
    for (final r in _repaymentRows) {
      (r['amountCtrl'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  String _formatNumber(double amount) {
    final fmt = NumberFormat('#,##0.00', 'fr_FR');
    return fmt.format(amount);
  }

  double _parseAmount(String val) {
    final cleaned = val.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  void _generateSchedule() {
    final double total = _parseAmount(_amountCtrl.text);
    final int months = int.tryParse(_monthsCountCtrl.text) ?? 1;

    if (months <= 0) return;

    final double monthly = total / months;
    _monthlyAmountCtrl.text = _formatNumber(monthly);

    // Dispose old controllers
    for (final r in _repaymentRows) {
      (r['amountCtrl'] as TextEditingController?)?.dispose();
    }
    _repaymentRows.clear();

    DateTime cursor = _loanDate;
    for (int i = 0; i < months; i++) {
      final dueDate = DateTime(cursor.year, cursor.month + i, cursor.day);
      _repaymentRows.add({
        'id': const Uuid().v4(),
        'date': dueDate,
        'amount': monthly,
        'amountCtrl': TextEditingController(text: _formatNumber(monthly)),
        'payslipId': null,
        'payslipReference': null,
        'status': 'draft',
      });
    }

    _remainingAmount = total;
    setState(() {});
  }

  void _recalculateRemaining() {
    final double total = _parseAmount(_amountCtrl.text);
    double paidTotal = 0.0;
    for (final r in _repaymentRows) {
      final st = (r['status'] ?? 'draft').toString().toLowerCase();
      if (st == 'paid' || st == 'payé') {
        paidTotal += (r['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    setState(() {
      _remainingAmount = (total - paidTotal).clamp(0.0, double.infinity);
      if (_remainingAmount == 0.0 && total > 0) {
        _status = 'paid';
      }
    });
  }

  void _saveLoan() {
    if (!_formKey.currentState!.validate()) return;

    final double total = _parseAmount(_amountCtrl.text);
    final double monthly = _parseAmount(_monthlyAmountCtrl.text);
    final int months = int.tryParse(_monthsCountCtrl.text) ?? 1;

    final repayments = _repaymentRows.map((r) {
      final amt = _parseAmount((r['amountCtrl'] as TextEditingController?)?.text ?? '0.0');
      return LoanRepayment(
        id: r['id']?.toString() ?? const Uuid().v4(),
        loanId: widget.loan?.id ?? '',
        payslipId: r['payslipId']?.toString(),
        payslipReference: r['payslipReference']?.toString(),
        date: r['date'] as DateTime? ?? DateTime.now(),
        amount: amt,
        status: r['status']?.toString() ?? 'draft',
      );
    }).toList();

    final loan = EmployeeLoan(
      id: widget.loan?.id ?? const Uuid().v4(),
      reference: widget.loan?.reference,
      name: _nameCtrl.text.trim(),
      employeeId: _selectedEmployee?.id ?? widget.loan?.employeeId ?? '',
      employeeName: _selectedEmployee?.fullName ?? widget.loan?.employeeName ?? 'Employé',
      amount: total,
      monthlyAmount: monthly > 0 ? monthly : (months > 0 ? total / months : total),
      isCompanyCredit: _isCompanyCredit,
      date: _loanDate,
      monthsCount: months,
      remainingAmount: _remainingAmount,
      status: _status,
      repayments: repayments,
      notes: _notesCtrl.text.trim(),
      enterpriseId: widget.loan?.enterpriseId,
    );

    if (widget.loan == null) {
      context.read<LoansBloc>().add(AddLoan(loan));
    } else {
      context.read<LoansBloc>().add(UpdateLoan(loan));
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              widget.loan == null
                  ? 'Prêt de ${_formatNumber(total)} DT créé avec succès !'
                  : 'Prêt mis à jour avec succès !',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 40,
        vertical: isMobile ? 12 : 30,
      ),
      child: Container(
        width: 1050,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 1. Top Header Bar (Odoo Style: Breadcrumb, Save, Undo, Close)
              _buildTopBar(isMobile),

              // 2. Action Ribbon & Stepper ([ Brouillon | Confirmé | Payé | Annulé ])
              _buildActionBar(isMobile),

              // 3. Scrollable Content (Form Fields & Remboursements Table)
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Two Column Form Fields
                      _buildFormFields(isMobile),
                      const SizedBox(height: 24),

                      // Remboursements Header & Table (Images 2 & 3)
                      _buildRepaymentsSection(isMobile),
                    ],
                  ),
                ),
              ),

              // 4. Bottom Footer (Cancel, Save)
              _buildBottomFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER BAR
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: _borderLight, width: 1.5)),
      ),
      child: Row(
        children: [
          // "Nouveau" Button (Odoo-like)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _primaryBlue.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(6),
              color: _primaryBlue.withValues(alpha: 0.08),
            ),
            child: Text(
              widget.loan == null ? 'Nouveau' : 'Modifier',
              style: const TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Breadcrumb: Prêts des employés / Nom
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Prêts des employés / ',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                  ),
                ),
                Flexible(
                  child: Text(
                    _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Nouveau',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.settings_outlined, size: 16, color: _textMuted),
                const SizedBox(width: 8),
                const Icon(Icons.cloud_done_outlined, size: 16, color: _primaryBlue),
                const SizedBox(width: 6),
                const Icon(Icons.undo_rounded, size: 16, color: _textMuted),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.close, size: 20, color: _textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ACTION RIBBON & STEPPER
  // ---------------------------------------------------------------------------
  Widget _buildActionBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderLight)),
      ),
      child: Row(
        children: [
          // "Confirmer" Button
          if (_status == 'draft')
            ElevatedButton(
              onPressed: () {
                setState(() => _status = 'confirmed');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prêt confirmé avec succès !'),
                    backgroundColor: _primaryBlue,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),

          if (_status == 'confirmed')
            OutlinedButton(
              onPressed: () => setState(() => _status = 'draft'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textMuted,
                side: const BorderSide(color: _borderLight),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Remettre en brouillon', style: TextStyle(fontSize: 12.5)),
            ),

          const SizedBox(width: 10),

          if (_status != 'cancelled' && _status != 'paid')
            TextButton(
              onPressed: () => setState(() => _status = 'cancelled'),
              child: const Text('Annuler', style: TextStyle(color: Colors.redAccent, fontSize: 12.5)),
            ),

          const Spacer(),

          // Stepper: [ Brouillon | Confirmé | Payé | Annulé ]
          _buildOdooStepper(),
        ],
      ),
    );
  }

  Widget _buildOdooStepper() {
    final steps = [
      {'key': 'draft', 'label': 'Brouillon'},
      {'key': 'confirmed', 'label': 'Confirmé'},
      {'key': 'paid', 'label': 'Payé'},
      if (_status == 'cancelled') {'key': 'cancelled', 'label': 'Annulé'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: steps.map((s) {
          final isCurrent = _status == s['key'];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent ? _primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              s['label']!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. FORM FIELDS (Images 2 & 3)
  // ---------------------------------------------------------------------------
  Widget _buildFormFields(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNomField(),
          const SizedBox(height: 14),
          _buildEmployeeSelector(),
          const SizedBox(height: 14),
          _buildAmountField(),
          const SizedBox(height: 14),
          _buildMonthlyAmountField(),
          const SizedBox(height: 14),
          _buildCompanyCreditCheckbox(),
          const SizedBox(height: 14),
          _buildDateField(),
          const SizedBox(height: 14),
          _buildMonthsCountField(),
          const SizedBox(height: 14),
          _buildRemainingAmountBox(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Nom, Employé, Montant, Montant mensuel)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNomField(),
              const SizedBox(height: 14),
              _buildEmployeeSelector(),
              const SizedBox(height: 14),
              _buildAmountField(),
              const SizedBox(height: 14),
              _buildMonthlyAmountField(),
            ],
          ),
        ),
        const SizedBox(width: 32),

        // Right Column (Company Credit, Date, Nombre de mois, Reste à rembourser)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompanyCreditCheckbox(),
              const SizedBox(height: 14),
              _buildDateField(),
              const SizedBox(height: 14),
              _buildMonthsCountField(),
              const SizedBox(height: 14),
              _buildRemainingAmountBox(),
            ],
          ),
        ),
      ],
    );
  }

  // Field: Nom (with Autocomplete / Suggestions dropdown)
  Widget _buildNomField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nom *',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark),
        ),
        const SizedBox(height: 6),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _nameCtrl.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return _suggestedLoanNames;
            }
            return _suggestedLoanNames.where((option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            _nameCtrl.text = selection;
            setState(() {});
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            controller.addListener(() {
              if (_nameCtrl.text != controller.text) {
                _nameCtrl.text = controller.text;
              }
            });
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: _inputDecoration(
                'Ex: prêt aid kbir',
                suffixIcon: Icons.arrow_drop_down,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom du prêt est requis' : null,
            );
          },
        ),
      ],
    );
  }

  // Field: Employé Selector
  Widget _buildEmployeeSelector() {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];

        if (_selectedEmployee == null && employees.isNotEmpty) {
          if (widget.loan != null) {
            _selectedEmployee = employees.firstWhere(
              (e) => e.id == widget.loan!.employeeId,
              orElse: () => employees.first,
            );
          } else {
            _selectedEmployee = employees.first;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employé *',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 6),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Employee>(
                  value: _selectedEmployee,
                  isExpanded: true,
                  hint: const Text('Sélectionner un employé', style: TextStyle(fontSize: 13, color: _textMuted)),
                  icon: const Icon(Icons.arrow_drop_down, color: _primaryBlue),
                  items: employees.map((emp) {
                    return DropdownMenuItem<Employee>(
                      value: emp,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                            child: Text(
                              emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(emp.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          if (emp.jobTitle.isNotEmpty)
                            Text(' • ${emp.jobTitle}', style: const TextStyle(fontSize: 11.5, color: _textMuted)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (Employee? newEmp) {
                    if (newEmp != null) {
                      setState(() => _selectedEmployee = newEmp);
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Field: Montant
  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Montant (TND) *',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration('1 500,00', suffixText: 'DT'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Montant requis';
            if (_parseAmount(v) <= 0) return 'Montant invalide';
            return null;
          },
          onChanged: (_) => _generateSchedule(),
        ),
      ],
    );
  }

  // Field: Montant mensuel
  Widget _buildMonthlyAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Montant mensuel (TND)',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _monthlyAmountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration('150,00', suffixText: 'DT'),
          onChanged: (val) {
            final double monthly = _parseAmount(val);
            final double total = _parseAmount(_amountCtrl.text);
            if (monthly > 0 && total > 0) {
              final months = (total / monthly).ceil();
              _monthsCountCtrl.text = months.toString();
              _generateSchedule();
            }
          },
        ),
      ],
    );
  }

  // Field: Company Credit Checkbox
  Widget _buildCompanyCreditCheckbox() {
    return Row(
      children: [
        const Text(
          'Company Credit',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
        ),
        const SizedBox(width: 12),
        Checkbox(
          value: _isCompanyCredit,
          activeColor: _primaryBlue,
          onChanged: (v) => setState(() => _isCompanyCredit = v ?? false),
        ),
      ],
    );
  }

  // Field: Date
  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _loanDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              setState(() => _loanDate = picked);
              _generateSchedule();
            }
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: _primaryBlue),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(_loanDate),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Field: Nombre de mois
  Widget _buildMonthsCountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nombre de mois',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _monthsCountCtrl,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('10'),
          onChanged: (_) => _generateSchedule(),
        ),
      ],
    );
  }

  // Field: Reste à rembourser
  Widget _buildRemainingAmountBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reste à rembourser',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _textDark),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatNumber(_remainingAmount)} DT',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryBlue),
              ),
              if (_remainingAmount == 0.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Entièrement remboursé',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. REMBOURSEMENTS SECTION (Matching Images 2 & 3)
  // ---------------------------------------------------------------------------
  Widget _buildRepaymentsSection(bool isMobile) {
    double totalScheduled = 0.0;
    for (final r in _repaymentRows) {
      totalScheduled += _parseAmount((r['amountCtrl'] as TextEditingController?)?.text ?? '0.0');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Remboursements',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final lastDate = _repaymentRows.isNotEmpty
                    ? (_repaymentRows.last['date'] as DateTime)
                    : _loanDate;
                final nextDate = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
                final defaultAmt = _parseAmount(_monthlyAmountCtrl.text);
                setState(() {
                  _repaymentRows.add({
                    'id': const Uuid().v4(),
                    'date': nextDate,
                    'amount': defaultAmt,
                    'amountCtrl': TextEditingController(text: _formatNumber(defaultAmt)),
                    'payslipId': null,
                    'payslipReference': null,
                    'status': 'draft',
                  });
                });
                _recalculateRemaining();
              },
              icon: const Icon(Icons.add, size: 16, color: _primaryBlue),
              label: const Text('Ajouter une ligne', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Table Header (Fiche de paie | Date | Montant | État | Actions)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderLight),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(bottom: BorderSide(color: _borderLight)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('Fiche de paie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Montant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('État', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMuted)),
                    ),
                    SizedBox(width: 40),
                  ],
                ),
              ),

              // Rows
              if (_repaymentRows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Aucune ligne de remboursement générée.', style: TextStyle(fontSize: 12.5, color: _textMuted)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _repaymentRows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: _borderLight),
                  itemBuilder: (ctx, idx) {
                    final row = _repaymentRows[idx];
                    final rowDate = row['date'] as DateTime? ?? DateTime.now();
                    final ctrl = row['amountCtrl'] as TextEditingController;
                    final payslipRef = row['payslipReference']?.toString();
                    final status = (row['status'] ?? 'draft').toString();
                    final isPaid = status.toLowerCase() == 'paid' || status.toLowerCase() == 'payé';

                    return Container(
                      color: idx.isEven ? Colors.white : const Color(0xFFFBFDFF),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          // Fiche de paie column (Image 2 & 3)
                          Expanded(
                            flex: 3,
                            child: payslipRef != null && payslipRef.isNotEmpty
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _primaryBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          payslipRef,
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _primaryBlue),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text('—', style: TextStyle(fontSize: 12, color: _textMuted)),
                          ),

                          // Date Column
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () async {
                                final p = await showDatePicker(
                                  context: context,
                                  initialDate: rowDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (p != null) {
                                  setState(() => row['date'] = p);
                                }
                              },
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(rowDate),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _textDark),
                              ),
                            ),
                          ),

                          // Montant Column (Editable)
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 32,
                              child: TextFormField(
                                controller: ctrl,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  row['amount'] = _parseAmount(v);
                                  _recalculateRemaining();
                                },
                              ),
                            ),
                          ),

                          // État Column (Brouillon / Payé)
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid ? Colors.green.shade50 : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPaid ? 'Payé' : 'Brouillon',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? Colors.green.shade700 : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),

                          // Trash action
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  (row['amountCtrl'] as TextEditingController?)?.dispose();
                                  _repaymentRows.removeAt(idx);
                                });
                                _recalculateRemaining();
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Summary footer in table
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: _surfaceLight,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                  border: Border(top: BorderSide(color: _borderLight)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Totale : ${_formatNumber(totalScheduled)} DT',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark),
                    ),
                    Text(
                      '${_repaymentRows.length} échéance(s)',
                      style: const TextStyle(fontSize: 12, color: _textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. BOTTOM FOOTER
  // ---------------------------------------------------------------------------
  Widget _buildBottomFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: _borderLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: const Text('Annuler', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _saveLoan,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              widget.loan == null ? 'Enregistrer le prêt' : 'Mettre à jour',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? suffixText, IconData? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      suffixText: suffixText,
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18, color: _primaryBlue) : null,
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
}
