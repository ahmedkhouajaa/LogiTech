import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../database/database_helper.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import 'notifications/web_notification_helper.dart' as web_notif;

class StockNotificationService {
  StockNotificationService._();
  static final StockNotificationService instance = StockNotificationService._();

  final ValueNotifier<List<Product>> lowStockNotifier = ValueNotifier<List<Product>>([]);
  final ValueNotifier<List<Product>> highStockNotifier = ValueNotifier<List<Product>>([]);
  final ValueNotifier<int> alertCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isCheckingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Set<String>> dismissedIdsNotifier = ValueNotifier<Set<String>>({});

  final Set<String> _notifiedProductIds = {};
  final Set<String> _dismissedProductIds = {};
  final Map<String, DateTime> _alertTimestamps = {};
  Timer? _periodicTimer;
  StreamSubscription<String?>? _enterpriseSubscription;
  bool _initialized = false;

  String get _currentEnterpriseKey {
    final entId = EnterpriseService.instance.currentEnterpriseId ?? DatabaseHelper.instance.currentEnterpriseId;
    return (entId != null && entId.isNotEmpty) ? entId : 'default';
  }

  String get _prefKeyTimestamps => 'stock_alerts_timestamps_map_$_currentEnterpriseKey';
  String get _prefKeyDismissed => 'stock_alerts_dismissed_ids_$_currentEnterpriseKey';

  int get alertCount => alertCountNotifier.value;
  List<Product> get lowStockProducts => lowStockNotifier.value;
  List<Product> get highStockProducts => highStockNotifier.value;

  /// Check whether an article alert has been marked as seen/dismissed
  bool isDismissed(String productId) => _dismissedProductIds.contains(productId);

  /// Retrieve the recorded alert timestamp for an article (or product.updatedAt as fallback)
  DateTime getAlertTimestamp(Product product) {
    return _alertTimestamps[product.id] ?? product.updatedAt;
  }

  /// Initialize service, request platform permissions, and schedule periodic checks
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Listen to enterprise switches to reload enterprise-specific alert state
    _enterpriseSubscription?.cancel();
    _enterpriseSubscription = EnterpriseService.instance.enterpriseStream.listen((_) async {
      await _loadSavedState();
      await checkStockAlerts(notifyOnNew: false);
    });

    await _loadSavedState();

    if (kIsWeb) {
      await web_notif.requestWebNotificationPermission();
    }

    await checkStockAlerts(notifyOnNew: false);

    // Periodic check every 8 minutes
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 8), (_) {
      checkStockAlerts(notifyOnNew: true);
    });
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load timestamps
      final rawTs = prefs.getString(_prefKeyTimestamps) ?? prefs.getString('stock_alerts_timestamps_map');
      if (rawTs != null && rawTs.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(rawTs);
        decoded.forEach((k, v) {
          final dt = DateTime.tryParse(v.toString());
          if (dt != null) {
            _alertTimestamps[k] = dt;
          }
        });
      }

      // 2. Load dismissed IDs locally
      final savedDismissed = prefs.getStringList(_prefKeyDismissed) ??
          prefs.getStringList('stock_alerts_dismissed_ids_default') ??
          prefs.getStringList('stock_alerts_dismissed_ids');
      if (savedDismissed != null) {
        _dismissedProductIds.addAll(savedDismissed);
      }
      dismissedIdsNotifier.value = Set.from(_dismissedProductIds);
      _recalculateAlertCount();
    } catch (e) {
      debugPrint('[StockNotificationService] Error loading local state: $e');
    }

    // 3. Asynchronously sync remote state from Firestore
    _syncFromFirestore();
  }

  Future<void> _syncFromFirestore() async {
    final entId = EnterpriseService.instance.currentEnterpriseId ?? DatabaseHelper.instance.currentEnterpriseId;
    if (entId == null || entId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(entId)
          .collection('stock_alerts')
          .doc('dismissed_state')
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final remote = List<String>.from(doc.data()!['dismissed_ids'] ?? []);
        if (remote.isNotEmpty) {
          _dismissedProductIds.addAll(remote);
          dismissedIdsNotifier.value = Set.from(_dismissedProductIds);
          _recalculateAlertCount();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_prefKeyDismissed, _dismissedProductIds.toList());
        }
      }
    } catch (e) {
      debugPrint('[StockNotificationService] Remote state fetch error: $e');
    }
  }

  Future<void> _saveTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _alertTimestamps.map((k, v) => MapEntry(k, v.toIso8601String()));
      await prefs.setString(_prefKeyTimestamps, jsonEncode(map));
      await prefs.setString('stock_alerts_timestamps_map', jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _saveDismissed() async {
    // 1. Immediately persist locally (Desktop, Android, Web)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKeyDismissed, _dismissedProductIds.toList());
      if (_currentEnterpriseKey != 'default') {
        await prefs.setStringList('stock_alerts_dismissed_ids_default', _dismissedProductIds.toList());
      }
    } catch (e) {
      debugPrint('[StockNotificationService] Error saving dismissed locally: $e');
    }

    // 2. Sync to Firestore in background
    final entId = EnterpriseService.instance.currentEnterpriseId ?? DatabaseHelper.instance.currentEnterpriseId;
    if (entId != null && entId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('enterprises')
            .doc(entId)
            .collection('stock_alerts')
            .doc('dismissed_state')
            .set({
              'dismissed_ids': _dismissedProductIds.toList(),
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[StockNotificationService] Error syncing dismissed to Firestore: $e');
      }
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
    _enterpriseSubscription?.cancel();
    lowStockNotifier.dispose();
    highStockNotifier.dispose();
    alertCountNotifier.dispose();
    isCheckingNotifier.dispose();
    dismissedIdsNotifier.dispose();
  }

  /// Manually dismiss a specific article alert from the notification badge
  void dismissAlert(String productId) {
    _dismissedProductIds.add(productId);
    dismissedIdsNotifier.value = Set.from(_dismissedProductIds);
    _recalculateAlertCount();
    unawaited(_saveDismissed());
  }

  /// Toggle dismissed state for an article alert
  void toggleDismiss(String productId) {
    if (_dismissedProductIds.contains(productId)) {
      _dismissedProductIds.remove(productId);
    } else {
      _dismissedProductIds.add(productId);
    }
    dismissedIdsNotifier.value = Set.from(_dismissedProductIds);
    _recalculateAlertCount();
    unawaited(_saveDismissed());
  }

  /// Dismiss all active notifications
  void dismissAll() {
    for (final p in lowStockNotifier.value) {
      _dismissedProductIds.add(p.id);
    }
    for (final p in highStockNotifier.value) {
      _dismissedProductIds.add(p.id);
    }
    dismissedIdsNotifier.value = Set.from(_dismissedProductIds);
    _recalculateAlertCount();
    unawaited(_saveDismissed());
  }

  /// Check stock levels across all articles and trigger alerts
  Future<void> checkStockAlerts({bool notifyOnNew = true}) async {
    if (isCheckingNotifier.value) return;
    isCheckingNotifier.value = true;

    try {
      final allProducts = await DatabaseHelper.instance.getProducts().timeout(const Duration(seconds: 6));

      // Fetch stock movements to calculate exact real-time physical quantities
      List<StockMovement> movements = [];
      try {
        final entId = DatabaseHelper.instance.currentEnterpriseId;
        Query query = FirebaseFirestore.instance.collection('stock_movements');
        if (entId != null && entId.isNotEmpty) {
          query = query.where('enterprise_id', isEqualTo: entId);
        }
        final snap = await query.limit(500).get().timeout(const Duration(seconds: 6));
        movements = snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return StockMovement.fromMap(data);
        }).where((m) => !m.isDeleted).toList();
      } catch (_) {
        try {
          movements = await DatabaseHelper.instance.getStockMovements();
        } catch (_) {}
      }

      final Map<String, double> movementStocks = {};
      final Set<String> productsWithMovements = {};
      for (final m in movements) {
        productsWithMovements.add(m.productId);
        if (m.type == MovementType.entry || m.type == MovementType.transfer_in) {
          movementStocks[m.productId] = (movementStocks[m.productId] ?? 0.0) + m.quantity;
        } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
          movementStocks[m.productId] = (movementStocks[m.productId] ?? 0.0) - m.quantity;
        } else if (m.type == MovementType.adjustment) {
          movementStocks[m.productId] = (movementStocks[m.productId] ?? 0.0) + m.quantity;
        }
      }

      final resolvedProducts = allProducts.map((p) {
        if (productsWithMovements.contains(p.id)) {
          final movStock = movementStocks[p.id] ?? 0.0;
          return p.copyWith(stockQty: movStock);
        }
        return p;
      }).toList();

      final lowStock = resolvedProducts.where((p) {
        if (p.isService || !p.lowStockAlert || p.isDeleted) return false;
        return p.stockQty <= p.lowStockThreshold;
      }).toList();

      final highStock = resolvedProducts.where((p) {
        if (p.isService || !p.highStockAlert || p.highStockThreshold <= 0 || p.isDeleted) {
          return false;
        }
        return p.stockQty >= p.highStockThreshold;
      }).toList();

      // Timestamp recording and detection of newly critical low-stock items
      final now = DateTime.now();
      bool timestampsUpdated = false;
      final newlyCritical = <Product>[];

      for (final p in lowStock) {
        if (!_alertTimestamps.containsKey(p.id)) {
          _alertTimestamps[p.id] = p.updatedAt.isBefore(now) ? p.updatedAt : now;
          timestampsUpdated = true;
        }
        // Only trigger system notifications for items not already dismissed/seen
        if (!_notifiedProductIds.contains(p.id) && !_dismissedProductIds.contains(p.id)) {
          newlyCritical.add(p);
          _notifiedProductIds.add(p.id);
        }
      }

      for (final p in highStock) {
        if (!_alertTimestamps.containsKey(p.id)) {
          _alertTimestamps[p.id] = p.updatedAt.isBefore(now) ? p.updatedAt : now;
          timestampsUpdated = true;
        }
      }

      // Cleanup resolved items that are no longer in alert
      final activeAlertIds = {...lowStock.map((p) => p.id), ...highStock.map((p) => p.id)};
      final resolvedIds = _alertTimestamps.keys.where((id) => !activeAlertIds.contains(id)).toList();
      for (final id in resolvedIds) {
        _alertTimestamps.remove(id);
        _dismissedProductIds.remove(id);
        _notifiedProductIds.remove(id);
        timestampsUpdated = true;
      }

      // Also clean up any stale dismissed IDs for products no longer in alert
      final staleDismissed = _dismissedProductIds.where((id) => !activeAlertIds.contains(id)).toList();
      bool dismissedUpdated = false;
      if (staleDismissed.isNotEmpty) {
        _dismissedProductIds.removeAll(staleDismissed);
        dismissedUpdated = true;
      }

      if (timestampsUpdated) {
        unawaited(_saveTimestamps());
      }
      if (dismissedUpdated) {
        dismissedIdsNotifier.value = Set.from(_dismissedProductIds);
        unawaited(_saveDismissed());
      }

      lowStockNotifier.value = lowStock;
      highStockNotifier.value = highStock;
      _recalculateAlertCount();

      // Trigger OS/Browser notifications for new critical items
      if (notifyOnNew && newlyCritical.isNotEmpty) {
        _dispatchSystemNotification(newlyCritical);
      }
    } catch (e) {
      debugPrint('[StockNotificationService] Error checking stock: $e');
    } finally {
      isCheckingNotifier.value = false;
    }
  }

  void _recalculateAlertCount() {
    final activeLow = lowStockNotifier.value.where((p) => !_dismissedProductIds.contains(p.id)).length;
    final activeHigh = highStockNotifier.value.where((p) => !_dismissedProductIds.contains(p.id)).length;
    alertCountNotifier.value = activeLow + activeHigh;
  }

  void _dispatchSystemNotification(List<Product> products) {
    if (products.isEmpty) return;

    final String title;
    final String body;

    if (products.length == 1) {
      final p = products.first;
      final qtyStr = p.stockQty == p.stockQty.truncateToDouble() ? p.stockQty.toInt().toString() : p.stockQty.toStringAsFixed(1);
      final seuilStr = p.lowStockThreshold == p.lowStockThreshold.truncateToDouble() ? p.lowStockThreshold.toInt().toString() : p.lowStockThreshold.toStringAsFixed(1);
      title = '⚠️ Alerte Rupture de Stock';
      body = '${p.name} : $qtyStr ${p.unit} restant(s) (seuil alerte : $seuilStr ${p.unit})';
    } else {
      title = '⚠️ Alertes Stock (${products.length} articles)';
      body = '${products.first.name} et ${products.length - 1} autre(s) article(s) ont atteint le seuil d\'alerte.';
    }

    if (kIsWeb) {
      web_notif.showWebNotification(title, body);
    }
  }
}
