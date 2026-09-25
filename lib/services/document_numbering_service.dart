import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static final DocumentNumberingService instance = DocumentNumberingService._();

  DocumentNumberingService._() {
    _initEnterpriseListener();
  }

  static final Map<String, DocumentNumberingConfig> _configCache = {};
  static StreamSubscription<QuerySnapshot>? _countersSub;
  static String? _subscribedEnterpriseId;

  /// ValueNotifier to trigger real-time UI updates across Desktop, Web, and Android.
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  final _configsController = StreamController<Map<String, DocumentNumberingConfig>>.broadcast();
  Stream<Map<String, DocumentNumberingConfig>> get configsStream => _configsController.stream;

  static String? get _currentEntId =>
      EnterpriseService.instance.currentEnterpriseId ?? DatabaseHelper.instance.currentEnterpriseId;

  void _initEnterpriseListener() {
    EnterpriseService.instance.enterpriseStream.listen((enterpriseId) {
      if (enterpriseId != null && enterpriseId.isNotEmpty) {
        startRealtimeSync(enterpriseId);
      }
    });

    final currentId = EnterpriseService.instance.currentEnterpriseId;
    if (currentId != null && currentId.isNotEmpty) {
      startRealtimeSync(currentId);
    }
  }

  /// Starts real-time Firestore synchronization for document numbering counters.
  /// Automatically listens to changes made from Android, Web, or Desktop and keeps
  /// local caches and UI screens synchronized.
  Future<void> startRealtimeSync([String? enterpriseId]) async {
    final entId = enterpriseId ?? _currentEntId ?? 'default';

    if (_subscribedEnterpriseId == entId && _countersSub != null) {
      return;
    }
    _subscribedEnterpriseId = entId;

    // 1. Load from SharedPreferences first for instant UI response on mobile boot
    await _loadFromPrefs(entId);

    // 2. Set up real-time listener to Firestore
    await _countersSub?.cancel();
    _countersSub = FirebaseFirestore.instance
        .collection('enterprises')
        .doc(entId)
        .collection('counters')
        .snapshots()
        .listen((snap) async {
      for (var doc in snap.docs) {
        final key = DocumentTypeDefinition.normalizeKey(doc.id);
        final data = doc.data();
        final config = DocumentNumberingConfig.fromMap(key, data);
        _configCache['${entId}_$key'] = config;
      }
      await _saveToPrefs(entId);
      notifier.value++;
      _configsController.add(getCachedConfigs(entId));
    }, onError: (err) {
      debugPrint('[DocumentNumberingService] Real-time counters sync error: $err');
    });
  }

  /// Loads all 12 document numbering configurations for the specified enterprise.
  /// If a configuration has not been explicitly saved yet, it auto-detects the current
  /// sequence number and prefix from existing documents in the database.
  static Future<Map<String, DocumentNumberingConfig>> loadAllConfigs(String enterpriseId) async {
    // Ensure real-time sync is actively running
    instance.startRealtimeSync(enterpriseId);

    final Map<String, DocumentNumberingConfig> result = {};

    try {
      final snap = await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(enterpriseId)
          .collection('counters')
          .get()
          .timeout(const Duration(seconds: 8));

      final Map<String, Map<String, dynamic>> existingDocs = {
        for (var doc in snap.docs) DocumentTypeDefinition.normalizeKey(doc.id): doc.data(),
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

      await instance._saveToPrefs(enterpriseId);
      instance.notifier.value++;
      instance._configsController.add(result);
    } catch (e) {
      debugPrint('[DocumentNumberingService] Error loading configs from Firestore: $e');
      // Fallback to cached or default definitions
      final cached = getCachedConfigs(enterpriseId);
      if (cached.isNotEmpty) {
        return cached;
      }
      for (var def in DocumentTypeDefinition.allTypes) {
        final config = DocumentNumberingConfig.fromMap(def.key, null);
        result[def.key] = config;
      }
    }

    return result;
  }

  /// Returns cached configs for this enterprise, providing clean defaults for any un-cached items.
  static Map<String, DocumentNumberingConfig> getCachedConfigs(String enterpriseId) {
    final Map<String, DocumentNumberingConfig> result = {};
    for (var def in DocumentTypeDefinition.allTypes) {
      final cacheKey = '${enterpriseId}_${def.key}';
      if (_configCache.containsKey(cacheKey)) {
        result[def.key] = _configCache[cacheKey]!;
      } else {
        result[def.key] = DocumentNumberingConfig.fromMap(def.key, null);
      }
    }
    return result;
  }

  /// Gets the configuration for a single document collection, checking in-memory cache and local storage first.
  static Future<DocumentNumberingConfig> getConfig(String docCollection, {String? enterpriseId}) async {
    final normCol = DocumentTypeDefinition.normalizeKey(docCollection);
    final entId = enterpriseId ?? _currentEntId ?? 'default';
    final cacheKey = '${entId}_$normCol';

    if (_configCache.containsKey(cacheKey)) {
      return _configCache[cacheKey]!;
    }

    // Try loading from local storage
    await instance._loadFromPrefs(entId);
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

  /// Saves a single document numbering configuration in Firestore and local storage.
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

    await instance._saveToPrefs(enterpriseId);
    instance.notifier.value++;
    instance._configsController.add(getCachedConfigs(enterpriseId));
  }

  /// Saves only the modified configurations, preventing overwrite of concurrent changes
  /// made from other platforms (e.g. Android editing Facture while Desktop edited Devis).
  static Future<void> saveModifiedConfigs(String enterpriseId, List<DocumentNumberingConfig> configs) async {
    if (configs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final config in configs) {
      final normCol = DocumentTypeDefinition.normalizeKey(config.docTypeKey);
      final cacheKey = '${enterpriseId}_$normCol';
      _configCache[cacheKey] = config;

      final docRef = FirebaseFirestore.instance
          .collection('enterprises')
          .doc(enterpriseId)
          .collection('counters')
          .doc(normCol);

      batch.set(docRef, config.toMap(), SetOptions(merge: true));
    }

    await batch.commit().timeout(const Duration(seconds: 8));
    await instance._saveToPrefs(enterpriseId);
    instance.notifier.value++;
    instance._configsController.add(getCachedConfigs(enterpriseId));
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

  // ─── Local SharedPreferences Helpers ─────────────────────────────────────
  Future<void> _saveToPrefs(String enterpriseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> serializable = {};
      for (var def in DocumentTypeDefinition.allTypes) {
        final cacheKey = '${enterpriseId}_${def.key}';
        final cfg = _configCache[cacheKey];
        if (cfg != null) {
          serializable[def.key] = cfg.toMap();
        }
      }
      if (serializable.isNotEmpty) {
        await prefs.setString('doc_numbering_configs_$enterpriseId', jsonEncode(serializable));
      }
    } catch (e) {
      debugPrint('[DocumentNumberingService] Error saving to SharedPreferences: $e');
    }
  }

  Future<void> _loadFromPrefs(String enterpriseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('doc_numbering_configs_$enterpriseId');
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(str);
        for (var entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            final key = DocumentTypeDefinition.normalizeKey(entry.key);
            final cfg = DocumentNumberingConfig.fromMap(key, entry.value as Map<String, dynamic>);
            _configCache['${enterpriseId}_$key'] = cfg;
          }
        }
      }
    } catch (e) {
      debugPrint('[DocumentNumberingService] Error loading from SharedPreferences: $e');
    }
  }
}
