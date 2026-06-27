import os
import re

file_path = "d:/LogiTech/lib/mobile/mobile_shell_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add imports for the new mobile screens
new_imports = """
import 'screens/mobile_quotes_screen.dart';
import 'screens/mobile_customer_orders_screen.dart';
import 'screens/mobile_delivery_notes_screen.dart';
import 'screens/mobile_invoices_screen.dart';
import 'screens/mobile_stock_withdrawals_screen.dart';
import 'screens/mobile_credit_notes_screen.dart';
import 'screens/mobile_return_notes_screen.dart';
import 'screens/mobile_supplier_orders_screen.dart';
import 'screens/mobile_receiving_vouchers_screen.dart';
import 'screens/mobile_purchase_invoices_screen.dart';
import 'screens/mobile_supplier_credit_notes_screen.dart';
import 'screens/mobile_supplier_returns_screen.dart';
import 'screens/mobile_payments_screen.dart';
import 'screens/mobile_transactions_screen.dart';
import 'screens/mobile_checks_traites_screen.dart';
import 'screens/mobile_customers_screen.dart';
import 'screens/mobile_suppliers_screen.dart';
import 'screens/mobile_products_screen.dart';
import 'screens/mobile_stock_screen.dart';
import 'screens/mobile_projects_screen.dart';
import 'screens/mobile_withholding_tax_screen.dart';
"""

# Insert new imports after 'import 'mobile_dashboard_screen.dart';'
content = content.replace("import 'mobile_dashboard_screen.dart';", "import 'mobile_dashboard_screen.dart';\n" + new_imports)

# 2. Replace the switch cases in _buildContent()
replacements = {
    "return const CustomersScreen();": "return const MobileCustomersScreen();",
    "return const SuppliersScreen();": "return const MobileSuppliersScreen();",
    "return const ProductsScreen();": "return const MobileProductsScreen();",
    "return const InvoicesScreen();": "return const MobileInvoicesScreen();",
    "return const CustomerOrdersScreen();": "return const MobileCustomerOrdersScreen();",
    "return const QuotesScreen();": "return const MobileQuotesScreen();",
    "return const DeliveryNotesScreen();": "return const MobileDeliveryNotesScreen();",
    "return const StockScreen();": "return const MobileStockScreen();",
    "return const TreasuryTransactionsScreen();": "return const MobileTreasuryTransactionsScreen();",
    "return const ChecksTraitesScreen();": "return const MobileChecksTraitesScreen();",
    "return const ProjectsScreen();": "return const MobileProjectsScreen();",
    "return const PaymentsScreen();": "return const MobilePaymentsScreen();",
    "return const PurchaseInvoicesScreen();": "return const MobilePurchaseInvoicesScreen();",
    "return const SupplierOrdersScreen();": "return const MobileSupplierOrdersScreen();",
    "return const ReceivingVouchersScreen();": "return const MobileReceivingVouchersScreen();",
    "return WithholdingTaxScreen(isSales: _activeModule == AppModule.withholdingTaxSales);": "return MobileWithholdingTaxScreen(isSales: _activeModule == AppModule.withholdingTaxSales);",
    "return const StockWithdrawalsScreen();": "return const MobileStockWithdrawalsScreen();",
    "return const ReturnNotesScreen();": "return const MobileReturnNotesScreen();",
    "return const CreditNotesScreen();": "return const MobileCreditNotesScreen();",
    "return const SupplierReturnsScreen();": "return const MobileSupplierReturnsScreen();",
    "return const SupplierCreditNotesScreen();": "return const MobileSupplierCreditNotesScreen();",
}

for old, new in replacements.items():
    content = content.replace(old, new)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated mobile_shell_screen.dart successfully.")
