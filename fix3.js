const fs = require('fs');
const path = require('path');

// Fix bloc
let blocPath = 'd:/LogiTech/lib/blocs/supplier_returns/supplier_returns_bloc.dart';
let blocContent = fs.readFileSync(blocPath, 'utf8');
if (!blocContent.includes('import \'../../models/supplier_return.dart\';') && !blocContent.includes('import \'../../models/supplier_return.dart\'')) {
    blocContent = "import '../../models/supplier_return.dart';\n" + blocContent;
}

blocContent = blocContent.replace(/}\n  Future<void> _onFilterSupplierReturns/g, '  Future<void> _onFilterSupplierReturns');
blocContent = blocContent.replace(/}\n}\n$/g, '}\n');
fs.writeFileSync(blocPath, blocContent, 'utf8');

// Fix create screen
let createPath = 'd:/LogiTech/lib/screens/create_supplier_return_screen.dart';
let createContent = fs.readFileSync(createPath, 'utf8');

createContent = createContent.replace(/reason: _conditionsController\.text,\n\s*reason: _notesController\.text,/g, 'reason: _notesController.text,');
createContent = createContent.replace(/reason: _notesController\.text,\n\s*reason: _conditionsController\.text,/g, 'reason: _notesController.text,');

// add missing properties to SupplierReturn
createContent = createContent.replace(/items: _items,/g, 'items: _items,\n      isDeleted: false,\n      createdAt: DateTime.now(),\n      updatedAt: DateTime.now(),');

fs.writeFileSync(createPath, createContent, 'utf8');
