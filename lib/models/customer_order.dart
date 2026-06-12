import 'package:uuid/uuid.dart';

class CustomerOrder {
  final String id;
  final String number;
  final String customerId;
  final String? customerName;
  final String? customerCompany;
  final String? projectId;
  final String? projectName;
  final String? quoteId;
  final DateTime date;
  final DateTime? deliveryDate;
  final String status;
  final String pricingMode; // 'ht' or 'ttc'
  final double globalDiscountPercent;
  final double globalDiscountAmount;
  final double timbreFiscal;
  final String? notes;
  final String? conditionsGenerales;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CustomerOrderItem> items;

  CustomerOrder({
    String? id,
    required this.number,
    required this.customerId,
    this.customerName,
    this.customerCompany,
    this.projectId,
    this.projectName,
    this.quoteId,
    required this.date,
    this.deliveryDate,
    this.status = 'draft',
    this.pricingMode = 'ht',
    this.globalDiscountPercent = 0.0,
    this.globalDiscountAmount = 0.0,
    this.timbreFiscal = 1.000,
    this.notes,
    this.conditionsGenerales,
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get subTotalHT {
    return items.fold(0, (sum, item) => sum + item.totalHT);
  }

  double get subTotalTTC {
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
    return items.fold(0, (sum, item) => sum + item.tvaAmount);
  }

  double get discountAmount {
    if (globalDiscountAmount > 0) return globalDiscountAmount;
    if (globalDiscountPercent > 0) return subTotalHT * (globalDiscountPercent / 100);
    return 0;
  }

  double get totalHTAfterDiscount {
    return subTotalHT - discountAmount;
  }

  double get totalTTC {
    if (pricingMode == 'ttc') {
      return subTotalTTC - discountAmount + timbreFiscal;
    } else {
      return totalHTAfterDiscount + totalTVA + timbreFiscal;
    }
  }

  CustomerOrder copyWith({
    String? id,
    String? number,
    String? customerId,
    String? customerName,
    String? customerCompany,
    String? projectId,
    String? projectName,
    String? quoteId,
    DateTime? date,
    DateTime? deliveryDate,
    String? status,
    String? pricingMode,
    double? globalDiscountPercent,
    double? globalDiscountAmount,
    double? timbreFiscal,
    String? notes,
    String? conditionsGenerales,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CustomerOrderItem>? items,
  }) {
    return CustomerOrder(
      id: id ?? this.id,
      number: number ?? this.number,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerCompany: customerCompany ?? this.customerCompany,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      quoteId: quoteId ?? this.quoteId,
      date: date ?? this.date,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      status: status ?? this.status,
      pricingMode: pricingMode ?? this.pricingMode,
      globalDiscountPercent: globalDiscountPercent ?? this.globalDiscountPercent,
      globalDiscountAmount: globalDiscountAmount ?? this.globalDiscountAmount,
      timbreFiscal: timbreFiscal ?? this.timbreFiscal,
      notes: notes ?? this.notes,
      conditionsGenerales: conditionsGenerales ?? this.conditionsGenerales,
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
      'customer_id': customerId,
      'project_id': projectId,
      'quote_id': quoteId,
      'date': date.toIso8601String(),
      'delivery_date': deliveryDate?.toIso8601String(),
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CustomerOrder.fromMap(Map<String, dynamic> map, [List<CustomerOrderItem> items = const []]) {
    return CustomerOrder(
      id: map['id'],
      number: map['number'],
      customerId: map['customer_id'],
      customerName: map['customer_name'],
      customerCompany: map['customer_company'],
      projectId: map['project_id'],
      projectName: map['project_name'],
      quoteId: map['quote_id'],
      date: DateTime.parse(map['date']),
      deliveryDate: map['delivery_date'] != null ? DateTime.parse(map['delivery_date']) : null,
      status: map['status'] ?? 'draft',
      pricingMode: map['pricing_mode'] ?? 'ht',
      globalDiscountPercent: map['global_discount_percent'] ?? 0.0,
      globalDiscountAmount: map['global_discount_amount'] ?? 0.0,
      timbreFiscal: map['timbre_fiscal'] ?? 1.000,
      notes: map['notes'],
      conditionsGenerales: map['conditions'],
      firebaseUid: map['firebase_uid'],
      isDeleted: map['is_deleted'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      items: items,
    );
  }
}

class CustomerOrderItem {
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

  CustomerOrderItem({
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

  CustomerOrderItem copyWith({
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
    return CustomerOrderItem(
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

  factory CustomerOrderItem.fromMap(Map<String, dynamic> map) {
    return CustomerOrderItem(
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
