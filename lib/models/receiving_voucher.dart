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
  final String pricingMode; // 'ht' or 'ttc'
  final double globalDiscountPercent;
  final double globalDiscountAmount;
  final double timbreFiscal;
  final String? conditionsGenerales;
  final double amountPaid;
  final String? firebaseUid;
  final bool isDeleted;
  final bool isConvertedToPurchaseInvoice;
  final String? convertedToPurchaseInvoiceId;
  final bool isConvertedToSupplierReturn;
  final String? convertedToSupplierReturnId;
  final String? notes;
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
    this.pricingMode = 'ht',
    this.globalDiscountPercent = 0,
    this.globalDiscountAmount = 0,
    this.timbreFiscal = 0,
    this.conditionsGenerales,
    this.amountPaid = 0,
    this.firebaseUid,
    this.isDeleted = false,
    this.isConvertedToPurchaseInvoice = false,
    this.convertedToPurchaseInvoiceId,
    this.isConvertedToSupplierReturn = false,
    this.convertedToSupplierReturnId,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();


  double get computedTotalHT => items.fold(0, (s, i) => s + i.computedTotalHT);
  double get globalDiscountAmountValue => (computedTotalHT * globalDiscountPercent / 100) + globalDiscountAmount;
  double get computedTotalHTAfterDiscount => computedTotalHT - globalDiscountAmountValue;
  double get computedTotalTvaAfterDiscount => items.fold(0.0, (s, i) {
    final discountRatio = computedTotalHT > 0 ? (i.computedTotalHT / computedTotalHT) : 0;
    final itemHTAfterGlobal = i.computedTotalHT - (globalDiscountAmountValue * discountRatio);
    return s + (itemHTAfterGlobal * (i.tvaRate / 100));
  });
  double get computedTotalTTC => computedTotalHTAfterDiscount + computedTotalTvaAfterDiscount + timbreFiscal;
  bool get isPaid => status == 'payee' || (amountPaid >= computedTotalTTC && computedTotalTTC > 0);

  ReceivingVoucher copyWith({
    String? id,
    String? number,
    String? supplierId,
    String? supplierName,
    String? orderId,
    DateTime? date,
    String? warehouseId,
    String? status,
    String? pricingMode,
    double? globalDiscountPercent,
    double? globalDiscountAmount,
    double? timbreFiscal,
    String? conditionsGenerales,
    double? amountPaid,
    String? firebaseUid,
    bool? isDeleted,
    bool? isConvertedToPurchaseInvoice,
    String? convertedToPurchaseInvoiceId,
    bool? isConvertedToSupplierReturn,
    String? convertedToSupplierReturnId,
    String? notes,
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
      pricingMode: pricingMode ?? this.pricingMode,
      globalDiscountPercent: globalDiscountPercent ?? this.globalDiscountPercent,
      globalDiscountAmount: globalDiscountAmount ?? this.globalDiscountAmount,
      timbreFiscal: timbreFiscal ?? this.timbreFiscal,
      conditionsGenerales: conditionsGenerales ?? this.conditionsGenerales,
      amountPaid: amountPaid ?? this.amountPaid,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      isDeleted: isDeleted ?? this.isDeleted,
      isConvertedToPurchaseInvoice: isConvertedToPurchaseInvoice ?? this.isConvertedToPurchaseInvoice,
      convertedToPurchaseInvoiceId: convertedToPurchaseInvoiceId ?? this.convertedToPurchaseInvoiceId,
      isConvertedToSupplierReturn: isConvertedToSupplierReturn ?? this.isConvertedToSupplierReturn,
      convertedToSupplierReturnId: convertedToSupplierReturnId ?? this.convertedToSupplierReturnId,
      notes: notes ?? this.notes,
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
      'pricing_mode': pricingMode,
      'global_discount_percent': globalDiscountPercent,
      'global_discount_amount': globalDiscountAmount,
      'timbre_fiscal': timbreFiscal,
      'conditions_generales': conditionsGenerales,
      'amount_paid': amountPaid,
      'firebase_uid': firebaseUid,
      'is_deleted': isDeleted ? 1 : 0,
      'is_converted_to_purchase_invoice': isConvertedToPurchaseInvoice ? 1 : 0,
      'converted_to_purchase_invoice_id': convertedToPurchaseInvoiceId,
      'is_converted_to_supplier_return': isConvertedToSupplierReturn ? 1 : 0,
      'converted_to_supplier_return_id': convertedToSupplierReturnId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory ReceivingVoucher.fromMap(Map<String, dynamic> map, [List<ReceivingVoucherItem> items = const []]) {
    return ReceivingVoucher(
      id: map['id'],
      number: map['number'],
      supplierId: map['supplier_id'],
      supplierName: map['supplier_name'],
      orderId: map['order_id'],
      date: map['date'] != null ? (DateTime.tryParse(map['date'].toString()) ?? DateTime.now()) : DateTime.now(),
      warehouseId: map['warehouse_id'],
      status: map['status'] ?? 'draft',
      pricingMode: map['pricing_mode'] ?? 'ht',
      globalDiscountPercent: (map['global_discount_percent'] ?? 0).toDouble(),
      globalDiscountAmount: (map['global_discount_amount'] ?? 0).toDouble(),
      timbreFiscal: (map['timbre_fiscal'] ?? 0).toDouble(),
      conditionsGenerales: map['conditions_generales'],
      amountPaid: (map['amount_paid'] ?? 0).toDouble(),
      firebaseUid: map['firebase_uid'],
      isDeleted: map['is_deleted'] == 1,
      isConvertedToPurchaseInvoice: map['is_converted_to_purchase_invoice'] == 1,
      convertedToPurchaseInvoiceId: map['converted_to_purchase_invoice_id'],
      isConvertedToSupplierReturn: map['is_converted_to_supplier_return'] == 1,
      convertedToSupplierReturnId: map['converted_to_supplier_return_id'],
      notes: map['notes'],
      createdAt: map['created_at'] != null ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      items: items,
    );
  }
}

class ReceivingVoucherItem {
  final String id;
  final String voucherId;
  final String productId;
  final String? productName;
  final double quantityExpected;
  final double quantityReceived;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;

  ReceivingVoucherItem({
    String? id,
    required this.voucherId,
    required this.productId,
    this.productName,
    this.quantityExpected = 0,
    this.quantityReceived = 0,
    this.unitPrice = 0,
    this.tvaRate = 19,
    this.discountPercent = 0,
  }) : id = id ?? const Uuid().v4();

  // Helper getters for calculations based on quantity_received
  double get computedDiscountAmount => (unitPrice * quantityReceived) * (discountPercent / 100);
  double get computedTotalHT => (unitPrice * quantityReceived) - computedDiscountAmount;
  double get tvaAmount => computedTotalHT * (tvaRate / 100);
  double get computedTotalTTC => computedTotalHT + tvaAmount;

  ReceivingVoucherItem copyWith({
    String? id,
    String? voucherId,
    String? productId,
    String? productName,
    double? quantityExpected,
    double? quantityReceived,
    double? unitPrice,
    double? tvaRate,
    double? discountPercent,
  }) {
    return ReceivingVoucherItem(
      id: id ?? this.id,
      voucherId: voucherId ?? this.voucherId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantityExpected: quantityExpected ?? this.quantityExpected,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      unitPrice: unitPrice ?? this.unitPrice,
      tvaRate: tvaRate ?? this.tvaRate,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'voucher_id': voucherId,
      'product_id': productId,
      'quantity_expected': quantityExpected,
      'quantity_received': quantityReceived,
      'unit_price': unitPrice,
      'tva_rate': tvaRate,
      'discount_percent': discountPercent,
    };
  }

  factory ReceivingVoucherItem.fromMap(Map<String, dynamic> map) {
    return ReceivingVoucherItem(
      id: map['id'],
      voucherId: map['voucher_id'],
      productId: map['product_id'],
      productName: map['product_name'], // From JOIN if any
      quantityExpected: (map['quantity_expected'] ?? 0).toDouble(),
      quantityReceived: (map['quantity_received'] ?? 0).toDouble(),
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      tvaRate: (map['tva_rate'] ?? 0).toDouble(),
      discountPercent: (map['discount_percent'] ?? 0).toDouble(),
    );
  }
}
