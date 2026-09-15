class DocumentTypeDefinition {
  final String key; // Firestore collection name, e.g. 'invoices'
  final String label; // e.g. 'Facture'
  final String category; // 'Vente' or 'Achat'
  final String dropdownLabel; // e.g. 'Facture - Vente'
  final String defaultPrefix; // e.g. 'FAC'

  const DocumentTypeDefinition({
    required this.key,
    required this.label,
    required this.category,
    required this.dropdownLabel,
    required this.defaultPrefix,
  });

  static const List<DocumentTypeDefinition> allTypes = [
    // Vente
    DocumentTypeDefinition(
      key: 'invoices',
      label: 'Facture',
      category: 'Vente',
      dropdownLabel: 'Facture - Vente',
      defaultPrefix: 'FAC',
    ),
    DocumentTypeDefinition(
      key: 'quotes',
      label: 'Devis',
      category: 'Vente',
      dropdownLabel: 'Devis - Vente',
      defaultPrefix: 'DV',
    ),
    DocumentTypeDefinition(
      key: 'customer_orders',
      label: 'Commande client',
      category: 'Vente',
      dropdownLabel: 'Commande client - Vente',
      defaultPrefix: 'CC',
    ),
    DocumentTypeDefinition(
      key: 'delivery_notes',
      label: 'Bon de livraison',
      category: 'Vente',
      dropdownLabel: 'Bon de livraison - Vente',
      defaultPrefix: 'BL',
    ),
    DocumentTypeDefinition(
      key: 'bons_sortie',
      label: 'Bon de sortie',
      category: 'Vente',
      dropdownLabel: 'Bon de sortie - Vente',
      defaultPrefix: 'BS',
    ),
    DocumentTypeDefinition(
      key: 'credit_notes',
      label: 'Avoir client',
      category: 'Vente',
      dropdownLabel: 'Avoir client - Vente',
      defaultPrefix: 'AV',
    ),
    DocumentTypeDefinition(
      key: 'return_notes',
      label: 'Bon de retour',
      category: 'Vente',
      dropdownLabel: 'Bon de retour - Vente',
      defaultPrefix: 'BR',
    ),
    // Achat
    DocumentTypeDefinition(
      key: 'supplier_orders',
      label: 'Commande fournisseur',
      category: 'Achat',
      dropdownLabel: 'Commande fournisseur - Achat',
      defaultPrefix: 'CF',
    ),
    DocumentTypeDefinition(
      key: 'receiving_vouchers',
      label: 'Bon de réception',
      category: 'Achat',
      dropdownLabel: 'Bon de réception - Achat',
      defaultPrefix: 'BR',
    ),
    DocumentTypeDefinition(
      key: 'purchase_invoices',
      label: 'Facture d\'achat',
      category: 'Achat',
      dropdownLabel: 'Facture d\'achat - Achat',
      defaultPrefix: 'FA',
    ),
    DocumentTypeDefinition(
      key: 'supplier_credit_notes',
      label: 'Avoir fournisseur',
      category: 'Achat',
      dropdownLabel: 'Avoir fournisseur - Achat',
      defaultPrefix: 'AVF',
    ),
    DocumentTypeDefinition(
      key: 'supplier_returns',
      label: 'Retour fournisseur',
      category: 'Achat',
      dropdownLabel: 'Retour fournisseur - Achat',
      defaultPrefix: 'BRF',
    ),
  ];

  static String normalizeKey(String key) {
    if (key == 'exit_vouchers') return 'bons_sortie';
    return key;
  }

  static DocumentTypeDefinition fromKey(String key) {
    final normKey = normalizeKey(key);
    return allTypes.firstWhere(
      (t) => t.key == normKey,
      orElse: () => DocumentTypeDefinition(
        key: normKey,
        label: normKey,
        category: 'Vente',
        dropdownLabel: normKey,
        defaultPrefix: normKey.toUpperCase().substring(0, normKey.length >= 2 ? 2 : normKey.length),
      ),
    );
  }
}

class DocumentNumberingConfig {
  final String docTypeKey;
  final String prefix;
  final int currentNumber;
  final int numberLength;
  final bool includeYear;
  final bool isEnabled;

  DocumentNumberingConfig({
    required this.docTypeKey,
    required this.prefix,
    required this.currentNumber,
    this.numberLength = 6,
    this.includeYear = true,
    this.isEnabled = true,
  });

  DocumentTypeDefinition get definition => DocumentTypeDefinition.fromKey(docTypeKey);

  String formatDocNumber(int number, {int? year}) {
    if (!isEnabled) {
      final y = year ?? DateTime.now().year;
      final seq = number.toString().padLeft(6, '0');
      return '$prefix-$y-$seq';
    }

    final paddedNum = number.toString().padLeft(numberLength > 0 ? numberLength : 6, '0');
    final cleanPrefix = prefix.trim().isNotEmpty ? prefix.trim() : definition.defaultPrefix;

    if (includeYear) {
      final y = year ?? DateTime.now().year;
      return '$cleanPrefix-$y-$paddedNum';
    } else {
      return '$cleanPrefix-$paddedNum';
    }
  }

  String get preview => formatDocNumber(currentNumber > 0 ? currentNumber : 1);

  DocumentNumberingConfig copyWith({
    String? docTypeKey,
    String? prefix,
    int? currentNumber,
    int? numberLength,
    bool? includeYear,
    bool? isEnabled,
  }) {
    return DocumentNumberingConfig(
      docTypeKey: docTypeKey ?? this.docTypeKey,
      prefix: prefix ?? this.prefix,
      currentNumber: currentNumber ?? this.currentNumber,
      numberLength: numberLength ?? this.numberLength,
      includeYear: includeYear ?? this.includeYear,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'doc_type_key': docTypeKey,
      'prefix': prefix,
      'count': currentNumber,
      'number_length': numberLength,
      'include_year': includeYear,
      'is_enabled': isEnabled,
      'configured': true,
    };
  }

  factory DocumentNumberingConfig.fromMap(String key, Map<String, dynamic>? map) {
    final def = DocumentTypeDefinition.fromKey(key);
    if (map == null) {
      return DocumentNumberingConfig(
        docTypeKey: key,
        prefix: def.defaultPrefix,
        currentNumber: 1,
        numberLength: 6,
        includeYear: true,
        isEnabled: true,
      );
    }

    return DocumentNumberingConfig(
      docTypeKey: key,
      prefix: (map['prefix']?.toString().isNotEmpty == true)
          ? map['prefix'].toString()
          : def.defaultPrefix,
      currentNumber: (map['count'] is num)
          ? (map['count'] as num).toInt()
          : (map['currentNumber'] is num ? (map['currentNumber'] as num).toInt() : 1),
      numberLength: (map['number_length'] is num)
          ? (map['number_length'] as num).toInt()
          : (map['numberLength'] is num ? (map['numberLength'] as num).toInt() : 6),
      includeYear: map['include_year'] == null
          ? (map['includeYear'] ?? true)
          : map['include_year'] == true,
      isEnabled: map['is_enabled'] == null
          ? (map['isEnabled'] ?? true)
          : map['is_enabled'] == true,
    );
  }
}
