import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trash_item.dart';
import 'enterprise_service.dart';
import 'user_tracking_service.dart';

class TrashService {
  static final TrashService instance = TrashService._();
  TrashService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId;

  static const List<String> supportedCollections = [
    // Ventes
    'quotes',
    'customer_orders',
    'delivery_notes',
    'invoices',
    'bons_sortie',
    'credit_notes',
    'return_notes',
    // Achats
    'supplier_orders',
    'receiving_vouchers',
    'purchase_invoices',
    'supplier_credit_notes',
    'supplier_returns',
    // Clients & Fournisseurs
    'clients',
    'fournisseurs',
    // Articles
    'articles',
    'product_families',
    // Stock
    'stock_entries',
    'bons_prelevement',
    'stock_transfers',
    'inventory_sheets',
    'warehouses',
    // Trésorerie
    'paiements',
    'treasury_accounts',
    'treasury_transactions',
    'checks_traites',
    // Projets
    'projects',
  ];

  static String getCategoryForCollection(String collection, [Map<String, dynamic>? data]) {
    if (collection == 'paiements') {
      if (data != null) {
        final method = data['method'] ?? data['payment_method'];
        if (method == 'retenue_source') {
          return 'Retenue à la source (RS)';
        }
      }
      return 'Paiements';
    }

    switch (collection) {
      case 'quotes':
      case 'customer_orders':
      case 'delivery_notes':
      case 'invoices':
      case 'bons_sortie':
      case 'credit_notes':
      case 'return_notes':
        return 'Ventes';
      case 'supplier_orders':
      case 'receiving_vouchers':
      case 'purchase_invoices':
      case 'supplier_credit_notes':
      case 'supplier_returns':
        return 'Achats';
      case 'clients':
        return 'Clients';
      case 'fournisseurs':
        return 'Fournisseurs';
      case 'articles':
      case 'product_families':
        return 'Articles';
      case 'stock_entries':
      case 'bons_prelevement':
      case 'stock_transfers':
      case 'inventory_sheets':
      case 'warehouses':
        return 'Stock';
      case 'treasury_accounts':
      case 'treasury_transactions':
      case 'checks_traites':
        return 'Trésorerie';
      case 'projects':
        return 'Projets';
      default:
        return 'Autre';
    }
  }

  static String extractTitle(String collection, Map<String, dynamic> data) {
    final numStr = data['number'] ?? data['code'] ?? data['reference'] ?? data['payment_number'];
    final nameStr = data['name'] ?? data['companyName'] ?? data['description'] ?? data['title'];

    switch (collection) {
      case 'invoices':
        return 'Facture ${numStr ?? ''}'.trim();
      case 'quotes':
        return 'Devis ${numStr ?? ''}'.trim();
      case 'customer_orders':
        return 'Commande ${numStr ?? ''}'.trim();
      case 'delivery_notes':
        return 'Bon de livraison ${numStr ?? ''}'.trim();
      case 'bons_sortie':
        return 'Bon de sortie ${numStr ?? ''}'.trim();
      case 'credit_notes':
        return 'Avoir ${numStr ?? ''}'.trim();
      case 'return_notes':
        return 'Bon de retour ${numStr ?? ''}'.trim();
      case 'supplier_orders':
        return 'Commande fourn. ${numStr ?? ''}'.trim();
      case 'receiving_vouchers':
        return 'Bon de réception ${numStr ?? ''}'.trim();
      case 'purchase_invoices':
        return 'Facture d\'achat ${numStr ?? ''}'.trim();
      case 'supplier_credit_notes':
        return 'Avoir fourn. ${numStr ?? ''}'.trim();
      case 'supplier_returns':
        return 'Retour fourn. ${numStr ?? ''}'.trim();
      case 'clients':
        return nameStr != null ? 'Client $nameStr' : (numStr != null ? 'Client $numStr' : 'Client');
      case 'fournisseurs':
        return nameStr != null ? 'Fournisseur $nameStr' : (numStr != null ? 'Fournisseur $numStr' : 'Fournisseur');
      case 'articles':
        return nameStr != null ? 'Article $nameStr' : (numStr != null ? 'Article $numStr' : 'Article');
      case 'stock_entries':
        return 'Bon d\'entrée ${numStr ?? ''}'.trim();
      case 'bons_prelevement':
        return 'Bon de prélèvement ${numStr ?? ''}'.trim();
      case 'stock_transfers':
        return 'Transfert de stock ${numStr ?? ''}'.trim();
      case 'inventory_sheets':
        return 'Fiche d\'inventaire ${numStr ?? ''}'.trim();
      case 'warehouses':
        return 'Entrepôt ${nameStr ?? ''}'.trim();
      case 'paiements':
        final method = data['method'] ?? data['payment_method'];
        if (method == 'retenue_source') {
          final dir = data['direction'];
          final ref = data['reference'] ?? data['payment_number'] ?? numStr ?? '';
          if (dir == 'encaissement') {
            return 'RS Vente $ref'.trim();
          } else if (dir == 'decaissement') {
            return 'RS Achat $ref'.trim();
          }
          return 'Retenue à la source $ref'.trim();
        }
        final dir = data['direction'];
        final pNum = data['payment_number'] ?? numStr ?? data['reference'] ?? '';
        final prefix = dir == 'encaissement' ? 'Encaissement' : (dir == 'decaissement' ? 'Décaissement' : 'Paiement');
        return '$prefix $pNum'.trim();
      case 'treasury_accounts':
        return 'Compte ${nameStr ?? ''}'.trim();
      case 'treasury_transactions':
        return 'Transaction ${nameStr ?? numStr ?? ''}'.trim();
      case 'checks_traites':
        return 'Chèque / Traite ${numStr ?? ''}'.trim();
      case 'product_families':
        return 'Famille d\'articles ${nameStr ?? ''}'.trim();
      case 'projects':
        return 'Projet ${nameStr ?? numStr ?? ''}'.trim();
      default:
        return nameStr?.toString() ?? numStr?.toString() ?? 'Élément supprimé';
    }
  }

  static String extractSubtitle(String collection, Map<String, dynamic> data) {
    final parts = <String>[];

    // Articles specific details
    if (collection == 'articles') {
      final code = data['code'] ?? data['barcode'] ?? data['reference'];
      if (code != null && code.toString().trim().isNotEmpty) {
        parts.add('Réf: ${code.toString().trim()}');
      }
      final price = data['selling_price'] ?? data['sellingPrice'] ?? data['purchase_price'] ?? data['purchasePrice'];
      if (price != null) {
        final val = double.tryParse(price.toString());
        if (val != null && val > 0) {
          parts.add('${val.toStringAsFixed(3)} DT');
        }
      }
      final qty = data['stock_qty'] ?? data['stockQty'];
      if (qty != null) {
        parts.add('Stock: $qty');
      }
    } else if (collection == 'paiements') {
      // Partner info
      final partner = data['contact_name'] ?? data['contactName'] ?? data['customer_name'] ?? data['customerName'] ?? data['supplier_name'] ?? data['supplierName'] ?? data['client_name'] ?? data['clientName'];
      if (partner != null && partner.toString().trim().isNotEmpty) {
        parts.add(partner.toString().trim());
      }

      // Method info
      final method = data['method'] ?? data['payment_method'];
      if (method != null && method.toString().trim().isNotEmpty) {
        final m = method.toString();
        final label = m == 'especes' ? 'Espèces'
            : m == 'cheque' ? 'Chèque'
            : m == 'virement' ? 'Virement'
            : m == 'traite' ? 'Traite'
            : m == 'carte_bancaire' ? 'Carte bancaire'
            : m == 'retenue_source' ? 'Retenue à la source'
            : m;
        parts.add(label);
      }

      // Amount info
      final amount = data['amount'] ?? data['total_ttc'] ?? data['total'];
      if (amount != null) {
        final val = double.tryParse(amount.toString());
        if (val != null) {
          parts.add('${val.toStringAsFixed(3)} DT');
        }
      }

      // Payment date
      final pDate = data['payment_date'] ?? data['date'] ?? data['created_at'];
      if (pDate != null) {
        DateTime? dt;
        if (pDate is int) {
          dt = DateTime.fromMillisecondsSinceEpoch(pDate);
        } else if (pDate.toString().isNotEmpty) {
          dt = DateTime.tryParse(pDate.toString());
        }
        if (dt != null) {
          parts.add('${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}');
        }
      }
      return parts.join(' • ');
    } else {
      // Partner info
      final partner = data['customer_name'] ?? data['customerName'] ?? data['supplier_name'] ?? data['supplierName'];
      if (partner != null && partner.toString().trim().isNotEmpty) {
        parts.add(partner.toString().trim());
      }

      // Amount info
      final amount = data['total_ttc'] ?? data['totalTTC'] ?? data['total'] ?? data['amount'] ?? data['balance'];
      if (amount != null) {
        final val = double.tryParse(amount.toString());
        if (val != null) {
          parts.add('${val.toStringAsFixed(3)} DT');
        }
      }
    }

    // Date
    final date = data['date'] ?? data['created_at'] ?? data['createdAt'];
    if (date != null) {
      final s = date.toString();
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        parts.add('${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}');
      }
    }

    return parts.join(' • ');
  }

  /// Moves a document to the Corbeille
  Future<void> moveToTrash(
    String collection,
    String id, {
    Map<String, dynamic>? preloadedData,
  }) async {
    final docRef = _firestore.collection(collection).doc(id);
    Map<String, dynamic> data = preloadedData ?? {};

    if (data.isEmpty) {
      try {
        final snap = await docRef.get();
        if (snap.exists && snap.data() != null) {
          data = Map<String, dynamic>.from(snap.data()!);
        }
      } catch (e) {
        debugPrint('TrashService: error reading document before soft delete: $e');
      }
    }

    final now = DateTime.now().toIso8601String();

    // 1. Soft-delete the original document
    try {
      await docRef.update({
        'is_deleted': 1,
        'deleted_at': now,
        'updated_at': now,
        if (currentUid != null) 'userId': currentUid,
      });
    } catch (e) {
      // If doc does not exist or update fails with permission denied, retry or set
      debugPrint('TrashService: soft-delete update failed on $collection/$id: $e');
    }

    // 2. Register into the 'corbeille' collection
    final trashDocId = '${collection}_$id';
    final category = getCategoryForCollection(collection, data);
    final title = extractTitle(collection, data);
    final subtitle = extractSubtitle(collection, data);
    final entId = currentEnterpriseId ?? data['enterprise_id'] ?? data['enterpriseId'];

    try {
      await _firestore.collection('corbeille').doc(trashDocId).set({
        'id': trashDocId,
        'original_id': id,
        'collection': collection,
        'category': category,
        'title': title,
        'subtitle': subtitle,
        'deleted_at': now,
        'enterprise_id': entId,
        'userId': currentUid ?? data['userId'] ?? data['firebase_uid'],
        'snapshot': data,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TrashService: error writing to corbeille: $e');
    }

    // Traceability: Log delete to trash action
    unawaited(UserTrackingService.instance.logActivity(
      action: 'delete',
      module: UserTrackingService.getModuleForCollection(collection),
      collection: collection,
      documentId: id,
      documentReference: title,
      enterpriseId: entId,
      description: 'Mis dans la corbeille: $title',
      details: {
        'category': category,
        if (subtitle.isNotEmpty) 'subtitle': subtitle,
      },
    ));
  }

  /// Restores a document from the Corbeille back to its original collection
  Future<void> restoreItem(TrashItem item) async {
    final now = DateTime.now().toIso8601String();
    final docRef = _firestore.collection(item.collection).doc(item.originalId);

    try {
      final snap = await docRef.get();
      if (snap.exists) {
        // Document exists in original collection: un-delete it
        await docRef.update({
          'is_deleted': 0,
          'deleted_at': null,
          'updated_at': now,
        });
      } else if (item.snapshot.isNotEmpty) {
        // Document was missing: recreate it from cached snapshot
        final restoredMap = Map<String, dynamic>.from(item.snapshot);
        restoredMap['is_deleted'] = 0;
        restoredMap['deleted_at'] = null;
        restoredMap['updated_at'] = now;
        await docRef.set(restoredMap, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('TrashService: error restoring original document ${item.collection}/${item.originalId}: $e');
      // If update fails because doc not found, try set from snapshot
      if (item.snapshot.isNotEmpty) {
        try {
          final restoredMap = Map<String, dynamic>.from(item.snapshot);
          restoredMap['is_deleted'] = 0;
          restoredMap['deleted_at'] = null;
          restoredMap['updated_at'] = now;
          await docRef.set(restoredMap, SetOptions(merge: true));
        } catch (_) {}
      }
    }

    // Remove from corbeille
    try {
      await _firestore.collection('corbeille').doc(item.id).delete();
    } catch (e) {
      debugPrint('TrashService: error deleting from corbeille ${item.id}: $e');
    }

    // Traceability: Log restore action
    unawaited(UserTrackingService.instance.logActivity(
      action: 'restore',
      module: UserTrackingService.getModuleForCollection(item.collection),
      collection: item.collection,
      documentId: item.originalId,
      documentReference: item.title,
      enterpriseId: item.enterpriseId,
      description: 'Restauré depuis la corbeille: ${item.title}',
      details: {
        'category': item.category,
        if (item.subtitle.isNotEmpty) 'subtitle': item.subtitle,
      },
    ));
  }

  /// Permanently deletes a document from its original collection and from Corbeille
  Future<void> deletePermanently(TrashItem item) async {
    // 1. Delete from original collection
    try {
      await _firestore.collection(item.collection).doc(item.originalId).delete();
    } catch (e) {
      debugPrint('TrashService: error deleting original document ${item.collection}/${item.originalId}: $e');
    }

    // 2. Delete from corbeille
    try {
      await _firestore.collection('corbeille').doc(item.id).delete();
    } catch (e) {
      debugPrint('TrashService: error deleting from corbeille ${item.id}: $e');
    }

    // Traceability: Log permanent delete action
    unawaited(UserTrackingService.instance.logActivity(
      action: 'delete_permanent',
      module: UserTrackingService.getModuleForCollection(item.collection),
      collection: item.collection,
      documentId: item.originalId,
      documentReference: item.title,
      enterpriseId: item.enterpriseId,
      description: 'Supprimé définitivement: ${item.title}',
      details: {
        'category': item.category,
        if (item.subtitle.isNotEmpty) 'subtitle': item.subtitle,
      },
    ));
  }

  /// Empties the Corbeille (all or filtered by category)
  Future<void> emptyTrash({List<TrashItem>? items}) async {
    final targetList = items ?? await getTrashItems();
    for (final item in targetList) {
      await deletePermanently(item);
    }

    // Traceability: Log empty trash
    if (targetList.isNotEmpty) {
      unawaited(UserTrackingService.instance.logActivity(
        action: 'empty_trash',
        module: 'Corbeille',
        collection: 'corbeille',
        documentId: 'all',
        documentReference: 'Corbeille',
        description: 'A vidé la corbeille (${targetList.length} élément(s))',
        details: {
          'count': targetList.length,
        },
      ));
    }
  }

  /// Restores all items (or given items)
  Future<void> restoreAll({List<TrashItem>? items}) async {
    final targetList = items ?? await getTrashItems();
    for (final item in targetList) {
      await restoreItem(item);
    }

    // Traceability: Log restore all
    if (targetList.isNotEmpty) {
      unawaited(UserTrackingService.instance.logActivity(
        action: 'restore_all',
        module: 'Corbeille',
        collection: 'corbeille',
        documentId: 'all',
        documentReference: 'Corbeille',
        description: 'A restauré tous les éléments (${targetList.length} élément(s))',
        details: {
          'count': targetList.length,
        },
      ));
    }
  }

  /// Stream of Trash items for real-time reactivity
  Stream<List<TrashItem>> getTrashStream() {
    Query query = _firestore.collection('corbeille');
    final entId = currentEnterpriseId;
    if (entId != null && entId.isNotEmpty) {
      query = query.where('enterprise_id', isEqualTo: entId);
    } else {
      final uid = currentUid;
      if (uid != null && uid.isNotEmpty) {
        query = query.where('userId', isEqualTo: uid);
      }
    }

    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return TrashItem.fromMap(data, d.id);
      }).toList();

      list.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return list;
    });
  }

  /// Fetch one-time list of Trash items
  Future<List<TrashItem>> getTrashItems() async {
    try {
      Query query = _firestore.collection('corbeille');
      final entId = currentEnterpriseId;
      if (entId != null && entId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: entId);
      } else {
        final uid = currentUid;
        if (uid != null && uid.isNotEmpty) {
          query = query.where('userId', isEqualTo: uid);
        }
      }

      final snap = await query.get();
      final list = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return TrashItem.fromMap(data, d.id);
      }).toList();

      list.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return list;
    } catch (e) {
      debugPrint('TrashService: error getting trash items: $e');
      return [];
    }
  }

  /// Synchronize any historical soft-deleted documents (is_deleted == 1) that were not yet indexed in 'corbeille'
  Future<void> syncLegacyDeletedItems() async {
    final entId = currentEnterpriseId;
    if (entId == null || entId.isEmpty) return;

    for (final coll in supportedCollections) {
      try {
        final snap = await _firestore
            .collection(coll)
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: 1)
            .limit(50)
            .get();

        for (final doc in snap.docs) {
          final trashDocId = '${coll}_${doc.id}';
          final exists = (await _firestore.collection('corbeille').doc(trashDocId).get()).exists;
          if (!exists) {
            final data = doc.data();
            await _firestore.collection('corbeille').doc(trashDocId).set({
              'id': trashDocId,
              'original_id': doc.id,
              'collection': coll,
              'category': getCategoryForCollection(coll, data),
              'title': extractTitle(coll, data),
              'subtitle': extractSubtitle(coll, data),
              'deleted_at': data['deleted_at'] ?? DateTime.now().toIso8601String(),
              'enterprise_id': entId,
              'userId': data['userId'] ?? data['firebase_uid'],
              'snapshot': data,
            }, SetOptions(merge: true));
          }
        }
      } catch (_) {
        // Continue silently if some composite indexes do not exist yet
      }
    }
  }
}
