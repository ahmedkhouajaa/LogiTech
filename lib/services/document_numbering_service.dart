import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../widgets/document_number_config_dialog.dart';

class DocumentNumberingService {
  static Future<int?> ensureNumberSequence({
    required BuildContext context,
    required String docCollection,
    required String docTypeName,
    required String prefix,
  }) async {
    final isFirst = await DatabaseHelper.instance.isFirstDocumentOfType(docCollection);

    if (!isFirst) {
      return await DatabaseHelper.instance.generateNextDocSequenceAtomic(
        DatabaseHelper.instance.currentEnterpriseId,
        docCollection,
      );
    }

    final chosenNumber = await DocumentNumberConfigDialog.show(
      context: context,
      docTypeName: docTypeName,
      prefix: prefix,
    );

    if (chosenNumber == null) return null;

    await DatabaseHelper.instance.setInitialDocSequenceAtomic(
      DatabaseHelper.instance.currentEnterpriseId,
      docCollection,
      chosenNumber,
    );

    return chosenNumber;
  }
}
