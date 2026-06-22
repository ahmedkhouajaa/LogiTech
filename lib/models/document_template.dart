import 'dart:convert';

/// Represents a document template configuration.
///
/// All template styling/positioning is stored as a JSON blob in [configJson]
/// for maximum flexibility. Helper getters/setters provide typed access.
class DocumentTemplate {
  final String id;
  final String name;
  final String documentType; // 'invoice', 'quote', 'delivery_note', etc.
  final bool isDefault;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentTemplate({
    required this.id,
    required this.name,
    this.documentType = 'invoice',
    this.isDefault = false,
    Map<String, dynamic>? config,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : config = config ?? defaultConfig(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ─── SQLite Serialization ───────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'document_type': documentType,
        'is_default': isDefault ? 1 : 0,
        'config_json': jsonEncode(config),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DocumentTemplate.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> cfg;
    try {
      cfg = jsonDecode(map['config_json'] as String? ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      cfg = defaultConfig();
    }
    return DocumentTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      documentType: map['document_type'] as String? ?? 'invoice',
      isDefault: map['is_default'] == 1,
      config: cfg,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  DocumentTemplate copyWith({
    String? id,
    String? name,
    String? documentType,
    bool? isDefault,
    Map<String, dynamic>? config,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      DocumentTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        documentType: documentType ?? this.documentType,
        isDefault: isDefault ?? this.isDefault,
        config: config ?? Map<String, dynamic>.from(this.config),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  // ─── Default Configuration ──────────────────────────────────────

  static Map<String, dynamic> defaultConfig() => {
        // Global styles
        'tableStyle': 'classique', // classique | alterne | minimaliste
        'headerBgColor': 0xFF1a56db,
        'headerTextColor': 0xFFFFFFFF,
        'fontSize': 10.0,
        'rowHeight': 8.0,

        // Table Columns Configuration
        'tableColumns': [
          {'id': 'designation', 'label': 'Désignation', 'visible': true, 'type': 'standard'},
          {'id': 'quantity', 'label': 'Qté', 'visible': true, 'type': 'standard'},
          {'id': 'unitPrice', 'label': 'Prix Unitaire', 'visible': true, 'type': 'standard'},
          {'id': 'tva', 'label': 'TVA', 'visible': true, 'type': 'standard'},
          {'id': 'discount', 'label': 'Remise', 'visible': true, 'type': 'standard'},
          {'id': 'totalHT', 'label': 'Total HT', 'visible': true, 'type': 'standard'},
        ],

        // Header and Client Elements (Absolute Positioning)
        'logo': {
          'positionX': 15.0,
          'positionY': 15.0,
          'width': 20.0,
          'height': 15.0,
        },
        'companyName': {
          'positionX': 40.0,
          'positionY': 15.0,
        },
        'companyDetails': {
          'positionX': 40.0,
          'positionY': 22.0,
        },
        'documentTitle': {
          'positionX': 140.0,
          'positionY': 15.0,
        },
        'clientDetails': {
          'positionX': 15.0,
          'positionY': 45.0,
          'width': 180.0,
          'height': 30.0,
        },

        // Totals section positioning
        'totals': {
          'positionX': 130.0,
          'width': 65.0,
          'lineSpacing': 7.0,
          'labelWidth': 35.0,
        },

        // Total fields
        'totalBrut': {
          'visible': false,
          'fontSize': 10.0,
          'color': 0xFF000000,
          'style': 'Normal', // Normal | Gras
        },
        'totalRemises': {
          'visible': true,
          'fontSize': 10.0,
          'color': 0xFF000000,
          'style': 'Normal',
        },
        'totalHT': {
          'visible': true,
          'fontSize': 10.0,
          'color': 0xFF000000,
          'style': 'Normal',
        },
        'taxes': {
          'visible': true,
          'fontSize': 10.0,
          'color': 0xFF000000,
          'style': 'Normal',
        },
        'totalTTC': {
          'visible': true,
          'fontSize': 12.0,
          'color': 0xFF000000,
          'style': 'Gras',
          'showColoredBg': true,
          'bgColor': 0xFF2D3748,
          'padding': 4.0,
        },
        'totalLetters': {
          'visible': true,
          'fontSize': 9.0,
          'color': 0xFF000000,
          'style': 'Normal',
        },

        // E-Facture section
        'qrCode': {
          'enabled': true,
          'positionX': 15.0,
          'positionY': 98.0,
          'width': 25.0,
          'height': 25.0,
          'showLabel': true,
          'labelText': 'E-Facture',
        },
        'ttnReference': {
          'enabled': true,
          'positionX': 45.0,
          'positionY': 99.0,
          'fontSize': 9.0,
          'color': 0xFF1a56db,
          'fontWeight': 'Gras', // Normal | Gras | Graisse
          'showLabel': true,
          'labelText': 'Réf TTN:',
        },
        'submissionDate': {
          'enabled': true,
          'positionX': 45.0,
          'positionY': 232.0,
          'fontSize': 8.0,
          'color': 0xFF000000,
          'showLabel': true,
          'labelText': 'Envoyé le:',
        },
        'statusBadge': {
          'enabled': true,
          'positionX': 45.0,
          'positionY': 239.0,
          'width': 40.0,
          'height': 6.0,
          'fontSize': 8.0,
        },

        // Table settings
        'table': {
          'fixedHeight': false,
          'borderColor': 0xFFE2E8F0,
          'borderWidth': 0.3,
          'showOutline': true,
        },
      };

  // ─── Typed Config Accessors ─────────────────────────────────────

  String get tableStyle => config['tableStyle'] as String? ?? 'classique';
  int get headerBgColor => config['headerBgColor'] as int? ?? 0xFF1a56db;
  int get headerTextColor => config['headerTextColor'] as int? ?? 0xFFFFFFFF;
  double get fontSize => (config['fontSize'] as num?)?.toDouble() ?? 10.0;
  double get rowHeight => (config['rowHeight'] as num?)?.toDouble() ?? 8.0;

  Map<String, dynamic> get totalsConfig =>
      config['totals'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get totalBrutConfig =>
      config['totalBrut'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get totalRemisesConfig =>
      config['totalRemises'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get totalHTConfig =>
      config['totalHT'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get taxesConfig =>
      config['taxes'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get totalTTCConfig =>
      config['totalTTC'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get totalLettersConfig =>
      config['totalLetters'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get qrCodeConfig =>
      config['qrCode'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get ttnReferenceConfig =>
      config['ttnReference'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get submissionDateConfig =>
      config['submissionDate'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get statusBadgeConfig =>
      config['statusBadge'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get tableConfig =>
      config['table'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get logoConfig =>
      config['logo'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get companyNameConfig =>
      config['companyName'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get companyDetailsConfig =>
      config['companyDetails'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get documentTitleConfig =>
      config['documentTitle'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get clientDetailsConfig =>
      config['clientDetails'] as Map<String, dynamic>? ?? {};
}
