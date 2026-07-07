import 'package:uuid/uuid.dart';

class StockEntry {
  final String id;
  final String number;
  final String warehouseId;
  final DateTime date;
  final String? supplierId;
  final String? reason;
  final String? notes;
  final String status; // draft, validated, cancelled
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StockEntryItem> items;

  StockEntry({
    String? id,
    required this.number,
    required this.warehouseId,
    required this.date,
    this.supplierId,
    this.reason,
    this.notes,
    this.status = 'draft',
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  StockEntry copyWith({
    String? id,
    String? number,
    String? warehouseId,
    DateTime? date,
    String? supplierId,
    String? reason,
    String? notes,
    String? status,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<StockEntryItem>? items,
  }) {
    return StockEntry(
      id: id ?? this.id,
      number: number ?? this.number,
      warehouseId: warehouseId ?? this.warehouseId,
      date: date ?? this.date,
      supplierId: supplierId ?? this.supplierId,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'warehouse_id': warehouseId,
      'date': date.toIso8601String(),
      'supplier_id': supplierId,
      'reason': reason,
      'notes': notes,
      'status': status,
      'firebase_uid': firebaseUid,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StockEntry.fromMap(Map<String, dynamic> map, [List<StockEntryItem>? items]) {
    return StockEntry(
      id: map['id'],
      number: map['number'],
      warehouseId: map['warehouse_id'],
      date: DateTime.parse(map['date']),
      supplierId: map['supplier_id'],
      reason: map['reason'],
      notes: map['notes'],
      status: map['status'] ?? 'draft',
      firebaseUid: map['firebase_uid'],
      isDeleted: map['is_deleted'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      items: items ?? [],
    );
  }
}

class StockEntryItem {
  final String id;
  final String entryId;
  final String productId;
  final double quantity;
  final double unitPrice;

  StockEntryItem({
    String? id,
    required this.entryId,
    required this.productId,
    this.quantity = 1,
    this.unitPrice = 0,
  }) : id = id ?? const Uuid().v4();

  StockEntryItem copyWith({
    String? id,
    String? entryId,
    String? productId,
    double? quantity,
    double? unitPrice,
  }) {
    return StockEntryItem(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_id': entryId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  factory StockEntryItem.fromMap(Map<String, dynamic> map) {
    return StockEntryItem(
      id: map['id'],
      entryId: map['entry_id'],
      productId: map['product_id'],
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
    );
  }
}
