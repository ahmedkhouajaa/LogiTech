import 'package:uuid/uuid.dart';

class StockWithdrawal {
  final String id;
  final String number;
  final String customerId;
  final String? customerName;
  final String? customerCompany;
  final String? projectId;
  final String? projectName;
  final DateTime date;
  final String status; // draft, validated, cancelled
  final String pricingMode; // 'ht' or 'ttc'
  final double globalDiscountPercent;
  final double globalDiscountAmount;
  final double timbreFiscal;
  final String? vehicleRegistration;
  final String? driverName;
  final String? notes;
  final String? conditionsGenerales;
  final String? warehouseId;
  final String? firebaseUid;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StockWithdrawalItem> items;

  StockWithdrawal({
    String? id,
    required this.number,
    required this.customerId,
    this.customerName,
    this.customerCompany,
    this.projectId,
    this.projectName,
    required this.date,
    this.status = 'draft',
    this.pricingMode = 'ht',
    this.globalDiscountPercent = 0.0,
    this.globalDiscountAmount = 0.0,
    this.timbreFiscal = 0.0,
    this.vehicleRegistration,
    this.driverName,
    this.notes,
    this.conditionsGenerales,
    this.warehouseId,
    this.firebaseUid,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
    double? dbTotalHT,
    double? dbTotalTVA,
    double? dbTotalTTC,
  })  : id = id ?? const Uuid().v4(),
        _dbTotalHT = dbTotalHT,
        _dbTotalTVA = dbTotalTVA,
        _dbTotalTTC = dbTotalTTC,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final double? _dbTotalHT;
  final double? _dbTotalTVA;
  final double? _dbTotalTTC;

  double get subTotalHT {
    if (items.isEmpty && _dbTotalHT != null) return _dbTotalHT!;
    return items.fold(0, (sum, item) => sum + item.totalHT);
  }

  double get subTotalTTC {
    if (items.isEmpty && _dbTotalTTC != null && pricingMode == 'ttc') {
      return _dbTotalTTC! - timbreFiscal + discountAmount;
    }
    return items.fold(0, (sum, item) => sum + item.totalTTC);
  }

  Map<double, double> get tvaBreakdown {
    final breakdown = <double, double>{};
    for (var item in items) {
      breakdown[item.tvaRate] = (breakdown[item.tvaRate] ?? 0) + item.tvaAmount;
    }
    return breakdown;
  }

  double get totalTVA {
    if (items.isEmpty && _dbTotalTVA != null) return _dbTotalTVA!;
    return items.fold(0, (sum, item) => sum + item.tvaAmount);
  }

  double get discountAmount {
    if (globalDiscountAmount > 0) return globalDiscountAmount;
    if (globalDiscountPercent > 0) return subTotalHT * (globalDiscountPercent / 100);
    return 0;
  }

  double get totalHTAfterDiscount {
    if (items.isEmpty && _dbTotalHT != null) return _dbTotalHT!;
    return subTotalHT - discountAmount;
  }

  double get totalTTC {
    if (items.isEmpty && _dbTotalTTC != null) return _dbTotalTTC!;
    if (pricingMode == 'ttc') {
      return subTotalTTC - discountAmount + timbreFiscal;
    } else {
      return totalHTAfterDiscount + totalTVA + timbreFiscal;
    }
  }

  StockWithdrawal copyWith({
    String? id,
    String? number,
    String? customerId,
    String? customerName,
    String? customerCompany,
    String? projectId,
    String? projectName,
    DateTime? date,
    String? status,
    String? pricingMode,
    double? globalDiscountPercent,
    double? globalDiscountAmount,
    double? timbreFiscal,
    String? vehicleRegistration,
    String? driverName,
    String? notes,
    String? conditionsGenerales,
    String? warehouseId,
    String? firebaseUid,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<StockWithdrawalItem>? items,
  }) {
    return StockWithdrawal(
      id: id ?? this.id,
      number: number ?? this.number,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerCompany: customerCompany ?? this.customerCompany,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      date: date ?? this.date,
      status: status ?? this.status,
      pricingMode: pricingMode ?? this.pricingMode,
      globalDiscountPercent: globalDiscountPercent ?? this.globalDiscountPercent,
      globalDiscountAmount: globalDiscountAmount ?? this.globalDiscountAmount,
      timbreFiscal: timbreFiscal ?? this.timbreFiscal,
      vehicleRegistration: vehicleRegistration ?? this.vehicleRegistration,
      driverName: driverName ?? this.driverName,
      notes: notes ?? this.notes,
      conditionsGenerales: conditionsGenerales ?? this.conditionsGenerales,
      warehouseId: warehouseId ?? this.warehouseId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'customer_id': customerId,
        'project_id': projectId,
        'date': date.toIso8601String(),
        'status': status,
        'pricing_mode': pricingMode,
        'global_discount_percent': globalDiscountPercent,
        'global_discount_amount': globalDiscountAmount,
        'timbre_fiscal': timbreFiscal,
        'vehicle_registration': vehicleRegistration,
        'driver_name': driverName,
        'warehouse_id': warehouseId,
        'notes': notes,
        'conditions': conditionsGenerales,
        'total_ht': totalHTAfterDiscount,
        'total_tva': totalTVA,
        'total_ttc': totalTTC,
        'firebase_uid': firebaseUid,
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory StockWithdrawal.fromMap(Map<String, dynamic> map, [List<StockWithdrawalItem> items = const []]) =>
      StockWithdrawal(
        id: map['id'] as String,
        number: map['number'] as String,
        customerId: map['customer_id'] as String,
        customerName: map['customer_name'] as String?,
        customerCompany: map['customer_company'] as String?,
        projectId: map['project_id'] as String?,
        projectName: map['project_name'] as String?,
        date: DateTime.parse(map['date'] as String),
        status: map['status'] as String? ?? 'draft',
        pricingMode: map['pricing_mode'] as String? ?? 'ht',
        globalDiscountPercent: (map['global_discount_percent'] as num?)?.toDouble() ?? 0.0,
        globalDiscountAmount: (map['global_discount_amount'] as num?)?.toDouble() ?? 0.0,
        timbreFiscal: (map['timbre_fiscal'] as num?)?.toDouble() ?? 0.0,
        vehicleRegistration: map['vehicle_registration'] as String?,
        driverName: map['driver_name'] as String?,
        notes: map['notes'] as String?,
        conditionsGenerales: map['conditions'] as String?,
        warehouseId: map['warehouse_id'] as String?,
        firebaseUid: map['firebase_uid'] as String?,
        isDeleted: map['is_deleted'] == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        items: items,
        dbTotalHT: map['total_ht'] != null ? (map['total_ht'] as num).toDouble() : null,
        dbTotalTVA: map['total_tva'] != null ? (map['total_tva'] as num).toDouble() : null,
        dbTotalTTC: map['total_ttc'] != null ? (map['total_ttc'] as num).toDouble() : null,
      );
}

class StockWithdrawalItem {
  final String id;
  final String withdrawalId;
  final String productId;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;
  final bool showDescription;
  final bool showDiscount;

  StockWithdrawalItem({
    String? id,
    required this.withdrawalId,
    required this.productId,
    this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.tvaRate = 19,
    this.discountPercent = 0,
    this.showDescription = false,
    this.showDiscount = false,
  }) : id = id ?? const Uuid().v4();

  double get unitPriceAfterDiscount => unitPrice * (1 - (discountPercent / 100));
  double get totalHT => unitPriceAfterDiscount * quantity;
  double get tvaAmount => totalHT * (tvaRate / 100);
  double get totalTTC => totalHT + tvaAmount;

  StockWithdrawalItem copyWith({
    String? id,
    String? withdrawalId,
    String? productId,
    String? description,
    double? quantity,
    double? unitPrice,
    double? tvaRate,
    double? discountPercent,
    bool? showDescription,
    bool? showDiscount,
  }) {
    return StockWithdrawalItem(
      id: id ?? this.id,
      withdrawalId: withdrawalId ?? this.withdrawalId,
      productId: productId ?? this.productId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      tvaRate: tvaRate ?? this.tvaRate,
      discountPercent: discountPercent ?? this.discountPercent,
      showDescription: showDescription ?? this.showDescription,
      showDiscount: showDiscount ?? this.showDiscount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'withdrawal_id': withdrawalId,
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tva_rate': tvaRate,
        'discount_percent': discountPercent,
        'total_ht': totalHT,
        'show_description': showDescription ? 1 : 0,
        'show_discount': showDiscount ? 1 : 0,
      };

  factory StockWithdrawalItem.fromMap(Map<String, dynamic> map) => StockWithdrawalItem(
        id: map['id'] as String,
        withdrawalId: map['withdrawal_id'] as String,
        productId: map['product_id'] as String,
        description: map['description'] as String?,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        tvaRate: (map['tva_rate'] as num?)?.toDouble() ?? 19,
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
        showDescription: map['show_description'] == 1,
        showDiscount: map['show_discount'] == 1,
      );
}
