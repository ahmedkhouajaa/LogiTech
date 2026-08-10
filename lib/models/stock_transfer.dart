import 'package:uuid/uuid.dart';

class StockTransfer {
  final String id;
  final String number;
  final DateTime date;
  final String sourceWarehouseId;
  final String destinationWarehouseId;
  final String status; // draft, validated, cancelled
  final String? reason;
  final String? notes;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StockTransferItem> items;

  StockTransfer({
    String? id,
    required this.number,
    required this.date,
    required this.sourceWarehouseId,
    required this.destinationWarehouseId,
    this.status = 'draft',
    this.reason,
    this.notes,
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'date': date.toIso8601String(),
      'source_warehouse_id': sourceWarehouseId,
      'destination_warehouse_id': destinationWarehouseId,
      'status': status,
      'reason': reason,
      'notes': notes,
      'firebase_uid': firebaseUid,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory StockTransfer.fromMap(Map<String, dynamic> map, [List<StockTransferItem>? items]) {
    List<StockTransferItem> parsedItems = items ?? [];
    if ((items == null || items.isEmpty) && map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List)
          .map((i) => StockTransferItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList();
    }
    return StockTransfer(
      id: map['id'],
      number: map['number'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      sourceWarehouseId: map['source_warehouse_id'] ?? '',
      destinationWarehouseId: map['destination_warehouse_id'] ?? '',
      status: map['status'] ?? 'draft',
      reason: map['reason'],
      notes: map['notes'],
      firebaseUid: map['firebase_uid'],
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
      items: parsedItems,
    );
  }

  StockTransfer copyWith({
    String? id,
    String? number,
    DateTime? date,
    String? sourceWarehouseId,
    String? destinationWarehouseId,
    String? status,
    String? reason,
    String? notes,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<StockTransferItem>? items,
  }) {
    return StockTransfer(
      id: id ?? this.id,
      number: number ?? this.number,
      date: date ?? this.date,
      sourceWarehouseId: sourceWarehouseId ?? this.sourceWarehouseId,
      destinationWarehouseId: destinationWarehouseId ?? this.destinationWarehouseId,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}

class StockTransferItem {
  final String id;
  final String transferId;
  final String productId;
  final String? productName;
  final String? productSku;
  final double quantityToTransfer;

  StockTransferItem({
    String? id,
    required this.transferId,
    required this.productId,
    this.productName,
    this.productSku,
    required this.quantityToTransfer,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transfer_id': transferId,
      'product_id': productId,
      'product_name': productName,
      'product_sku': productSku,
      'quantity_to_transfer': quantityToTransfer,
    };
  }

  factory StockTransferItem.fromMap(Map<String, dynamic> map, {String? productName, String? productSku}) {
    return StockTransferItem(
      id: map['id'] ?? const Uuid().v4(),
      transferId: map['transfer_id'] ?? '',
      productId: map['product_id'] ?? '',
      productName: productName ?? map['product_name'],
      productSku: productSku ?? map['product_sku'],
      quantityToTransfer: (map['quantity_to_transfer'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
