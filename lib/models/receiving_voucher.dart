import 'package:uuid/uuid.dart';

class ReceivingVoucher {
  final String id;
  final String number;
  final String supplierId;
  final String? supplierName;
  final String? orderId;
  final DateTime date;
  final String? warehouseId;
  final String status;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ReceivingVoucherItem> items;

  ReceivingVoucher({
    String? id,
    required this.number,
    required this.supplierId,
    this.supplierName,
    this.orderId,
    required this.date,
    this.warehouseId,
    this.status = 'draft',
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ReceivingVoucher copyWith({
    String? id,
    String? number,
    String? supplierId,
    String? supplierName,
    String? orderId,
    DateTime? date,
    String? warehouseId,
    String? status,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ReceivingVoucherItem>? items,
  }) {
    return ReceivingVoucher(
      id: id ?? this.id,
      number: number ?? this.number,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      orderId: orderId ?? this.orderId,
      date: date ?? this.date,
      warehouseId: warehouseId ?? this.warehouseId,
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
      'supplier_id': supplierId,
      'order_id': orderId,
      'date': date.toIso8601String(),
      'warehouse_id': warehouseId,
      'status': status,
      'firebase_uid': firebaseUid,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ReceivingVoucher.fromMap(Map<String, dynamic> map, [List<ReceivingVoucherItem> items = const []]) {
    return ReceivingVoucher(
      id: map['id'],
      number: map['number'],
      supplierId: map['supplier_id'],
      supplierName: map['supplier_name'], // From JOIN
      orderId: map['order_id'],
      date: DateTime.parse(map['date']),
      warehouseId: map['warehouse_id'],
      status: map['status'] ?? 'draft',
      firebaseUid: map['firebase_uid'],
      isDeleted: map['is_deleted'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      items: items,
    );
  }
}

class ReceivingVoucherItem {
  final String id;
  final String voucherId;
  final String productId;
  final double quantityExpected;
  final double quantityReceived;

  ReceivingVoucherItem({
    String? id,
    required this.voucherId,
    required this.productId,
    this.quantityExpected = 0,
    this.quantityReceived = 0,
  }) : id = id ?? const Uuid().v4();

  ReceivingVoucherItem copyWith({
    String? id,
    String? voucherId,
    String? productId,
    double? quantityExpected,
    double? quantityReceived,
  }) {
    return ReceivingVoucherItem(
      id: id ?? this.id,
      voucherId: voucherId ?? this.voucherId,
      productId: productId ?? this.productId,
      quantityExpected: quantityExpected ?? this.quantityExpected,
      quantityReceived: quantityReceived ?? this.quantityReceived,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'voucher_id': voucherId,
      'product_id': productId,
      'quantity_expected': quantityExpected,
      'quantity_received': quantityReceived,
    };
  }

  factory ReceivingVoucherItem.fromMap(Map<String, dynamic> map) {
    return ReceivingVoucherItem(
      id: map['id'],
      voucherId: map['voucher_id'],
      productId: map['product_id'],
      quantityExpected: map['quantity_expected'] ?? 0,
      quantityReceived: map['quantity_received'] ?? 0,
    );
  }
}
