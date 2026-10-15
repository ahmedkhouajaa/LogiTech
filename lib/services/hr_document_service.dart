import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/hr_document.dart';
import '../utils/file_download_helper.dart';
import '../widgets/hr_document_preview_dialog.dart';

class HrDocumentService {
  static final HrDocumentService instance = HrDocumentService._();
  HrDocumentService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> _collection() {
    return _firestore.collection('hr_documents');
  }

  /// Get Stream of documents for active enterprise
  Stream<List<HrDocument>> getDocumentsStream(String enterpriseId) {
    if (enterpriseId.isEmpty) {
      return Stream.value([]);
    }

    return _collection()
        .where('enterpriseId', isEqualTo: enterpriseId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return HrDocument.fromMap(doc.data(), docId: doc.id);
      }).toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Seed initial demo documents if the enterprise has none yet (matching user's sample)
  Future<void> seedInitialDemoDocumentsIfEmpty(String enterpriseId) async {
    if (enterpriseId.isEmpty) return;
    try {
      final existing = await _collection()
          .where('enterpriseId', isEqualTo: enterpriseId)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        final now = DateTime(2026, 10, 4);

        final sample1 = HrDocument(
          id: _uuid.v4(),
          enterpriseId: enterpriseId,
          title: 'red',
          type: 'Déclaration',
          fileName: 'Accompagnement-pour-la-signature-et-la-facturation-electronique.pdf',
          fileSize: 1024 * 512, // 512 KB
          fileExtension: 'pdf',
          createdAt: now,
          sharedWith: 'Privé',
          notes: 'Guide d\'accompagnement officiel',
        );

        final sample2 = HrDocument(
          id: _uuid.v4(),
          enterpriseId: enterpriseId,
          title: 'Identité CZE czec',
          type: 'Pièce d\'identité',
          fileName: 'Capture d\'écran 2026-09-10 215754.png',
          fileSize: 1024 * 240, // 240 KB
          fileExtension: 'png',
          createdAt: now,
          sharedWith: 'czec CZE',
          notes: 'Copie CIN collaborateur',
        );

        await _collection().doc(sample1.id).set(sample1.toMap());
        await _collection().doc(sample2.id).set(sample2.toMap());
      }
    } catch (e) {
      debugPrint('[HrDocumentService] seedInitialDemoDocumentsIfEmpty error: $e');
    }
  }

  /// Add a new document
  Future<void> addDocument(HrDocument document) async {
    final docRef = _collection().doc(document.id.isEmpty ? _uuid.v4() : document.id);
    final toSave = document.id.isEmpty ? document.copyWith(id: docRef.id) : document;
    await docRef.set(toSave.toMap());
  }

  /// Delete document
  Future<void> deleteDocument(String documentId) async {
    if (documentId.isEmpty) return;
    await _collection().doc(documentId).delete();
  }

  /// Download or open document
  Future<void> downloadDocument(BuildContext context, HrDocument document) async {
    try {
      Uint8List bytes;
      if (document.fileBase64 != null && document.fileBase64!.isNotEmpty) {
        String cleanBase64 = document.fileBase64!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        bytes = base64Decode(cleanBase64);
      } else {
        // Fallback placeholder bytes if raw binary wasn't uploaded (demo seed)
        final fallbackContent = 'LogiTech Document: ${document.title}\n'
            'Type: ${document.type}\n'
            'Fichier: ${document.fileName}\n'
            'Créé le: ${document.createdAt}\n'
            'Partagé avec: ${document.sharedWith}\n';
        bytes = Uint8List.fromList(utf8.encode(fallbackContent));
      }

      await FileDownloadHelper.saveAndOpenFile(
        bytes,
        document.fileName,
        context: context,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "${document.fileName}" téléchargé avec succès.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Preview document in dialog (matching Images 3 and 4)
  Future<void> previewDocument(BuildContext context, HrDocument document) async {
    await HrDocumentPreviewDialog.show(context, document);
  }
}
