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
  final String? documentType; // e.g. 'invoice', 'purchase_invoice', 'quote', etc.
  final Map<String, dynamic> customData;
  final Map<String, dynamic>? _customFields;

  Map<String, dynamic> get customFields {
    final cf = _customFields;
    if (cf != null && cf.isNotEmpty) {
      return Map<String, dynamic>.from(cf);
    }
    if (customData['customFields'] is Map) {
      return Map<String, dynamic>.from(customData['customFields'] as Map);
    }
    return const {};
  }

  DocumentWrapper({
    required this.id,
    required this.number,
    required this.documentTitle,
    this.documentType,
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
    Map<String, dynamic>? customFields,
  }) : _customFields = customFields;

  /// Creates a copy of this wrapper with optional field overrides.
  /// Used by PdfService to enrich with customer/supplier details from the database.
  DocumentWrapper copyWith({
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? customerEmail,
    String? customerCode,
    String? customerTaxId,
    String? documentType,
    Map<String, dynamic>? customFields,
  }) {
    return DocumentWrapper(
      id: id,
      number: number,
      documentTitle: documentTitle,
      documentType: documentType ?? this.documentType,
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
      customFields: customFields ?? _customFields,
    );
  }

  /// Resolves the canonical document type key for template matching.
  String get resolvedDocumentType {
    if (documentType != null && documentType!.isNotEmpty) return documentType!;
    final title = documentTitle.toUpperCase().trim();
    if (title.contains('FACTURE D\'ACHAT') || title.contains('FACTURE ACHAT')) return 'purchase_invoice';
    if (title.contains('COMMANDE FOURNISSEUR')) return 'supplier_order';
    if (title.contains('RECEPTION') || title.contains('RÉCEPTION')) return 'receiving_voucher';
    if (title.contains('AVOIR FOURNISSEUR')) return 'supplier_credit_note';
    if (title.contains('RETOUR FOURNISSEUR')) return 'supplier_return';
    if (title.contains("ENTRÉE") || title.contains("ENTREE")) return 'stock_entry';
    if (title.contains('PRÉLÈVEMENT') || title.contains('PRELEVEMENT')) return 'stock_withdrawal';
    if (title.contains('SORTIE')) return 'exit_voucher';
    if (title.contains('TRANSFERT')) return 'stock_transfer';
    if (title.contains('INVENTAIRE')) return 'inventory_sheet';
    if (title.contains('DEVIS')) return 'quote';
    if (title.contains('COMMANDE')) return 'customer_order';
    if (title.contains('LIVRAISON')) return 'delivery_note';
    if (title.contains('AVOIR')) return 'credit_note';
    if (title.contains('RETOUR')) return 'return_voucher';
    if (title.contains('FACTURE')) return 'invoice';
    return 'invoice';
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
      documentType: 'invoice',
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
        if (inv.customFields is Map) 'customFields': Map<String, dynamic>.from(inv.customFields as Map),
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
      documentType: 'quote',
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
        if (quote.customFields is Map) 'customFields': Map<String, dynamic>.from(quote.customFields as Map),
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
      documentType: 'customer_order',
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
        if (order.customFields is Map) 'customFields': Map<String, dynamic>.from(order.customFields as Map),
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
      documentType: 'delivery_note',
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
        if (doc.customFields is Map) 'customFields': Map<String, dynamic>.from(doc.customFields as Map),
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

  static DocumentWrapper fromExitVoucher(dynamic doc) {
    final client = (doc.customerCompany != null && doc.customerCompany.toString().trim().isNotEmpty)
        ? doc.customerCompany.toString().trim()
        : (doc.customerName != null && doc.customerName.toString().trim().isNotEmpty ? doc.customerName.toString().trim() : 'Client divers');
    return DocumentWrapper(
      id: doc.id,
      number: doc.number,
      documentTitle: 'BON DE SORTIE',
      documentType: 'exit_voucher',
      customerName: client,
      customerId: doc.customerId,
      date: doc.date,
      totalHT: doc.subTotalHT,
      totalTva: doc.totalTVA,
      totalTTC: doc.subTotalTTC,
      stampTax: doc.timbreFiscal ?? 0.0,
      notes: doc.notes,
      conditionsGenerales: doc.conditionsGenerales,
      customFields: doc.customFields is Map ? Map<String, dynamic>.from(doc.customFields as Map) : null,
      customData: {
        'projectName': doc.projectName,
        'driverName': doc.driverName,
        'vehicleRegistration': doc.vehicleRegistration,
        if (doc.customFields is Map) 'customFields': Map<String, dynamic>.from(doc.customFields as Map),
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

  static DocumentWrapper fromStockWithdrawal(dynamic doc, [String? warehouseName]) {
    return DocumentWrapper(
      id: doc.id,
      number: doc.number,
      documentTitle: 'BON DE PRÉLÈVEMENT',
      documentType: 'stock_withdrawal',
      customerName: null,
      date: doc.date,
      totalHT: doc.subTotalHT,
      totalTva: doc.totalTVA,
      totalTTC: doc.subTotalTTC,
      notes: doc.notes,
      conditionsGenerales: doc.conditionsGenerales,
      customFields: doc.customFields is Map ? Map<String, dynamic>.from(doc.customFields as Map) : null,
      customData: {
        'warehouseId': doc.warehouseId,
        'warehouseName': warehouseName ?? doc.warehouseId ?? 'Entrepôt par défaut',
        'createdBy': doc.createdBy ?? 'Admin',
        if (doc.customFields is Map) 'customFields': Map<String, dynamic>.from(doc.customFields as Map),
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
        customFields: {
          'code': _extractItemReference(i),
          'unit': 'pièce',
          'purchasePrice': i.unitPrice,
        },
      )).toList(),
    );
  }

  static DocumentWrapper fromPurchaseInvoice(dynamic inv) {
    return DocumentWrapper(
      id: inv.id,
      number: inv.number,
      documentTitle: 'FACTURE D\'ACHAT',
      documentType: 'purchase_invoice',
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
        if (inv.customFields is Map) 'customFields': Map<String, dynamic>.from(inv.customFields as Map),
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
      documentType: 'supplier_order',
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
        if (order.customFields is Map) 'customFields': Map<String, dynamic>.from(order.customFields as Map),
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
      documentType: 'return_voucher',
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
        if (note.customFields is Map) 'customFields': Map<String, dynamic>.from(note.customFields as Map),
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
      documentType: 'receiving_voucher',
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
        if (voucher.customFields is Map) 'customFields': Map<String, dynamic>.from(voucher.customFields as Map),
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
      documentType: 'supplier_credit_note',
      customerName: supplierName ?? 'Fournisseur',
      customerId: sId,
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTVA ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.reason,
      customData: {
        'contactType': 'supplier',
        if (note.customFields is Map) 'customFields': Map<String, dynamic>.from(note.customFields as Map),
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
      documentType: 'supplier_return',
      customerName: note.supplierName ?? 'Fournisseur Inconnu',
      customerId: sId,
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTVA ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.reason,
      customData: {
        'contactType': 'supplier',
        if (note.customFields is Map) 'customFields': Map<String, dynamic>.from(note.customFields as Map),
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
      documentType: 'credit_note',
      customerName: note.customerName ?? 'Client Inconnu',
      customerId: cId,
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTva ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.notes,
      customData: {
        'contactType': 'customer',
        if (note.customFields is Map) 'customFields': Map<String, dynamic>.from(note.customFields as Map),
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
      documentType: 'stock_transfer',
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
      documentType: 'inventory_sheet',
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

  static DocumentWrapper fromStockEntry(dynamic entry, [String? warehouseName]) {
    return DocumentWrapper(
      id: entry.id,
      number: entry.number,
      documentTitle: "BON D'ENTRÉE",
      documentType: 'stock_entry',
      date: entry.date,
      totalHT: (entry.items as List).fold(0.0, (sum, i) => sum + (i.quantity * i.unitPrice)),
      totalTva: 0.0,
      totalTTC: (entry.items as List).fold(0.0, (sum, i) => sum + (i.quantity * i.unitPrice)),
      notes: entry.notes,
      customFields: (() {
        try {
          if (entry.customFields is Map) return Map<String, dynamic>.from(entry.customFields as Map);
        } catch (_) {}
        return null;
      })(),
      items: (entry.items as List).map((item) {
        return DocumentItemWrapper(
          productId: item.productId,
          productName: 'Article',
          quantity: (item.quantity as num).toDouble(),
          unitPrice: (item.unitPrice as num).toDouble(),
          tvaRate: 0.0,
          discountPercent: 0.0,
          totalHT: (item.quantity as num).toDouble() * (item.unitPrice as num).toDouble(),
        );
      }).toList(),
      customData: {
        'warehouseId': entry.warehouseId,
        if (warehouseName != null) 'warehouseName': warehouseName,
      },
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
