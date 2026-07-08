class InventorySheetItem {
  final String id;
  final String inventoryId;
  final String productId;
  final String? productName;
  final String? productSku;
  final double theoreticalQty;
  final double actualQty;

  InventorySheetItem({
    required this.id,
    required this.inventoryId,
    required this.productId,
    this.productName,
    this.productSku,
    required this.theoreticalQty,
    required this.actualQty,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'inventory_id': inventoryId,
        'product_id': productId,
        'theoretical_qty': theoreticalQty,
        'actual_qty': actualQty,
      };

  factory InventorySheetItem.fromMap(Map<String, dynamic> map, {String? productName, String? productSku}) => InventorySheetItem(
        id: map['id'] as String,
        inventoryId: map['inventory_id'] as String,
        productId: map['product_id'] as String,
        productName: productName,
        productSku: productSku,
        theoreticalQty: (map['theoretical_qty'] as num).toDouble(),
        actualQty: (map['actual_qty'] as num).toDouble(),
      );

  InventorySheetItem copyWith({
    String? id,
    String? inventoryId,
    String? productId,
    String? productName,
    String? productSku,
    double? theoreticalQty,
    double? actualQty,
  }) {
    return InventorySheetItem(
      id: id ?? this.id,
      inventoryId: inventoryId ?? this.inventoryId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      theoreticalQty: theoreticalQty ?? this.theoreticalQty,
      actualQty: actualQty ?? this.actualQty,
    );
  }
}
