import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database_helper.dart';
import '../models/document_numbering_config.dart';
import '../services/enterprise_service.dart';
import '../widgets/document_number_config_dialog.dart';

class CollectionMetadata {
  final int maxSeq;
  final String? detectedPrefix;
  final int count;

  const CollectionMetadata({
    required this.maxSeq,
    this.detectedPrefix,
    this.count = 0,
  });
}

class DocumentNumberingService {
  static final Map<String, DocumentNumberingConfig> _configCache = {};

  static String? get _currentEntId =>
      EnterpriseService.instance.currentEnterpriseId ?? DatabaseHelper.instance.currentEnterpriseId;

  /// Loads all 12 document numbering configurations for the specified enterprise.
  /// If a configuration has not been explicitly saved yet, it auto-detects the current
  /// sequence number and prefix from existing documents in the database.
  static Future<Map<String, DocumentNumberingConfig>> loadAllConfigs(String enterpriseId) async {
    final Map<String, DocumentNumberingConfig> result = {};

    try {
      final snap = await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(enterpriseId)
          .collection('counters')
          .get()
          .timeout(const Duration(seconds: 8));

      final Map<String, Map<String, dynamic>> existingDocs = {
        for (var doc in snap.docs) doc.id: doc.data(),
      };

      for (var def in DocumentTypeDefinition.allTypes) {
        final data = existingDocs[def.key];
        DocumentNumberingConfig config;

        if (data != null && data['configured'] == true) {
          config = DocumentNumberingConfig.fromMap(def.key, data);
        } else {
          // Auto-detect current reference and prefix from existing documents
          final meta = await getCollectionMetadata(def.key, enterpriseId);
          final existingCount = (data != null && data['count'] is num) ? (data['count'] as num).toInt() : 0;
          final realCurrentNumber = meta.maxSeq > existingCount ? meta.maxSeq : (existingCount > 0 ? existingCount : 1);
          final activePrefix = (data != null && data['prefix']?.toString().isNotEmpty == true)
              ? data['prefix'].toString()
              : (meta.detectedPrefix != null && meta.detectedPrefix!.isNotEmpty
                  ? meta.detectedPrefix!
                  : def.defaultPrefix);

          config = DocumentNumberingConfig(
            docTypeKey: def.key,
            prefix: activePrefix,
            currentNumber: realCurrentNumber,
            numberLength: (data != null && data['number_length'] is num) ? (data['number_length'] as num).toInt() : 6,
            includeYear: data != null && data['include_year'] != null ? data['include_year'] == true : true,
            isEnabled: data != null && data['is_enabled'] != null ? data['is_enabled'] == true : true,
          );
        }

        result[def.key] = config;
        _configCache['${enterpriseId}_${def.key}'] = config;
      }
    } catch (e) {
      debugPrint('[DocumentNumberingService] Error loading configs: $e');
      // Fallback to default definitions
      for (var def in DocumentTypeDefinition.allTypes) {
        final config = DocumentNumberingConfig.fromMap(def.key, null);
        result[def.key] = config;
      }
    }

    return result;
  }

  /// Gets the configuration for a single document collection, checking cache first.
  static Future<DocumentNumberingConfig> getConfig(String docCollection, {String? enterpriseId}) async {
    final normCol = DocumentTypeDefinition.normalizeKey(docCollection);
    final entId = enterpriseId ?? _currentEntId ?? 'default';
    final cacheKey = '${entId}_$normCol';

    if (_configCache.containsKey(cacheKey)) {
      return _configCache[cacheKey]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(entId)
          .collection('counters')
          .doc(normCol)
          .get()
          .timeout(const Duration(seconds: 4));

      final data = doc.data();
      DocumentNumberingConfig config;

      if (data != null && data['configured'] == true) {
        config = DocumentNumberingConfig.fromMap(normCol, data);
      } else {
        final meta = await getCollectionMetadata(normCol, entId);
        final existingCount = (data != null && data['count'] is num) ? (data['count'] as num).toInt() : 0;
        final realCurrentNumber = meta.maxSeq > existingCount ? meta.maxSeq : (existingCount > 0 ? existingCount : 1);
        final def = DocumentTypeDefinition.fromKey(normCol);
        final activePrefix = (data != null && data['prefix']?.toString().isNotEmpty == true)
            ? data['prefix'].toString()
            : (meta.detectedPrefix != null && meta.detectedPrefix!.isNotEmpty
                ? meta.detectedPrefix!
                : def.defaultPrefix);

        config = DocumentNumberingConfig(
          docTypeKey: normCol,
          prefix: activePrefix,
          currentNumber: realCurrentNumber,
          numberLength: (data != null && data['number_length'] is num) ? (data['number_length'] as num).toInt() : 6,
          includeYear: data != null && data['include_year'] != null ? data['include_year'] == true : true,
          isEnabled: data != null && data['is_enabled'] != null ? data['is_enabled'] == true : true,
        );
      }

      _configCache[cacheKey] = config;
      return config;
    } catch (e) {
      debugPrint('[DocumentNumberingService] Error getting config for $normCol: $e');
      final fallback = DocumentNumberingConfig.fromMap(normCol, null);
      _configCache[cacheKey] = fallback;
      return fallback;
    }
  }

  /// Saves a single document numbering configuration in Firestore.
  static Future<void> saveConfig(String enterpriseId, DocumentNumberingConfig config) async {
    final normCol = DocumentTypeDefinition.normalizeKey(config.docTypeKey);
    final cacheKey = '${enterpriseId}_$normCol';
    _configCache[cacheKey] = config;

    await FirebaseFirestore.instance
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('counters')
        .doc(normCol)
        .set(config.toMap(), SetOptions(merge: true))
        .timeout(const Duration(seconds: 8));
  }

  /// Scans documents in the collection to extract metadata:
  /// - Highest numeric sequence number (`maxSeq`)
  /// - Currently used prefix (`detectedPrefix`)
  /// - Total active document count (`count`)
  static Future<CollectionMetadata> getCollectionMetadata(String docCollection, String enterpriseId) async {
    int maxSeq = 0;
    String? detectedPrefix;
    int count = 0;

    final normCol = DocumentTypeDefinition.normalizeKey(docCollection);
    final collectionsToCheck = <String>[normCol];
    if (normCol == 'bons_sortie') {
      collectionsToCheck.add('exit_vouchers');
    }

    try {
      for (final col in collectionsToCheck) {
        Query query = FirebaseFirestore.instance.collection(col);
        if (enterpriseId != 'default' && enterpriseId.isNotEmpty) {
          query = query.where('enterprise_id', isEqualTo: enterpriseId);
        }

        final snap = await query.get().timeout(const Duration(seconds: 6));
        var docs = snap.docs;

        // Fallback check if enterpriseId was default or nothing returned
        if (docs.isEmpty && enterpriseId == 'default') {
          final fallbackSnap = await FirebaseFirestore.instance
              .collection(col)
              .limit(50)
              .get()
              .timeout(const Duration(seconds: 4));
          docs = fallbackSnap.docs;
        }

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final isDel = data['is_deleted'] == 1 ||
              data['is_deleted'] == true ||
              data['is_deleted'] == '1' ||
              data['isDeleted'] == 1 ||
              data['isDeleted'] == true;

          if (isDel) continue;
          count++;

          final numStr = (data['number'] ??
                  data['documentNumber'] ??
                  data['transaction_number'] ??
                  data['transactionNumber'] ??
                  '')
              .toString()
              .trim();

          if (numStr.isEmpty) continue;

          // Detect prefix from existing reference format: e.g. "FAC-2026-000005" -> "FAC"
          final parts = numStr.split('-');
          if (parts.length >= 2 && detectedPrefix == null) {
            final firstPart = parts.first.trim();
            if (firstPart.isNotEmpty && RegExp(r'^[A-Za-z]+$').hasMatch(firstPart)) {
              detectedPrefix = firstPart.toUpperCase();
            }
          }

          // Extract sequence number from last segment
          if (parts.isNotEmpty) {
            final lastNum = int.tryParse(parts.last);
            if (lastNum != null && lastNum > maxSeq && lastNum < 10000000) {
              maxSeq = lastNum;
              continue;
            }
          }

          // Trailing digits regex fallback
          final match = RegExp(r'\d+$').firstMatch(numStr);
          if (match != null) {
            final val = int.tryParse(match.group(0) ?? '');
            if (val != null && val > maxSeq && val < 10000000) {
              maxSeq = val;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DocumentNumberingService] Error getting metadata for $docCollection: $e');
    }

    return CollectionMetadata(
      maxSeq: maxSeq,
      detectedPrefix: detectedPrefix,
      count: count,
    );
  }

  /// Finds the highest numeric sequence already used in existing documents for this collection.
  static Future<int> getMaxExistingSequence(String docCollection, String enterpriseId) async {
    final meta = await getCollectionMetadata(docCollection, enterpriseId);
    return meta.maxSeq;
  }

  /// Formats a document number using the active configuration for the document collection.
  static String formatDocumentNumber(
    String docCollection,
    int sequence, {
    String? defaultPrefix,
    String? enterpriseId,
  }) {
    final normCol = DocumentTypeDefinition.normalizeKey(docCollection);
    final entId = enterpriseId ?? _currentEntId ?? 'default';
    final cacheKey = '${entId}_$normCol';
    final config = _configCache[cacheKey];

    if (config != null) {
      return config.formatDocNumber(sequence);
    }

    // Default formatting if not loaded
    final def = DocumentTypeDefinition.fromKey(normCol);
    final prefix = (defaultPrefix != null && defaultPrefix.isNotEmpty)
        ? defaultPrefix
        : def.defaultPrefix;
    final year = DateTime.now().year;
    final seqStr = sequence.toString().padLeft(6, '0');
    return '$prefix-$year-$seqStr';
  }

  /// Ensures that document sequence is set up.
  /// If it's the very first document, prompts the user or initializes with configured number.
  static Future<int?> ensureNumberSequence({
    required BuildContext context,
    required String docCollection,
    required String docTypeName,
    required String prefix,
  }) async {
    final normCol = DocumentTypeDefinition.normalizeKey(docCollection);
    final entId = _currentEntId ?? 'default';
    final isFirst = await DatabaseHelper.instance.isFirstDocumentOfType(normCol);

    // Fetch or initialize config
    final config = await getConfig(normCol, enterpriseId: entId);

    if (!isFirst) {
      return await DatabaseHelper.instance.generateNextDocSequenceAtomic(
        entId,
        normCol,
      );
    }

    // If config was already customized with a count > 1, use that starting point
    if (config.currentNumber > 1) {
      await DatabaseHelper.instance.setInitialDocSequenceAtomic(
        entId,
        normCol,
        config.currentNumber,
      );
      return config.currentNumber;
    }

    // Otherwise show initial config dialog
    if (!context.mounted) return null;
    final chosenNumber = await DocumentNumberConfigDialog.show(
      context: context,
      docTypeName: docTypeName,
      prefix: config.prefix.isNotEmpty ? config.prefix : prefix,
      initialNumber: config.currentNumber > 0 ? config.currentNumber : 1,
    );

    if (chosenNumber == null) return null;

    await DatabaseHelper.instance.setInitialDocSequenceAtomic(
      entId,
      normCol,
      chosenNumber,
    );

    // Sync config with chosen starting number
    await saveConfig(entId, config.copyWith(currentNumber: chosenNumber));

    return chosenNumber;
  }
}
