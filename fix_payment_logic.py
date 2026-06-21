import os

file_path = 'd:/LogiTech/lib/widgets/purchase_invoice_payment_dialog.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'encaissement'", "'decaissement'")
content = content.replace("'customer'", "'supplier'")
content = content.replace("'income'", "'expense'")
content = content.replace("'Paiement Client'", "'Paiement Fournisseur'")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed Payment direction and type for purchase invoices')
