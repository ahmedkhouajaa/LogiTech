# -*- coding: utf-8 -*-

with open('lib/screens/stock_withdrawals_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Core Renames
content = content.replace('StockWithdrawal', 'StockTransfer')
content = content.replace('StockWithdrawalsBloc', 'StockTransfersBloc')
content = content.replace('StockWithdrawalsState', 'StockTransfersState')
content = content.replace('StockWithdrawalsLoaded', 'StockTransfersLoaded')
content = content.replace('StockWithdrawalsError', 'StockTransfersError')
content = content.replace('StockWithdrawalsLoading', 'StockTransfersLoading')
content = content.replace("Bon de prélèvement", "Bon de transfert")
content = content.replace("Bons de prélèvement", "Bons de transfert")
content = content.replace("Aucun Bon de prélèvement trouvé", "Aucun Bon de transfert trouvé")
content = content.replace("Bons de sortie", "Bons de transfert")
content = content.replace("Aucun Bon de sortie", "Aucun Bon de transfert")
content = content.replace("widget.isExitVoucher ? 'Bons de transfert' : 'Bons de transfert'", "'Bons de transfert'")
content = content.replace("widget.isExitVoucher ? 'Aucun Bon de transfert' : 'Aucun Bon de transfert'", "'Aucun Bon de transfert'")
content = content.replace("state.withdrawals", "state.transfers")

# Fix _navigate
# We need to use CreateStockTransferScreen directly without isMobile
# since there is no MobileTransferFormScreen
nav_start = content.find("  void _navigate(BuildContext context")
nav_end = content.find("  // ─── Mobile Layout ─────────────────────────────────────────────────")
new_nav = '''  void _navigate(BuildContext context, [StockTransfer? entry]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateStockTransferScreen(existing: entry),
      ),
    );
  }

  void _confirmDelete(StockTransfer transfer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce bon de transfert ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              context.read<StockTransfersBloc>().add(DeleteStockTransfer(transfer.id));
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

'''
content = content[:nav_start] + new_nav + content[nav_end:]

# Add import for create screen
content = content.replace(
    "import 'create_stock_withdrawal_screen.dart';", 
    "import 'create_stock_transfer_screen.dart';"
)

content = content.replace(
    "import '../mobile/screens/forms/mobile_exit_voucher_form_screen.dart';", 
    ""
)

# Fix filterWarehouse logic
old_warehouse = "e.warehouseId == _filterWarehouseId || (e.warehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault))"
new_warehouse = "e.sourceWarehouseId == _filterWarehouseId || e.destinationWarehouseId == _filterWarehouseId || (e.sourceWarehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault))"
content = content.replace(old_warehouse, new_warehouse)

# Fix _buildMobileCard
card_start = content.find("  Widget _buildMobileCard(BuildContext context, StockTransfer entry) {")
card_end = content.find("  Widget _buildInfoItem(IconData icon, String text) {")
new_card = '''  Widget _buildMobileCard(BuildContext context, StockTransfer entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _navigate(context, entry),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(
                      children: [
                        _buildStatusChip(entry.status),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmDelete(entry),
                          child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(Icons.date_range_rounded, formatDateTime(entry.date)),
                    ),
                    _buildInfoItem(Icons.shopping_bag_rounded, ' article'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(Icons.outbox_rounded, 'Source: ' + _getWarehouseName(entry.sourceWarehouseId)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(Icons.move_to_inbox_rounded, 'Dest: ' + _getWarehouseName(entry.destinationWarehouseId)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

'''
content = content[:card_start] + new_card + content[card_end:]


# Fix _buildDesktopLayout Headers
old_header_1 = "child: Text('Entrepôt'"
new_header_1 = "child: Text('Source'"
content = content.replace(old_header_1, new_header_1)

old_header_2 = "child: Text('Bénéficiaire'"
old_header_2_alt = "child: Text('Client/Admin'"
new_header_2 = "child: Text('Destination'"
content = content.replace(old_header_2, new_header_2).replace(old_header_2_alt, new_header_2)

# Fix _buildRow
row_start = content.find("  Widget _buildRow(BuildContext context, StockTransfer entry, int index) {")
new_row = '''  Widget _buildRow(BuildContext context, StockTransfer entry, int index) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(entry.number, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(formatDateTimeLong(entry.date), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(_getWarehouseName(entry.sourceWarehouseId), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(_getWarehouseName(entry.destinationWarehouseId), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 1,
            child: Text('', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusChip(entry.status),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                  onPressed: () => _navigate(context, entry),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  onPressed: () => _confirmDelete(entry),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
'''
content = content[:row_start] + new_row

# Fix unused _pageButton warning
content = content.replace("  Widget _pageButton(int page) {", "  // Widget _pageButton(int page) {")

with open('lib/screens/stock_transfers_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Generated successfully")
