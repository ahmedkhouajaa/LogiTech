class DocumentWrapper {
  final String id;
  final String number;
  final String documentTitle; // "FACTURE", "DEVIS", "BON DE LIVRAISON", etc.
  final String? customerName;
  final String? customerId; // ID of the customer or supplier contact
  final DateTime date;
  final DateTime? dueDate;
  final double totalHT;
  final double totalTva;
  final double totalTTC;
  final double stampTax;
  final String? notes;
  final String? conditionsGenerales;
  final List<DocumentItemWrapper> items;
  final String? customerAddress;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerCode;
  final String? customerTaxId;
  final DateTime? validityDate;
  final double? subtotalHT;
  final double? totalDiscountAmount;
  final Map<String, dynamic> customData;

  DocumentWrapper({
    required this.id,
    required this.number,
    required this.documentTitle,
    this.customerName,
    this.customerId,
    this.customerAddress,
    this.customerPhone,
    this.customerEmail,
    this.customerCode,
    this.customerTaxId,
    this.validityDate,
    this.subtotalHT,
    this.totalDiscountAmount,
    required this.date,
    this.dueDate,
    required this.totalHT,
    required this.totalTva,
    required this.totalTTC,
    this.stampTax = 0,
    this.notes,
    this.conditionsGenerales,
    required this.items,
    this.customData = const {},
  });

  /// Creates a copy of this wrapper with optional field overrides.
  /// Used by PdfService to enrich with customer/supplier details from the database.
  DocumentWrapper copyWith({
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? customerEmail,
    String? customerCode,
    String? customerTaxId,
  }) {
    return DocumentWrapper(
      id: id,
      number: number,
      documentTitle: documentTitle,
      customerName: customerName ?? this.customerName,
      customerId: customerId,
      customerAddress: customerAddress ?? this.customerAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerCode: customerCode ?? this.customerCode,
      customerTaxId: customerTaxId ?? this.customerTaxId,
      validityDate: validityDate,
      subtotalHT: subtotalHT,
      totalDiscountAmount: totalDiscountAmount,
      date: date,
      dueDate: dueDate,
      totalHT: totalHT,
      totalTva: totalTva,
      totalTTC: totalTTC,
      stampTax: stampTax,
      notes: notes,
      conditionsGenerales: conditionsGenerales,
      items: items,
      customData: customData,
    );
  }

  double get totalDiscount {
    if (totalDiscountAmount != null) return totalDiscountAmount!;
    if (customData.containsKey('totalDiscount')) {
      return (customData['totalDiscount'] as num?)?.toDouble() ?? 0.0;
    }
    double sum = 0;
    for (final item in items) {
      if (item.discountPercent > 0) {
        sum += (item.quantity * item.unitPrice) * (item.discountPercent / 100);
      }
    }
    return sum;
  }

  static String _extractItemName(dynamic item) {
    try {
      if (item.productName != null && item.productName.toString().trim().isNotEmpty) {
        return item.productName.toString().trim();
      }
    } catch (_) {}
    try {
      if (item.designation != null && item.designation.toString().trim().isNotEmpty) {
        return item.designation.toString().trim();
      }
    } catch (_) {}
    try {
      if (item.description != null && item.description.toString().trim().isNotEmpty) {
        return item.description.toString().trim();
      }
    } catch (_) {}
    return 'Produit Inconnu';
  }

  static String? _extractItemReference(dynamic item) {
    try {
      if (item.reference != null && item.reference.toString().trim().isNotEmpty) {
        return item.reference.toString().trim();
      }
    } catch (_) {}
    try {
      if (item.productCode != null && item.productCode.toString().trim().isNotEmpty) {
        return item.productCode.toString().trim();
      }
    } catch (_) {}
    try {
      if (item.code != null && item.code.toString().trim().isNotEmpty) {
        return item.code.toString().trim();
      }
    } catch (_) {}
    return null;
  }

  static DocumentWrapper fromInvoice(dynamic inv) {
    return DocumentWrapper(
      id: inv.id,
      number: inv.number,
      documentTitle: 'FACTURE',
      customerName: inv.customerName,
      customerId: inv.customerId,
      date: inv.date,
      dueDate: inv.dueDate,
      totalHT: inv.totalHT,
      totalTva: inv.totalTva,
      totalTTC: inv.totalTTC,
      stampTax: inv.timbreFiscal ?? 0,
      notes: inv.notes,
      conditionsGenerales: inv.conditionsGenerales,
      customData: {
        'projectName': inv.projectName,
        'contactType': 'customer',
      },
      items: (inv.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: i.totalHT,
      )).toList(),
    );
  }

  static DocumentWrapper fromQuote(dynamic quote) {
    return DocumentWrapper(
      id: quote.id,
      number: quote.number,
      documentTitle: 'DEVIS',
      customerName: quote.customerName,
      customerId: quote.customerId,
      date: quote.date,
      dueDate: quote.validityDate,
      totalHT: quote.totalHT,
      totalTva: quote.totalTva,
      totalTTC: quote.totalTTC,
      stampTax: quote.timbreFiscal ?? 1.0,
      notes: quote.notes,
      conditionsGenerales: quote.conditionsGenerales,
      customData: {
        'projectName': quote.projectName,
        'contactType': 'customer',
      },
      items: (quote.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: (() { try { return i.computedTotalHT; } catch(_) { return i.totalHT; } })(),
      )).toList(),
    );
  }

  static DocumentWrapper fromCustomerOrder(dynamic order) {
    return DocumentWrapper(
      id: order.id,
      number: order.number,
      documentTitle: 'COMMANDE CLIENT',
      customerName: order.customerName,
      customerId: order.customerId,
      date: order.date,
      dueDate: order.deliveryDate,
      totalHT: order.subTotalHT,
      totalTva: order.totalTVA,
      totalTTC: order.subTotalTTC,
      stampTax: order.timbreFiscal ?? 1.0,
      notes: order.notes,
      conditionsGenerales: order.conditionsGenerales,
      customData: {
        'projectName': order.projectName,
        'contactType': 'customer',
      },
      items: (order.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: i.totalHT,
      )).toList(),
    );
  }

  static DocumentWrapper fromDeliveryNote(dynamic doc) {
    return DocumentWrapper(
      id: doc.id,
      number: doc.number,
      documentTitle: 'BON DE LIVRAISON',
      customerName: doc.customerName,
      customerId: doc.customerId,
      date: doc.date,
      totalHT: doc.subTotalHT,
      totalTva: doc.totalTVA,
      totalTTC: doc.subTotalTTC,
      stampTax: doc.timbreFiscal ?? 1.0,
      notes: doc.notes,
      conditionsGenerales: doc.conditionsGenerales,
      customData: {
        'projectName': doc.projectName,
        'contactType': 'customer',
      },
      items: (doc.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: i.totalHT,
      )).toList(),
    );
  }

  static DocumentWrapper fromStockWithdrawal(dynamic doc) {
    return DocumentWrapper(
      id: doc.id,
      number: doc.number,
      documentTitle: 'BON DE SORTIE',
      customerName: doc.customerName,
      date: doc.date,
      totalHT: doc.subTotalHT,
      totalTva: doc.totalTVA,
      totalTTC: doc.subTotalTTC,
      stampTax: doc.timbreFiscal ?? 0.0,
      notes: doc.notes,
      conditionsGenerales: doc.conditionsGenerales,
      customData: {
        'projectName': doc.projectName,
      },
      items: (doc.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: i.totalHT,
      )).toList(),
    );
  }

  static DocumentWrapper fromPurchaseInvoice(dynamic inv) {
    return DocumentWrapper(
      id: inv.id,
      number: inv.number,
      documentTitle: 'FACTURE D\'ACHAT',
      customerName: inv.supplierName,
      customerId: inv.supplierId,
      date: inv.date,
      dueDate: inv.dueDate,
      totalHT: inv.totalHT,
      totalTva: inv.totalTva,
      totalTTC: inv.totalTTC,
      stampTax: inv.timbreFiscal ?? 0,
      notes: inv.notes,
      conditionsGenerales: inv.conditionsGenerales,
      customData: {
        'contactType': 'supplier',
      },
      items: (inv.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: (() { try { return i.computedTotalHT; } catch(_) { return i.totalHT; } })(),
      )).toList(),
    );
  }

  static DocumentWrapper fromSupplierOrder(dynamic order) {
    return DocumentWrapper(
      id: order.id,
      number: order.number,
      documentTitle: 'COMMANDE FOURNISSEUR',
      customerName: order.supplierName,
      customerId: order.supplierId,
      date: order.date,
      totalHT: order.totalHTAfterDiscount ?? 0,
      totalTva: order.totalTVA ?? 0,
      totalTTC: order.totalTTC ?? 0,
      stampTax: order.timbreFiscal ?? 0,
      notes: order.notes,
      conditionsGenerales: order.conditionsGenerales,
      customData: {
        'contactType': 'supplier',
      },
      items: (order.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: i.discountPercent ?? 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }


  static DocumentWrapper fromReturnNote(dynamic note) {
    String? cId;
    try { cId = note.customerId; } catch (_) {}
    return DocumentWrapper(
      id: note.id,
      number: note.returnNumber ?? note.number,
      documentTitle: 'BON DE RETOUR',
      customerName: note.customerName ?? note.customerCompany ?? 'Client',
      customerId: cId,
      date: note.dateEmission ?? note.date ?? DateTime.now(),
      totalHT: note.subtotalHT ?? 0,
      totalTva: (note.totalTTC ?? 0) - (note.subtotalHT ?? 0),
      totalTTC: note.totalTTC ?? 0,
      notes: note.notes,
      conditionsGenerales: note.conditions,
      customData: {
        'contactType': 'customer',
      },
      items: (note.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromReceivingVoucher(dynamic voucher) {
    String? sId;
    try { sId = voucher.supplierId; } catch (_) {}
    return DocumentWrapper(
      id: voucher.id,
      number: voucher.number,
      documentTitle: 'BON DE RECEPTION',
      customerName: voucher.supplierName,
      customerId: sId,
      date: voucher.date,
      totalHT: voucher.computedTotalHTAfterDiscount ?? 0,
      totalTva: voucher.computedTotalTvaAfterDiscount ?? 0,
      totalTTC: voucher.computedTotalTTC ?? 0,
      stampTax: voucher.timbreFiscal ?? 0,
      notes: voucher.notes,
      conditionsGenerales: voucher.conditionsGenerales,
      customData: {
        'contactType': 'supplier',
      },
      items: (voucher.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantityReceived > 0 ? i.quantityReceived : (i.quantityExpected ?? 0),
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: i.discountPercent ?? 0,
        totalHT: i.computedTotalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromSupplierCreditNote(dynamic note, [String? supplierName]) {
    String? sId;
    try { sId = note.supplierId; } catch (_) {}
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: 'AVOIR FOURNISSEUR',
      customerName: supplierName ?? 'Fournisseur',
      customerId: sId,
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTVA ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.reason,
      customData: {
        'contactType': 'supplier',
      },
      items: (note.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromSupplierReturn(dynamic note) {
    String? sId;
    try { sId = note.supplierId; } catch (_) {}
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: 'RETOUR FOURNISSEUR',
      customerName: note.supplierName ?? 'Fournisseur Inconnu',
      customerId: sId,
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTVA ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.reason,
      customData: {
        'contactType': 'supplier',
      },
      items: (note.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromCreditNote(dynamic note) {
    String? cId;
    try { cId = note.customerId; } catch (_) {}
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: 'AVOIR',
      customerName: note.customerName ?? 'Client Inconnu',
      customerId: cId,
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTva ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.notes,
      customData: {
        'contactType': 'customer',
      },
      items: (note.items as List).map((i) => DocumentItemWrapper(
        productId: i.productId,
        reference: _extractItemReference(i),
        productName: _extractItemName(i),
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: i.discountPercent ?? 0,
        totalHT: (() { try { return i.computedTotalHT; } catch(_) { return i.totalHT; } })(),
      )).toList(),
    );
  }

  static DocumentWrapper fromWithholdingTax(dynamic payment, bool isSales) {
    return DocumentWrapper(
      id: payment.id,
      number: payment.reference ?? payment.paymentNumber,
      documentTitle: isSales ? 'RETENUE A LA SOURCE' : 'CERTIFICAT DE RETENUE',
      customerName: payment.contactName ?? 'Inconnu',
      date: payment.paymentDate,
      totalHT: 0,
      totalTva: 0,
      totalTTC: payment.amount,
      notes: payment.notes,
      items: [
        DocumentItemWrapper(
          productName: 'Retenue à la source',
          quantity: 1,
          unitPrice: payment.amount,
          tvaRate: 0,
          discountPercent: 0,
          totalHT: payment.amount,
        ),
      ],
    );
  }

  static DocumentWrapper fromStockTransfer(dynamic transfer) {
    return DocumentWrapper(
      id: transfer.id,
      number: transfer.number,
      documentTitle: 'BON DE TRANSFERT',
      customerName: 'Inter-Entrepôts',
      date: transfer.date,
      totalHT: 0,
      totalTva: 0,
      totalTTC: 0,
      notes: transfer.notes,
      items: (transfer.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.productName ?? 'Produit Inconnu',
        quantity: i.quantityToTransfer,
        unitPrice: 0,
        tvaRate: 0,
        discountPercent: 0,
        totalHT: 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromInventorySheet(dynamic sheet) {
    return DocumentWrapper(
      id: sheet.id,
      number: sheet.number,
      documentTitle: 'FICHE D\'INVENTAIRE',
      customerName: 'Ajustement de stock',
      date: sheet.date,
      totalHT: 0,
      totalTva: 0,
      totalTTC: 0,
      notes: sheet.notes,
      items: (sheet.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.productName ?? 'Produit Inconnu',
        quantity: i.actualQty,
        unitPrice: 0,
        tvaRate: 0,
        discountPercent: 0,
        totalHT: 0,
      )).toList(),
    );
  }
}

class DocumentItemWrapper {
  final String? productId;
  final String? reference;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final double totalHT;
  final String? unit;
  final Map<String, dynamic> customFields;

  DocumentItemWrapper({
    this.productId,
    this.reference,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.tvaRate,
    required this.discountPercent,
    required this.totalHT,
    this.unit,
    Map<String, dynamic>? customFields,
  }) : customFields = customFields ?? <String, dynamic>{};
}
