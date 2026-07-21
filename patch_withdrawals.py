# -*- coding: utf-8 -*-

with open('lib/screens/stock_entries_screen.dart', 'r', encoding='utf-8') as f:
    entries = f.read()

with open('lib/screens/stock_withdrawals_screen.dart', 'r', encoding='utf-8') as f:
    withdr = f.read()

def rename(code):
    code = code.replace('StockEntry', 'StockWithdrawal')
    code = code.replace('StockEntriesBloc', 'StockWithdrawalsBloc')
    code = code.replace('StockEntriesState', 'StockWithdrawalsState')
    code = code.replace('StockEntriesLoaded', 'StockWithdrawalsLoaded')
    code = code.replace('StockEntriesError', 'StockWithdrawalsError')
    code = code.replace('StockEntriesLoading', 'StockWithdrawalsLoading')
    code = code.replace("Bon d\'entrée", "Bon de prélèvement")
    code = code.replace("Bons d\'entrée", "Bons de prélèvement")
    code = code.replace("Aucun Bon de prélèvement trouvé", "Aucun Bon de prélèvement")
    code = code.replace("state.filteredEntries", "state.withdrawals")
    return code

# Extract desktop layout from entries
e_d_start = entries.find("  Widget _buildDesktopLayout(BuildContext context, StockEntriesState state, List<StockEntry> entries) {")
e_d_end = entries.find("  Widget _buildRow(BuildContext context, StockEntry entry, int index) {")
e_desktop_code = entries[e_d_start:e_d_end]

e_desktop_code = rename(e_desktop_code)
e_desktop_code = e_desktop_code.replace("'Bons de prélèvement'", "widget.isExitVoucher ? 'Bons de sortie' : 'Bons de prélèvement'")
e_desktop_code = e_desktop_code.replace("'Aucun Bon de prélèvement'", "widget.isExitVoucher ? 'Aucun Bon de sortie' : 'Aucun Bon de prélèvement'")

# Replace desktop layout in withdr
w_d_start = withdr.find("  Widget _buildDesktopLayout(BuildContext context) {")
w_d_end = withdr.find("  Widget _buildRow(BuildContext context, StockWithdrawal entry, int index) {")
withdr = withdr[:w_d_start] + e_desktop_code + withdr[w_d_end:]

# Also fix filteredEntries in build
withdr = withdr.replace("state.filteredEntries", "state.withdrawals")

with open('lib/screens/stock_withdrawals_screen.dart', 'w', encoding='utf-8') as f:
    f.write(withdr)

print("Desktop patch applied successfully.")
