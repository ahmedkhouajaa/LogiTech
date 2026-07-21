import 'package:equatable/equatable.dart';

enum CreditNoteStatus {
  unused,
  partiallyUsed,
  used,
  cancelled;

  String get label {
    switch (this) {
      case unused:
        return 'Non utilisé';
      case partiallyUsed:
        return 'Partiellement utilisé';
      case used:
        return 'Utilisé';
      case cancelled:
        return 'Annulé';
    }
  }
}

class CreditNoteItem extends Equatable {
  final String id;
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

  const CreditNoteItem({
    required this.id,
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

  double get tvaAmount => computedTotalHT * (tvaRate / 100);
  double get totalTTC => computedTotalHT + tvaAmount;
  double get computedTotalHT {
    final base = quantity * unitPrice;
    return base - (base * (discountPercent / 100));
  }

  Map<String, dynamic> toMap(String creditNoteId) => {
        'id': id,
        'credit_note_id': creditNoteId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tva_rate': tvaRate,
        'total_ht': totalHT,
      };

  factory CreditNoteItem.fromMap(Map<String, dynamic> map) {
    final rawQty = double.tryParse(map['quantity']?.toString() ?? '1') ?? 1.0;
    final rawHT = double.tryParse(map['total_ht']?.toString() ?? '0') ?? 0.0;
    return CreditNoteItem(
        id: map['id']?.toString() ?? '',
        productId: map['product_id']?.toString() ?? '',
        quantity: rawQty > 0 ? -rawQty : rawQty,
        unitPrice: double.tryParse(map['unit_price']?.toString() ?? '0') ?? 0.0,
        tvaRate: double.tryParse(map['tva_rate']?.toString() ?? '19') ?? 19.0,
        totalHT: rawHT > 0 ? -rawHT : rawHT,
      );
  }

  CreditNoteItem copyWith({
    String? id,
    String? invoiceId,
    String? productId,
    String? productName,
    String? description,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? discountPercent,
    double? totalHT,
    bool? showDescription,
    bool? showDiscount,
    Map<String, String>? customFields,
  }) {
    return CreditNoteItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      tvaRate: tvaRate ?? this.tvaRate,
      discountPercent: discountPercent ?? this.discountPercent,
      totalHT: totalHT ?? this.totalHT,
      showDescription: showDescription ?? this.showDescription,
      showDiscount: showDiscount ?? this.showDiscount,
      customFields: customFields ?? this.customFields,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        description,
        quantity,
        unitPrice,
        tvaRate,
        discountPercent,
        totalHT,
        showDescription,
        showDiscount,
        customFields,
      ];
}

class CreditNote extends Equatable {
  final String id;
  final String number;
  final String invoiceId;
  final String customerId;
  final String? customerName;
  final String? projectId;
  final DateTime date;
  final DateTime dueDate;
  final String? reason;
  final CreditNoteStatus status;
  final double totalHT;
  final double totalTva;
  final double totalTTC;
  final double stampTax;
  final double timbreFiscal;
  final double globalDiscountPercent;
  final double globalDiscountAmount;
  final String pricingMode; // 'ht' or 'ttc'
  final String? notes;
  final String? conditionsGenerales;
  final List<CreditNoteItem> items;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  CreditNote({
    required this.id,
    required this.number,
    required this.invoiceId,
    required this.customerId,
    this.customerName,
    this.projectId,
    required this.date,
    DateTime? dueDate,
    this.reason,
    this.status = CreditNoteStatus.unused,
    this.totalHT = 0,
    this.totalTva = 0,
    this.totalTTC = 0,
    this.stampTax = 0,
    this.timbreFiscal = 0,
    this.globalDiscountPercent = 0,
    this.globalDiscountAmount = 0,
    this.pricingMode = 'ht',
    this.notes,
    this.conditionsGenerales,
    this.items = const [],
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        dueDate = dueDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'invoice_id': invoiceId,
        'customer_id': customerId,
        'date': date.millisecondsSinceEpoch.toString(),
        'reason': reason,
        'status': status.name,
        'total_ht': totalHT,
        'total_tva': totalTva,
        'total_ttc': totalTTC,
        'notes': notes,
        'firebase_uid': firebaseUid,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'items': items.map((i) => i.toMap(id)).toList(),
      };

  factory CreditNote.fromMap(Map<String, dynamic> map, {List<CreditNoteItem>? items}) {
    CreditNoteStatus parsedStatus = CreditNoteStatus.unused;
    if (map['status'] != null) {
      parsedStatus = CreditNoteStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CreditNoteStatus.unused,
      );
    }
    
    List<CreditNoteItem> parsedItems = items ?? [];
    if (parsedItems.isEmpty && map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List).map((i) => CreditNoteItem.fromMap(Map<String, dynamic>.from(i))).toList();
    }
    
    DateTime parsedDate = DateTime.now();
    if (map['date'] != null) {
      int? ms = int.tryParse(map['date'].toString());
      if (ms != null) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(ms);
      } else {
        parsedDate = DateTime.tryParse(map['date'].toString()) ?? DateTime.now();
      }
    }
    
    final rawHT = double.tryParse(map['total_ht']?.toString() ?? '0') ?? 0.0;
    final rawTva = double.tryParse(map['total_tva']?.toString() ?? '0') ?? 0.0;
    final rawTTC = double.tryParse(map['total_ttc']?.toString() ?? '0') ?? 0.0;

    return CreditNote(
      id: map['id']?.toString() ?? '',
      number: map['number']?.toString() ?? '',
      invoiceId: map['invoice_id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      customerName: map['customer_name']?.toString(),
      date: parsedDate,
      reason: map['reason']?.toString(),
      status: parsedStatus,
      totalHT: rawHT > 0 ? -rawHT : rawHT,
      totalTva: rawTva > 0 ? -rawTva : rawTva,
      totalTTC: rawTTC > 0 ? -rawTTC : rawTTC,
      notes: map['notes']?.toString(),
      items: parsedItems,
      firebaseUid: map['firebase_uid']?.toString(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == '1' || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  CreditNote copyWith({
    String? id,
    String? number,
    String? invoiceId,
    String? customerId,
    String? customerName,
    String? projectId,
    DateTime? date,
    DateTime? dueDate,
    String? reason,
    CreditNoteStatus? status,
    double? totalHT,
    double? totalTva,
    double? totalTTC,
    double? stampTax,
    double? timbreFiscal,
    double? globalDiscountPercent,
    double? globalDiscountAmount,
    String? pricingMode,
    String? notes,
    String? conditionsGenerales,
    List<CreditNoteItem>? items,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditNote(
      id: id ?? this.id,
      number: number ?? this.number,
      invoiceId: invoiceId ?? this.invoiceId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      projectId: projectId ?? this.projectId,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      totalHT: totalHT ?? this.totalHT,
      totalTva: totalTva ?? this.totalTva,
      totalTTC: totalTTC ?? this.totalTTC,
      stampTax: stampTax ?? this.stampTax,
      timbreFiscal: timbreFiscal ?? this.timbreFiscal,
      globalDiscountPercent: globalDiscountPercent ?? this.globalDiscountPercent,
      globalDiscountAmount: globalDiscountAmount ?? this.globalDiscountAmount,
      pricingMode: pricingMode ?? this.pricingMode,
      notes: notes ?? this.notes,
      conditionsGenerales: conditionsGenerales ?? this.conditionsGenerales,
      items: items ?? this.items,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        number,
        invoiceId,
        customerId,
        customerName,
        projectId,
        date,
        dueDate,
        reason,
        status,
        totalHT,
        totalTva,
        totalTTC,
        stampTax,
        timbreFiscal,
        globalDiscountPercent,
        globalDiscountAmount,
        pricingMode,
        notes,
        conditionsGenerales,
        items,
        firebaseUid,
        isDeleted,
        createdAt,
        updatedAt,
      ];
}
