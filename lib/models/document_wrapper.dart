import 'package:flutter/foundation.dart';

class DocumentWrapper {
  final String id;
  final String number;
  final String documentTitle; // "FACTURE", "DEVIS", "BON DE LIVRAISON", etc.
  final String? customerName;
  final DateTime date;
  final DateTime? dueDate;
  final double totalHT;
  final double totalTva;
  final double totalTTC;
  final double stampTax;
  final String? notes;
  final String? conditionsGenerales;
  final List<DocumentItemWrapper> items;
  final Map<String, dynamic> customData;

  DocumentWrapper({
    required this.id,
    required this.number,
    required this.documentTitle,
    this.customerName,
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

  static DocumentWrapper fromInvoice(dynamic inv) {
    return DocumentWrapper(
      id: inv.id,
      number: inv.number,
      documentTitle: 'FACTURE',
      customerName: inv.customerName,
      date: inv.date,
      dueDate: inv.dueDate,
      totalHT: inv.totalHT,
      totalTva: inv.totalTva,
      totalTTC: inv.totalTTC,
      stampTax: (inv.runtimeType.toString() == 'Invoice') ? inv.timbreFiscal ?? 0 : 0,
      notes: inv.notes,
      items: (inv.items as List).map((i) => DocumentItemWrapper(
        productName: i.productName ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: (i.runtimeType.toString() == 'InvoiceItem') ? i.computedTotalHT : i.totalHT,
      )).toList(),
    );
  }

  static DocumentWrapper fromQuote(dynamic quote) {
    return DocumentWrapper(
      id: quote.id,
      number: quote.number,
      documentTitle: 'DEVIS',
      customerName: quote.customerName,
      date: quote.date,
      dueDate: quote.validityDate,
      totalHT: quote.totalHT,
      totalTva: quote.totalTva,
      totalTTC: quote.totalTTC,
      notes: quote.notes,
      items: (quote.items as List).map((i) => DocumentItemWrapper(
        productName: i.productName ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: (i.runtimeType.toString() == 'QuoteItem') ? i.computedTotalHT : i.totalHT,
      )).toList(),
    );
  }

  static DocumentWrapper fromDeliveryNote(dynamic doc) {
    return DocumentWrapper(
      id: doc.id,
      number: doc.number,
      documentTitle: 'BON DE SORTIE',
      customerName: doc.customerName,
      date: doc.date,
      totalHT: doc.totalHTAfterDiscount,
      totalTva: doc.totalTVA,
      totalTTC: doc.totalTTC,
      stampTax: doc.timbreFiscal,
      notes: doc.notes,
      conditionsGenerales: doc.conditionsGenerales,
      items: (doc.items as List).map((i) => DocumentItemWrapper(
        productName: 'Produit Inconnu', // DeliveryNoteItem often doesn't have productName directly, we can fetch it or just show description
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
      date: inv.date,
      dueDate: inv.dueDate,
      totalHT: inv.totalHT,
      totalTva: inv.totalTva,
      totalTTC: inv.totalTTC,
      stampTax: inv.timbreFiscal ?? 0,
      notes: inv.notes,
      items: (inv.items as List).map((i) => DocumentItemWrapper(
        productName: (i.runtimeType.toString() == 'PurchaseInvoiceItem' ? i.productName : null) ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        totalHT: (i.runtimeType.toString() == 'PurchaseInvoiceItem') ? i.computedTotalHT : i.totalHT,
      )).toList(),
    );
  }

  static DocumentWrapper fromSupplierOrder(dynamic order) {
    return DocumentWrapper(
      id: order.id,
      number: order.number,
      documentTitle: 'COMMANDE FOURNISSEUR',
      customerName: order.supplierName,
      date: order.date,
      totalHT: order.totalHTAfterDiscount ?? 0,
      totalTva: order.totalTVA ?? 0,
      totalTTC: order.totalTTC ?? 0,
      stampTax: order.timbreFiscal ?? 0,
      notes: order.notes,
      items: (order.items as List).map((i) => DocumentItemWrapper(
        productName: (i.runtimeType.toString() == 'SupplierOrderItem' ? i.description : null) ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: i.discountPercent ?? 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromCustomerOrder(dynamic order) {
    return DocumentWrapper(
      id: order.id,
      number: order.number,
      documentTitle: 'COMMANDE',
      customerName: order.customerName,
      date: order.date,
      dueDate: order.deliveryDate,
      totalHT: order.totalHTAfterDiscount ?? 0,
      totalTva: order.totalTVA ?? 0,
      totalTTC: order.totalTTC ?? 0,
      notes: order.notes,
      items: (order.items as List).map((i) => DocumentItemWrapper(
        productName: i.description ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: i.discountPercent ?? 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromReturnNote(dynamic note) {
    return DocumentWrapper(
      id: note.id,
      number: note.returnNumber ?? note.number,
      documentTitle: 'BON DE RETOUR',
      customerName: note.customerName ?? note.customerCompany ?? 'Client',
      date: note.dateEmission ?? note.date ?? DateTime.now(),
      totalHT: note.subtotalHT ?? 0,
      totalTva: (note.totalTTC ?? 0) - (note.subtotalHT ?? 0),
      totalTTC: note.totalTTC ?? 0,
      notes: note.notes,
      items: (note.items as List).map((i) => DocumentItemWrapper(
        productName: i.designation ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromReceivingVoucher(dynamic voucher) {
    return DocumentWrapper(
      id: voucher.id,
      number: voucher.number,
      documentTitle: 'BON DE RECEPTION',
      customerName: voucher.supplierName,
      date: voucher.date,
      totalHT: 0,
      totalTva: 0,
      totalTTC: 0,
      notes: voucher.notes,
      items: (voucher.items as List).map((i) => DocumentItemWrapper(
        productName: 'Produit Inconnu', // ReceivingVoucherItem doesn't store productName natively in the model
        quantity: i.quantityReceived ?? i.quantityExpected ?? 0,
        unitPrice: 0,
        tvaRate: 0,
        discountPercent: 0,
        totalHT: 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromSupplierCreditNote(dynamic note) {
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: 'AVOIR FOURNISSEUR',
      customerName: note.supplierName,
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTVA ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.notes,
      items: (note.items as List).map((i) => DocumentItemWrapper(
        productName: i.designation ?? i.productName ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromSupplierReturn(dynamic note) {
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: 'RETOUR FOURNISSEUR',
      customerName: note.supplierName,
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTVA ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.notes,
      items: (note.items as List).map((i) => DocumentItemWrapper(
        productName: i.designation ?? i.productName ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: 0,
        totalHT: i.totalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromCreditNote(dynamic note) {
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: 'AVOIR',
      customerName: note.customerName ?? 'Client Inconnu',
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTva ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.notes,
      items: (note.items as List).map((i) => DocumentItemWrapper(
        productName: i.productName ?? 'Produit Inconnu',
        quantity: i.quantity,
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: i.discountPercent ?? 0,
        totalHT: (i.runtimeType.toString() == 'CreditNoteItem') ? i.computedTotalHT : i.totalHT,
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
}

class DocumentItemWrapper {
  final String productName;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final double totalHT;
  final Map<String, dynamic> customFields;

  DocumentItemWrapper({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.tvaRate,
    required this.discountPercent,
    required this.totalHT,
    this.customFields = const {},
  });
}
