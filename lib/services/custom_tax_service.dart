import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/custom_tax_rate.dart';
import 'enterprise_service.dart';
import '../database/database_helper.dart';

class CustomTaxService {
  static final CustomTaxService instance = CustomTaxService._();
  CustomTaxService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<CustomTaxRate> _cache = [];
  bool _isLoaded = false;

  final _taxesController = StreamController<List<CustomTaxRate>>.broadcast();
  Stream<List<CustomTaxRate>> get taxesStream => _taxesController.stream;
  List<CustomTaxRate> get cachedTaxes => List.unmodifiable(_cache);

  String? get _currentEnterpriseId =>
      EnterpriseService.instance.currentEnterpriseId ?? DatabaseHelper.instance.currentEnterpriseId;

  /// Retrieves custom taxes, optionally filtered by usage ('sale', 'purchase', or 'all').
  Future<List<CustomTaxRate>> getTaxes({String? usage, bool forceRefresh = false}) async {
    if (!_isLoaded || forceRefresh) {
      await _fetchTaxes();
    }

    if (usage == null || usage.isEmpty || usage == 'all') {
      return List.unmodifiable(_cache);
    }

    return List.unmodifiable(
      _cache.where((t) => t.usage == 'all' || t.usage == usage).toList(),
    );
  }

  Future<void> _fetchTaxes() async {
    final eid = _currentEnterpriseId;
    if (eid == null || eid.isEmpty) {
      _isLoaded = true;
      return;
    }

    try {
      final snap = await _firestore
          .collection('enterprises')
          .doc(eid)
          .collection('custom_taxes')
          .orderBy('priority')
          .get();

      _cache.clear();
      for (final doc in snap.docs) {
        _cache.add(CustomTaxRate.fromMap(doc.data()));
      }
      _isLoaded = true;
      _taxesController.add(List.unmodifiable(_cache));
    } catch (e) {
      debugPrint('[CustomTaxService] Error fetching custom taxes: $e');
      _isLoaded = true;
    }
  }

  /// Adds or updates a custom tax rate.
  Future<void> saveTax(CustomTaxRate tax) async {
    final eid = _currentEnterpriseId;
    final map = tax.toMap();

    final idx = _cache.indexWhere((t) => t.id == tax.id);
    if (idx != -1) {
      _cache[idx] = tax;
    } else {
      _cache.add(tax);
    }
    _cache.sort((a, b) => a.priority.compareTo(b.priority));
    _taxesController.add(List.unmodifiable(_cache));

    if (eid != null && eid.isNotEmpty) {
      try {
        await _firestore
            .collection('enterprises')
            .doc(eid)
            .collection('custom_taxes')
            .doc(tax.id)
            .set(map, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[CustomTaxService] Error saving custom tax: $e');
      }
    }
  }

  /// Deletes a custom tax rate.
  Future<void> deleteTax(String taxId) async {
    final eid = _currentEnterpriseId;
    _cache.removeWhere((t) => t.id == taxId);
    _taxesController.add(List.unmodifiable(_cache));

    if (eid != null && eid.isNotEmpty) {
      try {
        await _firestore
            .collection('enterprises')
            .doc(eid)
            .collection('custom_taxes')
            .doc(taxId)
            .delete();
      } catch (e) {
        debugPrint('[CustomTaxService] Error deleting custom tax: $e');
      }
    }
  }
}
