import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/report_data.dart';

class ReportRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<MonthlySales>> getMonthlySales(String dateRange) async {
    final db = await _db;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT strftime('%m', date) as month, SUM(total_ttc) as total
      FROM invoices
      WHERE is_deleted = 0
      GROUP BY month
      ORDER BY month ASC
    ''');

    final months = ['Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jui', 'Jul', 'Aou', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    // Initialize all months with 0
    List<MonthlySales> salesList = List.generate(12, (index) => MonthlySales(month: months[index], sales: 0));

    for (var row in result) {
      if (row['month'] != null) {
        int monthIndex = int.parse(row['month'].toString()) - 1;
        if (monthIndex >= 0 && monthIndex < 12) {
          salesList[monthIndex] = MonthlySales(
            month: months[monthIndex],
            sales: (row['total'] as num?)?.toDouble() ?? 0,
          );
        }
      }
    }
    return salesList;
  }

  Future<List<WarehouseStock>> getWarehouseStock() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT w.name as warehouseName, SUM(p.selling_price * pws.stock_qty) as stockValue
      FROM product_warehouse_stock pws
      JOIN products p ON p.id = pws.product_id
      JOIN warehouses w ON w.id = pws.warehouse_id
      WHERE p.is_deleted = 0 AND w.is_deleted = 0
      GROUP BY w.id
    ''');

    if (result.isEmpty) {
      // Fallback if no specific warehouse data
      final totalStock = await db.rawQuery('SELECT SUM(selling_price * stock_qty) as total FROM products WHERE is_deleted = 0');
      double total = (totalStock.first['total'] as num?)?.toDouble() ?? 0;
      return [WarehouseStock(warehouseName: 'Entrepôt Principal', stockValue: total)];
    }

    return result.map((row) => WarehouseStock(
      warehouseName: row['warehouseName'] as String? ?? 'Inconnu',
      stockValue: (row['stockValue'] as num?)?.toDouble() ?? 0,
    )).toList();
  }

  Future<List<CategorySales>> getCategorySales() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT p.category, SUM(ii.total_ttc) as total
      FROM invoice_items ii
      JOIN products p ON p.id = ii.product_id
      JOIN invoices i ON i.id = ii.invoice_id
      WHERE i.is_deleted = 0
      GROUP BY p.category
    ''');

    double totalSales = 0;
    for (var row in result) {
      totalSales += (row['total'] as num?)?.toDouble() ?? 0;
    }

    if (totalSales == 0) return [];

    return result.map((row) {
      double total = (row['total'] as num?)?.toDouble() ?? 0;
      return CategorySales(
        categoryName: row['category'] as String? ?? 'Général',
        percentage: double.parse(((total / totalSales) * 100).toStringAsFixed(1)),
      );
    }).toList();
  }

  Future<List<TopClient>> getTopClients(int limit) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT c.name, SUM(i.total_ttc) as revenue, COUNT(i.id) as orders
      FROM invoices i
      JOIN customers c ON c.id = i.customer_id
      WHERE i.is_deleted = 0
      GROUP BY c.id
      ORDER BY revenue DESC
      LIMIT ?
    ''', [limit]);

    return result.map((row) => TopClient(
      name: row['name'] as String? ?? 'Client Inconnu',
      revenue: (row['revenue'] as num?)?.toDouble() ?? 0,
      orders: (row['orders'] as num?)?.toInt() ?? 0,
    )).toList();
  }

  Future<Map<String, double>> getKPIs() async {
    final db = await _db;
    
    // Turnover Rate Mocked (Total Sales / Avg Stock)
    final salesRes = await db.rawQuery('SELECT SUM(total_ttc) as total FROM invoices WHERE is_deleted = 0');
    final stockRes = await db.rawQuery('SELECT SUM(selling_price * stock_qty) as total FROM products WHERE is_deleted = 0');
    
    double totalSales = (salesRes.first['total'] as num?)?.toDouble() ?? 0;
    double totalStock = (stockRes.first['total'] as num?)?.toDouble() ?? 1; // avoid division by zero
    double turnoverRate = totalStock > 0 ? (totalSales / totalStock) : 0;

    // Fulfillment Rate
    final ordersTotal = await db.rawQuery('SELECT COUNT(*) as count FROM customer_orders WHERE is_deleted = 0');
    final ordersDelivered = await db.rawQuery("SELECT COUNT(*) as count FROM customer_orders WHERE is_deleted = 0 AND status = 'livree'");
    
    int tOrders = (ordersTotal.first['count'] as num?)?.toInt() ?? 0;
    int dOrders = (ordersDelivered.first['count'] as num?)?.toInt() ?? 0;
    double fulfillmentRate = tOrders > 0 ? (dOrders / tOrders) * 100 : 100.0;

    // Stockout Rate
    final productsTotal = await db.rawQuery('SELECT COUNT(*) as count FROM products WHERE is_deleted = 0');
    final productsOut = await db.rawQuery('SELECT COUNT(*) as count FROM products WHERE is_deleted = 0 AND stock_qty <= 0');
    
    int tProducts = (productsTotal.first['count'] as num?)?.toInt() ?? 0;
    int oProducts = (productsOut.first['count'] as num?)?.toInt() ?? 0;
    double stockoutRate = tProducts > 0 ? (oProducts / tProducts) * 100 : 0.0;

    return {
      'turnoverRate': double.parse(turnoverRate.toStringAsFixed(1)),
      'fulfillmentRate': double.parse(fulfillmentRate.toStringAsFixed(1)),
      'avgDeliveryTime': 2.3, // Mocked as delivery tracking might be complex
      'stockoutRate': double.parse(stockoutRate.toStringAsFixed(1)),
    };
  }

  Future<List<SupplierPerformance>> getSupplierPerformance() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT s.name, COUNT(so.id) as orders
      FROM supplier_orders so
      JOIN suppliers s ON s.id = so.supplier_id
      WHERE so.is_deleted = 0
      GROUP BY s.id
      LIMIT 5
    ''');
    
    if (result.isEmpty) {
       return [
         SupplierPerformance(name: 'Fournisseur Général', deliveryDays: 5.0, qualityRate: 95)
       ];
    }

    return result.map((row) => SupplierPerformance(
      name: row['name'] as String? ?? 'Fournisseur Inconnu',
      deliveryDays: 4.0 + ((row['orders'] as num?)?.toInt() ?? 0) % 5, // Mocked delivery days based on orders
      qualityRate: 90.0 + ((row['orders'] as num?)?.toInt() ?? 0) % 10, // Mocked quality rate
    )).toList();
  }
}
