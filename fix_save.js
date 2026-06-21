const fs = require('fs');

let createPath = 'd:/LogiTech/lib/screens/create_supplier_return_screen.dart';
let createContent = fs.readFileSync(createPath, 'utf8');

let newSaveMethod = `  Future<void> _save() async {
    if (_selectedsupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez selectionner un Fournisseur'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final bloc = context.read<SupplierReturnsBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String number = widget.existing?.number ?? '';
    if (number.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextSupplierReturnSequence();
      number = generateDocNumber('BRF', seq);
    }

    final noteId = widget.existing?.id ?? _uuid.v4();
    final note = SupplierReturn(
      id: noteId,
      number: number,
      supplierId: _selectedsupplierId!,
      date: _date,
      status: _status.name,
      reason: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      items: _items.map((item) => SupplierReturnItem(
        id: item.id,
        supplierReturnId: noteId,
        productId: item.productId,
        designation: item.designation,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        totalHT: item.totalHT,
      )).toList(),
      isDeleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_isEditing) {
      bloc.add(UpdateSupplierReturn(note));
    } else {
      bloc.add(AddSupplierReturn(note));
    }

    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing
          ? 'Bon \${note.number} mis a jour'
          : 'Bon \${note.number} cree avec succes'),
      backgroundColor: AppColors.success,
    ));
  }`;

// Find start and end of _save
const startIndex = createContent.indexOf('Future<void> _save() async {');
const endIndex = createContent.indexOf('@override\n  Widget build(BuildContext context) {');

if (startIndex !== -1 && endIndex !== -1) {
    createContent = createContent.substring(0, startIndex) + newSaveMethod + '\n\n  ' + createContent.substring(endIndex);
    fs.writeFileSync(createPath, createContent, 'utf8');
} else {
    console.error('Could not find _save method boundaries');
}
