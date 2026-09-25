import 'package:uuid/uuid.dart';

class CheckTraite {
  final String id;
  final String documentNumber; // Référence du chèque/traite
  final String type; // 'cheque', 'traite', or legacy 'check_received', 'check_issued', etc.
  final String entityType; // 'client' or 'fournisseur'
  final String? partyId; // customer_id or supplier_id
  final String partyName; // customer or supplier name
  final double amount;
  final String? bankName;
  final String? bankAccount;
  final DateTime issueDate;
  final DateTime maturityDate;
  final String status; // 'en_attente', 'déposé', 'rejeté', or legacy 'pending', 'cashed', 'bounced'
  final String? paymentId; // link to payment when cashed
  final String? compteTresorerieId;
  final String? compteTresorerieName;
  final String? documentType; // 'facture_vente', 'facture_achat', 'bon_livraison', 'bon_reception'
  final String? documentId; // ID of the linked document
  final String? documentRef; // Number of the linked document, e.g. "FAC-2026-0001"
  final DateTime? dateDepot;
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Convenient aliases
  String get reference => documentNumber;
  double get montant => amount;
  DateTime get dateEmission => issueDate;
  DateTime get dateEcheance => maturityDate;
  String get statut => status;
  bool get isClient => entityType == 'client' || type == 'check_received' || type == 'traite_received';
  bool get isFournisseur => entityType == 'fournisseur' || type == 'check_issued' || type == 'traite_issued';

  bool get canDeposit {
    final s = status.toLowerCase().replaceAll('é', 'e');
    return s == 'en_attente' || s == 'pending';
  }

  bool get canReject {
    final s = status.toLowerCase().replaceAll('é', 'e');
    return s != 'rejete' && s != 'bounced' && s != 'annule' && s != 'cancelled';
  }

  int get daysUntilMaturity {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maturity = DateTime(maturityDate.year, maturityDate.month, maturityDate.day);
    return maturity.difference(today).inDays;
  }

  CheckTraite({
    String? id,
    required this.documentNumber,
    required this.type,
    this.entityType = 'client',
    required this.amount,
    required this.partyName,
    this.partyId,
    this.bankName,
    this.bankAccount,
    required this.issueDate,
    required this.maturityDate,
    this.status = 'en_attente',
    this.paymentId,
    this.compteTresorerieId,
    this.compteTresorerieName,
    this.documentType,
    this.documentId,
    this.documentRef,
    this.dateDepot,
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  CheckTraite copyWith({
    String? id,
    String? documentNumber,
    String? type,
    String? entityType,
    double? amount,
    String? partyName,
    String? partyId,
    String? bankName,
    String? bankAccount,
    DateTime? issueDate,
    DateTime? maturityDate,
    String? status,
    String? paymentId,
    String? compteTresorerieId,
    String? compteTresorerieName,
    String? documentType,
    String? documentId,
    String? documentRef,
    DateTime? dateDepot,
    String? notes,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheckTraite(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      type: type ?? this.type,
      entityType: entityType ?? this.entityType,
      amount: amount ?? this.amount,
      partyName: partyName ?? this.partyName,
      partyId: partyId ?? this.partyId,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      issueDate: issueDate ?? this.issueDate,
      maturityDate: maturityDate ?? this.maturityDate,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId,
      compteTresorerieId: compteTresorerieId ?? this.compteTresorerieId,
      compteTresorerieName: compteTresorerieName ?? this.compteTresorerieName,
      documentType: documentType ?? this.documentType,
      documentId: documentId ?? this.documentId,
      documentRef: documentRef ?? this.documentRef,
      dateDepot: dateDepot ?? this.dateDepot,
      notes: notes ?? this.notes,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_number': documentNumber,
      'reference': documentNumber,
      'type': type,
      'entity_type': entityType,
      'amount': amount,
      'montant': amount,
      'party_name': partyName,
      'party_id': partyId,
      'bank_name': bankName,
      'bank_account': bankAccount,
      'issue_date': issueDate.millisecondsSinceEpoch,
      'date_emission': issueDate.toIso8601String(),
      'maturity_date': maturityDate.millisecondsSinceEpoch,
      'date_echeance': maturityDate.toIso8601String(),
      'status': status,
      'statut': status,
      'payment_id': paymentId,
      'compte_tresorerie_id': compteTresorerieId,
      'compte_tresorerie_name': compteTresorerieName,
      'document_type': documentType,
      'document_id': documentId,
      'document_ref': documentRef,
      'date_depot': dateDepot?.toIso8601String(),
      'notes': notes,
      'enterprise_id': enterpriseId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CheckTraite.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    final rawStatus = map['statut'] ?? map['status'] ?? 'en_attente';
    String normalizedStatus = rawStatus.toString();
    if (normalizedStatus == 'pending') normalizedStatus = 'en_attente';
    if (normalizedStatus == 'cashed') normalizedStatus = 'déposé';
    if (normalizedStatus == 'bounced') normalizedStatus = 'rejeté';

    final rawType = map['type']?.toString() ?? 'cheque';
    String entityType = map['entity_type']?.toString() ?? 'client';
    if (rawType == 'check_issued' || rawType == 'traite_issued') {
      entityType = 'fournisseur';
    } else if (rawType == 'check_received' || rawType == 'traite_received') {
      entityType = 'client';
    }

    return CheckTraite(
      id: map['id']?.toString(),
      documentNumber: map['document_number']?.toString() ?? map['reference']?.toString() ?? '',
      type: rawType,
      entityType: entityType,
      amount: double.tryParse(map['amount']?.toString() ?? map['montant']?.toString() ?? '0') ?? 0.0,
      partyName: map['party_name']?.toString() ?? '',
      partyId: map['party_id']?.toString() ?? map['entity_id']?.toString(),
      bankName: map['bank_name']?.toString(),
      bankAccount: map['bank_account']?.toString(),
      issueDate: parseDate(map['issue_date'] ?? map['date_emission']),
      maturityDate: parseDate(map['maturity_date'] ?? map['date_echeance']),
      status: normalizedStatus,
      paymentId: map['payment_id']?.toString(),
      compteTresorerieId: map['compte_tresorerie_id']?.toString(),
      compteTresorerieName: map['compte_tresorerie_name']?.toString(),
      documentType: map['document_type']?.toString(),
      documentId: map['document_id']?.toString(),
      documentRef: map['document_ref']?.toString(),
      dateDepot: map['date_depot'] != null ? parseDate(map['date_depot']) : null,
      notes: map['notes']?.toString(),
      enterpriseId: map['enterprise_id']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }
}
