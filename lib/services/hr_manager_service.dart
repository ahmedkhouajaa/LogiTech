import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/hr_manager.dart';
import 'enterprise_service.dart';

class HrManagerService {
  static final HrManagerService instance = HrManagerService._();
  HrManagerService._();

  CollectionReference _collectionRef(String enterpriseId) {
    return FirebaseFirestore.instance
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('hr_managers');
  }

  /// Stream all platform managers of an enterprise in real time
  Stream<List<HrManager>> streamManagers(String enterpriseId) {
    if (enterpriseId.isEmpty) {
      return Stream.value([]);
    }

    return _collectionRef(enterpriseId).snapshots().map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final list = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return HrManager.fromMap(data, docId: doc.id);
        }).toList();

        list.sort((a, b) {
          if (a.isOwner) return -1;
          if (b.isOwner) return 1;
          return a.createdAt.compareTo(b.createdAt);
        });
        return list;
      }

      // If empty, auto-seed the creator / current user as first manager matching Image 1
      _seedInitialManager(enterpriseId);
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentEmail = currentUser?.email ?? 'ahmedkhouaja2000@gmail.com';
      final currentName = currentUser?.displayName ?? 'dd sameh';
      final parts = currentName.split(' ');
      final fallback = HrManager(
        id: 'owner_default',
        enterpriseId: enterpriseId,
        lastName: parts.isNotEmpty ? parts.first : 'dd',
        firstName: parts.length > 1 ? parts.sublist(1).join(' ') : 'sameh',
        email: currentEmail,
        roles: const ['Administrateur', 'Manager'],
        isOwner: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return [fallback];
    });
  }

  Future<void> _seedInitialManager(String enterpriseId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final enterprise = EnterpriseService.instance.currentEnterprise;
      final email = currentUser?.email ?? enterprise?.email ?? 'ahmedkhouaja2000@gmail.com';
      final name = currentUser?.displayName ?? enterprise?.name ?? 'dd sameh';
      final parts = name.split(' ');
      final lastName = parts.isNotEmpty ? parts.first : 'dd';
      final firstName = parts.length > 1 ? parts.sublist(1).join(' ') : 'sameh';

      final initial = HrManager(
        id: 'owner_default',
        enterpriseId: enterpriseId,
        lastName: lastName,
        firstName: firstName,
        email: email,
        roles: const ['Administrateur', 'Manager'],
        isOwner: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _collectionRef(enterpriseId).doc('owner_default').set(initial.toMap());
    } catch (e) {
      debugPrint('[HrManagerService] _seedInitialManager error: $e');
    }
  }

  /// Create or invite a new manager
  Future<HrManager> inviteManager(HrManager manager) async {
    final id = manager.id.isNotEmpty
        ? manager.id
        : 'mgr_${const Uuid().v4().substring(0, 8)}';

    final toSave = manager.copyWith(
      id: id,
      createdAt: manager.createdAt,
      updatedAt: DateTime.now(),
    );

    await _collectionRef(manager.enterpriseId).doc(id).set(toSave.toMap());
    return toSave;
  }

  /// Update an existing manager
  Future<void> updateManager(HrManager manager) async {
    final toSave = manager.copyWith(updatedAt: DateTime.now());
    await _collectionRef(manager.enterpriseId)
        .doc(manager.id)
        .update(toSave.toMap());
  }

  /// Delete a manager
  Future<void> deleteManager(String enterpriseId, String managerId) async {
    await _collectionRef(enterpriseId).doc(managerId).delete();
  }
}
