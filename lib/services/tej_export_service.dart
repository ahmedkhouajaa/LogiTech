import 'package:xml/xml.dart';
import '../models/payment_model.dart';
import '../models/supplier.dart';
import '../models/purchase_invoice.dart';
import '../database/database_helper.dart';
import '../utils/file_download_helper.dart';

class TejExportService {
  static Future<String?> exportAchats(List<Payment> payments, int year, int month) async {
    try {
      // Fetch dependencies beforehand
      final suppliers = await DatabaseHelper.instance.getSuppliers();
      final invoices = await DatabaseHelper.instance.getPurchaseInvoices();

      final builder = XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="UTF-8"');
      
      // Convert month to MM format
      final monthStr = month.toString().padLeft(2, '0');
      
      builder.element('DeclarationsRS', attributes: {'VersionSchema': '1.0'}, nest: () {
        // Declarant
        builder.element('Declarant', nest: () {
          builder.element('TypeIdentifiant', nest: '1');
          builder.element('Identifiant', nest: '1234567B');
          builder.element('CategorieContribuable', nest: 'PM');
        });

        // ReferenceDeclaration
        builder.element('ReferenceDeclaration', nest: () {
          builder.element('ActeDepot', nest: '0');
          builder.element('AnneeDepot', nest: year.toString());
          builder.element('MoisDepot', nest: monthStr);
        });

        builder.element('AjouterCertificats', nest: () {
          for (var payment in payments) {
            // Safe lookup for Supplier
            final supplier = suppliers.firstWhere(
              (s) => s.id == payment.contactId,
              orElse: () => Supplier(
                id: payment.contactId,
                code: '',
                name: payment.contactName ?? 'Inconnu',
              ),
            );
            
            // Safe lookup for Invoice
            final invoice = invoices.firstWhere(
              (inv) => inv.id == payment.relatedInvoiceId,
              orElse: () => PurchaseInvoice(
                id: payment.relatedInvoiceId ?? '',
                number: payment.reference ?? payment.paymentNumber,
                supplierId: payment.contactId,
                date: payment.paymentDate,
                dueDate: payment.paymentDate,
                totalHT: payment.amount,
                totalTva: 0.0,
                totalTTC: payment.amount,
              ),
            );

            // Compute Amounts
            final montantHt = invoice.totalHT > 0 
                ? invoice.totalHT 
                : payment.amount;
            final montantTva = invoice.totalTva;
            final montantTtc = invoice.totalTTC > 0 
                ? invoice.totalTTC 
                : payment.amount;
            final montantRs = payment.amount;
            final montantNetServi = (montantTtc - montantRs).clamp(0.0, double.infinity);

            builder.element('Certificat', nest: () {
              builder.element('Beneficiaire', nest: () {
                builder.element('TypeIdentifiant', nest: '1');
                builder.element('Identifiant', nest: supplier.taxId ?? '0000000A');
                builder.element('RaisonSociale', nest: supplier.name);
                builder.element('Activite', nest: 'Commerce');
                builder.element('Adresse', nest: supplier.address ?? 'Tunisie');
              });

              builder.element('ListeFactures', nest: () {
                builder.element('Facture', nest: () {
                  builder.element('NumFacture', nest: invoice.number.isNotEmpty ? invoice.number : payment.paymentNumber);
                  builder.element('DateFacture', nest: invoice.date.toIso8601String().split('T')[0]);
                  builder.element('MontantHT', nest: montantHt.toString());
                  builder.element('MontantTVA', nest: montantTva.toString());
                  builder.element('MontantTTC', nest: montantTtc.toString());
                });
              });

              builder.element('ListeRetenues', nest: () {
                builder.element('Retenue', nest: () {
                  builder.element('CodeRetenue', nest: '1'); // Standard Code
                  builder.element('Taux', nest: '1.5');
                  builder.element('BaseImposable', nest: montantTtc.toString());
                  builder.element('MontantRS', nest: montantRs.toString());
                  builder.element('MontantNetServi', nest: montantNetServi.toString());
                });
              });
              
              builder.element('TotalPayement', nest: () {
                builder.element('TotalMontantHT', nest: montantHt.toString());
                builder.element('TotalMontantTVA', nest: montantTva.toString());
                builder.element('TotalMontantTTC', nest: montantTtc.toString());
                builder.element('TotalMontantRS', nest: montantRs.toString());
                builder.element('TotalMontantNetServi', nest: montantNetServi.toString());
              });
            });
          }
        });
      });

      final document = builder.buildDocument();
      final xmlString = document.toXmlString(pretty: true, indent: '  ');
      
      final fileName = 'RS_Achat_${monthStr}${year}.xml';
      final filePath = await FileDownloadHelper.saveStringFile(
        xmlString,
        fileName,
        mimeType: 'application/xml',
      );
      return filePath;
    } catch (e, stack) {
      print('Error generating/saving TEJ XML: $e');
      print(stack);
      rethrow;
    }
  }
}
