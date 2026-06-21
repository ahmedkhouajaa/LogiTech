import os
import re

file_path = 'd:/LogiTech/lib/screens/purchase_invoices_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'purchase_invoice_payment_dialog.dart' not in content:
    content = content.replace("import 'create_invoice_screen.dart';", "import 'create_invoice_screen.dart';\nimport '../widgets/purchase_invoice_payment_dialog.dart';")

content = re.sub(r'// child: PurchaseInvoicePaymentDialog\(purchaseInvoice: inv\),\s*child: const SizedBox\(\),', 'child: PurchaseInvoicePaymentDialog(purchaseInvoice: inv),', content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
