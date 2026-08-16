import 'dart:async';
import 'dart:convert';
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

  final _enterpriseController = StreamController<String?>.broadcast();

  /// The currently active enterprise ID, used by all data queries.
  String? get currentEnterpriseId => _currentEnterpriseId;

  /// Stream that emits whenever the active enterprise changes.
  Stream<String?> get enterpriseStream => _enterpriseController.stream;

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
        _enterprises = decoded
            .map((e) => Enterprise.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        _enterprises = [];
      }
    }
    unawaited(PermissionService.instance.loadPermissions());
  }

  /// Clears in-memory and cached enterprise data on logout.
  Future<void> clearCache() async {
    _currentEnterpriseId = null;
    _enterprises = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyCurrentId);
    await prefs.remove(_prefKeyEnterprisesJson);
    _enterpriseController.add(null);
  }

  // ─── Enterprise CRUD ─────────────────────────────────────────────

  /// Loads enterprises for the current user from Firestore and updates cache.
  Future<List<Enterprise>> loadEnterprisesFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

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

      _enterprises = result;

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
      await PermissionService.instance.loadPermissions(enterpriseId: _currentEnterpriseId);
      return _enterprises;
    } catch (e) {
      print('EnterpriseService.loadEnterprisesFromFirestore error: $e');
      return _enterprises; // Return cached list on failure
    }
  }

  /// Creates a new enterprise and adds the current user as owner/admin.
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local-user';
    final id = const Uuid().v4();
    final now = DateTime.now();

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
        print('EnterpriseService.createEnterprise Firestore warning: $e');
      }
    }

    // Update local state early so subsequent inserts adopt currentEnterpriseId
    _enterprises.add(enterprise);
    _currentEnterpriseId = id;
    await _persistToPrefs();
    _enterpriseController.add(_currentEnterpriseId);
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
      print('EnterpriseService.createEnterprise company_settings insert warning: $e');
    }

    // Insert default warehouse for this enterprise
    try {
      final defaultWarehouse = Warehouse(
        id: const Uuid().v4(),
        name: 'Entrepôt par défaut',
        reference: 'WH-001',
        isDefault: true,
        isActive: true,
        enterpriseId: id,
        createdAt: now,
        updatedAt: now,
      );
      await DatabaseHelper.instance.insertWarehouse(defaultWarehouse);
      final warehouseData = defaultWarehouse.toMap();
      warehouseData['userId'] = uid;
      FirebaseFirestore.instance
          .collection('warehouses')
          .doc(defaultWarehouse.id)
          .set(warehouseData, SetOptions(merge: true))
          .catchError((e) => print('Firestore warehouse sync error: $e'));
    } catch (e) {
      print('EnterpriseService.createEnterprise default warehouse insert warning: $e');
    }

    // Insert default customer ("Client passager") for this enterprise
    try {
      final defaultCustomer = Customer(
        id: const Uuid().v4(),
        code: 'CL-00001',
        name: 'Client passager',
        customerType: 'particular',
        country: 'Tunisia',
        deliveryCountry: 'Tunisia',
        priceList: 'HT',
        isDefault: true,
        enterpriseId: id,
        createdAt: now,
        updatedAt: now,
      );
      await DatabaseHelper.instance.insertCustomer(defaultCustomer);
      final customerData = defaultCustomer.toMap();
      customerData['userId'] = uid;
      FirebaseFirestore.instance
          .collection('clients')
          .doc(defaultCustomer.id)
          .set(customerData, SetOptions(merge: true))
          .catchError((e) => print('Firestore customer sync error: $e'));
    } catch (e) {
      print('EnterpriseService.createEnterprise default customer insert warning: $e');
    }

    // Insert default supplier ("Fournisseur passager") for this enterprise
    try {
      final defaultSupplier = Supplier(
        id: const Uuid().v4(),
        code: 'FR-00001',
        name: 'Fournisseur passager',
        supplierType: 'company',
        country: 'Tunisia',
        deliveryCountry: 'Tunisia',
        isDefault: true,
        enterpriseId: id,
        createdAt: now,
        updatedAt: now,
      );
      await DatabaseHelper.instance.insertSupplier(defaultSupplier);
      final supplierData = defaultSupplier.toMap();
      supplierData['userId'] = uid;
      FirebaseFirestore.instance
          .collection('fournisseurs')
          .doc(defaultSupplier.id)
          .set(supplierData, SetOptions(merge: true))
          .catchError((e) => print('Firestore supplier sync error: $e'));
    } catch (e) {
      print('EnterpriseService.createEnterprise default supplier insert warning: $e');
    }

    // Insert default treasury account ("Compte principal") for this enterprise
    try {
      final defaultAccount = TreasuryAccount(
        id: const Uuid().v4(),
        name: 'Compte principal',
        type: 'cash',
        currency: 'TND',
        isDefault: true,
        enterpriseId: id,
        createdAt: now,
        updatedAt: now,
      );
      await DatabaseHelper.instance.createTreasuryAccount(defaultAccount.toMap());
      final accountData = defaultAccount.toMap();
      accountData['userId'] = uid;
      FirebaseFirestore.instance
          .collection('treasury_accounts')
          .doc(defaultAccount.id)
          .set(accountData, SetOptions(merge: true))
          .catchError((e) => print('Firestore treasury account sync error: $e'));
      FirebaseFirestore.instance
          .collection('comptes_tresorerie')
          .doc(defaultAccount.id)
          .set(accountData, SetOptions(merge: true))
          .catchError((e) => print('Firestore treasury account sync error: $e'));
    } catch (e) {
      print('EnterpriseService.createEnterprise default treasury account insert warning: $e');
    }

    // Insert default project ("Projet par défaut") for this enterprise
    try {
      final defaultProject = Project(
        id: const Uuid().v4(),
        name: 'Projet par défaut',
        description: 'Projet principal par défaut',
        startDate: now,
        status: ProjectStatus.active,
        isDefault: true,
        enterpriseId: id,
        createdAt: now,
        updatedAt: now,
      );
      await DatabaseHelper.instance.insertProject(defaultProject);
      final projectData = defaultProject.toMap();
      projectData['userId'] = uid;
      FirebaseFirestore.instance
          .collection('projects')
          .doc(defaultProject.id)
          .set(projectData, SetOptions(merge: true))
          .catchError((e) => print('Firestore project sync error: $e'));
    } catch (e) {
      print('EnterpriseService.createEnterprise default project insert warning: $e');
    }

    _enterpriseController.add(_currentEnterpriseId);

    return enterprise;
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
    _currentEnterpriseId = null;
    _enterprises = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyCurrentId);
    await prefs.remove(_prefKeyEnterprisesJson);
    _enterpriseController.add(null);
  }

  void dispose() {
    _enterpriseController.close();
  }
}
