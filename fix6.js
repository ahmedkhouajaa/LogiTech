const fs = require('fs');

let createPath = 'd:/LogiTech/lib/screens/create_supplier_return_screen.dart';
let createContent = fs.readFileSync(createPath, 'utf8');

const lines = createContent.split('\n');

let startOfSave = -1;
let endOfBuildTopBar = -1;

for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('Future<void> _save() async {')) {
    startOfSave = i;
  }
  if (lines[i].includes('Widget _buildTopBar() {')) {
    endOfBuildTopBar = i;
    break;
  }
}

if (startOfSave !== -1 && endOfBuildTopBar !== -1) {
    let before = lines.slice(0, startOfSave).join('\n');
    let after = lines.slice(endOfBuildTopBar).join('\n');
    let replacement = `  Future<void> _save() async {
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

    final noteId = widget.existing?.id ?? const Uuid().v4();
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
          ? 'Bon \${note.number} mis à jour'
          : 'Bon \${note.number} créé avec succès'),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildArticlesSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildArticleActions(),
                    const SizedBox(height: AppSpacing.md),
                    _buildGlobalDiscountSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTotalsSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildNotesSection(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

`;

    fs.writeFileSync(createPath, before + '\n' + replacement + after, 'utf8');
    console.log("Success");
} else {
    console.log("Could not find bounds", startOfSave, endOfBuildTopBar);
}
