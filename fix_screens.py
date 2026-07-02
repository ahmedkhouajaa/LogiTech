import os

def fix_file(filepath, status_enum, total_ht, validity_date):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return
        
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Fix Status logic
    obj_name = "currentCustomerOrder" if "Order" in filepath else "currentDeliveryNote" if "Delivery" in filepath else "currentInvoice"
    
    # In header:
    status_expr = f"{status_enum}.values.firstWhere((e) => e.name == {obj_name}.status, orElse: () => {status_enum}.draft)"
    
    content = content.replace(f"{obj_name}.status.color", f"{status_expr}.color")
    content = content.replace(f"{obj_name}.status.label", f"{status_expr}.label")
    
    # In dialog
    obj_type = "CustomerOrder" if "Order" in filepath else "DeliveryNote" if "Delivery" in filepath else "Invoice"
    obj_param = "order" if "Order" in filepath else "deliveryNote" if "Delivery" in filepath else "invoice"
    
    content = content.replace(f"DocumentStatus selectedStatus = {obj_param}.status;", f"{status_enum} selectedStatus = {status_enum}.values.firstWhere((e) => e.name == {obj_param}.status, orElse: () => {status_enum}.draft);")
    content = content.replace(f"DropdownButtonFormField<DocumentStatus>", f"DropdownButtonFormField<{status_enum}>")
    content = content.replace(f"DocumentStatus.values.map", f"{status_enum}.values.map")
    
    content = content.replace(f"{obj_param}.status, selectedStatus,", f"{obj_param}.status, selectedStatus.name,")
    
    # 2. Fix totals
    content = content.replace(f"{obj_name}.totalHT", f"{obj_name}.{total_ht}")
    
    # 3. Fix dates
    content = content.replace(f"{obj_name}.validityDate", f"{obj_name}.{validity_date}")
    
    # 4. Remove unnecessary conversions that cause errors
    if obj_type == "CustomerOrder":
        content = content.replace("!currentCustomerOrder.isConverted && ", "")
        content = content.replace("currentCustomerOrder.isConverted && currentCustomerOrder.convertedTo == 'invoice'", "currentCustomerOrder.isConvertedToInvoice")
        content = content.replace("currentCustomerOrder.convertedToId", "currentCustomerOrder.convertedToInvoiceId")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file('lib/mobile/screens/mobile_customer_order_detail_screen.dart', 'CustomerOrderStatus', 'totalHT', 'deliveryDate') # Wait, CustomerOrder has totalHT() getter!
fix_file('lib/mobile/screens/mobile_delivery_note_detail_screen.dart', 'DeliveryNoteStatus', 'totalHT', 'date')
fix_file('lib/mobile/screens/mobile_invoice_detail_screen.dart', 'InvoiceStatus', 'totalHT', 'dueDate')

print("Fixed screens!")
