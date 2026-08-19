import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/enterprise.dart';
import '../models/stock_movement.dart' show Warehouse;
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/treasury_account.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../database/database_helper.dart';
import '../models/user_management_model.dart';
import 'permission_service.dart';

/// Singleton service that manages the current enterprise context.
///
/// Responsibilities:
/// - Tracks [currentEnterpriseId] and exposes a stream for changes
/// - Caches enterprise list in SharedPreferences for fast boot
/// - Reads/writes enterprise data to Firestore
/// - Auto-creates a default enterprise for new users
class EnterpriseService {
  static final EnterpriseService instance = EnterpriseService._();
  EnterpriseService._();

  static const _prefKeyCurrentId = 'currentEnterpriseId';
  static const _prefKeyEnterprisesJson = 'enterpriseListJson';

  String? _currentEnterpriseId;
  List<Enterprise> _enterprises = [];
  final Set<String> _pendingDefaultCreations = {};
  bool _isCreatingEnterprise = false;

  final _enterpriseController = StreamController<String?>.broadcast();
  final _enterpriseListController = StreamController<List<Enterprise>>.broadcast();
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  /// The currently active enterprise ID, used by all data queries.
  String? get currentEnterpriseId => _currentEnterpriseId;

  /// Stream that emits whenever the active enterprise changes.
  Stream<String?> get enterpriseStream => _enterpriseController.stream;

  /// Stream that emits whenever the enterprise list updates.
  Stream<List<Enterprise>> get enterprisesStream => _enterpriseListController.stream;

  /// Whether the current active enterprise is the user's default/first enterprise.
  bool get isDefaultEnterprise {
    if (_enterprises.isEmpty) return true;
    return _currentEnterpriseId == null || _currentEnterpriseId == _enterprises.first.id;
  }

  /// The currently active Enterprise object.
  Enterprise? get currentEnterprise {
    if (_currentEnterpriseId == null || _enterprises.isEmpty) return null;
    try {
      return _enterprises.firstWhere((e) => e.id == _currentEnterpriseId);
    } catch (_) {
      return null;
    }
  }

  /// Cached enterprise list (may be stale until refreshed from Firestore).
  List<Enterprise> get enterprises => List.unmodifiable(_enterprises);

  // ─── Realtime Sync ────────────────────────────────────────────────

  /// Listens in real-time to user document in Firestore to detect new enterprises
  /// created from other devices (e.g. Mobile <-> Desktop).
  void startRealtimeSync() {
    _userDocSubscription?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((userDoc) async {
      if (!userDoc.exists) return;
      final data = userDoc.data();
      if (data == null) return;

      final List<String> enterpriseIds = List<String>.from(data['enterprises'] ?? []);
      final currentIds = _enterprises.map((e) => e.id).toList();

      // Check if enterprise list in Firestore has new/removed enterprises
      final hasChanges = enterpriseIds.length != currentIds.length ||
          !enterpriseIds.every((id) => currentIds.contains(id));

      if (hasChanges) {
        print('EnterpriseService: Detected enterprise change in Firestore! Syncing...');
        await loadEnterprisesFromFirestore();
      }
    }, onError: (e) {
      print('EnterpriseService.startRealtimeSync error: $e');
    });
  }

  // ─── Initialisation ──────────────────────────────────────────────

  /// Loads the last-used enterprise ID from SharedPreferences for instant boot.
  /// Call this early in main() after Firebase.initializeApp().
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentEnterpriseId = prefs.getString(_prefKeyCurrentId);

    // Restore cached enterprise list
    final jsonStr = prefs.getString(_prefKeyEnterprisesJson);
    if (jsonStr != null) {
      try {
        final List decoded = jsonDecode(jsonStr) as List;
        _enterprises = List.unmodifiable(decoded
            .map((e) => Enterprise.fromMap(Map<String, dynamic>.from(e)))
            .toList());
      } catch (_) {
        _enterprises = [];
      }
    }
    startRealtimeSync();
    unawaited(PermissionService.instance.loadPermissions());
  }

  /// Clears in-memory and cached enterprise data on logout.
  Future<void> clearCache() async {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
    _currentEnterpriseId = null;
    _enterprises = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyCurrentId);
    await prefs.remove(_prefKeyEnterprisesJson);
    _enterpriseController.add(null);
    _enterpriseListController.add([]);
  }

  // ─── Enterprise CRUD ─────────────────────────────────────────────

  /// Loads enterprises for the current user from Firestore and updates cache.
  Future<List<Enterprise>> loadEnterprisesFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    startRealtimeSync();

    try {
      // Read user doc to get enterprise IDs
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      List<String> enterpriseIds = [];
      if (userDoc.exists && userDoc.data()?['enterprises'] != null) {
        enterpriseIds = List<String>.from(userDoc.data()!['enterprises']);
      }

      if (enterpriseIds.isEmpty) {
        _enterprises = [];
        _currentEnterpriseId = null;
        await _persistToPrefs();
        _enterpriseController.add(_currentEnterpriseId);
        _enterpriseListController.add(_enterprises);
        return _enterprises;
      }

      // Fetch enterprise docs
      final List<Enterprise> result = [];
      for (final eid in enterpriseIds) {
        final doc = await FirebaseFirestore.instance
            .collection('enterprises')
            .doc(eid)
            .get();
        if (doc.exists) {
          result.add(Enterprise.fromMap({...doc.data()!, 'id': doc.id}));
        }
      }

      _enterprises = List.unmodifiable(result);

      // If current enterprise is not in list, switch to first
      if (_currentEnterpriseId == null ||
          !enterpriseIds.contains(_currentEnterpriseId)) {
        _currentEnterpriseId = result.isNotEmpty ? result.first.id : null;
      }

      // Also update Firestore user doc's currentEnterpriseId
      if (_currentEnterpriseId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'currentEnterpriseId': _currentEnterpriseId}, SetOptions(merge: true));
      }

      await _persistToPrefs();
      _enterpriseController.add(_currentEnterpriseId);
      _enterpriseListController.add(_enterprises);
      await PermissionService.instance.loadPermissions(enterpriseId: _currentEnterpriseId);
      return _enterprises;
    } catch (e) {
      print('EnterpriseService.loadEnterprisesFromFirestore error: $e');
      return _enterprises; // Return cached list on failure
    }
  }

  /// Ensures all required default records (Warehouse, Customer, Supplier, TreasuryAccount, Project)
  /// exist for the given enterprise.
  /// 
  /// - Guaranteed to be atomic and idempotent.
  /// - Prevents concurrent duplicate runs via [_pendingDefaultCreations].
  /// - Checks the [defaultsCreated] flag on the enterprise document.
  /// - Verifies if records already exist before creating missing defaults.
  /// - Uses [WriteBatch] to commit all missing default records atomically.
  /// - Automatically cleans up existing duplicate default records if any exist.
  Future<void> ensureDefaultRecordsCreated(
    String enterpriseId, {
    String? ownerUid,
    bool force = false,
  }) async {
    if (enterpriseId.isEmpty) return;

    if (_pendingDefaultCreations.contains(enterpriseId)) {
      debugPrint('[EnterpriseDefaults] Creation already in-flight for enterprise $enterpriseId. Skipping duplicate call.');
      return;
    }
    _pendingDefaultCreations.add(enterpriseId);

    try {
      final uid = ownerUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'local-user';
      final now = DateTime.now();

      debugPrint('[EnterpriseDefaults] [${now.toIso8601String()}] Checking defaults for enterprise $enterpriseId...');

      // 1. Check if enterprise doc already has defaultsCreated == true in Firestore
      final entDocRef = FirebaseFirestore.instance.collection('enterprises').doc(enterpriseId);
      final entSnap = await entDocRef.get();
      if (!force && entSnap.exists) {
        final data = entSnap.data();
        final isAlreadyCreated = data?['defaults_created'] == true ||
            data?['defaults_created'] == 1 ||
            data?['defaults_created'] == 'true' ||
            data?['defaultsCreated'] == true ||
            data?['defaultsCreated'] == 1 ||
            data?['defaultsCreated'] == 'true';
        if (isAlreadyCreated) {
          debugPrint('[EnterpriseDefaults] Enterprise $enterpriseId already has defaultsCreated=true. Skipping default generation.');
          return;
        }
      }

      // 2. Query Firestore collections for existing records in this enterprise
      final warehousesQuery = await FirebaseFirestore.instance
          .collection('warehouses')
          .where('enterprise_id', isEqualTo: enterpriseId)
          .get();

      final customersQuery = await FirebaseFirestore.instance
          .collection('clients')
          .where('enterprise_id', isEqualTo: enterpriseId)
          .get();

      final suppliersQuery = await FirebaseFirestore.instance
          .collection('fournisseurs')
          .where('enterprise_id', isEqualTo: enterpriseId)
          .get();

      final treasuryQuery = await FirebaseFirestore.instance
          .collection('treasury_accounts')
          .where('enterprise_id', isEqualTo: enterpriseId)
          .get();

      final projectsQuery = await FirebaseFirestore.instance
          .collection('projects')
          .where('enterprise_id', isEqualTo: enterpriseId)
          .get();

      // Clean up duplicate default records from previous runs if any exist
      // Projects: keep the oldest one and delete duplicate defaults
      final defaultProjects = projectsQuery.docs.where((d) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim().toLowerCase();
        return data['is_default'] == true || data['is_default'] == 1 || data['isDefault'] == true ||
            name == 'projet par défaut' || name == 'projet principal par défaut';
      }).toList();
      if (defaultProjects.length > 1) {
        debugPrint('[EnterpriseDefaults] Found ${defaultProjects.length} duplicate default projects for enterprise $enterpriseId. Cleaning up ${defaultProjects.length - 1} duplicates...');
        for (int i = 1; i < defaultProjects.length; i++) {
          try {
            await FirebaseFirestore.instance.collection('projects').doc(defaultProjects[i].id).delete();
          } catch (e) {
            debugPrint('[EnterpriseDefaults] Error deleting duplicate project ${defaultProjects[i].id}: $e');
          }
        }
      }

      // Customers: keep oldest and delete duplicate defaults
      final defaultCustomers = customersQuery.docs.where((d) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim().toLowerCase();
        return data['is_default'] == true || data['is_default'] == 1 || data['isDefault'] == true ||
            name == 'client passager';
      }).toList();
      if (defaultCustomers.length > 1) {
        debugPrint('[EnterpriseDefaults] Found ${defaultCustomers.length} duplicate default customers for enterprise $enterpriseId. Cleaning up ${defaultCustomers.length - 1} duplicates...');
        for (int i = 1; i < defaultCustomers.length; i++) {
          try {
            await FirebaseFirestore.instance.collection('clients').doc(defaultCustomers[i].id).delete();
          } catch (e) {
            debugPrint('[EnterpriseDefaults] Error deleting duplicate customer ${defaultCustomers[i].id}: $e');
          }
        }
      }

      // Suppliers: keep oldest and delete duplicate defaults
      final defaultSuppliers = suppliersQuery.docs.where((d) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim().toLowerCase();
        return data['is_default'] == true || data['is_default'] == 1 || data['isDefault'] == true ||
            name == 'fournisseur passager';
      }).toList();
      if (defaultSuppliers.length > 1) {
        debugPrint('[EnterpriseDefaults] Found ${defaultSuppliers.length} duplicate default suppliers for enterprise $enterpriseId. Cleaning up ${defaultSuppliers.length - 1} duplicates...');
        for (int i = 1; i < defaultSuppliers.length; i++) {
          try {
            await FirebaseFirestore.instance.collection('fournisseurs').doc(defaultSuppliers[i].id).delete();
          } catch (e) {
            debugPrint('[EnterpriseDefaults] Error deleting duplicate supplier ${defaultSuppliers[i].id}: $e');
          }
        }
      }

      // Warehouses: keep oldest and delete duplicate defaults
      final defaultWarehouses = warehousesQuery.docs.where((d) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim().toLowerCase();
        return data['is_default'] == true || data['is_default'] == 1 || data['isDefault'] == true ||
            name == 'entrepôt par défaut' || name == 'entrepot par defaut';
      }).toList();
      if (defaultWarehouses.length > 1) {
        debugPrint('[EnterpriseDefaults] Found ${defaultWarehouses.length} duplicate default warehouses for enterprise $enterpriseId. Cleaning up ${defaultWarehouses.length - 1} duplicates...');
        for (int i = 1; i < defaultWarehouses.length; i++) {
          try {
            await FirebaseFirestore.instance.collection('warehouses').doc(defaultWarehouses[i].id).delete();
          } catch (e) {
            debugPrint('[EnterpriseDefaults] Error deleting duplicate warehouse ${defaultWarehouses[i].id}: $e');
          }
        }
      }

      // Treasury Accounts: keep oldest and delete duplicate defaults
      final defaultAccounts = treasuryQuery.docs.where((d) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim().toLowerCase();
        return data['is_default'] == true || data['is_default'] == 1 || data['isDefault'] == true ||
            name == 'compte principal';
      }).toList();
      if (defaultAccounts.length > 1) {
        debugPrint('[EnterpriseDefaults] Found ${defaultAccounts.length} duplicate default treasury accounts for enterprise $enterpriseId. Cleaning up ${defaultAccounts.length - 1} duplicates...');
        for (int i = 1; i < defaultAccounts.length; i++) {
          try {
            await FirebaseFirestore.instance.collection('treasury_accounts').doc(defaultAccounts[i].id).delete();
            await FirebaseFirestore.instance.collection('comptes_tresorerie').doc(defaultAccounts[i].id).delete();
          } catch (e) {
            debugPrint('[EnterpriseDefaults] Error deleting duplicate treasury account ${defaultAccounts[i].id}: $e');
          }
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      bool hasNewDefaults = false;

      // Warehouse: only create if no non-deleted warehouse exists
      final hasWarehouse = warehousesQuery.docs.any((d) => (d.data()['is_deleted'] != true && d.data()['is_deleted'] != 1));
      if (!hasWarehouse) {
        final defaultWarehouse = Warehouse(
          id: const Uuid().v4(),
          name: 'Entrepôt par défaut',
          reference: 'WH-001',
          isDefault: true,
          isActive: true,
          enterpriseId: enterpriseId,
          createdAt: now,
          updatedAt: now,
        );
        final warehouseData = defaultWarehouse.toMap();
        warehouseData['userId'] = uid;
        batch.set(
          FirebaseFirestore.instance.collection('warehouses').doc(defaultWarehouse.id),
          warehouseData,
          SetOptions(merge: true),
        );
        hasNewDefaults = true;
        debugPrint('[EnterpriseDefaults] Staged default warehouse: ${defaultWarehouse.id}');
      }

      // Customer: only create if no non-deleted customer exists
      final hasCustomer = customersQuery.docs.any((d) => (d.data()['is_deleted'] != true && d.data()['is_deleted'] != 1));
      if (!hasCustomer) {
        final defaultCustomer = Customer(
          id: const Uuid().v4(),
          code: 'CL-00001',
          name: 'Client passager',
          customerType: 'particular',
          country: 'Tunisia',
          deliveryCountry: 'Tunisia',
          priceList: 'HT',
          isDefault: true,
          enterpriseId: enterpriseId,
          createdAt: now,
          updatedAt: now,
        );
        final customerData = defaultCustomer.toMap();
        customerData['userId'] = uid;
        batch.set(
          FirebaseFirestore.instance.collection('clients').doc(defaultCustomer.id),
          customerData,
          SetOptions(merge: true),
        );
        hasNewDefaults = true;
        debugPrint('[EnterpriseDefaults] Staged default customer: ${defaultCustomer.id}');
      }

      // Supplier: only create if no non-deleted supplier exists
      final hasSupplier = suppliersQuery.docs.any((d) => (d.data()['is_deleted'] != true && d.data()['is_deleted'] != 1));
      if (!hasSupplier) {
        final defaultSupplier = Supplier(
          id: const Uuid().v4(),
          code: 'FR-00001',
          name: 'Fournisseur passager',
          supplierType: 'company',
          country: 'Tunisia',
          deliveryCountry: 'Tunisia',
          isDefault: true,
          enterpriseId: enterpriseId,
          createdAt: now,
          updatedAt: now,
        );
        final supplierData = defaultSupplier.toMap();
        supplierData['userId'] = uid;
        batch.set(
          FirebaseFirestore.instance.collection('fournisseurs').doc(defaultSupplier.id),
          supplierData,
          SetOptions(merge: true),
        );
        hasNewDefaults = true;
        debugPrint('[EnterpriseDefaults] Staged default supplier: ${defaultSupplier.id}');
      }

      // Treasury Account: only create if no non-deleted treasury account exists
      final hasTreasury = treasuryQuery.docs.any((d) => (d.data()['is_deleted'] != true && d.data()['is_deleted'] != 1));
      if (!hasTreasury) {
        final defaultAccount = TreasuryAccount(
          id: const Uuid().v4(),
          name: 'Compte principal',
          type: 'cash',
          currency: 'TND',
          isDefault: true,
          enterpriseId: enterpriseId,
          createdAt: now,
          updatedAt: now,
        );
        final accountData = defaultAccount.toMap();
        accountData['userId'] = uid;
        batch.set(
          FirebaseFirestore.instance.collection('treasury_accounts').doc(defaultAccount.id),
          accountData,
          SetOptions(merge: true),
        );
        batch.set(
          FirebaseFirestore.instance.collection('comptes_tresorerie').doc(defaultAccount.id),
          accountData,
          SetOptions(merge: true),
        );
        hasNewDefaults = true;
        debugPrint('[EnterpriseDefaults] Staged default treasury account: ${defaultAccount.id}');
      }

      // Project: only create if no non-deleted project exists
      final hasProject = projectsQuery.docs.any((d) => (d.data()['is_deleted'] != true && d.data()['is_deleted'] != 1));
      if (!hasProject) {
        final defaultProject = Project(
          id: const Uuid().v4(),
          name: 'Projet par défaut',
          description: 'Projet principal par défaut',
          startDate: now,
          status: ProjectStatus.active,
          isDefault: true,
          enterpriseId: enterpriseId,
          createdAt: now,
          updatedAt: now,
        );
        final projectData = defaultProject.toMap();
        projectData['userId'] = uid;
        batch.set(
          FirebaseFirestore.instance.collection('projects').doc(defaultProject.id),
          projectData,
          SetOptions(merge: true),
        );
        hasNewDefaults = true;
        debugPrint('[EnterpriseDefaults] Staged default project: ${defaultProject.id}');
      }

      // Mark enterprise document with defaultsCreated: true in the same batch
      batch.set(
        entDocRef,
        {
          'defaults_created': true,
          'defaultsCreated': true,
          'updated_at': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );

      // Commit all changes atomically
      await batch.commit();
      debugPrint('[EnterpriseDefaults] Successfully committed defaults batch for enterprise $enterpriseId. (New defaults created: $hasNewDefaults)');

      // Update in-memory enterprise cache
      final idx = _enterprises.indexWhere((e) => e.id == enterpriseId);
      if (idx != -1) {
        final updatedList = List<Enterprise>.from(_enterprises);
        updatedList[idx] = updatedList[idx].copyWith(defaultsCreated: true);
        _enterprises = List.unmodifiable(updatedList);
        await _persistToPrefs();
        _enterpriseListController.add(_enterprises);
      }
    } catch (e, stack) {
      debugPrint('[EnterpriseDefaults] Error ensuring default records for enterprise $enterpriseId: $e\n$stack');
    } finally {
      _pendingDefaultCreations.remove(enterpriseId);
    }
  }

  /// Creates a new enterprise and adds the current user as owner/admin.
  /// Enforces single execution via [_isCreatingEnterprise] lock.
  Future<Enterprise> createEnterprise(
    String name, {
    String? description,
    String? phone,
    String? email,
    String? website,
    String? taxId,
    String? rcNumber,
    String? address,
    String? rib,
  }) async {
    if (_isCreatingEnterprise) {
      debugPrint('[EnterpriseService] Enterprise creation already in progress. Rejecting duplicate call.');
      throw 'Une création d\'entreprise est déjà en cours. Veuillez patienter.';
    }

    _isCreatingEnterprise = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local-user';
      final id = const Uuid().v4();
      final now = DateTime.now();

      debugPrint('[EnterpriseService] Creating enterprise "$name" (id: $id)...');

      final enterprise = Enterprise(
        id: id,
        name: name,
        description: description,
        phone: phone,
        email: email,
        website: website,
        taxId: taxId,
        rcNumber: rcNumber,
        address: address,
        rib: rib,
        ownerId: uid,
        members: [EnterpriseMember(uid: uid, role: 'admin')],
        defaultsCreated: false,
        createdAt: now,
        updatedAt: now,
      );

      final adminPerms = UserPermissionResources.getAdminDefaultPermissions()
          .map((k, v) => MapEntry(k, v.toMap()));

      final memberMap = {
        'uid': uid,
        'role': 'admin',
        'isOwner': true,
        'name': FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
        'permissions': adminPerms,
      };

      // Write enterprise doc to Firestore if online
      if (FirebaseAuth.instance.currentUser != null) {
        try {
          await FirebaseFirestore.instance
              .collection('enterprises')
              .doc(id)
              .set({
                ...enterprise.toMap(),
                'owner_id': uid,
                'userId': uid,
                'members': [memberMap],
                'defaults_created': false,
                'defaultsCreated': false,
              });

          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'email': FirebaseAuth.instance.currentUser?.email,
            'role': 'admin',
            'isOwner': true,
            'permissions': adminPerms,
            'enterprises': FieldValue.arrayUnion([id]),
            'currentEnterpriseId': id,
            'enterpriseRoles': {
              id: {
                'role': 'admin',
                'isOwner': true,
                'permissions': adminPerms,
              }
            },
            'updated_at': now.toIso8601String(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[EnterpriseService] createEnterprise Firestore warning: $e');
        }
      }

      // Update local state early so subsequent inserts adopt currentEnterpriseId
      _enterprises = List.unmodifiable([..._enterprises, enterprise]);
      _currentEnterpriseId = id;
      await _persistToPrefs();
      _enterpriseController.add(_currentEnterpriseId);
      _enterpriseListController.add(_enterprises);
      await PermissionService.instance.loadPermissions(enterpriseId: id);

      // Insert company_settings row into SQLite for this enterprise
      try {
        await DatabaseHelper.instance.insert('company_settings', {
          'id': const Uuid().v4(),
          'enterprise_id': id,
          'name': name,
          'phone': phone,
          'email': email,
          'website': website,
          'tax_id': taxId,
          'rc_number': rcNumber,
          'address': address,
          'rib': rib,
          'currency': 'DZD',
          'default_tva_rate': 19,
          'invoice_prefix': 'FAC',
          'next_invoice_number': 1,
          'updated_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('[EnterpriseService] createEnterprise company_settings insert warning: $e');
      }

      // Create default records atomically and mark defaultsCreated: true
      await ensureDefaultRecordsCreated(id, ownerUid: uid);

      _enterpriseController.add(_currentEnterpriseId);

      return enterprise.copyWith(defaultsCreated: true);
    } finally {
      _isCreatingEnterprise = false;
    }
  }

  // ─── Switching ───────────────────────────────────────────────────

  /// Switches the active enterprise. All subsequent queries will use
  /// the new enterprise_id.
  Future<void> setCurrentEnterprise(String enterpriseId) async {
    if (_currentEnterpriseId == enterpriseId) return;

    _currentEnterpriseId = enterpriseId;

    // Persist locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyCurrentId, enterpriseId);

    // Persist to Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'currentEnterpriseId': enterpriseId},
          SetOptions(merge: true),
        );
      } catch (e) {
        print('EnterpriseService.setCurrentEnterprise Firestore error: $e');
      }
    }

    _enterpriseController.add(_currentEnterpriseId);
    await PermissionService.instance.loadPermissions(enterpriseId: enterpriseId);
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  /// Returns the display name of the current enterprise.
  String get currentEnterpriseName {
    if (_currentEnterpriseId == null) return 'Mon Entreprise';
    final match = _enterprises.where((e) => e.id == _currentEnterpriseId);
    return match.isNotEmpty ? match.first.name : 'Mon Entreprise';
  }

  /// Persist current enterprise ID and list to SharedPreferences.
  Future<void> _persistToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentEnterpriseId != null) {
      await prefs.setString(_prefKeyCurrentId, _currentEnterpriseId!);
    }
    // Cache a lightweight list for dropdown rendering
    final listJson = jsonEncode(
      _enterprises.map((e) => {'id': e.id, 'name': e.name, 'owner_id': e.ownerId}).toList(),
    );
    await prefs.setString(_prefKeyEnterprisesJson, listJson);
  }

  /// Clear state on logout.
  Future<void> clear() async {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
    _currentEnterpriseId = null;
    _enterprises = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyCurrentId);
    await prefs.remove(_prefKeyEnterprisesJson);
    _enterpriseController.add(null);
    _enterpriseListController.add([]);
  }

  void dispose() {
    _userDocSubscription?.cancel();
    _enterpriseController.close();
    _enterpriseListController.close();
  }
}
