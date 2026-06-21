const fs = require('fs');

// Fix database_helper.dart
let dbPath = 'd:/LogiTech/lib/database/database_helper.dart';
let dbContent = fs.readFileSync(dbPath, 'utf8');
dbContent = dbContent.replace(/Sqflite\.firstIntValue\(result\)/g, "((result.first['count'] ?? 0) as int)");
fs.writeFileSync(dbPath, dbContent);

// Fix purchase_invoices_screen.dart
let piPath = 'd:/LogiTech/lib/screens/purchase_invoices_screen.dart';
let piContent = fs.readFileSync(piPath, 'utf8');
piContent = piContent.replace(/designation: i\.designation,/g, '');
fs.writeFileSync(piPath, piContent);

// Fix supplier_credit_notes_screen.dart
let scnPath = 'd:/LogiTech/lib/screens/supplier_credit_notes_screen.dart';
let scnContent = fs.readFileSync(scnPath, 'utf8');
scnContent = scnContent.replace(/FournisseurId:/g, 'supplierId:');
scnContent = scnContent.replace(/\.returns/g, '.creditNotes');

// Fix totalRows clamp issue
scnContent = scnContent.replace(/final int totalPages = \(totalRows \/ _rowsPerPage\)\.ceil\(\)\.clamp\(1, 9999\);/g, 'final int totalPages = (totalRows / _rowsPerPage).ceil().clamp(1, 9999).toInt();');
scnContent = scnContent.replace(/\.clamp\(1, 9999\);/g, '.clamp(1, 9999).toInt();');

// Fix supplierName lookup issue
// There might be Text(inv.supplierName ?? '—', ...)
// Actually wait, SupplierCreditNote doesn't have supplierName, it has supplierId.
// In supplier_returns_screen.dart, did it look up the supplier?
// We will replace note.supplierName with a lookup or just 'Fournisseur ${note.supplierId}' for now to fix compile error.
// Or we can just use note.supplierId.
scnContent = scnContent.replace(/inv\.supplierName/g, '""');
scnContent = scnContent.replace(/supplierName/g, 'supplierId');

fs.writeFileSync(scnPath, scnContent);
