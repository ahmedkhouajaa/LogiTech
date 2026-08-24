import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Helper to safely fetch documents by ID across platforms.
/// 
/// Avoids the native C++ assertion failure on Windows in `cloud_firestore`
/// when `DocumentReference.get()` is called on non-existent documents.
class FirestoreSafeHelper {
  /// Safely fetches document data as a Map, or `null` if not found.
  static Future<Map<String, dynamic>?> getDocData(
    CollectionReference<Map<String, dynamic>> collection,
    String docId, {
    GetOptions? options,
    Duration? timeout,
  }) async {
    final trimmedId = docId.trim();
    if (trimmedId.isEmpty) return null;

    final effectiveTimeout = timeout ?? (kIsWeb ? const Duration(seconds: 5) : const Duration(seconds: 30));

    try {
      final docRef = collection.doc(trimmedId);
      final snapshot = options != null 
          ? await docRef.get(options).timeout(effectiveTimeout)
          : await docRef.get().timeout(effectiveTimeout);
      
      if (snapshot.exists && snapshot.data() != null) {
        return Map<String, dynamic>.from(snapshot.data()!);
      }
      return null;
    } catch (_) {
      try {
        final docRef = collection.doc(trimmedId);
        final cached = await docRef.get(const GetOptions(source: Source.cache));
        if (cached.exists && cached.data() != null) {
          return Map<String, dynamic>.from(cached.data()!);
        }
      } catch (_) {}
      return null;
    }
  }
}
