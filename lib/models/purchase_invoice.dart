import '../utils/constants.dart';

class PurchaseInvoice {
  final String id;
  final String number;
  final String supplierId;
  final String? supplierName;
  final String? orderId;
  final String? deliveryNoteId;
  final String? projectId;
  final String? projectName;
  final String? devisId;
  final String? receivingVoucherId;
  final DateTime date;
  final DateTime dueDate;
  final InvoiceStatus status;
  final double totalHT;
  final double totalTva;
  final double totalTTC;
  final double amountPaid;
  final double stampTax;
  final double timbreFiscal;
  final double globalDiscountPercent;
  final double globalDiscountAmount;
  final String pricingMode; // 'ht' or 'ttc'
  final String? notes;
  final String? conditionsGenerales;
  final List<PurchaseInvoiceItem> items;
  final String? firebaseUid;
  final String? creditNoteId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchaseInvoice({
    required this.id,
    required this.number,
    required this.supplierId,
    this.supplierName,
    this.orderId,
    this.deliveryNoteId,
    this.projectId,
    this.projectName,
    this.devisId,
    this.receivingVoucherId,
    required this.date,
    required this.dueDate,
    this.status = InvoiceStatus.unpaid,
    this.totalHT = 0,
    this.totalTva = 0,
    this.totalTTC = 0,
    this.amountPaid = 0,
    this.stampTax = 0,
    this.timbreFiscal = 0,
    this.globalDiscountPercent = 0,
    this.globalDiscountAmount = 0,
    this.pricingMode = 'ht',
    this.notes,
    this.conditionsGenerales,
    this.items = const [],
    this.firebaseUid,
    this.creditNoteId,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get amountRemaining => totalTTC + stampTax - amountPaid;
  bool get isOverdue => dueDate.isBefore(DateTime.now()) && status != InvoiceStatus.paid;

  Map<String, dynamic> toMap() => {
        'id': id, 'number': number, 'supplier_id': supplierId,
        'order_id': orderId, 'delivery_note_id': deliveryNoteId,
        'project_id': projectId, 'devis_id': devisId,
        'receiving_voucher_id': receivingVoucherId,
        'date': date.toIso8601String(), 'due_date': dueDate.toIso8601String(),
        'status': status.name, 'total_ht': totalHT, 'total_tva': totalTva,
        'total_ttc': totalTTC, 'amount_paid': amountPaid, 'stamp_tax': stampTax,
        'timbre_fiscal': timbreFiscal,
        'global_discount_percent': globalDiscountPercent,
        'global_discount_amount': globalDiscountAmount,
        'pricing_mode': pricingMode,
        'notes': notes,
        'conditions': conditionsGenerales,
        'firebase_uid': firebaseUid,
        'credit_note_id': creditNoteId,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'items': items.map((i) => i.toMap()).toList(),
      };

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map, [List<PurchaseInvoiceItem> optionalItems = const []]) {
    List<PurchaseInvoiceItem> parsedItems = optionalItems;
    if (parsedItems.isEmpty && map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List).map((i) => PurchaseInvoiceItem.fromMap(Map<String, dynamic>.from(i))).toList();
    }

    return PurchaseInvoice(
        id: map['id']?.toString() ?? '', number: map['number']?.toString() ?? '',
        supplierId: map['supplier_id']?.toString() ?? '',
        supplierName: map['supplier_name']?.toString(),
        orderId: map['order_id']?.toString(),
        deliveryNoteId: map['delivery_note_id']?.toString(),
        projectId: map['project_id']?.toString(),
        projectName: map['project_name']?.toString(),
        devisId: map['devis_id']?.toString(),
        receivingVoucherId: map['receiving_voucher_id']?.toString(),
        date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now() : DateTime.now(),
        dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'].toString()) ?? DateTime.now() : DateTime.now(),
        status: InvoiceStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => InvoiceStatus.unpaid,
        ),
        totalHT: double.tryParse(map['total_ht']?.toString() ?? '0') ?? 0.0,
        totalTva: double.tryParse(map['total_tva']?.toString() ?? '0') ?? 0.0,
        totalTTC: double.tryParse(map['total_ttc']?.toString() ?? '0') ?? 0.0,
        amountPaid: double.tryParse(map['amount_paid']?.toString() ?? '0') ?? 0.0,
        stampTax: double.tryParse(map['stamp_tax']?.toString() ?? '0') ?? 0.0,
        timbreFiscal: double.tryParse(map['timbre_fiscal']?.toString() ?? '0') ?? 0.0,
        globalDiscountPercent: double.tryParse(map['global_discount_percent']?.toString() ?? '0') ?? 0.0,
        globalDiscountAmount: double.tryParse(map['global_discount_amount']?.toString() ?? '0') ?? 0.0,
        pricingMode: map['pricing_mode']?.toString() ?? 'ht',
        notes: map['notes']?.toString(),
        conditionsGenerales: map['conditions']?.toString(),
        firebaseUid: map['firebase_uid']?.toString(),
        creditNoteId: map['credit_note_id']?.toString(),
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == '1' || map['is_deleted'] == true,
        createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
        updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
        items: parsedItems,
      );
  }

  PurchaseInvoice copyWith({
    String? id, String? number, String? supplierId, String? supplierName,
    String? orderId, String? deliveryNoteId, String? projectId, String? projectName,
    String? devisId, String? receivingVoucherId,
    DateTime? date, DateTime? dueDate,
    InvoiceStatus? status, double? totalHT, double? totalTva, double? totalTTC,
    double? amountPaid, double? stampTax, double? timbreFiscal,
    double? globalDiscountPercent, double? globalDiscountAmount,
    String? pricingMode, String? notes, String? conditionsGenerales,
    List<PurchaseInvoiceItem>? items,
    String? firebaseUid, String? creditNoteId, bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => PurchaseInvoice(
        id: id ?? this.id, number: number ?? this.number,
        supplierId: supplierId ?? this.supplierId,
        supplierName: supplierName ?? this.supplierName,
        orderId: orderId ?? this.orderId,
        deliveryNoteId: deliveryNoteId ?? this.deliveryNoteId,
        projectId: projectId ?? this.projectId,
        projectName: projectName ?? this.projectName,
        devisId: devisId ?? this.devisId,
        receivingVoucherId: receivingVoucherId ?? this.receivingVoucherId,
        date: date ?? this.date, dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status, totalHT: totalHT ?? this.totalHT,
        totalTva: totalTva ?? this.totalTva, totalTTC: totalTTC ?? this.totalTTC,
        amountPaid: amountPaid ?? this.amountPaid, stampTax: stampTax ?? this.stampTax,
        timbreFiscal: timbreFiscal ?? this.timbreFiscal,
        globalDiscountPercent: globalDiscountPercent ?? this.globalDiscountPercent,
        globalDiscountAmount: globalDiscountAmount ?? this.globalDiscountAmount,
        pricingMode: pricingMode ?? this.pricingMode,
        notes: notes ?? this.notes, conditionsGenerales: conditionsGenerales ?? this.conditionsGenerales,
        items: items ?? this.items,
        firebaseUid: firebaseUid ?? this.firebaseUid, creditNoteId: creditNoteId ?? this.creditNoteId,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}

class PurchaseInvoiceItem {
  final String id;
  final String purchaseInvoiceId;
  final String productId;
  final String? productName;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final double totalHT;
  final bool showDescription;
  final bool showDiscount;

  PurchaseInvoiceItem({
    required this.id,
    required this.purchaseInvoiceId,
    required this.productId,
    this.productName,
    this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.tvaRate = 19,
    this.discountPercent = 0,
    this.totalHT = 0,
    this.showDescription = false,
    this.showDiscount = false,
  });

  double get computedTotalHT {
    final subtotal = quantity * unitPrice;
    return subtotal - (subtotal * discountPercent / 100);
  }

  double get tvaAmount => computedTotalHT * (tvaRate / 100);
  double get totalTTC => computedTotalHT + tvaAmount;

  Map<String, dynamic> toMap() => {
        'id': id, 'invoice_id': purchaseInvoiceId, 'product_id': productId,
        'description': description, 'quantity': quantity,
        'unit_price': unitPrice, 'tva_rate': tvaRate,
        'discount_percent': discountPercent, 'total_ht': computedTotalHT,
      };

  factory PurchaseInvoiceItem.fromMap(Map<String, dynamic> map) => PurchaseInvoiceItem(
        id: map['id']?.toString() ?? '', purchaseInvoiceId: map['invoice_id']?.toString() ?? '',
        productId: map['product_id']?.toString() ?? '',
        productName: map['product_name']?.toString(),
        description: map['description']?.toString(),
        quantity: double.tryParse(map['quantity']?.toString() ?? '1') ?? 1.0,
        unitPrice: double.tryParse(map['unit_price']?.toString() ?? '0') ?? 0.0,
        tvaRate: double.tryParse(map['tva_rate']?.toString() ?? '19') ?? 19.0,
        discountPercent: double.tryParse(map['discount_percent']?.toString() ?? '0') ?? 0.0,
        totalHT: double.tryParse(map['total_ht']?.toString() ?? '0') ?? 0.0,
      );

  PurchaseInvoiceItem copyWith({
    String? id, String? purchaseInvoiceId, String? productId, String? productName,
    String? description, double? quantity, double? unitPrice, double? tvaRate,
    double? discountPercent, double? totalHT, bool? showDescription, bool? showDiscount,
  }) => PurchaseInvoiceItem(
        id: id ?? this.id, purchaseInvoiceId: purchaseInvoiceId ?? this.purchaseInvoiceId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity, unitPrice: unitPrice ?? this.unitPrice,
        tvaRate: tvaRate ?? this.tvaRate,
        discountPercent: discountPercent ?? this.discountPercent,
        totalHT: totalHT ?? this.totalHT,
        showDescription: showDescription ?? this.showDescription,
        showDiscount: showDiscount ?? this.showDiscount,
      );
}
