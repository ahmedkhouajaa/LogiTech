import '../utils/constants.dart';

class CheckTraite {
  final String id;
  final CheckTraiteType type;
  final String number;
  final double amount;
  final DateTime dateIssued;
  final DateTime maturityDate;
  final CheckTraiteStatus status;
  final String partyName;
  final String? accountId;
  final String? bankName;
  final String? notes;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  CheckTraite({
    required this.id, required this.type, required this.number,
    required this.amount, required this.dateIssued, required this.maturityDate,
    this.status = CheckTraiteStatus.pending, required this.partyName,
    this.accountId, this.bankName, this.notes, this.firebaseUid,
    this.isDeleted = false, DateTime? createdAt, DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isMatured => maturityDate.isBefore(DateTime.now());
  int get daysUntilMaturity => maturityDate.difference(DateTime.now()).inDays;

  Map<String, dynamic> toMap() => {
        'id': id, 'type': type.name, 'number': number, 'amount': amount,
        'date_issued': dateIssued.toIso8601String(),
        'maturity_date': maturityDate.toIso8601String(),
        'status': status.name, 'party_name': partyName,
        'account_id': accountId, 'bank_name': bankName, 'notes': notes,
        'firebase_uid': firebaseUid, 'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CheckTraite.fromMap(Map<String, dynamic> map) => CheckTraite(
        id: map['id'] as String,
        type: CheckTraiteType.values.firstWhere(
          (e) => e.name == map['type'], orElse: () => CheckTraiteType.checkReceived),
        number: map['number'] as String,
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        dateIssued: DateTime.parse(map['date_issued'] as String),
        maturityDate: DateTime.parse(map['maturity_date'] as String),
        status: CheckTraiteStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => CheckTraiteStatus.pending),
        partyName: map['party_name'] as String? ?? '',
        accountId: map['account_id'] as String?,
        bankName: map['bank_name'] as String?,
        notes: map['notes'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  CheckTraite copyWith({
    String? id, CheckTraiteType? type, String? number, double? amount,
    DateTime? dateIssued, DateTime? maturityDate, CheckTraiteStatus? status,
    String? partyName, String? accountId, String? bankName, String? notes,
    String? firebaseUid, bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => CheckTraite(
        id: id ?? this.id, type: type ?? this.type, number: number ?? this.number,
        amount: amount ?? this.amount, dateIssued: dateIssued ?? this.dateIssued,
        maturityDate: maturityDate ?? this.maturityDate, status: status ?? this.status,
        partyName: partyName ?? this.partyName, accountId: accountId ?? this.accountId,
        bankName: bankName ?? this.bankName, notes: notes ?? this.notes,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}
