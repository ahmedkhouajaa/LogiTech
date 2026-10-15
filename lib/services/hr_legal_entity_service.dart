import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/enterprise.dart';
import '../models/hr_legal_entity.dart';
import 'enterprise_service.dart';

class HrLegalEntityService {
  static final HrLegalEntityService instance = HrLegalEntityService._();
  HrLegalEntityService._();

  final Map<String, HrLegalEntity> _cached = {};
  bool _isSyncing = false;

  CollectionReference _collectionRef(String enterpriseId) {
    return FirebaseFirestore.instance
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('hr_legal_entities');
  }

  DocumentReference _docRef(String enterpriseId, [String? entityId]) {
    final eid = (entityId != null && entityId.isNotEmpty) ? entityId : 'default';
    return _collectionRef(enterpriseId).doc(eid);
  }

  /// Stream all legal entities of an enterprise in real time
  Stream<List<HrLegalEntity>> streamLegalEntities(String enterpriseId) {
    if (enterpriseId.isEmpty) {
      return Stream.value([]);
    }

    return _collectionRef(enterpriseId).snapshots().map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final list = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final entity = HrLegalEntity.fromMap(data);
          _cached['${enterpriseId}_${entity.id}'] = entity;
          return entity;
        }).toList();

        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return list;
      }

      // If no docs exist yet, create initial from Enterprise
      final currentEnt = EnterpriseService.instance.currentEnterprise;
      if (currentEnt != null) {
        final initial = HrLegalEntity.fromEnterprise(currentEnt);
        _docRef(enterpriseId, 'default').set(initial.toMap()).catchError((e) {
          debugPrint('[HrLegalEntityService] initial set error: $e');
        });
        _cached['${enterpriseId}_default'] = initial;
        return [initial];
      }

      final fallback = HrLegalEntity(
        id: 'default',
        enterpriseId: enterpriseId,
        socialReason: 'Mon Entreprise',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _cached['${enterpriseId}_default'] = fallback;
      return [fallback];
    });
  }

  /// Stream real-time changes to a legal entity of the given enterprise
  Stream<HrLegalEntity> streamLegalEntity(String enterpriseId, {String? entityId}) {
    if (enterpriseId.isEmpty) {
      return Stream.value(
        HrLegalEntity(
          id: 'default',
          enterpriseId: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    final targetId = (entityId != null && entityId.isNotEmpty) ? entityId : 'default';
    return _docRef(enterpriseId, targetId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final entity = HrLegalEntity.fromMap(data);
        _cached['${enterpriseId}_$targetId'] = entity;
        return entity;
      }

      // If document doesn't exist yet, construct from current Enterprise
      final currentEnt = EnterpriseService.instance.currentEnterprise;
      if (currentEnt != null) {
        final initial = HrLegalEntity.fromEnterprise(currentEnt);
        // Persist initial in background so it exists
        _docRef(enterpriseId, targetId).set(initial.toMap()).catchError((e) {
          debugPrint('[HrLegalEntityService] initial set error: $e');
        });
        _cached['${enterpriseId}_$targetId'] = initial;
        return initial;
      }

      final fallback = HrLegalEntity(
        id: targetId,
        enterpriseId: enterpriseId,
        socialReason: 'Mon Entreprise',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _cached['${enterpriseId}_$targetId'] = fallback;
      return fallback;
    });
  }

  /// Create a new legal entity for the enterprise
  Future<HrLegalEntity> createLegalEntity(HrLegalEntity entity) async {
    if (entity.enterpriseId.isEmpty) {
      throw 'Identifiant de l\'entreprise manquant.';
    }

    final id = (entity.id.isNotEmpty && entity.id != 'default')
        ? entity.id
        : const Uuid().v4();
    final now = DateTime.now();
    final newEntity = entity.copyWith(
      id: id,
      createdAt: now,
      updatedAt: now,
    );

    _cached['${entity.enterpriseId}_$id'] = newEntity;
    await _docRef(entity.enterpriseId, id).set(newEntity.toMap());
    return newEntity;
  }

  /// Synchronous cached or fast fetch
  Future<HrLegalEntity> getOrCreateLegalEntity(String enterpriseId, {String? entityId}) async {
    if (enterpriseId.isEmpty) {
      return HrLegalEntity(
        id: 'default',
        enterpriseId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    final targetId = (entityId != null && entityId.isNotEmpty) ? entityId : 'default';
    final cacheKey = '${enterpriseId}_$targetId';
    if (_cached.containsKey(cacheKey)) {
      return _cached[cacheKey]!;
    }

    try {
      final doc = await _docRef(enterpriseId, targetId).get();
      if (doc.exists && doc.data() != null) {
        final entity = HrLegalEntity.fromMap(doc.data() as Map<String, dynamic>);
        _cached[cacheKey] = entity;
        return entity;
      }

      final ent = EnterpriseService.instance.currentEnterprise;
      final newEntity = ent != null
          ? HrLegalEntity.fromEnterprise(ent).copyWith(id: targetId)
          : HrLegalEntity(
              id: targetId,
              enterpriseId: enterpriseId,
              socialReason: 'Mon Entreprise',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      await _docRef(enterpriseId, targetId).set(newEntity.toMap());
      _cached[cacheKey] = newEntity;
      return newEntity;
    } catch (e) {
      debugPrint('[HrLegalEntityService] getOrCreate error: $e');
      final fallback = HrLegalEntity(
        id: targetId,
        enterpriseId: enterpriseId,
        socialReason: 'Mon Entreprise',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return fallback;
    }
  }

  /// Save legal entity changes, and automatically synchronize shared fields
  /// back to Enterprise ("Informations de la société") so both stay in sync in real time.
  Future<void> saveLegalEntity(HrLegalEntity entity) async {
    if (entity.enterpriseId.isEmpty) return;
    final entityId = entity.id.isNotEmpty ? entity.id : 'default';
    final updated = entity.copyWith(id: entityId, updatedAt: DateTime.now());
    _cached['${entity.enterpriseId}_$entityId'] = updated;
    await _docRef(entity.enterpriseId, entityId).set(updated.toMap(), SetOptions(merge: true));

    // Two-way sync: automatically propagate changes to Enterprise
    if (!_isSyncing) {
      _isSyncing = true;
      try {
        await _syncToEnterprise(updated);
      } catch (e) {
        debugPrint('[HrLegalEntityService] Error syncing to enterprise: $e');
      } finally {
        _isSyncing = false;
      }
    }
  }

  Future<void> _syncToEnterprise(HrLegalEntity entity) async {
    final entService = EnterpriseService.instance;
    Enterprise? targetEnt;
    try {
      targetEnt = entService.enterprises.firstWhere((e) => e.id == entity.enterpriseId);
    } catch (_) {
      if (entService.currentEnterprise?.id == entity.enterpriseId) {
        targetEnt = entService.currentEnterprise;
      }
    }

    if (targetEnt == null) {
      // Fallback: update document in Firestore directly if enterprise is not yet cached
      final updateMap = <String, dynamic>{};
      if (entity.socialReason.isNotEmpty && entity.socialReason != '-') {
        updateMap['name'] = entity.socialReason;
      }
      if (entity.taxId != '-') {
        updateMap['tax_id'] = entity.taxId;
        updateMap['taxId'] = entity.taxId;
      }
      if (entity.address != '-') {
        updateMap['address'] = entity.address;
      }
      if (entity.iban != '-') {
        updateMap['rib'] = entity.iban;
      }
      if (updateMap.isNotEmpty) {
        updateMap['updatedAt'] = DateTime.now().toIso8601String();
        await FirebaseFirestore.instance
            .collection('enterprises')
            .doc(entity.enterpriseId)
            .set(updateMap, SetOptions(merge: true));
      }
      return;
    }

    final newName = (entity.socialReason.isNotEmpty && entity.socialReason != '-')
        ? entity.socialReason
        : targetEnt.name;
    final newTaxId = (entity.taxId != '-') ? entity.taxId : (targetEnt.taxId ?? '');
    final newAddress = (entity.address != '-') ? entity.address : (targetEnt.address ?? '');
    final newRib = (entity.iban != '-') ? entity.iban : (targetEnt.rib ?? '');

    final hasChanges = targetEnt.name != newName ||
        (targetEnt.taxId ?? '') != newTaxId ||
        (targetEnt.address ?? '') != newAddress ||
        (targetEnt.rib ?? '') != newRib;

    if (!hasChanges) return;

    final updatedEnt = targetEnt.copyWith(
      name: newName,
      taxId: newTaxId,
      address: newAddress,
      rib: newRib,
      updatedAt: DateTime.now(),
    );

    await entService.updateEnterprise(updatedEnt);
  }

  /// Called automatically whenever Enterprise ("Informations de la société") is updated.
  /// Updates shared fields in hr_legal_entities/default doc while preserving all HR/payroll fields.
  Future<void> updateFromEnterprise(Enterprise ent) async {
    if (ent.id.isEmpty) return;
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      final current = await getOrCreateLegalEntity(ent.id);

      final newSocialReason = ent.name.trim().isNotEmpty ? ent.name.trim() : current.socialReason;
      final newTaxId = (ent.taxId != null && ent.taxId!.trim().isNotEmpty) ? ent.taxId!.trim() : current.taxId;
      final newAddress = (ent.address != null && ent.address!.trim().isNotEmpty) ? ent.address!.trim() : current.address;
      final newIban = (ent.rib != null && ent.rib!.trim().isNotEmpty) ? ent.rib!.trim() : current.iban;
      final newBankAccountName = (current.bankAccountName == '-' ||
              current.bankAccountName.isEmpty ||
              current.bankAccountName == current.socialReason)
          ? newSocialReason
          : current.bankAccountName;

      final hasChanges = current.socialReason != newSocialReason ||
          current.taxId != newTaxId ||
          current.address != newAddress ||
          current.iban != newIban ||
          current.bankAccountName != newBankAccountName;

      if (!hasChanges) return;

      final updated = current.copyWith(
        socialReason: newSocialReason,
        taxId: newTaxId,
        address: newAddress,
        iban: newIban,
        bankAccountName: newBankAccountName,
        updatedAt: DateTime.now(),
      );

      _cached[ent.id] = updated;
      await _docRef(ent.id).set(updated.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[HrLegalEntityService] Error updating from enterprise: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Re-sync fields from "Informations de la société" (Enterprise)
  Future<HrLegalEntity> syncFromCompanyInfo(String enterpriseId) async {
    final current = await getOrCreateLegalEntity(enterpriseId);
    final ent = EnterpriseService.instance.currentEnterprise;
    if (ent == null) return current;

    final updated = current.copyWith(
      socialReason: ent.name.isNotEmpty ? ent.name : current.socialReason,
      taxId: (ent.taxId != null && ent.taxId!.trim().isNotEmpty) ? ent.taxId!.trim() : current.taxId,
      address: (ent.address != null && ent.address!.trim().isNotEmpty) ? ent.address!.trim() : current.address,
      iban: (ent.rib != null && ent.rib!.trim().isNotEmpty) ? ent.rib!.trim() : current.iban,
      bankAccountName: ent.name.isNotEmpty ? ent.name : current.bankAccountName,
      updatedAt: DateTime.now(),
    );

    await saveLegalEntity(updated);
    return updated;
  }
}
