import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'enterprise_service.dart';

/// Pre-fetches and warms up Firestore caches in the background upon login
/// so that screens render instantly (<100ms) without waiting on cold network queries.
class DataPrefetchService {
  static final DataPrefetchService instance = DataPrefetchService._();
  DataPrefetchService._();

  bool _isPrefetching = false;
  String? _lastPrefetchedEnterpriseId;

  Future<void> prefetchEnterpriseData({bool force = false}) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    if (currentEntId == null || currentEntId.isEmpty) return;

    if (!force && _isPrefetching) return;
    if (!force && _lastPrefetchedEnterpriseId == currentEntId) return;

    _isPrefetching = true;
    _lastPrefetchedEnterpriseId = currentEntId;

    final stopwatch = Stopwatch()..start();
    debugPrint('[PERF/Prefetch] Starting background prefetch for enterprise: $currentEntId');

    try {
      final db = FirebaseFirestore.instance;
      
      // Concurrently warm up top-level collections
      await Future.wait([
        // Articles
        db.collection('articles')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache))
            .then((s) => debugPrint('[PERF/Prefetch] Cached ${s.docs.length} articles')),

        // Invoices
        db.collection('invoices')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache))
            .then((s) => debugPrint('[PERF/Prefetch] Cached ${s.docs.length} invoices')),

        // Quotes (Devis)
        db.collection('quotes')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache))
            .then((s) => debugPrint('[PERF/Prefetch] Cached ${s.docs.length} quotes')),

        // Clients
        db.collection('clients')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache))
            .then((s) => debugPrint('[PERF/Prefetch] Cached ${s.docs.length} clients')),

        // Fournisseurs
        db.collection('fournisseurs')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache))
            .then((s) => debugPrint('[PERF/Prefetch] Cached ${s.docs.length} fournisseurs')),
      ]).timeout(const Duration(seconds: 15));

      stopwatch.stop();
      debugPrint('[PERF/Prefetch] Background prefetch completed successfully in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      stopwatch.stop();
      debugPrint('[PERF/Prefetch] Background prefetch warning: $e (${stopwatch.elapsedMilliseconds}ms)');
    } finally {
      _isPrefetching = false;
    }
  }
}
