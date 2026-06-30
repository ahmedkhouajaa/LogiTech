import 'package:equatable/equatable.dart';

class SupplierReturnItem extends Equatable {
  final String id;
  final String supplierReturnId;
  final String? productId;
  final String designation;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double totalHT;
  final String? reason;

  const SupplierReturnItem({
    required this.id,
    required this.supplierReturnId,
    this.productId,
    required this.designation,
    required this.quantity,
    required this.unitPrice,
    required this.tvaRate,
    required this.totalHT,
    this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_id': supplierReturnId,
      'product_id': productId,
      'designation': designation,
      'quantity': quantity,
      'unit_price': unitPrice,
      'tva_rate': tvaRate,
      'total_ht': totalHT,
      'reason': reason,
    };
  }

  factory SupplierReturnItem.fromMap(Map<String, dynamic> map) {
    return SupplierReturnItem(
      id: map['id'],
      supplierReturnId: map['return_id'],
      productId: map['product_id'],
      designation: map['designation'],
      quantity: (map['quantity'] ?? 0).toDouble(),
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      tvaRate: (map['tva_rate'] ?? 19.0).toDouble(),
      totalHT: (map['total_ht'] ?? 0).toDouble(),
      reason: map['reason'],
    );
  }

  SupplierReturnItem copyWith({
    String? id,
    String? supplierReturnId,
    String? productId,
    String? designation,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? totalHT,
    String? reason,
  }) {
    return SupplierReturnItem(
      id: id ?? this.id,
      supplierReturnId: supplierReturnId ?? this.supplierReturnId,
      productId: productId ?? this.productId,
      designation: designation ?? this.designation,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      tvaRate: tvaRate ?? this.tvaRate,
      totalHT: totalHT ?? this.totalHT,
      reason: reason ?? this.reason,
    );
  }

  @override
  List<Object?> get props => [
        id,
        supplierReturnId,
        productId,
        designation,
        quantity,
        unitPrice,
        tvaRate,
        totalHT,
        reason,
      ];
}

class SupplierReturn extends Equatable {
  final String id;
  final String number; // BRF-YYYY-XXXXXX
  final String supplierId;
  final String? purchaseInvoiceId;
  final String? receivingVoucherId;
  final DateTime date;
  final String? reason;
  final String status; // 'draft', 'validated', 'cancelled'
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Modèles imbriqués pour l'UI
  final String? supplierName;
  final List<SupplierReturnItem> items;

  const SupplierReturn({
    required this.id,
    required this.number,
    required this.supplierId,
    this.purchaseInvoiceId,
    this.receivingVoucherId,
    required this.date,
    this.reason,
    required this.status,
    this.firebaseUid,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.supplierName,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'supplier_id': supplierId,
      'purchase_invoice_id': purchaseInvoiceId,
      'receiving_voucher_id': receivingVoucherId,
      'date': date.toIso8601String(),
      'reason': reason,
      'status': status,
      'firebase_uid': firebaseUid,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory SupplierReturn.fromMap(Map<String, dynamic> map, {String? supplierName, List<SupplierReturnItem>? items}) {
    return SupplierReturn(
      id: map['id'],
      number: map['number'],
      supplierId: map['supplier_id'],
      purchaseInvoiceId: map['purchase_invoice_id'],
      receivingVoucherId: map['receiving_voucher_id'],
      date: DateTime.parse(map['date']),
      reason: map['reason'],
      status: map['status'] ?? 'draft',
      firebaseUid: map['firebase_uid'],
      isDeleted: map['is_deleted'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      supplierName: supplierName,
      items: items ?? [],
    );
  }

  SupplierReturn copyWith({
    String? id,
    String? number,
    String? supplierId,
    String? purchaseInvoiceId,
    String? receivingVoucherId,
    DateTime? date,
    String? reason,
    String? status,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    List<SupplierReturnItem>? items,
  }) {
    return SupplierReturn(
      id: id ?? this.id,
      number: number ?? this.number,
      supplierId: supplierId ?? this.supplierId,
      purchaseInvoiceId: purchaseInvoiceId ?? this.purchaseInvoiceId,
      receivingVoucherId: receivingVoucherId ?? this.receivingVoucherId,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
    );
  }

  double get totalHT => items.fold(0, (sum, item) => sum + item.totalHT);
  
  double get totalTVA => items.fold(0, (sum, item) => sum + (item.totalHT * (item.tvaRate / 100)));
  
  double get totalTTC => totalHT + totalTVA;

  @override
  List<Object?> get props => [
        id,
        number,
        supplierId,
        purchaseInvoiceId,
        receivingVoucherId,
        date,
        reason,
        status,
        firebaseUid,
        isDeleted,
        createdAt,
        updatedAt,
        supplierName,
        items,
      ];
}
