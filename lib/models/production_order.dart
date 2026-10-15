import 'package:flutter/material.dart';

enum ProductionOrderStatus {
  draft,
  confirmed,
  planned,
  inProgress,
  qualityCheck,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case ProductionOrderStatus.draft:
        return 'Brouillon';
      case ProductionOrderStatus.confirmed:
        return 'Confirmé';
      case ProductionOrderStatus.planned:
        return 'Planifié';
      case ProductionOrderStatus.inProgress:
        return 'En cours';
      case ProductionOrderStatus.qualityCheck:
        return 'Contrôle qualité';
      case ProductionOrderStatus.completed:
        return 'Terminé';
      case ProductionOrderStatus.cancelled:
        return 'Annulé';
    }
  }

  Color get color {
    switch (this) {
      case ProductionOrderStatus.draft:
        return const Color(0xFF64748B); // Slate
      case ProductionOrderStatus.confirmed:
        return const Color(0xFF2563EB); // Bleu
      case ProductionOrderStatus.planned:
        return const Color(0xFF8B5CF6); // Violet
      case ProductionOrderStatus.inProgress:
        return const Color(0xFFF59E0B); // Ambre / Orange
      case ProductionOrderStatus.qualityCheck:
        return const Color(0xFF06B6D4); // Cyan
      case ProductionOrderStatus.completed:
        return const Color(0xFF10B981); // Vert
      case ProductionOrderStatus.cancelled:
        return const Color(0xFFEF4444); // Rouge
    }
  }

  IconData get icon {
    switch (this) {
      case ProductionOrderStatus.draft:
        return Icons.edit_note_rounded;
      case ProductionOrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case ProductionOrderStatus.planned:
        return Icons.calendar_month_rounded;
      case ProductionOrderStatus.inProgress:
        return Icons.play_circle_outline_rounded;
      case ProductionOrderStatus.qualityCheck:
        return Icons.verified_outlined;
      case ProductionOrderStatus.completed:
        return Icons.task_alt_rounded;
      case ProductionOrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }
}

class OrderMaterialLine {
  final String productId;
  final String productName;
  final double qtyRequired;
  final double qtyConsumed;
  final double availableQty;
  final String unit;
  final double unitCost;

  OrderMaterialLine({
    required this.productId,
    required this.productName,
    required this.qtyRequired,
    this.qtyConsumed = 0.0,
    this.availableQty = 0.0,
    this.unit = 'Unité',
    this.unitCost = 0.0,
  });

  bool get isShortage => availableQty < (qtyRequired - qtyConsumed);
  double get totalActualCost => qtyConsumed * unitCost;
  double get totalPlannedCost => qtyRequired * unitCost;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'qty_required': qtyRequired,
        'qty_consumed': qtyConsumed,
        'available_qty': availableQty,
        'unit': unit,
        'unit_cost': unitCost,
      };

  factory OrderMaterialLine.fromMap(Map<String, dynamic> map) =>
      OrderMaterialLine(
        productId: map['product_id']?.toString() ?? '',
        productName: map['product_name']?.toString() ?? '',
        qtyRequired: (map['qty_required'] as num?)?.toDouble() ?? 0.0,
        qtyConsumed: (map['qty_consumed'] as num?)?.toDouble() ?? 0.0,
        availableQty: (map['available_qty'] as num?)?.toDouble() ?? 0.0,
        unit: map['unit']?.toString() ?? 'Unité',
        unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      );

  OrderMaterialLine copyWith({
    String? productId,
    String? productName,
    double? qtyRequired,
    double? qtyConsumed,
    double? availableQty,
    String? unit,
    double? unitCost,
  }) =>
      OrderMaterialLine(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        qtyRequired: qtyRequired ?? this.qtyRequired,
        qtyConsumed: qtyConsumed ?? this.qtyConsumed,
        availableQty: availableQty ?? this.availableQty,
        unit: unit ?? this.unit,
        unitCost: unitCost ?? this.unitCost,
      );
}

class OrderOperationLine {
  final int seq;
  final String name;
  final String workcenterId;
  final String workcenterName;
  final double plannedMinutes;
  final double actualMinutes;
  final double hourlyCost;
  final String status; // 'pending', 'inProgress', 'done'
  final String? operatorId;
  final String? operatorName;

  OrderOperationLine({
    required this.seq,
    required this.name,
    required this.workcenterId,
    required this.workcenterName,
    this.plannedMinutes = 0.0,
    this.actualMinutes = 0.0,
    this.hourlyCost = 0.0,
    this.status = 'pending',
    this.operatorId,
    this.operatorName,
  });

  double get plannedCost => (plannedMinutes / 60.0) * hourlyCost;
  double get actualCost => (actualMinutes / 60.0) * hourlyCost;

  Map<String, dynamic> toMap() => {
        'seq': seq,
        'name': name,
        'workcenter_id': workcenterId,
        'workcenter_name': workcenterName,
        'planned_minutes': plannedMinutes,
        'actual_minutes': actualMinutes,
        'hourly_cost': hourlyCost,
        'status': status,
        'operator_id': operatorId,
        'operator_name': operatorName,
      };

  factory OrderOperationLine.fromMap(Map<String, dynamic> map) =>
      OrderOperationLine(
        seq: (map['seq'] as num?)?.toInt() ?? 10,
        name: map['name']?.toString() ?? '',
        workcenterId: map['workcenter_id']?.toString() ?? '',
        workcenterName: map['workcenter_name']?.toString() ?? '',
        plannedMinutes: (map['planned_minutes'] as num?)?.toDouble() ?? 0.0,
        actualMinutes: (map['actual_minutes'] as num?)?.toDouble() ?? 0.0,
        hourlyCost: (map['hourly_cost'] as num?)?.toDouble() ?? 0.0,
        status: map['status']?.toString() ?? 'pending',
        operatorId: map['operator_id']?.toString(),
        operatorName: map['operator_name']?.toString(),
      );

  OrderOperationLine copyWith({
    int? seq,
    String? name,
    String? workcenterId,
    String? workcenterName,
    double? plannedMinutes,
    double? actualMinutes,
    double? hourlyCost,
    String? status,
    String? operatorId,
    String? operatorName,
  }) =>
      OrderOperationLine(
        seq: seq ?? this.seq,
        name: name ?? this.name,
        workcenterId: workcenterId ?? this.workcenterId,
        workcenterName: workcenterName ?? this.workcenterName,
        plannedMinutes: plannedMinutes ?? this.plannedMinutes,
        actualMinutes: actualMinutes ?? this.actualMinutes,
        hourlyCost: hourlyCost ?? this.hourlyCost,
        status: status ?? this.status,
        operatorId: operatorId ?? this.operatorId,
        operatorName: operatorName ?? this.operatorName,
      );
}

class ProductionOrder {
  final String id;
  final String number; // ex: OF-2026-0001
  final String productId;
  final String productName;
  final String bomId;
  final String bomVersion;
  final double qtyPlanned;
  final double qtyProduced;
  final double qtyScrapped;
  final String unit;
  final ProductionOrderStatus status;
  final int priority; // 0=basse, 1=normale, 2=haute, 3=urgente
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final String? sourceWarehouseId;
  final String? sourceWarehouseName;
  final String? destWarehouseId;
  final String? destWarehouseName;
  final String? customerOrderId;
  final String? customerOrderNumber;
  final List<OrderMaterialLine> materialLines;
  final List<OrderOperationLine> operationLines;
  final String qcStatus; // 'none', 'pending', 'passed', 'failed'
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductionOrder({
    required this.id,
    required this.number,
    required this.productId,
    required this.productName,
    required this.bomId,
    this.bomVersion = 'v1.0',
    required this.qtyPlanned,
    this.qtyProduced = 0.0,
    this.qtyScrapped = 0.0,
    this.unit = 'Unité',
    this.status = ProductionOrderStatus.draft,
    this.priority = 1,
    this.plannedStart,
    this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    this.sourceWarehouseId,
    this.sourceWarehouseName,
    this.destWarehouseId,
    this.destWarehouseName,
    this.customerOrderId,
    this.customerOrderNumber,
    this.materialLines = const [],
    this.operationLines = const [],
    this.qcStatus = 'none',
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Pourcentage de progression de la production
  double get progressPercentage {
    if (qtyPlanned <= 0) return 0.0;
    final p = (qtyProduced / qtyPlanned) * 100.0;
    return p.clamp(0.0, 100.0);
  }

  // Coûts prévus
  double get plannedMaterialCost =>
      materialLines.fold(0.0, (acc, l) => acc + l.totalPlannedCost);
  double get plannedOperationCost =>
      operationLines.fold(0.0, (acc, op) => acc + op.plannedCost);
  double get plannedTotalCost => plannedMaterialCost + plannedOperationCost;

  // Coûts réels engagés
  double get actualMaterialCost =>
      materialLines.fold(0.0, (acc, l) => acc + l.totalActualCost);
  double get actualOperationCost =>
      operationLines.fold(0.0, (acc, op) => acc + op.actualCost);
  double get actualTotalCost => actualMaterialCost + actualOperationCost;

  // Coût unitaire réel produit
  double get actualUnitCost {
    if (qtyProduced <= 0) return 0.0;
    return actualTotalCost / qtyProduced;
  }

  // Écart de coût (réel - prévu)
  double get costVariance => actualTotalCost - plannedTotalCost;

  bool get hasShortage => materialLines.any((l) => l.isShortage);

  bool get isDelayed =>
      plannedEnd != null &&
      plannedEnd!.isBefore(DateTime.now()) &&
      status != ProductionOrderStatus.completed &&
      status != ProductionOrderStatus.cancelled;

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'product_id': productId,
        'product_name': productName,
        'bom_id': bomId,
        'bom_version': bomVersion,
        'qty_planned': qtyPlanned,
        'qty_produced': qtyProduced,
        'qty_scrapped': qtyScrapped,
        'unit': unit,
        'status': status.name,
        'priority': priority,
        'planned_start': plannedStart?.toIso8601String(),
        'planned_end': plannedEnd?.toIso8601String(),
        'actual_start': actualStart?.toIso8601String(),
        'actual_end': actualEnd?.toIso8601String(),
        'source_warehouse_id': sourceWarehouseId,
        'source_warehouse_name': sourceWarehouseName,
        'dest_warehouse_id': destWarehouseId,
        'dest_warehouse_name': destWarehouseName,
        'customer_order_id': customerOrderId,
        'customer_order_number': customerOrderNumber,
        'material_lines': materialLines.map((l) => l.toMap()).toList(),
        'operation_lines': operationLines.map((op) => op.toMap()).toList(),
        'qc_status': qcStatus,
        'notes': notes,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ProductionOrder.fromMap(Map<String, dynamic> map) => ProductionOrder(
        id: map['id']?.toString() ?? '',
        number: map['number']?.toString() ?? '',
        productId: map['product_id']?.toString() ?? '',
        productName: map['product_name']?.toString() ?? '',
        bomId: map['bom_id']?.toString() ?? '',
        bomVersion: map['bom_version']?.toString() ?? 'v1.0',
        qtyPlanned: (map['qty_planned'] as num?)?.toDouble() ?? 0.0,
        qtyProduced: (map['qty_produced'] as num?)?.toDouble() ?? 0.0,
        qtyScrapped: (map['qty_scrapped'] as num?)?.toDouble() ?? 0.0,
        unit: map['unit']?.toString() ?? 'Unité',
        status: ProductionOrderStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => ProductionOrderStatus.draft,
        ),
        priority: (map['priority'] as num?)?.toInt() ?? 1,
        plannedStart: map['planned_start'] != null
            ? DateTime.tryParse(map['planned_start'].toString())
            : null,
        plannedEnd: map['planned_end'] != null
            ? DateTime.tryParse(map['planned_end'].toString())
            : null,
        actualStart: map['actual_start'] != null
            ? DateTime.tryParse(map['actual_start'].toString())
            : null,
        actualEnd: map['actual_end'] != null
            ? DateTime.tryParse(map['actual_end'].toString())
            : null,
        sourceWarehouseId: map['source_warehouse_id']?.toString(),
        sourceWarehouseName: map['source_warehouse_name']?.toString(),
        destWarehouseId: map['dest_warehouse_id']?.toString(),
        destWarehouseName: map['dest_warehouse_name']?.toString(),
        customerOrderId: map['customer_order_id']?.toString(),
        customerOrderNumber: map['customer_order_number']?.toString(),
        materialLines: (map['material_lines'] as List?)
                ?.map((item) =>
                    OrderMaterialLine.fromMap(Map<String, dynamic>.from(item)))
                .toList() ??
            [],
        operationLines: (map['operation_lines'] as List?)
                ?.map((item) =>
                    OrderOperationLine.fromMap(Map<String, dynamic>.from(item)))
                .toList() ??
            [],
        qcStatus: map['qc_status']?.toString() ?? 'none',
        notes: map['notes']?.toString(),
        enterpriseId: map['enterprise_id']?.toString(),
        createdAt: map['created_at'] != null
            ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
      );

  ProductionOrder copyWith({
    String? id,
    String? number,
    String? productId,
    String? productName,
    String? bomId,
    String? bomVersion,
    double? qtyPlanned,
    double? qtyProduced,
    double? qtyScrapped,
    String? unit,
    ProductionOrderStatus? status,
    int? priority,
    DateTime? plannedStart,
    DateTime? plannedEnd,
    DateTime? actualStart,
    DateTime? actualEnd,
    String? sourceWarehouseId,
    String? sourceWarehouseName,
    String? destWarehouseId,
    String? destWarehouseName,
    String? customerOrderId,
    String? customerOrderNumber,
    List<OrderMaterialLine>? materialLines,
    List<OrderOperationLine>? operationLines,
    String? qcStatus,
    String? notes,
    String? enterpriseId,
  }) =>
      ProductionOrder(
        id: id ?? this.id,
        number: number ?? this.number,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        bomId: bomId ?? this.bomId,
        bomVersion: bomVersion ?? this.bomVersion,
        qtyPlanned: qtyPlanned ?? this.qtyPlanned,
        qtyProduced: qtyProduced ?? this.qtyProduced,
        qtyScrapped: qtyScrapped ?? this.qtyScrapped,
        unit: unit ?? this.unit,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        plannedStart: plannedStart ?? this.plannedStart,
        plannedEnd: plannedEnd ?? this.plannedEnd,
        actualStart: actualStart ?? this.actualStart,
        actualEnd: actualEnd ?? this.actualEnd,
        sourceWarehouseId: sourceWarehouseId ?? this.sourceWarehouseId,
        sourceWarehouseName: sourceWarehouseName ?? this.sourceWarehouseName,
        destWarehouseId: destWarehouseId ?? this.destWarehouseId,
        destWarehouseName: destWarehouseName ?? this.destWarehouseName,
        customerOrderId: customerOrderId ?? this.customerOrderId,
        customerOrderNumber: customerOrderNumber ?? this.customerOrderNumber,
        materialLines: materialLines ?? this.materialLines,
        operationLines: operationLines ?? this.operationLines,
        qcStatus: qcStatus ?? this.qcStatus,
        notes: notes ?? this.notes,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
