import 'package:equatable/equatable.dart';

class ReturnNoteItem extends Equatable {
  final String id;
  final String returnNoteId;
  final String? productId;
  final String designation;
  final double quantity; // Negative values
  final double unitPrice;
  final double tvaRate;
  final double totalHT;
  final String? reason;

  const ReturnNoteItem({
    required this.id,
    required this.returnNoteId,
    this.productId,
    required this.designation,
    required this.quantity,
    required this.unitPrice,
    this.tvaRate = 19.0,
    required this.totalHT,
    this.reason,
  });

  ReturnNoteItem copyWith({
    String? id,
    String? returnNoteId,
    String? productId,
    String? designation,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? totalHT,
    String? reason,
  }) {
    return ReturnNoteItem(
      id: id ?? this.id,
      returnNoteId: returnNoteId ?? this.returnNoteId,
      productId: productId ?? this.productId,
      designation: designation ?? this.designation,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      tvaRate: tvaRate ?? this.tvaRate,
      totalHT: totalHT ?? this.totalHT,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_note_id': returnNoteId,
      'product_id': productId,
      'designation': designation,
      'quantity': quantity,
      'unit_price': unitPrice,
      'tva_rate': tvaRate,
      'total_ht': totalHT,
      'reason': reason,
    };
  }

  factory ReturnNoteItem.fromMap(Map<String, dynamic> map) {
    return ReturnNoteItem(
      id: map['id']?.toString() ?? '',
      returnNoteId: map['return_note_id']?.toString() ?? '',
      productId: map['product_id']?.toString(),
      designation: map['designation']?.toString() ?? '',
      quantity: double.tryParse(map['quantity']?.toString() ?? '0') ?? 0.0,
      unitPrice: double.tryParse(map['unit_price']?.toString() ?? '0') ?? 0.0,
      tvaRate: double.tryParse(map['tva_rate']?.toString() ?? '19') ?? 19.0,
      totalHT: double.tryParse(map['total_ht']?.toString() ?? '0') ?? 0.0,
      reason: map['reason']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        returnNoteId,
        productId,
        designation,
        quantity,
        unitPrice,
        tvaRate,
        totalHT,
        reason,
      ];
}

class ReturnNote extends Equatable {
  final String id;
  final String returnNumber;
  final String customerId;
  final String? customerName;
  final String? customerCompany;
  final String? deliveryNoteId;
  final DateTime dateEmission;
  final double subtotalHT;
  final double totalTTC;
  final String? notes;
  final String? conditions;
  final String status;
  final List<ReturnNoteItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReturnNote({
    required this.id,
    required this.returnNumber,
    required this.customerId,
    this.customerName,
    this.customerCompany,
    this.deliveryNoteId,
    required this.dateEmission,
    this.subtotalHT = 0,
    this.totalTTC = 0,
    this.notes,
    this.conditions,
    this.status = 'draft',
    this.items = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ReturnNote copyWith({
    String? id,
    String? returnNumber,
    String? customerId,
    String? customerName,
    String? customerCompany,
    String? deliveryNoteId,
    DateTime? dateEmission,
    double? subtotalHT,
    double? totalTTC,
    String? notes,
    String? conditions,
    String? status,
    List<ReturnNoteItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReturnNote(
      id: id ?? this.id,
      returnNumber: returnNumber ?? this.returnNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerCompany: customerCompany ?? this.customerCompany,
      deliveryNoteId: deliveryNoteId ?? this.deliveryNoteId,
      dateEmission: dateEmission ?? this.dateEmission,
      subtotalHT: subtotalHT ?? this.subtotalHT,
      totalTTC: totalTTC ?? this.totalTTC,
      notes: notes ?? this.notes,
      conditions: conditions ?? this.conditions,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_number': returnNumber,
      'customer_id': customerId,
      'delivery_note_id': deliveryNoteId,
      'date_emission': dateEmission.toIso8601String(),
      'subtotal_ht': subtotalHT,
      'total_ttc': totalTTC,
      'notes': notes,
      'conditions': conditions,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory ReturnNote.fromMap(Map<String, dynamic> map, [List<ReturnNoteItem> optionalItems = const []]) {
    List<ReturnNoteItem> parsedItems = optionalItems;
    if (parsedItems.isEmpty && map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List).map((i) => ReturnNoteItem.fromMap(Map<String, dynamic>.from(i))).toList();
    }

    return ReturnNote(
      id: map['id']?.toString() ?? '',
      returnNumber: map['return_number']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      customerName: map['customer_name']?.toString(),
      customerCompany: map['customer_company']?.toString(),
      deliveryNoteId: map['delivery_note_id']?.toString(),
      dateEmission: map['date_emission'] != null ? DateTime.tryParse(map['date_emission'].toString()) ?? DateTime.now() : DateTime.now(),
      subtotalHT: double.tryParse(map['subtotal_ht']?.toString() ?? '0') ?? 0.0,
      totalTTC: double.tryParse(map['total_ttc']?.toString() ?? '0') ?? 0.0,
      notes: map['notes']?.toString(),
      conditions: map['conditions']?.toString(),
      status: map['status']?.toString() ?? 'draft',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      items: parsedItems,
    );
  }

  @override
  List<Object?> get props => [
        id,
        returnNumber,
        customerId,
        customerName,
        customerCompany,
        deliveryNoteId,
        dateEmission,
        subtotalHT,
        totalTTC,
        notes,
        conditions,
        status,
        items,
        createdAt,
        updatedAt,
      ];
}
