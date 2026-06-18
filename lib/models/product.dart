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
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String, code: map['code'] as String,
        name: map['name'] as String, reference: map['reference'] as String?,
        description: map['description'] as String?, category: map['category'] as String?,
        productType: map['product_type'] as String? ?? 'produit',
        familyId: map['family_id'] as String?, subFamilyId: map['sub_family_id'] as String?,
        brandId: map['brand_id'] as String?,
        unit: map['unit'] as String? ?? 'Unite',
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
        usualDiscount: (map['usual_discount'] as num?)?.toDouble() ?? 0,
        tvaRate: (map['tva_rate'] as num?)?.toDouble() ?? 19,
        stockQty: (map['stock_qty'] as num?)?.toDouble() ?? 0,
        minStockQty: (map['min_stock_qty'] as num?)?.toDouble() ?? 0,
        allowNegativeStock: map['allow_negative_stock'] == 1,
        lowStockAlert: map['low_stock_alert'] == 1,
        lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 5,
        highStockAlert: map['high_stock_alert'] == 1,
        highStockThreshold: (map['high_stock_threshold'] as num?)?.toDouble() ?? 0,
        defaultWarehouseId: map['default_warehouse_id'] as String?,
        barcode: map['barcode'] as String?, privateNotes: map['private_notes'] as String?,
        isActive: map['is_active'] != 0, firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Product copyWith({
    String? id, String? code, String? name, String? reference, String? description,
    String? category, String? productType, String? familyId, String? subFamilyId,
    String? brandId, String? unit, double? purchasePrice, double? sellingPrice,
    double? usualDiscount, double? tvaRate, double? stockQty, double? minStockQty,
    bool? allowNegativeStock, bool? lowStockAlert, double? lowStockThreshold,
    bool? highStockAlert, double? highStockThreshold, String? defaultWarehouseId,
    String? barcode, String? privateNotes, bool? isActive, String? firebaseUid,
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
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}
