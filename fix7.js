const fs = require('fs');

const createScreenPath = 'd:/LogiTech/lib/screens/create_supplier_credit_note_screen.dart';
const listScreenPath = 'd:/LogiTech/lib/screens/supplier_credit_notes_screen.dart';

const srcCreate = 'd:/LogiTech/lib/screens/create_supplier_return_screen.dart';
const srcList = 'd:/LogiTech/lib/screens/supplier_returns_screen.dart';

let createContent = fs.readFileSync(srcCreate, 'utf8');
let listContent = fs.readFileSync(srcList, 'utf8');

function replaceAll(str, mapObj) {
    var re = new RegExp(Object.keys(mapObj).join("|"), "gi");
    return str.replace(re, function(matched){
        return mapObj[matched.toLowerCase()] || mapObj[matched] || matched;
    });
}

// 1. Replace in create screen
createContent = createContent
  .replace(/SupplierReturn/g, 'SupplierCreditNote')
  .replace(/supplierReturn/g, 'supplierCreditNote')
  .replace(/SupplierReturns/g, 'SupplierCreditNotes')
  .replace(/supplierReturns/g, 'supplierCreditNotes')
  .replace(/supplier_returns/g, 'supplier_credit_notes')
  .replace(/Bon de retour fournisseur/g, 'Avoir fournisseur')
  .replace(/Bon de retour/g, 'Avoir fournisseur')
  .replace(/BRF/g, 'AVF')
  .replace(/Bon/g, 'Avoir');

// Fix import paths
createContent = createContent.replace(/supplier_return/g, 'supplier_credit_note');

fs.writeFileSync(createScreenPath, createContent, 'utf8');

// 2. Replace in list screen
listContent = listContent
  .replace(/SupplierReturn/g, 'SupplierCreditNote')
  .replace(/supplierReturn/g, 'supplierCreditNote')
  .replace(/SupplierReturns/g, 'SupplierCreditNotes')
  .replace(/supplierReturns/g, 'supplierCreditNotes')
  .replace(/supplier_returns/g, 'supplier_credit_notes')
  .replace(/Retours Fournisseur/g, 'Avoirs Fournisseur')
  .replace(/Gérer vos retours/g, 'Gérer vos avoirs')
  .replace(/Ajouter un retour/g, 'Ajouter un avoir')
  .replace(/Retour fournisseur/g, 'Avoir fournisseur')
  .replace(/Bon de retour/g, 'Avoir fournisseur')
  .replace(/BRF/g, 'AVF')
  .replace(/Bon/g, 'Avoir');

listContent = listContent.replace(/supplier_return/g, 'supplier_credit_note');
listContent = listContent.replace(/create_supplier_credit_note_screen/g, 'create_supplier_credit_note_screen'); // wait it's already replaced

fs.writeFileSync(listScreenPath, listContent, 'utf8');
