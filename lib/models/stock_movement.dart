import '../utils/constants.dart';

class StockMovement {
  final String id;
  final String productId;
  final String? productName;
  final String warehouseId;
  final String? warehouseName;
  final MovementType type;
  final double quantity;
  final String? referenceType;
  final String? referenceId;
  final DateTime date;
  final String? notes;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;

  StockMovement({
    required this.id, required this.productId, this.productName,
    required this.warehouseId, this.warehouseName, required this.type,
    required this.quantity, this.referenceType, this.referenceId,
    required this.date, this.notes, this.firebaseUid,
    this.isDeleted = false, DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'product_id': productId, 'warehouse_id': warehouseId,
        'type': type.name, 'quantity': quantity,
        'reference_type': referenceType, 'reference_id': referenceId,
        'date': date.toIso8601String(), 'notes': notes,
        'firebase_uid': firebaseUid, 'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as String, productId: map['product_id'] as String,
        productName: map['product_name'] as String?,
        warehouseId: map['warehouse_id'] as String,
        warehouseName: map['warehouse_name'] as String?,
        type: MovementType.values.firstWhere(
          (e) => e.name == map['type'], orElse: () => MovementType.entry),
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        referenceType: map['reference_type'] as String?,
        referenceId: map['reference_id'] as String?,
        date: DateTime.parse(map['date'] as String),
        notes: map['notes'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class Warehouse {
  final String id;
  final String name;
  final String? address;
  final bool isDefault;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Warehouse({
    required this.id, required this.name, this.address,
    this.isDefault = false, this.firebaseUid, this.isDeleted = false,
    DateTime? createdAt, DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'address': address,
        'is_default': isDefault ? 1 : 0, 'firebase_uid': firebaseUid,
        'is_deleted': isDeleted ? 1 : 0, 'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Warehouse.fromMap(Map<String, dynamic> map) => Warehouse(
        id: map['id'] as String, name: map['name'] as String,
        address: map['address'] as String?,
        isDefault: map['is_default'] == 1,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Warehouse copyWith({
    String? id, String? name, String? address, bool? isDefault,
    String? firebaseUid, bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => Warehouse(
        id: id ?? this.id, name: name ?? this.name,
        address: address ?? this.address, isDefault: isDefault ?? this.isDefault,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}
