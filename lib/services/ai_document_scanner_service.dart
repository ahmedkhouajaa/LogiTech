import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_utils.dart';

// Import dart:io conditionally only on non-web platforms
import 'dart:io' if (dart.library.html) 'dart:html' as io;

class ExtractedDocumentItem {
  final String? productCode;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final double totalHt;
  final double totalTtc;

  ExtractedDocumentItem({
    this.productCode,
    required this.productName,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.tvaRate = 19.0,
    this.discountPercent = 0.0,
    this.totalHt = 0.0,
    this.totalTtc = 0.0,
  });

  factory ExtractedDocumentItem.fromJson(Map<String, dynamic> json) {
    return ExtractedDocumentItem(
      productCode: json['product_code']?.toString(),
      productName: json['product_name']?.toString() ?? 'Article',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      tvaRate: (json['tva_rate'] as num?)?.toDouble() ?? 19.0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      totalHt: (json['total_ht'] as num?)?.toDouble() ?? 0.0,
      totalTtc: (json['total_ttc'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_code': productCode,
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'tva_rate': tvaRate,
    'discount_percent': discountPercent,
    'total_ht': totalHt,
    'total_ttc': totalTtc,
  };
}

class ExtractedDocumentData {
  final String documentType;
  final String? documentNumber;
  final String? documentDate;
  final String? dueDate;
  final String? supplierName;
  final String? supplierTaxId;
  final String? supplierPhone;
  final String? supplierAddress;
  final double totalHt;
  final double totalTva;
  final double stampDuty;
  final double totalTtc;
  final String currency;
  final String rawText;
  final List<ExtractedDocumentItem> items;

  ExtractedDocumentData({
    required this.documentType,
    this.documentNumber,
    this.documentDate,
    this.dueDate,
    this.supplierName,
    this.supplierTaxId,
    this.supplierPhone,
    this.supplierAddress,
    this.totalHt = 0.0,
    this.totalTva = 0.0,
    this.stampDuty = 1.0,
    this.totalTtc = 0.0,
    this.currency = 'TND',
    this.rawText = '',
    this.items = const [],
  });

  factory ExtractedDocumentData.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<ExtractedDocumentItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((item) => ExtractedDocumentItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return ExtractedDocumentData(
      documentType: json['document_type']?.toString() ?? 'document',
      documentNumber: json['document_number']?.toString(),
      documentDate: json['document_date']?.toString(),
      dueDate: json['due_date']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      supplierTaxId: json['supplier_tax_id']?.toString(),
      supplierPhone: json['supplier_phone']?.toString(),
      supplierAddress: json['supplier_address']?.toString(),
      totalHt: (json['total_ht'] as num?)?.toDouble() ?? 0.0,
      totalTva: (json['total_tva'] as num?)?.toDouble() ?? 0.0,
      stampDuty: (json['stamp_duty'] as num?)?.toDouble() ?? 1.0,
      totalTtc: (json['total_ttc'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'TND',
      rawText: json['raw_text']?.toString() ?? '',
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'document_type': documentType,
    'document_number': documentNumber,
    'document_date': documentDate,
    'due_date': dueDate,
    'supplier_name': supplierName,
    'supplier_tax_id': supplierTaxId,
    'supplier_phone': supplierPhone,
    'supplier_address': supplierAddress,
    'total_ht': totalHt,
    'total_tva': totalTva,
    'stamp_duty': stampDuty,
    'total_ttc': totalTtc,
    'currency': currency,
    'raw_text': rawText,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class AiScanResult {
  final bool success;
  final String status; // "OK"
  final String textResponse; // Text with "OK" for the app text field
  final String source; // 'friend_ai_model' | 'local_ocr_llm' | 'fallback_demo' | 'error'
  final String message;
  final String documentType;
  final List<String> fileNames;
  final ExtractedDocumentData? extractedData;

  AiScanResult({
    required this.success,
    this.status = 'OK',
    this.textResponse = 'OK',
    required this.source,
    required this.message,
    required this.documentType,
    this.fileNames = const [],
    this.extractedData,
  });

  factory AiScanResult.fromJson(Map<String, dynamic> json) {
    return AiScanResult(
      success: json['success'] == true,
      status: json['status']?.toString() ?? 'OK',
      textResponse: json['text_response']?.toString() ?? 'OK',
      source: json['source']?.toString() ?? 'unknown',
      message: json['message']?.toString() ?? '',
      documentType: json['document_type']?.toString() ?? 'document',
      fileNames: (json['file_names'] as List?)?.map((e) => e.toString()).toList() ?? [],
      extractedData: json['extracted_data'] != null
          ? ExtractedDocumentData.fromJson(Map<String, dynamic>.from(json['extracted_data'] as Map))
          : null,
    );
  }

  factory AiScanResult.error(String message, {String documentType = 'document'}) {
    return AiScanResult(
      success: false,
      status: 'ERROR',
      textResponse: 'ERROR: $message',
      source: 'error',
      message: message,
      documentType: documentType,
    );
  }
}

/// Service reliant l'ERP LogiTech au microservice Python d'extraction IA
class AiDocumentScannerService {
  static final AiDocumentScannerService instance = AiDocumentScannerService._internal();
  AiDocumentScannerService._internal();

  static const String _prefKeyHost = 'ai_service_custom_host';
  String? _customHost;

  /// Détermine l'URL hôte adaptée à chaque environnement (Desktop, Web, Android)
  Future<String> getBaseUrl() async {
    if (_customHost != null && _customHost!.isNotEmpty) {
      return _customHost!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyHost);
      if (saved != null && saved.isNotEmpty) {
        _customHost = saved;
        return saved;
      }
    } catch (_) {}

    // Résolution automatique par plateforme
    if (PlatformUtils.isWeb) {
      // Navigateur Web
      return 'http://localhost:8000';
    } else if (PlatformUtils.isAndroid) {
      // Émulateur Android (10.0.2.2 redirige vers le localhost de la machine hôte)
      return 'http://10.0.2.2:8000';
    } else {
      // Windows Desktop, macOS, Linux
      return 'http://127.0.0.1:8000';
    }
  }

  /// Permet à l'utilisateur de configurer l'IP manuellement (utile pour téléphone physique sur Wi-Fi)
  Future<void> setCustomHost(String host) async {
    String formatted = host.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }
    _customHost = formatted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyHost, formatted);
    } catch (_) {}
  }

  /// Vérifie si le microservice Python est démarré et fonctionnel
  Future<Map<String, dynamic>> checkServiceHealth() async {
    try {
      final base = await getBaseUrl();
      final uri = Uri.parse('$base/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'is_online': true,
          'model_configured': data['model_configured'] == true,
          'endpoint': data['endpoint']?.toString() ?? '',
          'url': base,
        };
      }
      return {'is_online': false, 'error': 'HTTP ${res.statusCode}', 'url': base};
    } catch (e) {
      final base = await getBaseUrl();
      return {'is_online': false, 'error': e.toString(), 'url': base};
    }
  }

  /// Envoie un ou plusieurs fichiers au microservice Python pour extraction IA
  Future<AiScanResult> scanDocuments({
    required List<PlatformFile> files,
    required String documentType,
  }) async {
    if (files.isEmpty) {
      return AiScanResult.error('Aucun fichier sélectionné pour la numérisation.', documentType: documentType);
    }

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/scan');
      final request = http.MultipartRequest('POST', uri);

      request.fields['document_type'] = documentType;

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        Uint8List? fileBytes = file.bytes;

        // Si les octets ne sont pas chargés en mémoire et qu'on est sur desktop/mobile
        if (fileBytes == null && file.path != null && !PlatformUtils.isWeb) {
          try {
            final f = io.File(file.path!);
            if (await f.exists()) {
              fileBytes = await f.readAsBytes();
            }
          } catch (e) {
            debugPrint('AiDocumentScannerService: Erreur de lecture de fichier local: $e');
          }
        }

        if (fileBytes != null) {
          final multipartFile = http.MultipartFile.fromBytes(
            'files',
            fileBytes,
            filename: file.name,
          );
          request.files.add(multipartFile);
        }
      }

      if (request.files.isEmpty) {
        return AiScanResult.error('Impossible d\'accéder au contenu des fichiers sélectionnés.', documentType: documentType);
      }

      debugPrint('AiDocumentScannerService: Envoi de ${request.files.length} fichier(s) vers $uri');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
        return AiScanResult.fromJson(jsonResponse);
      } else {
        return AiScanResult.error(
          'Erreur serveur (${streamedResponse.statusCode}): $responseBody',
          documentType: documentType,
        );
      }
    } catch (e) {
      debugPrint('AiDocumentScannerService: Exception pendant le scan: $e');
      return AiScanResult.error(
        'Connexion au service d\'extraction IA impossible ($e).\n'
        'Vérifiez que le service Python est lancé via "ai_service/start_service.bat".',
        documentType: documentType,
      );
    }
  }
}
