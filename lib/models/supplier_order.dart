import 'package:uuid/uuid.dart';

class SupplierOrder {
  final String id;
  final String number;
  final String supplierId;
  final String? supplierName;
  final String? supplierCompany;
  final String? projectId;
  final String? projectName;
  final DateTime date;
  final DateTime? expectedDate;
  final String status;
  final String pricingMode; // 'ht' or 'ttc'
  final double globalDiscountPercent;
  final double globalDiscountAmount;
  final double timbreFiscal;
  final String? notes;
  final String? conditionsGenerales;
  final String? firebaseUid;
  final bool isDeleted;
  final bool isConvertedToReceipt;
  final String? convertedToReceiptId;
  final bool isConvertedToInvoice;
  final String? convertedToInvoiceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupplierOrderItem> items;

  SupplierOrder({
    String? id,
    required this.number,
    required this.supplierId,
    this.supplierName,
    this.supplierCompany,
    this.projectId,
    this.projectName,
    required this.date,
    this.expectedDate,
    this.status = 'draft',
    this.pricingMode = 'ht',
    this.globalDiscountPercent = 0.0,
    this.globalDiscountAmount = 0.0,
    this.timbreFiscal = 1.000,
    this.notes,
    this.conditionsGenerales,
    this.firebaseUid,
    this.isDeleted = false,
    this.isConvertedToReceipt = false,
    this.convertedToReceiptId,
    this.isConvertedToInvoice = false,
    this.convertedToInvoiceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
    double? dbTotalHT,
    double? dbTotalTVA,
    double? dbTotalTTC,
  })  : id = id ?? const Uuid().v4(),
        _dbTotalHT = dbTotalHT,
        _dbTotalTVA = dbTotalTVA,
        _dbTotalTTC = dbTotalTTC,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final double? _dbTotalHT;
  final double? _dbTotalTVA;
  final double? _dbTotalTTC;

  double get subTotalHT {
    if (items.isEmpty && _dbTotalHT != null) return _dbTotalHT!;
    return items.fold(0, (sum, item) => sum + item.totalHT);
  }

  double get subTotalTTC {
    if (items.isEmpty && _dbTotalTTC != null && pricingMode == 'ttc') {
      return _dbTotalTTC! - timbreFiscal + discountAmount;
    }
    return items.fold(0, (sum, item) => sum + item.totalTTC);
  }

  Map<double, double> get tvaBreakdown {
    final breakdown = <double, double>{};
    for (var item in items) {
      breakdown[item.tvaRate] = (breakdown[item.tvaRate] ?? 0) + item.tvaAmount;
    }
    return breakdown;
  }

  double get totalTVA {
    if (items.isEmpty && _dbTotalTVA != null) return _dbTotalTVA!;
    return items.fold(0, (sum, item) => sum + item.tvaAmount);
  }

  double get discountAmount {
    if (globalDiscountAmount > 0) return globalDiscountAmount;
    if (globalDiscountPercent > 0) return subTotalHT * (globalDiscountPercent / 100);
    return 0;
  }

  double get totalHTAfterDiscount {
    if (items.isEmpty && _dbTotalHT != null) return _dbTotalHT!;
    return subTotalHT - discountAmount;
  }

  double get totalTTC {
    if (items.isEmpty && _dbTotalTTC != null) return _dbTotalTTC!;
    if (pricingMode == 'ttc') {
      return subTotalTTC - discountAmount + timbreFiscal;
    } else {
      return totalHTAfterDiscount + totalTVA + timbreFiscal;
    }
  }

  SupplierOrder copyWith({
    String? id,
    String? number,
    String? supplierId,
    String? supplierName,
    String? supplierCompany,
    String? projectId,
    String? projectName,
    DateTime? date,
    DateTime? expectedDate,
    String? status,
    String? pricingMode,
    double? globalDiscountPercent,
    double? globalDiscountAmount,
    double? timbreFiscal,
    String? notes,
    String? conditionsGenerales,
    String? firebaseUid,
    bool? isDeleted,
    bool? isConvertedToReceipt,
    String? convertedToReceiptId,
    bool? isConvertedToInvoice,
    String? convertedToInvoiceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SupplierOrderItem>? items,
  }) {
    return SupplierOrder(
      id: id ?? this.id,
      number: number ?? this.number,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierCompany: supplierCompany ?? this.supplierCompany,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      date: date ?? this.date,
      expectedDate: expectedDate ?? this.expectedDate,
      status: status ?? this.status,
      pricingMode: pricingMode ?? this.pricingMode,
      globalDiscountPercent: globalDiscountPercent ?? this.globalDiscountPercent,
      globalDiscountAmount: globalDiscountAmount ?? this.globalDiscountAmount,
      timbreFiscal: timbreFiscal ?? this.timbreFiscal,
      notes: notes ?? this.notes,
      conditionsGenerales: conditionsGenerales ?? this.conditionsGenerales,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      isDeleted: isDeleted ?? this.isDeleted,
      isConvertedToReceipt: isConvertedToReceipt ?? this.isConvertedToReceipt,
      convertedToReceiptId: convertedToReceiptId ?? this.convertedToReceiptId,
      isConvertedToInvoice: isConvertedToInvoice ?? this.isConvertedToInvoice,
      convertedToInvoiceId: convertedToInvoiceId ?? this.convertedToInvoiceId,
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
      'project_id': projectId,
      'date': date.toIso8601String(),
      'expected_date': expectedDate?.toIso8601String(),
      'status': status,
      'pricing_mode': pricingMode,
      'global_discount_percent': globalDiscountPercent,
      'global_discount_amount': globalDiscountAmount,
      'timbre_fiscal': timbreFiscal,
      'notes': notes,
      'conditions': conditionsGenerales,
      'total_ht': totalHTAfterDiscount,
      'total_tva': totalTVA,
      'total_ttc': totalTTC,
      'firebase_uid': firebaseUid,
      'is_deleted': isDeleted ? 1 : 0,
      'is_converted_to_receipt': isConvertedToReceipt ? 1 : 0,
      'converted_to_receipt_id': convertedToReceiptId,
      'is_converted_to_invoice': isConvertedToInvoice ? 1 : 0,
      'converted_to_invoice_id': convertedToInvoiceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SupplierOrder.fromMap(Map<String, dynamic> map, [List<SupplierOrderItem> items = const []]) {
    return SupplierOrder(
      id: map['id'],
      number: map['number'],
      supplierId: map['supplier_id'],
      supplierName: map['supplier_name'],
      supplierCompany: map['supplier_company'], // Not standard in supplier model but useful for UI joins
      projectId: map['project_id'],
      projectName: map['project_name'],
      date: DateTime.parse(map['date']),
      expectedDate: map['expected_date'] != null ? DateTime.parse(map['expected_date']) : null,
      status: map['status'] ?? 'draft',
      pricingMode: map['pricing_mode'] ?? 'ht',
      globalDiscountPercent: map['global_discount_percent'] ?? 0.0,
      globalDiscountAmount: map['global_discount_amount'] ?? 0.0,
      timbreFiscal: map['timbre_fiscal'] ?? 1.000,
      notes: map['notes'],
      conditionsGenerales: map['conditions'],
      firebaseUid: map['firebase_uid'],
      isDeleted: map['is_deleted'] == 1,
      isConvertedToReceipt: map['is_converted_to_receipt'] == 1,
      convertedToReceiptId: map['converted_to_receipt_id'],
      isConvertedToInvoice: map['is_converted_to_invoice'] == 1,
      convertedToInvoiceId: map['converted_to_invoice_id'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      items: items,
      dbTotalHT: map['total_ht'] != null ? (map['total_ht'] as num).toDouble() : null,
      dbTotalTVA: map['total_tva'] != null ? (map['total_tva'] as num).toDouble() : null,
      dbTotalTTC: map['total_ttc'] != null ? (map['total_ttc'] as num).toDouble() : null,
    );
  }
}

class SupplierOrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final bool showDescription;
  final bool showDiscount;

  SupplierOrderItem({
    String? id,
    required this.orderId,
    required this.productId,
    this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.tvaRate = 19,
    this.discountPercent = 0,
    this.showDescription = false,
    this.showDiscount = false,
  }) : id = id ?? const Uuid().v4();

  double get unitPriceAfterDiscount {
    return unitPrice * (1 - (discountPercent / 100));
  }

  double get totalHT {
    return unitPriceAfterDiscount * quantity;
  }

  double get tvaAmount {
    return totalHT * (tvaRate / 100);
  }

  double get totalTTC {
    return totalHT + tvaAmount;
  }

  SupplierOrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? description,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? discountPercent,
    bool? showDescription,
    bool? showDiscount,
  }) {
    return SupplierOrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      tvaRate: tvaRate ?? this.tvaRate,
      discountPercent: discountPercent ?? this.discountPercent,
      showDescription: showDescription ?? this.showDescription,
      showDiscount: showDiscount ?? this.showDiscount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'tva_rate': tvaRate,
      'discount_percent': discountPercent,
      'total_ht': totalHT,
      'show_description': showDescription ? 1 : 0,
      'show_discount': showDiscount ? 1 : 0,
    };
  }

  factory SupplierOrderItem.fromMap(Map<String, dynamic> map) {
    return SupplierOrderItem(
      id: map['id'],
      orderId: map['order_id'],
      productId: map['product_id'],
      description: map['description'],
      quantity: map['quantity'] ?? 1,
      unitPrice: map['unit_price'] ?? 0,
      tvaRate: map['tva_rate'] ?? 19,
      discountPercent: map['discount_percent'] ?? 0,
      showDescription: map['show_description'] == 1,
      showDiscount: map['show_discount'] == 1,
    );
  }
}
