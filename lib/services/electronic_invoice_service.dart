import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/electronic_invoice_config.dart';
import 'enterprise_service.dart';

class ElectronicInvoiceService {
  static final ElectronicInvoiceService instance = ElectronicInvoiceService._();
  ElectronicInvoiceService._() {
    _initEnterpriseListener();
  }

  static const String _prefPrefix = 'electronic_invoice_config_';
  final ValueNotifier<ElectronicInvoiceConfig> configNotifier =
      ValueNotifier<ElectronicInvoiceConfig>(const ElectronicInvoiceConfig());

  final StreamController<ElectronicInvoiceConfig> _configController =
      StreamController<ElectronicInvoiceConfig>.broadcast();
  Stream<ElectronicInvoiceConfig> get configStream => _configController.stream;

  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  String? _currentEnterpriseId;

  ElectronicInvoiceConfig get currentConfig => configNotifier.value;

  void _initEnterpriseListener() {
    EnterpriseService.instance.enterpriseStream.listen((enterpriseId) {
      if (enterpriseId != null && enterpriseId.isNotEmpty) {
        loadConfig(enterpriseId);
      }
    });

    final currentId = EnterpriseService.instance.currentEnterpriseId;
    if (currentId != null && currentId.isNotEmpty) {
      loadConfig(currentId);
    }
  }

  Future<ElectronicInvoiceConfig> loadConfig([String? enterpriseId]) async {
    final eid = enterpriseId ?? EnterpriseService.instance.currentEnterpriseId;
    if (eid == null || eid.isEmpty) {
      return const ElectronicInvoiceConfig();
    }

    _currentEnterpriseId = eid;

    // 1. Try local cache first for instant UI response
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('$_prefPrefix$eid');
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final map = jsonDecode(localJson) as Map<String, dynamic>;
        final cached = ElectronicInvoiceConfig.fromMap(map);
        configNotifier.value = cached;
        _configController.add(cached);
      } catch (e) {
        debugPrint('[ElectronicInvoiceService] Local cache parse error: $e');
      }
    }

    // 2. Setup real-time listener from Firestore
    await _firestoreSub?.cancel();
    _firestoreSub = FirebaseFirestore.instance
        .collection('enterprises')
        .doc(eid)
        .collection('settings')
        .doc('electronic_invoice')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final remoteConfig = ElectronicInvoiceConfig.fromMap(doc.data()!);
        configNotifier.value = remoteConfig;
        _configController.add(remoteConfig);
        // Update local cache
        prefs.setString('$_prefPrefix$eid', jsonEncode(remoteConfig.toMap()));
      }
    }, onError: (e) {
      debugPrint('[ElectronicInvoiceService] Firestore subscription error: $e');
    });

    return configNotifier.value;
  }

  Future<void> saveConfig(ElectronicInvoiceConfig config) async {
    final eid = _currentEnterpriseId ?? EnterpriseService.instance.currentEnterpriseId;
    if (eid == null || eid.isEmpty) return;

    configNotifier.value = config;
    _configController.add(config);

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefPrefix$eid', jsonEncode(config.toMap()));

    // Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(eid)
          .collection('settings')
          .doc('electronic_invoice')
          .set(config.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ElectronicInvoiceService] Firestore save error: $e');
    }
  }

  Future<void> activateEInvoicing({
    required String ttnMemberCode,
    required String matriculeFiscal,
    String taxCode = '',
    String environment = 'sandbox',
    String signatureType = 'digigo',
    bool autoGenerateXml = true,
    bool showQrCode = true,
    bool autoSendEmail = true,
  }) async {
    final newConfig = currentConfig.copyWith(
      isEnabled: true,
      adhesionStatus: 'active',
      ttnMemberCode: ttnMemberCode.trim().toUpperCase(),
      matriculeFiscal: matriculeFiscal.trim(),
      taxCode: taxCode.trim(),
      environment: environment,
      signatureType: signatureType,
      autoGenerateXml: autoGenerateXml,
      showQrCode: showQrCode,
      autoSendEmail: autoSendEmail,
      activatedAt: DateTime.now(),
    );
    await saveConfig(newConfig);
  }

  Future<void> deactivateEInvoicing() async {
    final newConfig = currentConfig.copyWith(
      isEnabled: false,
      adhesionStatus: 'not_started',
    );
    await saveConfig(newConfig);
  }
}
