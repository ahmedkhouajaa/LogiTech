class PaymentAccount {
  final String id;
  final String name;
  final String type; // 'cash', 'bank'
  final String? bankName;
  final String? accountNumber;
  final String? iban;
  final double balance;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentAccount({
    required this.id,
    required this.name,
    this.type = 'cash',
    this.bankName,
    this.accountNumber,
    this.iban,
    this.balance = 0,
    this.isDefault = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'bank_name': bankName,
        'account_number': accountNumber,
        'iban': iban,
        'balance': balance,
        'is_default': isDefault ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory PaymentAccount.fromMap(Map<String, dynamic> map) => PaymentAccount(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String? ?? 'cash',
        bankName: map['bank_name'] as String?,
        accountNumber: map['account_number'] as String?,
        iban: map['iban'] as String?,
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        isDefault: map['is_default'] == 1,
        createdAt: map['created_at'] != null
            ? (map['created_at'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
                : DateTime.parse(map['created_at'].toString()))
            : DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? (map['updated_at'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
                : DateTime.parse(map['updated_at'].toString()))
            : DateTime.now(),
      );

  PaymentAccount copyWith({
    String? id,
    String? name,
    String? type,
    String? bankName,
    String? accountNumber,
    String? iban,
    double? balance,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      PaymentAccount(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        bankName: bankName ?? this.bankName,
        accountNumber: accountNumber ?? this.accountNumber,
        iban: iban ?? this.iban,
        balance: balance ?? this.balance,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Payment {
  final String id;
  final String paymentNumber;
  final String direction; // 'encaissement' or 'decaissement'
  final String contactId;
  final String contactType; // 'customer' or 'supplier'
  final String? contactName; // joined from query
  final double amount;
  final String method; // 'especes', 'cheque', 'virement', 'carte'
  final String? accountId;
  final String? accountName; // joined from query
  final String? reference;
  final DateTime paymentDate;
  final String? notes;
  final String status; // 'paid', 'pending', 'cancelled'
  final String? relatedInvoiceId;
  final String? relatedQuoteId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.paymentNumber,
    required this.direction,
    required this.contactId,
    required this.contactType,
    this.contactName,
    required this.amount,
    required this.method,
    this.accountId,
    this.accountName,
    this.reference,
    required this.paymentDate,
    this.notes,
    this.status = 'paid',
    this.relatedInvoiceId,
    this.relatedQuoteId,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'payment_number': paymentNumber,
        'direction': direction,
        'contact_id': contactId,
        'contact_type': contactType,
        'contact_name': contactName,
        'amount': amount,
        'method': method,
        'account_id': accountId,
        'account_name': accountName,
        'reference': reference,
        'payment_date': paymentDate.toIso8601String(),
        'notes': notes,
        'status': status,
        'related_invoice_id': relatedInvoiceId,
        'related_quote_id': relatedQuoteId,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id']?.toString() ?? '',
        paymentNumber: map['payment_number']?.toString() ?? '',
        direction: map['direction']?.toString() ?? 'encaissement',
        contactId: map['contact_id']?.toString() ?? '',
        contactType: map['contact_type']?.toString() ?? 'customer',
        contactName: map['contact_name']?.toString(),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        method: map['method']?.toString() ?? 'especes',
        accountId: map['account_id']?.toString(),
        accountName: map['account_name']?.toString(),
        reference: map['reference']?.toString(),
        paymentDate: map['payment_date'] != null
            ? (map['payment_date'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['payment_date'] as int)
                : (DateTime.tryParse(map['payment_date'].toString()) ?? DateTime.now()))
            : DateTime.now(),
        notes: map['notes']?.toString(),
        status: map['status']?.toString() ?? 'paid',
        relatedInvoiceId: map['related_invoice_id']?.toString(),
        relatedQuoteId: map['related_quote_id']?.toString(),
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['is_deleted'] == '1',
        createdAt: map['created_at'] != null
            ? (map['created_at'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
                : (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()))
            : DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? (map['updated_at'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
                : (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()))
            : DateTime.now(),
      );

  Payment copyWith({
    String? id,
    String? paymentNumber,
    String? direction,
    String? contactId,
    String? contactType,
    String? contactName,
    double? amount,
    String? method,
    String? accountId,
    String? accountName,
    String? reference,
    DateTime? paymentDate,
    String? notes,
    String? status,
    String? relatedInvoiceId,
    String? relatedQuoteId,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Payment(
        id: id ?? this.id,
        paymentNumber: paymentNumber ?? this.paymentNumber,
        direction: direction ?? this.direction,
        contactId: contactId ?? this.contactId,
        contactType: contactType ?? this.contactType,
        contactName: contactName ?? this.contactName,
        amount: amount ?? this.amount,
        method: method ?? this.method,
        accountId: accountId ?? this.accountId,
        accountName: accountName ?? this.accountName,
        reference: reference ?? this.reference,
        paymentDate: paymentDate ?? this.paymentDate,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        relatedInvoiceId: relatedInvoiceId ?? this.relatedInvoiceId,
        relatedQuoteId: relatedQuoteId ?? this.relatedQuoteId,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class PaymentAllocation {
  final String id;
  final String paymentId;
  final String invoiceId;
  final double allocatedAmount;
  final DateTime createdAt;

  PaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.invoiceId,
    required this.allocatedAmount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'payment_id': paymentId,
        'invoice_id': invoiceId,
        'allocated_amount': allocatedAmount,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory PaymentAllocation.fromMap(Map<String, dynamic> map) =>
      PaymentAllocation(
        id: map['id'] as String,
        paymentId: map['payment_id'] as String,
        invoiceId: map['invoice_id'] as String,
        allocatedAmount: (map['allocated_amount'] as num?)?.toDouble() ?? 0,
        createdAt: map['created_at'] != null
            ? (map['created_at'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
                : DateTime.parse(map['created_at'].toString()))
            : DateTime.now(),
      );
}
