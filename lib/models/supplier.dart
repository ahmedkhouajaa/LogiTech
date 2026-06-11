class Supplier {
  final String id;
  final String code;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? taxId;
  final String? rc;
  final double balance;
  final String? notes;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    required this.id,
    required this.code,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.taxId,
    this.rc,
    this.balance = 0,
    this.notes,
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'tax_id': taxId,
        'rc': rc,
        'balance': balance,
        'notes': notes,
        'firebase_uid': firebaseUid,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        city: map['city'] as String?,
        taxId: map['tax_id'] as String?,
        rc: map['rc'] as String?,
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Supplier copyWith({
    String? id, String? code, String? name, String? email,
    String? phone, String? address, String? city, String? taxId,
    String? rc, double? balance, String? notes, String? firebaseUid,
    bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => Supplier(
        id: id ?? this.id, code: code ?? this.code, name: name ?? this.name,
        email: email ?? this.email, phone: phone ?? this.phone,
        address: address ?? this.address, city: city ?? this.city,
        taxId: taxId ?? this.taxId, rc: rc ?? this.rc,
        balance: balance ?? this.balance, notes: notes ?? this.notes,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}
