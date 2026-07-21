import codecs
import re

with codecs.open('lib/screens/stock_transfers_screen.dart', 'r', 'utf-8') as f:
    text = f.read()

# Models and Types
text = text.replace('StockWithdrawal', 'StockTransfer')
text = text.replace('stock_withdrawals_bloc', 'stock_transfers_bloc')
text = text.replace('stock_withdrawal', 'stock_transfer')
text = text.replace('withdrawals', 'transfers')

# Text strings
text = text.replace("Bon de prélèvement", "Bon de transfert")
text = text.replace("Bons de prélèvement", "Bons de transfert")
text = text.replace("Aucun Bon de prélèvement trouvé", "Aucun Bon de transfert trouvé")
text = text.replace("Bons de sortie", "Bons de transfert")
text = text.replace("Aucun Bon de sortie", "Aucun Bon de transfert")
text = text.replace("widget.isExitVoucher ? 'Bons de transfert' : 'Bons de transfert'", "'Bons de transfert'")
text = text.replace("widget.isExitVoucher ? 'Aucun Bon de transfert' : 'Aucun Bon de transfert'", "'Aucun Bon de transfert'")

# Update imports
text = text.replace("import '../mobile/screens/forms/mobile_exit_voucher_form_screen.dart';", "")

# Fix _navigate
text = re.sub(r'  void _navigate\(BuildContext context, \[StockTransfer\? entry\]\) \{[\s\S]*?    \);[\s\n]*  \}', 
'''  void _navigate(BuildContext context, [StockTransfer? entry]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateStockTransferScreen(existing: entry),
      ),
    );
  }''', text)

# Fix matchesWarehouse
text = text.replace(
    "e.warehouseId == _filterWarehouseId || (e.warehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault))",
    "e.sourceWarehouseId == _filterWarehouseId || e.destinationWarehouseId == _filterWarehouseId || (e.sourceWarehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault))"
)

# Fix Mobile Layout Warehouse Row
text = re.sub(
    r'_buildInfoItem\(Icons\.warehouse_rounded, _getWarehouseName\(entry\.sourceWarehouseId\)\),',
    r'_buildInfoItem(Icons.outbox_rounded, "Source: " + _getWarehouseName(entry.sourceWarehouseId)),\n                    ),\n                  ],\n                ),\n                const SizedBox(height: 8),\n                Row(\n                  children: [\n                    Expanded(\n                      child: _buildInfoItem(Icons.move_to_inbox_rounded, "Dest: " + _getWarehouseName(entry.destinationWarehouseId)),',
    text
)

# Fix Desktop Header
text = text.replace("Text('Entrepôt'", "Text('Source'")
text = text.replace("Text('Bénéficiaire'", "Text('Destination'")
text = text.replace("Text('Client/Admin'", "Text('Destination'")

# Fix _buildRow
text = text.replace(
    "_getWarehouseName(entry.sourceWarehouseId)",
    "_getWarehouseName(entry.sourceWarehouseId)"
)
text = text.replace(
    "Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)",
    "Text(_getWarehouseName(entry.destinationWarehouseId), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)"
)
# We also have to remove name logic from _buildMobileCard and _buildRow
text = re.sub(r'    final name = entry\.customerName \?\? entry\.customerCompany \?\? entry\.projectName \?\? \'Inconnu\';\n', '', text)
text = re.sub(r'    final nameIcon = entry\.projectName != null \? Icons\.business_center_rounded : Icons\.person_rounded;\n', '', text)

# Fix _buildMobileCard name usage
text = re.sub(
    r'_buildInfoItem\(nameIcon, name\)',
    r'_buildInfoItem(Icons.move_to_inbox_rounded, "Dest: " + _getWarehouseName(entry.destinationWarehouseId))',
    text
)

# Remove the isExitVoucher stuff from the widget definition
text = re.sub(r'  final bool isExitVoucher;\n\n  const StockTransfersScreen\(\{super\.key, this\.isExitVoucher = false\}\);', '  const StockTransfersScreen({super.key});', text)
text = text.replace("widget.isExitVoucher", "false")

with codecs.open('lib/screens/stock_transfers_screen.dart', 'w', 'utf-8') as f:
    f.write(text)

print("Replacement complete.")
