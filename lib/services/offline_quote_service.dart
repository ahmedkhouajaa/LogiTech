import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quote.dart';
import '../database/database_helper.dart';
import 'firestore_repository.dart';
import 'connectivity_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class OfflineQuoteService {
  static final OfflineQuoteService instance = OfflineQuoteService._();
  OfflineQuoteService._();

  static const String _storageKey = 'pending_quotes_v1';

  /// Save a pending offline quote to SharedPreferences
  Future<void> savePendingQuote(Quote quote) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingList = await getPendingQuotes();

      // Remove existing version if present
      pendingList.removeWhere((q) => q.id == quote.id);

      // Ensure isSynced is false
      final pendingQuote = quote.copyWith(
        isSynced: false,
      );

      pendingList.add(pendingQuote);

      final jsonList = pendingList.map((q) => jsonEncode(q.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
      debugPrint('[OFFLINE QUOTE] Saved pending quote ${pendingQuote.number} locally.');
    } catch (e) {
      debugPrint('❌ [OFFLINE QUOTE] Error saving pending quote: $e');
    }
  }

  /// Get all locally saved pending quotes (sorted by createdAt ascending)
  Future<List<Quote>> getPendingQuotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      final quotes = <Quote>[];
      for (final jsonStr in jsonList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          quotes.add(Quote.fromMap(map));
        } catch (e) {
          debugPrint('❌ Error parsing stored quote: $e');
        }
      }
      quotes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return quotes;
    } catch (e) {
      debugPrint('❌ [OFFLINE QUOTE] Error loading pending quotes: $e');
      return [];
    }
  }

  /// Remove a specific pending quote from SharedPreferences
  Future<void> removePendingQuote(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingList = await getPendingQuotes();
      pendingList.removeWhere((q) => q.id == id);
      final jsonList = pendingList.map((q) => jsonEncode(q.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      debugPrint('❌ [OFFLINE QUOTE] Error removing pending quote: $e');
    }
  }

  /// Sync all pending quotes to Firestore with sequential atomic numbering
  Future<int> syncPendingQuotes() async {
    if (!ConnectivityService.instance.isOnline) {
      debugPrint('[OFFLINE QUOTE] Device is offline, skipping quote sync.');
      return 0;
    }

    final pendingList = await getPendingQuotes();
    if (pendingList.isEmpty) return 0;

    debugPrint('[OFFLINE QUOTE] Starting sync for ${pendingList.length} pending quotes...');
    int syncedCount = 0;

    for (final quote in pendingList) {
      try {
        // 1. Get atomic sequential number from Firestore counter
        final seq = await DatabaseHelper.instance.getNextQuoteSequence();
        final officialNumber = generateDocNumber('DV', seq);

        // 2. Prepare updated synced quote with official number & valid status
        final syncedQuote = quote.copyWith(
          number: officialNumber,
          isSynced: true,
          status: quote.status == DocumentStatus.draft ? DocumentStatus.created : quote.status,
          updatedAt: DateTime.now(),
        );

        // 3. Save to Cloud Firestore
        await FirestoreRepository.instance.saveQuote(syncedQuote);

        // 4. Remove synced quote from local pending queue
        await removePendingQuote(quote.id);
        syncedCount++;

        debugPrint('✅ [OFFLINE QUOTE] Synced quote ${quote.number} -> $officialNumber');
      } catch (e) {
        debugPrint('❌ [OFFLINE QUOTE] Failed to sync quote ${quote.id}: $e');
        // Stop batch on first network failure to preserve sequential ordering without gaps
        break;
      }
    }

    return syncedCount;
  }
}
