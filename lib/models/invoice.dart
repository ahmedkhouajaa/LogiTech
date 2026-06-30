import 'dart:convert';
import '../utils/constants.dart';

class Invoice {
  final String id;
  final String number;
  final String customerId;
  final String? customerName;
  final String? orderId;
  final String? deliveryNoteId;
  final String? projectId;
  final String? projectName;
  final String? devisId;
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
  final List<InvoiceItem> items;
  final String? firebaseUid;
  final String? creditNoteId;
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
    this.projectId,
    this.projectName,
    this.devisId,
    required this.date,
    required this.dueDate,
    this.status = InvoiceStatus.draft,
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
        'id': id, 'number': number, 'customer_id': customerId,
        'order_id': orderId, 'delivery_note_id': deliveryNoteId,
        'project_id': projectId, 'devis_id': devisId,
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

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'] as String, number: map['number'] as String,
        customerId: map['customer_id'] as String,
        customerName: map['customer_name'] as String?,
        orderId: map['order_id'] as String?,
        deliveryNoteId: map['delivery_note_id'] as String?,
        projectId: map['project_id'] as String?,
        projectName: map['project_name'] as String?,
        devisId: map['devis_id'] as String?,
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
        timbreFiscal: (map['timbre_fiscal'] as num?)?.toDouble() ?? 0,
        globalDiscountPercent: (map['global_discount_percent'] as num?)?.toDouble() ?? 0,
        globalDiscountAmount: (map['global_discount_amount'] as num?)?.toDouble() ?? 0,
        pricingMode: map['pricing_mode'] as String? ?? 'ht',
        notes: map['notes'] as String?,
        conditionsGenerales: map['conditions'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        creditNoteId: map['credit_note_id'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Invoice copyWith({
    String? id, String? number, String? customerId, String? customerName,
    String? orderId, String? deliveryNoteId, String? projectId, String? projectName,
    String? devisId,
    DateTime? date, DateTime? dueDate,
    InvoiceStatus? status, double? totalHT, double? totalTva, double? totalTTC,
    double? amountPaid, double? stampTax, double? timbreFiscal,
    double? globalDiscountPercent, double? globalDiscountAmount,
    String? pricingMode, String? notes, String? conditionsGenerales,
    List<InvoiceItem>? items,
    String? firebaseUid, String? creditNoteId, bool? isDeleted, DateTime? createdAt, DateTime? updatedAt,
  }) => Invoice(
        id: id ?? this.id, number: number ?? this.number,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        orderId: orderId ?? this.orderId,
        deliveryNoteId: deliveryNoteId ?? this.deliveryNoteId,
        projectId: projectId ?? this.projectId,
        projectName: projectName ?? this.projectName,
        devisId: devisId ?? this.devisId,
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
  final bool showDescription;
  final bool showDiscount;
  final Map<String, String> customFields;

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
    this.showDescription = false,
    this.showDiscount = false,
    this.customFields = const {},
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
        'custom_fields_json': jsonEncode(customFields),
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
        customFields: _parseCustomFields(map['custom_fields_json'] as String?),
      );

  static Map<String, String> _parseCustomFields(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  InvoiceItem copyWith({
    String? id, String? invoiceId, String? productId, String? productName,
    String? description, double? quantity, double? unitPrice, double? tvaRate,
    double? discountPercent, double? totalHT, bool? showDescription, bool? showDiscount,
    Map<String, String>? customFields,
  }) => InvoiceItem(
        id: id ?? this.id, invoiceId: invoiceId ?? this.invoiceId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity, unitPrice: unitPrice ?? this.unitPrice,
        tvaRate: tvaRate ?? this.tvaRate,
        discountPercent: discountPercent ?? this.discountPercent,
        totalHT: totalHT ?? this.totalHT,
        showDescription: showDescription ?? this.showDescription,
        showDiscount: showDiscount ?? this.showDiscount,
        customFields: customFields ?? this.customFields,
      );
}
