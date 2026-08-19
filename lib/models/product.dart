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
        if (d.runtimeType.toString().contains('Timestamp') || d is dynamic) {
          final toDate = (d as dynamic).toDate;
          if (toDate != null) return (d as dynamic).toDate() as DateTime;
        }
      } catch (_) {}
      return DateTime.tryParse(d.toString()) ?? DateTime.now();
    }

    return Product(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      reference: map['reference']?.toString(),
      description: map['description']?.toString(),
      category: map['category']?.toString(),
      productType: map['product_type']?.toString() ?? 'produit',
      familyId: map['family_id']?.toString(),
      subFamilyId: map['sub_family_id']?.toString(),
      brandId: map['brand_id']?.toString(),
      unit: map['unit']?.toString() ?? 'Unite',
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
      usualDiscount: (map['usual_discount'] as num?)?.toDouble() ?? 0,
      tvaRate: (map['tva_rate'] as num?)?.toDouble() ?? 19,
      stockQty: (map['stock_qty'] as num?)?.toDouble() ?? 0,
      minStockQty: (map['min_stock_qty'] as num?)?.toDouble() ?? 0,
      allowNegativeStock: map['allow_negative_stock'] == 1 || map['allow_negative_stock'] == true,
      lowStockAlert: map['low_stock_alert'] == 1 || map['low_stock_alert'] == true,
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 5,
      highStockAlert: map['high_stock_alert'] == 1 || map['high_stock_alert'] == true,
      highStockThreshold: (map['high_stock_threshold'] as num?)?.toDouble() ?? 0,
      defaultWarehouseId: map['default_warehouse_id']?.toString(),
      barcode: map['barcode']?.toString(),
      privateNotes: map['private_notes']?.toString(),
      isActive: map['is_active'] != 0 && map['is_active'] != false,
      firebaseUid: map['firebase_uid']?.toString(),
      enterpriseId: map['enterprise_id']?.toString(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
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
