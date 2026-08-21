import 'dart:convert';

/// Represents a document template configuration.
///
/// All template styling/positioning is stored as a JSON blob in [config]
/// for maximum flexibility. Helper getters/setters provide typed access.
class DocumentTemplate {
  final String id;
  final String name;
  final String documentType; // 'invoice', 'quote', 'delivery_note', etc.
  final String? enterpriseId;
  final bool isDefault;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentTemplate({
    required this.id,
    required this.name,
    this.documentType = 'invoice',
    this.enterpriseId,
    this.isDefault = false,
    Map<String, dynamic>? config,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : config = config ?? classicConfig(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ─── Serialization (Firestore & SQLite) ───────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'document_type': documentType,
        'type': documentType,
        'enterprise_id': enterpriseId,
        'enterpriseId': enterpriseId,
        'is_default': isDefault,
        'isDefault': isDefault,
        'config': config,
        'templateData': config,
        'config_json': jsonEncode(config),
        'created_at': createdAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DocumentTemplate.fromMap(Map<String, dynamic> map, {String? id}) {
    Map<String, dynamic> cfg;
    try {
      if (map['config'] is Map) {
        cfg = Map<String, dynamic>.from(map['config'] as Map);
      } else if (map['templateData'] is Map) {
        cfg = Map<String, dynamic>.from(map['templateData'] as Map);
      } else if (map['config_json'] != null) {
        cfg = jsonDecode(map['config_json'] as String) as Map<String, dynamic>;
      } else {
        cfg = classicConfig();
      }
    } catch (_) {
      cfg = classicConfig();
    }

    final isDef = map['is_default'] == true ||
        map['is_default'] == 1 ||
        map['isDefault'] == true ||
        map['isDefault'] == 1;

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) {
        try {
          return DateTime.parse(val);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return DocumentTemplate(
      id: id ?? (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? 'Modèle de document',
      documentType: map['document_type'] as String? ??
          map['type'] as String? ??
          'invoice',
      enterpriseId: map['enterprise_id'] as String? ??
          map['enterpriseId'] as String?,
      isDefault: isDef,
      config: cfg,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  DocumentTemplate copyWith({
    String? id,
    String? name,
    String? documentType,
    String? enterpriseId,
    bool? isDefault,
    Map<String, dynamic>? config,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      DocumentTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        documentType: documentType ?? this.documentType,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        isDefault: isDefault ?? this.isDefault,
        config: config ?? Map<String, dynamic>.from(this.config),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  // ─── Default Configurations (5 Presets) ───────────────────────────

  static Map<String, dynamic> defaultConfig() => classicConfig();

  /// Standard company info default toggles
  static Map<String, dynamic> defaultCompanyInfo() => {
        'showName': true,
        'showPhone': true,
        'showEmail': true,
        'showWebsite': true,
        'showTaxId': true, // Matricule Fiscale / NIF
        'showRcNumber': true, // Registre de Commerce
        'showAddress': true,
        'showRib': true,
        'showLogo': false,
      };

  /// Standard document info default toggles
  static Map<String, dynamic> defaultDocumentInfo() => {
        'showNumber': true, // Numéro de document
        'showDate': true, // Date d'émission
        'showDueDate': true, // Date d'échéance
        'showValidityDate': true, // Date de validité
        'showTitle': true, // Type / Titre
        'showStatus': true, // Statut du document
      };

  /// Standard client info default toggles
  static Map<String, dynamic> defaultClientInfo() => {
        'showName': true,
        'showAddress': true,
        'showPhone': true,
        'showEmail': true,
        'showCode': true,
        'showTaxId': true, // Matricule fiscale client
      };

  /// Standard table columns list
  static List<Map<String, dynamic>> defaultTableColumns() => [
        {'id': 'index', 'label': '#', 'visible': true, 'type': 'standard'},
        {'id': 'reference', 'label': 'Référence', 'visible': true, 'type': 'standard'},
        {'id': 'code', 'label': 'Code article', 'visible': false, 'type': 'standard'},
        {'id': 'designation', 'label': 'Désignation', 'visible': true, 'type': 'standard'},
        {'id': 'quantity', 'label': 'Qté', 'visible': true, 'type': 'standard'},
        {'id': 'unitPrice', 'label': 'Prix Unitaire HT', 'visible': true, 'type': 'standard'},
        {'id': 'unitPriceTTC', 'label': 'Prix Unitaire TTC', 'visible': false, 'type': 'standard'},
        {'id': 'tva', 'label': 'TVA (%)', 'visible': true, 'type': 'standard'},
        {'id': 'discount', 'label': 'Remise (%)', 'visible': true, 'type': 'standard'},
        {'id': 'totalHT', 'label': 'Total HT', 'visible': true, 'type': 'standard'},
        {'id': 'totalTTCLine', 'label': 'Total TTC', 'visible': false, 'type': 'standard'},
      ];

  /// Standard footer default toggles
  static Map<String, dynamic> defaultFooter() => {
        'showSignature': true,
        'showNotes': true,
        'showPaymentTerms': true,
        'showLegalNotice': true,
        'showPageNumbers': true,
      };

  /// Template 1: Classique (Default) - Standard, proven layout matching PDF example
  static Map<String, dynamic> classicConfig() => {
        'styleCode': 'classic',
        'styleName': 'Classique',
        'description': 'Mise en page standard avec en-tête bleu, tableau structuré et récapitulatif net.',
        'tableStyle': 'classique',
        'headerBgColor': 0xFF1A56DB, // Primary Blue
        'headerTextColor': 0xFFFFFFFF,
        'accentColor': 0xFF1A56DB,
        'fontSize': 10.0,
        'rowHeight': 8.0,

        // Field sections visibility
        'companyInfo': defaultCompanyInfo(),
        'documentInfo': defaultDocumentInfo(),
        'clientInfo': defaultClientInfo(),
        'tableColumns': defaultTableColumns(),
        'footer': defaultFooter(),

        // Header and Client Elements positioning
        'logo': {'positionX': 15.0, 'positionY': 15.0, 'width': 20.0, 'height': 15.0},
        'companyName': {'positionX': 40.0, 'positionY': 15.0},
        'companyDetails': {'positionX': 40.0, 'positionY': 22.0},
        'documentTitle': {'positionX': 140.0, 'positionY': 15.0},
        'clientDetails': {'positionX': 15.0, 'positionY': 45.0, 'width': 180.0, 'height': 30.0},

        // Totals section positioning & visibility
        'totals': {'positionX': 130.0, 'width': 65.0, 'lineSpacing': 7.0, 'labelWidth': 35.0},
        'totalBrut': {'visible': false, 'fontSize': 10.0, 'color': 0xFF000000, 'style': 'Normal'},
        'totalRemises': {'visible': true, 'fontSize': 10.0, 'color': 0xFF000000, 'style': 'Normal'},
        'totalHT': {'visible': true, 'fontSize': 10.0, 'color': 0xFF000000, 'style': 'Normal'},
        'taxes': {'visible': true, 'fontSize': 10.0, 'color': 0xFF000000, 'style': 'Normal'},
        'timbre': {'visible': true, 'fontSize': 10.0, 'color': 0xFF000000, 'style': 'Normal'},
        'totalTTC': {
          'visible': true,
          'fontSize': 12.0,
          'color': 0xFF000000,
          'style': 'Gras',
          'showColoredBg': true,
          'bgColor': 0xFF2D3748,
          'padding': 4.0,
        },
        'totalLetters': {'visible': false, 'fontSize': 9.0, 'color': 0xFF000000, 'style': 'Normal'},

        // E-Facture section
        'qrCode': {'enabled': true, 'positionX': 15.0, 'positionY': 98.0, 'width': 25.0, 'height': 25.0, 'showLabel': true, 'labelText': 'E-Facture'},
        'ttnReference': {'enabled': true, 'positionX': 45.0, 'positionY': 99.0, 'fontSize': 9.0, 'color': 0xFF1A56DB, 'fontWeight': 'Gras', 'showLabel': true, 'labelText': 'Réf TTN:'},
        'submissionDate': {'enabled': true, 'positionX': 45.0, 'positionY': 232.0, 'fontSize': 8.0, 'color': 0xFF000000, 'showLabel': true, 'labelText': 'Envoyé le:'},
        'statusBadge': {'enabled': true, 'positionX': 45.0, 'positionY': 239.0, 'width': 40.0, 'height': 6.0, 'fontSize': 8.0},

        // Table settings
        'table': {'fixedHeight': false, 'borderColor': 0xFFE2E8F0, 'borderWidth': 0.3, 'showOutline': true},
      };

  /// Template 2: Moderne - Contemporary design with indigo/blue bar, zebra rows, airy layout
  static Map<String, dynamic> modernConfig() => {
        ...classicConfig(),
        'styleCode': 'modern',
        'styleName': 'Moderne',
        'description': 'Design contemporain avec barre d\'accent indigo, lignes alternées et typographie aérée.',
        'tableStyle': 'alterne',
        'headerBgColor': 0xFF2563EB,
        'headerTextColor': 0xFFFFFFFF,
        'accentColor': 0xFF3B82F6,
        'fontSize': 10.5,
        'rowHeight': 9.0,
        'companyInfo': defaultCompanyInfo(),
        'documentInfo': defaultDocumentInfo(),
        'clientInfo': defaultClientInfo(),
        'tableColumns': defaultTableColumns(),
        'footer': defaultFooter(),
        'table': {'fixedHeight': false, 'borderColor': 0xFFDBEAFE, 'borderWidth': 0.5, 'showOutline': false},
        'totalTTC': {
          'visible': true,
          'fontSize': 13.0,
          'color': 0xFF1E3A8A,
          'style': 'Gras',
          'showColoredBg': true,
          'bgColor': 0xFFEFF6FF,
          'padding': 6.0,
        },
      };

  /// Template 3: Minimaliste - Scandinavian / Apple-style ultra clean, no borders, subtle dividers
  static Map<String, dynamic> minimalistConfig() => {
        ...classicConfig(),
        'styleCode': 'minimalist',
        'styleName': 'Minimaliste',
        'description': 'Design épuré et sobre, axé sur la clarté et l\'espace blanc sans bordures superflues.',
        'tableStyle': 'minimaliste',
        'headerBgColor': 0xFFF3F4F6,
        'headerTextColor': 0xFF111827,
        'accentColor': 0xFF111827,
        'fontSize': 9.5,
        'rowHeight': 8.0,
        'companyInfo': defaultCompanyInfo(),
        'documentInfo': defaultDocumentInfo(),
        'clientInfo': defaultClientInfo(),
        'tableColumns': defaultTableColumns(),
        'footer': defaultFooter(),
        'table': {'fixedHeight': false, 'borderColor': 0xFFE5E7EB, 'borderWidth': 0.4, 'showOutline': false},
        'totalTTC': {
          'visible': true,
          'fontSize': 12.0,
          'color': 0xFF111827,
          'style': 'Gras',
          'showColoredBg': false,
          'bgColor': 0xFFFFFFFF,
          'padding': 4.0,
        },
      };

  /// Template 4: Professionnel - Corporate style with deep navy, structured metadata & dual signatures
  static Map<String, dynamic> professionalConfig() => {
        ...classicConfig(),
        'styleCode': 'professional',
        'styleName': 'Professionnel',
        'description': 'Format corporate pour entreprises : en-tête complet, mentions légales détaillées et double signature.',
        'tableStyle': 'classique',
        'headerBgColor': 0xFF0F2942,
        'headerTextColor': 0xFFFFFFFF,
        'accentColor': 0xFF0F2942,
        'fontSize': 10.0,
        'rowHeight': 8.5,
        'companyInfo': defaultCompanyInfo(),
        'documentInfo': defaultDocumentInfo(),
        'clientInfo': defaultClientInfo(),
        'tableColumns': defaultTableColumns(),
        'footer': defaultFooter(),
        'totalBrut': {'visible': true, 'fontSize': 10.0, 'color': 0xFF000000, 'style': 'Normal'},
        'table': {'fixedHeight': false, 'borderColor': 0xFFCBD5E1, 'borderWidth': 0.5, 'showOutline': true},
        'totalTTC': {
          'visible': true,
          'fontSize': 13.0,
          'color': 0xFFFFFFFF,
          'style': 'Gras',
          'showColoredBg': true,
          'bgColor': 0xFF0F2942,
          'padding': 6.0,
        },
      };

  /// Template 5: Coloré - Vibrant teal / emerald design with highlighted total and energetic accents
  static Map<String, dynamic> colorfulConfig() => {
        ...classicConfig(),
        'styleCode': 'colorful',
        'styleName': 'Coloré',
        'description': 'Style dynamique et créatif avec touches de couleur sarcelle / émeraude et totaux mis en valeur.',
        'tableStyle': 'alterne',
        'headerBgColor': 0xFF0D9488,
        'headerTextColor': 0xFFFFFFFF,
        'accentColor': 0xFF0D9488,
        'fontSize': 10.0,
        'rowHeight': 8.5,
        'companyInfo': defaultCompanyInfo(),
        'documentInfo': defaultDocumentInfo(),
        'clientInfo': defaultClientInfo(),
        'tableColumns': defaultTableColumns(),
        'footer': defaultFooter(),
        'table': {'fixedHeight': false, 'borderColor': 0xFFCCFBF1, 'borderWidth': 0.5, 'showOutline': false},
        'totalTTC': {
          'visible': true,
          'fontSize': 13.0,
          'color': 0xFFFFFFFF,
          'style': 'Gras',
          'showColoredBg': true,
          'bgColor': 0xFF0D9488,
          'padding': 6.0,
        },
      };

  // ─── Factory Methods for the 5 Default Templates ──────────────────

  factory DocumentTemplate.classicTemplate({
    required String id,
    required String enterpriseId,
    bool isDefault = true,
    String documentType = 'invoice',
  }) =>
      DocumentTemplate(
        id: id,
        name: 'Classique',
        documentType: documentType,
        enterpriseId: enterpriseId,
        isDefault: isDefault,
        config: classicConfig(),
      );

  factory DocumentTemplate.modernTemplate({
    required String id,
    required String enterpriseId,
    bool isDefault = false,
    String documentType = 'invoice',
  }) =>
      DocumentTemplate(
        id: id,
        name: 'Moderne',
        documentType: documentType,
        enterpriseId: enterpriseId,
        isDefault: isDefault,
        config: modernConfig(),
      );

  factory DocumentTemplate.minimalistTemplate({
    required String id,
    required String enterpriseId,
    bool isDefault = false,
    String documentType = 'invoice',
  }) =>
      DocumentTemplate(
        id: id,
        name: 'Minimaliste',
        documentType: documentType,
        enterpriseId: enterpriseId,
        isDefault: isDefault,
        config: minimalistConfig(),
      );

  factory DocumentTemplate.professionalTemplate({
    required String id,
    required String enterpriseId,
    bool isDefault = false,
    String documentType = 'invoice',
  }) =>
      DocumentTemplate(
        id: id,
        name: 'Professionnel',
        documentType: documentType,
        enterpriseId: enterpriseId,
        isDefault: isDefault,
        config: professionalConfig(),
      );

  factory DocumentTemplate.colorfulTemplate({
    required String id,
    required String enterpriseId,
    bool isDefault = false,
    String documentType = 'invoice',
  }) =>
      DocumentTemplate(
        id: id,
        name: 'Coloré',
        documentType: documentType,
        enterpriseId: enterpriseId,
        isDefault: isDefault,
        config: colorfulConfig(),
      );

  /// Creates the primary default template (Classique) configured for the given enterprise.
  static List<DocumentTemplate> createDefaultTemplates({
    required String enterpriseId,
    String Function(String preset)? idGenerator,
  }) {
    return [
      DocumentTemplate.classicTemplate(
        id: idGenerator?.call('classic') ?? '${enterpriseId}_tpl_classic',
        enterpriseId: enterpriseId,
        isDefault: true,
      ),
    ];
  }

  // ─── Typed Config Accessors ─────────────────────────────────────

  String get tableStyle => config['tableStyle'] as String? ?? 'classique';
  int get headerBgColor => config['headerBgColor'] as int? ?? 0xFF1A56DB;
  int get headerTextColor => config['headerTextColor'] as int? ?? 0xFFFFFFFF;
  int get accentColor => config['accentColor'] as int? ?? headerBgColor;
  double get fontSize => (config['fontSize'] as num?)?.toDouble() ?? 10.0;
  double get rowHeight => (config['rowHeight'] as num?)?.toDouble() ?? 8.0;
  String get styleCode => config['styleCode'] as String? ?? 'classic';
  String get styleName => config['styleName'] as String? ?? 'Classique';
  String get styleDescription => config['description'] as String? ?? '';

  /// Returns the pristine preset configuration associated with this template's styleCode.
  Map<String, dynamic> getPristinePresetConfig() {
    switch (styleCode) {
      case 'modern':
        return DocumentTemplate.modernConfig();
      case 'minimalist':
        return DocumentTemplate.minimalistConfig();
      case 'professional':
        return DocumentTemplate.professionalConfig();
      case 'colorful':
        return DocumentTemplate.colorfulConfig();
      case 'classic':
      default:
        return DocumentTemplate.classicConfig();
    }
  }

  Map<String, dynamic> get companyInfoConfig =>
      config['companyInfo'] as Map<String, dynamic>? ?? defaultCompanyInfo();
  Map<String, dynamic> get documentInfoConfig =>
      config['documentInfo'] as Map<String, dynamic>? ?? defaultDocumentInfo();
  Map<String, dynamic> get clientInfoConfig =>
      config['clientInfo'] as Map<String, dynamic>? ?? defaultClientInfo();
  Map<String, dynamic> get footerConfig =>
      config['footer'] as Map<String, dynamic>? ?? defaultFooter();

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
  Map<String, dynamic> get timbreConfig =>
      config['timbre'] as Map<String, dynamic>? ?? {};
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
