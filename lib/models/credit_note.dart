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
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double totalHT;

  const CreditNoteItem({
    required this.id,
    required this.productId,
    this.quantity = 1,
    this.unitPrice = 0,
    this.tvaRate = 19,
    this.totalHT = 0,
  });

  Map<String, dynamic> toMap(String creditNoteId) => {
        'id': id,
        'credit_note_id': creditNoteId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tva_rate': tvaRate,
        'total_ht': totalHT,
      };

  factory CreditNoteItem.fromMap(Map<String, dynamic> map) => CreditNoteItem(
        id: map['id']?.toString() ?? '',
        productId: map['product_id']?.toString() ?? '',
        quantity: double.tryParse(map['quantity']?.toString() ?? '1') ?? 1.0,
        unitPrice: double.tryParse(map['unit_price']?.toString() ?? '0') ?? 0.0,
        tvaRate: double.tryParse(map['tva_rate']?.toString() ?? '19') ?? 19.0,
        totalHT: double.tryParse(map['total_ht']?.toString() ?? '0') ?? 0.0,
      );

  @override
  List<Object?> get props => [
        id,
        productId,
        quantity,
        unitPrice,
        tvaRate,
        totalHT,
      ];
}

class CreditNote extends Equatable {
  final String id;
  final String number;
  final String invoiceId;
  final String customerId;
  final String? customerName;
  final DateTime date;
  final String? reason;
  final CreditNoteStatus status;
  final double totalHT;
  final double totalTva;
  final double totalTTC;
  final String? notes;
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
    required this.date,
    this.reason,
    this.status = CreditNoteStatus.unused,
    this.totalHT = 0,
    this.totalTva = 0,
    this.totalTTC = 0,
    this.notes,
    this.items = const [],
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
    
    return CreditNote(
      id: map['id']?.toString() ?? '',
      number: map['number']?.toString() ?? '',
      invoiceId: map['invoice_id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? map['customer_name']?.toString(),
      date: parsedDate,
      reason: map['reason']?.toString(),
      status: parsedStatus,
      totalHT: double.tryParse(map['total_ht']?.toString() ?? '0') ?? 0.0,
      totalTva: double.tryParse(map['total_tva']?.toString() ?? '0') ?? 0.0,
      totalTTC: double.tryParse(map['total_ttc']?.toString() ?? '0') ?? 0.0,
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
    DateTime? date,
    String? reason,
    CreditNoteStatus? status,
    double? totalHT,
    double? totalTva,
    double? totalTTC,
    String? notes,
    List<CreditNoteItem>? items,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CreditNote(
        id: id ?? this.id,
        number: number ?? this.number,
        invoiceId: invoiceId ?? this.invoiceId,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        date: date ?? this.date,
        reason: reason ?? this.reason,
        status: status ?? this.status,
        totalHT: totalHT ?? this.totalHT,
        totalTva: totalTva ?? this.totalTva,
        totalTTC: totalTTC ?? this.totalTTC,
        notes: notes ?? this.notes,
        items: items ?? this.items,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        number,
        invoiceId,
        customerId,
        date,
        reason,
        status,
        totalHT,
        totalTva,
        totalTTC,
        notes,
        items,
        firebaseUid,
        isDeleted,
        createdAt,
        updatedAt,
      ];
}
