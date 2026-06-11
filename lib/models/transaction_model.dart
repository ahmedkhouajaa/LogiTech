import '../utils/constants.dart';

class TransactionModel {
  final String id;
  final String accountId;
  final String? accountName;
  final TransactionType type;
  final String? category;
  final double amount;
  final DateTime date;
  final String? reference;
  final String? description;
  final String? relatedInvoiceId;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    required this.id, required this.accountId, this.accountName,
    required this.type, this.category, required this.amount,
    required this.date, this.reference, this.description,
    this.relatedInvoiceId, this.firebaseUid, this.isDeleted = false,
    DateTime? createdAt, DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'account_id': accountId, 'type': type.name,
        'category': category, 'amount': amount,
        'date': date.toIso8601String(), 'reference': reference,
        'description': description, 'related_invoice_id': relatedInvoiceId,
        'firebase_uid': firebaseUid, 'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'] as String, accountId: map['account_id'] as String,
        accountName: map['account_name'] as String?,
        type: TransactionType.values.firstWhere(
          (e) => e.name == map['type'], orElse: () => TransactionType.income),
        category: map['category'] as String?,
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.parse(map['date'] as String),
        reference: map['reference'] as String?,
        description: map['description'] as String?,
        relatedInvoiceId: map['related_invoice_id'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  TransactionModel copyWith({
    String? id, String? accountId, String? accountName, TransactionType? type,
    String? category, double? amount, DateTime? date, String? reference,
    String? description, String? relatedInvoiceId, String? firebaseUid,
    bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => TransactionModel(
        id: id ?? this.id, accountId: accountId ?? this.accountId,
        accountName: accountName ?? this.accountName, type: type ?? this.type,
        category: category ?? this.category, amount: amount ?? this.amount,
        date: date ?? this.date, reference: reference ?? this.reference,
        description: description ?? this.description,
        relatedInvoiceId: relatedInvoiceId ?? this.relatedInvoiceId,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Account {
  final String id;
  final String name;
  final String type; // bank, cash, other
  final String? bankName;
  final String? accountNumber;
  final double balance;
  final bool isDefault;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id, required this.name, this.type = 'cash',
    this.bankName, this.accountNumber, this.balance = 0,
    this.isDefault = false, this.firebaseUid, this.isDeleted = false,
    DateTime? createdAt, DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'type': type, 'bank_name': bankName,
        'account_number': accountNumber, 'balance': balance,
        'is_default': isDefault ? 1 : 0, 'firebase_uid': firebaseUid,
        'is_deleted': isDeleted ? 1 : 0, 'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as String, name: map['name'] as String,
        type: map['type'] as String? ?? 'cash',
        bankName: map['bank_name'] as String?,
        accountNumber: map['account_number'] as String?,
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        isDefault: map['is_default'] == 1,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Account copyWith({
    String? id, String? name, String? type, String? bankName,
    String? accountNumber, double? balance, bool? isDefault,
    String? firebaseUid, bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => Account(
        id: id ?? this.id, name: name ?? this.name, type: type ?? this.type,
        bankName: bankName ?? this.bankName,
        accountNumber: accountNumber ?? this.accountNumber,
        balance: balance ?? this.balance, isDefault: isDefault ?? this.isDefault,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}
