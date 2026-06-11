class DeliveryNote {
  final String id;
  final String number;
  final String customerId;
  final String? customerName;
  final String? orderId;
  final DateTime date;
  final String status; // draft, delivered, invoiced
  final String? warehouseId;
  final String? notes;
  final List<DeliveryNoteItem> items;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryNote({
    required this.id, required this.number, required this.customerId,
    this.customerName, this.orderId, required this.date,
    this.status = 'draft', this.warehouseId, this.notes,
    this.items = const [], this.firebaseUid, this.isDeleted = false,
    DateTime? createdAt, DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'number': number, 'customer_id': customerId,
        'order_id': orderId, 'date': date.toIso8601String(),
        'status': status, 'warehouse_id': warehouseId, 'notes': notes,
        'firebase_uid': firebaseUid, 'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DeliveryNote.fromMap(Map<String, dynamic> map) => DeliveryNote(
        id: map['id'] as String, number: map['number'] as String,
        customerId: map['customer_id'] as String,
        customerName: map['customer_name'] as String?,
        orderId: map['order_id'] as String?,
        date: DateTime.parse(map['date'] as String),
        status: map['status'] as String? ?? 'draft',
        warehouseId: map['warehouse_id'] as String?,
        notes: map['notes'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  DeliveryNote copyWith({
    String? id, String? number, String? customerId, String? customerName,
    String? orderId, DateTime? date, String? status, String? warehouseId,
    String? notes, List<DeliveryNoteItem>? items, String? firebaseUid,
    bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => DeliveryNote(
        id: id ?? this.id, number: number ?? this.number,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        orderId: orderId ?? this.orderId, date: date ?? this.date,
        status: status ?? this.status, warehouseId: warehouseId ?? this.warehouseId,
        notes: notes ?? this.notes, items: items ?? this.items,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}

class DeliveryNoteItem {
  final String id;
  final String deliveryNoteId;
  final String productId;
  final String? productName;
  final double quantity;
  final double unitPrice;

  DeliveryNoteItem({
    required this.id, required this.deliveryNoteId, required this.productId,
    this.productName, this.quantity = 1, this.unitPrice = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'delivery_note_id': deliveryNoteId, 'product_id': productId,
        'quantity': quantity, 'unit_price': unitPrice,
      };

  factory DeliveryNoteItem.fromMap(Map<String, dynamic> map) => DeliveryNoteItem(
        id: map['id'] as String, deliveryNoteId: map['delivery_note_id'] as String,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String?,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      );
}
