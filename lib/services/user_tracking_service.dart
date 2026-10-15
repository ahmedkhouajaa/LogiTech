import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_activity_log.dart';
import '../models/user_management_model.dart';
import '../utils/firestore_safe_helper.dart';
import 'enterprise_service.dart';
import 'user_management_service.dart';

/// Singleton service responsible for logging and streaming user actions (Traceability / Audit Log).
class UserTrackingService {
  static final UserTrackingService instance = UserTrackingService._();
  UserTrackingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId;

  /// Cache for resolved user names to avoid repeated Firestore fetches
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _userRoleCache = {};

  /// Cache for resolved document references across sessions
  final Map<String, String> _documentReferenceCache = {};

  /// Resolves the human-readable reference of a document from Firestore or trash
  Future<String> resolveDocumentReference(String collection, String documentId) async {
    final col = collection.trim();
    final docId = documentId.trim();
    if (col.isEmpty || docId.isEmpty) return '';

    final cacheKey = '$col/$docId';
    if (_documentReferenceCache.containsKey(cacheKey)) {
      return _documentReferenceCache[cacheKey]!;
    }

    try {
      final docData = await FirestoreSafeHelper.getDocData(
        _firestore.collection(col),
        docId,
      );
      if (docData != null) {
        final ref = extractDocumentReference(col, docData);
        if (ref.isNotEmpty) {
          _documentReferenceCache[cacheKey] = ref;
          return ref;
        }
      }

      // Check in trash if document was deleted or moved
      final trashData = await FirestoreSafeHelper.getDocData(
        _firestore.collection('corbeille'),
        docId,
      );
      if (trashData != null) {
        final orig = trashData['data'] is Map ? Map<String, dynamic>.from(trashData['data']) : trashData;
        final ref = extractDocumentReference(col, orig);
        if (ref.isNotEmpty) {
          _documentReferenceCache[cacheKey] = ref;
          return ref;
        }
      }
    } catch (e) {
      debugPrint('UserTrackingService.resolveDocumentReference error: $e');
    }

    return '';
  }

  /// Resolves human-readable module from collection
  static String getModuleForCollection(String collection, [Map<String, dynamic>? data]) {
    if (collection == 'paiements') {
      if (data != null) {
        final method = data['method'] ?? data['payment_method'];
        if (method == 'retenue_source') {
          return 'Retenues (RS)';
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
      case 'corbeille':
        return 'Corbeille';
      case 'users':
      case 'user_management':
        return 'Utilisateurs';
      default:
        return 'Paramètres';
    }
  }

  /// Returns a specific document label for descriptions
  static String getDocumentLabelForCollection(String collection) {
    switch (collection.toLowerCase().trim()) {
      case 'quotes':
        return 'Devis';
      case 'customer_orders':
        return 'Commande client';
      case 'delivery_notes':
        return 'Bon de livraison';
      case 'invoices':
        return 'Facture';
      case 'bons_sortie':
        return 'Bon de sortie';
      case 'credit_notes':
        return 'Avoir';
      case 'return_notes':
        return 'Bon de retour';
      case 'supplier_orders':
        return 'Commande fournisseur';
      case 'receiving_vouchers':
        return 'Bon de réception';
      case 'purchase_invoices':
        return 'Facture d\'achat';
      case 'supplier_credit_notes':
        return 'Avoir fournisseur';
      case 'supplier_returns':
        return 'Retour fournisseur';
      case 'stock_entries':
        return 'Bon d\'entrée';
      case 'bons_prelevement':
        return 'Bon de prélèvement';
      case 'stock_transfers':
        return 'Bon de transfert';
      case 'inventory_sheets':
        return 'Fiche d\'inventaire';
      case 'articles':
        return 'Articles';
      case 'clients':
        return 'Clients';
      case 'fournisseurs':
        return 'Fournisseurs';
      case 'warehouses':
        return 'Entrepôts';
      case 'paiements':
        return 'Paiements';
      case 'treasury_accounts':
        return 'Comptes de trésorerie';
      case 'treasury_transactions':
        return 'Transactions de trésorerie';
      case 'checks_traites':
        return 'Chèques & Traites';
      default:
        return '';
    }
  }

  /// Extracts a display reference or name from document data
  static String extractDocumentReference(String collection, Map<String, dynamic> data) {
    final ref = (data['number'] ??
        data['code'] ??
        data['reference'] ??
        data['payment_number'] ??
        data['piece_number'] ??
        data['check_number'] ??
        data['title'] ??
        data['companyName'] ??
        data['company_name'] ??
        data['name'])?.toString().trim();

    final secondaryName = (data['customer_name'] ??
        data['customerName'] ??
        data['supplier_name'] ??
        data['supplierName'] ??
        data['client_name'] ??
        data['clientName'] ??
        data['name'] ??
        data['designation'] ??
        data['reason'] ??
        data['label'] ??
        data['fileName'] ??
        data['file_name'])?.toString().trim();

    if (ref != null && ref.isNotEmpty) {
      if (secondaryName != null &&
          secondaryName.isNotEmpty &&
          secondaryName != ref &&
          !ref.contains(secondaryName)) {
        return '$ref — $secondaryName';
      }
      return ref;
    } else if (secondaryName != null && secondaryName.isNotEmpty) {
      return secondaryName;
    }
    return '';
  }

  /// Logs a user activity into Firestore
  Future<void> logActivity({
    required String action, // 'create', 'update', 'delete', 'restore', 'login', 'empty_trash', 'export'
    required String collection,
    required String documentId,
    String? documentReference,
    String? module,
    String? description,
    String? enterpriseId,
    Map<String, dynamic>? details,
    Map<String, dynamic>? docData,
    String? customUserId,
    String? customUserName,
    String? customUserEmail,
    String? customUserRole,
  }) async {
    try {
      final entId = enterpriseId ?? currentEnterpriseId;
      if (entId == null || entId.isEmpty) return;

      final user = FirebaseAuth.instance.currentUser;
      final uid = customUserId ?? user?.uid ?? 'system';
      final email = customUserEmail ?? user?.email ?? '';

      // Determine user name
      String name = customUserName ?? user?.displayName ?? '';
      if (name.isEmpty && _userNameCache.containsKey(uid)) {
        name = _userNameCache[uid]!;
      }
      if (name.isEmpty) {
        if (email.isNotEmpty) {
          name = email.split('@').first;
        } else {
          name = 'Utilisateur ($uid)';
        }
      }

      // Determine role
      final role = customUserRole ?? _userRoleCache[uid] ?? 'collaborateur';

      final resolvedModule = module ?? getModuleForCollection(collection, docData);
      String ref = documentReference ?? (docData != null ? extractDocumentReference(collection, docData) : '');

      // If reference is still empty, auto-resolve it from the document in Firestore
      if (ref.isEmpty && documentId.isNotEmpty && collection.isNotEmpty) {
        try {
          final fetchedRef = await resolveDocumentReference(collection, documentId);
          if (fetchedRef.isNotEmpty) {
            ref = fetchedRef;
          }
        } catch (_) {}
      }

      // Generate human-readable description if not provided
      final finalDescription = description ?? _generateDescription(action, resolvedModule, ref, collection);

      Map<String, dynamic>? finalDetails = details != null ? Map<String, dynamic>.from(details) : null;
      if (docData != null) {
        finalDetails ??= <String, dynamic>{};
        for (final k in [
          'name',
          'designation',
          'customer_name',
          'customerName',
          'supplier_name',
          'supplierName',
          'client_name',
          'clientName',
          'fileName',
          'file_name',
          'total_amount',
          'totalAmount'
        ]) {
          if (docData.containsKey(k) && docData[k] != null && !finalDetails.containsKey(k)) {
            finalDetails[k] = docData[k];
          }
        }
        if (finalDetails.isEmpty) finalDetails = null;
      }

      final now = DateTime.now();
      final logRef = _firestore.collection('user_activities').doc();

      final logItem = UserActivityLog(
        id: logRef.id,
        enterpriseId: entId,
        userId: uid,
        userName: name,
        userEmail: email,
        userRole: role,
        action: action,
        module: resolvedModule,
        collection: collection,
        documentId: documentId,
        documentReference: ref,
        description: finalDescription,
        timestamp: now,
        details: finalDetails,
      );

      await logRef.set(logItem.toMap());
    } catch (e) {
      debugPrint('UserTrackingService: Error recording activity: $e');
    }
  }

  String _generateDescription(String action, String module, String ref, [String collection = '']) {
    final docLabel = getDocumentLabelForCollection(collection);
    final targetContext = docLabel.isNotEmpty ? docLabel : module;
    final refSuffix = ref.isNotEmpty ? ' « $ref »' : '';
    switch (action) {
      case 'create':
        return 'Création dans $targetContext$refSuffix';
      case 'update':
        return 'Modification dans $targetContext$refSuffix';
      case 'delete':
        return 'Suppression dans $targetContext$refSuffix (déplacé dans la corbeille)';
      case 'delete_permanent':
        return 'Suppression définitive dans $targetContext$refSuffix';
      case 'restore':
        return 'Restauration dans $targetContext$refSuffix depuis la corbeille';
      case 'empty_trash':
        return 'Vidage de la corbeille ($refSuffix)';
      case 'restore_all':
        return 'Restauration groupée depuis la corbeille ($refSuffix)';
      case 'login':
        return 'Connexion au système';
      case 'export':
        return 'Exportation de données ($targetContext)';
      default:
        return 'Action $action sur $targetContext$refSuffix';
    }
  }

  /// Live Firestore stream of activities for the current enterprise
  Stream<List<UserActivityLog>> getActivitiesStream({
    String? userId,
    String? module,
    String? action,
    int limit = 150,
  }) {
    final entId = currentEnterpriseId;
    if (entId == null || entId.isEmpty) {
      return Stream.value([]);
    }

    Query query = _firestore
        .collection('user_activities')
        .where('enterprise_id', isEqualTo: entId);

    if (userId != null && userId.isNotEmpty) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (module != null && module.isNotEmpty && module != 'all') {
      query = query.where('module', isEqualTo: module);
    }
    if (action != null && action.isNotEmpty && action != 'all') {
      query = query.where('action', isEqualTo: action);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return UserActivityLog.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Client-side sort by timestamp descending
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  /// Fetches enterprise users for filter dropdown
  Future<List<EnterpriseUserModel>> getEnterpriseUsers() async {
    final entId = currentEnterpriseId;
    if (entId == null || entId.isEmpty) return [];

    try {
      final users = await UserManagementService.instance.getUsersForEnterprise(entId);
      for (final u in users) {
        _userNameCache[u.uid] = u.name;
        _userRoleCache[u.uid] = u.role;
      }
      return users;
    } catch (e) {
      debugPrint('UserTrackingService: Error fetching enterprise users: $e');
      return [];
    }
  }
}
