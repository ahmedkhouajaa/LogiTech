class Product {
  final String id;
  final String code;
  final String name;
  final String? reference;
  final String? description;
  final String? category;
  final String productType; // produit, service, consommable
  final String? familyId;
  final String? subFamilyId;
  final String? brandId;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final double usualDiscount;
  final double tvaRate;
  final double stockQty;
  final double minStockQty;
  final bool allowNegativeStock;
  final bool lowStockAlert;
  final double lowStockThreshold;
  final bool highStockAlert;
  final double highStockThreshold;
  final String? defaultWarehouseId;
  final String? barcode;
  final String? privateNotes;
  final bool isActive;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? enterpriseId;

  Product({
    required this.id,
    required this.code,
    required this.name,
    this.reference,
    this.description,
    this.category,
    this.productType = 'produit',
    this.familyId,
    this.subFamilyId,
    this.brandId,
    this.unit = 'Unite',
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.usualDiscount = 0,
    this.tvaRate = 19,
    this.stockQty = 0,
    this.minStockQty = 0,
    this.allowNegativeStock = false,
    this.lowStockAlert = false,
    this.lowStockThreshold = 5,
    this.highStockAlert = false,
    this.highStockThreshold = 0,
    this.defaultWarehouseId,
    this.barcode,
    this.privateNotes,
    this.isActive = true,
    this.firebaseUid,
    this.enterpriseId,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => stockQty <= lowStockThreshold && lowStockAlert;

  double get margin => sellingPrice > 0 && purchasePrice > 0
      ? ((sellingPrice - purchasePrice) / purchasePrice) * 100
      : 0;

  Map<String, dynamic> toMap() => {
        'id': id, 'code': code, 'name': name, 'reference': reference,
        'description': description, 'category': category, 'product_type': productType,
        'family_id': familyId, 'sub_family_id': subFamilyId, 'brand_id': brandId,
        'unit': unit, 'purchase_price': purchasePrice, 'selling_price': sellingPrice,
        'usual_discount': usualDiscount, 'tva_rate': tvaRate,
        'stock_qty': stockQty, 'min_stock_qty': minStockQty,
        'allow_negative_stock': allowNegativeStock ? 1 : 0,
        'low_stock_alert': lowStockAlert ? 1 : 0,
        'low_stock_threshold': lowStockThreshold,
        'high_stock_alert': highStockAlert ? 1 : 0,
        'high_stock_threshold': highStockThreshold,
        'default_warehouse_id': defaultWarehouseId,
        'barcode': barcode, 'private_notes': privateNotes,
        'is_active': isActive ? 1 : 0, 'firebase_uid': firebaseUid,
        'enterprise_id': enterpriseId,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      try {
        final toDate = (d as dynamic).toDate;
        if (toDate != null) return (d as dynamic).toDate() as DateTime;
      } catch (_) {}
      return DateTime.tryParse(d.toString()) ?? DateTime.now();
    }

    double parseDouble(dynamic val, [double defaultVal = 0.0]) {
      if (val == null) return defaultVal;
      if (val is num) return val.toDouble();
      if (val is String) {
        final clean = val.replaceAll(' ', '').replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.-]'), '');
        return double.tryParse(clean) ?? defaultVal;
      }
      return defaultVal;
    }

    return Product(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      reference: map['reference']?.toString(),
      description: map['description']?.toString(),
      category: map['category']?.toString(),
      productType: (map['product_type'] ?? map['productType'])?.toString() ?? 'produit',
      familyId: (map['family_id'] ?? map['familyId'])?.toString(),
      subFamilyId: (map['sub_family_id'] ?? map['subFamilyId'])?.toString(),
      brandId: (map['brand_id'] ?? map['brandId'])?.toString(),
      unit: map['unit']?.toString() ?? 'Unite',
      purchasePrice: parseDouble(map['purchase_price'] ?? map['purchasePrice'], 0.0),
      sellingPrice: parseDouble(map['selling_price'] ?? map['sellingPrice'], 0.0),
      usualDiscount: parseDouble(map['usual_discount'] ?? map['usualDiscount'], 0.0),
      tvaRate: parseDouble(map['tva_rate'] ?? map['tvaRate'], 19.0),
      stockQty: parseDouble(map['stock_qty'] ?? map['stockQty'], 0.0),
      minStockQty: parseDouble(map['min_stock_qty'] ?? map['minStockQty'], 0.0),
      allowNegativeStock: map['allow_negative_stock'] == 1 || map['allow_negative_stock'] == true || map['allowNegativeStock'] == true,
      lowStockAlert: map['low_stock_alert'] == 1 || map['low_stock_alert'] == true || map['lowStockAlert'] == true,
      lowStockThreshold: parseDouble(map['low_stock_threshold'] ?? map['lowStockThreshold'], 5.0),
      highStockAlert: map['high_stock_alert'] == 1 || map['high_stock_alert'] == true || map['highStockAlert'] == true,
      highStockThreshold: parseDouble(map['high_stock_threshold'] ?? map['highStockThreshold'], 0.0),
      defaultWarehouseId: (map['default_warehouse_id'] ?? map['defaultWarehouseId'])?.toString(),
      barcode: (map['barcode'] ?? map['barCode'])?.toString(),
      privateNotes: (map['private_notes'] ?? map['privateNotes'])?.toString(),
      isActive: map['is_active'] != 0 && map['is_active'] != false && map['isActive'] != false,
      firebaseUid: (map['firebase_uid'] ?? map['userId'] ?? map['firebaseUid'])?.toString(),
      enterpriseId: (map['enterprise_id'] ?? map['enterpriseId'])?.toString(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == 1 || map['isDeleted'] == true,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Product copyWith({
    String? id, String? code, String? name, String? reference, String? description,
    String? category, String? productType, String? familyId, String? subFamilyId,
    String? brandId, String? unit, double? purchasePrice, double? sellingPrice,
    double? usualDiscount, double? tvaRate, double? stockQty, double? minStockQty,
    bool? allowNegativeStock, bool? lowStockAlert, double? lowStockThreshold,
    bool? highStockAlert, double? highStockThreshold, String? defaultWarehouseId,
    String? barcode, String? privateNotes, bool? isActive, String? firebaseUid,
    String? enterpriseId,
    bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => Product(
        id: id ?? this.id, code: code ?? this.code, name: name ?? this.name,
        reference: reference ?? this.reference, description: description ?? this.description,
        category: category ?? this.category, productType: productType ?? this.productType,
        familyId: familyId ?? this.familyId, subFamilyId: subFamilyId ?? this.subFamilyId,
        brandId: brandId ?? this.brandId, unit: unit ?? this.unit,
        purchasePrice: purchasePrice ?? this.purchasePrice, sellingPrice: sellingPrice ?? this.sellingPrice,
        usualDiscount: usualDiscount ?? this.usualDiscount, tvaRate: tvaRate ?? this.tvaRate,
        stockQty: stockQty ?? this.stockQty, minStockQty: minStockQty ?? this.minStockQty,
        allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
        lowStockAlert: lowStockAlert ?? this.lowStockAlert, lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        highStockAlert: highStockAlert ?? this.highStockAlert, highStockThreshold: highStockThreshold ?? this.highStockThreshold,
        defaultWarehouseId: defaultWarehouseId ?? this.defaultWarehouseId,
        barcode: barcode ?? this.barcode, privateNotes: privateNotes ?? this.privateNotes,
        isActive: isActive ?? this.isActive, firebaseUid: firebaseUid ?? this.firebaseUid,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}
