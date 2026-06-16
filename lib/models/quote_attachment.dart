import 'package:flutter/material.dart';

class QuoteAttachment {
  final String id;
  final String quoteId;
  final String fileName;
  final String filePath;
  final int? fileSize;
  final String? fileType;
  final DateTime uploadedAt;
  final String? uploadedBy;

  QuoteAttachment({
    required this.id,
    required this.quoteId,
    required this.fileName,
    required this.filePath,
    this.fileSize,
    this.fileType,
    required this.uploadedAt,
    this.uploadedBy,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'quote_id': quoteId,
        'file_name': fileName,
        'file_path': filePath,
        'file_size': fileSize,
        'file_type': fileType,
        'uploaded_at': uploadedAt.millisecondsSinceEpoch,
        'uploaded_by': uploadedBy,
      };

  factory QuoteAttachment.fromMap(Map<String, dynamic> map) => QuoteAttachment(
        id: map['id'] as String,
        quoteId: map['quote_id'] as String,
        fileName: map['file_name'] as String,
        filePath: map['file_path'] as String,
        fileSize: map['file_size'] as int?,
        fileType: map['file_type'] as String?,
        uploadedAt: DateTime.fromMillisecondsSinceEpoch(map['uploaded_at'] as int),
        uploadedBy: map['uploaded_by'] as String?,
      );
}
