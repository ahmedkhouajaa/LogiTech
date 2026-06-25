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
      id: map['id'] as String,
      returnNoteId: map['return_note_id'] as String,
      productId: map['product_id'] as String?,
      designation: map['designation'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      tvaRate: (map['tva_rate'] as num?)?.toDouble() ?? 19.0,
      totalHT: (map['total_ht'] as num).toDouble(),
      reason: map['reason'] as String?,
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
    };
  }

  factory ReturnNote.fromMap(Map<String, dynamic> map, [List<ReturnNoteItem> items = const []]) {
    return ReturnNote(
      id: map['id'] as String,
      returnNumber: map['return_number'] as String,
      customerId: map['customer_id'] as String,
      customerName: map['customer_name'] as String?,
      customerCompany: map['customer_company'] as String?,
      deliveryNoteId: map['delivery_note_id'] as String?,
      dateEmission: DateTime.parse(map['date_emission'] as String),
      subtotalHT: (map['subtotal_ht'] as num?)?.toDouble() ?? 0,
      totalTTC: (map['total_ttc'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      conditions: map['conditions'] as String?,
      status: map['status'] as String? ?? 'draft',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      items: items,
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
