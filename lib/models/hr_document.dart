import 'package:cloud_firestore/cloud_firestore.dart';

class HrDocument {
  final String id;
  final String enterpriseId;
  final String title;
  final String type; // Déclaration, Pièce d'identité, Attestation, Autre, Document RH, Contrat de travail
  final String fileName;
  final int fileSize; // in bytes
  final String fileExtension;
  final String? fileBase64;
  final String? fileUrl;
  final DateTime createdAt;
  final String sharedWith; // e.g., 'Privé', 'Tout le personnel', or Employee Name
  final String? employeeId;
  final String? createdBy;
  final String? notes;

  const HrDocument({
    required this.id,
    required this.enterpriseId,
    required this.title,
    required this.type,
    required this.fileName,
    this.fileSize = 0,
    this.fileExtension = '',
    this.fileBase64,
    this.fileUrl,
    required this.createdAt,
    this.sharedWith = 'Privé',
    this.employeeId,
    this.createdBy,
    this.notes,
  });

  String get formattedFileSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize o';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'title': title,
      'type': type,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileExtension': fileExtension,
      'fileBase64': fileBase64,
      'fileUrl': fileUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'sharedWith': sharedWith,
      'employeeId': employeeId,
      'createdBy': createdBy,
      'notes': notes,
    };
  }

  factory HrDocument.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parsedDate;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return HrDocument(
      id: docId ?? map['id']?.toString() ?? '',
      enterpriseId: map['enterpriseId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      type: map['type']?.toString() ?? 'Autre',
      fileName: map['fileName']?.toString() ?? '',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
      fileExtension: map['fileExtension']?.toString() ?? '',
      fileBase64: map['fileBase64']?.toString(),
      fileUrl: map['fileUrl']?.toString(),
      createdAt: parsedDate,
      sharedWith: map['sharedWith']?.toString() ?? 'Privé',
      employeeId: map['employeeId']?.toString(),
      createdBy: map['createdBy']?.toString(),
      notes: map['notes']?.toString(),
    );
  }

  HrDocument copyWith({
    String? id,
    String? enterpriseId,
    String? title,
    String? type,
    String? fileName,
    int? fileSize,
    String? fileExtension,
    String? fileBase64,
    String? fileUrl,
    DateTime? createdAt,
    String? sharedWith,
    String? employeeId,
    String? createdBy,
    String? notes,
  }) {
    return HrDocument(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      title: title ?? this.title,
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileExtension: fileExtension ?? this.fileExtension,
      fileBase64: fileBase64 ?? this.fileBase64,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      sharedWith: sharedWith ?? this.sharedWith,
      employeeId: employeeId ?? this.employeeId,
      createdBy: createdBy ?? this.createdBy,
      notes: notes ?? this.notes,
    );
  }
}
