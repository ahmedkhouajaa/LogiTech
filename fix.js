const fs = require('fs');
const path = require('path');

const screensDir = 'd:/LogiTech/lib/screens';
const screens = ['supplier_returns_screen.dart', 'create_supplier_return_screen.dart'];

for (const screen of screens) {
    let p = path.join(screensDir, screen);
    let content = fs.readFileSync(p, 'utf8');

    // Fix enum
    if (content.includes('class SupplierReturnsScreen')) {
        if (!content.includes('enum SupplierReturnStatus')) {
            content = content.replace('class SupplierReturnsScreen', 
            `enum SupplierReturnStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Validé', AppColors.success),
  canceled('Annulé', AppColors.error);

  final String label;
  final Color color;
  const SupplierReturnStatus(this.label, this.color);
}

class SupplierReturnsScreen`);
        }
    }
    
    if (content.includes('class CreateSupplierReturnScreen')) {
        if (!content.includes('enum SupplierReturnStatus')) {
            content = content.replace('class CreateSupplierReturnScreen', 
            `enum SupplierReturnStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Validé', AppColors.success),
  canceled('Annulé', AppColors.error);

  final String label;
  final Color color;
  const SupplierReturnStatus(this.label, this.color);
}

class CreateSupplierReturnScreen`);
        }
    }

    content = content.replace(/SupplierReturnStatus/g, 'SupplierReturnStatus');
    content = content.replace(/FilterSupplierReturns/g, '_filterSupplierReturns');
    content = content.replace(/\.Suppliers/g, '.suppliers');
    content = content.replace(/\.companyName/g, '.name');
    content = content.replace(/\.responsibleName/g, '.name');
    content = content.replace(/\.SupplierCompany/g, '.supplierName');
    content = content.replace(/\.SupplierName/g, '.supplierName');
    content = content.replace(/\.returnNumber/g, '.number');
    content = content.replace(/\.dateEmission/g, '.date');
    content = content.replace(/\.notes/g, '.reason');
    content = content.replace(/\.SupplierId/g, '.supplierId');
    content = content.replace(/SupplierReturnId/g, 'supplierReturnId');
    content = content.replace(/\.conditions/g, '.reason');
    content = content.replace(/SupplierReturnStatus _statusFilter/g, 'SupplierReturnStatus? _statusFilter');

    fs.writeFileSync(p, content, 'utf8');
}
