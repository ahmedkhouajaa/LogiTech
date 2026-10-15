class Payslip {
  final String id;
  final String reference; // e.g. SLIP/2024/10/001
  final String? payslipName; // e.g. Bulletin de paie de Alex pour octobre-2024
  final String employeeId;
  final String employeeName;
  final String? employeeCin;
  final String? employeeCnss;
  final String? employeeJobTitle;
  final String? contractReference; // e.g. C02 or CTR/2026/001
  final String salaryStructure; // Contrat de travail à durée indéterminée
  final bool isCreditNote; // Avoir ?
  final int periodMonth; // 1 - 12
  final int periodYear; // e.g. 2026
  final double workedDays; // default 23.0
  final double workedHours; // default 184.0
  final double baseSalary;
  final double primes; // Primes de rendement, panier, présence, etc.
  final double transportAllowance; // Indemnité de transport
  final double grossSalary; // Salaire brut
  final double cnssDeduction; // Cotisation CNSS (9.18%)
  final double taxDeduction; // Retenue IRPP
  final double cssDeduction; // Contribution Sociale de Solidarité (1%)
  final double otherDeductions; // Prêts, retenues diverses
  final double advanceSalary; // Avances sur salaire
  final double loanDeduction; // Remboursements de prêts
  final double indemnitiesTotal; // Total des indemnités spécifiques (règles salariales)
  final double unpaidAbsenceDeduction; // Déduction des absences non rémunérées (ABS)
  final double unpaidAbsenceDays; // Nombre de jours d'absence non rémunérée
  final double netSalary; // Net à payer
  final double? overtimeHours; // Heures supplémentaires (e.g. sur jour férié HSX2)
  final String paymentStatus; // draft, validated, paid, cancelled
  final DateTime? paymentDate;
  final String paymentMethod; // Virement bancaire, Chèque, Espèces
  final String? salaryJournal; // Opérations diverses, Banque, Espèces, etc.
  final DateTime? accountDate;
  final String? accountingEntry; // e.g. MISC/2024/10/001
  final bool establishPaymentOrder;
  final String? batchNumber;
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Payslip({
    required this.id,
    String? reference,
    this.payslipName,
    required this.employeeId,
    required this.employeeName,
    this.employeeCin,
    this.employeeCnss,
    this.employeeJobTitle,
    this.contractReference,
    this.salaryStructure = 'Standard',
    this.isCreditNote = false,
    required this.periodMonth,
    required this.periodYear,
    this.workedDays = 23.0,
    this.workedHours = 184.0,
    required this.baseSalary,
    this.primes = 0.0,
    this.transportAllowance = 0.0,
    double? grossSalary,
    double? cnssDeduction,
    this.taxDeduction = 0.0,
    this.cssDeduction = 0.0,
    this.advanceSalary = 0.0,
    this.loanDeduction = 0.0,
    this.indemnitiesTotal = 0.0,
    this.unpaidAbsenceDeduction = 0.0,
    this.unpaidAbsenceDays = 0.0,
    this.otherDeductions = 0.0,
    double? netSalary,
    this.overtimeHours,
    this.paymentStatus = 'draft',
    this.paymentDate,
    this.paymentMethod = 'Virement bancaire',
    this.salaryJournal = 'Opérations diverses',
    this.accountDate,
    this.accountingEntry,
    this.establishPaymentOrder = false,
    this.batchNumber,
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : reference = reference ?? 'SLIP/$periodYear/${periodMonth.toString().padLeft(2, '0')}/001',
        grossSalary = grossSalary ?? ((baseSalary - unpaidAbsenceDeduction) + primes + transportAllowance + indemnitiesTotal),
        cnssDeduction = cnssDeduction ?? (((baseSalary - unpaidAbsenceDeduction) + primes + transportAllowance + indemnitiesTotal) * 0.0918),
        netSalary = netSalary ??
            (((baseSalary - unpaidAbsenceDeduction) + primes + transportAllowance + indemnitiesTotal) -
                (cnssDeduction ?? (((baseSalary - unpaidAbsenceDeduction) + primes + transportAllowance + indemnitiesTotal) * 0.0918)) -
                taxDeduction -
                cssDeduction -
                advanceSalary -
                loanDeduction -
                otherDeductions),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get periodLabel {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final m = (periodMonth >= 1 && periodMonth <= 12) ? months[periodMonth - 1] : '$periodMonth';
    return '$m $periodYear';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'reference': reference,
        'payslip_name': payslipName,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'employee_cin': employeeCin,
        'employee_cnss': employeeCnss,
        'employee_job_title': employeeJobTitle,
        'contract_reference': contractReference,
        'salary_structure': salaryStructure,
        'is_credit_note': isCreditNote ? 1 : 0,
        'period_month': periodMonth,
        'period_year': periodYear,
        'worked_days': workedDays,
        'worked_hours': workedHours,
        'base_salary': baseSalary,
        'primes': primes,
        'transport_allowance': transportAllowance,
        'gross_salary': grossSalary,
        'cnss_deduction': cnssDeduction,
        'tax_deduction': taxDeduction,
        'css_deduction': cssDeduction,
        'advance_salary': advanceSalary,
        'loan_deduction': loanDeduction,
        'indemnities_total': indemnitiesTotal,
        'unpaid_absence_deduction': unpaidAbsenceDeduction,
        'unpaid_absence_days': unpaidAbsenceDays,
        'other_deductions': otherDeductions,
        'net_salary': netSalary,
        'overtime_hours': overtimeHours,
        'payment_status': paymentStatus,
        'payment_date': paymentDate?.toIso8601String(),
        'payment_method': paymentMethod,
        'salary_journal': salaryJournal,
        'account_date': accountDate?.toIso8601String(),
        'accounting_entry': accountingEntry,
        'establish_payment_order': establishPaymentOrder ? 1 : 0,
        'batch_number': batchNumber,
        'notes': notes,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Payslip.fromMap(Map<String, dynamic> map) => Payslip(
        id: map['id']?.toString() ?? '',
        reference: map['reference']?.toString(),
        payslipName: map['payslip_name']?.toString(),
        employeeId: (map['employee_id'] ?? map['employeeId'])?.toString() ?? '',
        employeeName: (map['employee_name'] ?? map['employeeName'])?.toString() ?? '',
        employeeCin: (map['employee_cin'] ?? map['employeeCin'])?.toString(),
        employeeCnss: (map['employee_cnss'] ?? map['employeeCnss'])?.toString(),
        employeeJobTitle: (map['employee_job_title'] ?? map['employeeJobTitle'])?.toString(),
        contractReference: (map['contract_reference'] ?? map['contractReference'])?.toString(),
        salaryStructure: map['salary_structure']?.toString() ?? 'Standard',
        isCreditNote: map['is_credit_note'] == 1 || map['is_credit_note'] == true,
        periodMonth: (map['period_month'] ?? map['periodMonth'] as num?)?.toInt() ?? DateTime.now().month,
        periodYear: (map['period_year'] ?? map['periodYear'] as num?)?.toInt() ?? DateTime.now().year,
        workedDays: (map['worked_days'] as num?)?.toDouble() ?? 23.0,
        workedHours: (map['worked_hours'] as num?)?.toDouble() ?? 184.0,
        baseSalary: (map['base_salary'] as num?)?.toDouble() ?? 0.0,
        primes: (map['primes'] as num?)?.toDouble() ?? 0.0,
        transportAllowance: (map['transport_allowance'] as num?)?.toDouble() ?? 0.0,
        grossSalary: (map['gross_salary'] as num?)?.toDouble(),
        cnssDeduction: (map['cnss_deduction'] as num?)?.toDouble(),
        taxDeduction: (map['tax_deduction'] as num?)?.toDouble() ?? 0.0,
        cssDeduction: (map['css_deduction'] as num?)?.toDouble() ?? 0.0,
        advanceSalary: (map['advance_salary'] as num?)?.toDouble() ?? 0.0,
        loanDeduction: (map['loan_deduction'] as num?)?.toDouble() ?? 0.0,
        indemnitiesTotal: (map['indemnities_total'] ?? map['indemnitiesTotal'] as num?)?.toDouble() ?? 0.0,
        unpaidAbsenceDeduction: (map['unpaid_absence_deduction'] ?? map['unpaidAbsenceDeduction'] as num?)?.toDouble() ?? 0.0,
        unpaidAbsenceDays: (map['unpaid_absence_days'] ?? map['unpaidAbsenceDays'] as num?)?.toDouble() ?? 0.0,
        otherDeductions: (map['other_deductions'] as num?)?.toDouble() ?? 0.0,
        netSalary: (map['net_salary'] as num?)?.toDouble(),
        overtimeHours: (map['overtime_hours'] as num?)?.toDouble(),
        paymentStatus: map['payment_status']?.toString() ?? 'draft',
        paymentDate: DateTime.tryParse(map['payment_date']?.toString() ?? ''),
        paymentMethod: map['payment_method']?.toString() ?? 'Virement bancaire',
        salaryJournal: map['salary_journal']?.toString() ?? 'Opérations diverses',
        accountDate: DateTime.tryParse(map['account_date']?.toString() ?? ''),
        accountingEntry: map['accounting_entry']?.toString(),
        establishPaymentOrder: map['establish_payment_order'] == 1 || map['establish_payment_order'] == true,
        batchNumber: map['batch_number']?.toString(),
        notes: map['notes']?.toString(),
        enterpriseId: (map['enterprise_id'] ?? map['enterpriseId'])?.toString(),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == true,
      );

  Payslip copyWith({
    String? id,
    String? reference,
    String? payslipName,
    String? employeeId,
    String? employeeName,
    String? employeeCin,
    String? employeeCnss,
    String? employeeJobTitle,
    String? contractReference,
    String? salaryStructure,
    bool? isCreditNote,
    int? periodMonth,
    int? periodYear,
    double? workedDays,
    double? workedHours,
    double? baseSalary,
    double? primes,
    double? transportAllowance,
    double? grossSalary,
    double? cnssDeduction,
    double? taxDeduction,
    double? cssDeduction,
    double? advanceSalary,
    double? loanDeduction,
    double? indemnitiesTotal,
    double? unpaidAbsenceDeduction,
    double? unpaidAbsenceDays,
    double? otherDeductions,
    double? netSalary,
    double? overtimeHours,
    String? paymentStatus,
    DateTime? paymentDate,
    String? paymentMethod,
    String? salaryJournal,
    DateTime? accountDate,
    String? accountingEntry,
    bool? establishPaymentOrder,
    String? batchNumber,
    String? notes,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      Payslip(
        id: id ?? this.id,
        reference: reference ?? this.reference,
        payslipName: payslipName ?? this.payslipName,
        employeeId: employeeId ?? this.employeeId,
        employeeName: employeeName ?? this.employeeName,
        employeeCin: employeeCin ?? this.employeeCin,
        employeeCnss: employeeCnss ?? this.employeeCnss,
        employeeJobTitle: employeeJobTitle ?? this.employeeJobTitle,
        contractReference: contractReference ?? this.contractReference,
        salaryStructure: salaryStructure ?? this.salaryStructure,
        isCreditNote: isCreditNote ?? this.isCreditNote,
        periodMonth: periodMonth ?? this.periodMonth,
        periodYear: periodYear ?? this.periodYear,
        workedDays: workedDays ?? this.workedDays,
        workedHours: workedHours ?? this.workedHours,
        baseSalary: baseSalary ?? this.baseSalary,
        primes: primes ?? this.primes,
        transportAllowance: transportAllowance ?? this.transportAllowance,
        grossSalary: grossSalary ?? this.grossSalary,
        cnssDeduction: cnssDeduction ?? this.cnssDeduction,
        taxDeduction: taxDeduction ?? this.taxDeduction,
        cssDeduction: cssDeduction ?? this.cssDeduction,
        advanceSalary: advanceSalary ?? this.advanceSalary,
        loanDeduction: loanDeduction ?? this.loanDeduction,
        indemnitiesTotal: indemnitiesTotal ?? this.indemnitiesTotal,
        unpaidAbsenceDeduction: unpaidAbsenceDeduction ?? this.unpaidAbsenceDeduction,
        unpaidAbsenceDays: unpaidAbsenceDays ?? this.unpaidAbsenceDays,
        otherDeductions: otherDeductions ?? this.otherDeductions,
        netSalary: netSalary ?? this.netSalary,
        overtimeHours: overtimeHours ?? this.overtimeHours,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        paymentDate: paymentDate ?? this.paymentDate,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        salaryJournal: salaryJournal ?? this.salaryJournal,
        accountDate: accountDate ?? this.accountDate,
        accountingEntry: accountingEntry ?? this.accountingEntry,
        establishPaymentOrder: establishPaymentOrder ?? this.establishPaymentOrder,
        batchNumber: batchNumber ?? this.batchNumber,
        notes: notes ?? this.notes,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
