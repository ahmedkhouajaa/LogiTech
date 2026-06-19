import '../utils/constants.dart';

class Project {
  final String id;
  final String name;
  final String? description;
  final String? customerId;
  final String? customerName;
  final DateTime startDate;
  final DateTime? endDate;
  final double budget;
  final double spent;
  final ProjectStatus status;
  final double progress;
  final String? notes;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id, required this.name, this.description,
    this.customerId, this.customerName, required this.startDate,
    this.endDate, this.budget = 0, this.spent = 0,
    this.status = ProjectStatus.planning, this.progress = 0,
    this.notes, this.firebaseUid, this.isDeleted = false,
    DateTime? createdAt, DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get budgetRemaining => budget - spent;
  bool get isOverBudget => spent > budget && budget > 0;

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'description': description,
        'customer_id': customerId, 'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(), 'budget': budget, 'spent': spent,
        'status': status.name, 'progress': progress, 'notes': notes,
        'firebase_uid': firebaseUid, 'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Project.fromMap(Map<String, dynamic> map) => Project(
        id: map['id'] as String, name: map['name'] as String,
        description: map['description'] as String?,
        customerId: map['customer_id'] as String?,
        customerName: map['customer_name'] as String?,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: map['end_date'] != null ? DateTime.parse(map['end_date'] as String) : null,
        budget: (map['budget'] as num?)?.toDouble() ?? 0,
        spent: (map['spent'] as num?)?.toDouble() ?? 0,
        status: ProjectStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => ProjectStatus.planning),
        progress: (map['progress'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Project copyWith({
    String? id, String? name, String? description, String? customerId,
    String? customerName, DateTime? startDate, DateTime? endDate,
    double? budget, double? spent, ProjectStatus? status, double? progress,
    String? notes, String? firebaseUid, bool? isDeleted,
    DateTime? createdAt, DateTime? updatedAt,
  }) => Project(
        id: id ?? this.id, name: name ?? this.name,
        description: description ?? this.description,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        startDate: startDate ?? this.startDate, endDate: endDate ?? this.endDate,
        budget: budget ?? this.budget, spent: spent ?? this.spent,
        status: status ?? this.status, progress: progress ?? this.progress,
        notes: notes ?? this.notes, firebaseUid: firebaseUid ?? this.firebaseUid,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      );
}

class CompanySettings {
  final String id;
  final String name;
  final String? logoPath;
  final String? address;
  final String? city;
  final String? phone;
  final String? email;
  final String? website;
  final String? taxId;
  final String? rcNumber;
  final String? nis;
  final String? nif;
  final String? ai;
  final String currency;
  final double defaultTvaRate;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final String? bankName;
  final String? bankAccount;
  final String? rib;
  final DateTime updatedAt;

  CompanySettings({
    this.id = '1', this.name = 'Mon Entreprise', this.logoPath,
    this.address, this.city, this.phone, this.email, this.website,
    this.taxId, this.rcNumber, this.nis, this.nif, this.ai,
    this.currency = 'DZD', this.defaultTvaRate = 19,
    this.invoicePrefix = 'FAC', this.nextInvoiceNumber = 1,
    this.bankName, this.bankAccount, this.rib,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'logo_path': logoPath, 'address': address,
        'city': city, 'phone': phone, 'email': email, 'website': website,
        'tax_id': taxId, 'rc_number': rcNumber, 'nis': nis, 'nif': nif,
        'ai': ai, 'currency': currency, 'default_tva_rate': defaultTvaRate,
        'invoice_prefix': invoicePrefix, 'next_invoice_number': nextInvoiceNumber,
        'bank_name': bankName, 'bank_account': bankAccount, 'rib': rib,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CompanySettings.fromMap(Map<String, dynamic> map) => CompanySettings(
        id: map['id'] as String? ?? '1', name: map['name'] as String? ?? 'Mon Entreprise',
        logoPath: map['logo_path'] as String?,
        address: map['address'] as String?, city: map['city'] as String?,
        phone: map['phone'] as String?, email: map['email'] as String?,
        website: map['website'] as String?, taxId: map['tax_id'] as String?,
        rcNumber: map['rc_number'] as String?, nis: map['nis'] as String?,
        nif: map['nif'] as String?, ai: map['ai'] as String?,
        currency: map['currency'] as String? ?? 'DZD',
        defaultTvaRate: (map['default_tva_rate'] as num?)?.toDouble() ?? 19,
        invoicePrefix: map['invoice_prefix'] as String? ?? 'FAC',
        nextInvoiceNumber: (map['next_invoice_number'] as int?) ?? 1,
        bankName: map['bank_name'] as String?,
        bankAccount: map['bank_account'] as String?,
        rib: map['rib'] as String?,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
      );

  CompanySettings copyWith({
    String? id, String? name, String? logoPath, String? address,
    String? city, String? phone, String? email, String? website,
    String? taxId, String? rcNumber, String? nis, String? nif, String? ai,
    String? currency, double? defaultTvaRate, String? invoicePrefix,
    int? nextInvoiceNumber, String? bankName, String? bankAccount, String? rib,
    DateTime? updatedAt,
  }) => CompanySettings(
        id: id ?? this.id, name: name ?? this.name,
        logoPath: logoPath ?? this.logoPath, address: address ?? this.address,
        city: city ?? this.city, phone: phone ?? this.phone,
        email: email ?? this.email, website: website ?? this.website,
        taxId: taxId ?? this.taxId, rcNumber: rcNumber ?? this.rcNumber,
        nis: nis ?? this.nis, nif: nif ?? this.nif, ai: ai ?? this.ai,
        currency: currency ?? this.currency,
        defaultTvaRate: defaultTvaRate ?? this.defaultTvaRate,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
        bankName: bankName ?? this.bankName,
        bankAccount: bankAccount ?? this.bankAccount, rib: rib ?? this.rib,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}


class SyncQueueItem {
  final int? id;
  final String tableName;
  final String recordId;
  final String operation;
  final String dataJson;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String status;
  final String? errorMessage;

  SyncQueueItem({
    this.id, required this.tableName, required this.recordId,
    required this.operation, required this.dataJson,
    DateTime? createdAt, this.syncedAt,
    this.status = 'pending', this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'table_name': tableName, 'record_id': recordId,
        'operation': operation, 'data_json': dataJson,
        'created_at': createdAt.toIso8601String(),
        'synced_at': syncedAt?.toIso8601String(),
        'status': status, 'error_message': errorMessage,
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) => SyncQueueItem(
        id: map['id'] as int?,
        tableName: map['table_name'] as String,
        recordId: map['record_id'] as String,
        operation: map['operation'] as String,
        dataJson: map['data_json'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at'] as String) : null,
        status: map['status'] as String? ?? 'pending',
        errorMessage: map['error_message'] as String?,
      );
}

class ActivityLog {
  final String id;
  final String action;
  final String description;
  final String? entityType;
  final String? entityId;
  final String? userId;
  final DateTime createdAt;

  ActivityLog({
    required this.id, required this.action, required this.description,
    this.entityType, this.entityId, this.userId, DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'action': action, 'description': description,
        'entity_type': entityType, 'entity_id': entityId,
        'user_id': userId, 'created_at': createdAt.toIso8601String(),
      };

  factory ActivityLog.fromMap(Map<String, dynamic> map) => ActivityLog(
        id: map['id'] as String, action: map['action'] as String,
        description: map['description'] as String,
        entityType: map['entity_type'] as String?,
        entityId: map['entity_id'] as String?,
        userId: map['user_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
