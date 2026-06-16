import '../utils/constants.dart';

class Quote {
  final String id;
  final String number;
  final String customerId;
  final String? customerName;
  final DateTime date;
  final DateTime validityDate;
  final DocumentStatus status;
  final double totalHT;
  final double totalTva;
  final double totalTTC;
  final String? notes;
  final List<QuoteItem> items;
  final String? firebaseUid;
  final bool isDeleted;
  final bool isConverted;
  final String? convertedTo;
  final String? convertedToId;
  final bool isConvertedToOrder;
  final String? convertedToOrderId;
  final bool isConvertedToDelivery;
  final String? convertedToDeliveryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Quote({
    required this.id, required this.number, required this.customerId,
    this.customerName, required this.date, required this.validityDate,
    this.status = DocumentStatus.draft, this.totalHT = 0, this.totalTva = 0,
    this.totalTTC = 0, this.notes, this.items = const [],
    this.firebaseUid, this.isDeleted = false,
    this.isConverted = false, this.convertedTo, this.convertedToId,
    this.isConvertedToOrder = false, this.convertedToOrderId,
    this.isConvertedToDelivery = false, this.convertedToDeliveryId,
    DateTime? createdAt, DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isExpired => validityDate.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id, 'number': number, 'customer_id': customerId,
        'date': date.toIso8601String(), 'validity_date': validityDate.toIso8601String(),
        'status': status.name, 'total_ht': totalHT, 'total_tva': totalTva,
        'total_ttc': totalTTC, 'notes': notes, 'firebase_uid': firebaseUid,
        'is_deleted': isDeleted ? 1 : 0, 
        'is_converted': isConverted ? 1 : 0,
        'converted_to': convertedTo, 'converted_to_id': convertedToId,
        'is_converted_to_order': isConvertedToOrder ? 1 : 0,
        'converted_to_order_id': convertedToOrderId,
        'is_converted_to_delivery': isConvertedToDelivery ? 1 : 0,
        'converted_to_delivery_id': convertedToDeliveryId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Quote.fromMap(Map<String, dynamic> map) => Quote(
        id: map['id'] as String, number: map['number'] as String,
        customerId: map['customer_id'] as String,
        customerName: map['customer_name'] as String?,
        date: DateTime.parse(map['date'] as String),
        validityDate: DateTime.parse(map['validity_date'] as String),
        status: DocumentStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => DocumentStatus.draft),
        totalHT: (map['total_ht'] as num?)?.toDouble() ?? 0,
        totalTva: (map['total_tva'] as num?)?.toDouble() ?? 0,
        totalTTC: (map['total_ttc'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        isConverted: map['is_converted'] == 1,
        convertedTo: map['converted_to'] as String?,
        convertedToId: map['converted_to_id'] as String?,
        isConvertedToOrder: map['is_converted_to_order'] == 1,
        convertedToOrderId: map['converted_to_order_id'] as String?,
        isConvertedToDelivery: map['is_converted_to_delivery'] == 1,
        convertedToDeliveryId: map['converted_to_delivery_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Quote copyWith({
    String? id, String? number, String? customerId, String? customerName,
    DateTime? date, DateTime? validityDate, DocumentStatus? status,
    double? totalHT, double? totalTva, double? totalTTC, String? notes,
    List<QuoteItem>? items, String? firebaseUid, bool? isDeleted,
    bool? isConverted, String? convertedTo, String? convertedToId,
    bool? isConvertedToOrder, String? convertedToOrderId,
    bool? isConvertedToDelivery, String? convertedToDeliveryId,
    DateTime? createdAt, DateTime? updatedAt,
  }) => Quote(
        id: id ?? this.id, number: number ?? this.number,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        date: date ?? this.date, validityDate: validityDate ?? this.validityDate,
        status: status ?? this.status, totalHT: totalHT ?? this.totalHT,
        totalTva: totalTva ?? this.totalTva, totalTTC: totalTTC ?? this.totalTTC,
        notes: notes ?? this.notes, items: items ?? this.items,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        isConverted: isConverted ?? this.isConverted,
        convertedTo: convertedTo ?? this.convertedTo,
        convertedToId: convertedToId ?? this.convertedToId,
        isConvertedToOrder: isConvertedToOrder ?? this.isConvertedToOrder,
        convertedToOrderId: convertedToOrderId ?? this.convertedToOrderId,
        isConvertedToDelivery: isConvertedToDelivery ?? this.isConvertedToDelivery,
        convertedToDeliveryId: convertedToDeliveryId ?? this.convertedToDeliveryId,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}

class QuoteItem {
  final String id;
  final String quoteId;
  final String productId;
  final String? productName;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final double totalHT;

  QuoteItem({
    required this.id, required this.quoteId, required this.productId,
    this.productName, this.description, this.quantity = 1, this.unitPrice = 0,
    this.tvaRate = 19, this.discountPercent = 0, this.totalHT = 0,
  });

  double get computedTotalHT {
    final subtotal = quantity * unitPrice;
    return subtotal - (subtotal * discountPercent / 100);
  }

  Map<String, dynamic> toMap() => {
        'id': id, 'quote_id': quoteId, 'product_id': productId,
        'description': description, 'quantity': quantity, 'unit_price': unitPrice,
        'tva_rate': tvaRate, 'discount_percent': discountPercent,
        'total_ht': computedTotalHT,
      };

  factory QuoteItem.fromMap(Map<String, dynamic> map) => QuoteItem(
        id: map['id'] as String, quoteId: map['quote_id'] as String,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String?,
        description: map['description'] as String?,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        tvaRate: (map['tva_rate'] as num?)?.toDouble() ?? 19,
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
        totalHT: (map['total_ht'] as num?)?.toDouble() ?? 0,
      );
}
