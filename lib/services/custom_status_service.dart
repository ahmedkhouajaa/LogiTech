import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/custom_status_definition.dart';
import '../utils/constants.dart';
import 'enterprise_service.dart';

class StatusInfo {
  final String label;
  final Color color;
  final bool isCustom;

  const StatusInfo({
    required this.label,
    required this.color,
    this.isCustom = false,
  });
}

class CustomStatusService {
  static final CustomStatusService instance = CustomStatusService._();
  CustomStatusService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache keyed by enterpriseId
  final Map<String, List<CustomStatusDefinition>> _cache = {};

  // Broadcaster for change events
  final _changeController = StreamController<String>.broadcast();
  Stream<String> get changeStream => _changeController.stream;

  String? get _currentEnterpriseId =>
      EnterpriseService.instance.currentEnterpriseId;

  /// Default system statuses for each of the 12 document types.
  static final Map<String, List<CustomStatusDefinition>> _defaultStatuses = {
    // 1. Devis (quote)
    'quote': [
      CustomStatusDefinition(
        id: 'default_quote_draft',
        enterpriseId: '',
        documentType: 'quote',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_quote_sent',
        enterpriseId: '',
        documentType: 'quote',
        name: 'Envoyé',
        key: 'sent',
        colorValue: const Color(0xFFA855F7).toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_quote_accepted',
        enterpriseId: '',
        documentType: 'quote',
        name: 'Accepté',
        key: 'accepted',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 2,
      ),
      CustomStatusDefinition(
        id: 'default_quote_rejected',
        enterpriseId: '',
        documentType: 'quote',
        name: 'Refusé',
        key: 'rejected',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 3,
      ),
      CustomStatusDefinition(
        id: 'default_quote_converted',
        enterpriseId: '',
        documentType: 'quote',
        name: 'Converti',
        key: 'converted',
        colorValue: AppColors.info.toARGB32(),
        isDefault: true,
        order: 4,
      ),
      CustomStatusDefinition(
        id: 'default_quote_cancelled',
        enterpriseId: '',
        documentType: 'quote',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.textTertiary.toARGB32(),
        isDefault: true,
        order: 5,
      ),
    ],

    // 2. Facture de vente (invoice)
    'invoice': [
      CustomStatusDefinition(
        id: 'default_invoice_draft',
        enterpriseId: '',
        documentType: 'invoice',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_invoice_sent',
        enterpriseId: '',
        documentType: 'invoice',
        name: 'Envoyée',
        key: 'sent',
        colorValue: AppColors.info.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_invoice_partial',
        enterpriseId: '',
        documentType: 'invoice',
        name: 'Partiellement payée',
        key: 'partial',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 2,
      ),
      CustomStatusDefinition(
        id: 'default_invoice_paid',
        enterpriseId: '',
        documentType: 'invoice',
        name: 'Payée',
        key: 'paid',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 3,
      ),
      CustomStatusDefinition(
        id: 'default_invoice_unpaid',
        enterpriseId: '',
        documentType: 'invoice',
        name: 'Non payé',
        key: 'unpaid',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 4,
      ),
      CustomStatusDefinition(
        id: 'default_invoice_overdue',
        enterpriseId: '',
        documentType: 'invoice',
        name: 'En retard',
        key: 'overdue',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 5,
      ),
      CustomStatusDefinition(
        id: 'default_invoice_cancelled',
        enterpriseId: '',
        documentType: 'invoice',
        name: 'Annulée',
        key: 'cancelled',
        colorValue: AppColors.textTertiary.toARGB32(),
        isDefault: true,
        order: 6,
      ),
    ],

    // 3. Commande client (customer_order)
    'customer_order': [
      CustomStatusDefinition(
        id: 'default_corder_draft',
        enterpriseId: '',
        documentType: 'customer_order',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_corder_created',
        enterpriseId: '',
        documentType: 'customer_order',
        name: 'Créé',
        key: 'created',
        colorValue: AppColors.primary.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_corder_in_progress',
        enterpriseId: '',
        documentType: 'customer_order',
        name: 'En cours',
        key: 'inProgress',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 2,
      ),
      CustomStatusDefinition(
        id: 'default_corder_delivered',
        enterpriseId: '',
        documentType: 'customer_order',
        name: 'Livré',
        key: 'delivered',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 3,
      ),
      CustomStatusDefinition(
        id: 'default_corder_validated',
        enterpriseId: '',
        documentType: 'customer_order',
        name: 'Validée',
        key: 'validated',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 4,
      ),
      CustomStatusDefinition(
        id: 'default_corder_invoiced',
        enterpriseId: '',
        documentType: 'customer_order',
        name: 'Validée et facturée',
        key: 'validatedAndInvoiced',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 5,
      ),
      CustomStatusDefinition(
        id: 'default_corder_cancelled',
        enterpriseId: '',
        documentType: 'customer_order',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.textTertiary.toARGB32(),
        isDefault: true,
        order: 6,
      ),
    ],

    // 4. Bon de livraison (delivery_note)
    'delivery_note': [
      CustomStatusDefinition(
        id: 'default_dnote_draft',
        enterpriseId: '',
        documentType: 'delivery_note',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_dnote_created',
        enterpriseId: '',
        documentType: 'delivery_note',
        name: 'Créé',
        key: 'created',
        colorValue: AppColors.primary.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_dnote_delivered',
        enterpriseId: '',
        documentType: 'delivery_note',
        name: 'Livré',
        key: 'delivered',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 2,
      ),
      CustomStatusDefinition(
        id: 'default_dnote_invoiced',
        enterpriseId: '',
        documentType: 'delivery_note',
        name: 'Livré et Facturé',
        key: 'invoiced',
        colorValue: AppColors.primary.toARGB32(),
        isDefault: true,
        order: 3,
      ),
      CustomStatusDefinition(
        id: 'default_dnote_returned',
        enterpriseId: '',
        documentType: 'delivery_note',
        name: 'Retourné',
        key: 'returned',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 4,
      ),
      CustomStatusDefinition(
        id: 'default_dnote_paid',
        enterpriseId: '',
        documentType: 'delivery_note',
        name: 'Payé',
        key: 'paid',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 5,
      ),
      CustomStatusDefinition(
        id: 'default_dnote_cancelled',
        enterpriseId: '',
        documentType: 'delivery_note',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 6,
      ),
    ],

    // 5. Bon de sortie (exit_voucher)
    'exit_voucher': [
      CustomStatusDefinition(
        id: 'default_evoucher_draft',
        enterpriseId: '',
        documentType: 'exit_voucher',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_evoucher_validated',
        enterpriseId: '',
        documentType: 'exit_voucher',
        name: 'Validé',
        key: 'validated',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_evoucher_cancelled',
        enterpriseId: '',
        documentType: 'exit_voucher',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 2,
      ),
    ],

    // 6. Avoir client (credit_note)
    'credit_note': [
      CustomStatusDefinition(
        id: 'default_cnote_unused',
        enterpriseId: '',
        documentType: 'credit_note',
        name: 'Non utilisé',
        key: 'unused',
        colorValue: AppColors.info.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_cnote_partially_used',
        enterpriseId: '',
        documentType: 'credit_note',
        name: 'Partiellement utilisé',
        key: 'partiallyUsed',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_cnote_used',
        enterpriseId: '',
        documentType: 'credit_note',
        name: 'Utilisé',
        key: 'used',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 2,
      ),
      CustomStatusDefinition(
        id: 'default_cnote_cancelled',
        enterpriseId: '',
        documentType: 'credit_note',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 3,
      ),
    ],

    // 7. Bon de retour client (return_voucher)
    'return_voucher': [
      CustomStatusDefinition(
        id: 'default_rnote_draft',
        enterpriseId: '',
        documentType: 'return_voucher',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_rnote_validated',
        enterpriseId: '',
        documentType: 'return_voucher',
        name: 'Validé',
        key: 'validated',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_rnote_paid',
        enterpriseId: '',
        documentType: 'return_voucher',
        name: 'Remboursé',
        key: 'paid',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 2,
      ),
      CustomStatusDefinition(
        id: 'default_rnote_cancelled',
        enterpriseId: '',
        documentType: 'return_voucher',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 3,
      ),
    ],

    // 8. Facture d'achat (purchase_invoice)
    'purchase_invoice': [
      CustomStatusDefinition(
        id: 'default_pinvoice_draft',
        enterpriseId: '',
        documentType: 'purchase_invoice',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_pinvoice_sent',
        enterpriseId: '',
        documentType: 'purchase_invoice',
        name: 'Envoyée',
        key: 'sent',
        colorValue: AppColors.info.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_pinvoice_partial',
        enterpriseId: '',
        documentType: 'purchase_invoice',
        name: 'Partiellement payée',
        key: 'partial',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 2,
      ),
      CustomStatusDefinition(
        id: 'default_pinvoice_paid',
        enterpriseId: '',
        documentType: 'purchase_invoice',
        name: 'Payée',
        key: 'paid',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 3,
      ),
      CustomStatusDefinition(
        id: 'default_pinvoice_unpaid',
        enterpriseId: '',
        documentType: 'purchase_invoice',
        name: 'Non payé',
        key: 'unpaid',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 4,
      ),
      CustomStatusDefinition(
        id: 'default_pinvoice_overdue',
        enterpriseId: '',
        documentType: 'purchase_invoice',
        name: 'En retard',
        key: 'overdue',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 5,
      ),
      CustomStatusDefinition(
        id: 'default_pinvoice_cancelled',
        enterpriseId: '',
        documentType: 'purchase_invoice',
        name: 'Annulée',
        key: 'cancelled',
        colorValue: AppColors.textTertiary.toARGB32(),
        isDefault: true,
        order: 6,
      ),
    ],

    // 9. Commande fournisseur (supplier_order)
    'supplier_order': [
      CustomStatusDefinition(
        id: 'default_sorder_draft',
        enterpriseId: '',
        documentType: 'supplier_order',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_sorder_pending',
        enterpriseId: '',
        documentType: 'supplier_order',
        name: 'En attente',
        key: 'pending',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_sorder_confirmed',
        enterpriseId: '',
        documentType: 'supplier_order',
        name: 'Confirmée',
        key: 'confirmed',
        colorValue: AppColors.info.toARGB32(),
        isDefault: true,
        order: 2,
      ),
      CustomStatusDefinition(
        id: 'default_sorder_in_progress',
        enterpriseId: '',
        documentType: 'supplier_order',
        name: 'En cours',
        key: 'inProgress',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 3,
      ),
      CustomStatusDefinition(
        id: 'default_sorder_delivered',
        enterpriseId: '',
        documentType: 'supplier_order',
        name: 'Livrée',
        key: 'delivered',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 4,
      ),
      CustomStatusDefinition(
        id: 'default_sorder_cancelled',
        enterpriseId: '',
        documentType: 'supplier_order',
        name: 'Annulée',
        key: 'cancelled',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 5,
      ),
    ],

    // 10. Bon de réception (receiving_voucher)
    'receiving_voucher': [
      CustomStatusDefinition(
        id: 'default_rvoucher_draft',
        enterpriseId: '',
        documentType: 'receiving_voucher',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_rvoucher_validated',
        enterpriseId: '',
        documentType: 'receiving_voucher',
        name: 'Validé',
        key: 'validated',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_rvoucher_cancelled',
        enterpriseId: '',
        documentType: 'receiving_voucher',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 2,
      ),
    ],

    // 11. Avoir fournisseur (supplier_credit_note)
    'supplier_credit_note': [
      CustomStatusDefinition(
        id: 'default_scnote_draft',
        enterpriseId: '',
        documentType: 'supplier_credit_note',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_scnote_validated',
        enterpriseId: '',
        documentType: 'supplier_credit_note',
        name: 'Validé',
        key: 'validated',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_scnote_cancelled',
        enterpriseId: '',
        documentType: 'supplier_credit_note',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 2,
      ),
    ],

    // 12. Retour fournisseur (supplier_return)
    'supplier_return': [
      CustomStatusDefinition(
        id: 'default_sreturn_draft',
        enterpriseId: '',
        documentType: 'supplier_return',
        name: 'Brouillon',
        key: 'draft',
        colorValue: AppColors.warning.toARGB32(),
        isDefault: true,
        order: 0,
      ),
      CustomStatusDefinition(
        id: 'default_sreturn_validated',
        enterpriseId: '',
        documentType: 'supplier_return',
        name: 'Validé',
        key: 'validated',
        colorValue: AppColors.success.toARGB32(),
        isDefault: true,
        order: 1,
      ),
      CustomStatusDefinition(
        id: 'default_sreturn_cancelled',
        enterpriseId: '',
        documentType: 'supplier_return',
        name: 'Annulé',
        key: 'cancelled',
        colorValue: AppColors.error.toARGB32(),
        isDefault: true,
        order: 2,
      ),
    ],
  };

  /// Returns the default system statuses for a document type.
  List<CustomStatusDefinition> getDefaultStatuses(String documentType) {
    return _defaultStatuses[documentType] ?? [];
  }

  /// Retrieves custom statuses (user-added) configured for a document type.
  Future<List<CustomStatusDefinition>> getCustomStatuses(
    String documentType, {
    String? enterpriseId,
    bool forceRefresh = false,
  }) async {
    final eid = enterpriseId ?? _currentEnterpriseId;
    if (eid == null || eid.isEmpty) return [];

    if (!forceRefresh && _cache.containsKey(eid)) {
      final list = _cache[eid]!
          .where((s) => s.documentType == documentType && !s.isDefault)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return list;
    }

    await _fetchAllForEnterprise(eid);

    final list = (_cache[eid] ?? [])
        .where((s) => s.documentType == documentType && !s.isDefault)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Retrieves both default and custom statuses for a document type.
  Future<List<CustomStatusDefinition>> getAllStatuses(
    String documentType, {
    String? enterpriseId,
    bool forceRefresh = false,
  }) async {
    final defaults = getDefaultStatuses(documentType);
    final custom = await getCustomStatuses(
      documentType,
      enterpriseId: enterpriseId,
      forceRefresh: forceRefresh,
    );
    return [...defaults, ...custom];
  }

  /// Synchronously returns default statuses + cached custom statuses for a document type.
  List<CustomStatusDefinition> getAllStatusesSync(
    String documentType, {
    String? enterpriseId,
  }) {
    final defaults = getDefaultStatuses(documentType);
    final eid = enterpriseId ?? _currentEnterpriseId;
    if (eid != null && _cache.containsKey(eid)) {
      final custom = _cache[eid]!
          .where((s) => s.documentType == documentType && !s.isDefault)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return [...defaults, ...custom];
    }
    if (eid != null && eid.isNotEmpty) {
      unawaited(getCustomStatuses(documentType, enterpriseId: eid));
    }
    return defaults;
  }

  /// Preloads all custom statuses into memory for an enterprise.
  Future<void> preloadStatuses({String? enterpriseId}) async {
    final eid = enterpriseId ?? _currentEnterpriseId;
    if (eid != null && eid.isNotEmpty) {
      await _fetchAllForEnterprise(eid);
    }
  }

  Future<void> _fetchAllForEnterprise(String enterpriseId) async {
    try {
      final snap = await _firestore
          .collection('enterprises')
          .doc(enterpriseId)
          .collection('custom_statuses')
          .get();

      _cache[enterpriseId] = snap.docs
          .map((d) => CustomStatusDefinition.fromMap(d.data(), id: d.id))
          .toList();
    } catch (e) {
      debugPrint('[CustomStatusService] Error fetching statuses: $e');
      _cache[enterpriseId] ??= [];
    }
  }

  /// Adds or updates a custom status definition.
  Future<void> saveCustomStatus(CustomStatusDefinition status) async {
    final eid = status.enterpriseId.isNotEmpty ? status.enterpriseId : _currentEnterpriseId;
    if (eid == null || eid.isEmpty) return;

    final docId = status.id.isNotEmpty
        ? status.id
        : _firestore.collection('enterprises').doc(eid).collection('custom_statuses').doc().id;

    final updated = status.copyWith(id: docId, enterpriseId: eid);
    final map = updated.toMap();

    try {
      await _firestore
          .collection('enterprises')
          .doc(eid)
          .collection('custom_statuses')
          .doc(docId)
          .set(map, SetOptions(merge: true));

      _cache[eid] ??= [];
      final idx = _cache[eid]!.indexWhere((s) => s.id == docId);
      if (idx != -1) {
        _cache[eid]![idx] = updated;
      } else {
        _cache[eid]!.add(updated);
      }

      _changeController.add(status.documentType);
    } catch (e) {
      debugPrint('[CustomStatusService] Error saving custom status: $e');
      rethrow;
    }
  }

  /// Deletes a custom status definition.
  Future<void> deleteCustomStatus(String statusId, {String? enterpriseId, String? documentType}) async {
    final eid = enterpriseId ?? _currentEnterpriseId;
    if (eid == null || eid.isEmpty) return;

    try {
      await _firestore
          .collection('enterprises')
          .doc(eid)
          .collection('custom_statuses')
          .doc(statusId)
          .delete();

      if (_cache.containsKey(eid)) {
        _cache[eid]!.removeWhere((s) => s.id == statusId);
      }

      if (documentType != null) {
        _changeController.add(documentType);
      }
    } catch (e) {
      debugPrint('[CustomStatusService] Error deleting custom status: $e');
      rethrow;
    }
  }

  /// Resolves the display label and color for any status string (built-in or custom).
  StatusInfo getStatusInfo(
    String documentType,
    String? rawStatus, {
    String? fallbackLabel,
    Color? fallbackColor,
  }) {
    if (rawStatus == null || rawStatus.isEmpty) {
      return StatusInfo(
        label: fallbackLabel ?? 'Brouillon',
        color: fallbackColor ?? AppColors.warning,
      );
    }

    final eid = _currentEnterpriseId;
    // 1. Check custom statuses in cache
    if (eid != null && _cache.containsKey(eid)) {
      for (final cs in _cache[eid]!) {
        if (cs.documentType == documentType &&
            (cs.key == rawStatus || cs.id == rawStatus || cs.name.toLowerCase() == rawStatus.toLowerCase())) {
          return StatusInfo(label: cs.name, color: cs.color, isCustom: true);
        }
      }
    }

    // 2. Check default system statuses
    final defaults = getDefaultStatuses(documentType);
    for (final ds in defaults) {
      if (ds.key.toLowerCase() == rawStatus.toLowerCase() ||
          ds.name.toLowerCase() == rawStatus.toLowerCase() ||
          ds.id == rawStatus) {
        return StatusInfo(label: ds.name, color: ds.color, isCustom: false);
      }
    }

    // 3. Fallback for common status strings across all types
    final lower = rawStatus.toLowerCase();
    if (lower == 'draft' || lower == 'brouillon') {
      return StatusInfo(
        label: fallbackLabel ?? 'Brouillon',
        color: fallbackColor ?? AppColors.warning,
      );
    }
    if (lower == 'validated' || lower == 'valide' || lower == 'validé' || lower == 'paid' || lower == 'paye' || lower == 'payé') {
      return StatusInfo(
        label: fallbackLabel ?? 'Validé',
        color: fallbackColor ?? AppColors.success,
      );
    }
    if (lower == 'cancelled' || lower == 'annule' || lower == 'annulé') {
      return StatusInfo(
        label: fallbackLabel ?? 'Annulé',
        color: fallbackColor ?? AppColors.error,
      );
    }

    // Fallback: capitalize raw status
    final label = fallbackLabel ??
        (rawStatus.length > 1
            ? '${rawStatus[0].toUpperCase()}${rawStatus.substring(1)}'
            : rawStatus.toUpperCase());
    return StatusInfo(
      label: label,
      color: fallbackColor ?? AppColors.info,
      isCustom: true,
    );
  }
}
