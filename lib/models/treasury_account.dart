import 'package:uuid/uuid.dart';

class TreasuryAccount {
  final String id;
  final String name;
  final String? internalName;
  final String type; // 'cash' or 'bank'
  final String? bankName;
  final String? agency;
  final String? iban;
  final String currency;
  final double balance;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  TreasuryAccount({
    String? id,
    required this.name,
    this.internalName,
    required this.type,
    this.bankName,
    this.agency,
    this.iban,
    this.currency = 'TND',
    this.balance = 0.0,
    this.isDefault = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  TreasuryAccount copyWith({
    String? id,
    String? name,
    String? internalName,
    String? type,
    String? bankName,
    String? agency,
    String? iban,
    String? currency,
    double? balance,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TreasuryAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      internalName: internalName ?? this.internalName,
      type: type ?? this.type,
      bankName: bankName ?? this.bankName,
      agency: agency ?? this.agency,
      iban: iban ?? this.iban,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'internal_name': internalName,
      'type': type,
      'bank_name': bankName,
      'agency': agency,
      'iban': iban,
      'currency': currency,
      'balance': balance,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory TreasuryAccount.fromMap(Map<String, dynamic> map) {
    return TreasuryAccount(
      id: map['id'],
      name: map['name'],
      internalName: map['internal_name'],
      type: map['type'],
      bankName: map['bank_name'],
      agency: map['agency'],
      iban: map['iban'],
      currency: map['currency'] ?? 'TND',
      balance: map['balance']?.toDouble() ?? 0.0,
      isDefault: map['is_default'] == 1,
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['updated_at']) : DateTime.now(),
    );
  }
}
