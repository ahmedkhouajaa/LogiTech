class BomComponent {
  final String productId;
  final String productName;
  final double quantity; // Quantité unitaire par BOM
  final String unit;
  final double unitCost; // Coût unitaire d'achat ou revient
  final double scrapPercent; // Perte prévisionnelle en % (ex: 2%)

  BomComponent({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unit = 'Unité',
    this.unitCost = 0.0,
    this.scrapPercent = 0.0,
  });

  double get totalCost => (quantity * (1 + (scrapPercent / 100))) * unitCost;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit': unit,
        'unit_cost': unitCost,
        'scrap_percent': scrapPercent,
      };

  factory BomComponent.fromMap(Map<String, dynamic> map) => BomComponent(
        productId: map['product_id']?.toString() ?? '',
        productName: map['product_name']?.toString() ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: map['unit']?.toString() ?? 'Unité',
        unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
        scrapPercent: (map['scrap_percent'] as num?)?.toDouble() ?? 0.0,
      );

  BomComponent copyWith({
    String? productId,
    String? productName,
    double? quantity,
    String? unit,
    double? unitCost,
    double? scrapPercent,
  }) =>
      BomComponent(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        unitCost: unitCost ?? this.unitCost,
        scrapPercent: scrapPercent ?? this.scrapPercent,
      );
}

class BomOperation {
  final int seq; // 10, 20, 30...
  final String name; // ex: Découpe, Usinage, Assemblage, Peinture
  final String workcenterId;
  final String workcenterName;
  final double setupMinutes; // Temps de réglage/calage
  final double runMinutesPerUnit; // Temps opératoire par unité
  final double hourlyCost; // Taux horaire du poste appliqué

  BomOperation({
    required this.seq,
    required this.name,
    required this.workcenterId,
    required this.workcenterName,
    this.setupMinutes = 0.0,
    this.runMinutesPerUnit = 0.0,
    this.hourlyCost = 0.0,
  });

  // Calcul du coût opératoire pour [batchQty] unités produites
  double costForQty(double batchQty) {
    final totalHours = (setupMinutes + (runMinutesPerUnit * batchQty)) / 60.0;
    return totalHours * hourlyCost;
  }

  Map<String, dynamic> toMap() => {
        'seq': seq,
        'name': name,
        'workcenter_id': workcenterId,
        'workcenter_name': workcenterName,
        'setup_minutes': setupMinutes,
        'run_minutes_per_unit': runMinutesPerUnit,
        'hourly_cost': hourlyCost,
      };

  factory BomOperation.fromMap(Map<String, dynamic> map) => BomOperation(
        seq: (map['seq'] as num?)?.toInt() ?? 10,
        name: map['name']?.toString() ?? '',
        workcenterId: map['workcenter_id']?.toString() ?? '',
        workcenterName: map['workcenter_name']?.toString() ?? '',
        setupMinutes: (map['setup_minutes'] as num?)?.toDouble() ?? 0.0,
        runMinutesPerUnit:
            (map['run_minutes_per_unit'] as num?)?.toDouble() ?? 0.0,
        hourlyCost: (map['hourly_cost'] as num?)?.toDouble() ?? 0.0,
      );

  BomOperation copyWith({
    int? seq,
    String? name,
    String? workcenterId,
    String? workcenterName,
    double? setupMinutes,
    double? runMinutesPerUnit,
    double? hourlyCost,
  }) =>
      BomOperation(
        seq: seq ?? this.seq,
        name: name ?? this.name,
        workcenterId: workcenterId ?? this.workcenterId,
        workcenterName: workcenterName ?? this.workcenterName,
        setupMinutes: setupMinutes ?? this.setupMinutes,
        runMinutesPerUnit: runMinutesPerUnit ?? this.runMinutesPerUnit,
        hourlyCost: hourlyCost ?? this.hourlyCost,
      );
}

class ProductionBom {
  final String id;
  final String productId;
  final String productName;
  final String version; // ex: "v1.0"
  final double quantityProduced; // Quantité de référence de la recette (ex: 1 unité ou lot de 10)
  final String unit;
  final List<BomComponent> components;
  final List<BomOperation> operations;
  final double scrapRate; // Taux de perte global en %
  final bool isDefault; // BOM par défaut pour ce produit
  final bool active;
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductionBom({
    required this.id,
    required this.productId,
    required this.productName,
    this.version = 'v1.0',
    this.quantityProduced = 1.0,
    this.unit = 'Unité',
    this.components = const [],
    this.operations = const [],
    this.scrapRate = 0.0,
    this.isDefault = true,
    this.active = true,
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Coût matières total de la recette
  double get totalMaterialCost =>
      components.fold(0.0, (acc, c) => acc + c.totalCost);

  // Coût opérations total pour la quantité de référence
  double get totalOperationsCost =>
      operations.fold(0.0, (acc, op) => acc + op.costForQty(quantityProduced));

  // Coût de revient standard unitaire calculé
  double get standardUnitCost {
    if (quantityProduced <= 0) return 0.0;
    final total = (totalMaterialCost + totalOperationsCost) * (1 + (scrapRate / 100));
    return total / quantityProduced;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'version': version,
        'quantity_produced': quantityProduced,
        'unit': unit,
        'components': components.map((c) => c.toMap()).toList(),
        'operations': operations.map((op) => op.toMap()).toList(),
        'scrap_rate': scrapRate,
        'is_default': isDefault,
        'active': active,
        'notes': notes,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ProductionBom.fromMap(Map<String, dynamic> map) => ProductionBom(
        id: map['id']?.toString() ?? '',
        productId: map['product_id']?.toString() ?? '',
        productName: map['product_name']?.toString() ?? '',
        version: map['version']?.toString() ?? 'v1.0',
        quantityProduced:
            (map['quantity_produced'] as num?)?.toDouble() ?? 1.0,
        unit: map['unit']?.toString() ?? 'Unité',
        components: (map['components'] as List?)
                ?.map((item) =>
                    BomComponent.fromMap(Map<String, dynamic>.from(item)))
                .toList() ??
            [],
        operations: (map['operations'] as List?)
                ?.map((item) =>
                    BomOperation.fromMap(Map<String, dynamic>.from(item)))
                .toList() ??
            [],
        scrapRate: (map['scrap_rate'] as num?)?.toDouble() ?? 0.0,
        isDefault: map['is_default'] == true || map['is_default'] == 1,
        active: map['active'] == true || map['active'] == 1,
        notes: map['notes']?.toString(),
        enterpriseId: map['enterprise_id']?.toString(),
        createdAt: map['created_at'] != null
            ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
      );

  ProductionBom copyWith({
    String? id,
    String? productId,
    String? productName,
    String? version,
    double? quantityProduced,
    String? unit,
    List<BomComponent>? components,
    List<BomOperation>? operations,
    double? scrapRate,
    bool? isDefault,
    bool? active,
    String? notes,
    String? enterpriseId,
  }) =>
      ProductionBom(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        version: version ?? this.version,
        quantityProduced: quantityProduced ?? this.quantityProduced,
        unit: unit ?? this.unit,
        components: components ?? this.components,
        operations: operations ?? this.operations,
        scrapRate: scrapRate ?? this.scrapRate,
        isDefault: isDefault ?? this.isDefault,
        active: active ?? this.active,
        notes: notes ?? this.notes,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
