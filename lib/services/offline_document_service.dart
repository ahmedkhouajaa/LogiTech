import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../utils/helpers.dart';
import 'firestore_repository.dart';
import 'connectivity_service.dart';

class OfflineDocumentService {
  static final OfflineDocumentService instance = OfflineDocumentService._();
  OfflineDocumentService._();

  static String _getStorageKey(String collection) => 'pending_docs_$collection';

  /// Generate a 6-digit draft number: BROUILLON-XXXXXX
  static String generateDraftNumber() {
    final rand6 = 100000 + (DateTime.now().microsecondsSinceEpoch % 900000);
    return 'BROUILLON-$rand6';
  }

  /// Save a pending document to SharedPreferences
  Future<void> savePendingDocument(String collection, Map<String, dynamic> docMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(collection);
      final pendingList = await getPendingDocuments(collection);

      final docId = docMap['id'] as String;
      pendingList.removeWhere((map) => map['id'] == docId);

      docMap['is_synced'] = 0;
      pendingList.add(docMap);

      final jsonList = pendingList.map((m) => jsonEncode(m)).toList();
      await prefs.setStringList(key, jsonList);
      debugPrint('[OFFLINE DOC] Saved pending document ${docMap['number']} to $collection locally.');
    } catch (e) {
      debugPrint('❌ [OFFLINE DOC] Error saving pending document to $collection: $e');
    }
  }

  /// Get pending raw maps for a collection
  Future<List<Map<String, dynamic>>> getPendingDocuments(String collection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(collection);
      final jsonList = prefs.getStringList(key) ?? [];
      final result = <Map<String, dynamic>>[];
      for (final jsonStr in jsonList) {
        try {
          result.add(jsonDecode(jsonStr) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('❌ Error parsing stored document in $collection: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ [OFFLINE DOC] Error reading pending documents for $collection: $e');
      return [];
    }
  }

  /// Remove a pending document by ID
  Future<void> removePendingDocument(String collection, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(collection);
      final pendingList = await getPendingDocuments(collection);
      pendingList.removeWhere((map) => map['id'] == id);
      final jsonList = pendingList.map((m) => jsonEncode(m)).toList();
      await prefs.setStringList(key, jsonList);
    } catch (e) {
      debugPrint('❌ [OFFLINE DOC] Error removing pending document from $collection: $e');
    }
  }

  /// Sync all pending documents across all collections to Cloud Firestore
  Future<int> syncAllPendingDocuments() async {
    if (!ConnectivityService.instance.isOnline) {
      debugPrint('[OFFLINE DOC] Device is offline, skipping batch sync.');
      return 0;
    }

    final collections = [
      'quotes',
      'invoices',
      'delivery_notes',
      'customer_orders',
      'credit_notes',
      'purchase_invoices',
      'supplier_orders',
      'receiving_vouchers',
      'exit_vouchers',
      'bons_sortie',
      'stock_withdrawals',
      'bons_prelevement',
      'stock_entries',
      'stock_transfers',
      'inventory_sheets',
      'supplier_credit_notes',
      'return_notes',
      'supplier_returns',
    ];

    int totalSynced = 0;

    for (final collection in collections) {
      final pending = await getPendingDocuments(collection);
      if (pending.isEmpty) continue;

      debugPrint('[OFFLINE DOC] Syncing ${pending.length} pending items in $collection...');

      for (final map in pending) {
        try {
          final docId = map['id'] as String;
          int seq = 0;
          String prefix = 'DOC';

          switch (collection) {
            case 'quotes':
              seq = await DatabaseHelper.instance.getNextQuoteSequence();
              prefix = 'DV';
              break;
            case 'invoices':
              seq = await DatabaseHelper.instance.getNextInvoiceSequence();
              prefix = 'FA';
              break;
            case 'delivery_notes':
              seq = await DatabaseHelper.instance.getNextDeliveryNoteSequence();
              prefix = 'BL';
              break;
            case 'customer_orders':
              seq = await DatabaseHelper.instance.getNextCustomerOrderSequence();
              prefix = 'CC';
              break;
            case 'credit_notes':
              seq = await DatabaseHelper.instance.getNextCreditNoteSequence();
              prefix = 'AV';
              break;
            case 'purchase_invoices':
              seq = await DatabaseHelper.instance.getNextPurchaseInvoiceSequence();
              prefix = 'FA';
              break;
            case 'supplier_orders':
              seq = await DatabaseHelper.instance.getNextSupplierOrderSequence();
              prefix = 'CF';
              break;
            case 'receiving_vouchers':
              seq = await DatabaseHelper.instance.getNextReceivingVoucherSequence();
              prefix = 'BR';
              break;
            case 'exit_vouchers':
            case 'bons_sortie':
              seq = await DatabaseHelper.instance.getNextExitVoucherSequence();
              prefix = 'BS';
              break;
            case 'stock_withdrawals':
            case 'bons_prelevement':
              seq = await DatabaseHelper.instance.getNextStockWithdrawalSequence();
              prefix = 'BP';
              break;
            case 'stock_entries':
              seq = await DatabaseHelper.instance.getNextStockEntrySequence();
              prefix = 'BE';
              break;
            case 'stock_transfers':
              seq = await DatabaseHelper.instance.getNextStockTransferSequence();
              prefix = 'BT';
              break;
            case 'inventory_sheets':
              seq = await DatabaseHelper.instance.getNextInventorySheetSequence();
              prefix = 'FI';
              break;
            case 'supplier_credit_notes':
              seq = await DatabaseHelper.instance.getNextSupplierCreditNoteSequence();
              prefix = 'AV';
              break;
            case 'return_notes':
              seq = await DatabaseHelper.instance.getNextReturnNoteSequence();
              prefix = 'BR';
              break;
            case 'supplier_returns':
              seq = await DatabaseHelper.instance.getNextSupplierReturnSequence();
              prefix = 'RF';
              break;
          }

          final officialNumber = generateDocNumber(prefix, seq);
          map['number'] = officialNumber;
          map['transaction_number'] = officialNumber;
          map['transactionNumber'] = officialNumber;
          map['is_synced'] = 1;
          map['updated_at'] = DateTime.now().toIso8601String();

          final curStatus = (map['status']?.toString() ?? '').toLowerCase();
          if (curStatus == 'draft' || curStatus == 'brouillon' || curStatus == 'pending' || curStatus.isEmpty) {
            switch (collection) {
              case 'quotes':
              case 'delivery_notes':
              case 'customer_orders':
              case 'supplier_orders':
              case 'receiving_vouchers':
                map['status'] = 'created';
                break;
              case 'invoices':
              case 'purchase_invoices':
                map['status'] = 'unpaid';
                break;
              case 'exit_vouchers':
              case 'bons_sortie':
              case 'stock_withdrawals':
              case 'bons_prelevement':
              case 'stock_entries':
              case 'stock_transfers':
              case 'inventory_sheets':
              case 'credit_notes':
              case 'supplier_credit_notes':
              case 'return_notes':
              case 'supplier_returns':
              default:
                map['status'] = 'created';
                break;
            }
          }

          final firestoreCollection = (collection == 'exit_vouchers' || collection == 'bons_sortie')
              ? 'bons_sortie'
              : (collection == 'stock_withdrawals' || collection == 'bons_prelevement')
                  ? 'stock_withdrawals'
                  : collection;

          // Save to Firestore
          await FirestoreRepository.instance.saveDocument(firestoreCollection, docId, map);

          // Remove from local SharedPreferences under all matching keys
          await removePendingDocument(collection, docId);
          if (collection == 'exit_vouchers' || collection == 'bons_sortie') {
            await removePendingDocument('exit_vouchers', docId);
            await removePendingDocument('bons_sortie', docId);
          } else if (collection == 'stock_withdrawals' || collection == 'bons_prelevement') {
            await removePendingDocument('stock_withdrawals', docId);
            await removePendingDocument('bons_prelevement', docId);
          }
          totalSynced++;

          debugPrint('✅ [OFFLINE DOC] Synced $collection document -> $officialNumber in $firestoreCollection');
        } catch (e) {
          debugPrint('❌ [OFFLINE DOC] Failed to sync document in $collection: $e');
          break;
        }
      }
    }

    return totalSynced;
  }
}
