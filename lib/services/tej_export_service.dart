import 'dart:io';
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import '../models/supplier.dart';
import '../models/purchase_invoice.dart';
import '../database/database_helper.dart';

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
                totalTva: 0,
                totalTTC: payment.amount,
              ),
            );

            final double ht = invoice.totalHT > 0 ? invoice.totalHT : payment.amount;
            final double tva = invoice.totalTva;
            final double ttc = invoice.totalTTC > 0 ? invoice.totalTTC : payment.amount;
            final double rs = payment.amount;

            // Calculations (multiplying by 1000 for millimes)
            final int montantHt = (ht * 1000).round();
            final int montantTva = (tva * 1000).round();
            final int montantTtc = (ttc * 1000).round();
            final int montantRs = (rs * 1000).round();
            final int montantNetServi = montantTtc - montantRs;
            
            double tauxRs = 1.0;
            if (montantTtc > 0) {
               tauxRs = (montantRs / montantTtc) * 100;
            }
            
            double tauxTva = 0.0;
            if (montantHt > 0) {
               tauxTva = (montantTva / montantHt) * 100;
            }

            builder.element('Certificat', nest: () {
              builder.element('Beneficiaire', nest: () {
                builder.element('IdTaxpayer', nest: () {
                  builder.element('MatriculeFiscal', nest: () {
                    builder.element('TypeIdentifiant', nest: '1');
                    builder.element('Identifiant', nest: (supplier.taxId != null && supplier.taxId!.isNotEmpty) ? supplier.taxId! : '0000000A');
                    builder.element('CategorieContribuable', nest: 'PM');
                  });
                });
                builder.element('Resident', nest: '1');
                builder.element('NometprenonOuRaisonsociale', nest: supplier.name);
                builder.element('Adresse', nest: (supplier.address != null && supplier.address!.isNotEmpty) ? supplier.address! : 'Rue de Syrie');
                
                builder.element('InfosContact', nest: () {
                  builder.element('AdresseMail', nest: supplier.email ?? '');
                  builder.element('NumTel', nest: supplier.phone ?? '');
                });
              });
              
              builder.element('DatePayement', nest: DateFormat('dd/MM/yyyy').format(payment.paymentDate));
              builder.element('Ref_certif_chez_declarant', nest: payment.reference ?? payment.paymentNumber);
              
              builder.element('ListeOperations', nest: () {
                builder.element('Operation', attributes: {'IdTypeOperation': 'RS7_000002'}, nest: () {
                  builder.element('AnneeFacturation', nest: invoice.date.year.toString());
                  builder.element('CNPC', nest: '0');
                  builder.element('P_Charge', nest: '0');
                  builder.element('MontantHT', nest: montantHt.toString());
                  builder.element('TauxRS', nest: tauxRs.toStringAsFixed(2));
                  builder.element('TauxTVA', nest: tauxTva.toStringAsFixed(2));
                  builder.element('MontantTVA', nest: montantTva.toString());
                  builder.element('MontantTTC', nest: montantTtc.toString());
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
      
      Directory? dir;
      if (Platform.isWindows) {
        dir = await getDownloadsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final fileName = 'RS_Achat_${monthStr}${year}.xml';
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);
      await file.writeAsString(xmlString);
      return filePath;
    } catch (e, stack) {
      print('Error generating/saving TEJ XML: $e');
      print(stack);
      rethrow;
    }
  }
}
