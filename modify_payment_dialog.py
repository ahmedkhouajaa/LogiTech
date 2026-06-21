import os

file_path = 'd:/LogiTech/lib/widgets/purchase_invoice_payment_dialog.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace imports
content = content.replace("import '../models/invoice.dart';", "import '../models/purchase_invoice.dart';")
content = content.replace("import '../blocs/invoices/invoices_bloc.dart';", "import '../blocs/purchase_invoices/purchase_invoices_bloc.dart';")

# Replace class names and fields
content = content.replace('InvoicePaymentDialog', 'PurchaseInvoicePaymentDialog')
content = content.replace('Invoice invoice', 'PurchaseInvoice purchaseInvoice')
content = content.replace('widget.invoice', 'widget.purchaseInvoice')
content = content.replace('InvoicesBloc', 'PurchaseInvoicesBloc')
content = content.replace('UpdateInvoice', 'UpdatePurchaseInvoice')
content = content.replace('invoiceId: widget.purchaseInvoice.id', 'purchaseInvoiceId: widget.purchaseInvoice.id')

# Replace 'Client' to 'Fournisseur'
content = content.replace('Client:', 'Fournisseur:')
content = content.replace('widget.purchaseInvoice.clientName', 'widget.purchaseInvoice.supplierName')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Modified purchase_invoice_payment_dialog.dart successfully.')
