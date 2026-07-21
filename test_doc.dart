import 'lib/models/supplier_credit_note.dart';
import 'lib/models/document_wrapper.dart';

void main() {
  try {
    final note = SupplierCreditNote(
      id: '1',
      number: '123',
      supplierId: 'sup1',
      date: DateTime.now(),
      status: 'draft',
      items: [
        SupplierCreditNoteItem(
          id: 'i1',
          supplierCreditNoteId: '1',
          productId: 'p1',
          quantity: 1,
          unitPrice: 10,
          tvaRate: 19,
        )
      ]
    );

    final doc = DocumentWrapper.fromSupplierCreditNote(note);
    print('SUCCESS: \${doc.documentTitle}');
  } catch (e, stack) {
    print('ERROR: \$e');
    print(stack);
  }
}
