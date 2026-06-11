import '../utils/constants.dart';

class Invoice {
  final String id;
  final String number;
  final String customerId;
  final String? customerName;
  final String? orderId;
  final String? deliveryNoteId;
  final DateTime date;
  final DateTime dueDate;
  final InvoiceStatus status;
  final double totalHT;
  final double totalTva;
  final double totalTTC;
  final double amountPaid;
  final double stampTax;
  final String? notes;
  final List<InvoiceItem> items;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Invoice({
    required this.id,
    required this.number,
    required this.customerId,
    this.customerName,
    this.orderId,
    this.deliveryNoteId,
    required this.date,
    required this.dueDate,
    this.status = InvoiceStatus.draft,
    this.totalHT = 0,
    this.totalTva = 0,
    this.totalTTC = 0,
    this.amountPaid = 0,
    this.stampTax = 0,
    this.notes,
    this.items = const [],
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get amountRemaining => totalTTC + stampTax - amountPaid;
  bool get isOverdue => dueDate.isBefore(DateTime.now()) && status != InvoiceStatus.paid;

  Map<String, dynamic> toMap() => {
        'id': id, 'number': number, 'customer_id': customerId,
        'order_id': orderId, 'delivery_note_id': deliveryNoteId,
        'date': date.toIso8601String(), 'due_date': dueDate.toIso8601String(),
        'status': status.name, 'total_ht': totalHT, 'total_tva': totalTva,
        'total_ttc': totalTTC, 'amount_paid': amountPaid, 'stamp_tax': stampTax,
        'notes': notes, 'firebase_uid': firebaseUid,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'] as String, number: map['number'] as String,
        customerId: map['customer_id'] as String,
        customerName: map['customer_name'] as String?,
        orderId: map['order_id'] as String?,
        deliveryNoteId: map['delivery_note_id'] as String?,
        date: DateTime.parse(map['date'] as String),
        dueDate: DateTime.parse(map['due_date'] as String),
        status: InvoiceStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => InvoiceStatus.draft,
        ),
        totalHT: (map['total_ht'] as num?)?.toDouble() ?? 0,
        totalTva: (map['total_tva'] as num?)?.toDouble() ?? 0,
        totalTTC: (map['total_ttc'] as num?)?.toDouble() ?? 0,
        amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
        stampTax: (map['stamp_tax'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Invoice copyWith({
    String? id, String? number, String? customerId, String? customerName,
    String? orderId, String? deliveryNoteId, DateTime? date, DateTime? dueDate,
    InvoiceStatus? status, double? totalHT, double? totalTva, double? totalTTC,
    double? amountPaid, double? stampTax, String? notes, List<InvoiceItem>? items,
    String? firebaseUid, bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => Invoice(
        id: id ?? this.id, number: number ?? this.number,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        orderId: orderId ?? this.orderId,
        deliveryNoteId: deliveryNoteId ?? this.deliveryNoteId,
        date: date ?? this.date, dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status, totalHT: totalHT ?? this.totalHT,
        totalTva: totalTva ?? this.totalTva, totalTTC: totalTTC ?? this.totalTTC,
        amountPaid: amountPaid ?? this.amountPaid, stampTax: stampTax ?? this.stampTax,
        notes: notes ?? this.notes, items: items ?? this.items,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String productId;
  final String? productName;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final double totalHT;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    this.productName,
    this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.tvaRate = 19,
    this.discountPercent = 0,
    this.totalHT = 0,
  });

  double get computedTotalHT {
    final subtotal = quantity * unitPrice;
    return subtotal - (subtotal * discountPercent / 100);
  }

  double get tvaAmount => computedTotalHT * (tvaRate / 100);
  double get totalTTC => computedTotalHT + tvaAmount;

  Map<String, dynamic> toMap() => {
        'id': id, 'invoice_id': invoiceId, 'product_id': productId,
        'description': description, 'quantity': quantity,
        'unit_price': unitPrice, 'tva_rate': tvaRate,
        'discount_percent': discountPercent, 'total_ht': computedTotalHT,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] as String, invoiceId: map['invoice_id'] as String,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String?,
        description: map['description'] as String?,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        tvaRate: (map['tva_rate'] as num?)?.toDouble() ?? 19,
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
        totalHT: (map['total_ht'] as num?)?.toDouble() ?? 0,
      );

  InvoiceItem copyWith({
    String? id, String? invoiceId, String? productId, String? productName,
    String? description, double? quantity, double? unitPrice, double? tvaRate,
    double? discountPercent, double? totalHT,
  }) => InvoiceItem(
        id: id ?? this.id, invoiceId: invoiceId ?? this.invoiceId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity, unitPrice: unitPrice ?? this.unitPrice,
        tvaRate: tvaRate ?? this.tvaRate,
        discountPercent: discountPercent ?? this.discountPercent,
        totalHT: totalHT ?? this.totalHT,
      );
}
