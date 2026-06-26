import os
import re

files = [
    "supplier_returns_screen.dart",
    "supplier_credit_notes_screen.dart",
    "return_notes_screen.dart",
    "quotes_screen.dart",
    "purchase_invoices_screen.dart",
    "invoices_screen.dart",
    "delivery_notes_screen.dart",
    "customer_orders_screen.dart",
    "receiving_vouchers_screen.dart",
    "supplier_orders_screen.dart"
]

for file_name in files:
    path = os.path.join("d:/LogiTech/lib/screens", file_name)
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the pdf case
    pdf_case_pattern = r"(case 'pdf':\s*final doc = DocumentWrapper\.([a-zA-Z]+)\(([a-zA-Z]+)\);\s*PdfService\.instance\.generateAndOpenDocument\(doc\);\s*break;)"
    match = re.search(r"case 'pdf':\s*final doc = DocumentWrapper\.([a-zA-Z]+)\(([a-zA-Z]+)\);", content)
    
    if match:
        doc_method = match.group(1)
        var_name = match.group(2)
        print_case_code = f"""      case 'print':
        final doc = DocumentWrapper.{doc_method}({var_name});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;"""
        
        # We need to replace the old print case.
        # It looks like:
        # case 'print':
        #   // TODO: Print logic
        #   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impression non implementee')));
        #   break;
        # OR: "Fonctionnalité bientôt disponible"
        
        # Let's just use a regex to match case 'print': up to break;
        old_print_pattern = r"case 'print':.*?break;"
        
        # ensure it matches the dummy one
        if re.search(old_print_pattern, content, flags=re.DOTALL):
             # check if it already has Navigator.push so we don't replace an already fixed one
             current_print_match = re.search(old_print_pattern, content, flags=re.DOTALL)
             if current_print_match and "Navigator.push" not in current_print_match.group(0):
                 content = re.sub(old_print_pattern, print_case_code, content, count=1, flags=re.DOTALL)
             elif not current_print_match:
                 # Should insert before case 'pdf':
                 content = re.sub(pdf_case_pattern, print_case_code + "\n" + r"\1", content)
        else:
             content = re.sub(pdf_case_pattern, print_case_code + "\n" + r"\1", content)
             
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
