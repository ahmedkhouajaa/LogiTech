import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/hr_establishment.dart';

class HrEstablishmentService {
  static final HrEstablishmentService instance = HrEstablishmentService._();
  HrEstablishmentService._();

  CollectionReference _collectionRef(String enterpriseId) {
    return FirebaseFirestore.instance
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('hr_establishments');
  }

  /// Stream all establishments of an enterprise in real time
  Stream<List<HrEstablishment>> streamEstablishments(String enterpriseId) {
    if (enterpriseId.isEmpty) {
      return Stream.value([]);
    }

    return _collectionRef(enterpriseId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return HrEstablishment.fromMap(data, docId: doc.id);
      }).toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream a single establishment in real time
  Stream<HrEstablishment?> streamEstablishment(String enterpriseId, String establishmentId) {
    if (enterpriseId.isEmpty || establishmentId.isEmpty) {
      return Stream.value(null);
    }
    return _collectionRef(enterpriseId).doc(establishmentId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return HrEstablishment.fromMap(doc.data() as Map<String, dynamic>, docId: doc.id);
    });
  }

  /// Get all establishments once
  Future<List<HrEstablishment>> getEstablishments(String enterpriseId) async {
    if (enterpriseId.isEmpty) return [];
    try {
      final snapshot = await _collectionRef(enterpriseId).get();
      final list = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return HrEstablishment.fromMap(data, docId: doc.id);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('[HrEstablishmentService] getEstablishments error: $e');
      return [];
    }
  }

  /// Create a new establishment
  Future<HrEstablishment> createEstablishment(HrEstablishment establishment) async {
    final id = establishment.id.isNotEmpty
        ? establishment.id
        : 'est_${const Uuid().v4().substring(0, 8)}';

    final toSave = establishment.copyWith(
      id: id,
      createdAt: establishment.createdAt,
      updatedAt: DateTime.now(),
    );

    await _collectionRef(establishment.enterpriseId).doc(id).set(toSave.toMap());
    return toSave;
  }

  /// Update an existing establishment
  Future<void> updateEstablishment(HrEstablishment establishment) async {
    final toSave = establishment.copyWith(updatedAt: DateTime.now());
    await _collectionRef(establishment.enterpriseId)
        .doc(establishment.id)
        .update(toSave.toMap());
  }

  /// Delete an establishment
  Future<void> deleteEstablishment(String enterpriseId, String establishmentId) async {
    await _collectionRef(enterpriseId).doc(establishmentId).delete();
  }

  /// Toggle active/inactive status
  Future<void> toggleEstablishmentStatus(
    String enterpriseId,
    String establishmentId,
    bool currentStatus,
  ) async {
    await _collectionRef(enterpriseId).doc(establishmentId).update({
      'isActive': !currentStatus,
      'updatedAt': Timestamp.now(),
    });
  }
}
