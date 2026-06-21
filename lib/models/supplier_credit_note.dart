import 'package:uuid/uuid.dart';

class SupplierCreditNote {
  final String id;
  final String number;
  final String supplierId;
  final DateTime date;
  final String status; // e.g. 'draft', 'validated', 'canceled'
  final String? reason;
  final double totalHT;
  final double totalTVA;
  final double totalTTC;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupplierCreditNoteItem> items;

  SupplierCreditNote({
    required this.id,
    required this.number,
    required this.supplierId,
    required this.date,
    required this.status,
    this.reason,
    required this.items,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        totalHT = items.fold(0, (sum, item) => sum + item.totalHT),
        totalTVA = items.fold(0, (sum, item) => sum + item.totalHT * (item.tvaRate / 100)),
        totalTTC = items.fold(0, (sum, item) => sum + item.totalTTC);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'supplier_id': supplierId,
      'date': date.toIso8601String(),
      'status': status,
      'reason': reason,
      'total_ht': totalHT,
      'total_tva': totalTVA,
      'total_ttc': totalTTC,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SupplierCreditNote.fromMap(Map<String, dynamic> map, List<SupplierCreditNoteItem> items) {
    return SupplierCreditNote(
      id: map['id'],
      number: map['number'],
      supplierId: map['supplier_id'],
      date: DateTime.parse(map['date']),
      status: map['status'],
      reason: map['reason'],
      isDeleted: map['is_deleted'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      items: items,
    );
  }

  SupplierCreditNote copyWith({
    String? id,
    String? number,
    String? supplierId,
    DateTime? date,
    String? status,
    String? reason,
    List<SupplierCreditNoteItem>? items,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierCreditNote(
      id: id ?? this.id,
      number: number ?? this.number,
      supplierId: supplierId ?? this.supplierId,
      date: date ?? this.date,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      items: items ?? this.items,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SupplierCreditNoteItem {
  final String id;
  final String supplierCreditNoteId;
  final String productId;
  final String? designation;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double totalHT;
  final double totalTTC;

  SupplierCreditNoteItem({
    required this.id,
    required this.supplierCreditNoteId,
    required this.productId,
    this.designation,
    required this.quantity,
    required this.unitPrice,
    required this.tvaRate,
    double? totalHT,
  })  : totalHT = totalHT ?? (quantity * unitPrice),
        totalTTC = (totalHT ?? (quantity * unitPrice)) * (1 + tvaRate / 100);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_credit_note_id': supplierCreditNoteId,
      'product_id': productId,
      'designation': designation,
      'quantity': quantity,
      'unit_price': unitPrice,
      'tva_rate': tvaRate,
      'total_ht': totalHT,
      'total_ttc': totalTTC,
    };
  }

  factory SupplierCreditNoteItem.fromMap(Map<String, dynamic> map) {
    return SupplierCreditNoteItem(
      id: map['id'],
      supplierCreditNoteId: map['supplier_credit_note_id'],
      productId: map['product_id'],
      designation: map['designation'],
      quantity: map['quantity'],
      unitPrice: map['unit_price'],
      tvaRate: map['tva_rate'],
      totalHT: map['total_ht'],
    );
  }

  SupplierCreditNoteItem copyWith({
    String? id,
    String? supplierCreditNoteId,
    String? productId,
    String? designation,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? totalHT,
  }) {
    return SupplierCreditNoteItem(
      id: id ?? this.id,
      supplierCreditNoteId: supplierCreditNoteId ?? this.supplierCreditNoteId,
      productId: productId ?? this.productId,
      designation: designation ?? this.designation,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      tvaRate: tvaRate ?? this.tvaRate,
      totalHT: totalHT ?? this.totalHT,
    );
  }
}
