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

  // New Fields
  final String? postalCode;
  final String country;
  final String? deliveryStreet;
  final String? deliveryCity;
  final String? deliveryPostalCode;
  final String deliveryCountry;
  final bool deliverySameAsBilling;
  final String? bankAccount;
  final String supplierType;
  final String? companyName;
  final String? responsibleName;
  final String? cinNumber;
  final String? birthDate;
  final String? referenceCode;

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
    this.postalCode,
    this.country = 'Tunisia',
    this.deliveryStreet,
    this.deliveryCity,
    this.deliveryPostalCode,
    this.deliveryCountry = 'Tunisia',
    this.deliverySameAsBilling = true,
    this.bankAccount,
    this.supplierType = 'entreprise',
    this.companyName,
    this.responsibleName,
    this.cinNumber,
    this.birthDate,
    this.referenceCode,
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
        'postal_code': postalCode,
        'country': country,
        'delivery_street': deliveryStreet,
        'delivery_city': deliveryCity,
        'delivery_postal_code': deliveryPostalCode,
        'delivery_country': deliveryCountry,
        'delivery_same_as_billing': deliverySameAsBilling ? 1 : 0,
        'bank_account': bankAccount,
        'supplier_type': supplierType,
        'company_name': companyName,
        'responsible_name': responsibleName,
        'cin_number': cinNumber,
        'birth_date': birthDate,
        'reference_code': referenceCode,
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
        postalCode: map['postal_code'] as String?,
        country: map['country'] as String? ?? 'Tunisia',
        deliveryStreet: map['delivery_street'] as String?,
        deliveryCity: map['delivery_city'] as String?,
        deliveryPostalCode: map['delivery_postal_code'] as String?,
        deliveryCountry: map['delivery_country'] as String? ?? 'Tunisia',
        deliverySameAsBilling: map['delivery_same_as_billing'] == 1 || map['delivery_same_as_billing'] == null,
        bankAccount: map['bank_account'] as String?,
        supplierType: map['supplier_type'] as String? ?? 'entreprise',
        companyName: map['company_name'] as String?,
        responsibleName: map['responsible_name'] as String?,
        cinNumber: map['cin_number'] as String?,
        birthDate: map['birth_date'] as String?,
        referenceCode: map['reference_code'] as String?,
      );

  Supplier copyWith({
    String? id, String? code, String? name, String? email,
    String? phone, String? address, String? city, String? taxId,
    String? rc, double? balance, String? notes, String? firebaseUid,
    bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
    String? postalCode, String? country, String? deliveryStreet,
    String? deliveryCity, String? deliveryPostalCode, String? deliveryCountry,
    bool? deliverySameAsBilling, String? bankAccount,
    String? supplierType, String? companyName, String? responsibleName,
    String? cinNumber, String? birthDate, String? referenceCode,
  }) => Supplier(
        id: id ?? this.id, code: code ?? this.code, name: name ?? this.name,
        email: email ?? this.email, phone: phone ?? this.phone,
        address: address ?? this.address, city: city ?? this.city,
        taxId: taxId ?? this.taxId, rc: rc ?? this.rc,
        balance: balance ?? this.balance, notes: notes ?? this.notes,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
        postalCode: postalCode ?? this.postalCode,
        country: country ?? this.country,
        deliveryStreet: deliveryStreet ?? this.deliveryStreet,
        deliveryCity: deliveryCity ?? this.deliveryCity,
        deliveryPostalCode: deliveryPostalCode ?? this.deliveryPostalCode,
        deliveryCountry: deliveryCountry ?? this.deliveryCountry,
        deliverySameAsBilling: deliverySameAsBilling ?? this.deliverySameAsBilling,
        bankAccount: bankAccount ?? this.bankAccount,
        supplierType: supplierType ?? this.supplierType,
        companyName: companyName ?? this.companyName,
        responsibleName: responsibleName ?? this.responsibleName,
        cinNumber: cinNumber ?? this.cinNumber,
        birthDate: birthDate ?? this.birthDate,
        referenceCode: referenceCode ?? this.referenceCode,
      );
}
