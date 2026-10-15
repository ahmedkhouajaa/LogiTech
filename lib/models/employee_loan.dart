class LoanRepayment {
  final String id;
  final String loanId;
  final String? payslipId;
  final String? payslipReference; // e.g. SLIP/2024/10/001
  final DateTime date;
  final double amount;
  final String status; // 'draft' (Brouillon), 'confirmed' (Confirmé), 'paid' (Payé)
  final String? notes;

  LoanRepayment({
    required this.id,
    required this.loanId,
    this.payslipId,
    this.payslipReference,
    required this.date,
    required this.amount,
    this.status = 'draft',
    this.notes,
  });

  bool get isPaid => status == 'paid' || status == 'Payé';
  bool get isDraft => status == 'draft' || status == 'Brouillon';

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'payé':
        return 'Payé';
      case 'confirmed':
      case 'confirmé':
        return 'Confirmé';
      default:
        return 'Brouillon';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'loan_id': loanId,
        'payslip_id': payslipId,
        'payslip_reference': payslipReference,
        'date': date.toIso8601String(),
        'amount': amount,
        'status': status,
        'notes': notes,
      };

  factory LoanRepayment.fromMap(Map<String, dynamic> map) => LoanRepayment(
        id: map['id']?.toString() ?? '',
        loanId: (map['loan_id'] ?? map['loanId'])?.toString() ?? '',
        payslipId: (map['payslip_id'] ?? map['payslipId'])?.toString(),
        payslipReference: (map['payslip_reference'] ?? map['payslipReference'])?.toString(),
        date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        status: map['status']?.toString() ?? 'draft',
        notes: map['notes']?.toString(),
      );

  LoanRepayment copyWith({
    String? id,
    String? loanId,
    String? payslipId,
    String? payslipReference,
    DateTime? date,
    double? amount,
    String? status,
    String? notes,
  }) =>
      LoanRepayment(
        id: id ?? this.id,
        loanId: loanId ?? this.loanId,
        payslipId: payslipId ?? this.payslipId,
        payslipReference: payslipReference ?? this.payslipReference,
        date: date ?? this.date,
        amount: amount ?? this.amount,
        status: status ?? this.status,
        notes: notes ?? this.notes,
      );
}

class EmployeeLoan {
  final String id;
  final String reference; // e.g. LOAN/2024/001
  final String name; // e.g. "prêt aid kbir", "prêt aid sghir", "pret de test"
  final String employeeId;
  final String employeeName;
  final double amount; // Montant total (ex: 1500.00)
  final double monthlyAmount; // Montant mensuel (ex: 150.00)
  final bool isCompanyCredit; // Company Credit
  final DateTime date; // Date de début
  final int monthsCount; // Nombre de mois (ex: 10)
  final double remainingAmount; // Reste à rembourser
  final String status; // 'draft', 'confirmed', 'paid', 'cancelled'
  final List<LoanRepayment> repayments;
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  EmployeeLoan({
    required this.id,
    String? reference,
    required this.name,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    double? monthlyAmount,
    this.isCompanyCredit = false,
    DateTime? date,
    int? monthsCount,
    double? remainingAmount,
    this.status = 'draft',
    List<LoanRepayment>? repayments,
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : reference = reference ?? 'LOAN/${(date ?? DateTime.now()).year}/001',
        date = date ?? DateTime.now(),
        monthsCount = monthsCount ?? 1,
        monthlyAmount = monthlyAmount ?? (monthsCount != null && monthsCount > 0 ? (amount / monthsCount) : amount),
        remainingAmount = remainingAmount ?? amount,
        repayments = repayments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'confirmé':
        return 'Confirmé';
      case 'paid':
      case 'payé':
        return 'Payé';
      case 'cancelled':
      case 'annulé':
        return 'Annulé';
      default:
        return 'Brouillon';
    }
  }

  double get totalRepaid {
    double total = 0.0;
    for (final r in repayments) {
      if (r.isPaid) {
        total += r.amount;
      }
    }
    return total;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'reference': reference,
        'name': name,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'amount': amount,
        'monthly_amount': monthlyAmount,
        'is_company_credit': isCompanyCredit ? 1 : 0,
        'date': date.toIso8601String(),
        'months_count': monthsCount,
        'remaining_amount': remainingAmount,
        'status': status,
        'repayments': repayments.map((r) => r.toMap()).toList(),
        'notes': notes,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory EmployeeLoan.fromMap(Map<String, dynamic> map) {
    final rawRepayments = map['repayments'];
    final repaymentsList = <LoanRepayment>[];
    if (rawRepayments is List) {
      for (final r in rawRepayments) {
        if (r is Map) {
          repaymentsList.add(LoanRepayment.fromMap(Map<String, dynamic>.from(r)));
        }
      }
    }

    final double amt = (map['amount'] as num?)?.toDouble() ?? 0.0;
    final int months = (map['months_count'] ?? map['monthsCount'] as num?)?.toInt() ?? 1;
    final double monthlyAmt = (map['monthly_amount'] ?? map['monthlyAmount'] as num?)?.toDouble() ?? (months > 0 ? amt / months : amt);
    final double remAmt = (map['remaining_amount'] ?? map['remainingAmount'] as num?)?.toDouble() ?? amt;

    return EmployeeLoan(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString(),
      name: map['name']?.toString() ?? 'Prêt sans nom',
      employeeId: (map['employee_id'] ?? map['employeeId'])?.toString() ?? '',
      employeeName: (map['employee_name'] ?? map['employeeName'])?.toString() ?? '',
      amount: amt,
      monthlyAmount: monthlyAmt,
      isCompanyCredit: map['is_company_credit'] == 1 || map['is_company_credit'] == true || map['isCompanyCredit'] == true,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      monthsCount: months,
      remainingAmount: remAmt,
      status: map['status']?.toString() ?? 'draft',
      repayments: repaymentsList,
      notes: map['notes']?.toString(),
      enterpriseId: (map['enterprise_id'] ?? map['enterpriseId'])?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == true,
    );
  }

  EmployeeLoan copyWith({
    String? id,
    String? reference,
    String? name,
    String? employeeId,
    String? employeeName,
    double? amount,
    double? monthlyAmount,
    bool? isCompanyCredit,
    DateTime? date,
    int? monthsCount,
    double? remainingAmount,
    String? status,
    List<LoanRepayment>? repayments,
    String? notes,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      EmployeeLoan(
        id: id ?? this.id,
        reference: reference ?? this.reference,
        name: name ?? this.name,
        employeeId: employeeId ?? this.employeeId,
        employeeName: employeeName ?? this.employeeName,
        amount: amount ?? this.amount,
        monthlyAmount: monthlyAmount ?? this.monthlyAmount,
        isCompanyCredit: isCompanyCredit ?? this.isCompanyCredit,
        date: date ?? this.date,
        monthsCount: monthsCount ?? this.monthsCount,
        remainingAmount: remainingAmount ?? this.remainingAmount,
        status: status ?? this.status,
        repayments: repayments ?? this.repayments,
        notes: notes ?? this.notes,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
