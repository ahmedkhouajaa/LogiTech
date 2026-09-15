import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/custom_field_definition.dart';
import 'enterprise_service.dart';
import '../database/database_helper.dart';

class CustomFieldsService {
  static final CustomFieldsService instance = CustomFieldsService._();
  CustomFieldsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache keyed by enterpriseId
  final Map<String, List<CustomFieldDefinition>> _cache = {};

  // Broadcaster for change events
  final _changeController = StreamController<String>.broadcast();
  Stream<String> get changeStream => _changeController.stream;

  String? get _currentEnterpriseId =>
      EnterpriseService.instance.currentEnterpriseId ?? DatabaseHelper.instance.currentEnterpriseId;

  /// Retrieves custom fields configured for a specific document type.
  Future<List<CustomFieldDefinition>> getCustomFields(
    String documentType, {
    String? enterpriseId,
    bool forceRefresh = false,
  }) async {
    final eid = enterpriseId ?? _currentEnterpriseId;
    if (eid == null || eid.isEmpty) return [];

    if (!forceRefresh && _cache.containsKey(eid)) {
      final list = _cache[eid]!
          .where((f) => f.documentType == documentType)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return list;
    }

    await _fetchAllForEnterprise(eid);

    final list = (_cache[eid] ?? [])
        .where((f) => f.documentType == documentType)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Retrieves all custom fields across all document types for an enterprise.
  Future<List<CustomFieldDefinition>> getAllCustomFields({String? enterpriseId}) async {
    final eid = enterpriseId ?? _currentEnterpriseId;
    if (eid == null || eid.isEmpty) return [];

    if (!_cache.containsKey(eid)) {
      await _fetchAllForEnterprise(eid);
    }
    return _cache[eid] ?? [];
  }

  Future<void> _fetchAllForEnterprise(String enterpriseId) async {
    try {
      final snap = await _firestore
          .collection('enterprises')
          .doc(enterpriseId)
          .collection('custom_fields')
          .get();

      if (snap.docs.isEmpty) {
        // Also check top-level collection for backwards compatibility
        final topSnap = await _firestore
            .collection('custom_fields')
            .where('enterprise_id', isEqualTo: enterpriseId)
            .get();

        if (topSnap.docs.isNotEmpty) {
          _cache[enterpriseId] = topSnap.docs
              .map((d) => CustomFieldDefinition.fromMap(d.data(), id: d.id))
              .toList();
          return;
        }
      }

      _cache[enterpriseId] = snap.docs
          .map((d) => CustomFieldDefinition.fromMap(d.data(), id: d.id))
          .toList();
    } catch (e) {
      debugPrint('[CustomFieldsService] Error fetching fields: $e');
      _cache[enterpriseId] ??= [];
    }
  }

  /// Adds or updates a custom field definition.
  Future<void> saveCustomField(CustomFieldDefinition field) async {
    final eid = field.enterpriseId.isNotEmpty ? field.enterpriseId : _currentEnterpriseId;
    if (eid == null || eid.isEmpty) return;

    final docId = field.id.isNotEmpty
        ? field.id
        : _firestore.collection('enterprises').doc(eid).collection('custom_fields').doc().id;

    final updated = field.copyWith(id: docId, enterpriseId: eid);
    final map = updated.toMap();

    try {
      // Save in subcollection
      await _firestore
          .collection('enterprises')
          .doc(eid)
          .collection('custom_fields')
          .doc(docId)
          .set(map, SetOptions(merge: true));

      // Also set top-level for cross-querying if needed
      await _firestore
          .collection('custom_fields')
          .doc(docId)
          .set(map, SetOptions(merge: true));

      // Update in-memory cache
      _cache[eid] ??= [];
      final idx = _cache[eid]!.indexWhere((f) => f.id == docId);
      if (idx != -1) {
        _cache[eid]![idx] = updated;
      } else {
        _cache[eid]!.add(updated);
      }

      _changeController.add(field.documentType);
    } catch (e) {
      debugPrint('[CustomFieldsService] Error saving custom field: $e');
      rethrow;
    }
  }

  /// Deletes a custom field definition.
  Future<void> deleteCustomField(String fieldId, {String? enterpriseId, String? documentType}) async {
    final eid = enterpriseId ?? _currentEnterpriseId;
    if (eid == null || eid.isEmpty) return;

    try {
      await _firestore
          .collection('enterprises')
          .doc(eid)
          .collection('custom_fields')
          .doc(fieldId)
          .delete();

      await _firestore.collection('custom_fields').doc(fieldId).delete();

      if (_cache.containsKey(eid)) {
        _cache[eid]!.removeWhere((f) => f.id == fieldId);
      }

      _changeController.add(documentType ?? 'all');
    } catch (e) {
      debugPrint('[CustomFieldsService] Error deleting custom field: $e');
      rethrow;
    }
  }

  /// Invalidate cache
  void clearCache() {
    _cache.clear();
  }
}
