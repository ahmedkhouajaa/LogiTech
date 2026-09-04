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
  final bool isDefault;

  final String? enterpriseId;

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
    this.enterpriseId,
    this.isDeleted = false,
    this.isDefault = false,
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
        'enterprise_id': enterpriseId,
        'is_deleted': isDeleted ? 1 : 0,
        'is_default': isDefault ? 1 : 0,
        'isDefault': isDefault,
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
        id: map['id']?.toString() ?? '',
        code: map['code']?.toString() ?? (map['supplierCode']?.toString() ?? ''),
        name: map['name']?.toString() ?? '',
        email: map['email']?.toString(),
        phone: map['phone']?.toString(),
        address: map['address']?.toString(),
        city: map['city']?.toString(),
        taxId: (map['tax_id'] ?? map['taxId'])?.toString(),
        rc: map['rc']?.toString(),
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        notes: map['notes']?.toString(),
        firebaseUid: (map['firebase_uid'] ?? (map['firebaseUid'] ?? map['userId']))?.toString(),
        enterpriseId: (map['enterprise_id'] ?? map['enterpriseId'])?.toString(),
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == 1 || map['isDeleted'] == true,
        isDefault: map['is_default'] == 1 || map['is_default'] == true || map['isDefault'] == true || (map['name']?.toString().trim().toLowerCase() == 'fournisseur passager'),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? (map['createdAt']?.toString() ?? '')) ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? (map['updatedAt']?.toString() ?? '')) ?? DateTime.now(),
        postalCode: (map['postal_code'] ?? map['postalCode'])?.toString(),
        country: map['country']?.toString() ?? 'Tunisia',
        deliveryStreet: (map['delivery_street'] ?? map['deliveryStreet'])?.toString(),
        deliveryCity: (map['delivery_city'] ?? map['deliveryCity'])?.toString(),
        deliveryPostalCode: (map['delivery_postal_code'] ?? map['deliveryPostalCode'])?.toString(),
        deliveryCountry: (map['delivery_country'] ?? map['deliveryCountry'])?.toString() ?? 'Tunisia',
        deliverySameAsBilling: map['delivery_same_as_billing'] == 1 || map['deliverySameAsBilling'] == 1 || map['delivery_same_as_billing'] == null,
        bankAccount: (map['bank_account'] ?? map['bankAccount'])?.toString(),
        supplierType: map['supplier_type']?.toString() ?? (map['supplierType']?.toString() ?? (map['type']?.toString() ?? 'entreprise')),
        companyName: (map['company_name'] ?? map['companyName'])?.toString(),
        responsibleName: (map['responsible_name'] ?? map['responsibleName'])?.toString(),
        cinNumber: (map['cin_number'] ?? map['cinNumber'])?.toString(),
        birthDate: (map['birth_date'] ?? map['birthDate'])?.toString(),
        referenceCode: (map['reference_code'] ?? map['referenceCode'])?.toString(),
      );

  Supplier copyWith({
    String? id, String? code, String? name, String? email,
    String? phone, String? address, String? city, String? taxId,
    String? rc, double? balance, String? notes, String? firebaseUid,
    String? enterpriseId,
    bool? isDeleted, bool? isDefault, DateTime? createdAt, DateTime? updatedAt,
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
        enterpriseId: enterpriseId ?? this.enterpriseId,
        isDeleted: isDeleted ?? this.isDeleted,
        isDefault: isDefault ?? this.isDefault,
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
