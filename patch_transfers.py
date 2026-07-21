# -*- coding: utf-8 -*-
import re

with open('lib/screens/stock_withdrawals_screen.dart', 'r', encoding='utf-8') as f:
    src_content = f.read()

with open('lib/screens/stock_transfers_screen.dart', 'r', encoding='utf-8') as f:
    dst_content = f.read()

# Replace Imports
imports_chunk = '''
import '../database/database_helper.dart';
import '../widgets/custom_date_range_picker.dart';
import '../blocs/products/products_bloc.dart';
'''
if 'DatabaseHelper' not in dst_content:
    dst_content = dst_content.replace("import '../models/stock_transfer.dart';", "import '../models/stock_transfer.dart';\n" + imports_chunk)

# Extract State Vars
s_state_start = src_content.find("  int _rowsPerPage = 20;")
s_state_end = src_content.find("  @override\n  void initState() {")
s_state_vars = src_content[s_state_start:s_state_end]

d_state_start = dst_content.find("  int _rowsPerPage = 10;")
if d_state_start == -1: d_state_start = dst_content.find("  int _rowsPerPage")
d_state_end = dst_content.find("  @override\n  void initState() {")
dst_content = dst_content[:d_state_start] + s_state_vars + dst_content[d_state_end:]

# Extract InitState and helpers
s_init_start = src_content.find("    super.initState();")
s_init_end = src_content.find("  void _navigate(BuildContext context")
s_init_code = src_content[s_init_start:s_init_end].replace('StockWithdrawals', 'StockTransfers')

d_init_start = dst_content.find("    super.initState();")
d_init_end = dst_content.find("  void _navigate(BuildContext context")
dst_content = dst_content[:d_init_start] + s_init_code + dst_content[d_init_end:]

# Replace _navigate signature in dst_content to handle Mobile
d_nav_start = dst_content.find("  void _navigate(BuildContext context")
d_nav_end = dst_content.find("  void _confirmDelete")
d_nav_code = '''  void _navigate(BuildContext context, [StockTransfer? entry]) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isMobile 
            ? CreateStockTransferScreen(existing: entry) // Wait, is there a mobile transfer form? We will use CreateStockTransferScreen for now.
            : CreateStockTransferScreen(existing: entry),
      ),
    );
  }

'''
dst_content = dst_content[:d_nav_start] + d_nav_code + dst_content[d_nav_end:]


# Extract build, mobile layout, desktop layout
s_build_start = src_content.find("  @override\n  Widget build(BuildContext context) {")
s_build_end = src_content.find("  Widget _buildMobileCard")
s_build_code = src_content[s_build_start:s_build_end]

s_d_start = src_content.find("  Widget _buildDesktopLayout(BuildContext context) {")
s_d_end = src_content.find("  Widget _buildRow(BuildContext context, StockWithdrawal entry, int index) {")
s_desktop_code = src_content[s_d_start:s_d_end]

# Rename everything
def rename(code):
    code = code.replace('StockWithdrawal', 'StockTransfer')
    code = code.replace('StockWithdrawalsBloc', 'StockTransfersBloc')
    code = code.replace('StockWithdrawalsState', 'StockTransfersState')
    code = code.replace('StockWithdrawalsLoaded', 'StockTransfersLoaded')
    code = code.replace('StockWithdrawalsError', 'StockTransfersError')
    code = code.replace('StockWithdrawalsLoading', 'StockTransfersLoading')
    code = code.replace("Bon de prélèvement", "Bon de transfert")
    code = code.replace("Bons de prélèvement", "Bons de transfert")
    code = code.replace("Aucun Bon de prélèvement", "Aucun Bon de transfert")
    code = code.replace("Bons de sortie", "Bons de transfert")
    code = code.replace("Aucun Bon de sortie", "Aucun Bon de transfert")
    code = code.replace("widget.isExitVoucher ? 'Bons de transfert' : 'Bons de transfert'", "'Bons de transfert'")
    code = code.replace("widget.isExitVoucher ? 'Aucun Bon de transfert' : 'Aucun Bon de transfert'", "'Aucun Bon de transfert'")
    code = code.replace("state.withdrawals", "state.transfers")
    
    # Custom matchesWarehouse
    old_warehouse = "e.warehouseId == _filterWarehouseId || (e.warehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault))"
    new_warehouse = "e.sourceWarehouseId == _filterWarehouseId || e.destinationWarehouseId == _filterWarehouseId || (e.sourceWarehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault))"
    code = code.replace(old_warehouse, new_warehouse)
    return code

s_build_code = rename(s_build_code)
s_desktop_code = rename(s_desktop_code)

# Apply
d_build_start = dst_content.find("  @override\n  Widget build(BuildContext context) {")
d_build_end = dst_content.find("  Widget _buildMobileCard")
if d_build_end == -1: 
    print("Warning: _buildMobileCard not found in dst")

d_d_start = dst_content.find("  Widget _buildDesktopLayout(BuildContext context) {")
if d_d_start == -1:
    # It might not exist in transfers yet
    d_d_start = dst_content.find("  Widget _buildRow(BuildContext context,")
    dst_content = dst_content[:d_build_start] + s_build_code + "  Widget _buildMobileCard(BuildContext context, StockTransfer entry) { return const SizedBox(); }\n\n" + s_desktop_code + dst_content[d_d_start:]
else:
    # First apply desktop
    d_d_end = dst_content.find("  Widget _buildRow(BuildContext context,")
    dst_content = dst_content[:d_d_start] + s_desktop_code + dst_content[d_d_end:]
    
    # Then apply mobile
    d_build_start = dst_content.find("  @override\n  Widget build(BuildContext context) {")
    d_build_end = dst_content.find("  Widget _buildMobileCard")
    dst_content = dst_content[:d_build_start] + s_build_code + dst_content[d_build_end:]

with open('lib/screens/stock_transfers_screen.dart', 'w', encoding='utf-8') as f:
    f.write(dst_content)

print("Patch applied successfully.")
