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
  final String? enterpriseId;
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
    this.enterpriseId,
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
        'enterprise_id': enterpriseId,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'items': items.map((i) => i.toMap()).toList(),
      };

  factory InventorySheet.fromMap(Map<String, dynamic> map, [List<InventorySheetItem>? items]) {
    List<InventorySheetItem> parsedItems = items ?? [];
    if ((items == null || items.isEmpty) && map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List)
          .map((i) => InventorySheetItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList();
    }
    return InventorySheet(
      id: map['id']?.toString() ?? '',
      number: map['number']?.toString() ?? '',
      date: map['date'] != null ? (DateTime.tryParse(map['date'].toString()) ?? DateTime.now()) : DateTime.now(),
      inventoryDate: map['inventory_date'] != null ? (DateTime.tryParse(map['inventory_date'].toString()) ?? DateTime.now()) : (map['date'] != null ? (DateTime.tryParse(map['date'].toString()) ?? DateTime.now()) : DateTime.now()),
      warehouseId: map['warehouse_id']?.toString() ?? '',
      countedBy: map['counted_by']?.toString(),
      status: map['status']?.toString() ?? 'draft',
      reason: map['reason']?.toString(),
      notes: map['notes']?.toString(),
      firebaseUid: map['firebase_uid']?.toString(),
      enterpriseId: map['enterprise_id']?.toString(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['is_deleted'] == '1' || map['is_deleted'] == 'true',
      createdAt: map['created_at'] != null ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      items: parsedItems,
    );
  }

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
