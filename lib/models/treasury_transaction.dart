import 'package:uuid/uuid.dart';

class TreasuryTransaction {
  final String id;
  final String transactionNumber;
  final String accountId;
  final String type; // 'income' or 'expense'
  final double amount;
  final String? category; // 'salaries', 'taxes', 'rent', 'other' or custom
  final DateTime dateTransaction;
  final String? description;
  final String? projectId;
  final double withholdingTax;
  final double withholdingTaxRate;
  final String? paymentId; // Linked to the payments module
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? balance;

  // Extracted fields (not saved in DB for this table, but used in joins)
  final String? accountName;
  final String? projectName;

  TreasuryTransaction({
    String? id,
    required this.transactionNumber,
    required this.accountId,
    required this.type,
    required this.amount,
    this.category,
    required this.dateTransaction,
    this.description,
    this.projectId,
    this.withholdingTax = 0.0,
    this.withholdingTaxRate = 0.0,
    this.paymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.accountName,
    this.projectName,
    this.balance,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  TreasuryTransaction copyWith({
    String? id,
    String? transactionNumber,
    String? accountId,
    String? type,
    double? amount,
    String? category,
    DateTime? dateTransaction,
    String? description,
    String? projectId,
    double? withholdingTax,
    double? withholdingTaxRate,
    String? paymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? accountName,
    String? projectName,
    double? balance,
  }) {
    return TreasuryTransaction(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dateTransaction: dateTransaction ?? this.dateTransaction,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      withholdingTax: withholdingTax ?? this.withholdingTax,
      withholdingTaxRate: withholdingTaxRate ?? this.withholdingTaxRate,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accountName: accountName ?? this.accountName,
      projectName: projectName ?? this.projectName,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_number': transactionNumber,
      'account_id': accountId,
      'type': type,
      'amount': amount,
      'category': category,
      'date_transaction': dateTransaction.millisecondsSinceEpoch,
      'description': description,
      'project_id': projectId,
      'withholding_tax': withholdingTax,
      'withholding_tax_rate': withholdingTaxRate,
      'payment_id': paymentId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory TreasuryTransaction.fromMap(Map<String, dynamic> map) {
    return TreasuryTransaction(
      id: map['id'],
      transactionNumber: map['transaction_number'],
      accountId: map['account_id'],
      type: map['type'],
      amount: map['amount']?.toDouble() ?? 0.0,
      category: map['category'],
      dateTransaction: DateTime.fromMillisecondsSinceEpoch(map['date_transaction']),
      description: map['description'],
      projectId: map['project_id'],
      withholdingTax: map['withholding_tax']?.toDouble() ?? 0.0,
      withholdingTaxRate: map['withholding_tax_rate']?.toDouble() ?? 0.0,
      paymentId: map['payment_id'],
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['updated_at']) : DateTime.now(),
      accountName: map['account_name'],
      projectName: map['project_name'],
    );
  }
}
