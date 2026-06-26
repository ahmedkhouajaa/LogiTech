import os
import re

files = [
    "supplier_returns_screen.dart",
    "supplier_orders_screen.dart",
    "supplier_credit_notes_screen.dart",
    "return_notes_screen.dart",
    "receiving_vouchers_screen.dart",
    "purchase_invoices_screen.dart",
    "invoices_screen.dart",
    "delivery_notes_screen.dart",
    "customer_orders_screen.dart"
]

for file_name in files:
    path = os.path.join("d:/LogiTech/lib/screens", file_name)
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Add import 'document_preview_screen.dart'; if not present
    if "document_preview_screen.dart" not in content:
        content = re.sub(
            r"(import '\.\./models/document_wrapper\.dart';)",
            r"\1\nimport 'document_preview_screen.dart';",
            content
        )

    # 2. Add print menu item
    pdf_menu_pattern = r"(_buildMenuItem\('pdf',\s*Icons\.picture_as_pdf_outlined,\s*AppColors\.error,\s*'Telecharger PDF'\),)"
    if "_buildMenuItem('print'" not in content:
        content = re.sub(
            pdf_menu_pattern,
            r"_buildMenuItem('print', Icons.print_outlined, AppColors.primary, 'Imprimer'),\n                                                  const PopupMenuDivider(height: 1),\n                                                  \1",
            content
        )

    # 3. Add print case
    pdf_case_pattern = r"(case 'pdf':\s*final doc = DocumentWrapper\.([a-zA-Z]+)\(([a-zA-Z]+)\);\s*PdfService\.instance\.generateAndOpenDocument\(doc\);\s*break;)"
    
    if "case 'print':" not in content:
        match = re.search(r"case 'pdf':\s*final doc = DocumentWrapper\.([a-zA-Z]+)\(([a-zA-Z]+)\);", content)
        if match:
            doc_method = match.group(1)
            var_name = match.group(2)
            print_case = f"""      case 'print':
        final doc = DocumentWrapper.{doc_method}({var_name});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;\n"""
            content = re.sub(
                pdf_case_pattern,
                print_case + r"\1",
                content
            )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
