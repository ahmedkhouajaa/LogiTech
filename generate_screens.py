import re

def process_file(source_path, target_path, replacements):
    with open(source_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements.items():
        content = content.replace(old, new)
        
    with open(target_path, 'w', encoding='utf-8') as f:
        f.write(content)

# 1. Customer Orders
replacements_order = {
    'MobileDevisDetailScreen': 'MobileCustomerOrderDetailScreen',
    'Quote': 'CustomerOrder',
    'quote': 'order',
    'currentQuote': 'currentOrder',
    'QuotesBloc': 'CustomerOrdersBloc',
    'QuotesState': 'CustomerOrdersState',
    'QuotesLoaded': 'CustomerOrdersLoaded',
    'quotes': 'orders',
    'DeleteQuote': 'DeleteCustomerOrder',
    'UpdateQuoteStatus': 'UpdateCustomerOrderStatus',
    'CreateQuoteScreen': 'CreateCustomerOrderScreen',
    'Devis': 'Commande',
    'devis': 'commande',
    'MobileQuotesScreen': 'MobileCustomerOrdersScreen',
    'MobileDevisDetailScreenState': 'MobileCustomerOrderDetailScreenState',
    'UpdateQuote': 'UpdateCustomerOrder',
}
process_file('lib/mobile/screens/mobile_devis_detail_screen.dart', 'lib/mobile/screens/mobile_customer_order_detail_screen.dart', replacements_order)

# 2. Delivery Notes
replacements_delivery = {
    'MobileDevisDetailScreen': 'MobileDeliveryNoteDetailScreen',
    'Quote': 'DeliveryNote',
    'quote': 'deliveryNote',
    'currentQuote': 'currentDeliveryNote',
    'QuotesBloc': 'DeliveryNotesBloc',
    'QuotesState': 'DeliveryNotesState',
    'QuotesLoaded': 'DeliveryNotesLoaded',
    'quotes': 'deliveryNotes',
    'DeleteQuote': 'DeleteDeliveryNote',
    'UpdateQuoteStatus': 'UpdateDeliveryNoteStatus',
    'CreateQuoteScreen': 'CreateDeliveryNoteScreen',
    'Devis': 'Bon de livraison',
    'devis': 'bon de livraison',
    'MobileQuotesScreen': 'MobileDeliveryNotesScreen',
    'MobileDevisDetailScreenState': 'MobileDeliveryNoteDetailScreenState',
    'UpdateQuote': 'UpdateDeliveryNote',
}
process_file('lib/mobile/screens/mobile_devis_detail_screen.dart', 'lib/mobile/screens/mobile_delivery_note_detail_screen.dart', replacements_delivery)

# 3. Invoices
replacements_invoice = {
    'MobileDevisDetailScreen': 'MobileInvoiceDetailScreen',
    'Quote': 'Invoice',
    'quote': 'invoice',
    'currentQuote': 'currentInvoice',
    'QuotesBloc': 'InvoicesBloc',
    'QuotesState': 'InvoicesState',
    'QuotesLoaded': 'InvoicesLoaded',
    'quotes': 'invoices',
    'DeleteQuote': 'DeleteInvoice',
    'UpdateQuoteStatus': 'UpdateInvoiceStatus',
    'CreateQuoteScreen': 'CreateInvoiceScreen',
    'Devis': 'Facture',
    'devis': 'facture',
    'MobileQuotesScreen': 'MobileInvoicesScreen',
    'MobileDevisDetailScreenState': 'MobileInvoiceDetailScreenState',
    'UpdateQuote': 'UpdateInvoice',
}
process_file('lib/mobile/screens/mobile_devis_detail_screen.dart', 'lib/mobile/screens/mobile_invoice_detail_screen.dart', replacements_invoice)

print("Generated screens successfully!")
