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
      stampTax: inv.timbreFiscal ?? 0,
      notes: inv.notes,
      conditionsGenerales: inv.conditionsGenerales,
      customData: {
        'projectName': inv.projectName,
      },
      items: (inv.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.productName ?? i.description ?? 'Produit Inconnu',
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
      },
      items: (quote.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.productName ?? 'Produit Inconnu',
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
      },
      items: (order.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.description ?? 'Produit Inconnu',
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
      date: doc.date,
      totalHT: doc.subTotalHT,
      totalTva: doc.totalTVA,
      totalTTC: doc.subTotalTTC,
      stampTax: doc.timbreFiscal ?? 1.0,
      notes: doc.notes,
      conditionsGenerales: doc.conditionsGenerales,
      customData: {
        'projectName': doc.projectName,
      },
      items: (doc.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.description ?? 'Produit Inconnu',
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
      items: (doc.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.description ?? 'Produit Inconnu',
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
      conditionsGenerales: inv.conditionsGenerales,
      items: (inv.items as List).map((i) {
        String pName = 'Produit Inconnu';
        try { pName = i.productName ?? 'Produit Inconnu'; } catch (_) {}
        try { pName = i.description ?? pName; } catch (_) {}
        
        return DocumentItemWrapper(productId: i.productId,
          productName: pName,
          quantity: i.quantity,
          unitPrice: i.unitPrice,
          tvaRate: i.tvaRate,
          discountPercent: i.discountPercent,
          totalHT: (() { try { return i.computedTotalHT; } catch(_) { return i.totalHT; } })(),
        );
      }).toList(),
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
      conditionsGenerales: order.conditionsGenerales,
      items: (order.items as List).map((i) {
        String pName = 'Produit Inconnu';
        try { pName = i.description ?? 'Produit Inconnu'; } catch (_) {}
        try { pName = i.productName ?? pName; } catch (_) {}
        
        return DocumentItemWrapper(productId: i.productId,
          productName: pName,
          quantity: i.quantity,
          unitPrice: i.unitPrice ?? 0,
          tvaRate: i.tvaRate ?? 0,
          discountPercent: i.discountPercent ?? 0,
          totalHT: i.totalHT ?? 0,
        );
      }).toList(),
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
      conditionsGenerales: note.conditions,
      items: (note.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
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
      totalHT: voucher.computedTotalHTAfterDiscount ?? 0,
      totalTva: voucher.computedTotalTvaAfterDiscount ?? 0,
      totalTTC: voucher.computedTotalTTC ?? 0,
      stampTax: voucher.timbreFiscal ?? 0,
      notes: voucher.notes,
      conditionsGenerales: voucher.conditionsGenerales,
      items: (voucher.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.productName ?? 'Produit Inconnu',
        quantity: i.quantityReceived > 0 ? i.quantityReceived : (i.quantityExpected ?? 0),
        unitPrice: i.unitPrice ?? 0,
        tvaRate: i.tvaRate ?? 0,
        discountPercent: i.discountPercent ?? 0,
        totalHT: i.computedTotalHT ?? 0,
      )).toList(),
    );
  }

  static DocumentWrapper fromSupplierCreditNote(dynamic note, [String? supplierName]) {
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: 'AVOIR FOURNISSEUR',
      customerName: supplierName ?? 'Fournisseur',
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTVA ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.reason,
      items: (note.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.designation ?? 'Produit Inconnu',
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
      customerName: note.supplierName ?? 'Fournisseur Inconnu',
      date: note.date,
      totalHT: note.totalHT ?? 0,
      totalTva: note.totalTVA ?? 0,
      totalTTC: note.totalTTC ?? 0,
      notes: note.reason,
      items: (note.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.designation ?? 'Produit Inconnu',
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
      items: (note.items as List).map((i) => DocumentItemWrapper(productId: i.productId,
        productName: i.productName ?? 'Produit Inconnu',
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
  final String productName;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final double totalHT;
  final Map<String, dynamic> customFields;

  DocumentItemWrapper({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.tvaRate,
    required this.discountPercent,
    required this.totalHT,
    Map<String, dynamic>? customFields,
  }) : customFields = customFields ?? <String, dynamic>{};
}
