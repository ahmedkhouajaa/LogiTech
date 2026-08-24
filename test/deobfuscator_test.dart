import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/services/deobfuscator.dart';
import 'package:business_manager_pro/models/invoice.dart';
import 'package:business_manager_pro/models/quote.dart';
import 'package:business_manager_pro/models/customer.dart';
import 'package:business_manager_pro/models/supplier.dart';
import 'package:business_manager_pro/models/product.dart';
import 'package:business_manager_pro/models/delivery_note.dart';
import 'package:business_manager_pro/models/stock_movement.dart';
import 'package:business_manager_pro/models/treasury_account.dart';

void main() {
  group('Deobfuscator Tests', () {
    test('Auto-detects obfuscated vs normal JSON', () {
      final obfJson = {
        'v': '2.0',
        'app': 'LGBK_OBF',
        'data': {
          'd_inv': [
            {'f_01': 'FAC-001', 'f_08': 100.0}
          ]
        }
      };

      final normalJson = {
        'version': '2.0',
        'collections': {
          'invoices': [
            {'number': 'FAC-001', 'total_ht': 100.0, 'items': []}
          ]
        }
      };

      expect(Deobfuscator.isObfuscated(obfJson), isTrue);
      expect(Deobfuscator.isObfuscated(normalJson), isFalse);
    });

    test('Deobfuscates complex obfuscated backup into models successfully', () {
      final obfJson = {
        'v': '2.0',
        'app': 'LGBK_OBF',
        'gen': '2026-08-24T00:00:00.000Z',
        'data': {
          'd_inv': [
            {
              'f_01': 'FAC-2026-001',
              'f_05': '2026-08-24T01:00:00.000Z',
              'f_06': '2026-09-24T01:00:00.000Z',
              'f_07': 'unpaid',
              'f_08': 500.0,
              'f_09': 95.0,
              'f_10': 596.0,
              'f_13': 1.0,
              'f_20': 'CUST_123',
              'f_21': 'Client Test',
              'f_19': [
                {
                  'f_59': 'PROD_1',
                  'f_60': 'Ordinateur Portable',
                  'f_56': 'PC Portable Core i7',
                  'f_35': 2.0,
                  'f_33': 250.0,
                  'f_34': 19.0,
                  'f_08': 500.0,
                  'k_646973636f756e745f70657263656e74': 0.0,
                }
              ]
            }
          ],
          'd_qte': [
            {
              'f_01': 'DEV-2026-001',
              'f_05': '2026-08-24T01:00:00.000Z',
              'k_76616c69646974795f64617465': '2026-09-24T01:00:00.000Z',
              'k_636f6e7665727465645f746f': 'invoice',
              'f_07': 'draft',
              'f_08': 1000.0,
              'f_09': 190.0,
              'f_10': 1191.0,
              'f_20': 'CUST_123',
              'f_19': [
                {
                  'f_59': 'PROD_2',
                  'f_60': 'Serveur Rack',
                  'f_35': 1.0,
                  'f_33': 1000.0,
                  'f_34': 19.0,
                }
              ]
            }
          ],
          'd_cli': [
            {
              'f_02': 'CLI-001',
              'f_04': 'Société Alpha',
              'f_41': '+216 71 000 000',
              'f_42': 'alpha@example.com',
              'f_43': 'Tunis',
              'f_17': 'Client VIP',
              'f_51': 596.0,
            }
          ],
          'd_sup': [
            {
              'f_02': 'FRN-001',
              'f_04': 'Fournisseur Bêta',
              'k_737570706c69657254797065': 'entreprise',
            }
          ],
          'd_art': [
            {
              'f_37': 'REF-LAPTOP-01',
              'f_04': 'Laptop Dell Latitude',
              'f_32': 1200.0,
              'k_73656c6c696e675f7072696365': 1500.0,
              'f_38': 'Unite',
              'f_35': 10.0,
              'k_70726f647563745f74797065': 'produit',
            }
          ],
          'd_dln': [
            {
              'f_01': 'BL-2026-001',
              'f_20': 'CUST_123',
              'f_21': 'Client Test',
              'f_05': '2026-08-24T01:00:00.000Z',
              'f_07': 'validated',
              'f_08': 500.0,
              'f_10': 595.0,
              'f_19': [
                {
                  'f_59': 'PROD_1',
                  'f_60': 'Ordinateur Portable',
                  'f_35': 2.0,
                  'f_33': 250.0,
                  'f_34': 19.0,
                  'f_08': 500.0,
                }
              ]
            }
          ],
          'd_stm': [
            {
              'f_59': 'PROD_1',
              'f_60': 'Ordinateur Portable',
              'f_26': 'WRH_1',
              'f_27': 'Dépôt Principal',
              'f_35': 5.0,
              'f_55': 'in',
              'f_05': '2026-08-24T01:00:00.000Z',
              'f_02': 'ENT-001',
            }
          ],
          'd_tra': [
            {
              'f_04': 'Compte Principal BIAT',
              'f_55': 'bank',
              'f_53': 'BIAT',
              'f_54': '08000123456789012345',
              'f_64': 'TND',
              'f_50': 5000.0,
              'f_51': 7500.0,
            }
          ]
        }
      };

      final processed = Deobfuscator.processBackup(obfJson);
      expect(processed['collections'], isNotNull);
      final cols = processed['collections'] as Map<String, dynamic>;

      // Verify invoices
      expect(cols.containsKey('invoices'), isTrue);
      final invDoc = (cols['invoices'] as List).first as Map<String, dynamic>;
      expect(invDoc['number'], equals('FAC-2026-001'));
      expect(invDoc['customer_name'], equals('Client Test'));
      expect(invDoc['total_ht'], equals(500.0));
      expect(invDoc['items'], isNotEmpty);

      // Verify Invoice model parsing
      final invoiceModel = Invoice.fromMap(invDoc);
      expect(invoiceModel.number, equals('FAC-2026-001'));
      expect(invoiceModel.items.first.productName, equals('Ordinateur Portable'));
      expect(invoiceModel.items.first.quantity, equals(2.0));
      expect(invoiceModel.items.first.unitPrice, equals(250.0));

      // Verify quotes
      expect(cols.containsKey('quotes'), isTrue);
      final qteDoc = (cols['quotes'] as List).first as Map<String, dynamic>;
      expect(qteDoc['number'], equals('DEV-2026-001'));
      expect(qteDoc['validity_date'], equals('2026-09-24T01:00:00.000Z'));
      expect(qteDoc['converted_to'], equals('invoice'));

      final quoteModel = Quote.fromMap(qteDoc);
      expect(quoteModel.number, equals('DEV-2026-001'));
      expect(quoteModel.items.first.productName, equals('Serveur Rack'));

      // Verify clients
      expect(cols.containsKey('clients'), isTrue);
      final cliDoc = (cols['clients'] as List).first as Map<String, dynamic>;
      expect(cliDoc['code'], equals('CLI-001'));
      expect(cliDoc['name'], equals('Société Alpha'));
      expect(cliDoc['phone'], equals('+216 71 000 000'));

      final customerModel = Customer.fromMap(cliDoc);
      expect(customerModel.code, equals('CLI-001'));
      expect(customerModel.name, equals('Société Alpha'));

      // Verify suppliers
      expect(cols.containsKey('fournisseurs'), isTrue);
      final supDoc = (cols['fournisseurs'] as List).first as Map<String, dynamic>;
      expect(supDoc['code'], equals('FRN-001'));
      expect(supDoc['name'], equals('Fournisseur Bêta'));
      expect(supDoc['supplier_type'], equals('entreprise'));

      final supplierModel = Supplier.fromMap(supDoc);
      expect(supplierModel.code, equals('FRN-001'));
      expect(supplierModel.supplierType, equals('entreprise'));

      // Verify articles
      expect(cols.containsKey('articles'), isTrue);
      final artDoc = (cols['articles'] as List).first as Map<String, dynamic>;
      expect(artDoc['reference'], equals('REF-LAPTOP-01'));
      expect(artDoc['name'], equals('Laptop Dell Latitude'));
      expect(artDoc['purchase_price'], equals(1200.0));
      expect(artDoc['selling_price'], equals(1500.0));
      expect(artDoc['unit'], equals('Unite'));
      expect(artDoc['stock_qty'], equals(10.0));

      final productModel = Product.fromMap(artDoc);
      expect(productModel.reference, equals('REF-LAPTOP-01'));
      expect(productModel.name, equals('Laptop Dell Latitude'));
      expect(productModel.sellingPrice, equals(1500.0));
      expect(productModel.purchasePrice, equals(1200.0));
      expect(productModel.stockQty, equals(10.0));

      // Verify delivery notes
      expect(cols.containsKey('delivery_notes'), isTrue);
      final dlnDoc = (cols['delivery_notes'] as List).first as Map<String, dynamic>;
      final dlnModel = DeliveryNote.fromMap(dlnDoc);
      expect(dlnModel.number, equals('BL-2026-001'));
      expect(dlnModel.items.first.productName, equals('Ordinateur Portable'));

      // Verify stock movements
      expect(cols.containsKey('stock_movements'), isTrue);
      final stmDoc = (cols['stock_movements'] as List).first as Map<String, dynamic>;
      final stmModel = StockMovement.fromMap(stmDoc);
      expect(stmModel.productId, equals('PROD_1'));
      expect(stmModel.quantity, equals(5.0));

      // Verify treasury accounts
      expect(cols.containsKey('treasury_accounts'), isTrue);
      final traDoc = (cols['treasury_accounts'] as List).first as Map<String, dynamic>;
      final traModel = TreasuryAccount.fromMap(traDoc);
      expect(traModel.name, equals('Compte Principal BIAT'));
      expect(traModel.bankName, equals('BIAT'));
      expect(traModel.balance, equals(7500.0));
    });

    test('Normal JSON backup is safely normalized without changing fields', () {
      final normalJson = {
        'version': '2.0',
        'exportDate': '2026-08-24T00:00:00.000Z',
        'collections': {
          'invoices': [
            {
              'id': 'INV_999',
              'number': 'FAC-2026-999',
              'date': '2026-08-24T00:00:00.000Z',
              'due_date': '2026-09-24T00:00:00.000Z',
              'status': 'paid',
              'total_ht': 300.0,
              'total_tva': 57.0,
              'total_ttc': 357.0,
              'items': [
                {
                  'product_name': 'Clavier sans fil',
                  'quantity': 3.0,
                  'unit_price': 100.0,
                  'total_ht': 300.0,
                }
              ]
            }
          ]
        }
      };

      final processed = Deobfuscator.processBackup(normalJson);
      final cols = processed['collections'] as Map<String, dynamic>;
      final inv = (cols['invoices'] as List).first as Map<String, dynamic>;

      final invoiceModel = Invoice.fromMap(inv);
      expect(invoiceModel.number, equals('FAC-2026-999'));
      expect(invoiceModel.totalHT, equals(300.0));
      expect(invoiceModel.items.first.productName, equals('Clavier sans fil'));
    });
  });
}
