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
        'items': items.map((i) => i.toMap()).toList(),
      };

  factory StockWithdrawal.fromMap(Map<String, dynamic> map, [List<StockWithdrawalItem> optionalItems = const []]) {
    List<StockWithdrawalItem> parsedItems = optionalItems;
    if (parsedItems.isEmpty && map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List).map((i) => StockWithdrawalItem.fromMap(Map<String, dynamic>.from(i))).toList();
    }

    return StockWithdrawal(
      id: map['id']?.toString() ?? '',
      number: map['number']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      customerName: map['customer_name']?.toString(),
      customerCompany: map['customer_company']?.toString(),
      projectId: map['project_id']?.toString(),
      projectName: map['project_name']?.toString(),
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now() : DateTime.now(),
      status: map['status']?.toString() ?? 'draft',
      pricingMode: map['pricing_mode']?.toString() ?? 'ht',
      globalDiscountPercent: double.tryParse(map['global_discount_percent']?.toString() ?? '0') ?? 0.0,
      globalDiscountAmount: double.tryParse(map['global_discount_amount']?.toString() ?? '0') ?? 0.0,
      timbreFiscal: double.tryParse(map['timbre_fiscal']?.toString() ?? '0') ?? 0.0,
      vehicleRegistration: map['vehicle_registration']?.toString(),
      driverName: map['driver_name']?.toString(),
      notes: map['notes']?.toString(),
      conditionsGenerales: map['conditions']?.toString(),
      warehouseId: map['warehouse_id']?.toString(),
      firebaseUid: map['firebase_uid']?.toString(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == '1' || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      items: parsedItems,
      dbTotalHT: double.tryParse(map['total_ht']?.toString() ?? ''),
      dbTotalTVA: double.tryParse(map['total_tva']?.toString() ?? ''),
      dbTotalTTC: double.tryParse(map['total_ttc']?.toString() ?? ''),
    );
  }
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
        id: map['id']?.toString() ?? '',
        withdrawalId: map['withdrawal_id']?.toString() ?? '',
        productId: map['product_id']?.toString() ?? '',
        description: map['description']?.toString(),
        quantity: double.tryParse(map['quantity']?.toString() ?? '1') ?? 1.0,
        unitPrice: double.tryParse(map['unit_price']?.toString() ?? '0') ?? 0.0,
        tvaRate: double.tryParse(map['tva_rate']?.toString() ?? '19') ?? 19.0,
        discountPercent: double.tryParse(map['discount_percent']?.toString() ?? '0') ?? 0.0,
        showDescription: map['show_description'] == 1 || map['show_description'] == '1' || map['show_description'] == true,
        showDiscount: map['show_discount'] == 1 || map['show_discount'] == '1' || map['show_discount'] == true,
      );
}
