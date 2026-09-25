import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_activity_log.dart';
import '../models/user_management_model.dart';
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

  /// Extracts a display reference or name from document data
  static String extractDocumentReference(String collection, Map<String, dynamic> data) {
    final ref = data['number'] ??
        data['code'] ??
        data['reference'] ??
        data['payment_number'] ??
        data['name'] ??
        data['companyName'] ??
        data['title'];
    if (ref != null && ref.toString().trim().isNotEmpty) {
      return ref.toString().trim();
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
      final ref = documentReference ?? (docData != null ? extractDocumentReference(collection, docData) : '');

      // Generate human-readable description if not provided
      final finalDescription = description ?? _generateDescription(action, resolvedModule, ref);

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
        details: details,
      );

      await logRef.set(logItem.toMap());
    } catch (e) {
      debugPrint('UserTrackingService: Error recording activity: $e');
    }
  }

  String _generateDescription(String action, String module, String ref) {
    final refSuffix = ref.isNotEmpty ? ' « $ref »' : '';
    switch (action) {
      case 'create':
        return 'Création dans $module$refSuffix';
      case 'update':
        return 'Modification dans $module$refSuffix';
      case 'delete':
        return 'Suppression dans $module$refSuffix (déplacé dans la corbeille)';
      case 'delete_permanent':
        return 'Suppression définitive dans $module$refSuffix';
      case 'restore':
        return 'Restauration dans $module$refSuffix depuis la corbeille';
      case 'empty_trash':
        return 'Vidage de la corbeille ($refSuffix)';
      case 'restore_all':
        return 'Restauration groupée depuis la corbeille ($refSuffix)';
      case 'login':
        return 'Connexion au système';
      case 'export':
        return 'Exportation de données ($module)';
      default:
        return 'Action $action sur $module$refSuffix';
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
