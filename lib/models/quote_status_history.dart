import 'package:flutter/material.dart';

class QuoteStatusHistory {
  final String id;
  final String quoteId;
  final String? oldStatus;
  final String newStatus;
  final String changedBy;
  final String? notes;
  final DateTime changedAt;

  QuoteStatusHistory({
    required this.id,
    required this.quoteId,
    this.oldStatus,
    required this.newStatus,
    required this.changedBy,
    this.notes,
    required this.changedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'quote_id': quoteId,
        'old_status': oldStatus,
        'new_status': newStatus,
        'changed_by': changedBy,
        'notes': notes,
        'changed_at': changedAt.millisecondsSinceEpoch,
      };

  factory QuoteStatusHistory.fromMap(Map<String, dynamic> map) => QuoteStatusHistory(
        id: map['id'] as String,
        quoteId: map['quote_id'] as String,
        oldStatus: map['old_status'] as String?,
        newStatus: map['new_status'] as String,
        changedBy: map['changed_by'] as String,
        notes: map['notes'] as String?,
        changedAt: DateTime.fromMillisecondsSinceEpoch(map['changed_at'] as int),
      );
}
