import '../models/report_data.dart';

class ReportRepository {
  Future<List<MonthlySales>> getMonthlySales(String dateRange) async {
    final months = ['Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jui', 'Jul', 'Aou', 'Sep', 'Oct', 'Nov', 'Dec'];
    return List.generate(12, (index) => MonthlySales(month: months[index], sales: 0));
  }

  Future<List<WarehouseStock>> getWarehouseStock() async {
    return [WarehouseStock(warehouseName: 'Entrepôt Principal', stockValue: 0)];
  }

  Future<List<CategorySales>> getCategorySales() async {
    return [];
  }

  Future<List<TopClient>> getTopClients(int limit) async {
    return [];
  }

  Future<Map<String, double>> getKPIs() async {
    return {
      'turnoverRate': 0.0,
      'fulfillmentRate': 100.0,
      'avgDeliveryTime': 0.0,
      'stockoutRate': 0.0,
    };
  }

  Future<List<SupplierPerformance>> getSupplierPerformance() async {
    return [
      SupplierPerformance(name: 'Fournisseur Général', deliveryDays: 5.0, qualityRate: 95)
    ];
  }
}
