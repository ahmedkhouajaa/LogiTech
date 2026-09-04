class Customer {
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
  final double creditLimit;
  final String? notes;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New Fields
  final String customerType;
  final String? companyName;
  final String? responsibleName;
  final String? cinNumber;
  final String? birthDate;
  final String? referenceCode;
  final String? streetAddress;
  final String? postalCode;
  final String country;
  final String? deliveryStreet;
  final String? deliveryCity;
  final String? deliveryPostalCode;
  final String deliveryCountry;
  final bool deliverySameAsBilling;
  final String? bankAccount;
  final bool tvaSuspension;
  final String? tvaAttestation;
  final String? tvaStartDate;
  final String? tvaEndDate;
  final String priceList;
  final String? privateNote;
  final bool isDefault;

  final String? enterpriseId;

  Customer({
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
    this.creditLimit = 0,
    this.notes,
    this.firebaseUid,
    this.enterpriseId,
    this.isDeleted = false,
    this.isDefault = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.customerType = 'entreprise',
    this.companyName,
    this.responsibleName,
    this.cinNumber,
    this.birthDate,
    this.referenceCode,
    this.streetAddress,
    this.postalCode,
    this.country = 'Tunisia',
    this.deliveryStreet,
    this.deliveryCity,
    this.deliveryPostalCode,
    this.deliveryCountry = 'Tunisia',
    this.deliverySameAsBilling = true,
    this.bankAccount,
    this.tvaSuspension = false,
    this.tvaAttestation,
    this.tvaStartDate,
    this.tvaEndDate,
    this.priceList = 'default',
    this.privateNote,
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
        'credit_limit': creditLimit,
        'notes': notes,
        'firebase_uid': firebaseUid,
        'enterprise_id': enterpriseId,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'customer_type': customerType,
        'company_name': companyName,
        'responsible_name': responsibleName,
        'cin_number': cinNumber,
        'birth_date': birthDate,
        'reference_code': referenceCode,
        'street_address': streetAddress,
        'postal_code': postalCode,
        'country': country,
        'delivery_street': deliveryStreet,
        'delivery_city': deliveryCity,
        'delivery_postal_code': deliveryPostalCode,
        'delivery_country': deliveryCountry,
        'delivery_same_as_billing': deliverySameAsBilling ? 1 : 0,
        'bank_account': bankAccount,
        'tva_suspension': tvaSuspension ? 1 : 0,
        'tva_attestation': tvaAttestation,
        'tva_start_date': tvaStartDate,
        'tva_end_date': tvaEndDate,
        'price_list': priceList,
        'private_note': privateNote,
        'is_default': isDefault ? 1 : 0,
        'isDefault': isDefault,
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id']?.toString() ?? '',
        code: map['code']?.toString() ?? (map['clientCode']?.toString() ?? ''),
        name: map['name']?.toString() ?? '',
        email: map['email']?.toString(),
        phone: map['phone']?.toString(),
        address: map['address']?.toString(),
        city: map['city']?.toString(),
        taxId: (map['tax_id'] ?? map['taxId'])?.toString(),
        rc: map['rc']?.toString(),
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        creditLimit: ((map['credit_limit'] ?? map['creditLimit']) as num?)?.toDouble() ?? 0,
        notes: map['notes']?.toString(),
        firebaseUid: (map['firebase_uid'] ?? (map['firebaseUid'] ?? map['userId']))?.toString(),
        enterpriseId: (map['enterprise_id'] ?? map['enterpriseId'])?.toString(),
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == 1 || map['isDeleted'] == true,
        isDefault: map['is_default'] == 1 || map['is_default'] == true || map['isDefault'] == true || (map['name']?.toString().trim().toLowerCase() == 'client passager'),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? (map['createdAt']?.toString() ?? '')) ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? (map['updatedAt']?.toString() ?? '')) ?? DateTime.now(),
        customerType: map['customer_type']?.toString() ?? (map['customerType']?.toString() ?? (map['type']?.toString() ?? 'entreprise')),
        companyName: (map['company_name'] ?? map['companyName'])?.toString(),
        responsibleName: (map['responsible_name'] ?? map['responsibleName'])?.toString(),
        cinNumber: (map['cin_number'] ?? map['cinNumber'])?.toString(),
        birthDate: (map['birth_date'] ?? map['birthDate'])?.toString(),
        referenceCode: (map['reference_code'] ?? map['referenceCode'])?.toString(),
        streetAddress: (map['street_address'] ?? map['streetAddress'])?.toString(),
        postalCode: (map['postal_code'] ?? map['postalCode'])?.toString(),
        country: map['country']?.toString() ?? 'Tunisia',
        deliveryStreet: (map['delivery_street'] ?? map['deliveryStreet'])?.toString(),
        deliveryCity: (map['delivery_city'] ?? map['deliveryCity'])?.toString(),
        deliveryPostalCode: (map['delivery_postal_code'] ?? map['deliveryPostalCode'])?.toString(),
        deliveryCountry: (map['delivery_country'] ?? map['deliveryCountry'])?.toString() ?? 'Tunisia',
        deliverySameAsBilling: map['delivery_same_as_billing'] == 1 || map['deliverySameAsBilling'] == 1 || map['delivery_same_as_billing'] == null,
        bankAccount: (map['bank_account'] ?? map['bankAccount'])?.toString(),
        tvaSuspension: map['tva_suspension'] == 1 || map['tvaSuspension'] == 1,
        tvaAttestation: (map['tva_attestation'] ?? map['tvaAttestation'])?.toString(),
        tvaStartDate: (map['tva_start_date'] ?? map['tvaStartDate'])?.toString(),
        tvaEndDate: (map['tva_end_date'] ?? map['tvaEndDate'])?.toString(),
        priceList: (map['price_list'] ?? map['priceList'])?.toString() ?? 'default',
        privateNote: (map['private_note'] ?? map['privateNote'])?.toString(),
      );

  Customer copyWith({
    String? id,
    String? code,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? taxId,
    String? rc,
    double? balance,
    double? creditLimit,
    String? notes,
    String? firebaseUid,
    String? enterpriseId,
    bool? isDeleted,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerType,
    String? companyName,
    String? responsibleName,
    String? cinNumber,
    String? birthDate,
    String? referenceCode,
    String? streetAddress,
    String? postalCode,
    String? country,
    String? deliveryStreet,
    String? deliveryCity,
    String? deliveryPostalCode,
    String? deliveryCountry,
    bool? deliverySameAsBilling,
    String? bankAccount,
    bool? tvaSuspension,
    String? tvaAttestation,
    String? tvaStartDate,
    String? tvaEndDate,
    String? priceList,
    String? privateNote,
  }) =>
      Customer(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        city: city ?? this.city,
        taxId: taxId ?? this.taxId,
        rc: rc ?? this.rc,
        balance: balance ?? this.balance,
        creditLimit: creditLimit ?? this.creditLimit,
        notes: notes ?? this.notes,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        isDeleted: isDeleted ?? this.isDeleted,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        customerType: customerType ?? this.customerType,
        companyName: companyName ?? this.companyName,
        responsibleName: responsibleName ?? this.responsibleName,
        cinNumber: cinNumber ?? this.cinNumber,
        birthDate: birthDate ?? this.birthDate,
        referenceCode: referenceCode ?? this.referenceCode,
        streetAddress: streetAddress ?? this.streetAddress,
        postalCode: postalCode ?? this.postalCode,
        country: country ?? this.country,
        deliveryStreet: deliveryStreet ?? this.deliveryStreet,
        deliveryCity: deliveryCity ?? this.deliveryCity,
        deliveryPostalCode: deliveryPostalCode ?? this.deliveryPostalCode,
        deliveryCountry: deliveryCountry ?? this.deliveryCountry,
        deliverySameAsBilling: deliverySameAsBilling ?? this.deliverySameAsBilling,
        bankAccount: bankAccount ?? this.bankAccount,
        tvaSuspension: tvaSuspension ?? this.tvaSuspension,
        tvaAttestation: tvaAttestation ?? this.tvaAttestation,
        tvaStartDate: tvaStartDate ?? this.tvaStartDate,
        tvaEndDate: tvaEndDate ?? this.tvaEndDate,
        priceList: priceList ?? this.priceList,
        privateNote: privateNote ?? this.privateNote,
      );
}
