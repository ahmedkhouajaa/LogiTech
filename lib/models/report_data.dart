class MonthlySales {
  final String month;
  final double sales;

  MonthlySales({required this.month, required this.sales});
}

class WarehouseStock {
  final String warehouseName;
  final double stockValue;

  WarehouseStock({required this.warehouseName, required this.stockValue});
}

class CategorySales {
  final String categoryName;
  final double percentage;

  CategorySales({required this.categoryName, required this.percentage});
}

class TopClient {
  final String name;
  final double revenue;
  final int orders;

  TopClient({required this.name, required this.revenue, required this.orders});
}

class SupplierPerformance {
  final String name;
  final double deliveryDays;
  final double qualityRate;

  SupplierPerformance({required this.name, required this.deliveryDays, required this.qualityRate});
}
