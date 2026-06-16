import 'package:uuid/uuid.dart';

class CheckTraite {
  final String id;
  final String documentNumber;
  final String type; // 'check_received', 'check_issued', 'traite_received', 'traite_issued'
  final double amount;
  final String partyName; // customer or supplier name
  final String? partyId; // customer_id or supplier_id
  final String? bankName;
  final String? bankAccount;
  final DateTime issueDate;
  final DateTime maturityDate;
  final String status; // 'pending', 'cashed', 'bounced', 'cancelled'
  final String? paymentId; // link to payment when cashed
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get daysUntilMaturity {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maturity = DateTime(maturityDate.year, maturityDate.month, maturityDate.day);
    return maturity.difference(today).inDays;
  }

  CheckTraite({
    String? id,
    required this.documentNumber,
    required this.type,
    required this.amount,
    required this.partyName,
    this.partyId,
    this.bankName,
    this.bankAccount,
    required this.issueDate,
    required this.maturityDate,
    this.status = 'pending',
    this.paymentId,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  CheckTraite copyWith({
    String? id,
    String? documentNumber,
    String? type,
    double? amount,
    String? partyName,
    String? partyId,
    String? bankName,
    String? bankAccount,
    DateTime? issueDate,
    DateTime? maturityDate,
    String? status,
    String? paymentId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheckTraite(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      partyName: partyName ?? this.partyName,
      partyId: partyId ?? this.partyId,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      issueDate: issueDate ?? this.issueDate,
      maturityDate: maturityDate ?? this.maturityDate,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_number': documentNumber,
      'type': type,
      'amount': amount,
      'party_name': partyName,
      'party_id': partyId,
      'bank_name': bankName,
      'bank_account': bankAccount,
      'issue_date': issueDate.millisecondsSinceEpoch,
      'maturity_date': maturityDate.millisecondsSinceEpoch,
      'status': status,
      'payment_id': paymentId,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CheckTraite.fromMap(Map<String, dynamic> map) {
    return CheckTraite(
      id: map['id'],
      documentNumber: map['document_number'],
      type: map['type'],
      amount: map['amount']?.toDouble() ?? 0.0,
      partyName: map['party_name'],
      partyId: map['party_id'],
      bankName: map['bank_name'],
      bankAccount: map['bank_account'],
      issueDate: DateTime.fromMillisecondsSinceEpoch(map['issue_date']),
      maturityDate: DateTime.fromMillisecondsSinceEpoch(map['maturity_date']),
      status: map['status'] ?? 'pending',
      paymentId: map['payment_id'],
      notes: map['notes'],
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['updated_at']) : DateTime.now(),
    );
  }
}
