class Product {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String? category;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final double tvaRate;
  final double stockQty;
  final double minStockQty;
  final String? barcode;
  final bool isActive;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.category,
    this.unit = 'Unité',
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.tvaRate = 19,
    this.stockQty = 0,
    this.minStockQty = 0,
    this.barcode,
    this.isActive = true,
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => stockQty <= minStockQty && minStockQty > 0;

  double get margin => sellingPrice > 0 && purchasePrice > 0
      ? ((sellingPrice - purchasePrice) / purchasePrice) * 100
      : 0;

  Map<String, dynamic> toMap() => {
        'id': id, 'code': code, 'name': name, 'description': description,
        'category': category, 'unit': unit, 'purchase_price': purchasePrice,
        'selling_price': sellingPrice, 'tva_rate': tvaRate,
        'stock_qty': stockQty, 'min_stock_qty': minStockQty,
        'barcode': barcode, 'is_active': isActive ? 1 : 0,
        'firebase_uid': firebaseUid, 'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String, code: map['code'] as String,
        name: map['name'] as String, description: map['description'] as String?,
        category: map['category'] as String?, unit: map['unit'] as String? ?? 'Unité',
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
        tvaRate: (map['tva_rate'] as num?)?.toDouble() ?? 19,
        stockQty: (map['stock_qty'] as num?)?.toDouble() ?? 0,
        minStockQty: (map['min_stock_qty'] as num?)?.toDouble() ?? 0,
        barcode: map['barcode'] as String?,
        isActive: map['is_active'] != 0,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Product copyWith({
    String? id, String? code, String? name, String? description,
    String? category, String? unit, double? purchasePrice, double? sellingPrice,
    double? tvaRate, double? stockQty, double? minStockQty, String? barcode,
    bool? isActive, String? firebaseUid, bool? isDeleted,
    DateTime? createdAt, DateTime? updatedAt,
  }) => Product(
        id: id ?? this.id, code: code ?? this.code, name: name ?? this.name,
        description: description ?? this.description, category: category ?? this.category,
        unit: unit ?? this.unit, purchasePrice: purchasePrice ?? this.purchasePrice,
        sellingPrice: sellingPrice ?? this.sellingPrice, tvaRate: tvaRate ?? this.tvaRate,
        stockQty: stockQty ?? this.stockQty, minStockQty: minStockQty ?? this.minStockQty,
        barcode: barcode ?? this.barcode, isActive: isActive ?? this.isActive,
        firebaseUid: firebaseUid ?? this.firebaseUid, isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}
