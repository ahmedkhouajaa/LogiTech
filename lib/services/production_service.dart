import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/production_workcenter.dart';
import '../models/production_bom.dart';
import '../models/production_order.dart';
import '../models/production_quality_check.dart';
import '../models/stock_movement.dart';
import '../utils/constants.dart';
import 'enterprise_service.dart';

class ProductionService {
  ProductionService._internal();
  static final ProductionService instance = ProductionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ValueNotifiers for UI reactivity
  final ValueNotifier<List<ProductionWorkcenter>> workcentersNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<ProductionBom>> bomsNotifier = ValueNotifier([]);
  final ValueNotifier<List<ProductionOrder>> ordersNotifier = ValueNotifier([]);
  final ValueNotifier<List<ProductionQualityCheck>> qualityChecksNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<ProductionNonConformity>> nonConformitiesNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  StreamSubscription? _subWorkcenters;
  StreamSubscription? _subBoms;
  StreamSubscription? _subOrders;
  StreamSubscription? _subQualityChecks;
  StreamSubscription? _subNonConformities;

  String? _currentEnterpriseId;

  String get _activeEnterpriseId {
    if (_currentEnterpriseId != null && _currentEnterpriseId!.isNotEmpty) {
      return _currentEnterpriseId!;
    }
    final active = EnterpriseService.instance.currentEnterpriseId;
    if (active != null && active.isNotEmpty) {
      return active;
    }
    return 'default_enterprise';
  }

  void init() {
    EnterpriseService.instance.currentEnterpriseNotifier
        .addListener(_onEnterpriseChanged);
    _onEnterpriseChanged();
  }

  void dispose() {
    EnterpriseService.instance.currentEnterpriseNotifier
        .removeListener(_onEnterpriseChanged);
    _cancelSubs();
  }

  void _onEnterpriseChanged() {
    final eid = EnterpriseService.instance.currentEnterpriseId;
    if (eid != _currentEnterpriseId) {
      _currentEnterpriseId = eid;
      _cancelSubs();
      if (eid != null && eid.isNotEmpty) {
        loadData(eid);
      } else {
        workcentersNotifier.value = [];
        bomsNotifier.value = [];
        ordersNotifier.value = [];
        qualityChecksNotifier.value = [];
        nonConformitiesNotifier.value = [];
      }
    }
  }

  void _cancelSubs() {
    _subWorkcenters?.cancel();
    _subBoms?.cancel();
    _subOrders?.cancel();
    _subQualityChecks?.cancel();
    _subNonConformities?.cancel();
  }

  void loadData(String enterpriseId) {
    isLoadingNotifier.value = true;
    _cancelSubs();

    // Workcenters
    _subWorkcenters = _firestore
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('production_workcenters')
        .snapshots()
        .listen((snap) {
      workcentersNotifier.value = snap.docs
          .map((doc) => ProductionWorkcenter.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }, onError: (e) {
      debugPrint('[ProductionService] Error workcenters: $e');
    });

    // BOMs
    _subBoms = _firestore
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('production_boms')
        .snapshots()
        .listen((snap) {
      bomsNotifier.value = snap.docs
          .map((doc) => ProductionBom.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => a.productName.compareTo(b.productName));
    }, onError: (e) {
      debugPrint('[ProductionService] Error boms: $e');
    });

    // Production Orders
    _subOrders = _firestore
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('production_orders')
        .snapshots()
        .listen((snap) {
      ordersNotifier.value = snap.docs
          .map((doc) => ProductionOrder.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      isLoadingNotifier.value = false;
    }, onError: (e) {
      debugPrint('[ProductionService] Error orders: $e');
      isLoadingNotifier.value = false;
    });

    // Quality Checks
    _subQualityChecks = _firestore
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('production_quality_checks')
        .snapshots()
        .listen((snap) {
      qualityChecksNotifier.value = snap.docs
          .map((doc) => ProductionQualityCheck.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.inspectionDate.compareTo(a.inspectionDate));
    }, onError: (e) {
      debugPrint('[ProductionService] Error qc: $e');
    });

    // Non-Conformities
    _subNonConformities = _firestore
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('production_nonconformities')
        .snapshots()
        .listen((snap) {
      nonConformitiesNotifier.value = snap.docs
          .map((doc) => ProductionNonConformity.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }, onError: (e) {
      debugPrint('[ProductionService] Error nc: $e');
    });
  }

  // ---------------------------------------------------------------------------
  // WORKCENTERS CRUD
  // ---------------------------------------------------------------------------
  Future<void> saveWorkcenter(ProductionWorkcenter wc) async {
    final eid = _activeEnterpriseId;
    final item = wc.copyWith(enterpriseId: eid);
    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_workcenters')
        .doc(item.id)
        .set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteWorkcenter(String id) async {
    final eid = _activeEnterpriseId;
    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_workcenters')
        .doc(id)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // BOMS CRUD
  // ---------------------------------------------------------------------------
  Future<void> saveBom(ProductionBom bom) async {
    final eid = _activeEnterpriseId;
    final item = bom.copyWith(enterpriseId: eid);

    // If marked default, unset default for other BOMs of this product
    if (item.isDefault) {
      final existingBoms = bomsNotifier.value
          .where((b) => b.productId == item.productId && b.id != item.id);
      for (final b in existingBoms) {
        if (b.isDefault) {
          await _firestore
              .collection('enterprises')
              .doc(eid)
              .collection('production_boms')
              .doc(b.id)
              .update({'is_default': false});
        }
      }
    }

    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_boms')
        .doc(item.id)
        .set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteBom(String id) async {
    final eid = _activeEnterpriseId;
    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_boms')
        .doc(id)
        .delete();
  }

  Future<ProductionBom?> duplicateBom(ProductionBom src, String newVersion) async {
    final newId = _uuid.v4();
    final duplicated = src.copyWith(
      id: newId,
      version: newVersion,
      isDefault: false,
    );
    await saveBom(duplicated);
    return duplicated;
  }

  ProductionBom? getBomForProduct(String productId) {
    final list = bomsNotifier.value.where((b) => b.productId == productId).toList();
    if (list.isEmpty) return null;
    return list.firstWhere((b) => b.isDefault, orElse: () => list.first);
  }

  // ---------------------------------------------------------------------------
  // PRODUCTION ORDERS CRUD & LIFECYCLE
  // ---------------------------------------------------------------------------
  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    final year = now.year.toString();
    final existingThisYear = ordersNotifier.value
        .where((o) => o.number.startsWith('OF-$year-'))
        .length;
    final nextSeq = (existingThisYear + 1).toString().padLeft(4, '0');
    return 'OF-$year-$nextSeq';
  }

  Future<ProductionOrder> createOrderFromBom({
    required ProductionBom bom,
    required double qtyToProduce,
    DateTime? plannedStart,
    DateTime? plannedEnd,
    int priority = 1,
    String? sourceWarehouseId,
    String? sourceWarehouseName,
    String? destWarehouseId,
    String? destWarehouseName,
    String? customerOrderId,
    String? customerOrderNumber,
    String? notes,
  }) async {
    final eid = _activeEnterpriseId;
    final orderId = _uuid.v4();
    final number = await generateOrderNumber();

    // Scale components
    final scaleFactor = bom.quantityProduced > 0
        ? (qtyToProduce / bom.quantityProduced)
        : qtyToProduce;

    final materialLines = bom.components.map((c) {
      final reqQty = (c.quantity * (1 + (c.scrapPercent / 100))) * scaleFactor;
      return OrderMaterialLine(
        productId: c.productId,
        productName: c.productName,
        qtyRequired: reqQty,
        qtyConsumed: 0.0,
        availableQty: 0.0,
        unit: c.unit,
        unitCost: c.unitCost,
      );
    }).toList();

    // Scale operations
    final operationLines = bom.operations.map((op) {
      final plannedMin = op.setupMinutes + (op.runMinutesPerUnit * qtyToProduce);
      return OrderOperationLine(
        seq: op.seq,
        name: op.name,
        workcenterId: op.workcenterId,
        workcenterName: op.workcenterName,
        plannedMinutes: plannedMin,
        actualMinutes: 0.0,
        hourlyCost: op.hourlyCost,
        status: 'pending',
      );
    }).toList();

    final order = ProductionOrder(
      id: orderId,
      number: number,
      productId: bom.productId,
      productName: bom.productName,
      bomId: bom.id,
      bomVersion: bom.version,
      qtyPlanned: qtyToProduce,
      qtyProduced: 0.0,
      qtyScrapped: 0.0,
      unit: bom.unit,
      status: ProductionOrderStatus.draft,
      priority: priority,
      plannedStart: plannedStart ?? DateTime.now(),
      plannedEnd: plannedEnd ?? DateTime.now().add(const Duration(days: 3)),
      sourceWarehouseId: sourceWarehouseId,
      sourceWarehouseName: sourceWarehouseName,
      destWarehouseId: destWarehouseId,
      destWarehouseName: destWarehouseName,
      customerOrderId: customerOrderId,
      customerOrderNumber: customerOrderNumber,
      materialLines: materialLines,
      operationLines: operationLines,
      notes: notes,
      enterpriseId: eid,
    );

    await saveOrder(order);
    return order;
  }

  Future<void> saveOrder(ProductionOrder order) async {
    final eid = _activeEnterpriseId;
    final item = order.copyWith(enterpriseId: eid);
    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_orders')
        .doc(item.id)
        .set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteOrder(String id) async {
    final eid = _activeEnterpriseId;
    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_orders')
        .doc(id)
        .delete();
  }

  Future<void> confirmOrder(String id) async {
    final order = ordersNotifier.value.where((o) => o.id == id).firstOrNull;
    if (order == null) return;
    await saveOrder(order.copyWith(status: ProductionOrderStatus.confirmed));
  }

  Future<void> planOrder(String id, {DateTime? start, DateTime? end}) async {
    final order = ordersNotifier.value.where((o) => o.id == id).firstOrNull;
    if (order == null) return;
    await saveOrder(order.copyWith(
      status: ProductionOrderStatus.planned,
      plannedStart: start ?? order.plannedStart,
      plannedEnd: end ?? order.plannedEnd,
    ));
  }

  Future<void> startOrder(String id) async {
    final order = ordersNotifier.value.where((o) => o.id == id).firstOrNull;
    if (order == null) return;

    // Log stock movements for component consumption
    final eid = _activeEnterpriseId;
    final updatedLines = <OrderMaterialLine>[];

    for (final line in order.materialLines) {
      if (line.qtyRequired > 0 && order.sourceWarehouseId != null) {
        // Record exit movement
        final movement = StockMovement(
          id: _uuid.v4(),
          productId: line.productId,
          productName: line.productName,
          warehouseId: order.sourceWarehouseId!,
          warehouseName: order.sourceWarehouseName,
          type: MovementType.exit,
          quantity: line.qtyRequired,
          referenceType: 'production_order',
          referenceId: order.number,
          date: DateTime.now(),
          notes: 'Consommation fabrication ${order.number}',
          enterpriseId: eid,
        );
        try {
          await _firestore
              .collection('enterprises')
              .doc(eid)
              .collection('stock_movements')
              .doc(movement.id)
              .set(movement.toMap());

          // Decrement product stock in Firestore
          await _firestore
              .collection('enterprises')
              .doc(eid)
              .collection('products')
              .doc(line.productId)
              .update({'stock_qty': FieldValue.increment(-line.qtyRequired)});
        } catch (e) {
          debugPrint('[ProductionService] Stock exit log error: $e');
        }
      }

      updatedLines.add(line.copyWith(qtyConsumed: line.qtyRequired));
    }

    await saveOrder(order.copyWith(
      status: ProductionOrderStatus.inProgress,
      actualStart: DateTime.now(),
      materialLines: updatedLines,
    ));
  }

  Future<void> declareProduction({
    required String orderId,
    required double qtyProduced,
    double qtyScrapped = 0.0,
    String? note,
  }) async {
    final order = ordersNotifier.value.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;

    final eid = _activeEnterpriseId;
    final newProduced = order.qtyProduced + qtyProduced;
    final newScrapped = order.qtyScrapped + qtyScrapped;

    // Record entry movement of finished product into destination warehouse
    if (qtyProduced > 0 && order.destWarehouseId != null) {
      final movement = StockMovement(
        id: _uuid.v4(),
        productId: order.productId,
        productName: order.productName,
        warehouseId: order.destWarehouseId!,
        warehouseName: order.destWarehouseName,
        type: MovementType.entry,
        quantity: qtyProduced,
        referenceType: 'production_order',
        referenceId: order.number,
        date: DateTime.now(),
        notes: 'Entrée fabrication ${order.number}',
        enterpriseId: eid,
      );
      try {
        await _firestore
            .collection('enterprises')
            .doc(eid)
            .collection('stock_movements')
            .doc(movement.id)
            .set(movement.toMap());

        // Increment finished product stock
        await _firestore
            .collection('enterprises')
            .doc(eid)
            .collection('products')
            .doc(order.productId)
            .update({'stock_qty': FieldValue.increment(qtyProduced)});
      } catch (e) {
        debugPrint('[ProductionService] Stock entry log error: $e');
      }
    }

    // Determine next status: if full quantity produced -> Quality Check
    ProductionOrderStatus nextStatus = order.status;
    if (newProduced >= order.qtyPlanned) {
      nextStatus = ProductionOrderStatus.qualityCheck;
    }

    await saveOrder(order.copyWith(
      qtyProduced: newProduced,
      qtyScrapped: newScrapped,
      status: nextStatus,
      notes: note != null ? '${order.notes ?? ''}\n$note'.trim() : order.notes,
    ));
  }

  Future<void> completeOrder(String id) async {
    final order = ordersNotifier.value.where((o) => o.id == id).firstOrNull;
    if (order == null) return;
    await saveOrder(order.copyWith(
      status: ProductionOrderStatus.completed,
      actualEnd: DateTime.now(),
    ));
  }

  Future<void> cancelOrder(String id) async {
    final order = ordersNotifier.value.where((o) => o.id == id).firstOrNull;
    if (order == null) return;
    await saveOrder(order.copyWith(status: ProductionOrderStatus.cancelled));
  }

  Future<void> updateOperation({
    required String orderId,
    required int seq,
    String? status,
    double? actualMinutes,
    String? operatorId,
    String? operatorName,
  }) async {
    final order = ordersNotifier.value.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;

    final updatedOps = order.operationLines.map((op) {
      if (op.seq == seq) {
        return op.copyWith(
          status: status ?? op.status,
          actualMinutes: actualMinutes ?? op.actualMinutes,
          operatorId: operatorId ?? op.operatorId,
          operatorName: operatorName ?? op.operatorName,
        );
      }
      return op;
    }).toList();

    await saveOrder(order.copyWith(operationLines: updatedOps));
  }

  // ---------------------------------------------------------------------------
  // QUALITY CHECKS & NON-CONFORMITIES
  // ---------------------------------------------------------------------------
  Future<void> saveQualityCheck(ProductionQualityCheck check) async {
    final eid = _activeEnterpriseId;
    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_quality_checks')
        .doc(check.id)
        .set(check.toMap(), SetOptions(merge: true));

    // Update order qc_status
    final order = ordersNotifier.value.where((o) => o.id == check.orderId).firstOrNull;
    if (order != null) {
      String qcResultStr = 'passed';
      if (check.result == QualityCheckResult.nonConforme) {
        qcResultStr = 'failed';
      } else if (check.result == QualityCheckResult.avecReserves) {
        qcResultStr = 'warning';
      }
      await saveOrder(order.copyWith(qcStatus: qcResultStr));
    }
  }

  Future<void> saveNonConformity(ProductionNonConformity nc) async {
    final eid = _activeEnterpriseId;
    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_nonconformities')
        .doc(nc.id)
        .set(nc.toMap(), SetOptions(merge: true));
  }

  Future<void> updateNonConformityStatus(String id, String newStatus) async {
    final eid = _activeEnterpriseId;
    await _firestore
        .collection('enterprises')
        .doc(eid)
        .collection('production_nonconformities')
        .doc(id)
        .update({'status': newStatus});
  }

  // ---------------------------------------------------------------------------
  // KPI & PERFORMANCE HELPERS
  // ---------------------------------------------------------------------------
  int getActiveOrdersCount() {
    return ordersNotifier.value.where((o) =>
        o.status == ProductionOrderStatus.confirmed ||
        o.status == ProductionOrderStatus.planned ||
        o.status == ProductionOrderStatus.inProgress ||
        o.status == ProductionOrderStatus.qualityCheck).length;
  }

  int getDelayedOrdersCount() {
    final now = DateTime.now();
    return ordersNotifier.value.where((o) {
      if (o.status == ProductionOrderStatus.completed ||
          o.status == ProductionOrderStatus.cancelled) {
        return false;
      }
      return o.plannedEnd != null && o.plannedEnd!.isBefore(now);
    }).length;
  }

  double getMonthlyProducedUnits() {
    final now = DateTime.now();
    return ordersNotifier.value.where((o) {
      final d = o.actualEnd ?? o.createdAt;
      return d.month == now.month && d.year == now.year;
    }).fold(0.0, (acc, o) => acc + o.qtyProduced);
  }

  double getMonthlyProductionCost() {
    final now = DateTime.now();
    return ordersNotifier.value.where((o) {
      final d = o.actualEnd ?? o.createdAt;
      return d.month == now.month && d.year == now.year;
    }).fold(0.0, (acc, o) => acc + o.actualTotalCost);
  }

  double getGlobalOeeRate() {
    final completed = ordersNotifier.value
        .where((o) => o.status == ProductionOrderStatus.completed)
        .toList();
    if (completed.isEmpty) return 100.0;
    final totalPlanned = completed.fold(0.0, (acc, o) => acc + o.qtyPlanned);
    final totalProduced = completed.fold(0.0, (acc, o) => acc + o.qtyProduced);
    if (totalPlanned <= 0) return 100.0;
    return ((totalProduced / totalPlanned) * 100.0).clamp(0.0, 100.0);
  }

  double getGlobalScrapRate() {
    final completed = ordersNotifier.value
        .where((o) => o.status == ProductionOrderStatus.completed)
        .toList();
    if (completed.isEmpty) return 0.0;
    final totalScrapped = completed.fold(0.0, (acc, o) => acc + o.qtyScrapped);
    final totalTotal = completed.fold(0.0, (acc, o) => acc + (o.qtyProduced + o.qtyScrapped));
    if (totalTotal <= 0) return 0.0;
    return ((totalScrapped / totalTotal) * 100.0).clamp(0.0, 100.0);
  }
}
