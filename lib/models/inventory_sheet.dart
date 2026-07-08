import '../utils/constants.dart';
import 'inventory_sheet_item.dart';

class InventorySheet {
  final String id;
  final String number;
  final DateTime date;
  final DateTime inventoryDate;
  final String warehouseId;
  final String? countedBy;
  final String status;
  final String? reason;
  final String? notes;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InventorySheetItem> items;

  InventorySheet({
    required this.id,
    required this.number,
    required this.date,
    required this.inventoryDate,
    required this.warehouseId,
    this.countedBy,
    this.status = 'draft',
    this.reason,
    this.notes,
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'date': date.toIso8601String(),
        'inventory_date': inventoryDate.toIso8601String(),
        'warehouse_id': warehouseId,
        'counted_by': countedBy,
        'status': status,
        'reason': reason,
        'notes': notes,
        'firebase_uid': firebaseUid,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory InventorySheet.fromMap(Map<String, dynamic> map, [List<InventorySheetItem>? items]) => InventorySheet(
        id: map['id'] as String,
        number: map['number'] as String,
        date: DateTime.parse(map['date'] as String),
        inventoryDate: DateTime.parse(map['inventory_date'] as String),
        warehouseId: map['warehouse_id'] as String,
        countedBy: map['counted_by'] as String?,
        status: map['status'] as String,
        reason: map['reason'] as String?,
        notes: map['notes'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        items: items ?? [],
      );

  InventorySheet copyWith({
    String? id,
    String? number,
    DateTime? date,
    DateTime? inventoryDate,
    String? warehouseId,
    String? countedBy,
    String? status,
    String? reason,
    String? notes,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<InventorySheetItem>? items,
  }) {
    return InventorySheet(
      id: id ?? this.id,
      number: number ?? this.number,
      date: date ?? this.date,
      inventoryDate: inventoryDate ?? this.inventoryDate,
      warehouseId: warehouseId ?? this.warehouseId,
      countedBy: countedBy ?? this.countedBy,
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
